import QtQuick
import QtQuick.Layouts
import qs.components
import qs.core
import qs.core.functions

// StreamDeck — onglet Apps : lanceurs en sections, une carte par section (même ouverture
// que les cartes de survol de la barre, en cascade). Données : core/AppDeck.qml
// (user_data/streamdeck.json), éditées dans Réglages › Apps ; taille et libellés : [apps].
Item {
    id: root
    readonly property bool shown: visible && width > 0
    property int cascade: 0
    onShownChanged: if (shown && Appearance.morphPages) cascade++

    readonly property int ts: AppDeck.tileSize
    function secColor(s) { return AppDeck.color(s.accent) }

    Flickable {
        anchors.fill: parent
        contentHeight: row.implicitHeight + 4
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        RowLayout {
            id: row
            width: parent.width
            spacing: 16
            Repeater {
                model: AppDeck.sections
                delegate: MorphCard {
                    id: sec
                    required property var modelData
                    required property int index
                    readonly property color col: root.secColor(modelData)
                    readonly property var items: modelData.items || []
                    Layout.fillWidth: true
                    Layout.preferredWidth: Math.max(1, items.length ? 1 : 0.4)
                    Layout.alignment: Qt.AlignTop
                    order: index
                    hotColor: col
                    contentHeight: grid.y + grid.implicitHeight + 18
                    Connections { target: root; function onCascadeChanged() { sec.play() } }

                    // En-tête : pastille de couleur, nom, nombre d'applis
                    RowLayout {
                        id: head
                        x: 18; y: 14; width: parent.width - 36
                        spacing: 10
                        Rectangle { width: 10; height: 10; radius: 5; color: sec.col }
                        Text { Layout.fillWidth: true; text: sec.modelData.title || "Apps"; elide: Text.ElideRight
                               font.family: Appearance.font.family; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 1.8
                               font.capitalization: Font.AllUppercase; color: sec.col }
                        Text { text: sec.items.length; font.family: "JetBrains Mono"; font.pixelSize: 11; color: Appearance.colors.dim }
                    }
                    Rectangle { x: 18; y: head.y + head.height + 10; width: parent.width - 36; height: 1
                                gradient: Gradient { orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: ColorUtils.applyAlpha(sec.col, 0.5) }
                                    GradientStop { position: 1; color: "transparent" } } }

                    // Tuiles (s'enroulent dans la largeur de la carte)
                    Flow {
                        id: grid
                        x: 18; y: head.y + head.height + 22; width: parent.width - 36
                        spacing: 12
                        Repeater {
                            model: sec.items
                            delegate: Tile { required property var modelData; app: modelData; col: sec.col }
                        }
                    }
                }
            }
        }
    }

    // Une appli : logo (thème d'icônes ou chemin), glyphe de secours, libellé ; ondulation au toucher
    component Tile: Item {
        id: tile
        property var app: ({})
        property color col: Appearance.colors.accent
        readonly property bool custom: (app.color || "") !== ""
        width: Math.round(root.ts * 1.12); height: root.ts

        Rectangle {
            id: face
            anchors.fill: parent
            radius: 16
            clip: true
            color: tile.custom ? tile.app.color
                 : ma.pressed ? ColorUtils.applyAlpha(tile.col, 0.20)
                 : ma.containsMouse ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.07) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.035)
            border.width: 1
            border.color: ma.containsMouse || ma.pressed ? ColorUtils.applyAlpha(tile.col, 0.75) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.07)
            Behavior on color { ColorAnimation { duration: Appearance.dur(140) } }
            Behavior on border.color { ColorAnimation { duration: Appearance.dur(140) } }
            scale: ma.pressed ? 0.94 : 1
            Behavior on scale { NumberAnimation { duration: Appearance.dur(110); easing.type: Easing.OutCubic } }

            // ondulation depuis le point touché
            Rectangle {
                id: ripple
                property real cx: 0; property real cy: 0
                x: cx - width / 2; y: cy - height / 2
                width: 0; height: width; radius: width / 2
                color: ColorUtils.applyAlpha(tile.col, 0.35)
                opacity: 0
            }
            ParallelAnimation {
                id: rippleAnim
                NumberAnimation { target: ripple; property: "width"; from: 0; to: tile.width * 2.4; duration: Appearance.dur(520); easing.type: Easing.OutCubic }
                NumberAnimation { target: ripple; property: "opacity"; from: 1; to: 0; duration: Appearance.dur(520); easing.type: Easing.InQuad }
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 16
                spacing: 8
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    readonly property int sz: Math.round(root.ts * (AppDeck.labels ? 0.42 : 0.52))
                    Layout.preferredWidth: sz; Layout.preferredHeight: sz
                    Image {
                        id: logo
                        anchors.fill: parent
                        source: AppDeck.iconSource(tile.app.appicon)
                        sourceSize: Qt.size(parent.sz * 2, parent.sz * 2)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true; smooth: true; mipmap: true
                        visible: status === Image.Ready
                        scale: ma.containsMouse ? 1.08 : 1
                        Behavior on scale { NumberAnimation { duration: Appearance.dur(180); easing.type: Easing.OutBack } }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !logo.visible
                        text: tile.app.icon || "󰀻"
                        font.family: Appearance.font.family; font.pixelSize: parent.sz * 0.85
                        color: tile.custom ? "#ffffff" : tile.col
                    }
                }
                Text {
                    visible: AppDeck.labels
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: tile.app.label || ""
                    font.family: Appearance.font.family; font.pixelSize: Math.max(11, Math.round(root.ts * 0.11))
                    color: tile.custom ? "#ffffff" : Appearance.colors.fg
                }
            }
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: (e) => { ripple.cx = e.x; ripple.cy = e.y; rippleAnim.restart() }
            onClicked: { AppDeck.launch(tile.app.exec); GameBreak.extend() }
        }
    }

    // État vide
    Column {
        anchors.centerIn: parent
        visible: AppDeck.sections.length === 0
        spacing: 14
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰀻"; font.family: Appearance.font.family; font.pixelSize: 48; color: Appearance.colors.dim }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Aucune appli — ajoute-les dans Réglages › Apps"
               font.family: Appearance.font.family; font.pixelSize: 16; color: Appearance.colors.dim }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: openTxt.implicitWidth + 36; height: 46; radius: 14
            color: Appearance.colors.accent
            Text { id: openTxt; anchors.centerIn: parent; text: "󰒓  Ouvrir les réglages"; font.family: Appearance.font.family; font.pixelSize: 15
                   font.weight: Font.Bold; color: Appearance.textOn(Appearance.colors.accent) }
            MouseArea { anchors.fill: parent; onClicked: { Popups.closeAll(); Popups.settingsPage = "apps"; Popups.settingsOpen = true } }
        }
    }
}
