// Minimal contract stub used by test_schedule.js.
function getBeijingDateStr(ms) {
    return "2000-01-01";
}

function isPeakDay(dateStr, cal, opts) {
    return false;
}

function getStatus(ms, cal, opts) {
    return {
        isPeak: false,
        holidayToday: false,
        calendarCovered: true,
        reason: "offWindow"
    };
}

function getNextChange(ms, cal, opts) {
    return {
        ms: null,
        toPeak: null,
        calendarCovered: true
    };
}