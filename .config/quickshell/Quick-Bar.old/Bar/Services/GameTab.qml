import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../Common/"
import "../Common/functions/"

// GameTab — grille de jeux tactile, basée sur le backend du game-launcher.
// Cartes façon onglet RGB (jaquette en preview + nom), barre de recherche.
// Lance le jeu au tap via son `exec` (sur l'écran principal).
Item {
    id: root

    readonly property string _backend:
        Quickshell.env("HOME") + "/.config/quickshell/game-launcher/modules/service/backend.py"
    readonly property string _launcher:
        Quickshell.env("HOME") + "/.config/quickshell/Quick-Bar/Bar/Scripts/launch-main.sh"

    property var  games:   []
    property bool loading:  false
    property bool loaded:   false
    property string filter: ""

    readonly property var filteredGames: {
        if (root.filter.trim() === "") return root.games
        var f = root.filter.toLowerCase()
        return root.games.filter(function (g) {
            return (g.name || "").toLowerCase().indexOf(f) !== -1
        })
    }

    function _load() {
        if (root.loading) return
        root.loading = true
        backendProc.running = false
        backendProc.running = true
    }
    function _launch(exec) {
        if (!exec || exec.length === 0) return
        runProc.command = ["bash", root._launcher, exec]
        runProc.running = false
        runProc.running = true
    }

    onVisibleChanged: if (visible && !root.loaded && !root.loading) _load()
    Component.onCompleted: if (visible) _load()

    property var _backendProc: Process {
        id: backendProc
        command: ["python3", root._backend]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text)
                    root.games = (d && d.games) ? d.games : []
                } catch (e) { root.games = [] }
                root.loading = false
                root.loaded  = true
            }
        }
    }
    property var _runProc: Process { id: runProc }

    Column {
        anchors.fill: parent
        spacing: 12

        // En-tête : titre + compteur · recherche · rafraîchir
        Item {
            width: parent.width
            height: 38

            Row {
                id: hLeft
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Text {
                    text: "󰊴  Jeux"
                    font.family: Appearance.font.family; font.pixelSize: 18; font.weight: Font.Bold
                    color: Appearance.colors.fg
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.loading ? "chargement…" : (root.filteredGames.length + " jeux")
                    font.family: Appearance.font.family; font.pixelSize: 12
                    color: Appearance.colors.dim
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                id: refreshBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 110; height: 34; radius: 8
                color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.5)
                border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
                Text {
                    anchors.centerIn: parent; text: "󰑐  Rafraîchir"
                    font.family: Appearance.font.family; font.pixelSize: 12; color: Appearance.colors.fg
                }
                MouseArea { anchors.fill: parent; onClicked: root._load() }
            }

            // Barre de recherche (compacte, centrée)
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: 340
                height: 34; radius: 10
                color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.5)
                border.color: search.activeFocus ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.6)
                                                 : Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                Text {
                    id: searchIcon
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    text: "󰍉"
                    font.family: Appearance.font.family; font.pixelSize: 15
                    color: Appearance.colors.dim
                }
                TextInput {
                    id: search
                    anchors { left: searchIcon.right; leftMargin: 8; right: clearBtn.left; rightMargin: 8
                              verticalCenter: parent.verticalCenter }
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Appearance.font.family; font.pixelSize: 13
                    color: Appearance.colors.fg
                    clip: true
                    onTextChanged: root.filter = text
                }
                Text {
                    anchors { left: searchIcon.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    visible: search.text.length === 0
                    text: "Rechercher un jeu…"
                    font.family: Appearance.font.family; font.pixelSize: 13
                    color: Qt.rgba(1, 1, 1, 0.3)
                }
                Text {   // effacer
                    id: clearBtn
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    visible: search.text.length > 0
                    text: "󰅖"
                    font.family: Appearance.font.family; font.pixelSize: 14
                    color: Appearance.colors.dim
                    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: { search.text = ""; search.forceActiveFocus() } }
                }
            }
        }

        GridView {
            id: grid
            width: parent.width
            height: parent.height - 50
            clip: true
            // Cartes larges (jaquettes paysage ~420×165).
            cellWidth:  Math.floor(width / Math.max(1, Math.floor(width / 380)))
            cellHeight: 210
            model: root.filteredGames
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 1400

            delegate: Item {
                id: cell
                required property var modelData
                width: grid.cellWidth; height: grid.cellHeight

                Rectangle {
                    id: card
                    anchors { fill: parent; margins: 12 }
                    radius: 26
                    clip: true
                    color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.55)
                    border.color: tapArea.pressed ? Appearance.colors.accent : Qt.rgba(1, 1, 1, 0.08)
                    border.width: tapArea.pressed ? 2 : 1
                    scale: tapArea.pressed ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                    // Glow / ombre douce pour faire ressortir la carte (accent au tap).
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: tapArea.pressed ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.85)
                                                     : Qt.rgba(0, 0, 0, 0.55)
                        shadowBlur: tapArea.pressed ? 0.9 : 0.5
                        shadowVerticalOffset: 5
                    }

                    Column {
                        anchors.fill: parent

                        // Preview = jaquette large
                        Rectangle {
                            width: parent.width
                            height: Math.round(card.height * 0.74)
                            color: ColorUtils.applyAlpha(Appearance.colors.color4, 0.60)

                            Image {
                                anchors.fill: parent
                                source: cell.modelData.image || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                                sourceSize.height: 300
                                visible: status === Image.Ready
                            }
                            Text {   // fallback sans jaquette
                                anchors.centerIn: parent
                                width: parent.width - 20
                                visible: !cell.modelData.image
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                text: cell.modelData.name || ""
                                font.family: Appearance.font.family; font.pixelSize: 15
                                color: Appearance.colors.color4
                            }
                        }

                        // Nom
                        Item {
                            width: parent.width
                            height: parent.height - Math.round(card.height * 0.74)
                            Text {
                                anchors { fill: parent; margins: 14 }
                                verticalAlignment: Text.AlignVCenter
                                text: cell.modelData.name || ""
                                elide: Text.ElideRight; wrapMode: Text.WordWrap; maximumLineCount: 2
                                font.family: Appearance.font.family; font.pixelSize: 14; font.weight: Font.Bold
                                color: Appearance.colors.fg
                            }
                        }
                    }

                    MouseArea {
                        id: tapArea
                        anchors.fill: parent
                        onClicked: root._launch(cell.modelData.exec)
                    }
                }
            }
        }
    }

    // État de chargement / vide
    Text {
        anchors.centerIn: parent
        visible: root.filteredGames.length === 0
        font.family: Appearance.font.family; font.pixelSize: 14
        color: Appearance.colors.dim
        text: root.loading ? "Scan des jeux…"
                           : (root.filter.trim() !== "" ? "Aucun résultat." : "Aucun jeu trouvé.")
    }
}
