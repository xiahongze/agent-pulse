pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root
    required property var rows
    implicitWidth: Math.max(0, ...labels.children.map(c => c.implicitWidth || 0))
    implicitHeight: rows.length * 14
    Column {
        id: labels
        anchors.fill: parent
        spacing: 0
        Repeater {
            model: root.rows
            delegate: Text {
                required property var modelData
                width: root.width
                height: root.height / Math.max(1, root.rows.length)
                text: modelData.text
                color: Kirigami.Theme.textColor
                opacity: modelData.stale ? 0.6 : 1
                font.pixelSize: Math.max(9, Math.min(12, Math.floor(height)))
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 8
            }
        }
    }
}
