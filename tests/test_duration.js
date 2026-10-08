const assert = require("node:assert/strict");
const test = require("node:test");

const { loadQmlLibrary } = require("./helpers/qml_library.js");

const duration = loadQmlLibrary("contents/code/duration.js", ["splitDuration"]);

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
