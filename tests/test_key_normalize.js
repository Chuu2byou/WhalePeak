// Guards the duplication between the JS normaliser (Balance.normalizeKey) and its
// shell counterpart (tracker_normalize_key in tools/lib.sh). Both must turn the
// same input into the same stored key, otherwise the key saved by
// tools/kwallet-set.sh would not match the one the widget reads back.
const assert = require("node:assert/strict");
const test = require("node:test");
const { execFileSync } = require("node:child_process");

const { loadQmlLibrary, projectRoot } = require("./helpers/qml_library.js");

const balance = loadQmlLibrary("contents/code/balance.js", ["normalizeKey"]);

// No NUL bytes: they cannot travel through an argument vector, and neither the
// shell nor the JS normaliser is expected to handle them.
const SAMPLES = [
    "",
    "sk-abc",
    "  sk-abc\n",
    "sk-abc\r\n",
    '"sk-abc"',
    "'sk-abc'",
    "Bearer sk-abc",
    "  Bearer  sk-abc  ",
    ' "Bearer sk-abc" ',
    '"sk-abc',
    "\tsk-abc\t",
    "sk-abc def",
    "''",
    '""'
];

function bashAvailable() {
    try {
        execFileSync("bash", ["--version"], { stdio: "ignore" });
        return true;
    } catch (error) {
        return false;
    }
}

// Runs the shell normaliser from tools/lib.sh with the sample on stdin.
function shellNormalize(input) {
    const script = 'source "$1/tools/lib.sh"; printf %s "$2" | tracker_normalize_key';
    return execFileSync("bash", ["-c", script, "bash", projectRoot, input], { encoding: "utf8" });
}

test("shell and JS normalisers agree on every sample", { skip: !bashAvailable() }, () => {
    for (const sample of SAMPLES) {
        assert.equal(
            shellNormalize(sample),
            balance.normalizeKey(sample),
            "input " + JSON.stringify(sample)
        );
    }
});
