.pragma library

// Peak/off-peak classification and the next tariff change.

var HOUR_MS = 60 * 60 * 1000;
var DAY_MS = 24 * HOUR_MS;
var MAX_SEARCH_MS = 30 * DAY_MS;

// Minutes after UTC midnight at which the tariff status can change: the two
// peak windows start and end here, and at 16:00 UTC the Beijing date rolls over
// (16:00 UTC = 00:00 Beijing) - that also flips weekday/weekend/holiday and with
// them the base classification.
//
// The two peak windows follow DeepSeek's published off-peak discount, see
// <https://api-docs.deepseek.com/quick_start/pricing>. Unlike the colour
// palettes there is no bundled source to compare against, so these values are a
// snapshot: re-check them when DeepSeek changes the windows.
//
// Every transition sits on a UTC full hour, which is why main.qml and
// tests/fixtures/render-images.qml can cache the result per hour.
var UTC_CHANGE_MINUTES = [60, 240, 360, 600, 16 * 60];

function getBeijingDateStr(ms) {
    var date = new Date(ms + 8 * HOUR_MS);
    var year = date.getUTCFullYear();
    var month = String(date.getUTCMonth() + 1).padStart(2, "0");
    var day = String(date.getUTCDate()).padStart(2, "0");
    return year + "-" + month + "-" + day;
}

// Weekday (0 = Sunday) of the Beijing calendar date.
function weekdayOf(dateStr) {
    var parts = dateStr.split("-");
    return new Date(Date.UTC(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))).getUTCDay();
}

function isPeakDay(dateStr, cal, opts) {
    if (cal.holidays.has(dateStr)) {
        return false;
    }

    var weekday = weekdayOf(dateStr);
    if (weekday !== 0 && weekday !== 6) {
        return true;
    }

    return opts.treatWeekendWorkdayAsPeak && cal.workdays.has(dateStr);
}

function getStatus(ms, cal, opts) {
    var dateStr = getBeijingDateStr(ms);
    var year = Number(dateStr.slice(0, 4));
    var calendarCovered = cal.coveredYears.indexOf(year) !== -1;
    var isHoliday = cal.holidays.has(dateStr);
    var peakDay = isPeakDay(dateStr, cal, opts);
    var date = new Date(ms);
    var utcMinute = date.getUTCHours() * 60 + date.getUTCMinutes();
    var inPeakWindow = (utcMinute >= 60 && utcMinute < 240)
        || (utcMinute >= 360 && utcMinute < 600);

    var reason;
    if (isHoliday) {
        reason = "holiday";
    } else if (!peakDay) {
        reason = "weekend";
    } else if (inPeakWindow) {
        var weekday = weekdayOf(dateStr);
        reason = (weekday === 0 || weekday === 6) ? "makeupWorkday" : "weekday";
    } else {
        reason = "offWindow";
    }

    return {
        isPeak: peakDay && inPeakWindow,
        holidayToday: isHoliday,
        calendarCovered: calendarCovered,
        reason: reason
    };
}

// Always returns an object: `ms` and `toPeak` are `null` when no transition was
// found within the search horizon. The coverage information from the full 30 day
// scan is kept in that case too.
function getNextChange(ms, cal, opts) {
    var horizon = ms + MAX_SEARCH_MS;
    var initialStatus = getStatus(ms, cal, opts);
    var calendarCovered = initialStatus.calendarCovered;
    var nextTransition = null;
    var utcDayStart = Math.floor(ms / DAY_MS) * DAY_MS;

    for (var dayOffset = 0; dayOffset <= 30; dayOffset++) {
        var dayStart = utcDayStart + dayOffset * DAY_MS;
        for (var i = 0; i < UTC_CHANGE_MINUTES.length; i++) {
            var candidate = dayStart + UTC_CHANGE_MINUTES[i] * 60 * 1000;
            if (candidate <= ms || candidate > horizon) {
                continue;
            }

            var status = getStatus(candidate, cal, opts);
            calendarCovered = calendarCovered && status.calendarCovered;
            if (nextTransition === null && status.isPeak !== initialStatus.isPeak) {
                nextTransition = { ms: candidate, toPeak: status.isPeak };
            }
        }
    }

    return {
        ms: nextTransition === null ? null : nextTransition.ms,
        toPeak: nextTransition === null ? null : nextTransition.toPeak,
        calendarCovered: calendarCovered
    };
}