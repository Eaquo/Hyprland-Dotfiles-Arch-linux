import QtQuick
import Quickshell
import Quickshell.Io
import "../Common/"
import "../Common/functions/"

// RgbTab — onglet RGB (OpenRGB), consolidé depuis l'ancien rgb-launcher.
// Liste les modes via Bar/Scripts/rgb/backend.py (config.toml) et les applique au
// tap via launch_rgb_mode.sh (détaché, tue l'ancien mode). Couleurs = wallust.
Item {
    id: root

    readonly property string _dir:
        Quickshell.env("HOME") + "/.config/quickshell/Quick-Bar/Bar/Scripts/rgb"

    property var  modes:   []
    property bool loading:  false
    property bool loaded:   false
    property string current: ""   // arg du mode actif (ex. "cava", "sequence_2")
    // Nom lisible du mode actif (via config), pour l'afficher au centre de l'en-tête.
    readonly property string currentName: {
        for (var i = 0; i < modes.length; i++) {
            var p = String(modes[i].command || "").trim().split(/\s+/)
            if (p[p.length - 1] === root.current) return modes[i].name
        }
        return ""
    }

    function _load() {
        if (root.loading) return
        root.loading = true
        backendProc.running = false
        backendProc.running = true
    }
    // On écrit seulement le mode dans sequence.txt : le watch daemon (seul maître)
    // arrête l'ancien contrôleur et lance le nouveau → un seul contrôleur, plus de
    // course qui bloque un ventilo/la RAM.
    function _writeSeq(arg) {
        applyProc.command = ["bash", "-c",
            "echo " + arg + " > '" + root._dir + "/script/conf/sequence.txt'"]
        applyProc.running = false
        applyProc.running = true
    }
    function _apply(cmd) {
        if (!cmd) return
        var parts = String(cmd).trim().split(/\s+/)
        var arg = parts[parts.length - 1]        // ex. "sequence_1", "off"
        root._writeSeq(arg)
        root.current = arg
    }
    // Nom de couleur wallust (color9, foreground…) → couleur éclaircie.
    function _wc(name) {
        var c
        if (!name) c = Appearance.colors.accent
        else if (name === "foreground") c = Appearance.colors.fg
        else c = Appearance.colors["color" + (name.indexOf("color") === 0 ? name.substring(5) : "11")]
        if (!c) c = Appearance.colors.accent
        return Qt.lighter(c, 1.25)
    }

    // ── Luminosité ─────────────────────────────────────────────────────────────
    // Écrite dans conf/brightness.txt, relue en direct par le moteur (par frame) →
    // les modes animés suivent en live ; on ré-applique le mode courant au
    // relâchement pour que les couleurs fixes se mettent aussi à jour.
    property int brightness: 100
    function setBrightness(v) {
        root.brightness = Math.round(Math.max(0, Math.min(100, v)))
        bwThrottle.restart()
    }
    function _writeBrightness() {
        bwProc.command = ["bash", "-c",
            "echo " + root.brightness + " > '" + root._dir + "/script/conf/brightness.txt'"]
        bwProc.running = false
        bwProc.running = true
    }
    function reapplyCurrent() {
        root._writeBrightness()
        // Couleurs fixes : ne relisent pas la luminosité en continu → re-déclencher
        // le mode. Modes animés : luminosité live, inutile (évite un flicker).
        if (root.current.indexOf("fixed_") === 0)
            root._writeSeq(root.current)
    }
    property var _bwProc: Process { id: bwProc }
    property var _bwThrottle: Timer { id: bwThrottle; interval: 60; onTriggered: root._writeBrightness() }
    property var _bwFile: FileView {
        path: "file://" + root._dir + "/script/conf/brightness.txt"
        onLoaded: { var v = parseInt(text()); if (!isNaN(v)) root.brightness = v }
    }
    // Suit le mode réellement actif (écrit par le contrôleur) → nom à jour même
    // s'il a été changé ailleurs.
    property var _seqFile: FileView {
        path: "file://" + root._dir + "/script/conf/sequence.txt"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { var v = text().trim(); if (v) root.current = v }
    }

    onVisibleChanged: if (visible && !root.loaded && !root.loading) _load()
    Component.onCompleted: if (visible) _load()

    property var _backendProc: Process {
        id: backendProc
        command: ["python3", root._dir + "/backend.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text)
                    root.modes = (d && d.modes) ? d.modes : []
                } catch (e) { root.modes = [] }
                root.loading = false
                root.loaded  = true
            }
        }
    }
    property var _applyProc: Process { id: applyProc }

    Column {
        anchors.fill: parent
        spacing: 12

        // En-tête : titre (gauche) · thème actif (centre) · Rafraîchir (droite)
        Item {
            width: parent.width
            height: 34

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Text {
                    text: "󰌵  RGB"
                    font.family: Appearance.font.family; font.pixelSize: 18; font.weight: Font.Bold
                    color: Appearance.colors.fg
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root.loading ? "chargement…" : (root.modes.length + " modes")
                    font.family: Appearance.font.family; font.pixelSize: 12
                    color: Appearance.colors.dim
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Thème actif, centré
            Text {
                anchors.centerIn: parent
                visible: root.currentName !== ""
                text: "󰐌  " + root.currentName
                font.family: Appearance.font.family; font.pixelSize: 25; font.weight: Font.Bold
                color: Appearance.colors.dim
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
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

        // ── Barre de luminosité ──────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 40

            Row {
                anchors.fill: parent
                spacing: 14

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    text: root.brightness < 34 ? "󰃞" : (root.brightness < 67 ? "󰃟" : "󰃠")
                    font.family: Appearance.font.family; font.pixelSize: 26
                    color: Appearance.colors.accent
                }

                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 30 - 46 - 28
                    height: 12; radius: 6
                    color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.6)
                    border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

                    Rectangle {   // remplissage jusqu'au centre de la poignée
                        width: knob.x + knob.width / 2
                        height: parent.height; radius: parent.radius
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: ColorUtils.applyAlpha(Appearance.colors.dim, 0.55) }
                            GradientStop { position: 0.5; color: ColorUtils.applyAlpha(Appearance.colors.color4, 0.55) }
                            GradientStop { position: 1.0; color: Appearance.colors.accent }
                        }
                    }
                    Rectangle {   // poignée — reste toujours dans le track (0→100%)
                        id: knob
                        x: (track.width - width) * root.brightness / 100
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24; height: 24; radius: 12
                        color: Qt.lighter(Appearance.colors.accent, 1.2)
                        border.color: Appearance.colors.bg; border.width: 2
                        scale: barArea.pressed ? 1.15 : 1
                        Behavior on scale { NumberAnimation { duration: 90 } }
                    }
                    MouseArea {
                        id: barArea
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 44                       // zone tactile confortable
                        preventStealing: true
                        onPressed:         (m) => root.setBrightness(m.x / track.width * 100)
                        onPositionChanged: (m) => root.setBrightness(m.x / track.width * 100)
                        onReleased:        root.reapplyCurrent()
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 46
                    horizontalAlignment: Text.AlignRight
                    text: root.brightness + "%"
                    font.family: "JetBrains Mono"; font.pixelSize: 15; font.weight: Font.Bold
                    color: Appearance.colors.fg
                }
            }
        }

        GridView {
            id: grid
            width: parent.width
            height: parent.height - 96
            clip: true
            cellWidth:  Math.floor(width / Math.max(1, Math.floor(width / 300)))
            cellHeight: 240
            model: root.modes
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: cell
                required property var modelData
                width: grid.cellWidth; height: grid.cellHeight
                readonly property color mcol: root._wc(modelData.icon_color)
                readonly property string arg: {
                    var p = String(modelData.command || "").trim().split(/\s+/)
                    return p[p.length - 1]
                }
                readonly property bool isActive: root.current !== "" && root.current === arg
                readonly property bool isOff: arg === "off"

                Rectangle {
                    id: card
                    anchors { fill: parent; margins: 8 }
                    radius: 31
                    clip: true
                    color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.55)
                    border.color: cell.isActive ? cell.mcol : Qt.rgba(1, 1, 1, 0.08)
                    border.width: cell.isActive ? 2 : 1
                    scale: tapArea.pressed ? 0.96 : 1
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }

                    Column {
                        anchors.fill: parent

                        // ── Preview : glow dans la couleur du mode + icône ──
                        Rectangle {
                            width: parent.width
                            height: Math.round(card.height * 0.54)
                            radius: 31
                            gradient: Gradient {
                                GradientStop { position: 0.0
                                    color: cell.isOff ? Qt.rgba(1,1,1,0.05)
                                                      : ColorUtils.applyAlpha(cell.mcol, 0.85) }
                                GradientStop { position: 1.0
                                    color: cell.isOff ? Qt.rgba(1,1,1,0.02)
                                                      : ColorUtils.applyAlpha(cell.mcol, 0.10) }
                            }

                            Rectangle {   // cercle icône
                                anchors.centerIn: parent
                                width: 62; height: 62; radius: 31
                                color: Qt.rgba(0, 0, 0, 0.30)
                                border.color: ColorUtils.applyAlpha(cell.isOff ? Appearance.colors.fg : cell.mcol, 0.7)
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon || "󰌵"
                                    font.family: Appearance.font.family; font.pixelSize: 30
                                    color: cell.isOff ? Appearance.colors.fg : "#ffffff"
                                }
                            }

                            // Pastille "actif"
                            Rectangle {
                                visible: cell.isActive
                                anchors { top: parent.top; right: parent.right; margins: 8 }
                                width: 22; height: 22; radius: 11
                                color: cell.mcol
                                Text {
                                    anchors.centerIn: parent; text: "󰄬"
                                    font.family: Appearance.font.family; font.pixelSize: 13
                                    color: Appearance.colors.bg
                                }
                            }
                        }

                        // ── Texte ──
                        Item {
                            width: parent.width
                            height: parent.height - Math.round(card.height * 0.54)
                            Column {
                                anchors { fill: parent; margins: 12 }
                                spacing: 3
                                Text {
                                    width: parent.width
                                    text: modelData.name || ""
                                    elide: Text.ElideRight
                                    font.family: Appearance.font.family; font.pixelSize: 15; font.weight: Font.Bold
                                    color: cell.isActive ? cell.mcol : Appearance.colors.fg
                                }
                                Text {
                                    width: parent.width
                                    text: modelData.description || ""
                                    wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                                    font.family: Appearance.font.family; font.pixelSize: 11
                                    color: Appearance.colors.dim
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: tapArea
                        anchors.fill: parent
                        onClicked: root._apply(modelData.command)
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.modes.length === 0
        font.family: Appearance.font.family; font.pixelSize: 14
        color: Appearance.colors.dim
        text: root.loading ? "Chargement des modes…" : "Aucun mode RGB."
    }
}
