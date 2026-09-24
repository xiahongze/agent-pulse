import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
ColumnLayout {
    property string label: ""; property real percentage: 0; property string resetAt: ""
    property color accent; property color ink; property color muted
    Layout.fillWidth: true; spacing: 3
    RowLayout { Layout.fillWidth: true
        Controls.Label { text: parent.parent.label; color: parent.parent.muted; font.pixelSize: 9; font.family: "monospace" }
        Item { Layout.fillWidth: true }
        Controls.Label { text: Math.round(parent.parent.percentage) + "%"; color: parent.parent.ink; font.bold: true; font.family: "monospace" }
        Controls.Label { text: parent.parent.resetAt ? "↻ " + parent.parent.resetAt : ""; color: parent.parent.muted; font.pixelSize: 9; font.family: "monospace" }
    }
    Rectangle { Layout.fillWidth: true; height: 5; radius: 3; color: Qt.alpha(parent.ink, .1)
        Rectangle { width: parent.width * Math.min(100, Math.max(0, percentage)) / 100; height: parent.height; radius: 3; color: accent }
    }
}
