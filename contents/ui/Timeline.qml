import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../code/schedule.js" as Schedule
import "../code/timeline.js" as TimelineWindow

Item {
    id: root

    required property double timestamp
    required property var calendarData
    required property var scheduleOptions
    // Resolved colours (see main.qml): positive = off-peak, negative = peak.
    required property var theme

    readonly property color textColor: root.theme.foreground
    readonly property color positiveColor: root.theme.positive
    readonly property color negativeColor: root.theme.negative

    // Bar plus gap plus the measured height of the tick labels. The labels are
    // taken from the same font as the delegates below (FontMetrics), so the row
    // can no longer end up one pixel short: it grows with the desktop font. Kept
    // tight, so no blank space appears below the timeline in the popup; if the
    // space still grows, the bar row takes the rest.
    readonly property int barHeight: 24
    readonly property int gap: Kirigami.Units.smallSpacing
    readonly property int tickHeight: Math.ceil(tickMetrics.height)

    implicitHeight: root.barHeight + root.gap + root.tickHeight

    // Width the timeline is laid out for. FullView passes the card's real content
    // width (360 - 2 * gridUnit); the theme strips and the probe set their own
    // width anyway. The default approximates that content width for the default
    // gridUnit (18 px: 360 - 2 * 18 = 324 = 18 * gridUnit), so the row never
    // claims more width than the card offers - it used to claim 400 px.
    property int designWidth: 18 * Kirigami.Units.gridUnit

    implicitWidth: root.designWidth

    // One place for the label font: the delegates and the row height both read
    // it, so they cannot drift apart.
    FontMetrics {
        id: tickMetrics

        font.pointSize: 8
    }

    // For assistive tools: the timeline is purely graphical and otherwise unreadable.
    Accessible.role: Accessible.Indicator
    Accessible.name: i18n("Peak and off-peak timeline for the next 24 hours")

    // Visible window: "now" at the left edge, then that many hours.
    readonly property int windowHours: TimelineWindow.WINDOW_HOURS

    // Only the start of the hour determines the cells and their tariff
    // classification; within the hour the current instant only moves the x
    // positions. That way the segments are not rebuilt on every tick (1 s).
    readonly property double segmentKeyMs: TimelineWindow.floorToHourMs(timestamp)
    readonly property var segments: {
        var starts = TimelineWindow.cellStarts(segmentKeyMs, windowHours);
        var result = [];
        for (var i = 0; i < starts.length; i++) {
            result.push({
                ms: starts[i],
                isPeak: Schedule.getStatus(starts[i], calendarData, scheduleOptions).isPeak
            });
        }
        return result;
    }
    readonly property var ticks: TimelineWindow.tickStarts(segmentKeyMs, windowHours, TimelineWindow.STEP_HOURS)

    ColumnLayout {
        anchors.fill: parent
        spacing: root.gap

        Item {
            id: segmentRow

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: root.barHeight

            // Clipped edge cells must not stick out beyond the row.
            clip: true

            Repeater {
                model: root.segments

                delegate: Rectangle {
                    required property var modelData

                    // Absolute position and width: the window starts at "now" on
                    // the left, the cells keep sliding left with every tick.
                    readonly property var cell: TimelineWindow.cellRect(modelData.ms, root.timestamp, root.windowHours, segmentRow.width)

                    x: cell.x
                    width: cell.width
                    height: segmentRow.height
                    // Very narrow clipped cells would look like a hole in the row
                    // with a radius.
                    radius: width > 4 ? 2 : 0
                    // Fully opaque: the colours from main.qml already hold the
                    // contrast and luminance distance. An extra opacity (formerly
                    // peak 0.8, off-peak 0.34) pushed the off-peak contrast below
                    // the 3:1 threshold in every theme.
                    color: modelData.isPeak
                        ? root.negativeColor
                        : root.positiveColor
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.tickHeight

            // Absolute clock times on the hour grid, at their real position in the
            // window: they slide leftwards out of the bar over time.
            Repeater {
                model: root.ticks

                delegate: Text {
                    required property double modelData

                    color: root.textColor
                    font: tickMetrics.font
                    text: TimelineWindow.labelFor(modelData)
                    x: Math.max(0, Math.min(parent.width - width, parent.width * TimelineWindow.fractionOf(modelData, root.timestamp, root.windowHours) - width / 2))
                }
            }
        }
    }

}