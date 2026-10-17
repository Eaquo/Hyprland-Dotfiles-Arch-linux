import QtQuick
import qs.core
import qs.core.functions

// SetInput — champ texte ; `committed(text)` quand on valide (Entrée) ou quitte le champ.
Rectangle {
    id: box
    property alias text: input.text
    property string placeholder: ""
    signal committed(string text)
    implicitWidth: 320; implicitHeight: 34; radius: 9
    color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.6)
    border.width: 1
    border.color: input.activeFocus ? Appearance.colors.accent : ColorUtils.applyAlpha(Appearance.colors.fg, 0.12)
    Behavior on border.color { ColorAnimation { duration: Appearance.dur(150) } }
    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        verticalAlignment: TextInput.AlignVCenter
        clip: true; selectByMouse: true
        font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 1
        color: Appearance.colors.fg
        selectionColor: ColorUtils.applyAlpha(Appearance.colors.accent, 0.5)
        onEditingFinished: box.committed(text)
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === "" && !input.activeFocus
            text: box.placeholder
            font: input.font; color: Appearance.colors.dim
        }
    }
}
