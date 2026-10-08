.pragma library

// Splits a duration into its parts. Pure data, so the logic stays testable; the
// translation of the parts into readable text happens in QML (i18n() is not
// available in a .pragma library file).

var SECONDS_PER_MINUTE = 60;
var SECONDS_PER_HOUR = 60 * SECONDS_PER_MINUTE;
var SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR;

// Rounds up to whole seconds and clamps negative input to zero.
function splitDuration(milliseconds) {
    var totalSeconds = Math.max(0, Math.ceil(milliseconds / 1000));
    return {
        totalSeconds: totalSeconds,
        days: Math.floor(totalSeconds / SECONDS_PER_DAY),
        hours: Math.floor((totalSeconds % SECONDS_PER_DAY) / SECONDS_PER_HOUR),
        minutes: Math.floor((totalSeconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE),
        seconds: totalSeconds % SECONDS_PER_MINUTE
    };
}
