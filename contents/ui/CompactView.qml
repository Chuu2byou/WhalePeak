import QtQuick
import org.kde.kirigami as Kirigami

// Compact representation in the panel: only the status dot. The remaining time
// sits in the panel tooltip and in the expanded window.
Item {
    id: root

    required property bool isVertical
    required property bool isPeak
    // Target of the left click on the status dot.
    required property string usageUrl
    // Resolved colours (see main.qml): positive = off-peak, negative = peak.
    required property var theme

    // The applet reacts to both: the hover is the moment the tooltip (the only
    // place the balance appears without expanding) is needed, the middle click is
    // the second way to the detail view. The left click stays on the usage page.
    signal hovered()
    signal expandRequested()

    // Size of the status dot, like a small icon: the detail view uses the same
    // value, so the state is shown at the same size in the panel and in the card.
    readonly property int dotSize: Kirigami.Units.iconSizes.small
    // Space needed: dot plus panel margin, so nothing cuts into the neighbours.
    // Unlike the card the panel has a fixed row height, so these two numbers are
    // deliberately hard-coded panel metrics, not theme-scaled units.
    readonly property int compactWidth: dotSize + (isVertical ? 12 : 16)
    readonly property int compactHeight: isVertical ? 58 : 30
    implicitWidth: compactWidth
    implicitHeight: compactHeight
    clip: true

    // For assistive tools: the dot is the only indicator, so it carries the status
    // as its name and the activation opens the same page as the click.
    Accessible.role: Accessible.Button
    Accessible.name: root.isPeak ? i18n("DeepSeek: peak hours") : i18n("DeepSeek: off-peak")
    Accessible.description: i18n("Opens the DeepSeek usage page")
    Accessible.onPressAction: Qt.openUrlExternally(root.usageUrl)

    // Tooltip and expanded window carry the text; the panel shows only the dot, so
    // the applet does not stick out into its neighbours.
    Rectangle {
        anchors.centerIn: parent
        width: root.dotSize
        height: root.dotSize
        radius: width / 2
        color: root.isPeak ? root.theme.negative : root.theme.positive
    }

    // The left click on the dot opens the DeepSeek usage page; the middle click
    // asks the applet to expand, so the detail view is reachable with a single
    // click too. Right clicks stay untouched (acceptedButtons), so the Plasma
    // context menu still appears; the hover feeds the balance refresh in main.qml.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered()
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton) {
                root.expandRequested();
                return;
            }
            Qt.openUrlExternally(root.usageUrl);
        }
    }

}
