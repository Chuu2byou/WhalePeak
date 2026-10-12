// main.qml - the plasmoid: schedule state, balance fetching and the two views.
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import "../code/balance.js" as Balance
import "../code/calendar.js" as Calendar
import "../code/duration.js" as Duration
import "../code/palette.js" as Palette
import "../code/schedule.js" as Schedule

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    property double nowMs: Date.now()
    readonly property var calendarData: Calendar.parseCalendar(plasmoid.configuration.customHolidays)
    readonly property var scheduleOptions: ({
        treatWeekendWorkdayAsPeak: plasmoid.configuration.treatWeekendWorkdayAsPeak
    })
    // Keep these as bindings; assigning them in a handler would break updates.
    readonly property var currentStatus: Schedule.getStatus(nowMs, calendarData, scheduleOptions)
    readonly property double nextChangeKeyMs: Math.floor(nowMs / (60 * 60 * 1000)) * (60 * 60 * 1000)
    readonly property var nextChange: Schedule.getNextChange(nextChangeKeyMs, calendarData, scheduleOptions)
    readonly property bool nextChangeFound: nextChange.ms !== null
    readonly property double remainingMs: nextChangeFound ? Math.max(0, nextChange.ms - nowMs) : 0
    readonly property string remainingText: nextChangeFound
        ? Duration.formatDuration(remainingMs, translateText)
        : i18n("No change found in 30 days")
    readonly property bool forecastCovered: currentStatus.calendarCovered && nextChange.calendarCovered
    readonly property bool coverageNotice: calendarData.configured && !forecastCovered

    readonly property int glassOpacity: Palette.clampOpacityPercent(
        plasmoid.configuration.glassOpacity)
    readonly property var activeTheme: {
        var theme = Palette.resolveTheme(plasmoid.configuration.visualTheme);
        if (theme !== null) {
            return theme;
        }
        return Palette.systemTheme(
            Kirigami.Theme.backgroundColor,
            Kirigami.Theme.textColor,
            Kirigami.Theme.positiveTextColor,
            Kirigami.Theme.negativeTextColor,
            Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                Kirigami.Theme.textColor.b, 0.18));
    }

    readonly property string usageUrl: "https://platform.deepseek.com/usage"
    readonly property string balanceApiUrl: Balance.BALANCE_API_URL
    readonly property bool balanceEnabled: plasmoid.configuration.showBalance
    property string balanceState: "idle"
    property var balanceEntry: null
    property bool balanceUnavailable: false
    property string balancePhase: ""
    property double lastBalanceFetchMs: 0
    property bool walletBusy: false
    property int balanceRequestId: 0
    property var balanceRequest: null
    readonly property int walletTimeoutMs: Balance.WALLET_TIMEOUT_MS
    readonly property int balanceRetryIntervalMs: 15000
    readonly property string balanceText: balanceEntry !== null
        ? balanceEntry.totalBalance + " " + balanceEntry.currency
        : ""

    readonly property string statusText: currentStatus.isPeak ? i18n("Peak") : i18n("Off-peak")
    readonly property bool balanceShown: balanceEnabled && balanceState === "ok" && balanceEntry !== null
    toolTipSubText: Duration.tooltipSubText(statusText,
        nextChangeFound ? remainingText : "",
        balanceShown ? balanceText : "",
        translateText)

    compactRepresentation: CompactView {
        isVertical: root.Plasmoid.formFactor === PlasmaCore.Types.Vertical
        isPeak: root.currentStatus.isPeak
        usageUrl: root.usageUrl
        theme: root.activeTheme
        onHovered: root.maybeRefreshBalanceOnHover()
        onExpandRequested: root.expandFromCompact()
    }

    fullRepresentation: FullView {
        id: fullView
        readonly property string activeDisplayMode: ["combined", "status", "timeline"].indexOf(plasmoid.configuration.displayMode) >= 0
            ? plasmoid.configuration.displayMode : "combined"
        // Reapply the implicit size to override stale popup dimensions saved by Plasma.
        Layout.minimumWidth: fullView.implicitWidth
        Layout.maximumWidth: fullView.implicitWidth
        Layout.preferredWidth: fullView.implicitWidth
        Layout.minimumHeight: fullView.implicitHeight
        Layout.maximumHeight: fullView.implicitHeight
        Layout.preferredHeight: fullView.implicitHeight
        currentStatus: root.currentStatus
        coverageNotice: root.coverageNotice
        nextChange: root.nextChange
        remainingText: root.remainingText
        timestamp: root.nowMs
        displayMode: fullView.activeDisplayMode
        backgroundStyle: plasmoid.configuration.backgroundStyle
        glassOpacity: root.glassOpacity
        theme: root.activeTheme
        calendarData: root.calendarData
        scheduleOptions: root.scheduleOptions
        balanceEnabled: root.balanceEnabled
        balanceState: root.balanceState
        balanceUnavailable: root.balanceUnavailable
        balanceText: root.balanceText
        onBalanceRefreshRequested: root.refreshBalance()
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Open DeepSeek usage page")
            icon.name: "internet-services"
            onTriggered: Qt.openUrlExternally(root.usageUrl)
        },
        PlasmaCore.Action {
            text: i18n("Show details")
            icon.name: "view-visible"
            onTriggered: root.expandFromContextMenu()
        }
    ]

    P5Support.DataSource {
        id: walletSource
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            if (data["exit code"] === undefined) {
                return;
            }
            root.walletBusy = false;
            walletSource.disconnectSource(sourceName);
            var key = data["exit code"] === 0 ? String(data.stdout || "").trim() : "";
            if (key.length === 0) {
                walletTimeout.stop();
                root.balanceEntry = null;
                root.balanceState = "keyError";
                return;
            }
            root.fetchBalance(key);
        }
    }

    // One deadline covers both the wallet read and HTTP request.
    Timer {
        id: walletTimeout
        interval: root.walletTimeoutMs
        repeat: false

        onTriggered: {
            root.balanceRequestId += 1;
            root.abortWalletRead();
            root.walletBusy = false;
            root.balanceEntry = null;
            root.balanceUnavailable = false;
            root.balanceState = root.balancePhase === "http" ? "httpTimeout" : "timeout";
        }
    }

    Timer {
        id: startupBalanceTimer
        interval: 10000
        repeat: false

        onTriggered: {
            if (root.balanceState === "idle") {
                root.refreshBalance();
            }
        }
    }

    Component.onCompleted: {
        if (root.balanceEnabled) {
            startupBalanceTimer.start();
        }
    }

    onExpandedChanged: {
        if (Plasmoid.expanded) {
            refreshBalance();
        }
    }

    Connections {
        target: plasmoid.configuration

        function onShowBalanceChanged() {
            if (plasmoid.configuration.showBalance) {
                root.lastBalanceFetchMs = 0;
                Qt.callLater(root.refreshBalance);
                return;
            }
            root.abortWalletRead();
            walletTimeout.stop();
            root.walletBusy = false;
            root.balanceEntry = null;
            root.balanceUnavailable = false;
            root.balanceState = "idle";
        }

        function onWalletNameChanged() {
            root.reloadBalanceConfiguration();
        }

        function onWalletFolderChanged() {
            root.reloadBalanceConfiguration();
        }

        function onWalletEntryChanged() {
            root.reloadBalanceConfiguration();
        }
    }

    Timer {
        interval: root.Plasmoid.expanded ? 1000 : 15000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.nowMs = Date.now()
    }

    function maybeRefreshBalanceOnHover() {
        if (!balanceEnabled || balanceState === "ok" || walletBusy) {
            return;
        }
        if (Date.now() - lastBalanceFetchMs < balanceRetryIntervalMs) {
            return;
        }
        refreshBalance();
    }

    function expandFromCompact() {
        root.expanded = !root.expanded;
    }

    // Delay expansion until Plasma's context menu releases its input grab.
    function expandFromContextMenu() {
        expandDelay.restart();
    }

    Timer {
        id: expandDelay
        interval: 100
        repeat: false
        onTriggered: root.expandFromCompact()
    }

    function reloadBalanceConfiguration() {
        if (walletBusy) {
            abortWalletRead();
            walletBusy = false;
        }
        walletTimeout.stop();
        lastBalanceFetchMs = 0;
        Qt.callLater(refreshBalance);
    }

    // Invalidate the chain before aborting so late responses are ignored.
    function abortWalletRead() {
        balanceRequestId += 1;
        if (balanceRequest !== null) {
            balanceRequest.abort();
            balanceRequest = null;
        }
        var sources = walletSource.connectedSources;
        for (var i = sources.length - 1; i >= 0; i -= 1) {
            walletSource.disconnectSource(sources[i]);
        }
    }

    function refreshBalance() {
        if (!balanceEnabled || walletBusy) {
            return;
        }
        walletBusy = true;
        balanceState = "loading";
        balancePhase = "wallet";
        balanceUnavailable = false;
        lastBalanceFetchMs = Date.now();
        balanceRequestId += 1;
        walletTimeout.restart();
        walletSource.connectSource(Balance.readKeyCommand(
            plasmoid.configuration.walletName,
            plasmoid.configuration.walletFolder,
            plasmoid.configuration.walletEntry));
    }

    // Keep the API key out of the applet configuration.
    function fetchBalance(apiKey) {
        // Ignore responses from earlier requests.
        var requestId = balanceRequestId;
        balancePhase = "http";
        var xhr = new XMLHttpRequest();
        xhr.open("GET", balanceApiUrl);
        xhr.setRequestHeader("Authorization", "Bearer " + apiKey);
        xhr.setRequestHeader("Accept", "application/json");
        root.balanceRequest = xhr;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            root.balanceRequest = null;
            applyBalanceResult(Balance.parseBalance(xhr.status, xhr.responseText), requestId);
        };
        xhr.onerror = function () {
            root.balanceRequest = null;
            applyBalanceResult(Balance.parseBalance(0, ""), requestId);
        };
        xhr.send();
    }

    function applyBalanceResult(result, requestId) {
        if (requestId !== balanceRequestId) {
            return;
        }
        walletTimeout.stop();
        var entry = Balance.selectBalanceEntry(result.entries);
        balanceEntry = entry;
        // Availability is independent of whether a balance is returned.
        balanceUnavailable = result.state === "ok" && !result.isAvailable;
        balanceState = (result.state === "ok" && entry === null) ? "empty" : result.state;
    }

    // Expose QML's i18n() to the shared formatter.
    function translateText(text, first, second) {
        return i18n(text, first, second);
    }
}