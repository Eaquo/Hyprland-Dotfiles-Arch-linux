import QtQuick
import QtQuick.Layouts
import qs.core
import qs.core.functions

// SetCard — section d'une page de réglages : titre en petites capitales + lignes.
Rectangle {
    id: card
    property string title: ""
    // Bouton « Par défaut » dans l'en-tête : remet ces clés de config.toml à leur valeur d'origine
    // (resetKeys) et/ou émet resetRequested() pour les réglages rangés ailleurs (canReset: true).
    property var  resetKeys: []
    property bool canReset: resetKeys.length > 0
    signal resetRequested()
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
        RowLayout {
            visible: card.title !== "" || card.canReset
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: card.title
                font.family: Appearance.font.family; font.pixelSize: 11; font.weight: Font.DemiBold
                font.letterSpacing: 1.8; font.capitalization: Font.AllUppercase
                color: Appearance.colors.dim
            }
            Rectangle {
                visible: card.canReset
                implicitWidth: rl.implicitWidth + 18; implicitHeight: 24; radius: 8
                color: rMa.containsMouse ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.18) : "transparent"
                border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, rMa.containsMouse ? 0.25 : 0.1)
                Text {
                    id: rl
                    anchors.centerIn: parent
                    text: "󰑓  Par défaut"
                    font.family: Appearance.font.family; font.pixelSize: 11
                    color: rMa.containsMouse ? Appearance.colors.accent : Appearance.colors.dim
                }
                MouseArea {
                    id: rMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { card.resetKeys.forEach(k => Config.set(k, null)); card.resetRequested() }
                }
            }
        }
    }
}
