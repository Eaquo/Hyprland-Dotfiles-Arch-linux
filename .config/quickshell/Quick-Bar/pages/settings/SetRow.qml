import QtQuick
import QtQuick.Layouts
import qs.core

// SetRow — une ligne de réglage : titre + description à gauche, commande à droite.
// La commande est l'enfant de la ligne ; `wide: true` la place sous le texte, pleine largeur.
GridLayout {
    id: row
    property string title: ""
    property string desc: ""
    property bool   wide: false
    default property alias control: slot.data
    Layout.fillWidth: true
    columns: wide ? 1 : 2
    columnSpacing: 18; rowSpacing: 8
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Text {
            Layout.fillWidth: true
            text: row.title
            font.family: Appearance.font.family; font.pixelSize: Appearance.font.body - 1
            color: Appearance.colors.fg; wrapMode: Text.WordWrap
        }
        Text {
            Layout.fillWidth: true
            visible: row.desc !== ""
            text: row.desc
            font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 2
            color: Appearance.colors.dim; wrapMode: Text.WordWrap
        }
    }
    Item {
        id: slot
        Layout.fillWidth: row.wide
        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
