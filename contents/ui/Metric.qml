import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
ColumnLayout {
    property string label: ""; property var value: "—"; property color ink; property color muted
    Layout.fillWidth: true; Layout.minimumWidth: 90; spacing: 2
    Controls.Label { text: parent.value; color: parent.ink; font.pixelSize: 21; font.bold: true; font.family: "monospace" }
    Controls.Label { text: parent.label; color: parent.muted; font.pixelSize: 8; font.family: "monospace" }
}
