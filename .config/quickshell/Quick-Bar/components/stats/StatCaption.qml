import QtQuick
import QtQuick.Layouts
import qs.core
import qs.core.functions
import qs.services

// StatCaption — élément des cartes de stats (barre et pages System).
Text {
    font.family: Appearance.font.family; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.5
    font.capitalization: Font.AllUppercase
    color: Appearance.colors.dim
    Layout.topMargin: 6
}
