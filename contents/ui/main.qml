import QtQuick
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
    switchWidth: Plasmoid.formFactor === PlasmaCore.Types.Planar ? -1 : 360
    switchHeight: Plasmoid.formFactor === PlasmaCore.Types.Planar ? -1 : 500
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : null
    hideOnWindowDeactivate: !Plasmoid.configuration.pin

    compactRepresentation: Item {
        implicitWidth: Kirigami.Units.gridUnit * 2
        implicitHeight: implicitWidth
        Kirigami.Icon { anchors.fill: parent; anchors.margins: Kirigami.Units.smallSpacing; source: root.agentIcon; active: compactMouse.containsMouse }
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
