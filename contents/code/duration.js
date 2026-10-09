.pragma library

// Splits a duration into its parts and composes the readable texts from them.
// Pure data, so the logic stays testable; the actual translation happens in the
// caller, because i18n() is not available in a .pragma library file. The views
// pass their translate function in, so the widget, the render fixture and the
// tests share one wording instead of keeping copies in sync by hand.

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

// Readable duration ("2 d 3 h", "1 h 13 min", "4 min 5 s", "42 s"). `translate`
// is the caller's i18n() wrapper; it receives the text and the two placeholders
// it may use, and returns the finished string.
function formatDuration(milliseconds, translate) {
    var parts = splitDuration(milliseconds);
    if (parts.days > 0) {
        return translate("%1 d %2 h", parts.days, parts.hours);
    }
    if (parts.hours > 0) {
        return translate("%1 h %2 min", parts.hours, parts.minutes);
    }
    if (parts.minutes > 0) {
        return translate("%1 min %2 s", parts.minutes, parts.seconds);
    }
    return translate("%1 s", parts.seconds);
}

// Second line of the panel tooltip: "Peak \u00b7 1 h 13 min left \u00b7 Balance:
// 12.34 USD". `statusText` is already translated ("Peak"/"Off-peak"),
// `remainingText` and `balanceText` are empty when that part is not shown.
function tooltipSubText(statusText, remainingText, balanceText, translate) {
    var base = remainingText.length > 0
        ? translate("%1 \u00b7 %2 left", statusText, remainingText)
        : statusText;
    if (balanceText.length > 0) {
        return translate("%1 \u00b7 %2", base, translate("Balance: %1", balanceText));
    }
    return base;
}
