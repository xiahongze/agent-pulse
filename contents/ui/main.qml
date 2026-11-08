import QtQuick
import "taskbar.js" as Taskbar
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root
    property var snapshot: ({providers: [], history: [], generated_at: ""})
    property bool busy: false
    property string errorText: ""
    property string pendingCommand: ""
    property int refreshId: 0
    property var accents: ({cyan:"#22d3ee", violet:"#a78bfa", amber:"#fbbf24", nord:"#88c0d0", solarized:"#2aa198"})
    property color accent: accents[Plasmoid.configuration.palette] || Kirigami.Theme.highlightColor
    property bool isDesktop: Plasmoid.formFactor === PlasmaCore.Types.Planar
    property bool forcedDark: Plasmoid.configuration.themeMode === "dark"
    property bool forcedLight: Plasmoid.configuration.themeMode === "light"
    property color surface: forcedDark ? "#10151d" : forcedLight ? "#f7f9fc" : Kirigami.Theme.backgroundColor
    property color ink: forcedDark ? "#e8eef7" : forcedLight ? "#152033" : Kirigami.Theme.textColor
    property color muted: forcedDark ? "#93a1b5" : forcedLight ? "#64748b" : Kirigami.Theme.disabledTextColor
    property color cardSurface: forcedDark ? "#1b2430" : forcedLight ? "#e8edf4" : Kirigami.Theme.alternateBackgroundColor
    property url agentIcon: Qt.resolvedUrl("../icons/agent-pulse.svg")

    Plasmoid.icon: root.agentIcon
    Plasmoid.title: i18n("Agent Pulse")
    // The desktop supplies its own translucent surface below; panel popups keep native Plasma chrome.
    Plasmoid.backgroundHints: root.isDesktop ? PlasmaCore.Types.NoBackground : PlasmaCore.Types.DefaultBackground
    switchWidth: 0
    switchHeight: 0
    preferredRepresentation: isDesktop ? fullRepresentation : compactRepresentation
    hideOnWindowDeactivate: !Plasmoid.configuration.pin

    toolTipMainText: i18n("Agent Pulse")
    toolTipSubText: {
        const lines = [];
        if (errorText)
            lines.push(i18n("Last known usage · %1", errorText));
        for (const provider of snapshot.providers || []) {
            if (!provider.available) {
                lines.push(i18n("%1 · no data", provider.name));
                continue;
            }
            const windows = (provider.rate_windows || []).slice(0, 2).map(w => {
                const expired = w.expired || (w.reset_epoch !== null && w.reset_epoch !== undefined && w.reset_epoch * 1000 <= tooltipNow);
                return expired || w.used_percent === null || w.used_percent === undefined
                    ? i18n("%1 awaiting usage", w.label)
                    : i18n("%1 %2% used", w.label, Math.round(w.used_percent));
            });
            lines.push(i18n("%1 · %2", provider.name, windows.length ? windows.join(" · ") : i18n("%1 tokens today", compact(provider.tokens_today))));
            if (provider.usage_status)
                lines.push(provider.usage_status === "disabled" ? i18n("Online usage off") : i18n("Saved usage · retrying"));
        }
        return lines.length ? lines.join("\n") : i18n("Collecting local usage…");
    }
    property double tooltipNow: Date.now()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.tooltipNow = Date.now() }

    readonly property var taskbarRows: Taskbar.rows(snapshot.providers || [],
        Plasmoid.configuration.taskbarAllAgents, Plasmoid.configuration.taskbarCodex,
        Plasmoid.configuration.taskbarClaude, tooltipNow, Boolean(errorText))
    readonly property bool showTaskbarUsage: Plasmoid.pluginName === "io.github.xiahongze.agentpulse.usage" && taskbarRows.length > 0

    compactRepresentation: Item {
        implicitWidth: root.showTaskbarUsage ? usage.implicitWidth + Kirigami.Units.smallSpacing * 2 : Kirigami.Units.iconSizes.medium
        implicitHeight: root.showTaskbarUsage ? usage.implicitHeight : Kirigami.Units.iconSizes.medium
        Layout.minimumWidth: Plasmoid.formFactor === PlasmaCore.Types.Vertical ? Kirigami.Units.iconSizes.smallMedium : implicitWidth
        Layout.preferredWidth: implicitWidth
        Layout.maximumWidth: Math.max(implicitWidth, height)
        Accessible.name: root.toolTipMainText + ": " + root.toolTipSubText
        Accessible.role: Accessible.Button
        activeFocusOnTab: true
        Keys.onSpacePressed: root.expanded = !root.expanded
        Keys.onReturnPressed: root.expanded = !root.expanded
        TaskbarUsage {
            id: usage
            visible: root.showTaskbarUsage
            anchors.centerIn: parent
            width: Math.max(0, parent.width - Kirigami.Units.smallSpacing * 2)
            height: Math.min(parent.height, implicitHeight)
            rows: root.taskbarRows
        }
        Kirigami.Icon {
            visible: !root.showTaskbarUsage
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            source: Qt.resolvedUrl("../icons/agent-pulse-symbolic.svg")
            isMask: true
            color: Kirigami.Theme.textColor
            active: compactMouse.containsMouse
        }
        MouseArea { id: compactMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.expanded = !root.expanded }
    }

    fullRepresentation: Rectangle {
        Layout.minimumWidth: 400
        Layout.minimumHeight: 620
        Layout.preferredWidth: 430
        Layout.preferredHeight: 690
        radius: root.isDesktop ? 14 : 0
        color: root.isDesktop
            ? Qt.rgba(root.surface.r, root.surface.g, root.surface.b, Math.max(10, Plasmoid.configuration.desktopOpacity) / 100)
            : (root.forcedDark || root.forcedLight ? root.surface : "transparent")

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing
            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon { source: root.agentIcon; Layout.preferredWidth: 34; Layout.preferredHeight: 34 }
                ColumnLayout { spacing: 1; Controls.Label { text: i18n("AGENT PULSE"); color: root.ink; font.pixelSize: 18; font.bold: true; font.letterSpacing: 2 } Controls.Label { text: root.errorText || (root.busy ? i18n("SYNCING LOCAL TELEMETRY") : i18n("LOCAL TELEMETRY • PRIVATE")); color: root.errorText ? "#fb7185" : root.accent; font.pixelSize: 10; font.family: "monospace" } }
                Item { Layout.fillWidth: true }
                PlasmaComponents.ToolButton {
                    icon.name: "view-refresh"
                    enabled: !root.busy
                    onClicked: root.refresh()
                    PlasmaComponents.ToolTip { text: i18n("Refresh Now") }
                }
                PlasmaComponents.ToolButton {
                    visible: !root.isDesktop
                    checkable: true
                    checked: Plasmoid.configuration.pin
                    icon.name: "window-pin"
                    onToggled: Plasmoid.configuration.pin = checked
                    PlasmaComponents.ToolTip { text: i18n("Keep Open") }
                }
            }
            Repeater {
                model: root.snapshot.providers || []
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 142 + modelData.rate_windows.length * 32 + (modelData.usage_status ? 20 : 0)
                    radius: 9
                    color: root.cardSurface
                    border.color: Qt.alpha(root.accent, 0.3)
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.smallSpacing
                        RowLayout { Layout.fillWidth: true; Rectangle { width: 8; height: 8; radius: 4; color: modelData.available ? root.accent : root.muted } Controls.Label { text: modelData.name.toUpperCase(); color: root.ink; font.bold: true; font.letterSpacing: 1 } Item { Layout.fillWidth: true } Controls.Label { text: modelData.available ? i18n("ONLINE") : i18n("NO DATA"); color: modelData.available ? root.accent : root.muted; font.pixelSize: 10; font.family: "monospace" } }
                        Repeater { model: modelData.rate_windows; delegate: RateWindow { required property var modelData; label: modelData.label; percentage: modelData.used_percent; resetAt: modelData.reset_at; accent: root.accent; ink: root.ink; muted: root.muted } }
                        Controls.Label {
                            visible: modelData.name === "Claude" && Boolean(modelData.usage_status)
                            text: modelData.usage_status === "rate_limited" ? i18n("USAGE RATE LIMITED • RETRYING")
                                : modelData.usage_status === "disabled" ? i18n("ONLINE USAGE OFF")
                                : i18n("USAGE UNAVAILABLE • RETRYING")
                            color: root.muted
                            font.pixelSize: 9
                            font.family: "monospace"
                        }
                        RowLayout { Layout.fillWidth: true; spacing: Kirigami.Units.smallSpacing; Metric { label: i18n("TOKENS • 7D"); value: modelData.available ? root.compact(modelData.tokens_7d) : "—"; ink: root.ink; muted: root.muted } Metric { label: i18n("SESSIONS • 7D"); value: modelData.available ? modelData.sessions_7d : "—"; ink: root.ink; muted: root.muted } Metric { label: i18n("TOKENS • TODAY"); value: modelData.available ? root.compact(modelData.tokens_today) : "—"; ink: root.ink; muted: root.muted } }
                        Controls.Label { text: !modelData.available ? (modelData.status_detail || i18n("NO LOCAL DATA")) : modelData.usage_updated ? i18n("SOURCE %1  •  API FETCHED %2", modelData.source_updated || i18n("CURRENT"), modelData.usage_updated) : i18n("SOURCE  %1", modelData.source_updated || i18n("CURRENT")); color: root.muted; font.pixelSize: 9; font.family: "monospace" }
                    }
                }
            }
            Controls.Label { text: i18n("7 DAY ACTIVITY"); color: root.muted; font.pixelSize: 10; font.family: "monospace"; font.letterSpacing: 1 }
            RowLayout {
                Layout.fillWidth: true; Layout.preferredHeight: 58; spacing: 5
                Repeater { model: root.snapshot.history || []; delegate: ColumnLayout { required property var modelData; Layout.fillWidth: true; spacing: 3; Item { Layout.preferredHeight: 38; Layout.fillWidth: true; Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Math.max(3, 38 * modelData.ratio); radius: 2; color: root.accent } } Controls.Label { Layout.alignment: Qt.AlignHCenter; text: modelData.label; color: root.muted; font.pixelSize: 8 } } }
            }
            Item { Layout.fillHeight: true }
            RowLayout { Layout.fillWidth: true; Controls.Label { text: root.snapshot.generated_at ? i18n("UPDATED %1", root.snapshot.generated_at) : i18n("WAITING FOR DATA"); color: root.muted; font.pixelSize: 9; font.family: "monospace" } Item { Layout.fillWidth: true } Controls.Label { text: i18n("%1s AUTO", Plasmoid.configuration.refreshSeconds); color: root.muted; font.pixelSize: 9; font.family: "monospace" } }
        }
    }

    Plasma5Support.DataSource {
        id: collector
        engine: "executable"
        interval: 0
        onNewData: function(source, data) {
            if (source !== root.pendingCommand || data["exit code"] === undefined)
                return
            collector.disconnectSource(source)
            root.pendingCommand = ""
            root.busy = false
            refreshTimeout.stop()
            if (data["exit code"] !== 0 || data["exit status"] !== 0) {
                root.errorText = data["exit code"] === 127 ? i18n("PYTHON 3 NOT FOUND") : i18n("COLLECTOR FAILED")
                return
            }
            try {
                let result = JSON.parse(data.stdout)
                if (!Array.isArray(result.providers) || !Array.isArray(result.history))
                    throw new Error("Invalid snapshot")
                root.snapshot = result
                root.errorText = ""
            } catch (e) {
                root.errorText = i18n("INVALID COLLECTOR RESPONSE")
            }
        }
    }
    Component.onCompleted: Qt.callLater(refresh)
    Timer { interval: Math.max(15, Plasmoid.configuration.refreshSeconds) * 1000; running: true; repeat: true; onTriggered: root.refresh() }
    Timer { id: refreshTimeout; interval: 20000; onTriggered: { if (root.pendingCommand) collector.disconnectSource(root.pendingCommand); root.pendingCommand = ""; root.busy = false; root.errorText = i18n("COLLECTOR TIMED OUT") } }
    function compact(n) { n=Number(n||0); return n>=1000000?(n/1000000).toFixed(1)+"M":n>=1000?(n/1000).toFixed(1)+"K":String(n) }
    function shellQuote(value) { return "'" + value.replace(/'/g, "'\\''") + "'" }
    function refresh() {
        if (busy)
            return
        if (!collector.valid) {
            errorText = i18n("PLASMA EXECUTABLE ENGINE UNAVAILABLE")
            return
        }
        let scriptUrl = Qt.resolvedUrl("../code/agent_pulse.py").toString()
        let scriptPath = decodeURIComponent(scriptUrl.replace(/^file:\/\//, ""))
        let command = "/usr/bin/env python3 " + shellQuote(scriptPath) + " --once --refresh-id " + (++refreshId)
        command += Plasmoid.configuration.claudeOnlineUsage ? " --online" : " --offline"
        pendingCommand = command
        busy = true
        errorText = ""
        refreshTimeout.restart()
        collector.connectSource(command)
    }
}
