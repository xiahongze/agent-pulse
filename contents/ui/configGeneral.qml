import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    property string title: ""
    property alias cfg_refreshSeconds: refresh.value
    property alias cfg_claudeOnlineUsage: claudeOnlineUsage.checked
    property alias cfg_themeMode: theme.currentValue
    property alias cfg_palette: palette.currentValue
    property alias cfg_desktopOpacity: desktopOpacity.value
    property alias cfg_pin: pin.checked
    property int cfg_refreshSecondsDefault: 60
    property bool cfg_claudeOnlineUsageDefault: true
    property string cfg_themeModeDefault: "system"
    property string cfg_paletteDefault: "cyan"
    property int cfg_desktopOpacityDefault: 50
    property bool cfg_pinDefault: false
    Controls.SpinBox { id: refresh; Kirigami.FormData.label: i18n("Refresh interval:"); from: 15; to: 3600; stepSize: 15; editable: true; textFromValue: v => i18n("%1 seconds", v) }
    Controls.CheckBox { id: claudeOnlineUsage; Kirigami.FormData.label: i18n("Claude usage:"); text: i18n("Fetch online rate windows") }
    Controls.ComboBox { id: theme; Kirigami.FormData.label: i18n("Theme:"); textRole: "text"; valueRole: "value"; model: [{text:i18n("System"),value:"system"},{text:i18n("Light"),value:"light"},{text:i18n("Dark"),value:"dark"}] }
    Controls.ComboBox { id: palette; Kirigami.FormData.label: i18n("Palette:"); textRole: "text"; valueRole: "value"; model: [{text:"Cyan",value:"cyan"},{text:"Violet",value:"violet"},{text:"Amber",value:"amber"},{text:"Nord",value:"nord"},{text:"Solarized",value:"solarized"}] }
    RowLayout { Kirigami.FormData.label: i18n("Desktop opacity:"); Controls.Slider { id: desktopOpacity; from: 10; to: 100; stepSize: 5; Layout.fillWidth: true } Controls.Label { text: Math.round(desktopOpacity.value) + "%"; Layout.minimumWidth: 42 } }
    Controls.CheckBox { id: pin; Kirigami.FormData.label: i18n("Taskbar popup:"); text: i18n("Keep open when focus changes") }
    Controls.Label { text: i18n("Opacity applies only to the desktop dashboard. The taskbar popup keeps Plasma's native surface."); wrapMode: Text.Wrap; Layout.fillWidth: true }
    Controls.Label { text: i18n("Local history stays on this machine. Claude usage lookup sends your existing OAuth token only to Anthropic."); wrapMode: Text.Wrap; Layout.fillWidth: true }
}
