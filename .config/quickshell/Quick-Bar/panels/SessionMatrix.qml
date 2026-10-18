import QtQuick
import QtQuick.Effects
import Quickshell
import qs.core
import qs.core.functions

// SessionMatrix — style « matrix » du SessionPanel ([session] style = "matrix"), plein écran.
// Fond : le shader Matrix du wallpaper (plongée dans la pluie, le fond d'écran deviné dessous).
// Devant : un terminal qui s'allume comme un écran cathodique, tape ses lignes, déchiffre la ligne
// choisie ; pendant un compte à rebours la pluie accélère et passe à la couleur de l'action.
Item {
    id: m
    anchors.fill: parent

    required property var p              // le SessionPanel (sel, armed, armT, actions, trigger…)
    readonly property int outMs: Appearance.dur(560)

    property real show: 0                // pluie
    property real crtX: 0                // allumage cathodique
    property real crtY: 0.004
    property real flash: 0
    property real typed: 0               // caractères tapés (chaque ligne démarre 9 car. après la précédente)
    property real speed: 1
    property real glitchX: 0
    property real scramble: 0            // déchiffrement de la ligne choisie (1 → 0)
    property int frame: 0                // tic pour les textes aléatoires

    readonly property bool armedNow: p.armed !== ""
    readonly property color rainCol: {
        const c = armedNow ? p.tint(p.sel) : Appearance.colors.accent
        return Appearance.contrastRatio(c, "#000000") < 4 ? Qt.lighter(c, 1.6) : c
    }
    readonly property color hot: rainCol
    readonly property string mono: "JetBrainsMono Nerd Font"

    function open() {
        outSeq.stop(); typed = 0; scramble = 0
        inSeq.restart()
    }
    function close() { inSeq.stop(); outSeq.restart() }

    // ── ouverture : plongée dans la pluie, ligne lumineuse, l'écran s'ouvre, on tape ──
    SequentialAnimation {
        id: inSeq
        ScriptAction { script: { m.show = 0; m.crtX = 0; m.crtY = 0.004; m.flash = 0; m.speed = 7 } }
        ParallelAnimation {
            NumberAnimation { target: m; property: "show"; to: 1; duration: Appearance.dur(500); easing.type: Easing.OutCubic }
            NumberAnimation { target: m; property: "speed"; to: 1; duration: Appearance.dur(1800); easing.type: Easing.OutCubic }
            SequentialAnimation {
                PauseAnimation { duration: Appearance.dur(220) }
                NumberAnimation { target: m; property: "crtX"; to: 1; duration: Appearance.dur(170); easing.type: Easing.OutCubic }
                ParallelAnimation {
                    NumberAnimation { target: m; property: "crtY"; to: 1; duration: Appearance.dur(260); easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                    NumberAnimation { target: m; property: "flash"; from: 0.7; to: 0; duration: Appearance.dur(420) }
                }
                NumberAnimation { target: m; property: "typed"; to: 150; duration: Appearance.dur(1500) }
            }
        }
    }
    // fermeture : l'écran s'éteint (trait puis point), la pluie s'efface
    SequentialAnimation {
        id: outSeq
        ParallelAnimation {
            NumberAnimation { target: m; property: "crtY"; to: 0.004; duration: Appearance.dur(170); easing.type: Easing.InCubic }
            NumberAnimation { target: m; property: "flash"; to: 0.5; duration: Appearance.dur(170) }
        }
        ParallelAnimation {
            NumberAnimation { target: m; property: "crtX"; to: 0; duration: Appearance.dur(150); easing.type: Easing.InCubic }
            NumberAnimation { target: m; property: "show"; to: 0; duration: Appearance.dur(380); easing.type: Easing.InCubic }
        }
    }
    Behavior on speed { enabled: !inSeq.running; NumberAnimation { duration: Appearance.dur(600); easing.type: Easing.OutCubic } }
    Binding { target: m; property: "speed"; value: m.armedNow ? 2.6 : 1; when: !inSeq.running }

    Connections {
        target: m.p
        function onSelChanged() { if (m.typed > 60) { scrAnim.restart() } }
    }
    NumberAnimation { id: scrAnim; target: m; property: "scramble"; from: 1; to: 0; duration: Appearance.dur(380) }

    FrameAnimation {
        running: m.visible && m.show > 0
        onTriggered: { rain.time += frameTime * m.speed; m.frame++ }
    }

    // ── la pluie (shader du wallpaper) ────────────────────────────────────
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
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: m.show }
    ShaderEffect {
        id: rain
        anchors.fill: parent
        opacity: m.show
        property variant source: wall.status === Image.Ready ? wall : black
        property real intensity: 1.0
        property real time: 0
        property vector2d resolution: Qt.vector2d(width, height)
        property vector4d accent: Qt.vector4d(rc.r, rc.g, rc.b, 1)
        property color rc: m.rainCol
        Behavior on rc { ColorAnimation { duration: Appearance.dur(500) } }
        fragmentShader: Qt.resolvedUrl("../wallpaper/shaders/matrix.frag.qsb")
    }
    // vignette haut / bas
    Rectangle {
        anchors.fill: parent
        opacity: m.show
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#c0000000" }
            GradientStop { position: 0.25; color: "#00000000" }
            GradientStop { position: 0.75; color: "#00000000" }
            GradientStop { position: 1.0; color: "#c0000000" }
        }
    }
    MouseArea { anchors.fill: parent; onClicked: { if (m.armedNow) m.p.cancel(); else Popups.sessionOpen = false } }

    // ── texte ─────────────────────────────────────────────────────────────
    function reveal(s, line, off) { return s.slice(0, Math.max(0, Math.floor(m.typed) - line * 9 - (off || 0))) }
    function cmdStr(a) { return a[6].filter(x => x !== "sh" && x !== "-c" && x !== "bash").join(" ").replace(/ \|\|.*/, "").replace(Quickshell.env("HOME"), "~") }
    readonly property string glyphs: "01<>/\\#%$&*+=?{}[]|~"
    function scr(s, k) {
        if (k <= 0) return s
        m.frame                                     // relu à chaque image
        let o = ""
        for (let i = 0; i < s.length; i++)
            o += (s[i] === " " || i / s.length < 1 - k) ? s[i] : glyphs[Math.floor(Math.random() * glyphs.length)]
        return o
    }
    readonly property var armedAct: p.actions.find(a => a[0] === p.armed)

    // ── halo autour du terminal ───────────────────────────────────────────
    Rectangle {
        id: haloSrc
        anchors.centerIn: win
        width: win.width * win.scale * m.crtX; height: win.height * win.scale * m.crtY
        radius: 12; color: m.hot; visible: false; layer.enabled: true
    }
    MultiEffect {
        source: haloSrc
        x: haloSrc.x; y: haloSrc.y; width: haloSrc.width; height: haloSrc.height
        blurEnabled: true; blur: 1; blurMax: 64; blurMultiplier: 2
        autoPaddingEnabled: true
        opacity: m.armedNow ? 0.4 + 0.2 * Math.abs(Math.sin(m.frame / 9)) : 0.28
    }

    // ── le terminal ───────────────────────────────────────────────────────
    Item {
        id: win
        width: Math.min(parent.width * 0.62, 940)
        height: body.implicitHeight + 46 + 34
        anchors.centerIn: parent
        scale: Math.max(1, m.height / 1080)
        opacity: m.crtX > 0 ? 1 : 0
        transform: [
            Scale { origin.x: win.width / 2; origin.y: win.height / 2; xScale: m.crtX; yScale: m.crtY },
            Translate { x: m.glitchX }
        ]
        MouseArea { anchors.fill: parent }

        Rectangle {
            id: frame
            anchors.fill: parent
            radius: 12
            color: ColorUtils.applyAlpha("#000000", 0.82)
            border.width: m.armedNow ? 2 : 1
            border.color: ColorUtils.applyAlpha(m.hot, m.armedNow ? 0.5 + 0.4 * Math.abs(Math.sin(m.frame / 9)) : 0.45)
        }
        // lignes de balayage
        Canvas {
            anchors.fill: parent; anchors.margins: 1
            opacity: 0.07
            onPaint: { const c = getContext("2d"); c.fillStyle = "#ffffff"; for (let y = 0; y < height; y += 3) c.fillRect(0, y, width, 1) }
        }
        // barre de titre
        Row {
            x: 18; y: 15; spacing: 8
            Repeater { model: 3; Rectangle { required property int index; width: 11; height: 11; radius: 6
                       color: index === 0 ? m.hot : ColorUtils.applyAlpha(Appearance.colors.fg, 0.25) } }
            Text { leftPadding: 8; text: Config.userName + "@quickbar — session"
                   font.family: m.mono; font.pixelSize: 13; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.5); anchors.verticalCenter: parent.verticalCenter }
        }
        Text { anchors.right: parent.right; anchors.rightMargin: 18; y: 12; text: Qt.formatTime(m.p.now, "HH:mm:ss")
               font.family: m.mono; font.pixelSize: 13; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.5) }
        Rectangle { y: 40; width: parent.width; height: 1; color: ColorUtils.applyAlpha(m.hot, 0.2) }

        Column {
            id: body
            x: 26; y: 56
            width: parent.width - 52
            spacing: 4

            Text { text: m.reveal("$ quickbar session --user " + Config.userName, 0); font.family: m.mono; font.pixelSize: 17; color: Appearance.colors.fg
                   textFormat: Text.PlainText }
            Text {
                readonly property string day: m.p.now.toLocaleDateString(Qt.locale("fr_FR"), "dddd d MMMM")
                text: m.reveal("  " + day + (m.p.uptime ? " · allumé depuis " + m.p.uptime : ""), 1)
                font.family: m.mono; font.pixelSize: 15; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.45)
            }
            Item { width: 1; height: 10 }

            Item {
                width: body.width
                height: rows.implicitHeight
                // surbrillance qui glisse d'une ligne à l'autre
                Rectangle {
                    id: hl
                    x: -10; width: parent.width + 20; height: 32; radius: 6
                    y: m.p.sel * 34
                    Behavior on y { NumberAnimation { duration: Appearance.dur(200); easing.type: Easing.OutCubic } }
                    opacity: m.typed > 30 ? 1 : 0
                    color: ColorUtils.applyAlpha(m.hot, m.armedNow ? 0.16 + 0.1 * m.p.armT : 0.15)
                    Rectangle { width: 3; height: parent.height; radius: 2; color: m.hot }
                    // jauge du compte à rebours dans la ligne
                    Rectangle { visible: m.armedNow; height: parent.height; radius: 6; width: parent.width * m.p.armT
                                color: ColorUtils.applyAlpha(m.hot, 0.18) }
                }
                Column {
                    id: rows
                    width: parent.width
                    spacing: 2
                    Repeater {
                        model: m.p.actions
                        delegate: Item {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool on: m.p.sel === index
                            readonly property bool isArmed: m.p.armed === modelData[0]
                            readonly property int line: 3 + index
                            width: rows.width; height: 32
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0
                                Text {
                                    readonly property string s: (row.on ? "▶ " : "  ") + (row.on ? m.scr(row.modelData[2], m.scramble) : row.modelData[2]).padEnd(14)
                                    text: m.reveal(s, row.line)
                                    font.family: m.mono; font.pixelSize: 17; font.bold: row.on
                                    color: row.on ? (row.isArmed ? m.hot : Appearance.colors.fg) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.55)
                                }
                                Text {
                                    text: m.reveal(m.cmdStr(row.modelData), row.line, 16)
                                    font.family: m.mono; font.pixelSize: 15
                                    color: row.on ? m.hot : ColorUtils.applyAlpha(Appearance.colors.fg, 0.3)
                                    elide: Text.ElideRight
                                    width: rows.width - 16 * 11 - 50
                                }
                            }
                            Text {
                                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                                text: m.typed > row.line * 9 + 20 ? "[" + row.modelData[3] + "]" : ""
                                font.family: m.mono; font.pixelSize: 14
                                color: row.on ? m.hot : ColorUtils.applyAlpha(Appearance.colors.fg, 0.3)
                            }
                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onEntered: if (!m.armedNow) m.p.sel = row.index
                                onClicked: m.p.trigger(row.index)
                            }
                        }
                    }
                }
            }
            Item { width: 1; height: 10 }
            // invite : curseur, ou la commande armée avec sa jauge
            Text {
                readonly property int n: Math.round(m.p.armT * 16)
                text: m.armedNow
                      ? "$ " + m.cmdStr(m.armedAct) + "  ▕" + "█".repeat(n) + "░".repeat(16 - n) + "▏ "
                        + (3 - m.p.armT * 3).toFixed(1) + " s"
                      : m.reveal("$ ", 9) + (m.typed > 81 && Math.floor(m.frame / 30) % 2 === 0 ? "▌" : " ")
                font.family: m.mono; font.pixelSize: 17
                color: m.armedNow ? m.hot : Appearance.colors.fg
            }
            Text {
                text: m.armedNow ? "  échap ou clic pour annuler · entrée pour lancer tout de suite"
                                 : m.reveal("  ←→ choisir · entrée valider · l u e r s b · échap quitter", 10)
                font.family: m.mono; font.pixelSize: 13; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.35)
            }
        }

        // glitch : une tranche décalée qui traverse l'écran
        Rectangle {
            id: slice
            visible: m.glitchX !== 0
            x: -m.glitchX * 2; width: parent.width; height: 4 + Math.random() * 18
            y: Math.random() * parent.height
            color: ColorUtils.applyAlpha(m.hot, 0.3)
        }
        Rectangle { anchors.fill: parent; radius: 12; color: "#ffffff"; opacity: m.flash }
    }

    // petits glitchs au hasard
    Timer {
        id: glitchT
        running: m.visible && m.show > 0.9 && Appearance.animationsEnabled
        interval: 2600 + Math.random() * 4000
        repeat: true
        onTriggered: { interval = 2600 + Math.random() * 4000; glitch.restart() }
    }
    SequentialAnimation {
        id: glitch
        NumberAnimation { target: m; property: "glitchX"; to: 9; duration: 35 }
        NumberAnimation { target: m; property: "glitchX"; to: -6; duration: 35 }
        NumberAnimation { target: m; property: "glitchX"; to: 3; duration: 35 }
        NumberAnimation { target: m; property: "glitchX"; to: 0; duration: 45 }
    }
}
