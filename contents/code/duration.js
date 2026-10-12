.pragma library

// duration.js - splits a remaining time and renders the countdown texts.
//
// The caller supplies translation; i18n() is unavailable in library JS.

var SECONDS_PER_MINUTE = 60;
var SECONDS_PER_HOUR = 60 * SECONDS_PER_MINUTE;
var SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR;

// splitDuration - breaks a millisecond span into days, hours, minutes and seconds.
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

// formatDuration - renders the two largest non-zero parts, e.g. "1 h 13 min".
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

// tooltipSubText - joins state, remaining time and balance into one tooltip line.
function tooltipSubText(statusText, remainingText, balanceText, translate) {
    var base = remainingText.length > 0
        ? translate("%1 \u00b7 %2 left", statusText, remainingText)
        : statusText;
    if (balanceText.length > 0) {
        return translate("%1 \u00b7 %2", base, translate("Balance: %1", balanceText));
    }
    return base;
}
