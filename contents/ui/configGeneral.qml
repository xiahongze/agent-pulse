import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    property string title: ""
    property alias cfg_refreshSeconds: refresh.value
    property alias cfg_endpoint: endpoint.text
    property alias cfg_themeMode: theme.currentValue
    property alias cfg_palette: palette.currentValue
    property alias cfg_backgroundOpacity: opacity.value
    property int cfg_refreshSecondsDefault: 60
    property string cfg_endpointDefault: "http://127.0.0.1:42427/v1/stats"
    property string cfg_themeModeDefault: "system"
    property string cfg_paletteDefault: "cyan"
    property int cfg_backgroundOpacityDefault: 50
    Controls.SpinBox { id: refresh; Kirigami.FormData.label: i18n("Refresh interval:"); from: 15; to: 3600; stepSize: 15; editable: true; textFromValue: v => i18n("%1 seconds", v) }
    Controls.TextField { id: endpoint; Kirigami.FormData.label: i18n("Local service:") }
    Controls.ComboBox { id: theme; Kirigami.FormData.label: i18n("Theme:"); textRole: "text"; valueRole: "value"; model: [{text:i18n("System"),value:"system"},{text:i18n("Light"),value:"light"},{text:i18n("Dark"),value:"dark"}] }
    Controls.ComboBox { id: palette; Kirigami.FormData.label: i18n("Palette:"); textRole: "text"; valueRole: "value"; model: [{text:"Cyan",value:"cyan"},{text:"Violet",value:"violet"},{text:"Amber",value:"amber"},{text:"Nord",value:"nord"},{text:"Solarized",value:"solarized"}] }
    RowLayout { Kirigami.FormData.label: i18n("Background opacity:"); Controls.Slider { id: opacity; from: 10; to: 100; stepSize: 5; Layout.fillWidth: true } Controls.Label { text: Math.round(opacity.value) + "%"; Layout.minimumWidth: 42 } }
    Controls.Label { text: i18n("Executable paths are configured in ~/.config/agent-pulse/config.json. History never leaves this machine."); wrapMode: Text.Wrap; Layout.fillWidth: true }
}
