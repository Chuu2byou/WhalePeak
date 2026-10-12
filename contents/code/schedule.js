.pragma library

// schedule.js - the DeepSeek peak windows, expressed in Beijing time (UTC+8).

var HOUR_MS = 60 * 60 * 1000;
var DAY_MS = 24 * HOUR_MS;
var MAX_SEARCH_MS = 30 * DAY_MS;

// UTC transition minutes from DeepSeek pricing; 16:00 UTC is Beijing midnight.
var UTC_CHANGE_MINUTES = [60, 240, 360, 600, 16 * 60];

// getBeijingDateStr - the Beijing date (UTC+8) of a timestamp, as YYYY-MM-DD.
function getBeijingDateStr(ms) {
    var date = new Date(ms + 8 * HOUR_MS);
    var year = date.getUTCFullYear();
    var month = String(date.getUTCMonth() + 1).padStart(2, "0");
    var day = String(date.getUTCDate()).padStart(2, "0");
    return year + "-" + month + "-" + day;
}

// weekdayOf - weekday of a YYYY-MM-DD string (0 = Sunday).
function weekdayOf(dateStr) {
    var parts = dateStr.split("-");
    return new Date(Date.UTC(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))).getUTCDay();
}

// isPeakDay - true on weekdays, false on holidays; weekends only as makeup workdays.
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

// getStatus - the tariff state at a timestamp, together with the reason for it.
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

// getNextChange - the next switch to the other tariff, up to 30 days ahead.
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