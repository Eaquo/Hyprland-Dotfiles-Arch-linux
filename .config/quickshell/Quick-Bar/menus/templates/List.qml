import QtQuick
import QtQuick.Effects
import qs.core
import qs.core.functions

// List — une ligne par choix. Tabulations = colonnes (largeur selon la plus longue).
// Métadonnées lues : icon (nom ou chemin), glyph (Nerd Font), sub (à droite), nonselectable (titre de section).
Item {
    id: t
    required property var menu
    // contrat avec le cadre (panels/Menu.qml)
    property real prefW: 780
    property real rowH: menu.req.rowHeight > 0 ? menu.req.rowHeight : 58
    property int rows: 9
    property int cols: menu.req.columns > 0 ? menu.req.columns : 1
    property int minRows: 0         // hauteur minimale (Files : l'aperçu garde sa taille quand on filtre)
    readonly property real contentH: Math.max(minRows, Math.min(Math.ceil(menu.items.length / cols), rows)) * rowH
    property bool filter: true
    property bool search: true
    property string hints: "↑↓ choisir  ·  entrée valider"
    // emplacement libre à droite (Files y met l'aperçu)
    property real listW: width
    default property alias side: sideBox.data

    Item { id: sideBox; x: t.listW; width: t.width - t.listW; height: t.height }

    GridView {
        id: list
        width: t.listW; height: t.height
        cellWidth: Math.floor(width / t.cols); cellHeight: t.rowH
        model: t.menu.items
        currentIndex: t.menu.cur
        // en haut de liste : garder le titre de section visible au-dessus du 1er élément
        function goTop() { if (currentIndex <= t.cols) Qt.callLater(() => list.positionViewAtBeginning()) }
        onCurrentIndexChanged: goTop()
        onCountChanged: goTop()
        Timer { running: true; interval: 80; onTriggered: list.goTop() }
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        readonly property var colW: {
            const n = []
            t.menu.items.slice(0, 200).forEach(it => it.t.split("\t").forEach((c, i) => n[i] = Math.max(n[i] || 0, Math.min(c.length, 48))))
            const tot = n.reduce((a, b) => a + b, 0) || 1
            return n.map(x => x / tot)
        }
        delegate: Item {
            id: row
            required property var modelData
            required property int index
            readonly property bool on: index === t.menu.cur
            readonly property bool head: t.menu.isHead(modelData)
            readonly property var cells: modelData.t.split("\t")
            width: list.cellWidth; height: t.rowH
            opacity: t.menu.settled ? 1 : 0
            transform: Translate { id: rowT }
            Component.onCompleted: if (!t.menu.settled) appear.start()
            SequentialAnimation {
                id: appear
                PauseAnimation { duration: Math.min(row.index, 12) * 22 }
                ParallelAnimation {
                    NumberAnimation { target: row; property: "opacity"; to: 1; duration: Appearance.dur(200) }
                    NumberAnimation { target: rowT; property: "x"; from: -14; to: 0; duration: Appearance.dur(260); easing.type: Easing.OutCubic }
                }
            }
            // sélection comme SUPER+MAJ+G : la ligne se soulève, contour lumineux, ombre colorée
            Rectangle {
                visible: !row.head
                anchors.fill: parent; anchors.margins: 4
                radius: t.menu.rad(height)
                transform: Translate { y: row.on ? -2 : 0; Behavior on y { NumberAnimation { duration: Appearance.dur(180); easing.type: Easing.OutCubic } } }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: ColorUtils.applyAlpha(Appearance.colors.fg, row.on ? 0.06 : 0.035) }
                    GradientStop { position: 1.0; color: ColorUtils.applyAlpha(Appearance.colors.fg, row.on ? 0.03 : 0.01) }
                }
                border.width: row.on ? 2 : 1
                border.color: row.on ? ColorUtils.applyAlpha(t.menu.glow, 0.7) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.06)
            }
            Row {
                x: row.head ? 10 : 22 + (row.on ? 6 : 0)
                Behavior on x { NumberAnimation { duration: Appearance.dur(160); easing.type: Easing.OutCubic } }
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Item {
                    id: ico
                    visible: !row.head && (!!row.modelData.icon || !!row.modelData.glyph)
                    width: 30; height: 30
                    anchors.verticalCenter: parent.verticalCenter
                    scale: row.on ? 1.15 : 1
                    Behavior on scale { NumberAnimation { duration: Appearance.dur(160) } }
                    Image { anchors.fill: parent; visible: !!row.modelData.icon; sourceSize: Qt.size(60, 60); asynchronous: true
                            fillMode: Image.PreserveAspectCrop; source: t.menu.iconSrc(row.modelData.icon) }
                    Text { anchors.centerIn: parent; visible: !row.modelData.icon; text: row.modelData.glyph || ""
                           font.family: Appearance.font.family; font.pixelSize: 22; color: row.on ? t.menu.glow : Appearance.colors.fg }
                }
                Repeater {
                    model: row.cells
                    delegate: Text {
                        required property string modelData
                        required property int index
                        readonly property real avail: row.width - 60 - (ico.visible ? 42 : 0) - (row.modelData.sub ? row.width * 0.3 : 0)
                        width: row.cells.length > 1 ? Math.max(40, avail * (list.colW[index] || 0.2)) : avail
                        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                        text: row.head ? modelData : t.menu.mark(modelData, "", row.on); elide: Text.ElideRight
                        textFormat: row.head ? Text.PlainText : Text.StyledText
                        font.family: Appearance.font.family
                        font.pixelSize: row.head ? 12 : index === 0 ? 16 : 14
                        font.weight: row.head ? Font.Bold : index === 0 && row.on ? Font.DemiBold : Font.Normal
                        font.letterSpacing: row.head ? 2 : 0
                        color: row.head ? t.menu.glow : index === 0 ? (row.on ? t.menu.glow : Appearance.colors.fg) : Appearance.colors.dim
                    }
                }
            }
            Text {
                visible: !!row.modelData.sub && !row.head
                anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                width: parent.width * 0.3; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                text: row.modelData.sub || ""; font.family: Appearance.font.family; font.pixelSize: 13; color: Appearance.colors.dim
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true; enabled: !row.head
                cursorShape: Qt.PointingHandCursor
                onEntered: if (t.menu.hoverReady) t.menu.cur = row.index
                onClicked: t.menu.choose(row.index)
            }
        }
    }
}
