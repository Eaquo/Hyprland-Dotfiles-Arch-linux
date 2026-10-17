import QtQuick
import QtQuick.Layouts
import qs.core
import qs.core.functions

// SetCard — section d'une page de réglages : titre en petites capitales + lignes.
Rectangle {
    id: card
    property string title: ""
    default property alias content: col.data
    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 32
    radius: Appearance.cornerRadius - 4
    color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.03)
    border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
    ColumnLayout {
        id: col
        x: 18; y: 16; width: parent.width - 36
        spacing: 12
        Text {
            visible: card.title !== ""
            text: card.title
            font.family: Appearance.font.family; font.pixelSize: 11; font.weight: Font.DemiBold
            font.letterSpacing: 1.8; font.capitalization: Font.AllUppercase
            color: Appearance.colors.dim
        }
    }
}
