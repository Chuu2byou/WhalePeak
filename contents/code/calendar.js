.pragma library

// calendar.js - parses the holidays/workdays text field of the settings page.

var LINE_PATTERN = /^(\d{4}-\d{2}-\d{2})=(holiday|workday)$/;

// isRealDate - true only for a date that exists (rejects 2026-02-30).
function isRealDate(dateStr) {
    var parts = dateStr.split("-");
    var year = Number(parts[0]);
    var month = Number(parts[1]);
    var day = Number(parts[2]);
    var date = new Date(Date.UTC(year, month - 1, day));
    return date.getUTCFullYear() === year
        && date.getUTCMonth() === month - 1
        && date.getUTCDate() === day;
}

// parseCalendar - splits the text field into holiday/workday sets and ignored lines.
function parseCalendar(rawText) {
    var holidays = new Set();
    var workdays = new Set();
    var yearsSet = new Set();
    var invalidLines = [];
    var lines = String(rawText === undefined || rawText === null ? "" : rawText).split("\n");

    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (!line || line.charAt(0) === "#") {
            continue;
        }

        var match = line.match(LINE_PATTERN);
        if (!match || !isRealDate(match[1])) {
            invalidLines.push({ line: i + 1, text: line });
            continue;
        }

        yearsSet.add(Number(match[1].slice(0, 4)));
        if (match[2] === "holiday") {
            holidays.add(match[1]);
        } else {
            workdays.add(match[1]);
        }
    }

    var coveredYears = [];
    yearsSet.forEach(function (year) {
        coveredYears.push(year);
    });
    coveredYears.sort(function (a, b) {
        return a - b;
    });

    return {
        holidays: holidays,
        workdays: workdays,
        coveredYears: coveredYears,
        invalidLines: invalidLines,
        configured: holidays.size + workdays.size > 0
    };
}
