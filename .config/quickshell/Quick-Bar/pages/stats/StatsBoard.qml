import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.components.stats
import qs.core
import qs.core.functions
import qs.services

// StatsBoard — page System (dashboard et tactile) : les cartes de survol de la barre
// (components/stats/), rangées en colonnes. À l'affichage, chaque carte s'ouvre comme
// celle de la barre (goutte → pilule → déroulé), en cascade. Toucher une carte ouvre
// l'outil détaillé (btop, sensors, amdgpu_top, ncdu, nload).
Item {
    id: root
    // Colonnes de cartes : cpu · ram · tcpu · tgpu · tnvme · disk · net
    property var columns: [["cpu"], ["ram", "net"], ["tcpu", "tgpu"], ["tnvme", "disk"]]
    readonly property int gap: 12
    readonly property bool shown: visible && width > 0

    // Processus, place récupérable et profil d'énergie tant que la page est visible
    onShownChanged: { SysData.want("board" + root, shown); if (shown) cascade++ }
    Component.onDestruction: SysData.want("board" + root, false)
    property int cascade: 0             // incrémenté → les cartes rejouent leur ouverture

    readonly property var cards: ({ cpu: cpuC, ram: ramC, tcpu: tcpuC, tgpu: tgpuC, tnvme: nvmeC, disk: diskC, net: netC })
    Component { id: cpuC; CpuCard { hints: false } }
    Component { id: ramC; RamCard { hints: false } }
    Component { id: tcpuC; CpuTempCard { hints: false } }
    Component { id: tgpuC; GpuCard { hints: false } }
    Component { id: nvmeC; NvmeCard { hints: false } }
    Component { id: diskC; DiskCard { hints: false } }
    Component { id: netC; NetCard { hints: false } }
    readonly property var titles: ({ cpu: "Processeur", ram: "Mémoire", tcpu: "Température CPU", tgpu: "Carte graphique",
                                     tnvme: "SSD NVMe", disk: "Disques", net: "Réseau" })
    readonly property var icons: ({ cpu: "󰍛", ram: "󰾆", tcpu: "󰔏", tgpu: "󰢮", tnvme: "󰆼", disk: "󰋊", net: "󰛳" })

    Flickable {
        anchors.fill: parent
        contentHeight: row.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        RowLayout {
            id: row
            width: parent.width
            spacing: root.gap
            Repeater {
                model: root.columns
                delegate: ColumnLayout {
                    id: col
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: root.gap
                    Repeater {
                        model: col.modelData
                        delegate: Tile {
                            required property string modelData
                            required property int index
                            kind: modelData
                            order: col.index + index * root.columns.length
                        }
                    }
                }
            }
        }
    }

    // Une carte : réserve sa place, et sa forme s'anime dedans
    component Tile: Item {
        id: tile
        property string kind: ""
        property int order: 0
        Layout.fillWidth: true
        implicitHeight: fullH

        readonly property real fullW: width
        readonly property real fullH: ld.implicitHeight + 60
        readonly property real dot: 26
        property real w: fullW
        property real h: fullH
        property real by: 0
        property real content: 1

        Connections {
            target: root
            function onCascadeChanged() { enter.restart() }
        }
        SequentialAnimation {
            id: enter
            ScriptAction { script: { tile.w = tile.dot; tile.h = tile.dot; tile.content = 0; tile.by = -tile.dot } }
            PauseAnimation { duration: Appearance.dur(70 * tile.order) }
            // 1. la goutte tombe
            NumberAnimation { target: tile; property: "by"; to: 0; duration: Appearance.dur(300); easing.type: Easing.OutCubic }
            // 2. elle s'étire à l'horizontale
            NumberAnimation { target: tile; property: "w"; to: tile.fullW; duration: Appearance.dur(360); easing.type: Easing.OutCubic }
            // 3. elle se déroule, le contenu apparaît en fin de course
            ParallelAnimation {
                NumberAnimation { target: tile; property: "h"; to: tile.fullH; duration: Appearance.dur(500); easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                SequentialAnimation {
                    PauseAnimation { duration: Appearance.dur(200) }
                    NumberAnimation { target: tile; property: "content"; to: 1; duration: Appearance.dur(320); easing.type: Easing.OutCubic }
                }
            }
            ScriptAction { script: { tile.w = Qt.binding(() => tile.fullW); tile.h = Qt.binding(() => tile.fullH) } }
        }

        ClippingRectangle {
            id: box
            x: (tile.width - tile.w) / 2
            y: tile.by
            width: tile.w; height: tile.h
            radius: Math.min(16, Math.min(width, height) / 2)
            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.92)
            border.width: 1
            border.color: ma.containsMouse || ma.pressed ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.7) : ColorUtils.applyAlpha(Appearance.colors.color15, 0.22)
            Behavior on border.color { ColorAnimation { duration: Appearance.dur(160) } }
            scale: ma.pressed ? 0.985 : 1
            Behavior on scale { NumberAnimation { duration: Appearance.dur(120) } }

            Item {
                x: (tile.w - tile.fullW) / 2
                width: tile.fullW; height: tile.fullH
                opacity: tile.content
                transform: Translate { y: (1 - tile.content) * 8 }
                // titre de la carte
                RowLayout {
                    id: head
                    x: 16; y: 12; width: parent.width - 32
                    spacing: 8
                    Text { text: root.icons[tile.kind] || ""; font.family: Appearance.font.family; font.pixelSize: 14; color: Appearance.colors.accent }
                    Text { Layout.fillWidth: true; text: root.titles[tile.kind] || ""
                           font.family: Appearance.font.family; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.5
                           font.capitalization: Font.AllUppercase; color: Appearance.colors.dim }
                    Text { text: "󰁔"; font.family: Appearance.font.family; font.pixelSize: 13; color: Appearance.colors.dim; opacity: ma.containsMouse ? 1 : 0.4 }
                }
                Loader {
                    id: ld
                    x: 16; y: head.y + head.height + 10
                    width: parent.width - 32
                    sourceComponent: root.cards[tile.kind]
                }
            }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: SysData.open(tile.kind) }
        }
    }
}
