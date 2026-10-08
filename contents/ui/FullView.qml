import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: root

    required property var currentStatus
    required property bool coverageNotice
    required property var nextChange
    required property string remainingText
    required property double timestamp
    required property string displayMode
    required property string backgroundStyle
    required property var calendarData
    required property var scheduleOptions
    required property bool balanceEnabled
    required property string balanceState
    // True when DeepSeek flags the account as not usable for API calls
    // (is_available === false); the value is still shown, plus a notice.
    required property bool balanceUnavailable
    required property string balanceText
    // Resolved colours and opacity of the card (see main.qml).
    required property var theme
    required property int glassOpacity

    // The detail view only requests; KWallet and HTTP are known to main.qml.
    signal balanceRefreshRequested()

    readonly property bool showStatus: displayMode !== "timeline"
    readonly property bool showTimeline: displayMode !== "status"

    // Text of the balance row: depending on the state a value or a notice. With
    // "ok" a value is guaranteed, because main.qml reports the valueless case as
    // "empty".
    readonly property string balanceStatusText: {
        if (balanceState === "ok") {
            return i18n("Balance: %1", balanceText);
        }
        if (balanceState === "empty") {
            return i18n("Balance: no balance reported");
        }
        if (balanceState === "loading") {
            return i18n("Balance: loading…");
        }
        if (balanceState === "unauthorized") {
            return i18n("Balance: API key rejected");
        }
        if (balanceState === "keyError") {
            return i18n("Balance: no key in the wallet");
        }
        if (balanceState === "timeout") {
            return i18n("Balance: wallet did not answer");
        }
        if (balanceState === "httpTimeout") {
            return i18n("Balance: request timed out");
        }
        return i18n("Balance: unavailable");
    }

    implicitWidth: 360

    // Width the children get after the padding: the timeline is laid out for
    // exactly this width, so card and content agree (the timeline used to claim
    // 400 px, which the card never gave it).
    readonly property int contentWidth: implicitWidth - contentMargins * 2

    // gridUnit replaces the inner padding the Plasma frame used to provide: it
    // follows the desktop font and is ~18 px with the default font (the comment
    // here used to claim that largeSpacing would be, which is 8 px).
    readonly property int contentMargins: Kirigami.Units.gridUnit

    implicitHeight: content.implicitHeight + contentMargins * 2

    // The widget paints its surface itself, because main.qml disabled the Plasma
    // frame with NoBackground (Plasma frames are either opaque or square). The
    // colours come from the selected theme: "glass" shows the card colour at the
    // configured opacity, "solid" opaque, "transparent" without a surface.
    readonly property color panelColor: root.theme.background
    readonly property color textColor: root.theme.foreground
    readonly property color positiveColor: root.theme.positive
    readonly property color negativeColor: root.theme.negative
    readonly property color borderColor: root.theme.border
    readonly property color glassColor: Qt.rgba(panelColor.r, panelColor.g, panelColor.b,
        root.glassOpacity / 100)
    readonly property color surfaceColor: backgroundStyle === "transparent"
        ? "transparent"
        : backgroundStyle === "glass" ? glassColor : panelColor

    Rectangle {
        anchors.fill: parent
        visible: root.backgroundStyle !== "transparent"
        radius: 10
        color: root.surfaceColor
        // Thin border, so the card stays recognisable as a surface even over a
        // bright wallpaper.
        border.width: root.backgroundStyle === "glass" ? 1 : 0
        border.color: root.borderColor
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.contentMargins
        spacing: Kirigami.Units.mediumSpacing

        RowLayout {
            Layout.fillWidth: true
            visible: root.showStatus
            spacing: Kirigami.Units.largeSpacing

            Rectangle {
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                radius: width / 2
                color: root.currentStatus.isPeak
                    ? root.negativeColor
                    : root.positiveColor
            }

            Label {
                Layout.fillWidth: true
                color: root.textColor
                font.pointSize: 12
                font.weight: Font.DemiBold
                text: root.currentStatus.isPeak ? i18n("Peak") : i18n("Off-peak")
            }

            Label {
                color: root.textColor
                text: root.remainingText
                font.pointSize: 11
                font.weight: Font.DemiBold
            }
        }

        Label {
            Layout.fillWidth: true
            visible: root.showStatus && root.displayMode === "combined"
                && root.nextChange.ms !== null
            color: root.textColor
            opacity: 0.72
            font.pointSize: 9
            text: i18n("Changes at %1", Qt.formatDateTime(new Date(root.nextChange.ms), "ddd HH:mm"))
        }

        // Remaining balance from /user/balance. The value is refreshed only on
        // expanding and on click, hence the button next to it.
        RowLayout {
            Layout.fillWidth: true
            visible: root.balanceEnabled && root.showStatus
            spacing: Kirigami.Units.mediumSpacing

            Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                color: root.textColor
                font.pointSize: 9
                opacity: root.balanceState === "ok" ? 0.85 : 0.6
                text: root.balanceStatusText
            }

            ToolButton {
                display: ToolButton.IconOnly
                icon.name: "view-refresh"
                icon.color: root.textColor
                enabled: root.balanceState !== "loading"
                onClicked: root.balanceRefreshRequested()
                ToolTip.text: i18n("Refresh balance")
                ToolTip.visible: hovered
            }
        }

        // Extra notice when the value is there but the account is not usable for
        // API calls (is_available === false).
        Label {
            Layout.fillWidth: true
            visible: root.showStatus && root.balanceState === "ok" && root.balanceUnavailable
            color: root.textColor
            font.pointSize: 9
            opacity: 0.8
            text: i18n("Account not available for API calls")
        }

        Label {
            Layout.fillWidth: true
            visible: root.displayMode === "combined"
                && (root.coverageNotice || root.currentStatus.holidayToday)
            color: root.textColor
            font.pointSize: 9
            opacity: 0.8
            text: root.coverageNotice
                ? i18n("Calendar coverage incomplete")
                : i18n("Public holiday")
        }

        Timeline {
            Layout.fillWidth: true
            visible: root.showTimeline
            designWidth: root.contentWidth
            timestamp: root.timestamp
            calendarData: root.calendarData
            scheduleOptions: root.scheduleOptions
            theme: root.theme
        }
    }
}