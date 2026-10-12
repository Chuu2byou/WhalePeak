.pragma library

// timeline.js - geometry of the 24-hour bar: cells, ticks and hour labels.

var HOUR_MS = 60 * 60 * 1000;

var WINDOW_HOURS = 24;

var STEP_HOURS = 4;

// floorToHourMs - the full local hour a timestamp falls into.
function floorToHourMs(ms) {
    var date = new Date(ms);
    date.setMinutes(0, 0, 0);
    return date.getTime();
}

// cellStarts - the hourly cell starts of the window (24 hours by default).
function cellStarts(nowMs, spanHours) {
    var span = spanHours === undefined ? WINDOW_HOURS : spanHours;
    var first = floorToHourMs(nowMs);
    var starts = [];

    for (var i = 0; i <= span; i++) {
        starts.push(first + i * HOUR_MS);
    }
    return starts;
}

// tickStarts - the cells that carry a label: every stepHours hours after the first.
// Labels use local hours; around DST, an interval may differ by one hour.
function tickStarts(nowMs, spanHours, stepHours) {
    var span = spanHours === undefined ? WINDOW_HOURS : spanHours;
    var step = stepHours === undefined ? STEP_HOURS : stepHours;
    var first = floorToHourMs(nowMs);
    var last = first + span * HOUR_MS;
    var ticks = [];

    for (var ms = first; ms <= last; ms += HOUR_MS) {
        if (ms > first && new Date(ms).getHours() % step === 0) {
            ticks.push(ms);
        }
    }
    return ticks;
}

// fractionOf - the 0-1 position of a timestamp within the window.
function fractionOf(ms, nowMs, spanHours) {
    var span = spanHours === undefined ? WINDOW_HOURS : spanHours;
    return (ms - nowMs) / (span * HOUR_MS);
}

// cellRect - x and width of one hourly cell inside the bar width.
function cellRect(ms, nowMs, spanHours, totalWidth) {
    var x = Math.max(0, Math.min(totalWidth, fractionOf(ms, nowMs, spanHours) * totalWidth));
    var right = Math.max(0, Math.min(totalWidth, fractionOf(ms + HOUR_MS, nowMs, spanHours) * totalWidth));

    return { x: x, width: Math.max(0, right - x) };
}

// labelFor - the label of an hour mark: two-digit local time.
function labelFor(ms) {
    return String(new Date(ms).getHours()).padStart(2, "0");
}
