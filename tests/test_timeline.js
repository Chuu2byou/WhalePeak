const assert = require("node:assert/strict");
const test = require("node:test");

const { loadQmlLibrary, plain } = require("./helpers/qml_library.js");

const apiNames = [
    "HOUR_MS",
    "WINDOW_HOURS",
    "STEP_HOURS",
    "floorToHourMs",
    "cellStarts",
    "tickStarts",
    "fractionOf",
    "cellRect",
    "labelFor"
];
const timeline = loadQmlLibrary("contents/code/timeline.js", apiNames);

const HOUR = timeline.HOUR_MS;
const SPAN = timeline.WINDOW_HOURS;
const WIDTH = 400;

// The timeline works in local wall clock time, so the tests build their instants
// the same way. Only relative properties are checked then, so the tests are
// independent of the test machine's timezone. All dates deliberately lie outside
// any daylight-saving change.
function localTime(year, month, day, hour, minute) {
    return new Date(year, month - 1, day, hour, minute).getTime();
}

function localHour(ms) {
    return new Date(ms).getHours();
}

test("window constants stay the documented values", () => {
    assert.equal(timeline.WINDOW_HOURS, 24);
    assert.equal(timeline.STEP_HOURS, 4);
    assert.equal(timeline.HOUR_MS, 3_600_000);
});

test("floors a timestamp to the start of the local hour", () => {
    const now = localTime(2026, 7, 15, 13, 30) + 45_000 + 123;
    const floored = timeline.floorToHourMs(now);

    assert.equal(localHour(floored), 13);
    assert.equal(new Date(floored).getMinutes(), 0);
    assert.equal(new Date(floored).getSeconds(), 0);
    assert.equal(new Date(floored).getMilliseconds(), 0);
    assert.ok(floored <= now);
    assert.ok(now - floored < HOUR);
    assert.equal(timeline.floorToHourMs(localTime(2026, 7, 15, 13, 0)), localTime(2026, 7, 15, 13, 0));
});

test("cellStarts covers a full window in one hour steps", () => {
    const now = localTime(2026, 7, 15, 13, 30);
    const starts = plain(timeline.cellStarts(now, SPAN));

    assert.equal(starts.length, SPAN + 1);
    for (let i = 1; i < starts.length; i++) {
        assert.equal(starts[i] - starts[i - 1], HOUR);
    }
    // The first cell starts before "now" and is clipped on the left ...
    assert.ok(starts[0] <= now);
    assert.ok(now - starts[0] < HOUR);
    // ... the last reaches the end of the window or beyond.
    assert.ok(starts[starts.length - 1] + HOUR >= now + SPAN * HOUR);
});

test("cellStarts stays the same inside one hour", () => {
    // Basis for the hourly rebuild in Timeline.qml: only the x positions slide,
    // the model itself stays put.
    const start = plain(timeline.cellStarts(localTime(2026, 7, 15, 13, 0), SPAN));
    const later = plain(timeline.cellStarts(localTime(2026, 7, 15, 13, 59), SPAN));

    assert.deepEqual(later, start);
});

test("fractionOf puts the current time at the left edge", () => {
    const now = localTime(2026, 7, 15, 13, 30);

    assert.equal(timeline.fractionOf(now, now, SPAN), 0);
    assert.equal(timeline.fractionOf(now + SPAN * HOUR, now, SPAN), 1);
    assert.equal(timeline.fractionOf(now + (SPAN / 2) * HOUR, now, SPAN), 0.5);
    assert.ok(timeline.fractionOf(now - HOUR, now, SPAN) < 0);
    assert.ok(timeline.fractionOf(now + (SPAN + 1) * HOUR, now, SPAN) > 1);
});

test("cellRect tiles the row exactly, without gaps or overflow", () => {
    const moments = [
        localTime(2026, 7, 15, 13, 30),
        localTime(2026, 7, 15, 0, 0),
        localTime(2026, 7, 15, 23, 59),
        localTime(2026, 12, 31, 22, 30)
    ];

    for (const now of moments) {
        let covered = 0;
        for (const ms of plain(timeline.cellStarts(now, SPAN))) {
            const rect = plain(timeline.cellRect(ms, now, SPAN, WIDTH));
            assert.ok(rect.x >= 0 && rect.x <= WIDTH, `x outside the row: ${rect.x}`);
            assert.ok(rect.width >= 0, `negative width: ${rect.width}`);
            assert.ok(rect.x + rect.width <= WIDTH, `cell overflows: ${rect.x + rect.width}`);
            covered += rect.width;
        }
        assert.ok(Math.abs(covered - WIDTH) < 1e-9, `coverage ${covered} instead of ${WIDTH}`);
    }
});

test("the first cell is clipped at the left edge", () => {
    const now = localTime(2026, 7, 15, 13, 30);
    const starts = plain(timeline.cellStarts(now, SPAN));
    const first = plain(timeline.cellRect(starts[0], now, SPAN, WIDTH));

    assert.equal(first.x, 0);
    // Half an hour visible, because "now" sits at half past.
    assert.ok(Math.abs(first.width - WIDTH / SPAN / 2) < 1e-9);
});

test("the last cell collapses when the window ends on the hour", () => {
    const now = localTime(2026, 7, 15, 13, 0);
    const starts = plain(timeline.cellStarts(now, SPAN));
    const last = plain(timeline.cellRect(starts[starts.length - 1], now, SPAN, WIDTH));

    assert.equal(last.x, WIDTH);
    assert.equal(last.width, 0);
});

test("tickStarts follows the four hour grid inside the window", () => {
    const now = localTime(2026, 7, 15, 13, 30);
    const ticks = plain(timeline.tickStarts(now, SPAN, timeline.STEP_HOURS));

    assert.ok(ticks.length >= 5, `too few labels: ${ticks.length}`);
    for (let i = 1; i < ticks.length; i++) {
        assert.ok(ticks[i] > ticks[i - 1], "labels not ascending");
    }
    for (const ms of ticks) {
        assert.equal(new Date(ms).getMinutes(), 0);
        assert.equal(localHour(ms) % timeline.STEP_HOURS, 0);
        assert.ok(ms > now - HOUR, `label lies in the past: ${ms}`);
        assert.ok(ms <= now + SPAN * HOUR, `label lies beyond the window: ${ms}`);
    }
    // 16:00 (local) lies inside the window and must be labelled.
    assert.ok(ticks.some((ms) => localHour(ms) === 16 && new Date(ms).getDate() === 15));
});

test("the window crosses the year boundary at midnight", () => {
    const now = localTime(2026, 12, 31, 22, 30);
    const starts = plain(timeline.cellStarts(now, SPAN));

    assert.equal(new Date(starts[starts.length - 1]).getFullYear(), 2027);
    assert.equal(timeline.labelFor(starts[starts.length - 1]), "22");

    const midnight = plain(starts.find((ms) => localHour(ms) === 0));
    assert.equal(timeline.labelFor(midnight), "00");
});

test("labelFor prints the local hour and never 24", () => {
    assert.equal(timeline.labelFor(localTime(2026, 7, 15, 0, 0)), "00");
    assert.equal(timeline.labelFor(localTime(2026, 7, 15, 9, 0)), "09");
    assert.equal(timeline.labelFor(localTime(2026, 7, 15, 23, 0)), "23");
});
