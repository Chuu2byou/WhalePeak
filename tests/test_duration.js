const assert = require("node:assert/strict");
const test = require("node:test");

const { loadQmlLibrary } = require("./helpers/qml_library.js");

const duration = loadQmlLibrary("contents/code/duration.js", ["splitDuration", "formatDuration", "tooltipSubText"]);

// Builds an object in the test world; splitDuration returns objects from the VM context.
function pick(parts) {
    return {
        days: parts.days,
        hours: parts.hours,
        minutes: parts.minutes,
        seconds: parts.seconds
    };
}

test("splits a duration into days, hours, minutes and seconds", () => {
    const millis = ((2 * 24 + 3) * 3600 + 4 * 60 + 5) * 1000;
    const parts = duration.splitDuration(millis);

    assert.equal(parts.totalSeconds, 2 * 86400 + 3 * 3600 + 4 * 60 + 5);
    assert.deepEqual(pick(parts), { days: 2, hours: 3, minutes: 4, seconds: 5 });
});

test("rounds partial seconds up", () => {
    assert.equal(duration.splitDuration(1).seconds, 1);
    assert.equal(duration.splitDuration(1500).seconds, 2);
});

test("clamps negative input to zero", () => {
    assert.deepEqual(pick(duration.splitDuration(-5000)), { days: 0, hours: 0, minutes: 0, seconds: 0 });
});

test("rolls over at the minute, hour and day boundary", () => {
    assert.deepEqual(pick(duration.splitDuration(59_999)), { days: 0, hours: 0, minutes: 1, seconds: 0 });
    assert.deepEqual(pick(duration.splitDuration(3_600_000)), { days: 0, hours: 1, minutes: 0, seconds: 0 });
    assert.deepEqual(pick(duration.splitDuration(86_400_000)), { days: 1, hours: 0, minutes: 0, seconds: 0 });
});

// The wording lives in duration.js; main.qml and the render fixture only pass
// their i18n()/stub wrapper in. A stand-in records the call and joins the parts.
function translate(text) {
    const args = Array.prototype.slice.call(arguments, 1);
    return String(text).replace(/%([0-9]+)/g, (match, index) => {
        const value = args[Number(index) - 1];
        return value === undefined ? match : String(value);
    });
}

test("formatDuration picks the text and hands the parts to translate", () => {
    assert.equal(duration.formatDuration(90_061_000, translate), "1 d 1 h");
    assert.equal(duration.formatDuration(3_660_000, translate), "1 h 1 min");
    assert.equal(duration.formatDuration(305_000, translate), "5 min 5 s");
    assert.equal(duration.formatDuration(42_000, translate), "42 s");
});

test("tooltipSubText joins state, remaining time and balance", () => {
    assert.equal(duration.tooltipSubText("Peak", "", "", translate), "Peak");
    assert.equal(duration.tooltipSubText("Peak", "1 h 13 min", "", translate),
        "Peak \u00b7 1 h 13 min left");
    assert.equal(duration.tooltipSubText("Off-peak", "13 h 43 min", "12.34 USD", translate),
        "Off-peak \u00b7 13 h 43 min left \u00b7 Balance: 12.34 USD");
    assert.equal(duration.tooltipSubText("Off-peak", "", "12.34 USD", translate),
        "Off-peak \u00b7 Balance: 12.34 USD");
});
