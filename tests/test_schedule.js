const assert = require("node:assert/strict");
const test = require("node:test");

const { loadQmlLibrary } = require("./helpers/qml_library.js");

const apiNames = ["getBeijingDateStr", "isPeakDay", "getStatus", "getNextChange"];
const schedule = loadQmlLibrary("contents/code/schedule.js", apiNames);
const stub = loadQmlLibrary("tests/fixtures/schedule.stub.js", apiNames);

function calendar({ holidays = [], workdays = [], coveredYears = [2026] } = {}) {
    return {
        holidays: new Set(holidays),
        workdays: new Set(workdays),
        coveredYears
    };
}

const REASONS = ["weekday", "weekend", "holiday", "makeupWorkday", "offWindow"];

const weekdayPeak = Date.UTC(2026, 9, 6, 2);
const weekdayOffWindow = Date.UTC(2026, 9, 6, 5);
const defaultOptions = { treatWeekendWorkdayAsPeak: false };

// Checks the documented shape, not a concrete value. The fixed field count is
// intentional: an extra field is a contract change and should show up here
// instead of slipping through silently.
function assertStatusShape(status) {
    assert.equal(Object.keys(status).length, 4);
    assert.equal(typeof status.isPeak, "boolean");
    assert.equal(typeof status.holidayToday, "boolean");
    assert.equal(typeof status.calendarCovered, "boolean");
    assert.ok(REASONS.includes(status.reason), `unexpected reason: ${status.reason}`);
}

function assertChangeShape(change) {
    assert.equal(Object.keys(change).length, 3);
    assert.equal(typeof change.calendarCovered, "boolean");
    if (change.ms === null) {
        assert.equal(change.toPeak, null);
        return;
    }
    assert.equal(typeof change.ms, "number");
    assert.equal(typeof change.toPeak, "boolean");
}

test("Beijing date rolls over at 16:00 UTC", () => {
    assert.equal(schedule.getBeijingDateStr(Date.UTC(2026, 11, 31, 15, 59)), "2026-12-31");
    assert.equal(schedule.getBeijingDateStr(Date.UTC(2026, 11, 31, 16, 0)), "2027-01-01");
});

test("weekday peak windows use UTC minutes", () => {
    const cal = calendar();
    assert.equal(schedule.getStatus(weekdayPeak, cal, defaultOptions).isPeak, true);
    assert.equal(schedule.getStatus(weekdayOffWindow, cal, defaultOptions).isPeak, false);
    assert.equal(schedule.getStatus(Date.UTC(2026, 9, 9, 10), cal, defaultOptions).isPeak, false);
});

test("weekend makeup workday obeys the option and holiday wins", () => {
    const makeupDate = "2026-10-10";
    const makeupCal = calendar({ workdays: [makeupDate] });
    const saturdayPeakWindow = Date.UTC(2026, 9, 10, 2);

    assert.equal(schedule.getStatus(saturdayPeakWindow, makeupCal, defaultOptions).isPeak, false);
    assert.equal(schedule.getStatus(saturdayPeakWindow, makeupCal, { treatWeekendWorkdayAsPeak: true }).isPeak, true);

    const holidayCal = calendar({ holidays: ["2026-10-06"] });
    const holidayStatus = schedule.getStatus(weekdayPeak, holidayCal, { treatWeekendWorkdayAsPeak: true });
    assert.equal(holidayStatus.isPeak, false);
    assert.equal(holidayStatus.holidayToday, true);
    assert.equal(holidayStatus.reason, "holiday");
});

test("calendar coverage uses Beijing year and next-change scans its full horizon", () => {
    const cal = calendar({ coveredYears: [2026] });
    const beforeBeijingNewYear = Date.UTC(2026, 11, 31, 15, 30);
    const status = schedule.getStatus(beforeBeijingNewYear, cal, defaultOptions);
    const nextChange = schedule.getNextChange(beforeBeijingNewYear, cal, defaultOptions);

    assert.equal(status.calendarCovered, true);
    assert.notEqual(nextChange.ms, null);
    assert.equal(nextChange.toPeak, true);
    assert.equal(nextChange.calendarCovered, false);
});

