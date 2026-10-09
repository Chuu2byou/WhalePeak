const assert = require("node:assert/strict");
const test = require("node:test");

const { loadQmlLibrary, plain } = require("./helpers/qml_library.js");

const balance = loadQmlLibrary("contents/code/balance.js", [
    "parseBalance",
    "selectBalanceEntry",
    "quoteShellArg",
    "normalizeKey",
    "readKeyCommand",
    "writeKeyCommand",
    "BALANCE_API_URL",
    "WALLET_TIMEOUT_MS"
]);

// The endpoint and the timeout are shared with main.qml and configGeneral.qml, so
// a silent change would break both UIs at once.
test("exposes the shared endpoint and timeout constants", () => {
    assert.equal(balance.BALANCE_API_URL, "https://api.deepseek.com/user/balance");
    assert.equal(balance.WALLET_TIMEOUT_MS, 20000);
});

// Example response as described in the DeepSeek API reference.
const USD_RESPONSE = JSON.stringify({
    is_available: true,
    balance_infos: [
        {
            currency: "USD",
            total_balance: "12.34",
            granted_balance: "0.00",
            topped_up_balance: "12.34"
        }
    ]
});

test("reads a successful balance response", () => {
    const result = balance.parseBalance(200, USD_RESPONSE);

    assert.equal(result.state, "ok");
    assert.equal(result.httpStatus, 200);
    assert.equal(result.isAvailable, true);
    assert.deepEqual(plain(result.entries), [
        {
            currency: "USD",
            totalBalance: "12.34",
            grantedBalance: "0.00",
            toppedUpBalance: "12.34"
        }
    ]);
});

test("treats a rejected API token as unauthorized", () => {
    assert.equal(balance.parseBalance(401, "").state, "unauthorized");
    assert.equal(balance.parseBalance(403, "<html>").state, "unauthorized");
});

test("reports other status codes and network failures as error", () => {
    assert.equal(balance.parseBalance(500, "").state, "error");
    assert.equal(balance.parseBalance(429, "").state, "error");
    // 0 in QML means the request never reached the network.
    assert.equal(balance.parseBalance(0, "").state, "error");
});

test("survives broken JSON and empty responses", () => {
    assert.equal(balance.parseBalance(200, "").state, "error");
    assert.equal(balance.parseBalance(200, "not json").state, "error");
    assert.equal(balance.parseBalance(200, "[]").state, "error");
    assert.equal(balance.parseBalance(200, "null").state, "error");
});

test("requires a balance_infos list", () => {
    assert.equal(balance.parseBalance(200, JSON.stringify({ is_available: true })).state, "error");
    assert.equal(balance.parseBalance(200, JSON.stringify({ balance_infos: "USD" })).state, "error");
});

test("skips unusable entries and converts numbers to text", () => {
    const response = JSON.stringify({
        balance_infos: [null, "kaputt", { currency: "CNY", total_balance: 7.5 }]
    });
    const result = balance.parseBalance(200, response);

    assert.equal(result.state, "ok");
    assert.deepEqual(plain(result.entries), [
        {
            currency: "CNY",
            totalBalance: "7.5",
            grantedBalance: "",
            toppedUpBalance: ""
        }
    ]);
    // Without the is_available field the account stays usable.
    assert.equal(result.isAvailable, true);
});

test("only clears is_available on an explicit false", () => {
    const response = JSON.stringify({ is_available: false, balance_infos: [] });
    assert.equal(balance.parseBalance(200, response).isAvailable, false);
});

// A success without a displayable entry stays "ok"; the UI must treat this case
// as its own state, otherwise it would read "Balance: " without a value.
test("an ok answer without a usable entry selects nothing", () => {
    const result = balance.parseBalance(200, JSON.stringify({ is_available: true, balance_infos: [] }));

    assert.equal(result.state, "ok");
    assert.equal(result.isAvailable, true);
    assert.equal(balance.selectBalanceEntry(result.entries), null);
});

test("prefers USD, otherwise the first entry with a balance", () => {
    const result = balance.parseBalance(200, JSON.stringify({
        balance_infos: [
            { currency: "CNY", total_balance: "88.00" },
            { currency: "USD", total_balance: "12.34" }
        ]
    }));

    assert.equal(balance.selectBalanceEntry(result.entries).currency, "USD");
    assert.equal(balance.selectBalanceEntry([]), null);
    assert.equal(balance.selectBalanceEntry(null), null);
    assert.equal(balance.selectBalanceEntry([{ currency: "USD", totalBalance: "" }]), null);
    assert.equal(
        balance.selectBalanceEntry([{ currency: "CNY", totalBalance: "88" }]).currency,
        "CNY"
    );
});

test("quotes shell arguments with single quotes", () => {
    assert.equal(balance.quoteShellArg("api_key"), "'api_key'");
    assert.equal(balance.quoteShellArg("my folder"), "'my folder'");
    assert.equal(balance.quoteShellArg("it's"), "'it'\\''s'");
    // An attack value stays caught inside the quotes.
    assert.equal(balance.quoteShellArg("x'; rm -rf ~; '"), "'x'\\''; rm -rf ~; '\\'''");
});

test("strips paste leftovers around the API key", () => {
    assert.equal(balance.normalizeKey("  sk-abc\n"), "sk-abc");
    assert.equal(balance.normalizeKey("sk-abc"), "sk-abc");
    assert.equal(balance.normalizeKey('"sk-abc"'), "sk-abc");
    assert.equal(balance.normalizeKey("'sk-abc'"), "sk-abc");
    assert.equal(balance.normalizeKey("Bearer sk-abc"), "sk-abc");
    assert.equal(balance.normalizeKey("  Bearer  sk-abc  "), "sk-abc");
    assert.equal(balance.normalizeKey(' "Bearer sk-abc" '), "sk-abc");
    assert.equal(balance.normalizeKey(""), "");
    assert.equal(balance.normalizeKey(null), "");
    assert.equal(balance.normalizeKey(undefined), "");
    // A single quote is no pair and stays as is.
    assert.equal(balance.normalizeKey('"sk-abc'), '"sk-abc');
});

test("builds the read and write command for kwallet-query", () => {
    assert.equal(
        balance.readKeyCommand("kdewallet", "DeepSeek", "api_key"),
        "kwallet-query -r 'api_key' -f 'DeepSeek' 'kdewallet'"
    );
    assert.equal(
        balance.writeKeyCommand("kdewallet", "DeepSeek", "api_key", "sk-abc"),
        "printf %s 'sk-abc' | kwallet-query -w 'api_key' -f 'DeepSeek' 'kdewallet'"
    );
});

test("keeps special characters inside the printf argument", () => {
    const command = balance.writeKeyCommand("w", "f", "e", "sk-a's$(touch /tmp/x)`");

    assert.equal(
        command,
        "printf %s 'sk-a'\\''s$(touch /tmp/x)`' | kwallet-query -w 'e' -f 'f' 'w'"
    );
    // Exactly one pipe character: no second command can come out of the key.
    assert.equal(command.split("|").length, 2);
});

// 0 is falsy, so a naive `value || ""` would drop a real zero balance.
test("keeps a numeric zero balance", () => {
    const result = balance.parseBalance(200, JSON.stringify({
        balance_infos: [{ currency: "USD", total_balance: 0 }]
    }));

    assert.equal(result.state, "ok");
    assert.equal(result.entries[0].totalBalance, "0");
    assert.equal(balance.selectBalanceEntry(result.entries).totalBalance, "0");
});
