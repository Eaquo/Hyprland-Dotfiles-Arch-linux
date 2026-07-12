import QtQuick
import Quickshell
import Quickshell.Io
import "../Common/"
import "../Common/functions/"

// StreamDeck — grille tactile de lanceurs, façon Elgato Stream Deck, en sections.
// Piloté par user_data/streamdeck.json :
//   [{ "title": "Dev", "items": [{ icon, label, exec, color }, …] }, …]
// (un simple tableau plat reste accepté → une seule section sans titre.)
// Édite le fichier → mise à jour à chaud (watchChanges).
Item {
    id: root

    readonly property string _path:
        Quickshell.env("HOME") + "/.config/quickshell/Quick-Bar/user_data/streamdeck.json"
    // Wrapper qui force l'ouverture sur l'écran principal (pas le tactile).
    readonly property string _launcher:
        Quickshell.env("HOME") + "/.config/quickshell/Quick-Bar/Bar/Scripts/launch-main.sh"

    property var sections: []

    // Palette wallust vive, éclaircie pour rester lisible sur fond sombre.
    readonly property var _wpal: [
        Appearance.colors.color4,  Appearance.colors.color5,  Appearance.colors.color6,
        Appearance.colors.color9,  Appearance.colors.color10, Appearance.colors.color11,
        Appearance.colors.color12, Appearance.colors.color13, Appearance.colors.color14
    ]

    function _parse(txt) {
        try {
            var d = JSON.parse(txt)
            if (Array.isArray(d) && d.length > 0 && d[0] && d[0].items !== undefined)
                root.sections = d                                   // format sections
            else if (Array.isArray(d))
                root.sections = [{ title: "", items: d }]           // ancien format plat
            else
                root.sections = []
        } catch (e) { root.sections = [] }
    }
    function _launch(cmd) {
        if (!cmd || cmd.length === 0) return
        runProc.command = ["bash", root._launcher, cmd]
        runProc.running = false
        runProc.running = true
    }

    property var _fv: FileView {
        path:          "file://" + root._path
        watchChanges:  true
        onFileChanged: reload()
        onLoaded:      root._parse(text())
    }
    property var _runProc: Process { id: runProc }

    Flickable {
        anchors.fill: parent
        contentHeight: sectionRow.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // Sections = colonnes verticales côte à côte (Dev | Gaming | Other).
        Row {
            id: sectionRow
            width: parent.width
            spacing: 20
            readonly property real colW:
                (width - spacing * Math.max(0, root.sections.length - 1)) / Math.max(1, root.sections.length)

            Repeater {
                model: root.sections
                delegate: Column {
                    id: secDelegate
                    required property var modelData
                    width: sectionRow.colW
                    spacing: 12

                    // Couleur de la section : `accent` = index de la palette wallust
                    // (ex. Dev=4, Gaming=6, Média=8, Other=10), éclaircie. Sert au
                    // titre ET aux bordures/teintes/icônes des tuiles.
                    readonly property color secWcol:
                        Qt.lighter(Appearance.colors["color" + (modelData.accent !== undefined ? modelData.accent : 11)], 1.35)

                    // Titre de section
                    Row {
                        visible: (modelData.title || "") !== ""
                        width: parent.width
                        spacing: 10
                        Text {
                            id: secTitle
                            text: modelData.title || ""
                            font.family: Appearance.font.family; font.pixelSize: 15
                            font.weight: Font.Bold
                            color: secDelegate.secWcol
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - secTitle.implicitWidth - 10; height: 1
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }
                    }

                    // Tuiles de la section (s'enroulent dans la largeur de la colonne)
                    Flow {
                        width: parent.width
                        spacing: 16
                        Repeater {
                            model: modelData.items
                            delegate: Rectangle {
                                id: tile
                                required property var modelData
                                readonly property bool hasColor: (modelData.color || "") !== ""
                                // Couleur de la section (fixe pour toute la colonne).
                                readonly property color wcol: secDelegate.secWcol
                                width: 150; height: 130
                                radius: 18
                                color: hasColor ? modelData.color
                                                : ColorUtils.applyAlpha(wcol, 0.16)
                                border.color: hasColor ? Qt.rgba(1, 1, 1, 0.08)
                                                       : ColorUtils.applyAlpha(wcol, 0.5)
                                border.width: 1
                                scale: tapArea.pressed ? 0.94 : 1
                                Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 10
                                    // Vrai logo de l'app (image://icon, résolu via le thème comme
                                    // rofi) ; le glyphe Nerd Font sert de secours.
                                    Item {
                                        width: 52; height: 52
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        Image {
                                            id: appImg
                                            anchors.fill: parent
                                            visible: (tile.modelData.appicon || "") !== "" && status === Image.Ready
                                            // appicon = nom d'icône du thème OU chemin absolu (/…).
                                            source: {
                                                var a = tile.modelData.appicon || ""
                                                if (a === "") return ""
                                                return a.charAt(0) === "/" ? "file://" + a
                                                                           : "image://icon/" + a
                                            }
                                            sourceSize.width: 104; sourceSize.height: 104
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            visible: !appImg.visible
                                            text: tile.modelData.icon || "󰀻"
                                            font.family: Appearance.font.family; font.pixelSize: 46
                                            color: tile.hasColor ? "#ffffff" : tile.wcol
                                        }
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: modelData.label || ""
                                        font.family: Appearance.font.family; font.pixelSize: 15
                                        color: tile.hasColor ? "#ffffff" : Appearance.colors.fg
                                    }
                                }
                                MouseArea {
                                    id: tapArea
                                    anchors.fill: parent
                                    onClicked: root._launch(modelData.exec)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // État vide
    Text {
        anchors.centerIn: parent
        width: parent.width - 80
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        visible: root.sections.length === 0
        font.family: Appearance.font.family; font.pixelSize: 14
        color: Appearance.colors.dim
        text: "Aucune tuile.\nÉdite ~/.config/quickshell/Quick-Bar/user_data/streamdeck.json"
    }
}
