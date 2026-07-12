import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../Common/"
import "../Common/functions/"

// GameTab — grille de jeux tactile, basée sur le backend du game-launcher.
// Appelle game-launcher/modules/service/backend.py (sortie JSON { games: [...] }),
// affiche les jaquettes, lance le jeu au tap via son `exec`.
Item {
    id: root

    readonly property string _backend:
        Quickshell.env("HOME") + "/.config/quickshell/game-launcher/modules/service/backend.py"
    // Wrapper qui force le lancement sur l'écran principal (pas le tactile).
    readonly property string _launcher:
        Quickshell.env("HOME") + "/.config/quickshell/Quick-Bar/Bar/Scripts/launch-main.sh"

    property var  games:   []
    property bool loading:  false
    property bool loaded:   false

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

    // Chargement paresseux à la première ouverture de l'onglet.
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
        spacing: 10

        // En-tête : compteur + rafraîchir
        Row {
            width: parent.width
            spacing: 10
            Text {
                text: "󰊴  Jeux"
                font.family: Appearance.font.family; font.pixelSize: 18; font.weight: Font.Bold
                color: Appearance.colors.fg
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.loading ? "chargement…" : (root.games.length + " jeux")
                font.family: Appearance.font.family; font.pixelSize: 12
                color: Appearance.colors.dim
                anchors.verticalCenter: parent.verticalCenter
            }
            Item { width: parent.width - 340; height: 1 }
            Rectangle {
                width: 110; height: 32; radius: 8
                color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.5)
                border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
                Text {
                    anchors.centerIn: parent; text: "󰑐  Rafraîchir"
                    font.family: Appearance.font.family; font.pixelSize: 12; color: Appearance.colors.fg
                }
                MouseArea { anchors.fill: parent; onClicked: root._load() }
            }
        }

        // Étagère horizontale : grandes jaquettes qui remplissent la hauteur.
        ListView {
            id: shelf
            width: parent.width
            height: parent.height - 42
            clip: true
            orientation: ListView.Horizontal
            spacing: 18
            model: root.games
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 1600
            flickDeceleration: 6000

            delegate: Item {
                required property var modelData
                height: shelf.height
                width:  Math.round(shelf.height * 0.66)   // ratio jaquette 2:3

                ClippingRectangle {
                    id: cardBg
                    anchors.fill: parent
                    radius: 16
                    color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.6)
                    border.color: tapArea.pressed ? Appearance.colors.accent : Qt.rgba(1, 1, 1, 0.10)
                    border.width: tapArea.pressed ? 2 : 1
                    scale: tapArea.pressed ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                    Image {
                        anchors.fill: parent
                        source: modelData.image || ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        // cache:false → la texture est libérée quand le delegate/onglet
                        // est détruit (re-décodée depuis le disque au besoin).
                        cache: false
                        // Plafonne la mémoire texture des jaquettes (décodées à la
                        // taille d'affichage, pas en pleine résolution).
                        sourceSize.height: 512
                        visible: status === Image.Ready
                    }
                    // Fallback si pas de jaquette : nom centré
                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 24
                        visible: !modelData.image
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: modelData.name || ""
                        font.family: Appearance.font.family; font.pixelSize: 18
                        color: Appearance.colors.fg
                    }
                    // Bandeau nom en bas (dégradé)
                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 80
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.88) }
                        }
                        Text {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                            text: modelData.name || ""
                            elide: Text.ElideRight
                            font.family: Appearance.font.family; font.pixelSize: 16; font.weight: Font.Bold
                            color: "#ffffff"
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

    // État de chargement / vide
    Text {
        anchors.centerIn: parent
        visible: root.games.length === 0
        font.family: Appearance.font.family; font.pixelSize: 14
        color: Appearance.colors.dim
        text: root.loading ? "Scan des jeux…" : "Aucun jeu trouvé."
    }
}
