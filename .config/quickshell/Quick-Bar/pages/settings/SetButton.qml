import QtQuick
import qs.core
import qs.core.functions

// SetButton — bouton des pages de réglages (primary = plein, active = sélectionné).
Rectangle {
    id: b
    property string label: ""
    property bool primary: false
    property bool active: false
    signal tap()
    implicitWidth: t.implicitWidth + 26; implicitHeight: 32; radius: 9
    color: primary ? Appearance.colors.accent
         : active ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.3)
         : ColorUtils.applyAlpha(Appearance.colors.fg, ma.containsMouse ? 0.1 : 0.05)
    border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.1)
    scale: ma.pressed ? 0.95 : 1
    Behavior on scale { NumberAnimation { duration: Appearance.dur(160); easing.type: Easing.OutBack } }
    Text { id: t; anchors.centerIn: parent; text: b.label
           font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 1
           color: b.primary ? Appearance.textOn(Appearance.colors.accent) : Appearance.colors.fg }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.tap() }
}
