// Renders the images in assets/ from the widget's own views, off-screen and
// without plasmashell. Run it through tools/render-images.sh: that script
// stages a throwaway tree, swaps i18n() for the stub and starts this file with
// the output folder as working directory.
//
// The instant is fixed (Wed 2026-01-14, 08:47 UTC), so the timeline always
// shows the peak -> off-peak -> peak sequence of a working day.
//
// Every shot is rendered at twice its logical size and the floating surfaces
// cast a soft shadow, so the images read like screenshots on a HiDPI display.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../contents/code/calendar.js" as Calendar
import "../../contents/code/duration.js" as Duration
import "../../contents/code/palette.js" as Palette
import "../../contents/code/schedule.js" as Schedule
import "../../contents/ui" as Ui

Item {
    id: scene

    // Large enough for every shot; the empty space is off-screen.
    width: 1400
    height: 2000

    readonly property double nowMs: Date.UTC(2026, 0, 14, 8, 47, 0)
    // One entry marks the settings as configured; the far-off date leaves the
    // rendered window untouched.
    readonly property var calendarData: Calendar.parseCalendar("2026-12-25=holiday")
    readonly property var scheduleOptions: ({ treatWeekendWorkdayAsPeak: false })
    readonly property var currentStatus: Schedule.getStatus(nowMs, calendarData, scheduleOptions)
    readonly property var nextChange: Schedule.getNextChange(nowMs, calendarData, scheduleOptions)
    readonly property bool nextChangeFound: nextChange.ms !== null
    readonly property double remainingMs: nextChangeFound ? Math.max(0, nextChange.ms - nowMs) : 0
    readonly property string remainingText: nextChangeFound
        ? formatDuration(remainingMs)
        : "No change found in 30 days"
    readonly property bool coverageNotice: calendarData.configured
        && !(currentStatus.calendarCovered && nextChange.calendarCovered)

    // The widget as it looks on the author's desktop: the Plasma colour scheme
    // "Breeze Dark" resolved exactly like main.qml does for the "system" theme
    // (window background, text and the positive/negative text colours, plus the
    // text colour at 18 % for the border). Keeps the images close to the real
    // thing instead of a bundled palette the user does not run.
    readonly property var breezeDark: Palette.systemTheme(
        "#202326", "#fcfcfc", "#27ae60", "#da4453", "#2efcfcfc")
    // Plasma draws the panel tooltip, not the applet: these are the
    // [Colors:Tooltip] values of the same scheme.
    readonly property color tooltipBackground: "#292c30"
    readonly property color tooltipForeground: "#fcfcfc"
    readonly property color tooltipSubText: "#cfd3d6"

    // Geometry of the mock tooltip: the inner padding, the gap between its two
    // lines and the margin to the edge of the wallpaper frame. The card itself is
    // not pinned to one width - it is measured from its text (see the panel shot),
    // because the real tooltip is only as wide as its content too.
    readonly property int tooltipPadding: 13
    readonly property int tooltipLineGap: 5
    readonly property int panelEdgeMargin: 16
    readonly property int panelBarGap: 12
    // Width of the wallpaper frame in both panel shots: as wide as the widest
    // demo tooltip needs, and the same for both examples so the two README images
    // line up. Rendering fails if a card no longer fits (see the job timer).
    readonly property int panelShotWidth: 352

    readonly property string usageUrl: "https://platform.deepseek.com/usage"
    // Fixed like the instant, so the images do not depend on a real account.
    readonly property string balanceText: "12.34 USD"

    // Off-peak example: same day at 11:17 UTC, between the two peak windows.
    readonly property double offPeakMs: Date.UTC(2026, 0, 14, 11, 17, 0)
    readonly property var offPeakStatus: Schedule.getStatus(offPeakMs, calendarData, scheduleOptions)
    readonly property var offPeakChange: Schedule.getNextChange(offPeakMs, calendarData, scheduleOptions)

    // One panel example per state, each with its own tooltip.
    readonly property var panelExamples: [
        {
            name: "panel-off-peak",
            isPeak: false,
            toolTip: toolTipText(offPeakMs, offPeakStatus, offPeakChange)
        },
        {
            name: "panel-peak",
            isPeak: true,
            toolTip: toolTipText(nowMs, currentStatus, nextChange)
        }
    ]

    // Every shot is rendered at this multiple of its logical size: the README
    // pins the logical width, so the images stay crisp on a HiDPI display.
    readonly property real shotScale: 2

    // Stand-in for the desktop behind the floating surfaces: a dark blue-grey
    // in the tone of the Breeze Dark wallpaper, so the surfaces read against it
    // without a bright halo, and the same in every shot.
    component Wallpaper: Rectangle {
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#17232f" }
            GradientStop { position: 0.5; color: "#101821" }
            GradientStop { position: 1.0; color: "#080c11" }
        }
    }

    // Soft drop shadow without QtQuick.Effects: nested rounded rectangles with
    // falling opacity approximate the edge Plasma draws around the tooltip and
    // the cards. Because it sits behind the surface, the text stays crisp.
    component DropShadow: Item {
        id: shadow

        property real spread: 14
        property real corner: 8

        Repeater {
            model: 8

            Rectangle {
                anchors.centerIn: parent
                width: shadow.width + 2 * shadow.spread * (index + 1) / 8
                height: shadow.height + 2 * shadow.spread * (index + 1) / 8
                radius: shadow.corner + shadow.spread * (index + 1) / 8
                color: Qt.rgba(0, 0, 0, 0.07)
            }
        }
    }

    // Relative: the caller sets the target folder as working directory.
    property string targetDir: "."
    property var jobs: []
    property int jobIndex: 0
    property int failures: 0

    // Same wording as main.qml, joined directly (no i18n() outside plasmashell).
    // Keep formatDuration() and toolTipText() in sync with main.qml by hand:
    // these images render the strings, but no test compares them with the applet.
    function formatDuration(milliseconds) {
        var parts = Duration.splitDuration(milliseconds);
        if (parts.days > 0) {
            return parts.days + " d " + parts.hours + " h";
        }
        if (parts.hours > 0) {
            return parts.hours + " h " + parts.minutes + " min";
        }
        if (parts.minutes > 0) {
            return parts.minutes + " min " + parts.seconds + " s";
        }
        return parts.seconds + " s";
    }

    // Mirrors toolTipSubText in main.qml: state, remaining time, balance.
    function toolTipText(ms, status, change) {
        var label = status.isPeak ? "Peak" : "Off-peak";
        var base = change.ms === null
            ? label
            : label + " \u00b7 " + formatDuration(Math.max(0, change.ms - ms)) + " left";
        return base + " \u00b7 Balance: " + balanceText;
    }

    // Writes one image per job; grabbing the item alone skips the empty space.
    function grabNext() {
        if (jobIndex >= jobs.length) {
            console.log(failures === 0
                ? "RENDER OK (" + jobs.length + " images)"
                : "RENDER FAILED (" + failures + " of " + jobs.length + " images)");
            Qt.quit();
            return;
        }
        var job = jobs[jobIndex];
        jobIndex += 1;
        // Render at shotScale so the text stays crisp when the README shows the
        // image at its logical width on a HiDPI display.
        var target = Qt.size(Math.round(job.item.width * scene.shotScale),
                             Math.round(job.item.height * scene.shotScale));
        job.item.grabToImage(function (result) {
            if (result.saveToFile(scene.targetDir + "/" + job.name + ".png") === false) {
                scene.failures += 1;
                console.error("could not write " + job.name + ".png");
            } else {
                console.log("wrote " + job.name + ".png");
            }
            scene.grabNext();
        }, target);
    }

    Column {
        x: 20
        y: 20
        spacing: 24

        // 1) Panel indicator: one example per state, dot plus the tooltip that
        //    appears on hover. The shell window cannot be rendered off-screen,
        //    so the two lines from main.qml are drawn here instead.
        Repeater {
            id: panelShots
            model: scene.panelExamples

            delegate: Item {
                id: panelExample

                required property var modelData

                // Width the card needs: the wider of its two lines plus the
                // padding on both sides. A real Plasma tooltip grows and shrinks
                // with its text, so a long line keeps the same inner margin as a
                // short one instead of running into the frame.
                readonly property int tooltipWidth: 2 * scene.tooltipPadding
                    + Math.ceil(Math.max(tooltipTitle.implicitWidth, tooltipSubtext.implicitWidth))

                // Wallpaper frame, no empty panel area: the same width for both
                // examples, so the two README images line up.
                width: scene.panelShotWidth
                height: scene.panelEdgeMargin + tooltipBox.height + scene.panelBarGap + panelBar.height

                // Square and full-bleed: rounded corners leave transparent (then
                // black) edges in the README.
                Wallpaper {
                    anchors.fill: parent
                }

                // Panel bar: full width, flush with the bottom edge, like a real
                // taskbar - near-black, slightly translucent, light top edge.
                Rectangle {
                    id: panelBar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 44
                    color: Qt.rgba(0.086, 0.094, 0.102, 0.97)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.06)
                    }
                }

                // Only the dot belongs to WhalePeak; near the right edge, as on
                // screen.
                Ui.CompactView {
                    id: panelDot
                    x: panelExample.width - 104
                    anchors.verticalCenter: panelBar.verticalCenter
                    isVertical: false
                    isPeak: panelExample.modelData.isPeak
                    usageUrl: scene.usageUrl
                    theme: scene.breezeDark
                }

                // Shadow with the geometry of the tooltip - Plasma draws one
                // around the real popup.
                DropShadow {
                    x: tooltipBox.x
                    y: tooltipBox.y
                    width: tooltipBox.width
                    height: tooltipBox.height
                    corner: tooltipBox.radius
                }

                // Tooltip box above the panel: the opaque grey of the Breeze
                // Dark tooltip, with its fine lighter frame. Width and height come
                // from the content plus the padding (panelExample.tooltipWidth),
                // so both lines keep the same margin on every side.
                Rectangle {
                    id: tooltipBox
                    x: panelExample.width - width - scene.panelEdgeMargin
                    y: scene.panelEdgeMargin
                    width: panelExample.tooltipWidth
                    height: tooltipColumn.implicitHeight + 2 * scene.tooltipPadding
                    radius: 6
                    color: scene.tooltipBackground
                    border.width: 1
                    border.color: "#3b4147"

                    Column {
                        id: tooltipColumn
                        anchors.fill: parent
                        anchors.margins: scene.tooltipPadding
                        spacing: scene.tooltipLineGap

                        Label {
                            id: tooltipTitle
                            text: "WhalePeak"
                            color: scene.tooltipForeground
                            font.pointSize: 12
                            font.weight: Font.DemiBold
                        }

                        Label {
                            id: tooltipSubtext
                            text: panelExample.modelData.toolTip
                            color: scene.tooltipSubText
                            font.pointSize: 10
                        }
                    }
                }
            }
        }

        // 2) Detail view, "combined": status, next change, balance, timeline.
        //    The glass card needs a background - the wallpaper stands in.
        Item {
            id: combinedShot
            width: 392
            height: combined.height + 32

            // Square and opaque, see the note in shot 1.
            Wallpaper {
                anchors.fill: parent
            }

            // The card floats over the wallpaper, so it casts a soft shadow.
            DropShadow {
                anchors.fill: combined
                corner: 10
                spread: 16
            }

            Ui.FullView {
                id: combined
                anchors.centerIn: parent
                width: 360
                height: implicitHeight
                timestamp: scene.nowMs
                currentStatus: scene.currentStatus
                coverageNotice: scene.coverageNotice
                nextChange: scene.nextChange
                remainingText: scene.remainingText
                displayMode: "combined"
                backgroundStyle: "glass"
                glassOpacity: 55
                calendarData: scene.calendarData
                scheduleOptions: scene.scheduleOptions
                balanceEnabled: true
                balanceState: "ok"
                balanceUnavailable: false
                balanceText: scene.balanceText
                theme: scene.breezeDark
            }
        }

        // 3) The same window as timeline only, in a second palette.
        Item {
            id: timelineShot
            width: 392
            height: timelineOnly.height + 32

            // Square and opaque, see the note in shot 1.
            Wallpaper {
                anchors.fill: parent
            }

            // The solid card floats over the wallpaper, so it casts a shadow.
            DropShadow {
                anchors.fill: timelineOnly
                corner: 10
                spread: 16
            }

            Ui.FullView {
                id: timelineOnly
                anchors.centerIn: parent
                width: 360
                height: implicitHeight
                timestamp: scene.nowMs
                currentStatus: scene.currentStatus
                coverageNotice: scene.coverageNotice
                nextChange: scene.nextChange
                remainingText: scene.remainingText
                displayMode: "timeline"
                backgroundStyle: "solid"
                glassOpacity: 55
                calendarData: scene.calendarData
                scheduleOptions: scene.scheduleOptions
                balanceEnabled: false
                balanceState: "idle"
                balanceUnavailable: false
                balanceText: ""
                theme: scene.breezeDark
            }
        }

        // 4) One strip per bundled palette; the script joins them into
        //    assets/themes.png.
        Grid {
            columns: 3
            spacing: 12

            Repeater {
                id: themeStrips
                model: Palette.themeNames()

                delegate: Item {
                    id: strip

                    required property string modelData
                    readonly property var stripTheme: Palette.resolveTheme(modelData)

                    width: 432
                    height: 104

                    // Square and opaque, see the note in shot 1.
                    Rectangle {
                        anchors.fill: parent
                        color: strip.stripTheme.background
                        border.width: 1
                        border.color: strip.stripTheme.border
                    }

                    Label {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 12
                        text: Palette.displayName(strip.modelData)
                        color: strip.stripTheme.foreground
                        font.pointSize: 10
                        font.weight: Font.DemiBold
                    }

                    Ui.Timeline {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 12
                        // Follows the timeline: bar, gap and label row scale with
                        // the desktop font (see Timeline.qml).
                        height: implicitHeight
                        timestamp: scene.nowMs
                        calendarData: scene.calendarData
                        scheduleOptions: scene.scheduleOptions
                        theme: strip.stripTheme
                    }
                }
            }
        }
    }

    // Grab only after the first frame, once layouts are distributed (as in
    // tests/fixtures/timeline-probe.qml).
    Timer {
        interval: 200
        running: true
        repeat: false
        onTriggered: {
            scene.jobs = [];
            for (var p = 0; p < scene.panelExamples.length; p += 1) {
                var shot = panelShots.itemAt(p);
                // The card is content-sized; if a demo text ever grows past the
                // wallpaper frame, fail here instead of writing an image whose text
                // runs into the frame (a real tooltip would simply grow wider).
                var needed = shot.tooltipWidth + 2 * scene.panelEdgeMargin;
                if (needed > scene.panelShotWidth) {
                    scene.failures += 1;
                    console.error("tooltip " + shot.modelData.name + " needs " + needed
                        + " px, but the frame is only " + scene.panelShotWidth + " px wide");
                } else {
                    console.log("tooltip " + shot.modelData.name + ": " + shot.tooltipWidth
                        + " px wide (frame " + scene.panelShotWidth + " px)");
                }
                scene.jobs.push({
                    name: shot.modelData.name,
                    item: shot
                });
            }
            scene.jobs.push({ name: "detail-combined", item: combinedShot });
            scene.jobs.push({ name: "detail-timeline", item: timelineShot });
            var names = Palette.themeNames();
            for (var i = 0; i < names.length; i += 1) {
                // Leading number keeps the order for the script's sorted glob.
                scene.jobs.push({
                    name: "theme-" + (i + 1) + "-" + names[i],
                    item: themeStrips.itemAt(i)
                });
            }
            scene.grabNext();
        }
    }
}
