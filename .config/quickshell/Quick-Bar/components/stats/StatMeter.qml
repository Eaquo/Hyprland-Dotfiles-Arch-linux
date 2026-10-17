import QtQuick
import QtQuick.Layouts
import qs.core
import qs.core.functions
import qs.services

// StatMeter — élément des cartes de stats (barre et pages System).
ColumnLayout {
    id: mt
    property string name: ""
    property string value: ""
    property real   pct: 0
    property color  col: Appearance.colors.fg
    Layout.fillWidth: true
    spacing: 4
    RowLayout {
        Layout.fillWidth: true
        Text { Layout.fillWidth: true; text: mt.name; elide: Text.ElideRight; font.family: Appearance.font.family; font.pixelSize: 12; color: Appearance.colors.fg }
        Text { text: mt.value; font.family: "JetBrains Mono"; font.pixelSize: 12; color: Appearance.colors.fg }
    }
    Rectangle {
        Layout.fillWidth: true; implicitHeight: 4; radius: 2
        color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
        Rectangle {
            height: parent.height; radius: 2
            width: parent.width * Math.max(0.02, Math.min(1, mt.pct / 100))
            color: mt.col
            Behavior on width { NumberAnimation { duration: Appearance.dur(450); easing.type: Easing.OutCubic } }
        }
    }
}
