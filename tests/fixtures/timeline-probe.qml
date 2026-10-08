// Probe harness for the timeline: renders contents/ui/Timeline.qml without
// plasmashell (off-screen) and checks the measured geometry against
// contents/code/timeline.js and the cell colours against contents/code/schedule.js.
//
// Do not run it directly, use tools/probe-timeline.sh: the script creates a
// throwaway copy in which contents/ sits next to tests/ - only there do the
// relative imports fit. It additionally replaces i18n(), which does not exist
// outside plasmashell.
import QtQuick
import "../../contents/ui" as Ui
import "../../contents/code/timeline.js" as TimelineWindow
import "../../contents/code/schedule.js" as Schedule

Item {
    id: probeRoot

    // Fixed reference row as in tests/test_timeline.js: the timeline has to cope
    // with exactly this size and must not depend on its own implicit size.
    width: 400
    height: 43

    // How calendar and options look in the applet, just without user data.
    readonly property var calendarData: ({ holidays: new Set(), workdays: new Set(), coveredYears: [2026] })
    readonly property var scheduleOptions: ({ treatWeekendWorkdayAsPeak: false })
    readonly property var theme: ({
        background: "#1c1c1c",
        foreground: "#ffffff",
        positive: "#2f9e44",
        negative: "#e03131",
        border: "#ffffff"
    })

    property double nowMs: 0
    property int failures: 0
    property int checks: 0

    Ui.Timeline {
        id: timeline

        anchors.fill: parent
        timestamp: probeRoot.nowMs
        calendarData: probeRoot.calendarData
        scheduleOptions: probeRoot.scheduleOptions
        theme: probeRoot.theme
    }

    // Measure only after the first frame: before that the layout has not yet
    // distributed the widths.
    Timer {
        interval: 50
        repeat: false
        running: true
        onTriggered: {
            probeRoot.run();
            console.log(probeRoot.failures === 0
                ? "PROBE OK (" + probeRoot.checks + " checks)"
                : "PROBE FAILED (" + probeRoot.failures + " of " + probeRoot.checks + " checks)");
            Qt.quit();
        }
    }

    function check(message, ok) {
        probeRoot.checks += 1;
        if (!ok) {
            probeRoot.failures += 1;
            console.log("PROBE FAIL " + message);
        }
    }

    function near(message, actual, expected) {
        probeRoot.checks += 1;
        if (!(Math.abs(actual - expected) <= 0.01)) {
            probeRoot.failures += 1;
            console.log("PROBE FAIL " + message + ": " + Number(actual).toFixed(4)
                + " instead of " + Number(expected).toFixed(4));
        }
    }

    function collect(node, out) {
        var kids = node.children;
        if (!kids) {
            return out;
        }
        for (var i = 0; i < kids.length; i++) {
            out.push(kids[i]);
            collect(kids[i], out);
        }
        return out;
    }

    // Re-render the timeline and collect the drawn rectangles and texts. The
    // order is left to right, so the model order. The values are copied and not
    // kept as references: otherwise two snapshots would read the same, already
    // updated state of the QML items and every shift would be null.
    function render(nowMs) {
        probeRoot.nowMs = nowMs;

        // The timeline paints both tariffs fully opaque (see Timeline.qml), so the
        // tariff sits in the drawn colour and no longer in the opacity: peak takes
        // negative, off-peak positive.
        var peakColor = String(probeRoot.theme.negative);
        var all = collect(timeline, []);
        var cells = [];
        var labels = [];
        var width = 0;
        for (var i = 0; i < all.length; i++) {
            if (typeof all[i].radius === "number") {
                cells.push({ x: all[i].x, width: all[i].width, peak: String(all[i].color) === peakColor });
                width = all[i].parent.width;
            } else if (typeof all[i].text === "string") {
                labels.push({ x: all[i].x, width: all[i].width, text: all[i].text });
            }
        }

        cells.sort(function (a, b) { return a.x - b.x; });
        labels.sort(function (a, b) { return a.x - b.x; });

        return { cells: cells, labels: labels, width: width };
    }

    function run() {
        slide();
        verify("Thu 08.10. 13:30", new Date(2026, 9, 8, 13, 30).getTime());
        verify("Thu 08.10. 00:00", new Date(2026, 9, 8, 0, 0).getTime());
        verify("Thu 08.10. 23:59", new Date(2026, 9, 8, 23, 59).getTime());
        verify("Mon 12.10. 06:15", new Date(2026, 9, 12, 6, 15).getTime());
        verify("Sun 11.10. 09:00", new Date(2026, 9, 11, 9, 0).getTime());
    }

    function verify(label, nowMs) {
        var span = TimelineWindow.WINDOW_HOURS;
        var starts = TimelineWindow.cellStarts(nowMs, span);
        var ticks = TimelineWindow.tickStarts(nowMs, span, TimelineWindow.STEP_HOURS);
        var row = render(nowMs);

        if (row.cells.length !== starts.length) {
            probeRoot.failures += 1;
            console.log("PROBE FAIL " + label + ": " + row.cells.length + " cells instead of " + starts.length);
            return;
        }

        var covered = 0;
        var leftEdge = Infinity;
        var rightEdge = -Infinity;
        var peaks = [];
        for (var i = 0; i < row.cells.length; i++) {
            var rect = TimelineWindow.cellRect(starts[i], nowMs, span, row.width);
            near(label + " cell " + i + " x", row.cells[i].x, rect.x);
            near(label + " cell " + i + " width", row.cells[i].width, rect.width);

            // The cell colour comes from the tariff classification, not the index.
            var isPeak = Schedule.getStatus(starts[i], probeRoot.calendarData, probeRoot.scheduleOptions).isPeak;
            check(label + " cell " + i + " tariff", isPeak === row.cells[i].peak);

            covered += row.cells[i].width;
            leftEdge = Math.min(leftEdge, row.cells[i].x);
            rightEdge = Math.max(rightEdge, row.cells[i].x + row.cells[i].width);
            // List only visible cells: at the end of the window a cell can
            // collapse to zero, but it is still checked.
            if (isPeak && row.cells[i].width > 0.01) {
                peaks.push(TimelineWindow.labelFor(starts[i]));
            }
        }

        // The window starts exactly at "now" and fills the row without gaps.
        near(label + " left edge", leftEdge, 0);
        near(label + " right edge", rightEdge, row.width);
        near(label + " coverage", covered, row.width);

        check(label + " label count", row.labels.length === ticks.length);
        for (i = 0; i < Math.min(row.labels.length, ticks.length); i++) {
            check(label + " label " + i, row.labels[i].text === TimelineWindow.labelFor(ticks[i]));

            // The centre must sit on the hour mark; at the left edge the label is
            // clamped, so it stays readable.
            var half = row.labels[i].width / 2;
            var centred = Math.max(half, Math.min(row.width - half, row.width * TimelineWindow.fractionOf(ticks[i], nowMs, span)));
            near(label + " label " + i + " centre", row.labels[i].x + half, centred);
        }

        var shown = [];
        for (i = 0; i < row.labels.length; i++) {
            shown.push(row.labels[i].text + "@" + Math.round(row.labels[i].x));
        }
        console.log("PROBE " + label
            + " | cells=" + row.cells.length
            + " | remainder=" + (covered - row.width).toFixed(6) + "px"
            + " | first cell=" + Number(row.cells[0].width).toFixed(2) + "px"
            + " | peak hours=" + (peaks.length > 0 ? peaks.join(",") : "none")
            + " | labels=" + shown.join(" "));
    }

    // Within an hour only the x position may shift: the window moves rightwards
    // over the clock, the content slides leftwards.
    function slide() {
        var span = TimelineWindow.WINDOW_HOURS;
        var stepMs = 10 * 60 * 1000;
        var now = new Date(2026, 9, 8, 13, 30).getTime();
        var before = render(now);
        var after = render(now + stepMs);

        check("slide cell count", before.cells.length === after.cells.length);

        var index = Math.floor(before.cells.length / 2);
        var shift = stepMs / (span * 60 * 60 * 1000) * before.width;
        near("slide x shift", before.cells[index].x - after.cells[index].x, shift);
        near("slide width", after.cells[index].width, before.cells[index].width);

        console.log("PROBE slide | " + (stepMs / 60000) + " minutes = " + shift.toFixed(2) + "px");
    }
}
