import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root
    implicitWidth: 410
    implicitHeight: 650
    property var snapshot: ({providers: [], history: [], generated_at: ""})
    property bool busy: false
    property string errorText: ""
    property var accents: ({cyan:"#22d3ee", violet:"#a78bfa", amber:"#fbbf24", nord:"#88c0d0", solarized:"#2aa198"})
    property color accent: accents[Plasmoid.configuration.palette] || accents.cyan
    property bool forcedDark: Plasmoid.configuration.themeMode === "dark"
    property bool forcedLight: Plasmoid.configuration.themeMode === "light"
    property color themeSurface: forcedDark ? "#10151d" : forcedLight ? "#f7f9fc" : Kirigami.Theme.backgroundColor
    property color surface: Qt.rgba(themeSurface.r, themeSurface.g, themeSurface.b, 0.97)
    property color ink: forcedDark ? "#e8eef7" : forcedLight ? "#152033" : Kirigami.Theme.textColor
    property color muted: forcedDark ? "#8290a4" : forcedLight ? "#64748b" : Kirigami.Theme.disabledTextColor

    preferredRepresentation: fullRepresentation
    compactRepresentation: Controls.Button {
        implicitWidth: 38; implicitHeight: 38; onClicked: root.expanded = !root.expanded
        Accessible.name: i18n("Open Agent Pulse")
        contentItem: Controls.Label { text: "</>"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; color: root.accent; font.family: "monospace"; font.bold: true }
    }
    fullRepresentation: Rectangle {
        implicitWidth: 410; implicitHeight: 650; color: root.surface; radius: 14
        ColumnLayout {
            anchors.fill: parent; anchors.margins: Math.max(12, Math.min(20, parent.width * 0.05)); spacing: 14
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout { spacing: 1; Controls.Label { text: "AGENT PULSE"; color: root.ink; font.pixelSize: 18; font.bold: true; font.letterSpacing: 2 } Controls.Label { text: root.errorText || (root.busy ? "SYNCING LOCAL TELEMETRY" : "LOCAL TELEMETRY • PRIVATE"); color: root.errorText ? "#fb7185" : root.accent; font.pixelSize: 10; font.family: "monospace" } }
                Item { Layout.fillWidth: true }
                Controls.ToolButton { text: "↻"; enabled: !root.busy; Accessible.name: i18n("Refresh now"); onClicked: root.refresh() }
            }
            Repeater {
                model: root.snapshot.providers || []
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredHeight: modelData.rate_windows.length ? 190 : 150; radius: 10
                    color: Qt.alpha(root.ink, 0.055); border.color: Qt.alpha(root.accent, 0.28)
                    ColumnLayout { anchors.fill: parent; anchors.margins: 14; spacing: 7
                        RowLayout { Layout.fillWidth: true; Rectangle { width: 8; height: 8; radius: 4; color: modelData.available ? root.accent : root.muted } Controls.Label { text: modelData.name.toUpperCase(); color: root.ink; font.bold: true; font.letterSpacing: 1 } Item { Layout.fillWidth: true } Controls.Label { text: modelData.available ? "ONLINE" : "NO DATA"; color: modelData.available ? root.accent : root.muted; font.pixelSize: 10; font.family: "monospace" } }
                        Repeater { model: modelData.rate_windows; delegate: RateWindow { required property var modelData; label: modelData.label; percentage: modelData.used_percent; resetAt: modelData.reset_at; accent: root.accent; ink: root.ink; muted: root.muted } }
                        RowLayout { Layout.fillWidth: true; spacing: 6; Metric { label: "TOKENS • 7D"; value: modelData.available ? root.compact(modelData.tokens_7d) : "—"; ink: root.ink; muted: root.muted } Metric { label: "SESSIONS • 7D"; value: modelData.available ? modelData.sessions_7d : "—"; ink: root.ink; muted: root.muted } Metric { label: "TOKENS • TODAY"; value: modelData.available ? root.compact(modelData.tokens_today) : "—"; ink: root.ink; muted: root.muted } }
                        Controls.Label { text: modelData.available ? "SOURCE  " + (modelData.source_updated || "CURRENT") : (modelData.status_detail || "NO LOCAL DATA"); color: root.muted; font.pixelSize: 9; font.family: "monospace" }
                    }
                }
            }
            Controls.Label { Layout.fillWidth: true; text: "7 DAY ACTIVITY"; color: root.muted; font.pixelSize: 10; font.family: "monospace"; font.letterSpacing: 1 }
            RowLayout { Layout.fillWidth: true; Layout.preferredHeight: 54; spacing: 5
                Repeater { model: root.snapshot.history || []; delegate: ColumnLayout { required property var modelData; Layout.fillWidth: true; spacing: 3; Item { Layout.preferredHeight: 36; Layout.fillWidth: true; Accessible.name: modelData.label + ": " + root.compact(modelData.tokens) + " tokens"; Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Math.max(3, 36 * modelData.ratio); radius: 2; color: root.accent } } Controls.Label { Layout.alignment: Qt.AlignHCenter; text: modelData.label; color: root.muted; font.pixelSize: 8 } } }
            }
            Item { Layout.fillHeight: true }
            RowLayout { Layout.fillWidth: true; Controls.Label { text: root.snapshot.generated_at ? "UPDATED " + root.snapshot.generated_at : "WAITING FOR SERVICE"; color: root.muted; font.pixelSize: 9; font.family: "monospace" } Item { Layout.fillWidth: true } Controls.Label { text: Plasmoid.configuration.refreshSeconds + "s AUTO"; color: root.muted; font.pixelSize: 9; font.family: "monospace" } }
        }
    }
    Timer { interval: Math.max(15, Plasmoid.configuration.refreshSeconds) * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    function compact(n) { n=Number(n||0); return n>=1000000?(n/1000000).toFixed(1)+"M":n>=1000?(n/1000).toFixed(1)+"K":String(n) }
    function refresh() { busy=true; errorText=""; let x=new XMLHttpRequest(); x.open("GET",Plasmoid.configuration.endpoint); x.onreadystatechange=function(){ if(x.readyState===XMLHttpRequest.DONE){busy=false;if(x.status===200){try{snapshot=JSON.parse(x.responseText)}catch(e){errorText="INVALID SERVICE RESPONSE"}}else errorText="SERVICE OFFLINE"}}; x.send() }
}
