.pragma library

// Parses the user maintained holiday/workday list from the applet
// configuration. Pure data, deliberately without a Qt, QML or i18n dependency,
// so the same code can run under `node --test`.

var LINE_PATTERN = /^(\d{4}-\d{2}-\d{2})=(holiday|workday)$/;

// Checks that "YYYY-MM-DD" names a real calendar day; the pattern alone would
// also accept 2026-13-01 or February 30. The UTC round trip additionally rules
// out invalid leap days (2028-02-29 yes, 2027-02-29 no).
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

// One line per entry: "YYYY-MM-DD=holiday" or "YYYY-MM-DD=workday". Blank lines
// and lines starting with "#" are comments. Unmatched lines are ignored but
// reported with their line number, so typos are visible.
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
        // An entry with an impossible date would never match, so it counts as a
        // typo and is reported instead of being swallowed silently.
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
        // Without custom entries only the base rule applies (weekdays are peak).
        // Only then is an incomplete calendar worth a notice.
        configured: holidays.size + workdays.size > 0
    };
}
