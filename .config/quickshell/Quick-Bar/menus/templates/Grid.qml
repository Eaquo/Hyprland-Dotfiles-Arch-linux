import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.core
import qs.core.functions

// Grid — tuiles : image (icon = chemin ou nom d'icône, recadrée) ou glyphe, libellé dessous.
// Colonnes : COLUMNS du script (req.columns), sinon `cols`. Les autres grilles en héritent
// et remplacent `tile` (Apps, Emoji, Theme).
Item {
    id: t
    required property var menu
    property real prefW: 1120
    property int cols: menu.req.columns > 0 ? menu.req.columns : 5
    property int rows: 3
    property real ratio: 0.62                       // hauteur / largeur d'une tuile
    readonly property real cw: Math.floor(width / cols)
    readonly property real ch: Math.round(cw * ratio)
    readonly property real contentH: Math.min(Math.ceil(menu.items.length / cols), rows) * Math.round(Math.floor((menu.fullW - 52) / cols) * ratio)
    property bool filter: true
    property bool search: true
    property string hints: "←↑→↓ choisir  ·  entrée valider"
    property bool fit: false                        // true = image entière (icônes d'apps)
    property Component tile: defTile
    property bool ownBorder: tile === defTile         // la tuile dessine déjà son contour

    // tuile par défaut : carte façon SUPER+W (image recadrée, nom en bas sur un dégradé)
    Component {
        id: defTile
        Item {
            property var it: ({ t: "" })
            property bool on: false
            ClippingRectangle {
                anchors.fill: parent
                radius: t.menu.rad(height)
                color: Appearance.colors.color0
                border.width: on ? 2 : 1
                border.color: on ? ColorUtils.applyAlpha(t.menu.glow, 0.75) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
                Image {
                    anchors.fill: parent
                    visible: !!it.icon
                    source: t.menu.iconSrc(it.icon)
                    sourceSize: Qt.size(480, 360)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Text {
                    anchors.centerIn: parent; anchors.verticalCenterOffset: -12
                    visible: !it.icon
                    text: it.glyph || "󰀻"
                    font.family: Appearance.font.family; font.pixelSize: 46
                    color: on ? t.menu.glow : Appearance.colors.fg
                }
                Rectangle {
                    anchors.bottom: parent.bottom; width: parent.width; height: 46
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: ColorUtils.applyAlpha("#000000", 0.75) }
                    }
                }
                Text {
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 9
                    x: 12; width: parent.width - 24
                    text: t.menu.mark(it.t, t.menu.glow, on); textFormat: Text.StyledText; elide: Text.ElideRight
                    font.family: Appearance.font.family; font.pixelSize: 14; font.weight: Font.DemiBold
                    color: "white"
                }
            }
        }
    }

    GridView {
        id: grid
        anchors.fill: parent
        model: t.menu.items
        cellWidth: t.cw; cellHeight: t.ch
        currentIndex: t.menu.cur
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            readonly property bool on: index === t.menu.cur
            width: t.cw; height: t.ch
            opacity: t.menu.settled ? 1 : 0
            scale: t.menu.settled ? 1 : 0.85
            Component.onCompleted: if (!t.menu.settled) pop.start()
            SequentialAnimation {
                id: pop
                PauseAnimation { duration: Math.min(cell.index, 24) * 14 }
                ParallelAnimation {
                    NumberAnimation { target: cell; property: "opacity"; to: 1; duration: Appearance.dur(180) }
                    NumberAnimation { target: cell; property: "scale"; to: 1; duration: Appearance.dur(280); easing.type: Easing.OutBack }
                }
            }
            // sélection comme SUPER+MAJ+G : la tuile se soulève, contour lumineux, ombre colorée ; les autres en retrait
            RectangularShadow {
                visible: t.ownBorder && !cell.on
                anchors.fill: parent; anchors.margins: 14; anchors.topMargin: 22; anchors.bottomMargin: 6
                radius: t.menu.rad(height); blur: 18; spread: 0
                color: ColorUtils.applyAlpha("#000000", 0.5)
            }
            Item {
                anchors.fill: parent; anchors.margins: 10
                transform: Translate { y: cell.on ? -4 : 0; Behavior on y { NumberAnimation { duration: Appearance.dur(200); easing.type: Easing.OutCubic } } }
                scale: cell.on ? 1.0 : 0.94
                opacity: cell.on ? 1 : 0.82
                Behavior on scale { NumberAnimation { duration: Appearance.dur(160) } }
                Behavior on opacity { NumberAnimation { duration: Appearance.dur(160) } }
                Loader {
                    anchors.fill: parent
                    sourceComponent: t.tile
                    onLoaded: { item.it = Qt.binding(() => cell.modelData); item.on = Qt.binding(() => cell.on) }
                }
                Rectangle {   // contour (les tuiles à image ont déjà le leur)
                    visible: !t.ownBorder
                    anchors.fill: parent; radius: t.menu.rad(height)
                    color: "transparent"
                    border.width: cell.on ? 2 : 1
                    border.color: cell.on ? ColorUtils.applyAlpha(t.menu.glow, 0.7) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
                }
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onEntered: if (t.menu.hoverReady) t.menu.cur = cell.index
                onClicked: t.menu.choose(cell.index)
            }
        }
    }
}
