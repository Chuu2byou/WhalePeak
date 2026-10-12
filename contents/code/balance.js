.pragma library

// balance.js - parses the DeepSeek balance API and builds the KWallet commands.

var BALANCE_API_URL = "https://api.deepseek.com/user/balance";

var WALLET_TIMEOUT_MS = 20000;

// fieldText - returns a JSON field as text, empty for a missing value.
function fieldText(value) {
    return value === undefined || value === null ? "" : String(value);
}

// emptyResult - the result object for a failed or empty balance request.
function emptyResult(state, httpStatus) {
    return {
        state: state,
        httpStatus: httpStatus,
        isAvailable: false,
        entries: []
    };
}

// parseBalance - turns the /user/balance answer into a result object.
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
            currency: fieldText(info.currency),
            totalBalance: fieldText(info.total_balance),
            grantedBalance: fieldText(info.granted_balance),
            toppedUpBalance: fieldText(info.topped_up_balance)
        });
    }

    return {
        state: "ok",
        httpStatus: httpStatus,
        // Treat a missing field as usable after a successful response.
        isAvailable: payload.is_available !== false,
        entries: entries
    };
}

// selectBalanceEntry - the USD entry when there is one, else the first usable one.
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

// quoteShellArg - wraps a value in single quotes for a shell command line.
// Commands run through a shell, so quote values to prevent injection.
function quoteShellArg(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'";
}

// normalizeKey - cleans a pasted key: quotes, whitespace and a Bearer prefix.
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

// readKeyCommand - the kwallet-query call that reads the key.
function readKeyCommand(wallet, folder, entry) {
    return "kwallet-query -r " + quoteShellArg(entry)
        + " -f " + quoteShellArg(folder)
        + " " + quoteShellArg(wallet);
}

// writeKeyCommand - the kwallet-query call that stores the key.
// The executable engine has no stdin, so the key briefly appears in the process list.
function writeKeyCommand(wallet, folder, entry, key) {
    return "printf %s " + quoteShellArg(key)
        + " | kwallet-query -w " + quoteShellArg(entry)
        + " -f " + quoteShellArg(folder)
        + " " + quoteShellArg(wallet);
}