test("next change finds the first transition across date classifications", () => {
    const start = Date.UTC(2026, 9, 8, 3, 30);
    const cal = calendar({ holidays: ["2026-10-08", "2026-10-09"] });
    const nextChange = schedule.getNextChange(start, cal, defaultOptions);

    assert.equal(nextChange.ms, Date.UTC(2026, 9, 12, 1));
    assert.equal(nextChange.toPeak, true);
});

test("peak windows start inclusive and end exclusive", () => {
    const cal = calendar();
    const tuesday = Date.UTC(2026, 9, 6); // 2026-10-06 is a Tuesday
    const at = (minutes) => schedule.getStatus(tuesday + minutes * 60 * 1000, cal, defaultOptions).isPeak;

    assert.equal(at(59), false);
    assert.equal(at(60), true);
    assert.equal(at(239), true);
    assert.equal(at(240), false);
    assert.equal(at(360), true);
    assert.equal(at(600), false);
});

test("next change reports the transition back to off-peak", () => {
    const cal = calendar();
    const insidePeak = Date.UTC(2026, 9, 6, 2, 0); // Tuesday, inside the first window
    const nextChange = schedule.getNextChange(insidePeak, cal, defaultOptions);

    assert.equal(nextChange.ms, Date.UTC(2026, 9, 6, 4, 0));
    assert.equal(nextChange.toPeak, false);
});

test("reports no transition without losing the scanned coverage", () => {
    const holidays = [];
    for (let day = 0; day <= 31; day++) {
        holidays.push(schedule.getBeijingDateStr(weekdayPeak + day * 24 * 60 * 60 * 1000));
    }
    const cal = calendar({ holidays });
    const nextChange = schedule.getNextChange(weekdayPeak, cal, defaultOptions);

    assert.equal(nextChange.ms, null);
    assert.equal(nextChange.toPeak, null);
    assert.equal(nextChange.calendarCovered, true);
});

test("reason names the classification that decided the status", () => {
    const cal = calendar({ holidays: ["2026-10-06"], workdays: ["2026-10-10"] });

    assert.equal(schedule.getStatus(Date.UTC(2026, 9, 6, 2), cal, defaultOptions).reason, "holiday");
    assert.equal(schedule.getStatus(Date.UTC(2026, 9, 7, 2), cal, defaultOptions).reason, "weekday");
    assert.equal(schedule.getStatus(Date.UTC(2026, 9, 7, 5), cal, defaultOptions).reason, "offWindow");
    assert.equal(schedule.getStatus(Date.UTC(2026, 9, 10, 2), cal, defaultOptions).reason, "weekend");
    assert.equal(
        schedule.getStatus(Date.UTC(2026, 9, 10, 2), cal, { treatWeekendWorkdayAsPeak: true }).reason,
        "makeupWorkday"
    );
});

test("a calendar without covered years reports uncovered but still finds changes", () => {
    const uncovered = calendar({ coveredYears: [] });
    const status = schedule.getStatus(weekdayPeak, uncovered, defaultOptions);
    const nextChange = schedule.getNextChange(weekdayPeak, uncovered, defaultOptions);

    assert.equal(status.calendarCovered, false);
    assert.equal(nextChange.calendarCovered, false);
    // The base rule applies regardless of the calendar, the next change stays.
    assert.equal(status.isPeak, true);
    assert.notEqual(nextChange.ms, null);
});

test("stub and implementation both satisfy the documented contract shape", () => {
    const cal = calendar({
        holidays: ["2026-10-06"],
        workdays: ["2026-10-10"],
        coveredYears: [2026]
    });
    const probes = [
        Date.UTC(2026, 9, 6, 0, 30),
        Date.UTC(2026, 9, 6, 2),
        Date.UTC(2026, 9, 6, 5),
        Date.UTC(2026, 9, 10, 2),
        Date.UTC(2026, 9, 11, 3),
        Date.UTC(2026, 11, 31, 23, 30)
    ];

    for (const implementation of [schedule, stub]) {
        for (const probe of probes) {
            assertStatusShape(implementation.getStatus(probe, cal, defaultOptions));
            assertChangeShape(implementation.getNextChange(probe, cal, defaultOptions));
        }
    }
});
