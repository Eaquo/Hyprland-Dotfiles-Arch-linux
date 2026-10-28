import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Io
import qs.components
import qs.components.stats
import qs.core
import qs.core.functions
import qs.services
import qs.services.system

// GameModeTab — page « Game » du TouchPanel, façon HUD : fond = bannière du jeu floutée.
// Affichée automatiquement quand GameMode.active. Gauche : logo, durée, temps de jeu.
// Centre : oscilloscope des FPS (MangoHud), sinon compteur rond de la charge GPU + tuiles CPU · GPU · RAM
// dans le style des cartes System. Droite : verre du mixeur sur la bannière nette
// — glisser une ligne = volume, tap sur le nom = muet. Rien ne tourne en continu (le jeu passe avant).
Item {
    id: root

    readonly property string face: "Fira Sans"

    // mesures : services/SysData.qml (le démon des cartes System), en mode détail tant que la page est visible
    Component.onCompleted: { SysData.want("game" + root, visible); if (visible) introAnim.restart() }
    Component.onDestruction: SysData.want("game" + root, false)
    readonly property var g: SysData.d ? SysData.d.temps.gpu : ({})

    // ── Audio ─────────────────────────────────────────────────────────────────
    // Logique audio partagée : services/Mixer.qml. Une ligne par application
    // (un jeu peut ouvrir plusieurs flux audio → regroupés dans Mixer.apps).
    readonly property var sink: Mixer.sink
    readonly property var outputs: Mixer.outputs
    readonly property var appGroups: Mixer.apps

    // pastille batterie : rien si l'appareil n'est pas vu ; couleur d'alerte sous 30 % / 15 %
    function batChip(d, g) {
        if (!d) return null
        const p = Batteries.pct(d)
        return { g: Batteries.charging(d) ? "󱐋" : g, t: p + " %",
                 c: p < 15 ? Appearance.colors.color4 : p < 30 ? Appearance.colors.color12 : Appearance.colors.fg }
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
    property var gpuHist: []                         // charge GPU, 2 dernières minutes (vue sans MangoHud)
    Connections { target: GameMode; function onStartedAtChanged() { root.peakCpuT = 0; root.peakGpuT = 0; root.peakCpu = 0 } }
    Connections {
        target: SysData
        function onHistRevChanged() {
            root.peakCpuT = Math.max(root.peakCpuT, SysData.cpuT); root.peakGpuT = Math.max(root.peakGpuT, SysData.gpuT)
            root.peakCpu = Math.max(root.peakCpu, SysData.cpu)
            if (!root.hasFps) root.gpuHist = root.gpuHist.concat([root.g.busy || 0]).slice(-120)
        }
    }

    // ── Lecteur en cours (Spotify…) ───────────────────────────────────────────
    readonly property var player: {
        const ps = Mpris.players.values
        return ps.find(p => p.playbackState === MprisPlaybackState.Playing) || ps[0] || null
    }

    // ── Actions rapides ───────────────────────────────────────────────────────
    Process { id: shotProc }
    function screenshot() {
        // Écran principal seulement (le jeu), dossier des captures habituel.
        const mon = Quickshell.screens.find(s => !Config.isTouch(s))
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

    // ── FPS et temps de trame (journal MangoHud, quand MangoHud est actif : scripts/game/mangohud_tail.sh) ──
    property real fps: 0
    property real frametime: 0
    property var fpsHist: []                         // les 2 dernières minutes (une mesure par seconde)
    readonly property bool hasFps: fpsHist.length > 0 && fpsAge < 4
    property int fpsAge: 99
    readonly property real low1: {                  // 1 % low : le centile le plus bas
        if (!fpsHist.length) return 0
        const a = fpsHist.slice().sort((x, y) => x - y)
        return a[Math.floor(a.length * 0.01)]
    }
    // trame « 1 % » : celle du 1 % low (le min absolu vaut ~1000 ms au chargement d'une partie)
    readonly property real ft1: low1 > 0 ? 1000 / low1 : 0
    Process {
        id: mhProc
        command: ["bash", Quickshell.shellDir + "/scripts/game/mangohud_tail.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/)
                if (p.length < 2 || isNaN(parseFloat(p[0]))) { root.fpsAge++; return }
                root.fps = parseFloat(p[0]); root.frametime = parseFloat(p[1]); root.fpsAge = 0
                root.fpsHist = root.fpsHist.concat([root.fps]).slice(-120)
            }
        }
    }
    Timer { interval: 1000; repeat: true; running: root.visible && GameMode.active; onTriggered: mhProc.running = true }
    Connections { target: GameMode; function onActiveChanged() { root.fpsHist = []; root.fpsAge = 99 } }

    // couleur lisible sur le fond (l'accent wallust peut être trop sombre)
    function vis(c) { return Appearance.contrastRatio(c, Appearance.colors.bg) < 3.5 ? Qt.lighter(c, 1.7) : c }
    function tile(k) {
        const t = tile_(k); t.col = vis(t.col); return t
    }
    function tile_(k) {
        const A = Appearance.colors
        if (k === "fps") {
            const c = root.fps < 60 ? A.color4 : root.fps < 100 ? A.color12 : A.accent
            return { glyph: "󰊴", label: "FPS", side: root.frametime.toFixed(1) + " ms", value: Math.round(root.fps), unit: "",
                     col: c, series: [[root.fpsHist.slice(-60), c, Math.max(165, ...root.fpsHist)]],
                     sub: "1 % low " + Math.round(root.low1) + " · " + root.ft1.toFixed(1) + " ms" }
        }
        if (k === "cpu") return { glyph: "󰍛", label: "CPU", side: Math.round(SysData.cpuT) + " °C", value: SysData.cpu, unit: "%",
                     col: SysData.cpuCol, series: [[SysData.hist.cpu, SysData.cpuCol, 100], [SysData.hist.tcpu, SysData.tcpuCol, 100]],
                     sub: "pic " + Math.round(root.peakCpu) + " % · " + Math.round(root.peakCpuT) + " °C" }
        if (k === "gpu") return { glyph: "󰢮", label: "GPU", side: Math.round(SysData.gpuT) + " °C", value: root.g.busy || 0, unit: "%",
                     col: SysData.lvl(root.g.busy || 0, 101, 101, A.color13), series: [[SysData.hist.tgpu, SysData.tgpuCol, 110]],
                     sub: Math.round(root.g.power || 0) + " W · VRAM " + SysData.gb(root.g.vramUsed || 0) + " · pic " + Math.round(root.peakGpuT) + "°" }
        return { glyph: "󰾆", label: "RAM", side: SysData.gb(SysData.memUsed), value: SysData.memPct, unit: "%",
                 col: SysData.ramCol, series: [[SysData.hist.ram, SysData.ramCol, SysData.memTotal]],
                 sub: "sur " + SysData.gb(SysData.memTotal) + (root.ping >= 0 ? " · ping " + root.ping + " ms" : "") }
    }

    // Bande de chiffres en bas d'un cadre (oscilloscope, compteur GPU)
    component StatStrip: Rectangle {
        id: strip
        property var cells: []          // [[libellé, valeur], …]
        property color accent: Appearance.colors.fg
        property int hi: -1             // case mise en couleur
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 78
        color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.55)
        Rectangle { width: parent.width; height: 1; color: ColorUtils.applyAlpha(strip.accent, 0.25) }
        Row {
            anchors.centerIn: parent
            Repeater {
                model: strip.cells
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: (strip.width - 40) / Math.max(1, strip.cells.length); height: 56
                    Rectangle { visible: index > 0; width: 1; height: 30; anchors.verticalCenter: parent.verticalCenter
                                color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.1) }
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData[1]
                               font.family: root.face; font.pixelSize: 24; font.weight: Font.Medium
                               color: index === strip.hi ? strip.accent : Appearance.colors.fg }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData[0]
                               font.family: root.face; font.pixelSize: 10; font.letterSpacing: 2.5; color: Appearance.colors.dim }
                    }
                }
            }
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
        Behavior on color { ColorAnimation { duration: Appearance.dur(140) } }
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
                onClicked: { Mixer.toggleMute(row.nodes); GameBreak.extend() }
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
                Behavior on width { NumberAnimation { duration: Appearance.dur(80) } }
            }
            MouseArea {
                anchors.fill: parent; anchors.topMargin: -12; anchors.bottomMargin: -12
                preventStealing: true
                function set(m) {
                    Mixer.setVolume(row.nodes, m.x / width)
                    GameBreak.extend()
                }
                onPressed: (m) => set(m)
                onPositionChanged: (m) => set(m)
            }
        }
    }

    // Arrivée de la page : les blocs montent l'un après l'autre
    property real intro: 0
    onVisibleChanged: { SysData.want("game" + root, visible); if (visible) introAnim.restart() }
    NumberAnimation { id: introAnim; target: root; property: "intro"; from: 0; to: 1; duration: Appearance.dur(1100); easing.type: Easing.OutCubic }
    function rise(k) { return Math.max(0, Math.min(1, root.intro * 2.2 - k * 0.35)) }

    // ── Fond : la bannière du jeu, très floutée, assombrie vers la gauche ──────
    ClippingRectangle {
        anchors.fill: parent
        radius: 28
        color: "transparent"
        Image { id: bgArt; anchors.fill: parent; source: GameMode.gameArt; sourceSize.width: 800
                fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: false }
        MultiEffect {
            anchors.fill: parent; source: bgArt
            visible: bgArt.status === Image.Ready
            blurEnabled: true; blur: 1.0; blurMax: 64; saturation: 0.3; brightness: -0.1
            opacity: 0.55
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0;  color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.82) }
                GradientStop { position: 0.55; color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.45) }
                GradientStop { position: 1.0;  color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.7) }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 32

        // ══ Gauche : le jeu ══
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: 500
            Layout.fillWidth: false
            spacing: 0
            opacity: root.rise(0)
            transform: Translate { y: (1 - root.rise(0)) * 30 }

            Row {
                spacing: 14
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12; height: 12; radius: 6
                    color: root.gameAccent
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: root.gameAccent; shadowBlur: 1.0 }
                    SequentialAnimation on opacity {
                        running: GameMode.active && root.visible; loops: Animation.Infinite
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
                Layout.preferredHeight: 230
                Image {
                    id: logo
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: parent.width; height: parent.height
                    source: GameMode.active ? GameMode.gameLogo : ""
                    sourceSize.width: 1400
                    fillMode: Image.PreserveAspectFit
                    horizontalAlignment: Image.AlignLeft
                    asynchronous: true
                    visible: status === Image.Ready
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true; shadowColor: "black"
                        shadowBlur: 0.8; shadowOpacity: 0.7; shadowVerticalOffset: 6
                    }
                }
                Text {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    visible: !logo.visible
                    text: GameMode.active ? GameMode.gameTitle : "—"
                    font.family: root.face; font.pixelSize: 130; font.weight: Font.ExtraLight
                    font.letterSpacing: -3
                    color: Appearance.colors.fg
                    elide: Text.ElideRight
                }
            }

            Item { Layout.fillHeight: true }

            // pastilles : EQ, ping, batteries souris et manette (services/Batteries.qml)
            Flow {
                visible: GameMode.active
                Layout.fillWidth: true
                spacing: 10
                Repeater {
                    model: [GameMode.switchEq ? { g: "󰓃", t: "EQ FPS", c: Appearance.colors.fg } : null,
                            root.ping >= 0 ? { g: "󰓅", t: "Ping " + root.ping + " ms",
                                               c: root.ping > 80 ? Appearance.colors.color4 : root.ping > 45 ? Appearance.colors.color12 : Appearance.colors.fg }
                                           : { g: "󰖪", t: "Hors ligne", c: Appearance.colors.dim },
                            root.batChip(Batteries.mouse, "󰍽"), root.batChip(Batteries.pad, "󰊴")].filter(x => x)
                    delegate: Rectangle {
                        required property var modelData
                        height: 38; width: pr.implicitWidth + 30; radius: 19
                        color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
                        border.width: 1; border.color: ColorUtils.applyAlpha(modelData.c, 0.3)
                        Row {
                            id: pr; anchors.centerIn: parent; spacing: 8
                            Text { text: modelData.g; font.family: Appearance.font.family; font.pixelSize: 16; color: modelData.c; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: modelData.t; font.family: root.face; font.pixelSize: 16; color: modelData.c; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }

            // Temps de jeu cumulé (sessions enregistrées + session en cours)
            Row {
                visible: GameMode.active
                Layout.topMargin: 22
                spacing: 34
                Repeater {
                    model: [["AUJOURD'HUI", GameMode.statsToday + (root.startedToday ? root.elapsedSec : 0)],
                            ["SEMAINE", GameMode.statsWeek + root.elapsedSec],
                            ["TOTAL", GameMode.statsTotal + root.elapsedSec]]
                    delegate: Column {
                        required property var modelData
                        spacing: 2
                        Text { text: root.fmt(modelData[1]); font.family: root.face; font.pixelSize: 26; font.weight: Font.Light; color: Appearance.colors.fg }
                        Text { text: modelData[0]; font.family: root.face; font.pixelSize: 11; font.letterSpacing: 3; color: Appearance.colors.dim }
                    }
                }
            }

            Item { Layout.preferredHeight: 6 }
        }

        // ══ Centre : oscilloscope des FPS + tuiles ══
        RowLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: 1000
            Layout.fillWidth: false
            spacing: 22

            // Oscilloscope : courbe lumineuse des 2 dernières minutes (une mesure/s), halo
            // dégradé dessous, pointillé = 1 % low. Sans MangoHud : la charge CPU.
            ClippingRectangle {
                id: osc
                visible: root.hasFps
                Layout.fillWidth: true; Layout.fillHeight: true
                // même cadre que les tuiles ; la courbe et son halo restent dedans
                radius: 22
                color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.5)
                border.width: 1; border.color: ColorUtils.applyAlpha(osc.col, 0.35)
                opacity: root.rise(1)
                transform: Translate { y: (1 - root.rise(1)) * 30 }
                readonly property var t: root.tile(root.hasFps ? "fps" : "cpu")
                readonly property color col: t.col
                readonly property var points: root.hasFps ? root.fpsHist : SysData.hist.cpu
                readonly property int slots: root.hasFps ? 120 : 60
                readonly property real vmax: root.hasFps ? Math.max(165, ...root.fpsHist) : 100
                onColChanged: cv.requestPaint()
                Connections { target: root; function onFpsHistChanged() { if (root.hasFps) cv.requestPaint() } }
                Connections { target: SysData; function onHistRevChanged() { if (!root.hasFps) cv.requestPaint() } }

                Canvas {
                    id: cv
                    anchors.fill: parent
                    anchors.topMargin: 96
                    anchors.bottomMargin: root.hasFps ? 78 : 0
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        const g = getContext("2d"), W = width, H = height, a = osc.points
                        g.clearRect(0, 0, W, H)
                        g.strokeStyle = ColorUtils.applyAlpha(Appearance.colors.fg, 0.06); g.lineWidth = 1
                        for (let y = H; y > 0; y -= H / 5) { g.beginPath(); g.moveTo(0, y); g.lineTo(W, y); g.stroke() }
                        if (a.length < 2) return
                        const step = W / (osc.slots - 1), off = osc.slots - a.length
                        const yOf = v => H - 6 - Math.min(1, v / osc.vmax) * (H - 24)
                        const c = String(osc.col)
                        g.beginPath()
                        a.forEach((v, i) => i ? g.lineTo((i + off) * step, yOf(v)) : g.moveTo((i + off) * step, yOf(v)))
                        g.strokeStyle = c; g.lineWidth = 4; g.lineJoin = "round"
                        g.shadowColor = c; g.shadowBlur = 18
                        g.stroke()
                        g.shadowBlur = 0
                        g.lineTo(W, H); g.lineTo(off * step, H); g.closePath()
                        const gr = g.createLinearGradient(0, 0, 0, H)
                        gr.addColorStop(0, ColorUtils.applyAlpha(osc.col, 0.4)); gr.addColorStop(1, ColorUtils.applyAlpha(osc.col, 0))
                        g.fillStyle = gr; g.fill()
                        // point de la dernière mesure
                        g.beginPath(); g.arc(W - 4, yOf(a[a.length - 1]), 6, 0, 7); g.fillStyle = c; g.fill()
                        // 1 % low
                        if (root.hasFps && root.low1 > 0) {
                            const ly = yOf(root.low1)
                            g.setLineDash([8, 8]); g.strokeStyle = ColorUtils.applyAlpha(Appearance.colors.fg, 0.5); g.lineWidth = 1.5
                            g.beginPath(); g.moveTo(0, ly); g.lineTo(W, ly); g.stroke(); g.setLineDash([])
                        }
                    }
                }
                // valeur en surimpression
                Row {
                    x: 22; y: 8
                    spacing: 14
                    Text { id: oscV; text: osc.t.value; font.family: root.face; font.pixelSize: 86; font.weight: Font.DemiBold; color: Appearance.colors.fg }
                    Column {
                        anchors.baseline: oscV.baseline
                        anchors.baselineOffset: -28
                        spacing: 4
                        Text { text: root.hasFps ? "FPS" : "CPU %"; font.family: root.face; font.pixelSize: 14; font.letterSpacing: 5; color: osc.col }
                        Text { text: root.hasFps ? root.frametime.toFixed(1) + " ms" : Math.round(SysData.cpuT) + " °C"
                               font.family: "JetBrains Mono"; font.pixelSize: 15; color: Appearance.colors.dim }
                    }
                }
                // bas du cadre : les chiffres de la session (2 dernières minutes)
                StatStrip {
                    visible: root.hasFps
                    accent: osc.col; hi: 3
                    cells: root.hasFps ? [["MOYENNE", Math.round(root.fpsHist.reduce((a, b) => a + b, 0) / root.fpsHist.length)],
                                          ["MIN", Math.round(Math.min(...root.fpsHist))],
                                          ["MAX", Math.round(Math.max(...root.fpsHist))],
                                          ["1 % LOW", Math.round(root.low1)],
                                          ["TRAME 1 %", root.ft1.toFixed(1) + " ms"]] : []
                }
                Text {
                    anchors { right: parent.right; top: parent.top; topMargin: 22; rightMargin: 20 }
                    text: root.hasFps ? "2 DERNIÈRES MINUTES"
                                      : "FPS : active MangoHud dans le lancement du jeu"
                    font.family: "JetBrains Mono"; font.pixelSize: 13; color: Appearance.colors.dim
                }
            }

            // Sans MangoHud : le compteur rond de la charge GPU (40 graduations sur 270°)
            ClippingRectangle {
                visible: !root.hasFps
                Layout.fillWidth: true; Layout.fillHeight: true
                radius: 22
                color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.5)
                border.width: 1; border.color: ColorUtils.applyAlpha(gauge.col, 0.35)
                opacity: root.rise(1)
                transform: Translate { y: (1 - root.rise(1)) * 30 }
                // en-tête, comme l'oscilloscope
                Row {
                    x: 22; y: 22
                    spacing: 10
                    Text { text: "󰢮"; font.family: Appearance.font.family; font.pixelSize: 16; color: gauge.col }
                    Text { text: "CARTE GRAPHIQUE"; font.family: root.face; font.pixelSize: 14; font.letterSpacing: 5; color: gauge.col }
                }
                Text {
                    anchors { right: parent.right; top: parent.top; topMargin: 22; rightMargin: 20 }
                    text: "FPS : ACTIVE MANGOHUD"
                    font.family: "JetBrains Mono"; font.pixelSize: 13; color: Appearance.colors.dim
                }
                Item {
                    id: gauge
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 40 + (parent.height - 40 - 78 - size) / 2
                    readonly property real size: Math.min(parent.height - 40 - 78 - 6, parent.width - 40, 440)
                    width: size; height: size
                    readonly property var t: root.tile("gpu")
                    readonly property real frac: Math.max(0, Math.min(1, Number(t.value) / 100))
                    readonly property color col: t.col
                    readonly property real r: size / 2

                    readonly property real tf: Math.max(0, Math.min(1, SysData.gpuT / 110))
                    readonly property color tcol: root.vis(SysData.tgpuCol)
                    onColChanged: radar.requestPaint()
                    Connections { target: root; function onGpuHistChanged() { radar.requestPaint() } }

                    // Radar : les 120 dernières secondes de charge enroulées en cercle (la plus récente
                    // en haut, l'historique s'efface dans le sens des aiguilles), un trait fin par seconde
                    Canvas {
                        id: radar
                        anchors.fill: parent
                        onWidthChanged: requestPaint()
                        onPaint: {
                            const g = getContext("2d"), R = width / 2, a = root.gpuHist, N = 120
                            const r0 = R * 0.56, span = R * 0.36, c = String(gauge.col)
                            g.clearRect(0, 0, width, height)
                            // cercles de repère (0, 50, 100 %)
                            g.lineWidth = 1
                            for (const k of [0, 0.5, 1]) {
                                g.strokeStyle = ColorUtils.applyAlpha(Appearance.colors.fg, k === 0 ? 0.12 : 0.05)
                                g.beginPath(); g.arc(R, R, r0 + span * k, 0, Math.PI * 2); g.stroke()
                            }
                            g.lineCap = "round"; g.lineWidth = Math.max(1.6, R * 0.012)
                            g.shadowColor = c; g.shadowBlur = 10
                            for (let i = 0; i < a.length; i++) {
                                const age = (a.length - 1 - i) / N                // 0 = maintenant
                                const ang = -Math.PI / 2 - age * Math.PI * 2 * 0.98
                                const v = Math.max(0.02, Math.min(1, a[i] / 100))
                                g.strokeStyle = ColorUtils.applyAlpha(gauge.col, 1 - age * 0.85)
                                g.beginPath()
                                g.moveTo(R + Math.cos(ang) * r0, R + Math.sin(ang) * r0)
                                g.lineTo(R + Math.cos(ang) * (r0 + span * v), R + Math.sin(ang) * (r0 + span * v))
                                g.stroke()
                            }
                            g.shadowBlur = 0
                            // la mesure en cours : un point au bout
                            if (a.length) {
                                const v = Math.max(0.02, Math.min(1, a[a.length - 1] / 100))
                                g.fillStyle = Appearance.colors.fg
                                g.beginPath(); g.arc(R, R - r0 - span * v, R * 0.022, 0, Math.PI * 2); g.fill()
                            }
                        }
                    }
                    // anneau extérieur très fin : la température
                    Shape {
                        id: tring
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        readonly property real rr: gauge.r * 0.97
                        ShapePath {
                            fillColor: "transparent"; strokeWidth: 2; capStyle: ShapePath.RoundCap
                            strokeColor: ColorUtils.applyAlpha(Appearance.colors.fg, 0.06)
                            PathAngleArc { centerX: gauge.r; centerY: gauge.r; radiusX: tring.rr; radiusY: tring.rr; startAngle: -90; sweepAngle: 360 }
                        }
                        ShapePath {
                            fillColor: "transparent"; strokeWidth: 2; capStyle: ShapePath.RoundCap
                            strokeColor: gauge.tcol
                            PathAngleArc {
                                centerX: gauge.r; centerY: gauge.r; radiusX: tring.rr; radiusY: tring.rr; startAngle: -90
                                sweepAngle: Math.max(0.5, 360 * gauge.tf)
                                Behavior on sweepAngle { NumberAnimation { duration: Appearance.dur(700); easing.type: Easing.OutCubic } }
                            }
                        }
                    }
                    Column {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 6
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: gauge.t.value
                               font.family: root.face; font.pixelSize: gauge.size * 0.2; font.weight: Font.Light; color: Appearance.colors.fg }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "CHARGE %"
                               font.family: root.face; font.pixelSize: 11; font.letterSpacing: 5; color: gauge.col }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; topPadding: 6
                               text: Math.round(SysData.gpuT) + " °C"
                               font.family: "JetBrains Mono"; font.pixelSize: 12; color: gauge.tcol }
                    }
                }
                StatStrip {
                    accent: gauge.col; hi: 0
                    cells: [["TEMPÉRATURE", Math.round(SysData.gpuT) + " °C"],
                            ["PIC", Math.round(Math.max(root.peakGpuT, SysData.gpuT)) + " °C"],
                            ["CONSO", Math.round(root.g.power || 0) + " W"],
                            ["VRAM", SysData.gb(root.g.vramUsed || 0)],
                            ["FRÉQUENCE", Math.round(root.g.sclk || 0) + " MHz"]]
                }
            }

            // Tuiles CPU · GPU · RAM, dans le style des cartes System (components/stats/)
            ColumnLayout {
                Layout.preferredWidth: 400; Layout.fillWidth: false; Layout.fillHeight: true
                spacing: 12
                Repeater {
                    model: ["cpu", "gpu", "ram"]
                    delegate: Rectangle {
                        id: tile
                        required property string modelData
                        required property int index
                        readonly property var t: root.tile(modelData)
                        Layout.fillWidth: true; Layout.fillHeight: true
                        radius: 22
                        color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.5)
                        border.width: 1; border.color: ColorUtils.applyAlpha(tile.t.col, 0.35)
                        Behavior on border.color { ColorAnimation { duration: Appearance.dur(250) } }
                        opacity: root.rise(1.6 + index * 0.5)
                        transform: Translate { x: (1 - tile.opacity) * 40 }
                        // filet de couleur à gauche
                        Rectangle { x: 0; y: 18; width: 3; height: parent.height - 36; radius: 2; color: tile.t.col }
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 16; anchors.leftMargin: 22
                            spacing: 18
                            ColumnLayout {
                                Layout.preferredWidth: 150
                                spacing: 2
                                RowLayout {
                                    spacing: 8
                                    Text { text: tile.t.glyph; font.family: Appearance.font.family; font.pixelSize: 15; color: tile.t.col }
                                    Text { text: tile.t.label; font.family: Appearance.font.family; font.pixelSize: 11; font.weight: Font.Bold
                                           font.letterSpacing: 2; color: Appearance.colors.dim }
                                }
                                Row {
                                    spacing: 4
                                    Text { id: tv; text: tile.t.value; font.family: root.face; font.pixelSize: 40; font.weight: Font.DemiBold; color: tile.t.col
                                           Behavior on color { ColorAnimation { duration: Appearance.dur(250) } } }
                                    Text { anchors.baseline: tv.baseline; text: tile.t.unit; font.family: root.face; font.pixelSize: 17; color: Appearance.colors.dim }
                                }
                                Text { text: tile.t.side; font.family: "JetBrains Mono"; font.pixelSize: 12; color: Appearance.colors.fg }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                spacing: 4
                                StatSpark { Layout.fillHeight: true; implicitHeight: 40; series: tile.t.series }
                                Text { Layout.fillWidth: true; text: tile.t.sub; elide: Text.ElideRight; horizontalAlignment: Text.AlignRight
                                       font.family: "JetBrains Mono"; font.pixelSize: 11; color: Appearance.colors.dim }
                            }
                        }
                    }
                }
            }
        }

        // ══ Droite : verre du mixeur sur la bannière du jeu ══
        ClippingRectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 28
            opacity: root.rise(2.6)
            transform: Translate { x: (1 - root.rise(2.6)) * 50 }
            color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.06)

            Image {
                id: art
                anchors.fill: parent
                source: GameMode.gameArt
                sourceSize.width: 1400
                fillMode: Image.PreserveAspectCrop
                horizontalAlignment: Image.AlignRight     // les bannières Steam ont leur sujet à droite
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
                                onClicked: { Mixer.setOutput(parent.modelData); GameBreak.extend() }
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
