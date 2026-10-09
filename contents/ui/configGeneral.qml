import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as P5Support
import "../code/balance.js" as Balance
import "../code/calendar.js" as Calendar
import "../code/palette.js" as Palette

// KCM.SimpleKCM is a Kirigami.ScrollablePage: the settings dialog may be dragged
// smaller or narrower than its content, then a scroll bar appears instead of
// clipped fields.
KCM.SimpleKCM {
    id: page

    property alias cfg_displayMode: displayMode.currentValue
    property alias cfg_backgroundStyle: backgroundStyle.currentValue
    property alias cfg_glassOpacity: glassOpacity.value
    property alias cfg_visualTheme: visualTheme.currentValue
    property alias cfg_treatWeekendWorkdayAsPeak: treatWeekendWorkdayAsPeak.checked
    property alias cfg_customHolidays: customHolidays.text
    property alias cfg_showBalance: showBalance.checked
    property alias cfg_walletName: walletName.text
    property alias cfg_walletFolder: walletFolder.text
    property alias cfg_walletEntry: walletEntry.text

    // Ablaufzustand: "" | "writing" | "reading" | "checking" | "ok"
    // | "invalid" | "network" | "apiError" | "writeError" | "readError"
    // | "timeout"
    property string keyState: ""
    // Balance from the check ("12.34 USD") or "" when none was reported.
    property string keyBalance: ""
    // HTTP status of the check, only for the error message.
    property int keyHttpStatus: 0
    // Distinguishes "stored and verified" from "verified only".
    property bool keyJustStored: false
    // The running check request, so the timeout really aborts it.
    property var verifyRequest: null
    // Safety net against a hanging kwallet-query (KWallet password dialog).
    // Shared with the widget via balance.js; must match main.qml.
    readonly property int keyTimeoutMs: Balance.WALLET_TIMEOUT_MS
    // Same endpoint as the widget, from balance.js (see main.qml).
    readonly property string balanceApiUrl: Balance.BALANCE_API_URL

    readonly property bool keyBusy: keyState === "writing"
        || keyState === "reading" || keyState === "checking"
    readonly property bool canStore: showBalance.checked && !keyBusy
        && Balance.normalizeKey(apiKey.text).length > 0

    // Live evaluation of the text field, so typos show up immediately.
    readonly property var parsedCalendar: Calendar.parseCalendar(customHolidays.text)

    // Picker list of the colour themes: "system" is translated, the theme names
    // are proper nouns and stay untranslated.
    readonly property var themeModel: {
        var list = [{ "text": i18n("Use Plasma color scheme"), "value": "system" }];
        var names = Palette.themeNames();
        for (var i = 0; i < names.length; i += 1) {
            list.push({ "text": Palette.displayName(names[i]), "value": names[i] });
        }
        return list;
    }
    // Preview of the colours of the selected theme; null means "system". The
    // derived off-peak/peak values, so the fields show what the card really
    // paints.
    readonly property var themePreview: Palette.resolveTheme(visualTheme.currentValue)
    // The same derivation for the Plasma colour scheme. The border is dimmed from
    // the text tone as in main.qml, so the preview shows five fields here too and
    // the field count does not change when switching.
    readonly property var systemPreview: Palette.systemTheme(
        Kirigami.Theme.backgroundColor,
        Kirigami.Theme.textColor,
        Kirigami.Theme.positiveTextColor,
        Kirigami.Theme.negativeTextColor,
        Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
            Kirigami.Theme.textColor.b, 0.18))

    // From here on all visible fields sit in the FormLayout of the scrollable
    // page; functions, timers and data sources stay at page level.
    Kirigami.FormLayout {
        ComboBox {
            id: displayMode
            Kirigami.FormData.label: i18n("Display mode")
            textRole: "text"
            valueRole: "value"
            model: [
                { "text": i18n("Combined"), "value": "combined" },
                { "text": i18n("Status line only"), "value": "status" },
                { "text": i18n("Timeline only"), "value": "timeline" }
            ]
        }

        ComboBox {
            id: backgroundStyle
            Kirigami.FormData.label: i18n("Background")
            textRole: "text"
            valueRole: "value"
            model: [
                { "text": i18n("Glass"), "value": "glass" },
                { "text": i18n("Solid"), "value": "solid" },
                { "text": i18n("Transparent"), "value": "transparent" }
            ]
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.7
            font.pointSize: 9
            text: i18n("Glass paints a translucent surface of its own with rounded corners. Solid paints the same surface fully opaque. Transparent draws no card of its own, so the shell's popup background shows through and the text can be hard to read.")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Glass opacity")
            Layout.fillWidth: true
            visible: backgroundStyle.currentValue === "glass"

            Slider {
                id: glassOpacity
                Layout.fillWidth: true
                from: 0
                to: 100
                stepSize: 5
            }

            Label {
                text: i18n("%1 %", Math.round(glassOpacity.value))
                opacity: 0.7
                font.pointSize: 9
            }
        }

        Label {
            Layout.fillWidth: true
            visible: backgroundStyle.currentValue === "glass" && glassOpacity.value < 35
            wrapMode: Text.WordWrap
            opacity: 0.7
            font.pointSize: 9
            text: i18n("Below 35 percent the text can become hard to read over a busy wallpaper.")
        }

        ComboBox {
            id: visualTheme
            Kirigami.FormData.label: i18n("Color theme")
            textRole: "text"
            valueRole: "value"
            model: page.themeModel
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Preview")
            spacing: 4

            // Always five colour fields: surface, text, off-peak, peak and border.
            // With "system" the values come from the Plasma colour scheme.
            Repeater {
                model: {
                    var shown = page.themePreview === null ? page.systemPreview : page.themePreview;
                    return [shown.background, shown.foreground, shown.positive,
                        shown.negative, shown.border];
                }

                delegate: Rectangle {
                    required property color modelData
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    radius: 4
                    color: modelData
                    border.width: 1
                    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                        Kirigami.Theme.textColor.b, 0.2)
                }
            }
        }

        Label {
            Layout.fillWidth: true
            visible: page.themePreview === null
            wrapMode: Text.WordWrap
            opacity: 0.7
            font.pointSize: 9
            text: i18n("The Plasma color scheme follows the system, so the widget keeps matching your desktop colors.")
        }

        CheckBox {
            id: treatWeekendWorkdayAsPeak
            text: i18n("Treat weekend makeup workdays as peak")
        }

        Label {
            Layout.fillWidth: true
            visible: treatWeekendWorkdayAsPeak.checked
            wrapMode: Text.WordWrap
            opacity: 0.7
            font.pointSize: 9
            text: i18n("User override, not a DeepSeek rule: officially every weekend is off-peak. Weekend dates only count as peak when they are listed below.")
        }

        Label {
            Kirigami.FormData.isSection: true
            text: i18n("Calendar")
        }

        TextArea {
            id: customHolidays
            Kirigami.FormData.label: i18n("Holidays / workdays")
            implicitWidth: 300
            implicitHeight: 120
            // Grows with the dialog width, so wider windows do not lock the date
            // lines into a 300 px wide box. Wrapping instead of clipping keeps a
            // long comment line visible; the short date lines are unaffected.
            Layout.fillWidth: true
            wrapMode: TextEdit.Wrap
            placeholderText: i18n("One entry per line:\n2026-10-01=holiday\n2026-10-10=workday\nLines starting with # are comments.")
        }

        Label {
            Layout.fillWidth: true
            visible: page.parsedCalendar.invalidLines.length > 0
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.negativeTextColor
            font.pointSize: 9
            text: i18np("%1 line ignored: expected YYYY-MM-DD=holiday or YYYY-MM-DD=workday.",
                        "%1 lines ignored: expected YYYY-MM-DD=holiday or YYYY-MM-DD=workday.",
                        page.parsedCalendar.invalidLines.length)
        }

        Label {
            Layout.fillWidth: true
            visible: customHolidays.text.length === 0
            wrapMode: Text.WordWrap
            opacity: 0.7
            font.pointSize: 9
            text: i18n("Without entries only the base rule applies: weekdays are peak during the peak windows, weekends and holidays are off-peak. Chinese public holidays are not bundled.")
        }

        Label {
            Kirigami.FormData.isSection: true
            text: i18n("Remaining balance")
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            opacity: 0.7
            font.pointSize: 9
            text: i18n("DeepSeek provides no API for consumed tokens or costs, so the widget can only show the remaining balance from /user/balance. The key is stored in KWallet with kwallet-query — never in the widget configuration — and is verified with DeepSeek right after saving.")
        }

        CheckBox {
            id: showBalance
            text: i18n("Show remaining balance")
        }

        // Pure show/hide helper: wallet, folder and entry stay in the
        // configuration (the defaults fit almost always) but only appear when
        // someone really wants to change them.
        CheckBox {
            id: advancedToggle
            text: i18n("Change wallet, folder or entry")
            enabled: showBalance.checked
        }

        Label {
            Layout.fillWidth: true
            visible: advancedToggle.checked && showBalance.checked
            wrapMode: Text.WordWrap
            opacity: 0.7
            font.pointSize: 9
            text: i18n("The defaults fit most setups: kdewallet / DeepSeek / api_key. kwallet-query creates the folder and the entry on the first save.")
        }

        TextField {
            id: walletName
            Kirigami.FormData.label: i18n("Wallet")
            enabled: showBalance.checked
            visible: advancedToggle.checked
            implicitWidth: 200
        }

        TextField {
            id: walletFolder
            Kirigami.FormData.label: i18n("Folder")
            enabled: showBalance.checked
            visible: advancedToggle.checked
            implicitWidth: 200
        }

        TextField {
            id: walletEntry
            Kirigami.FormData.label: i18n("Entry")
            enabled: showBalance.checked
            visible: advancedToggle.checked
            implicitWidth: 200
        }

        RowLayout {
            Kirigami.FormData.label: i18n("API key")

            TextField {
                id: apiKey
                enabled: showBalance.checked && !page.keyBusy
                echoMode: TextInput.Password
                placeholderText: i18n("sk-…")
                implicitWidth: 240
                // Enter stores, so the mouse is not required.
                onAccepted: page.storeApiKey()
            }

            Button {
                text: i18n("Save to wallet")
                enabled: page.canStore
                onClicked: page.storeApiKey()
            }

            ToolButton {
                display: ToolButton.IconOnly
                icon.name: "view-refresh"
                enabled: showBalance.checked && !page.keyBusy
                onClicked: page.checkStoredKey()
                ToolTip.text: i18n("Read the stored key and verify it with DeepSeek")
                ToolTip.visible: hovered
            }
        }

        Label {
            Layout.fillWidth: true
            visible: page.keyState !== ""
            wrapMode: Text.WordWrap
            color: page.keyStateColor()
            font.pointSize: 9
            text: page.keyStateText()
        }
    }

    // Deliberately no call when the page opens: kwallet-query can trigger the
    // KWallet password dialog, and nobody who only wants to change the display
    // mode should see that. The check runs on click - and this timer aborts a
    // hanging call instead of leaving the page stuck.
    //
    // Like the widget's walletTimeout it is a single deadline for the whole chain
    // (write, read and HTTP check), so it is started once at the beginning and
    // deliberately not restarted between the phases.
    Timer {
        id: keyTimeout
        interval: page.keyTimeoutMs
        repeat: false

        onTriggered: {
            // The state first, so a late answer from the aborted process no
            // longer changes anything.
            page.keyState = "timeout";
            page.abortKeyCheck();
        }
    }

    // Message for all states in one place. The texts stay in QML, because i18n()
    // is not available in a .pragma-library JS.
    function keyStateText() {
        switch (page.keyState) {
        case "writing":
            return i18n("Writing the key to KWallet…");
        case "reading":
            return i18n("Reading the key back from KWallet…");
        case "checking":
            return i18n("Verifying the key with DeepSeek…");
        case "ok":
            if (page.keyBalance.length > 0) {
                return page.keyJustStored
                    ? i18n("Key stored and verified. Balance: %1", page.keyBalance)
                    : i18n("Key verified. Balance: %1", page.keyBalance);
            }
            return page.keyJustStored
                ? i18n("Key stored and verified. DeepSeek reported no balance.")
                : i18n("Key verified. DeepSeek reported no balance.");
        case "invalid":
            return i18n("DeepSeek rejected the key (HTTP %1). Check that the key is correct and active.", page.keyHttpStatus);
        case "network":
            return page.keyJustStored
                ? i18n("Key stored, but DeepSeek could not be reached.")
                : i18n("DeepSeek could not be reached.");
        case "apiError":
            return page.keyJustStored
                ? i18n("Key stored, but DeepSeek returned an error (HTTP %1).", page.keyHttpStatus)
                : i18n("DeepSeek returned an error (HTTP %1).", page.keyHttpStatus);
        case "writeError":
            return i18n("Could not write the key. Is kwallet-query installed and the wallet unlocked?");
        case "readError":
            return i18n("The key could not be read back from KWallet. Check wallet, folder and entry under \"Change wallet, folder or entry\".");
        case "timeout":
            return i18n("No answer within %1 seconds. If KWallet is locked, unlock it and try again.",
                Math.round(page.keyTimeoutMs / 1000));
        default:
            return "";
        }
    }

    function keyStateColor() {
        if (page.keyState === "ok") {
            return Kirigami.Theme.positiveTextColor;
        }
        if (page.keyState === "invalid" || page.keyState === "apiError"
                || page.keyState === "writeError" || page.keyState === "readError") {
            return Kirigami.Theme.negativeTextColor;
        }
        if (page.keyState === "network" || page.keyState === "timeout") {
            return Kirigami.Theme.neutralTextColor;
        }
        return Kirigami.Theme.textColor;
    }

    // Aborts running calls, so neither process nor request is left behind:
    // first the HTTP check, then the kwallet-query calls.
    function abortKeyCheck() {
        if (page.verifyRequest !== null) {
            page.verifyRequest.abort();
            page.verifyRequest = null;
        }
        var reader = walletReader.connectedSources;
        for (var i = reader.length - 1; i >= 0; i -= 1) {
            walletReader.disconnectSource(reader[i]);
        }
        var writer = walletWriter.connectedSources;
        for (var j = writer.length - 1; j >= 0; j -= 1) {
            walletWriter.disconnectSource(writer[j]);
        }
    }

    // Stores the pasted key and verifies it automatically afterwards.
    function storeApiKey() {
        if (!page.canStore) {
            return;
        }
        page.keyBalance = "";
        page.keyHttpStatus = 0;
        page.keyJustStored = true;
        page.keyState = "writing";
        keyTimeout.restart();
        walletWriter.connectSource(Balance.writeKeyCommand(
            page.cfg_walletName,
            page.cfg_walletFolder,
            page.cfg_walletEntry,
            Balance.normalizeKey(apiKey.text)));
    }

    // Checks the key already stored in KWallet without writing it again.
    function checkStoredKey() {
        if (!showBalance.checked || page.keyBusy) {
            return;
        }
        page.keyBalance = "";
        page.keyHttpStatus = 0;
        page.keyJustStored = false;
        page.keyState = "reading";
        keyTimeout.restart();
        walletReader.connectSource(Balance.readKeyCommand(
            page.cfg_walletName,
            page.cfg_walletFolder,
            page.cfg_walletEntry));
    }

    // Does the check via XMLHttpRequest, so no external tool such as curl is
    // required - the same path as in main.qml.
    function verifyKey(key) {
        page.keyState = "checking";
        var xhr = new XMLHttpRequest();
        page.verifyRequest = xhr;
        xhr.open("GET", page.balanceApiUrl);
        xhr.setRequestHeader("Authorization", "Bearer " + key);
        xhr.setRequestHeader("Accept", "application/json");
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            page.verifyRequest = null;
            page.applyVerifyResult(Balance.parseBalance(xhr.status, xhr.responseText));
        };
        // Network failures give status 0; parseBalance turns that into "error".
        xhr.onerror = function () {
            page.verifyRequest = null;
            page.applyVerifyResult(Balance.parseBalance(0, ""));
        };
        xhr.send();
    }

    function applyVerifyResult(result) {
        if (page.keyState !== "checking") {
            return;
        }
        keyTimeout.stop();
        page.keyHttpStatus = result.httpStatus;
        if (result.state === "ok") {
            var entry = Balance.selectBalanceEntry(result.entries);
            page.keyBalance = entry !== null
                ? entry.totalBalance + " " + entry.currency
                : "";
            page.keyState = "ok";
            // Only clear now: the key is verified in KWallet. On an error the
            // field stays, so it can be corrected.
            apiKey.text = "";
            return;
        }
        if (result.state === "unauthorized") {
            page.keyState = "invalid";
            return;
        }
        page.keyState = result.httpStatus === 0 ? "network" : "apiError";
    }

    // Writes the key to KWallet via the shell; kwallet-query reads it from stdin,
    // hence the printf part from Balance.writeKeyCommand. The exit code 0 only
    // says that something was written - only reading it back proves that exactly
    // the entry main.qml will later read is reachable.
    P5Support.DataSource {
        id: walletWriter
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            if (data["exit code"] === undefined) {
                return;
            }
            walletWriter.disconnectSource(sourceName);
            if (page.keyState !== "writing") {
                return;
            }
            if (data["exit code"] !== 0) {
                keyTimeout.stop();
                page.keyState = "writeError";
                return;
            }
            page.keyState = "reading";
            walletReader.connectSource(Balance.readKeyCommand(
                page.cfg_walletName,
                page.cfg_walletFolder,
                page.cfg_walletEntry));
        }
    }

    P5Support.DataSource {
        id: walletReader
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            if (data["exit code"] === undefined) {
                return;
            }
            walletReader.disconnectSource(sourceName);
            if (page.keyState !== "reading") {
                return;
            }
            var key = data["exit code"] === 0 ? String(data.stdout || "").trim() : "";
            if (key.length === 0) {
                // Wallet missing or locked, folder/entry unknown or empty.
                keyTimeout.stop();
                page.keyState = "readError";
                return;
            }
            page.verifyKey(key);
        }
    }
}