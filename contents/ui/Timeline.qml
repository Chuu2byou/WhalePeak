// Timeline.qml - the 24-hour peak/off-peak bar with its hour labels.
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
    required property var theme

    readonly property color textColor: root.theme.foreground
    readonly property color positiveColor: root.theme.positive
    readonly property color negativeColor: root.theme.negative

    readonly property int barHeight: 24
    readonly property int gap: Kirigami.Units.smallSpacing
    readonly property int tickHeight: Math.ceil(tickMetrics.height)

    implicitHeight: root.barHeight + root.gap + root.tickHeight

    property int designWidth: 18 * Kirigami.Units.gridUnit

    implicitWidth: root.designWidth

    FontMetrics {
        id: tickMetrics

        font.pointSize: 8
    }

    Accessible.role: Accessible.Indicator
    Accessible.name: i18n("Peak and off-peak timeline for the next 24 hours")

    readonly property int windowHours: TimelineWindow.WINDOW_HOURS

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

            clip: true

            Repeater {
                model: root.segments

                delegate: Rectangle {
                    required property var modelData

                    readonly property var cell: TimelineWindow.cellRect(modelData.ms, root.timestamp, root.windowHours, segmentRow.width)

                    x: cell.x
                    width: cell.width
                    height: segmentRow.height
                    radius: width > 4 ? 2 : 0
                    color: modelData.isPeak
                        ? root.negativeColor
                        : root.positiveColor
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.tickHeight

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