import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Io
import "../Common/"
import "../Common/functions/"
import "../Components/"
import "system/"

// GameModeTab — page « Game » du TouchPanel, style « verre minimal ».
// Affichée automatiquement quand GameMode.active. Gauche : jeu, durée et
// mesures. Droite : panneau de verre du mixeur posé sur la bannière du jeu
// (GameMode.gameArt) — glisser une ligne = volume, tap sur le nom = muet.
Item {
    id: root

    readonly property string face: "Fira Sans"

    CpuService     { id: cpu;     active: root.visible }
    MemService     { id: mem;     active: root.visible }
    GpuService     { id: gpu;     active: root.visible }
    ThermalService { id: thermal; active: root.visible }

    // ── Audio ─────────────────────────────────────────────────────────────────
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var appStreams: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio)
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    PwObjectTracker { objects: (root.sink ? [root.sink] : []).concat(root.appStreams, root.outputs) }
    // Une ligne par application (un jeu peut ouvrir plusieurs flux audio).
    readonly property var appGroups: {
        const g = {}
        for (const n of appStreams) { const k = appName(n); (g[k] = g[k] || []).push(n) }
        return Object.keys(g).map(k => ({ label: k, nodes: g[k] }))
    }
    function appName(n) {
        const p = n.properties
        return (p && (p["application.name"] || p["media.name"])) || n.description || n.name || "App"
    }

    // ── Ping (jeux en ligne) : 1 ping toutes les 5 s vers 1.1.1.1 ─────────────
    property int ping: -1
    Process {
        id: pingProc
        command: ["sh", "-c", "LC_ALL=C ping -c1 -W1 1.1.1.1 | sed -n 's/.*time=\\([0-9.]*\\).*/\\1/p'"]
        stdout: StdioCollector { onStreamFinished: root.ping = text.trim() !== "" ? Math.round(parseFloat(text)) : -1 }
    }
    Timer { interval: 5000; repeat: true; triggeredOnStart: true; running: root.visible; onTriggered: pingProc.running = true }

    // ── Pics de la session (remis à zéro à chaque nouveau jeu) ────────────────
    property real peakCpuT: 0
    property real peakGpuT: 0
    property real peakCpu: 0
    Connections { target: GameMode; function onStartedAtChanged() { root.peakCpuT = 0; root.peakGpuT = 0; root.peakCpu = 0 } }
    Connections { target: thermal; function onCpuTempChanged() { root.peakCpuT = Math.max(root.peakCpuT, thermal.cpuTemp) }
                                   function onGpuTempChanged() { root.peakGpuT = Math.max(root.peakGpuT, thermal.gpuTemp) } }
    Connections { target: cpu; function onUsagePercentChanged() { root.peakCpu = Math.max(root.peakCpu, cpu.usagePercent) } }

    // ── Lecteur en cours (Spotify…) ───────────────────────────────────────────
    readonly property var player: {
        const ps = Mpris.players.values
        return ps.find(p => p.playbackState === MprisPlaybackState.Playing) || ps[0] || null
    }

    // ── Actions rapides ───────────────────────────────────────────────────────
    Process { id: shotProc }
    function screenshot() {
        // Écran principal seulement (le jeu), dossier des captures habituel.
        const mon = Quickshell.screens.find(s => (s.model || "").toUpperCase().indexOf("XENEON") === -1)
        shotProc.command = ["sh", "-c",
            "d=\"$(xdg-user-dir PICTURES)/Screenshots\"; mkdir -p \"$d\"; f=\"$d/$2_$(date +%Y%m%d_%H%M%S).png\"; " +
            "grim -o \"$1\" \"$f\" && notify-send -i \"$f\" 'Capture du jeu' \"$f\"",
            "_", mon ? mon.name : "", (GameMode.gameTitle || "game").replace(/[^A-Za-z0-9_-]/g, "")]
        shotProc.running = false
        shotProc.running = true
        GameBreak.extend()
    }
    function toggleRecord() {
        if (ScreenRecService.recording) ScreenRecService.stopRecording()
        else if (ShellState.screenRecord) ScreenRecService.cancelSetup()
        else ShellState.screenRecord = true
        GameBreak.extend()
    }

    // ── Couleurs du jeu (bannière) ; palette wallust s'il n'y en a pas ────────
    readonly property var gameCols: GameMode.gameColors.map(c => Qt.color(c))
    readonly property color gameAccent: gameCols.length ? gameCols[0] : Appearance.colors.color13

    // ── Durée de la session + temps de jeu cumulé ─────────────────────────────
    property int elapsedSec: 0
    function fmt(sec) {
        const m = Math.floor(sec / 60)
        return m >= 60 ? Math.floor(m / 60) + " h " + String(m % 60).padStart(2, "0") : m + " min"
    }
    readonly property string elapsed: fmt(elapsedSec)
    // La session en cours compte dans « aujourd'hui » si elle a commencé aujourd'hui.
    readonly property bool startedToday: GameMode.startedAt !== null
        && new Date(GameMode.startedAt).toDateString() === new Date().toDateString()
    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: root.visible && GameMode.startedAt !== null
        onTriggered: root.elapsedSec = Math.floor((new Date() - GameMode.startedAt) / 1000)
    }

    component Metric: Column {
        property string label
        property string value
        property string peak: ""        // ex. « pic 74° » (vide = rien)
        property real ratio: 0          // 0..1 pour la ligne
        spacing: 6
        Text {
            text: parent.value
            font.family: root.face; font.pixelSize: 46; font.weight: Font.DemiBold
            color: Appearance.colors.fg
        }
        Text {
            text: parent.label
            font.family: root.face; font.pixelSize: 13; font.letterSpacing: 3
            color: Appearance.colors.dim
        }
        Rectangle {
            width: 120; height: 4; radius: 2
            color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.12)
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, parent.parent.ratio)); height: parent.height; radius: 2
                color: Appearance.colors.fg
                Behavior on width { NumberAnimation { duration: 300 } }
            }
        }
        Text {
            visible: parent.peak !== ""
            text: parent.peak
            font.family: root.face; font.pixelSize: 13
            color: Appearance.colors.dim
        }
    }

    // Bouton rond d'action (verre)
    component Action: Rectangle {
        property string glyph
        property string hint
        property bool on: false
        signal tap()
        width: 56; height: 56; radius: 28
        color: on ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.85) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.12)
        border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.18)
        Behavior on color { ColorAnimation { duration: 140 } }
        Text {
            anchors.centerIn: parent; text: parent.glyph
            font.family: Appearance.font.family; font.pixelSize: 24
            color: parent.on ? Appearance.colors.bg : Appearance.colors.fg
        }
        MouseArea { anchors.fill: parent; onClicked: parent.tap() }
    }

    // Ligne du mixeur : nom (tap = muet) · piste (glisser = volume) · valeur
    component MixRow: Item {
        id: row
        property var nodes: []          // tous les flux réglés ensemble
        readonly property var node: nodes.length ? nodes[0] : null
        property string label
        readonly property real vol: node?.audio ? node.audio.volume : 0
        readonly property bool muted: node?.audio ? node.audio.muted : false
        Layout.fillWidth: true
        implicitHeight: 52
        Text {
            id: rowName
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 170
            text: row.muted ? "󰖁  " + row.label : row.label
            font.family: root.face; font.pixelSize: 20
            color: row.muted ? Appearance.colors.dim : Appearance.colors.fg
            elide: Text.ElideRight
            MouseArea {
                anchors.fill: parent; anchors.margins: -8
                onClicked: if (row.node?.audio) {
                    const m = !row.node.audio.muted
                    for (const n of row.nodes) if (n.audio) n.audio.muted = m
                    GameBreak.extend()
                }
            }
        }
        Text {
            id: rowVal
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 56; horizontalAlignment: Text.AlignRight
            text: Math.round(row.vol * 100)
            font.family: root.face; font.pixelSize: 20
            color: Appearance.colors.dim
        }
        Rectangle {
            anchors { left: rowName.right; right: rowVal.left; leftMargin: 16; rightMargin: 16; verticalCenter: parent.verticalCenter }
            height: 26; radius: 13
            color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.12)
            Rectangle {
                width: Math.max(parent.height, parent.width * Math.min(1, row.vol)); height: parent.height; radius: 13
                color: ColorUtils.applyAlpha(Appearance.colors.fg, row.muted ? 0.25 : 0.8)
                Behavior on width { NumberAnimation { duration: 80 } }
            }
            MouseArea {
                anchors.fill: parent; anchors.topMargin: -12; anchors.bottomMargin: -12
                preventStealing: true
                function set(m) {
                    const v = Math.max(0, Math.min(1, m.x / width))
                    for (const n of row.nodes) if (n.audio) n.audio.volume = v
                    GameBreak.extend()
                }
                onPressed: (m) => set(m)
                onPositionChanged: (m) => set(m)
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 48

        // ══ Gauche : jeu + mesures ══
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: 960
            Layout.fillWidth: false
            spacing: 0

            Row {
                spacing: 14
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12; height: 12; radius: 6
                    color: root.gameAccent
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.gameAccent; shadowBlur: 1.0 }
                    SequentialAnimation on opacity {
                        running: GameMode.active; loops: Animation.Infinite
                        NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1;    duration: 900; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    text: (GameMode.active ? "EN JEU  ·  " + root.elapsed : "AUCUN JEU EN COURS").toUpperCase()
                    font.family: root.face; font.pixelSize: 16; font.letterSpacing: 6
                    color: Appearance.colors.dim
                }
            }

            Item { Layout.fillHeight: true }

            // Logo officiel du jeu (cache Steam) ; nom en texte s'il n'y en a pas.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 200
                Image {
                    id: logo
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: Math.min(parent.width, 820); height: parent.height
                    source: GameMode.active ? GameMode.gameLogo : ""
                    sourceSize.width: 1600
                    fillMode: Image.PreserveAspectFit
                    horizontalAlignment: Image.AlignLeft
                    asynchronous: true
                    visible: status === Image.Ready
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true; shadowColor: "black"
                        shadowBlur: 0.6; shadowOpacity: 0.6; shadowVerticalOffset: 4
                    }
                }
                Text {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    visible: !logo.visible
                    text: GameMode.active ? GameMode.gameTitle : "—"
                    font.family: root.face; font.pixelSize: 150; font.weight: Font.ExtraLight
                    font.letterSpacing: -3
                    color: Appearance.colors.fg
                    elide: Text.ElideRight
                }
            }

            Text {
                visible: GameMode.active
                Layout.topMargin: 18
                text: [GameMode.switchEq ? "EQ FPS" : "",
                       root.ping >= 0 ? "Ping " + root.ping + " ms" : "Hors ligne"].filter(x => x).join("   ·   ")
                font.family: root.face; font.pixelSize: 20; font.weight: Font.Light
                color: root.ping > 80 ? Appearance.colors.color13 : Appearance.colors.dim
            }

            // Temps de jeu cumulé (sessions enregistrées + session en cours)
            Text {
                visible: GameMode.active
                Layout.topMargin: 6
                text: "Aujourd'hui " + root.fmt(GameMode.statsToday + (root.startedToday ? root.elapsedSec : 0))
                    + "   ·   Semaine " + root.fmt(GameMode.statsWeek + root.elapsedSec)
                    + "   ·   Total " + root.fmt(GameMode.statsTotal + root.elapsedSec)
                font.family: root.face; font.pixelSize: 18; font.weight: Font.Light
                color: Appearance.colors.dim
            }

            Item { Layout.fillHeight: true }

            Row {
                spacing: 64
                Metric { label: "CPU";      value: Math.round(cpu.usagePercent) + "%";        ratio: cpu.usagePercent / 100; peak: "pic " + Math.round(Math.max(root.peakCpu, cpu.usagePercent)) + "%" }
                Metric { label: "GPU";      value: Math.round(gpu.igpu.freqPercent) + "%";    ratio: gpu.igpu.freqPercent / 100 }
                Metric { label: "CPU TEMP"; value: Math.round(thermal.cpuTemp) + "°";         ratio: thermal.cpuTemp / 100; peak: "pic " + Math.round(Math.max(root.peakCpuT, thermal.cpuTemp)) + "°" }
                Metric { label: "GPU TEMP"; value: Math.round(thermal.gpuTemp) + "°";         ratio: thermal.gpuTemp / 100; peak: "pic " + Math.round(Math.max(root.peakGpuT, thermal.gpuTemp)) + "°" }
                Metric { label: "RAM";      value: Math.round(mem.usagePercent) + "%";        ratio: mem.usagePercent / 100 }
            }
        }

        // ══ Droite : verre du mixeur sur la bannière du jeu ══
        ClippingRectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 28
            color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.06)

            Image {
                id: art
                anchors.fill: parent
                source: GameMode.gameArt
                sourceSize.width: 1400
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: art
                visible: art.status === Image.Ready
                blurEnabled: true; blur: 0.08; blurMax: 32
                brightness: -0.05; saturation: 0.2
            }
            // Voile en dégradé : fonce seulement le haut (lignes du mixeur) et le
            // bas (lecteur + boutons), la bannière reste bien visible au milieu.
            Rectangle {
                anchors.fill: parent
                readonly property real k: art.status === Image.Ready ? 1 : 0.5
                gradient: Gradient {
                    GradientStop { position: 0.0;  color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.55) }
                    GradientStop { position: 0.38; color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.12) }
                    GradientStop { position: 0.62; color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.12) }
                    GradientStop { position: 1.0;  color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.72) }
                }
            }
            // Contour animé multicolore, comme la barre principale (suit
            // l'interrupteur « Animations ») ; contour fixe sinon.
            GradientBorder {
                anchors.fill: parent
                colors: root.gameCols.length ? root.gameCols : Appearance.legiblePalette
                radius: 28
                borderWidth: 3
                visible: Appearance.animationsEnabled
                z: 5
            }
            Rectangle {
                anchors.fill: parent; radius: 28; color: "transparent"
                visible: !Appearance.animationsEnabled
                border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.14)
            }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 28
                spacing: 4

                MixRow { nodes: root.sink ? [root.sink] : []; label: "Master" }
                Repeater {
                    model: root.appGroups
                    delegate: MixRow {
                        required property var modelData
                        nodes: modelData.nodes
                        label: modelData.label
                    }
                }

                Item { Layout.fillHeight: true }

                // Lecteur en cours : titre · artiste + précédent / pause / suivant
                RowLayout {
                    visible: root.player !== null
                    Layout.fillWidth: true
                    spacing: 12
                    Column {
                        Layout.fillWidth: true
                        Text {
                            width: parent.width
                            text: root.player?.trackTitle || ""
                            font.family: root.face; font.pixelSize: 20; font.weight: Font.DemiBold
                            color: Appearance.colors.fg; elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: root.player?.trackArtist || root.player?.identity || ""
                            font.family: root.face; font.pixelSize: 15
                            color: Appearance.colors.dim; elide: Text.ElideRight
                        }
                    }
                    Action { glyph: "󰒮"; onTap: { root.player?.previous(); GameBreak.extend() } }
                    Action {
                        glyph: root.player?.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
                        on: true
                        onTap: { root.player?.togglePlaying(); GameBreak.extend() }
                    }
                    Action { glyph: "󰒭"; onTap: { root.player?.next(); GameBreak.extend() } }
                }

                Item { Layout.preferredHeight: 10 }

                // Bas : sortie audio à gauche, actions rapides à droite
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                Row {
                    Layout.fillWidth: true
                    spacing: 10
                    Repeater {
                        model: root.outputs
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool active: root.sink === modelData
                            readonly property bool isEq: (modelData.name || "").toLowerCase().indexOf("easyeffects") !== -1
                            width: chip.implicitWidth + 32; height: 44; radius: 22
                            color: active ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.85)
                                          : ColorUtils.applyAlpha(Appearance.colors.fg, 0.1)
                            Text {
                                id: chip
                                anchors.centerIn: parent
                                text: parent.isEq ? "Avec EQ" : (parent.modelData.description || "").split(" ").slice(0, 2).join(" ") + " direct"
                                font.family: root.face; font.pixelSize: 15
                                color: parent.active ? Appearance.colors.bg : Appearance.colors.fg
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { Pipewire.preferredDefaultAudioSink = parent.modelData; GameBreak.extend() }
                            }
                        }
                    }
                }
                    Action { glyph: ShellState.dnd ? "󰂛" : "󰂚"; on: ShellState.dnd; onTap: { ShellState.dnd = !ShellState.dnd; GameBreak.extend() } }
                    Action { glyph: "󰄀"; onTap: root.screenshot() }
                    Action { glyph: ScreenRecService.recording ? "󰙧" : "󰑋"; on: ScreenRecService.recording || ShellState.screenRecord; onTap: root.toggleRecord() }
                }
            }
        }
    }
}
