import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../contents/code/calendar.js" as Calendar
import "../../contents/code/duration.js" as Duration
import "../../contents/code/palette.js" as Palette
import "../../contents/code/schedule.js" as Schedule
import "../../contents/ui" as Ui

Item {
    id: scene

    width: 1400
    height: 2000

    readonly property double nowMs: Date.UTC(2026, 0, 14, 8, 47, 0)
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

    readonly property var breezeDark: Palette.systemTheme(
        "#202326", "#fcfcfc", "#27ae60", "#da4453", "#2efcfcfc")
    readonly property color tooltipBackground: "#292c30"
    readonly property color tooltipForeground: "#fcfcfc"
    readonly property color tooltipSubText: "#cfd3d6"

    readonly property int tooltipPadding: 13
    readonly property int tooltipLineGap: 5
    readonly property int panelEdgeMargin: 16
    readonly property int panelBarGap: 12
    readonly property int panelShotWidth: 352

    readonly property string usageUrl: "https://platform.deepseek.com/usage"
    readonly property string balanceText: "12.34 USD"

    readonly property double offPeakMs: Date.UTC(2026, 0, 14, 11, 17, 0)
    readonly property var offPeakStatus: Schedule.getStatus(offPeakMs, calendarData, scheduleOptions)
    readonly property var offPeakChange: Schedule.getNextChange(offPeakMs, calendarData, scheduleOptions)

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

    readonly property real shotScale: 2

    component Wallpaper: Rectangle {
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#17232f" }
            GradientStop { position: 0.5; color: "#101821" }
            GradientStop { position: 1.0; color: "#080c11" }
        }
    }

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

    property string targetDir: "."
    property var jobs: []
    property int jobIndex: 0
    property int failures: 0

    function tr(text, first, second) {
        var values = [first, second];
        return String(text).replace(/%([12])/g, function (match, index) {
            var value = values[Number(index) - 1];
            return value === undefined ? match : String(value);
        });
    }

    function formatDuration(milliseconds) {
        return Duration.formatDuration(milliseconds, tr);
    }

    function toolTipText(ms, status, change) {
        var label = status.isPeak ? "Peak" : "Off-peak";
        var remaining = change.ms === null ? "" : formatDuration(Math.max(0, change.ms - ms));
        return Duration.tooltipSubText(label, remaining, balanceText, tr);
    }

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

        Repeater {
            id: panelShots
            model: scene.panelExamples

            delegate: Item {
                id: panelExample

                required property var modelData

                readonly property int tooltipWidth: 2 * scene.tooltipPadding
                    + Math.ceil(Math.max(tooltipTitle.implicitWidth, tooltipSubtext.implicitWidth))

                width: scene.panelShotWidth
                height: scene.panelEdgeMargin + tooltipBox.height + scene.panelBarGap + panelBar.height

                Wallpaper {
                    anchors.fill: parent
                }

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

                Ui.CompactView {
                    id: panelDot
                    x: panelExample.width - 104
                    anchors.verticalCenter: panelBar.verticalCenter
                    isVertical: false
                    isPeak: panelExample.modelData.isPeak
                    usageUrl: scene.usageUrl
                    theme: scene.breezeDark
                }

                DropShadow {
                    x: tooltipBox.x
                    y: tooltipBox.y
                    width: tooltipBox.width
                    height: tooltipBox.height
                    corner: tooltipBox.radius
                }

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

        Item {
            id: combinedShot
            width: 392
            height: combined.height + 32

            Wallpaper {
                anchors.fill: parent
            }

            DropShadow {
                anchors.fill: combined
                corner: Kirigami.Units.cornerRadius !== undefined ? Kirigami.Units.cornerRadius : 10
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

        Item {
            id: timelineShot
            width: 392
            height: timelineOnly.height + 32

            Wallpaper {
                anchors.fill: parent
            }

            DropShadow {
                anchors.fill: timelineOnly
                corner: Kirigami.Units.cornerRadius !== undefined ? Kirigami.Units.cornerRadius : 10
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

    Timer {
        interval: 200
        running: true
        repeat: false
        onTriggered: {
            scene.jobs = [];
            for (var p = 0; p < scene.panelExamples.length; p += 1) {
                var shot = panelShots.itemAt(p);
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
                scene.jobs.push({
                    name: "theme-" + (i + 1) + "-" + names[i],
                    item: themeStrips.itemAt(i)
                });
            }
            scene.grabNext();
        }
    }
}
