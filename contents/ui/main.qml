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

    // The panel shows only the dot, so the applet itself paints no background.
    // This hint covers the panel representation only: the popup frame is the
    // shell's business (CompactApplet.qml sets the dialog's backgroundHints on
    // its own), which is why FullView paints its card on top of that frame.
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    property double nowMs: Date.now()
    readonly property var calendarData: Calendar.parseCalendar(plasmoid.configuration.customHolidays)
    readonly property var scheduleOptions: ({
        treatWeekendWorkdayAsPeak: plasmoid.configuration.treatWeekendWorkdayAsPeak
    })
    // Pure bindings: nowMs, calendarData and scheduleOptions appear in the
    // expressions, so QML recomputes on every change itself. An extra
    // refreshSchedule() from a handler would overwrite these bindings with a
    // fixed assignment and cut off the refresh.
    readonly property var currentStatus: Schedule.getStatus(nowMs, calendarData, scheduleOptions)
    // Every tariff transition lies on a UTC full hour (see schedule.js), so the
    // next change only has to be recomputed when the UTC hour rolls over - not on
    // every one-second tick. remainingText still counts down from the exact
    // nowMs, so the display keeps ticking within the hour.
    readonly property double nextChangeKeyMs: Math.floor(nowMs / (60 * 60 * 1000)) * (60 * 60 * 1000)
    readonly property var nextChange: Schedule.getNextChange(nextChangeKeyMs, calendarData, scheduleOptions)
    readonly property bool nextChangeFound: nextChange.ms !== null
    readonly property double remainingMs: nextChangeFound ? Math.max(0, nextChange.ms - nowMs) : 0
    readonly property string remainingText: nextChangeFound
        ? Duration.formatDuration(remainingMs, translateText)
        : i18n("No change found in 30 days")
    readonly property bool forecastCovered: currentStatus.calendarCovered && nextChange.calendarCovered
    // Without custom entries only the base rule applies - an incomplete calendar
    // is then not worth a notice, otherwise the warning would be permanent.
    readonly property bool coverageNotice: calendarData.configured && !forecastCovered

    // Appearance: opacity of the glass card (0-100 %) and the colour theme.
    readonly property int glassOpacity: Palette.clampOpacityPercent(
        plasmoid.configuration.glassOpacity)
    // Resolved colours, so the views need no case distinction: either the palette
    // from palette.js or the values of the Plasma colour scheme. Both paths go
    // through resolveThemeColors, so off-peak and peak hold the contrast and
    // luminance thresholds in every theme; the views still read only the five
    // keys.
    readonly property var activeTheme: {
        var theme = Palette.resolveTheme(plasmoid.configuration.visualTheme);
        if (theme !== null) {
            return theme;
        }
        // The palette border is already muted; for the colour scheme the text
        // tone is dimmed for it instead.
        return Palette.systemTheme(
            Kirigami.Theme.backgroundColor,
            Kirigami.Theme.textColor,
            Kirigami.Theme.positiveTextColor,
            Kirigami.Theme.negativeTextColor,
            Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g,
                Kirigami.Theme.textColor.b, 0.18));
    }

    // The panel dot leads to this page. DeepSeek offers no endpoint for consumed
    // usage, so only the web dashboard remains; the remaining balance comes from
    // /user/balance on top.
    readonly property string usageUrl: "https://platform.deepseek.com/usage"
    // Endpoint comes from balance.js, so it cannot drift from the settings dialog.
    readonly property string balanceApiUrl: Balance.BALANCE_API_URL
    readonly property bool balanceEnabled: plasmoid.configuration.showBalance
    // idle | loading | ok | empty | unauthorized | keyError | error | timeout | httpTimeout
    property string balanceState: "idle"
    property var balanceEntry: null
    // True when DeepSeek answers but flags the account as not usable for API
    // calls (is_available === false). The value is still shown, plus a notice.
    property bool balanceUnavailable: false
    // Which phase the running chain sits in: "" | "wallet" | "http". The timeout
    // reports the phase-appropriate message instead of blaming the wallet for a
    // slow HTTP request.
    property string balancePhase: ""
    // Time of the last fetch attempt, successful or not. Throttles the retry on
    // hovering the panel dot, so the tooltip does not touch KWallet on every
    // mouse move.
    property double lastBalanceFetchMs: 0
    // Ensures that only one kwallet-query request runs at a time.
    property bool walletBusy: false
    // Id of the running chain (read the wallet, then fetch the balance). A late
    // answer from an old chain is discarded with it instead of overwriting a
    // newer state.
    property int balanceRequestId: 0
    // The running HTTP request, so the timeout really aborts it and does not just
    // invalidate it - otherwise it would keep running until the answer arrives.
    property var balanceRequest: null
    // Deadline for the whole chain. The value comes from balance.js, so the
    // widget and configGeneral.qml cannot drift; without it a locked wallet would
    // leave everything at "loading" and the button disabled.
    readonly property int walletTimeoutMs: Balance.WALLET_TIMEOUT_MS
    // Minimum distance between two fetch attempts started by hovering the panel
    // dot. Every attempt costs a KWallet access, so the retry stays rare.
    readonly property int balanceRetryIntervalMs: 15000
    readonly property string balanceText: balanceEntry !== null
        ? balanceEntry.totalBalance + " " + balanceEntry.currency
        : ""

    // The panel tooltip (window that shows the applet name as heading) gets the
    // status and the remaining time as its second line, so the time is readable
    // there too - without having to hover exactly and without pinning it.
    readonly property string statusText: currentStatus.isPeak ? i18n("Peak") : i18n("Off-peak")
    readonly property bool balanceShown: balanceEnabled && balanceState === "ok" && balanceEntry !== null
    // Wording lives in duration.js, so the panel tooltip, the render fixture and
    // the tests cannot drift apart.
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
        // The popup is pinned to the card. Plasma's popup remembers its size in
        // the applet configuration (popupWidth/popupHeight) and stops following
        // the content once such a value exists, so the window kept the size of
        // Plasma's placeholder before the first expansion. Only minimum/maximum
        // are reapplied on every content change, hence min == max == implicit
        // size: that also pulls a stale stored size back to the card.
        // FullView.implicitWidth is the single source for the card width.
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

    // A custom compactRepresentation does not expand on its own - per the KDE
    // docs it has to trigger the expansion itself. The left click on the dot and
    // this context menu entry do exactly that; the middle click opens the usage
    // page.
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

    // Reads the API key from KWallet. The executable engine runs through the shell
    // (KProcess::setShellCommand), so Balance.readKeyCommand quotes every value
    // from the configuration. After the result the source is disconnected again,
    // so no persistent process is left behind.
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
                // Wallet missing or locked, entry unknown or key empty.
                walletTimeout.stop();
                root.balanceEntry = null;
                root.balanceState = "keyError";
                return;
            }
            // The deadline keeps running: it covers the HTTP request too.
            root.fetchBalance(key);
        }
    }

    // Safety net against a hanging kwallet-query (KWallet and password dialog) or
    // an HTTP request without an answer. The abort invalidates the running chain,
    // disconnects the source and releases the button again.
    Timer {
        id: walletTimeout
        interval: root.walletTimeoutMs
        repeat: false

        onTriggered: {
            // Invalidate first, so a late answer no longer changes anything.
            root.balanceRequestId += 1;
            root.abortWalletRead();
            root.walletBusy = false;
            root.balanceEntry = null;
            root.balanceUnavailable = false;
            // Report the phase that did not answer: the wallet read and the HTTP
            // request share one deadline.
            root.balanceState = root.balancePhase === "http" ? "httpTimeout" : "timeout";
        }
    }

    // Read once shortly after the start: the panel tooltip should show the
    // remaining balance without the applet being expanded first. The delay keeps
    // the fetch out of the login storm, and the state test prevents a second
    // fetch if the applet was expanded in the meantime.
    //
    // Started explicitly instead of via `running: balanceEnabled`: a one-shot
    // timer clears its own `running` when it fires, which would break such a
    // binding. Enabling the balance later is covered by onShowBalanceChanged().
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

    // Refresh once on expanding, afterwards only on demand via the refresh
    // button. The balance changes slowly, and every fetch costs a KWallet access.
    onExpandedChanged: {
        // Plasmoid.expanded instead of the parameter injection deprecated in Qt 6.
        if (Plasmoid.expanded) {
            refreshBalance();
        }
    }

    // Balance-relevant configuration. Enabling the balance or pointing the widget
    // at another wallet, folder or entry has to take effect right away. Storing
    // the key in the KCM is NOT covered here: that only writes to KWallet and
    // changes no configuration value - the hover retry covers that case.
    Connections {
        target: plasmoid.configuration

        function onShowBalanceChanged() {
            if (plasmoid.configuration.showBalance) {
                // Deferred: the balanceEnabled binding is only guaranteed to be
                // up to date on the next event loop turn, and refreshBalance()
                // reads it.
                root.lastBalanceFetchMs = 0;
                Qt.callLater(root.refreshBalance);
                return;
            }
            // Nothing to show any more: drop the value, so no stale balance stays
            // visible and no request keeps running.
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

    // Only sets the reference instant; status and next change hang off nowMs as
    // bindings and update along with it.
    Timer {
        interval: root.Plasmoid.expanded ? 1000 : 15000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.nowMs = Date.now()
    }

    // Retry path for the panel tooltip. The one-shot fetch 10 s after the start
    // can fail for good (the key is not in the wallet yet, or KWallet is still
    // locked during login), and storing the key in the KCM only writes to KWallet
    // without changing the configuration. Hovering the panel dot is exactly when
    // the tooltip is needed, so the widget retries then - throttled, because
    // every attempt costs a KWallet access. A value that is already there stays
    // untouched: it is refreshed on expanding and on the refresh button.
    function maybeRefreshBalanceOnHover() {
        if (!balanceEnabled || balanceState === "ok" || walletBusy) {
            return;
        }
        if (Date.now() - lastBalanceFetchMs < balanceRetryIntervalMs) {
            return;
        }
        refreshBalance();
    }

    // Expands the applet from the panel. Used by the left click on the dot; set
    // through the root item's own expanded property, the same way Plasma's own
    // applets do it.
    function expandFromCompact() {
        root.expanded = true;
    }

    // "Show details" sits in Plasma's own context menu, and that menu is a window
    // of its own: while its onTriggered runs, the menu still holds mouse and
    // keyboard. Expanding right there opened the popup, and the menu's dismissal
    // deactivated it again in the same instant - the window only flashed. Without
    // another window open, which normally takes over the activation, that happened
    // every time. So the expansion waits until the menu has closed and released
    // the grab; the popup then opens and keeps the focus.
    function expandFromContextMenu() {
        expandDelay.restart();
    }

    Timer {
        id: expandDelay
        // Long enough for the menu window to disappear and the focus change to
        // arrive; the shell waits the same 100 ms before it syncs the popup
        // (expandedSync in CompactApplet.qml).
        interval: 100
        repeat: false
        onTriggered: root.expandFromCompact()
    }

    // A changed wallet, folder or entry makes a running chain pointless: it would
    // still read the old entry. Abort it and read again with the new values.
    function reloadBalanceConfiguration() {
        if (walletBusy) {
            abortWalletRead();
            walletBusy = false;
        }
        walletTimeout.stop();
        lastBalanceFetchMs = 0;
        Qt.callLater(refreshBalance);
    }

    // Aborts a running wallet query, so neither process nor HTTP request is left
    // behind. The request id is bumped first, so a late answer from the aborted
    // request can no longer overwrite a newer state - the same guard the timeout
    // uses.
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

    // Builds the read command and starts the balance query.
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

    // Fetches the remaining balance via XMLHttpRequest from QtQuick, so no
    // external tool such as curl is required. The key only sits in the header and
    // is never written to the applet configuration.
    function fetchBalance(apiKey) {
        // The id is copied into the response handlers, so only the answer of the
        // currently running chain may set the state.
        var requestId = balanceRequestId;
        balancePhase = "http";
        var xhr = new XMLHttpRequest();
        xhr.open("GET", balanceApiUrl);
        xhr.setRequestHeader("Authorization", "Bearer " + apiKey);
        xhr.setRequestHeader("Accept", "application/json");
        // So the timeout can abort the request instead of only invalidating it.
        root.balanceRequest = xhr;
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            root.balanceRequest = null;
            applyBalanceResult(Balance.parseBalance(xhr.status, xhr.responseText), requestId);
        };
        // Network failures give status 0; parseBalance turns that into "error".
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
        // The API can report a usable account state separately from the value:
        // is_available === false means API calls are refused even if a balance
        // is listed, so the row adds a notice.
        balanceUnavailable = result.state === "ok" && !result.isAvailable;
        // 200 with an empty balance_infos list is not an error, but there is
        // nothing to show - otherwise it would read "Balance: " without a value.
        balanceState = (result.state === "ok" && entry === null) ? "empty" : result.state;
    }

    // Bridge so the shared text formatters in duration.js can reach i18n(), which
    // only exists inside QML. The trailing placeholders are undefined for the
    // shorter texts; i18n() ignores unused arguments.
    function translateText(text, first, second) {
        return i18n(text, first, second);
    }
}