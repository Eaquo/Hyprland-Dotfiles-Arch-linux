import QtQuick
import QtQuick.Layouts
import qs.core
import qs.core.functions
import qs.services

// StatHint — élément des cartes de stats (barre et pages System).
Text {
    Layout.fillWidth: true; Layout.topMargin: 6
    font.family: "JetBrains Mono"; font.pixelSize: 10; color: Appearance.colors.dim
    wrapMode: Text.WordWrap
}
