.pragma library

// Pure logic for the DeepSeek balance query (GET /user/balance) and for the
// kwallet-query commands. No QML, so the functions run in the Node tests
// without a Plasma runtime. UI strings and translations stay in QML, because
// i18n() is not available here.
//
// DeepSeek has no endpoint for consumed usage; /user/balance only reports the
// remaining balance.

// Single source for the endpoint, so the widget (main.qml) and the settings
// dialog (configGeneral.qml) cannot drift apart.
var BALANCE_API_URL = "https://api.deepseek.com/user/balance";

// Deadline for the whole wallet + HTTP chain, shared by the widget
// (walletTimeoutMs) and the settings dialog (keyTimeoutMs). tools/kwallet-set.sh
// keeps the same value as KEY_TIMEOUT (shell, see tools/lib.sh).
var WALLET_TIMEOUT_MS = 20000;

// Result shape for every error case, so callers only check one path.
function emptyResult(state, httpStatus) {
    return {
        state: state,
        httpStatus: httpStatus,
        isAvailable: false,
        entries: []
    };
}

// Flattens the GET /user/balance response. httpStatus 0 means the request
// never reached the network.
function parseBalance(httpStatus, responseText) {
    if (httpStatus === 401 || httpStatus === 403) {
        return emptyResult("unauthorized", httpStatus);
    }
    if (httpStatus !== 200) {
        return emptyResult("error", httpStatus);
    }

    var payload;
    try {
        payload = JSON.parse(responseText);
    } catch (e) {
        return emptyResult("error", httpStatus);
    }
    if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
        return emptyResult("error", httpStatus);
    }

    var infos = payload.balance_infos;
    if (!Array.isArray(infos)) {
        return emptyResult("error", httpStatus);
    }

    var entries = [];
    for (var i = 0; i < infos.length; i++) {
        var info = infos[i];
        if (!info || typeof info !== "object" || Array.isArray(info)) {
            continue;
        }
        entries.push({
            currency: String(info.currency || ""),
            totalBalance: String(info.total_balance || ""),
            grantedBalance: String(info.granted_balance || ""),
            toppedUpBalance: String(info.topped_up_balance || "")
        });
    }

    return {
        state: "ok",
        httpStatus: httpStatus,
        // A missing field means the account is usable: the call succeeded.
        isAvailable: payload.is_available !== false,
        entries: entries
    };
}

// Prefers USD (the usual billing currency), otherwise the first entry with a
// balance. Returns null when there is nothing to show.
function selectBalanceEntry(entries) {
    if (!Array.isArray(entries) || entries.length === 0) {
        return null;
    }

    var fallback = null;
    for (var i = 0; i < entries.length; i++) {
        var entry = entries[i];
        if (!entry || String(entry.totalBalance) === "") {
            continue;
        }
        if (fallback === null) {
            fallback = entry;
        }
        if (String(entry.currency).toUpperCase() === "USD") {
            return entry;
        }
    }
    return fallback;
}

// Wraps a value in single quotes and escapes embedded apostrophes the POSIX
// way ('\''). The executable engine runs its commands through the shell, so
// quoting configuration values is mandatory - without it command injection
// would be possible.
function quoteShellArg(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'";
}

// Strips the usual paste leftovers around the key: surrounding whitespace and
// line breaks, one pair of surrounding quotes and a leading "Bearer ". The key
// itself stays untouched; tools/kwallet-set.sh mirrors this function so script
// and widget store the same value.
function normalizeKey(raw) {
    var key = String(raw === undefined || raw === null ? "" : raw).trim();

    if (key.length >= 2) {
        var first = key.charAt(0);
        var last = key.charAt(key.length - 1);
        if ((first === "\"" && last === "\"") || (first === "'" && last === "'")) {
            key = key.substring(1, key.length - 1).trim();
        }
    }

    return key.replace(/^Bearer\s+/i, "").trim();
}

// Reads the API key from KWallet. kwallet-query writes the value to stdout.
function readKeyCommand(wallet, folder, entry) {
    return "kwallet-query -r " + quoteShellArg(entry)
        + " -f " + quoteShellArg(folder)
        + " " + quoteShellArg(wallet);
}

// Writes the API key to KWallet. kwallet-query reads the value from stdin,
// hence the pipe; printf without a line break keeps the key exact.
//
// Known limitation: printf receives the key as a command line argument, so it
// is briefly visible in the local process list (ps). The Plasma "executable"
// engine runs its command through a shell and offers no stdin, so the key
// cannot be piped in without such a helper process. The quoting below still
// prevents command injection; for the lowest exposure store the key once with
// tools/kwallet-set.sh and let the widget only read it back.
function writeKeyCommand(wallet, folder, entry, key) {
    return "printf %s " + quoteShellArg(key)
        + " | kwallet-query -w " + quoteShellArg(entry)
        + " -f " + quoteShellArg(folder)
        + " " + quoteShellArg(wallet);
}
