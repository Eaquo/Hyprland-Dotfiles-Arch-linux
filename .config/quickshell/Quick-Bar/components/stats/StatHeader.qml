import QtQuick
import QtQuick.Layouts
import qs.core
import qs.core.functions
import qs.services

// StatHeader — élément des cartes de stats (barre et pages System).
RowLayout {
    id: hd
    property string big: ""
    property string sub: ""
    property color  col: Appearance.colors.fg
    Layout.fillWidth: true
    Text { text: hd.big; font.family: Appearance.font.family; font.pixelSize: 30; font.weight: Font.Bold; color: hd.col
           Behavior on color { ColorAnimation { duration: Appearance.dur(250) } } }
    Item { Layout.fillWidth: true }
    Text { text: hd.sub; font.family: "JetBrains Mono"; font.pixelSize: 11; color: Appearance.colors.dim; horizontalAlignment: Text.AlignRight }
}
