// CompactView.qml - the panel item: status dot with hover and expand.
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    required property bool isVertical
    required property bool isPeak
    required property string usageUrl
    required property var theme

    signal hovered()
    signal expandRequested()

    readonly property int dotSize: Kirigami.Units.iconSizes.small
    readonly property int compactWidth: dotSize + (isVertical ? 12 : 16)
    readonly property int compactHeight: isVertical ? 58 : 30
    implicitWidth: compactWidth
    implicitHeight: compactHeight
    clip: true

    Accessible.role: Accessible.Button
    Accessible.name: root.isPeak ? i18n("DeepSeek: peak hours") : i18n("DeepSeek: off-peak")
    Accessible.description: i18n("Shows the peak-hour details")
    Accessible.onPressAction: root.expandRequested()

    Rectangle {
        anchors.centerIn: parent
        width: root.dotSize
        height: root.dotSize
        radius: width / 2
        color: root.isPeak ? root.theme.negative : root.theme.positive
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered()
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                root.expandRequested();
                return;
            }
            Qt.openUrlExternally(root.usageUrl);
        }
    }

}
