import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
ColumnLayout {
    property string label: ""; property var value: "—"; property color ink; property color muted
    Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: 2
    Controls.Label { Layout.fillWidth: true; text: parent.value; color: parent.ink; font.pixelSize: 19; font.bold: true; font.family: "monospace"; elide: Text.ElideRight }
    Controls.Label { Layout.fillWidth: true; text: parent.label; color: parent.muted; font.pixelSize: 7; font.family: "monospace"; elide: Text.ElideRight }
}
