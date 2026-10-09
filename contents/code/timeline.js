.pragma library

// Geometry of the timeline: a sliding window whose left edge is the current
// instant. Because the window itself moves with time, new hours enter on the
// right and drop off on the left - the bar therefore slides rightwards over the
// clock.
//
// Deliberately without imports and without Plasma dependencies: only then can
// tests/helpers/qml_library.js check the arithmetic in Node.

var HOUR_MS = 60 * 60 * 1000;

// Visible window length in hours: "now" on the left, then that many hours.
var WINDOW_HOURS = 24;

// Step of the axis labels in hours (local wall clock).
var STEP_HOURS = 4;

// Rounds the local wall clock down to the start of the hour. Uses setMinutes
// instead of modulo arithmetic, so timezones with a half-hour offset work too.
function floorToHourMs(ms) {
    var date = new Date(ms);
    date.setMinutes(0, 0, 0);
    return date.getTime();
}

// Start instants of the hour cells: always WINDOW_HOURS + 1 of them. The first
// cell starts before "now" (it is cut off on the left), the last reaches the end
// of the window and can collapse to zero width there.
//
// The result depends only on the start of the hour, so it stays constant within
// an hour - the tariff classification need not be recomputed every second, only
// the x positions keep sliding.
function cellStarts(nowMs, spanHours) {
    var span = spanHours === undefined ? WINDOW_HOURS : spanHours;
    var first = floorToHourMs(nowMs);
    var starts = [];

    for (var i = 0; i <= span; i++) {
        starts.push(first + i * HOUR_MS);
    }
    return starts;
}

// Start instants of the axis labels: local multiples of stepHours that fall
// inside the window. The left edge itself is not part of it - it is the current
// instant and would only be readable half cut off there.
//
// Known limitation: the steps are absolute (HOUR_MS) while the filter uses the
// local hour. Around a daylight-saving change the gap between two labels can
// therefore be one hour more or less, and a local hour can be skipped or
// repeated. The bar itself (cellStarts/cellRect, absolute hours) is unaffected.
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

// Fraction of the window width by which an instant is away from the left edge.
// Values below 0 or above 1 lie outside the window.
function fractionOf(ms, nowMs, spanHours) {
    var span = spanHours === undefined ? WINDOW_HOURS : spanHours;
    return (ms - nowMs) / (span * HOUR_MS);
}

// Position and width of an hour cell in pixels, clipped at both window edges.
// The sum of all widths adds up to the full row width again.
function cellRect(ms, nowMs, spanHours, totalWidth) {
    var x = Math.max(0, Math.min(totalWidth, fractionOf(ms, nowMs, spanHours) * totalWidth));
    var right = Math.max(0, Math.min(totalWidth, fractionOf(ms + HOUR_MS, nowMs, spanHours) * totalWidth));

    return { x: x, width: Math.max(0, right - x) };
}

// Axis label as local clock time "HH". In the sliding window there is no 24:00 -
// midnight reads "00".
function labelFor(ms) {
    return String(new Date(ms).getHours()).padStart(2, "0");
}
