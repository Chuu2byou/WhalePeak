// Shape reference for the schedule contract. The values are deliberately
// trivial; tests/test_schedule.js only checks that every documented field is
// present with the documented type.
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

// Covers the documented exception: no transition within the search horizon.
function getNextChange(ms, cal, opts) {
    return {
        ms: null,
        toPeak: null,
        calendarCovered: true
    };
}