const assert = require("node:assert/strict");
const test = require("node:test");

const { loadQmlLibrary, plain } = require("./helpers/qml_library.js");

const calendar = loadQmlLibrary("contents/code/calendar.js", ["parseCalendar"]);

test("empty input yields an empty, unconfigured calendar", () => {
    const parsed = calendar.parseCalendar("");

    assert.equal(parsed.holidays.size, 0);
    assert.equal(parsed.workdays.size, 0);
    assert.deepEqual([...parsed.coveredYears], []);
    assert.deepEqual(plain(parsed.invalidLines), []);
    assert.equal(parsed.configured, false);
});

test("missing and whitespace-only input is handled", () => {
    assert.equal(calendar.parseCalendar(undefined).configured, false);
    assert.equal(calendar.parseCalendar(null).configured, false);
    assert.equal(calendar.parseCalendar("  \n\t\n").configured, false);
});

test("comments and blank lines are skipped", () => {
    const parsed = calendar.parseCalendar("# Kopf\n\n   # Kommentar\n2026-10-01=holiday\n");

    assert.deepEqual([...parsed.holidays], ["2026-10-01"]);
    assert.deepEqual(plain(parsed.invalidLines), []);
    assert.equal(parsed.configured, true);
});

test("holidays and workdays stay separate and derive the covered years", () => {
    const parsed = calendar.parseCalendar(
        "2026-10-01=holiday\n2027-02-05=workday\n2027-02-06=holiday\n"
    );

    assert.deepEqual([...parsed.holidays].sort(), ["2026-10-01", "2027-02-06"]);
    assert.deepEqual([...parsed.workdays], ["2027-02-05"]);
    assert.deepEqual([...parsed.coveredYears], [2026, 2027]);
    assert.equal(parsed.configured, true);
});

test("invalid lines are ignored but reported with their line number", () => {
    const parsed = calendar.parseCalendar(
        "2026-10-01=holiday\n2026-1-1=holiday\n2000-01-01\nkaputt\n"
    );

    assert.deepEqual(plain(parsed.invalidLines), [
        { line: 2, text: "2026-1-1=holiday" },
        { line: 3, text: "2000-01-01" },
        { line: 4, text: "kaputt" }
    ]);
    assert.deepEqual([...parsed.holidays], ["2026-10-01"]);
});

test("surrounding whitespace is trimmed and duplicates collapse", () => {
    const parsed = calendar.parseCalendar("  2026-10-01=holiday  \n2026-10-01=holiday\n");

    assert.equal(parsed.holidays.size, 1);
    assert.deepEqual([...parsed.coveredYears], [2026]);
});

test("impossible dates are reported instead of silently never matching", () => {
    const parsed = calendar.parseCalendar(
        "2026-02-30=holiday\n2026-13-01=holiday\n2027-02-29=workday\n2028-02-29=holiday\n"
    );

    assert.deepEqual(plain(parsed.invalidLines), [
        { line: 1, text: "2026-02-30=holiday" },
        { line: 2, text: "2026-13-01=holiday" },
        { line: 3, text: "2027-02-29=workday" }
    ]);
    // The 2028 leap day stays valid and still counts towards the covered year.
    assert.deepEqual([...parsed.holidays], ["2028-02-29"]);
    assert.equal(parsed.workdays.size, 0);
    assert.deepEqual([...parsed.coveredYears], [2028]);
    assert.equal(parsed.configured, true);
});
