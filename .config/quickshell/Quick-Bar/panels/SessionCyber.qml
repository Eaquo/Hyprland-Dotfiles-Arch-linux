import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import qs.core
import qs.core.functions
import qs.services

// SessionCyber — style « cyber » du SessionPanel ([session] style = "cyber"), plein écran : un netrunner
// et son « breach protocol ». Fond : le shader Cyberpunk du wallpaper sous un voile.
// Chaque action est un daemon = une séquence de 3 codes tirée d'un chemin dans la matrice
// (ligne 0, puis colonne, puis ligne — comme dans le jeu). Valider lance la brèche : le curseur suit
// le chemin et remplit le buffer ; pour les actions sans retour la brèche EST le compte à rebours (3 s).
// Couleurs : accent wallust + sa teinte opposée (comme le shader).
Item {
    id: m
    anchors.fill: parent

    required property var p
    readonly property int outMs: Appearance.dur(420)

    property real intro: 0
    property real gl: 0                  // force du glitch en cours (0..1)
    property int frame: 0
    readonly property real u: Math.max(1, height / 1080)
    readonly property bool armedNow: p.armed !== ""
    // lisible sur du noir : même teinte, luminosité relevée (gris si la couleur est terne)
    function light(c) {
        if (Appearance.contrastRatio(c, "#000000") >= 5) return c
        return c.hslSaturation < 0.12 ? Qt.hsla(0, 0, 0.78, 1) : Qt.hsla(c.hslHue, Math.max(c.hslSaturation, 0.6), 0.64, 1)
    }
    readonly property color acc: light(Appearance.colors.accent)
    readonly property color opp: acc.hslSaturation < 0.12 ? Qt.hsla(0.98, 0.8, 0.6, 1) : Qt.hsla((acc.hslHue + 0.5) % 1, 0.85, 0.62, 1)
    readonly property color hot: armedNow ? light(p.tint(p.sel)) : acc
    readonly property string disp: "Bahnschrift"
    readonly property string mono: "JetBrainsMono Nerd Font"

    function st(d, span) { const t = Math.max(0, Math.min(1, (intro - d) / span)); return 1 - Math.pow(1 - t, 3) }
    function jit(k) { m.frame; return (Math.random() - 0.5) * 2 * k * m.gl }
    readonly property string glyphs: "01<>/\\#%$&*+=?{}[]|~ABCDEFX"
    function scr(s, k) {
        if (k <= 0) return s
        m.frame
        let o = ""
        for (let i = 0; i < s.length; i++) o += (s[i] === " " || i / s.length < 1 - k) ? s[i] : glyphs[Math.floor(Math.random() * glyphs.length)]
        return o
    }

    // ── la matrice et les chemins des daemons (retirés à chaque ouverture) ──
    readonly property var codes: ["1C", "BD", "55", "E9", "7A", "FF"]
    readonly property int n: 6
    property var grid: []
    property var paths: []
    function build() {
        const g = []
        for (let i = 0; i < n * n; i++) g.push(codes[Math.floor(Math.random() * codes.length)])
        const ps = []
        const pick = (except) => { let v; do v = Math.floor(Math.random() * n); while (v === except); return v }
        for (let a = 0; a < 6; a++) {
            const c0 = Math.floor(Math.random() * n)      // 1er code : ligne 0
            const r1 = pick(0)                            // 2e : même colonne
            const c2 = pick(c0)                           // 3e : même ligne
            ps.push([c0, r1 * n + c0, r1 * n + c2])
        }
        grid = g; paths = ps
    }
    // avancée de la brèche : nombre de codes injectés
    readonly property int step: armedNow ? Math.min(3, Math.floor((p.armT + 0.12) * 3.4)) : 0
    readonly property var path: paths.length ? paths[p.sel] : [0, 0, 0]
    // bande guide : ligne 0 au repos, puis colonne / ligne du code suivant
    readonly property bool guideCol: step === 1
    readonly property int guideIdx: step === 0 ? 0 : step === 1 ? path[0] % n : Math.floor(path[1] / n)
    property string banner: ""
    property color bannerCol: acc
    Timer { id: bannerT; interval: 1100; onTriggered: m.banner = "" }
    property bool _wasArmed: false
    Connections {
        target: m.p
        function onArmedChanged() {
            if (m.p.armed === "" && m._wasArmed && Popups.sessionOpen) { m.banner = "BRÈCHE INTERROMPUE"; m.bannerCol = m.light(Appearance.colors.color1); bannerT.restart(); glA.restart() }
            m._wasArmed = m.p.armed !== ""
        }
        function onArmTChanged() { if (m.p.armT > 0.93 && m.banner === "") { m.banner = "DAEMON INSTALLÉ"; m.bannerCol = m.acc; glA.restart() } }
    }

    function open() { build(); banner = ""; outA.stop(); inA.restart(); glA.restart() }
    function close() { inA.stop(); outA.restart(); glA.restart() }
    NumberAnimation { id: inA; target: m; property: "intro"; from: 0; to: 1; duration: Appearance.dur(1300) }
    NumberAnimation { id: outA; target: m; property: "intro"; to: 0; duration: Appearance.dur(400); easing.type: Easing.InCubic }
    SequentialAnimation {
        id: glA
        NumberAnimation { target: m; property: "gl"; to: 1; duration: 40 }
        NumberAnimation { target: m; property: "gl"; to: 0.3; duration: 60 }
        NumberAnimation { target: m; property: "gl"; to: 0.9; duration: 40 }
        NumberAnimation { target: m; property: "gl"; to: 0; duration: 180 }
    }
    Timer {
        running: m.visible && Appearance.animationsEnabled
        interval: 2200; repeat: true
        onTriggered: { interval = 1400 + Math.random() * 3200; glA.restart() }
    }
    Connections { target: m.p; function onSelChanged() { glA.restart() } }
    FrameAnimation { running: m.visible; onTriggered: { fx.time += frameTime; m.frame++ } }

    // ── fond ──────────────────────────────────────────────────────────────
    Image {
        id: wall
        anchors.fill: parent
        visible: false
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(Math.round(width / 2), Math.round(height / 2))
        source: !WallpaperState.videoMode && WallpaperState.currentWall !== ""
                ? (WallpaperState.currentWall.startsWith("file:") ? WallpaperState.currentWall : "file://" + WallpaperState.currentWall) : ""
    }
    Rectangle { id: black; anchors.fill: parent; color: "#000000"; visible: false; layer.enabled: true }
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: m.st(0, 0.2) }
    ShaderEffect {
        id: fx
        anchors.fill: parent
        opacity: m.st(0, 0.25)
        property variant source: wall.status === Image.Ready ? wall : black
        property real intensity: m.armedNow ? 1 : 0.85
        property real time: 0
        property vector2d resolution: Qt.vector2d(width, height)
        property vector4d accent: Qt.vector4d(m.acc.r, m.acc.g, m.acc.b, 1)
        fragmentShader: Qt.resolvedUrl("../wallpaper/shaders/cyberpunk.frag.qsb")
    }
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.74 * m.st(0, 0.25) }
    Canvas {
        anchors.fill: parent
        opacity: 0.08 * m.st(0, 0.3)
        onPaint: { const c = getContext("2d"); c.fillStyle = "#ffffff"; for (let y = 0; y < height; y += 3) c.fillRect(0, y, width, 1) }
    }
    MouseArea { anchors.fill: parent; onClicked: { if (m.armedNow) m.p.cancel(); else Popups.sessionOpen = false } }

    // équerres aux coins de l'écran
    Repeater {
        model: 4
        delegate: Item {
            required property int index
            readonly property bool r: index % 2 === 1
            readonly property bool b: index >= 2
            readonly property real len: 70 * m.u * m.st(0.1, 0.4)
            x: r ? m.width * 0.96 - len : m.width * 0.04
            y: b ? m.height * 0.95 - len : m.height * 0.05
            width: len; height: len
            Rectangle { width: parent.width; height: 2; y: parent.b ? parent.height - 2 : 0; color: m.hot }
            Rectangle { width: 2; height: parent.height; x: parent.r ? parent.width - 2 : 0; color: m.hot }
        }
    }

    // ── texte en split RVB ────────────────────────────────────────────────
    component Glitch: Item {
        id: g
        property string text
        property real size: 100
        property color col: Appearance.colors.fg
        property string family: m.disp
        implicitWidth: main.implicitWidth; implicitHeight: main.implicitHeight
        Text { x: -3 * m.u + m.jit(14 * m.u); y: m.jit(4 * m.u); text: g.text; color: m.opp; opacity: 0.85
               font.family: g.family; font.pixelSize: g.size; font.weight: Font.Bold; font.letterSpacing: g.size * 0.06 }
        Text { x: 3 * m.u + m.jit(14 * m.u); y: m.jit(4 * m.u); text: g.text; color: m.hot; opacity: 0.85
               font.family: g.family; font.pixelSize: g.size; font.weight: Font.Bold; font.letterSpacing: g.size * 0.06 }
        Text { id: main; x: m.jit(6 * m.u); text: g.text; color: g.col
               font.family: g.family; font.pixelSize: g.size; font.weight: Font.Bold; font.letterSpacing: g.size * 0.06
               layer.enabled: true
               layer.effect: MultiEffect { shadowEnabled: true; shadowColor: g.col; shadowBlur: 1; shadowOpacity: 0.75
                                           shadowHorizontalOffset: 0; shadowVerticalOffset: 0; autoPaddingEnabled: true } }
    }

    // ── en-tête : le netrunner ───────────────────────────────────────────
    Column {
        x: m.width * 0.07; y: m.height * 0.08
        opacity: m.st(0.05, 0.3)
        spacing: 2 * m.u
        Text { text: m.scr("// ICEBREAKER · NETRUNNER " + Config.userName.toUpperCase() + " · CYBERDECK QUICK-BAR MK.5", 1 - m.st(0.05, 0.4))
               font.family: m.mono; font.pixelSize: 15 * m.u; color: m.opp; font.letterSpacing: 2 }
        Glitch { text: m.scr("BREACH PROTOCOL", 1 - m.st(0.1, 0.45)); size: 84 * m.u }
    }
    Column {
        anchors.right: parent.right; anchors.rightMargin: m.width * 0.07
        y: m.height * 0.08
        opacity: m.st(0.15, 0.3)
        spacing: 6 * m.u
        Glitch { anchors.right: parent.right; text: Qt.formatTime(m.p.now, "HH:mm"); size: 84 * m.u; col: m.hot }
        // RAM du deck = vraie RAM, en cases ; TRACE = CPU
        Row {
            anchors.right: parent.right
            spacing: 5 * m.u
            Text { text: "RAM"; font.family: m.mono; font.pixelSize: 14 * m.u; color: Appearance.colors.fg; opacity: 0.7; anchors.verticalCenter: parent.verticalCenter }
            Repeater {
                model: 10
                Rectangle { required property int index; width: 16 * m.u; height: 16 * m.u
                            color: index < Math.round(SysData.memPct / 10) ? m.acc : "transparent"
                            border.width: 1; border.color: ColorUtils.applyAlpha(m.acc, 0.6) }
            }
        }
        Text {
            anchors.right: parent.right
            text: "TRACE " + SysData.cpu + " %  ·  " + Math.round(SysData.cpuT) + " °C  ·  UPTIME " + (m.p.uptime || "—").toUpperCase()
            font.family: m.mono; font.pixelSize: 14 * m.u; color: m.opp; font.letterSpacing: 1
        }
    }

    // ── temps de brèche ───────────────────────────────────────────────────
    Item {
        id: timer
        anchors.horizontalCenter: parent.horizontalCenter
        y: m.height * 0.27
        width: main.width; height: 44 * m.u
        opacity: m.st(0.2, 0.3)
        Text { text: "TEMPS DE BRÈCHE RESTANT"; font.family: m.mono; font.pixelSize: 15 * m.u; color: m.hot; font.letterSpacing: 2 }
        Rectangle {
            anchors.right: parent.right; width: 110 * m.u; height: 30 * m.u
            color: "transparent"; border.width: 1; border.color: m.hot
            Text { anchors.centerIn: parent; text: (m.armedNow ? 3 - m.p.armT * 3 : 3).toFixed(2)
                   font.family: m.mono; font.pixelSize: 18 * m.u; font.bold: true; color: m.hot }
        }
        Rectangle {
            y: 36 * m.u; width: parent.width; height: 6 * m.u
            color: ColorUtils.applyAlpha(m.hot, 0.15)
            Rectangle { anchors.right: parent.right; height: parent.height; color: m.hot
                        width: parent.width * (m.armedNow ? 1 - m.p.armT : 1) }
        }
    }

    // ── matrice + daemons ─────────────────────────────────────────────────
    component Panel: Item {
        id: pn
        property string title
        default property alias content: inner.data
        Rectangle { anchors.fill: parent; color: ColorUtils.applyAlpha("#000000", 0.6); border.width: 1; border.color: ColorUtils.applyAlpha(m.acc, 0.55) }
        Rectangle {
            width: parent.width; height: 34 * m.u; color: m.acc
            Text { x: 14 * m.u; anchors.verticalCenter: parent.verticalCenter; text: pn.title
                   font.family: m.disp; font.pixelSize: 17 * m.u; font.weight: Font.Bold; font.letterSpacing: 3; color: "#000000" }
        }
        Item { id: inner; x: 0; y: 34 * m.u; width: parent.width; height: parent.height - 34 * m.u }
    }

    Rectangle {
        id: haloSrc
        x: main.x; y: main.y; width: main.width; height: main.height
        color: m.hot; visible: false; layer.enabled: true
    }
    MultiEffect {
        source: haloSrc
        x: haloSrc.x; y: haloSrc.y; width: haloSrc.width; height: haloSrc.height
        blurEnabled: true; blur: 1; blurMax: 64; blurMultiplier: 2.2
        autoPaddingEnabled: true
        opacity: m.st(0.3, 0.4) * (m.armedNow ? 0.32 + 0.2 * Math.abs(Math.sin(m.frame / 10)) : 0.2)
    }
    Row {
        id: main
        anchors.horizontalCenter: parent.horizontalCenter
        y: timer.y + timer.height + 26 * m.u
        spacing: 34 * m.u
        readonly property real cell: 74 * m.u

        Panel {
            id: mat
            title: "MATRICE DE CODES"
            width: main.cell * m.n + 40 * m.u; height: main.cell * m.n + 74 * m.u
            transform: Scale { origin.y: mat.height / 2; yScale: m.st(0.25, 0.25) }
            // bande guide (ligne ou colonne du prochain code)
            Rectangle {
                x: 20 * m.u + (m.guideCol ? m.guideIdx * main.cell : 0)
                y: 20 * m.u + (m.guideCol ? 0 : m.guideIdx * main.cell)
                width: m.guideCol ? main.cell : main.cell * m.n
                height: m.guideCol ? main.cell * m.n : main.cell
                color: ColorUtils.applyAlpha(m.hot, 0.12)
                border.width: 1; border.color: ColorUtils.applyAlpha(m.hot, 0.35)
                Behavior on x { NumberAnimation { duration: Appearance.dur(220); easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: Appearance.dur(220); easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: Appearance.dur(220); easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: Appearance.dur(220); easing.type: Easing.OutCubic } }
            }
            Grid {
                x: 20 * m.u; y: 20 * m.u
                columns: m.n
                Repeater {
                    model: m.grid.length
                    delegate: Item {
                        id: cl
                        required property int index
                        readonly property int r: Math.floor(index / m.n)
                        readonly property int c: index % m.n
                        readonly property int k: m.path.indexOf(index)          // place dans le chemin du daemon choisi
                        readonly property bool done: k >= 0 && k < m.step
                        readonly property bool next: k >= 0 && k === m.step && m.armedNow
                        width: main.cell; height: main.cell
                        opacity: m.st(0.3 + (r + c) * 0.025, 0.2)
                        Rectangle {
                            anchors.centerIn: parent; width: parent.width * 0.74; height: parent.height * 0.62
                            layer.enabled: cl.done
                            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: m.hot; shadowBlur: 1; shadowOpacity: 0.9
                                                        shadowHorizontalOffset: 0; shadowVerticalOffset: 0; autoPaddingEnabled: true }
                            color: cl.done ? m.hot : "transparent"
                            border.width: cl.k >= 0 ? (cl.next ? 2 : 1) : 0
                            border.color: cl.next ? m.hot : ColorUtils.applyAlpha(m.opp, 0.7)
                            opacity: cl.next ? 0.5 + 0.5 * Math.abs(Math.sin(m.frame / 6)) : 1
                        }
                        Text {
                            anchors.centerIn: parent
                            text: m.scr(m.grid[cl.index] || "", 1 - m.st(0.35 + (cl.r + cl.c) * 0.025, 0.25))
                            font.family: m.mono; font.pixelSize: 24 * m.u; font.bold: cl.k >= 0
                            color: cl.done ? "#000000" : cl.k >= 0 ? m.opp : ColorUtils.applyAlpha(Appearance.colors.fg, 0.75)
                        }
                    }
                }
            }
        }

        Column {
            spacing: 22 * m.u
            // buffer
            Panel {
                id: buf
                title: "BUFFER"
                width: 640 * m.u; height: 110 * m.u
                transform: Scale { origin.y: buf.height / 2; yScale: m.st(0.3, 0.25) }
                Row {
                    x: 18 * m.u; anchors.verticalCenter: parent.verticalCenter
                    spacing: 10 * m.u
                    Repeater {
                        model: 5
                        Rectangle {
                            required property int index
                            readonly property bool filled: index < m.step
                            width: 52 * m.u; height: 46 * m.u
                            color: filled ? ColorUtils.applyAlpha(m.hot, 0.2) : "transparent"
                            border.width: 1; border.color: ColorUtils.applyAlpha(filled ? m.hot : m.acc, filled ? 1 : 0.35)
                            scale: filled ? 1 : 0.94
                            Behavior on scale { NumberAnimation { duration: Appearance.dur(200); easing.type: Easing.OutBack; easing.overshoot: 3 } }
                            Text { anchors.centerIn: parent; visible: parent.filled; text: m.grid[m.path[parent.index]] || ""
                                   font.family: m.mono; font.pixelSize: 20 * m.u; font.bold: true; color: m.hot }
                        }
                    }
                }
            }
            // daemons
            Panel {
                id: dae
                title: "SÉQUENCE REQUISE POUR L'INJECTION"
                width: 640 * m.u; height: main.cell * m.n + 74 * m.u - buf.height - 22 * m.u
                transform: Scale { origin.y: dae.height / 2; yScale: m.st(0.35, 0.25) }
                Column {
                    x: 12 * m.u; y: 10 * m.u
                    width: parent.width - 24 * m.u
                    spacing: 2 * m.u
                    Repeater {
                        model: m.p.actions
                        delegate: Item {
                            id: dr
                            required property var modelData
                            required property int index
                            readonly property bool on: m.p.sel === index
                            readonly property bool isArmed: m.p.armed === modelData[0]
                            width: parent.width; height: (dae.height - 34 * m.u - 30 * m.u) / 6
                            opacity: m.st(0.45 + index * 0.05, 0.25)
                            transform: Translate { x: (1 - dr.opacity) * 40 * m.u + (dr.on ? m.jit(6 * m.u) : 0) }
                            Rectangle { id: drGlow; anchors.fill: parent; color: m.hot; visible: false; layer.enabled: true }
                            MultiEffect { anchors.fill: drGlow; source: drGlow; blurEnabled: true; blur: 1; blurMax: 32; autoPaddingEnabled: true
                                          opacity: dr.on ? 0.35 : 0; Behavior on opacity { NumberAnimation { duration: Appearance.dur(200) } } }
                            Rectangle { anchors.fill: parent; color: dr.on ? ColorUtils.applyAlpha("#000000", 0.55) : "transparent" }
                            Rectangle { anchors.fill: parent; color: dr.on ? ColorUtils.applyAlpha(m.hot, 0.14) : "transparent" }
                            Rectangle { visible: dr.on; width: 4 * m.u; height: parent.height; color: m.hot }
                            Row {
                                x: 16 * m.u; anchors.verticalCenter: parent.verticalCenter
                                spacing: 6 * m.u
                                Repeater {
                                    model: 3
                                    Rectangle {
                                        required property int index
                                        readonly property bool ok: dr.isArmed && index < m.step
                                        width: 44 * m.u; height: 30 * m.u
                                        color: ok ? m.hot : "transparent"
                                        border.width: 1; border.color: ColorUtils.applyAlpha(dr.on ? m.hot : m.opp, dr.on ? 0.9 : 0.5)
                                        Text { anchors.centerIn: parent; text: m.paths.length ? m.grid[m.paths[dr.index][parent.index]] : ""
                                               font.family: m.mono; font.pixelSize: 15 * m.u; font.bold: true
                                               color: parent.ok ? "#000000" : dr.on ? m.hot : m.opp }
                                    }
                                }
                                Item { width: 14 * m.u; height: 1 }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: (dr.on ? m.scr(dr.modelData[2].toUpperCase(), m.gl) : dr.modelData[2].toUpperCase()) + ".DAEMON"
                                           font.family: m.disp; font.pixelSize: 20 * m.u; font.weight: Font.Bold; font.letterSpacing: 2
                                           color: dr.on ? Appearance.colors.fg : ColorUtils.applyAlpha(Appearance.colors.fg, 0.6) }
                                    Text { visible: dr.on
                                           text: dr.modelData[6].filter(x => x !== "sh" && x !== "-c" && x !== "bash").join(" ").replace(/ \|\|.*/, "").replace(Quickshell.env("HOME"), "~")
                                           font.family: m.mono; font.pixelSize: 12 * m.u; color: m.opp }
                                }
                            }
                            Text { anchors.right: parent.right; anchors.rightMargin: 12 * m.u; anchors.verticalCenter: parent.verticalCenter
                                   text: "[" + dr.modelData[3].toUpperCase() + "]"; font.family: m.mono; font.pixelSize: 14 * m.u
                                   color: dr.on ? m.hot : ColorUtils.applyAlpha(Appearance.colors.fg, 0.4) }
                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onEntered: if (!m.armedNow) m.p.sel = dr.index
                                onClicked: m.p.trigger(dr.index)
                            }
                        }
                    }
                }
            }
        }
    }

    // ── pied ──────────────────────────────────────────────────────────────
    Item {
        x: m.width * 0.07; width: m.width * 0.86
        y: m.height * 0.9
        height: 40 * m.u
        opacity: m.st(0.6, 0.3)
        Rectangle { width: parent.width; height: 1; color: ColorUtils.applyAlpha(m.acc, 0.4) }
        Text { y: 12 * m.u
               text: m.armedNow ? "BRÈCHE EN COURS — ÉCHAP OU CLIC POUR INTERROMPRE · ⏎ INJECTER TOUT DE SUITE"
                                : "←→ CHOISIR LE DAEMON   ⏎ LANCER LA BRÈCHE   L U E R S B   ÉCHAP SE DÉCONNECTER DU RÉSEAU"
               font.family: m.mono; font.pixelSize: 13 * m.u; color: m.armedNow ? m.hot : Appearance.colors.fg; opacity: 0.7; font.letterSpacing: 2 }
        Text { anchors.right: parent.right; y: 12 * m.u; text: "SYS://SESSION.CTRL  v2.0.77"
               font.family: m.mono; font.pixelSize: 13 * m.u; color: m.opp; font.letterSpacing: 2 }
    }

    // ── bandeau : daemon installé / brèche interrompue ────────────────────
    Item {
        anchors.centerIn: parent
        width: parent.width; height: 150 * m.u
        visible: m.banner !== ""
        Rectangle { anchors.fill: parent; color: ColorUtils.applyAlpha("#000000", 0.85) }
        Rectangle { width: parent.width; height: 3 * m.u; color: m.bannerCol }
        Rectangle { width: parent.width; height: 3 * m.u; anchors.bottom: parent.bottom; color: m.bannerCol }
        Glitch { anchors.centerIn: parent; text: m.banner; size: 76 * m.u; col: m.bannerCol }
    }

    Rectangle { anchors.fill: parent; color: m.acc; opacity: m.gl * 0.06 }
}
