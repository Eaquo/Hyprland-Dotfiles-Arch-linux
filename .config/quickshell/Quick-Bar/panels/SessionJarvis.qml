import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import qs.core
import qs.core.functions
import qs.services

// SessionJarvis — style « jarvis » du SessionPanel ([session] style = "jarvis"), plein écran.
// HUD holographique : un réacteur à anneaux qui se tracent puis tournent ; les six actions sont ses
// secteurs (survol / clic), une ligne de rappel relie le secteur choisi à sa fiche. Coins : diagnostic
// (SysData), session, radar, journal de démarrage. Compte à rebours : le réacteur s'emballe, « T-2.4 ».
Item {
    id: m
    anchors.fill: parent

    required property var p
    readonly property int outMs: Appearance.dur(520)

    property real intro: 0
    property real t: 0                   // temps des rotations (accéléré pendant un compte à rebours)
    property real spd: armedNow ? 5 : 1
    Behavior on spd { NumberAnimation { duration: Appearance.dur(700); easing.type: Easing.InOutCubic } }
    property real co: 1                  // tracé de la ligne de rappel (0 → 1 à chaque sélection)
    readonly property real u: Math.max(1, height / 1080)
    readonly property bool armedNow: p.armed !== ""
    function light(c) {
        if (Appearance.contrastRatio(c, "#000000") >= 5) return c
        return c.hslSaturation < 0.12 ? Qt.hsla(0, 0, 0.8, 1) : Qt.hsla(c.hslHue, Math.max(c.hslSaturation, 0.6), 0.66, 1)
    }
    readonly property color acc: light(Appearance.colors.accent)
    readonly property color hot: armedNow ? light(p.tint(p.sel)) : acc
    readonly property string disp: "Bahnschrift"
    readonly property string mono: "JetBrainsMono Nerd Font"

    function st(d, span) { const k = Math.max(0, Math.min(1, (intro - d) / span)); return 1 - Math.pow(1 - k, 3) }
    function open() { outA.stop(); inA.restart() }
    function close() { inA.stop(); outA.restart() }
    NumberAnimation { id: inA; target: m; property: "intro"; from: 0; to: 1; duration: Appearance.dur(1900) }
    NumberAnimation { id: outA; target: m; property: "intro"; to: 0; duration: Appearance.dur(500); easing.type: Easing.InCubic }
    Connections { target: m.p; function onSelChanged() { coA.restart() } }
    NumberAnimation { id: coA; target: m; property: "co"; from: 0; to: 1; duration: Appearance.dur(420); easing.type: Easing.OutCubic }
    FrameAnimation { running: m.visible; onTriggered: m.t += frameTime * m.spd }

    // ── fond ──────────────────────────────────────────────────────────────
    Image {
        id: wall
        anchors.fill: parent
        visible: false
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(Math.round(width / 3), Math.round(height / 3))
        source: !WallpaperState.videoMode && WallpaperState.currentWall !== ""
                ? (WallpaperState.currentWall.startsWith("file:") ? WallpaperState.currentWall : "file://" + WallpaperState.currentWall) : ""
    }
    MultiEffect {
        anchors.fill: parent; source: wall; visible: wall.status === Image.Ready
        blurEnabled: true; blur: 1; blurMax: 64; saturation: -0.5
        opacity: m.st(0, 0.2)
    }
    Rectangle { anchors.fill: parent; color: Qt.darker(Appearance.colors.bg, 1.6); opacity: 0.9 * m.st(0, 0.2) }
    // trame hexagonale
    Canvas {
        anchors.fill: parent
        opacity: 0.07 * m.st(0.05, 0.3)
        property color c: m.acc
        onCChanged: requestPaint()
        onPaint: {
            const g = getContext("2d"); g.clearRect(0, 0, width, height)
            g.strokeStyle = c; g.lineWidth = 1
            const s = 26 * m.u, h = s * Math.sqrt(3)
            for (let y = 0, row = 0; y < height + h; y += h / 2, row++)
                for (let x = (row % 2) * s * 1.5; x < width + s * 2; x += s * 3) {
                    g.beginPath()
                    for (let k = 0; k < 6; k++) { const a = Math.PI / 3 * k; g.lineTo(x + s * Math.cos(a), y + s * Math.sin(a)) }
                    g.closePath(); g.stroke()
                }
        }
    }
    MouseArea { anchors.fill: parent; onClicked: { if (m.armedNow) m.p.cancel(); else Popups.sessionOpen = false } }

    // ── réacteur ──────────────────────────────────────────────────────────
    readonly property real cx: width / 2
    readonly property real cy: height * 0.53
    readonly property real rad: Math.min(height * 0.3, width * 0.2)

    component Arc: Shape {
        id: arc
        property real r: 100
        property real w: 2
        property real start: 0
        property real sweep: 360
        property color col: m.acc
        property int cap: ShapePath.FlatCap
        property var dash: []
        anchors.fill: parent
        ShapePath {
            strokeColor: arc.col; strokeWidth: arc.w; fillColor: "transparent"; capStyle: arc.cap
            strokeStyle: arc.dash.length ? ShapePath.DashLine : ShapePath.SolidLine
            dashPattern: arc.dash.length ? arc.dash : [1, 0]
            PathAngleArc { centerX: m.cx; centerY: m.cy; radiusX: arc.r; radiusY: arc.r; startAngle: arc.start; sweepAngle: arc.sweep }
        }
    }

    // halo derrière le réacteur
    Rectangle { id: haloSrc; width: m.rad * 2.2; height: width; radius: width / 2; color: m.hot; visible: false; layer.enabled: true }
    MultiEffect {
        source: haloSrc
        x: m.cx - width / 2; y: m.cy - height / 2; width: haloSrc.width; height: haloSrc.height
        blurEnabled: true; blur: 1; blurMax: 64; blurMultiplier: 2.5
        autoPaddingEnabled: true
        opacity: m.st(0.1, 0.4) * (m.armedNow ? 0.3 + 0.15 * Math.sin(m.t * 2) : 0.16 + 0.04 * Math.sin(m.t * 1.3))
    }

    Item {
        id: reactor
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: m.hot; shadowBlur: 0.8; shadowOpacity: 0.9
                                    shadowHorizontalOffset: 0; shadowVerticalOffset: 0; autoPaddingEnabled: false }

        // graduations extérieures (tournent lentement)
        Canvas {
            id: ticks
            x: m.cx - width / 2; y: m.cy - height / 2
            width: m.rad * 2.5; height: width
            rotation: m.t * 4
            opacity: m.st(0.05, 0.3)
            property color c: m.hot
            onCChanged: requestPaint()
            onPaint: {
                const g = getContext("2d"); g.clearRect(0, 0, width, height)
                const c0 = width / 2, r = width / 2 - 2
                g.strokeStyle = c; g.globalAlpha = 0.6
                for (let a = 0; a < 360; a += 3) {
                    const big = a % 30 === 0, rad = a * Math.PI / 180, l = big ? 16 * m.u : 6 * m.u
                    g.lineWidth = big ? 2 : 1
                    g.beginPath(); g.moveTo(c0 + Math.cos(rad) * r, c0 + Math.sin(rad) * r)
                    g.lineTo(c0 + Math.cos(rad) * (r - l), c0 + Math.sin(rad) * (r - l)); g.stroke()
                }
            }
        }
        Arc { r: m.rad * 1.12; w: 1; col: ColorUtils.applyAlpha(m.hot, 0.45); start: -90; sweep: 360 * m.st(0.08, 0.35) }
        Arc { r: m.rad * 1.04; w: 3 * m.u; col: ColorUtils.applyAlpha(m.hot, 0.7); start: m.t * -12; sweep: 40 * m.st(0.12, 0.3) }
        Arc { r: m.rad * 1.04; w: 3 * m.u; col: ColorUtils.applyAlpha(m.hot, 0.7); start: m.t * -12 + 180; sweep: 40 * m.st(0.12, 0.3) }

        // les six secteurs = les actions
        Repeater {
            model: m.p.actions
            delegate: Arc {
                id: sec
                required property int index
                readonly property bool on: m.p.sel === index
                property real grow: on ? 14 * m.u : 0
                Behavior on grow { NumberAnimation { duration: Appearance.dur(260); easing.type: Easing.OutBack; easing.overshoot: 2 } }
                r: m.rad * 0.86 + grow
                w: 50 * m.u
                start: -90 - 26 + index * 60
                sweep: 52 * m.st(0.18 + index * 0.05, 0.25)
                col: on ? ColorUtils.applyAlpha(m.hot, m.armedNow ? 0.6 + 0.4 * Math.abs(Math.sin(m.t * 1.5)) : 0.95)
                        : ColorUtils.applyAlpha(m.acc, 0.22)
            }
        }
        // anneaux intérieurs
        Repeater {
            model: 3
            delegate: Arc {
                required property int index
                r: m.rad * 0.66; w: 2 * m.u; col: ColorUtils.applyAlpha(m.hot, 0.55)
                start: -m.t * 20 + index * 120; sweep: 70 * m.st(0.3, 0.3)
            }
        }
        Arc { r: m.rad * 0.58; w: 1; col: ColorUtils.applyAlpha(m.hot, 0.35); dash: [2, 4]; start: m.t * 8; sweep: 360 * m.st(0.32, 0.3) }
        // jauge du compte à rebours
        Arc { visible: m.armedNow; r: m.rad * 0.58; w: 6 * m.u; col: m.hot; start: -90; sweep: 360 * m.p.armT }
        Repeater {
            model: 4
            delegate: Arc {
                required property int index
                r: m.rad * 0.5; w: 4 * m.u; col: ColorUtils.applyAlpha(m.hot, 0.8)
                start: m.t * 45 + index * 90; sweep: 18 * m.st(0.36, 0.3)
            }
        }
    }

    // icônes des secteurs
    Repeater {
        model: m.p.actions
        delegate: Text {
            required property var modelData
            required property int index
            readonly property bool on: m.p.sel === index
            readonly property real a: (-90 + index * 60) * Math.PI / 180
            readonly property real rr: m.rad * 0.86 + (on ? 14 * m.u : 0)
            x: m.cx + Math.cos(a) * rr - width / 2; y: m.cy + Math.sin(a) * rr - height / 2
            Behavior on x { NumberAnimation { duration: Appearance.dur(260) } }
            Behavior on y { NumberAnimation { duration: Appearance.dur(260) } }
            text: modelData[1]
            font.family: m.mono; font.pixelSize: 26 * m.u
            color: on ? "#000000" : Appearance.colors.fg
            opacity: m.st(0.3 + index * 0.05, 0.25) * (on ? 1 : 0.8)
        }
    }
    // survol / clic sur les secteurs
    MouseArea {
        x: m.cx - m.rad * 1.15; y: m.cy - m.rad * 1.15; width: m.rad * 2.3; height: width
        hoverEnabled: true
        cursorShape: hit(mouseX, mouseY) >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
        function hit(x, y) {
            const dx = x - width / 2, dy = y - height / 2, d = Math.sqrt(dx * dx + dy * dy)
            if (d < m.rad * 0.62 || d > m.rad * 1.1) return -1
            const a = (Math.atan2(dy, dx) * 180 / Math.PI + 90 + 30 + 360) % 360
            return Math.floor(a / 60)
        }
        onPositionChanged: (e) => { const i = hit(e.x, e.y); if (i >= 0 && !m.armedNow) m.p.sel = i }
        onClicked: (e) => { const i = hit(e.x, e.y); if (i >= 0) m.p.trigger(i); else if (m.armedNow) m.p.cancel(); else Popups.sessionOpen = false }
    }

    // centre : heure, ou compte à rebours
    Column {
        x: m.cx - width / 2; y: m.cy - height / 2
        opacity: m.st(0.4, 0.3)
        spacing: 4 * m.u
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "J.A.R.V.I.S."
               font.family: m.mono; font.pixelSize: 14 * m.u; font.letterSpacing: 6; color: m.hot }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: m.armedNow ? "T-" + (3 - m.p.armT * 3).toFixed(1) : Qt.formatTime(m.p.now, "HH:mm")
            font.family: m.disp; font.pixelSize: 84 * m.u; font.weight: Font.Light; color: Appearance.colors.fg
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: m.hot; shadowBlur: 1; shadowOpacity: 0.7
                                        shadowHorizontalOffset: 0; shadowVerticalOffset: 0; autoPaddingEnabled: true }
        }
        Text { anchors.horizontalCenter: parent.horizontalCenter
               text: (m.p.actions[m.p.sel][2]).toUpperCase()
               font.family: m.disp; font.pixelSize: 20 * m.u; font.letterSpacing: 5; color: m.hot }
    }

    // ── ligne de rappel vers la fiche de l'action ─────────────────────────
    readonly property real ang: (-90 + p.sel * 60) * Math.PI / 180
    readonly property int side: Math.cos(ang) > -0.01 ? 1 : -1
    readonly property point p0: Qt.point(cx + Math.cos(ang) * (rad * 0.86 + 44 * u), cy + Math.sin(ang) * (rad * 0.86 + 44 * u))
    readonly property point p1: Qt.point(cx + Math.cos(ang) * rad * 1.34 + side * 30 * u, cy + Math.sin(ang) * rad * 1.34)
    readonly property point p2: Qt.point(p1.x + side * Math.max(260 * u, card.width + 30 * u), p1.y)
    readonly property real c1: Math.min(1, co * 2) * st(0.6, 0.2)
    readonly property real c2: Math.max(0, co * 2 - 1) * st(0.6, 0.2)
    Shape {
        anchors.fill: parent
        layer.enabled: true; layer.samples: 4
        ShapePath {
            strokeColor: m.hot; strokeWidth: 2 * m.u; fillColor: "transparent"
            startX: m.p0.x; startY: m.p0.y
            PathLine { x: m.p0.x + (m.p1.x - m.p0.x) * m.c1; y: m.p0.y + (m.p1.y - m.p0.y) * m.c1 }
            PathLine { x: m.p1.x + (m.p2.x - m.p1.x) * m.c2 * (m.c1 >= 1 ? 1 : 0); y: m.p1.y }
        }
    }
    Rectangle { x: m.p0.x - 5 * m.u; y: m.p0.y - 5 * m.u; width: 10 * m.u; height: width; radius: width / 2; color: m.hot; opacity: m.st(0.6, 0.2) }
    Column {
        id: card
        readonly property real k: Math.max(0, (m.co - 0.75) * 4) * m.st(0.6, 0.2)
        x: m.side > 0 ? m.p2.x - width : m.p2.x
        y: m.p1.y - height - 8 * m.u
        opacity: k
        spacing: 2 * m.u
        Text { anchors.right: m.side > 0 ? parent.right : undefined
               text: m.p.actions[m.p.sel][2].toUpperCase(); font.family: m.disp; font.pixelSize: 28 * m.u; font.weight: Font.DemiBold
               font.letterSpacing: 3; color: Appearance.colors.fg }
        Text { anchors.right: m.side > 0 ? parent.right : undefined
               text: m.p.actions[m.p.sel][6].filter(x => x !== "sh" && x !== "-c" && x !== "bash").join(" ").replace(/ \|\|.*/, "").replace(Quickshell.env("HOME"), "~")
               font.family: m.mono; font.pixelSize: 13 * m.u; color: m.hot }
        Text { anchors.right: m.side > 0 ? parent.right : undefined
               text: m.p.actions[m.p.sel][5] ? "CONFIRMATION 3 S · TOUCHE " + m.p.actions[m.p.sel][3].toUpperCase()
                                              : "IMMÉDIAT · TOUCHE " + m.p.actions[m.p.sel][3].toUpperCase()
               font.family: m.mono; font.pixelSize: 12 * m.u; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.5); font.letterSpacing: 2 }
    }

    // ── coins ─────────────────────────────────────────────────────────────
    component Corner: Item {
        id: cn
        property string title
        property bool onRight: false
        default property alias content: col.data
        width: 360 * m.u; height: col.implicitHeight + 40 * m.u
        Rectangle { width: 60 * m.u * m.st(0.2, 0.3); height: 2; color: m.hot; x: cn.onRight ? parent.width - width : 0 }
        Rectangle { width: 2; height: 30 * m.u * m.st(0.2, 0.3); color: m.hot; x: cn.onRight ? parent.width - 2 : 0 }
        Text { x: cn.onRight ? parent.width - width - 14 * m.u : 14 * m.u; y: 10 * m.u; text: cn.title
               font.family: m.mono; font.pixelSize: 13 * m.u; font.letterSpacing: 4; color: m.hot; opacity: m.st(0.3, 0.3) }
        Column { id: col; x: 14 * m.u; y: 36 * m.u; width: parent.width - 28 * m.u; spacing: 8 * m.u; opacity: m.st(0.4, 0.3) }
    }
    component Gauge: Item {
        id: ga
        property string label
        property real value: 0        // 0..1
        property string txt
        width: parent ? parent.width : 300; height: 26 * m.u
        Text { text: ga.label; font.family: m.mono; font.pixelSize: 13 * m.u; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.7) }
        Text { anchors.right: parent.right; text: ga.txt; font.family: m.mono; font.pixelSize: 13 * m.u; color: Appearance.colors.fg }
        Rectangle { y: 19 * m.u; width: parent.width; height: 3 * m.u; color: ColorUtils.applyAlpha(m.hot, 0.15)
            Rectangle { height: parent.height; color: m.hot; width: parent.width * Math.min(1, ga.value) * m.st(0.5, 0.4)
                        Behavior on width { NumberAnimation { duration: Appearance.dur(500) } } } }
    }

    Corner {
        x: m.width * 0.05; y: m.height * 0.07
        title: "DIAGNOSTIC SYSTÈME"
        Gauge { label: "PROCESSEUR"; value: SysData.cpu / 100; txt: SysData.cpu + " %" }
        Gauge { label: "MÉMOIRE"; value: SysData.memPct / 100; txt: SysData.memPct + " %" }
        Gauge { label: "TEMP. CPU"; value: SysData.cpuT / 100; txt: Math.round(SysData.cpuT) + " °C" }
        Gauge { label: "TEMP. GPU"; value: SysData.gpuT / 110; txt: Math.round(SysData.gpuT) + " °C" }
    }
    Corner {
        x: m.width * 0.95 - width; y: m.height * 0.07
        title: "SESSION"; onRight: true
        Repeater {
            model: [["UTILISATEUR", Config.userName], ["DATE", m.p.now.toLocaleDateString(Qt.locale("fr_FR"), "d MMMM yyyy")],
                    ["EN LIGNE DEPUIS", m.p.uptime || "—"], ["ÉTAT", m.armedNow ? "CONFIRMATION REQUISE" : "EN ATTENTE D'ORDRE"]]
            delegate: Item {
                required property var modelData
                width: parent.width; height: 18 * m.u
                Text { text: parent.modelData[0]; font.family: m.mono; font.pixelSize: 13 * m.u; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.55) }
                Text { anchors.right: parent.right; text: String(parent.modelData[1]).toUpperCase(); font.family: m.mono; font.pixelSize: 13 * m.u
                       color: parent.modelData[0] === "ÉTAT" ? m.hot : Appearance.colors.fg }
            }
        }
    }

    // radar
    Item {
        id: radar
        x: m.width * 0.05 + 14 * m.u; y: m.height * 0.93 - height
        width: 170 * m.u; height: width
        opacity: m.st(0.45, 0.3)
        Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.width: 1; border.color: ColorUtils.applyAlpha(m.hot, 0.5) }
        Rectangle { anchors.centerIn: parent; width: parent.width * 0.6; height: width; radius: width / 2; color: "transparent"
                    border.width: 1; border.color: ColorUtils.applyAlpha(m.hot, 0.25) }
        Rectangle { anchors.centerIn: parent; width: parent.width; height: 1; color: ColorUtils.applyAlpha(m.hot, 0.2) }
        Rectangle { anchors.centerIn: parent; width: 1; height: parent.height; color: ColorUtils.applyAlpha(m.hot, 0.2) }
        Shape {
            anchors.fill: parent
            rotation: m.t * 90
            layer.enabled: true; layer.samples: 4
            ShapePath {
                strokeColor: "transparent"
                fillGradient: ConicalGradient {
                    centerX: radar.width / 2; centerY: radar.height / 2; angle: 0
                    GradientStop { position: 0.0; color: ColorUtils.applyAlpha(m.hot, 0.6) }
                    GradientStop { position: 0.2; color: "transparent" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                PathAngleArc { centerX: radar.width / 2; centerY: radar.height / 2; radiusX: radar.width / 2 - 1; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
            }
        }
        Repeater {
            model: 5
            delegate: Rectangle {
                required property int index
                readonly property real a: index * 2.3 + 0.7
                readonly property real d: (0.25 + (index * 0.37) % 0.65) * radar.width / 2
                x: radar.width / 2 + Math.cos(a) * d - 3; y: radar.height / 2 + Math.sin(a) * d - 3
                width: 6; height: 6; radius: 3; color: m.hot
                opacity: 0.3 + 0.7 * Math.abs(Math.sin(m.t * 1.5 + index))
            }
        }
        Text { anchors.left: parent.right; anchors.leftMargin: 18 * m.u; anchors.bottom: parent.bottom
               text: "BALAYAGE PÉRIMÈTRE\n" + (SysData.net.iface || "réseau").toUpperCase() + " · ↓ " + SysData.rate(SysData.net.rx || 0)
               font.family: m.mono; font.pixelSize: 12 * m.u; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.6); lineHeight: 1.3 }
    }

    // journal de démarrage, tapé
    Column {
        x: m.width * 0.95 - width; y: m.height * 0.93 - height
        width: 440 * m.u
        spacing: 4 * m.u
        Repeater {
            model: ["> initialisation du protocole de session", "> liaison avec Hyprland ........ ok",
                    "> utilisateur authentifié : " + Config.userName, "> " + (m.armedNow ? "confirmation de l'ordre en cours" : "en attente d'un ordre, monsieur")]
            delegate: Text {
                required property string modelData
                required property int index
                anchors.right: parent.right
                readonly property real k: m.st(0.45 + index * 0.1, 0.25)
                text: modelData.slice(0, Math.round(modelData.length * k)) + (index === 3 && Math.floor(m.t * 2) % 2 ? "▌" : "")
                font.family: m.mono; font.pixelSize: 13 * m.u
                color: index === 3 ? m.hot : ColorUtils.applyAlpha(Appearance.colors.fg, 0.55)
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: m.height * 0.955
        opacity: 0.6 * m.st(0.7, 0.2)
        text: m.armedNow ? "ÉCHAP OU CLIC POUR ANNULER  ·  ENTRÉE POUR EXÉCUTER TOUT DE SUITE"
                         : "←  →  CHOISIR   ·   ENTRÉE  EXÉCUTER   ·   L U E R S B   ·   ÉCHAP  FERMER"
        font.family: m.mono; font.pixelSize: 12 * m.u; font.letterSpacing: 2; color: Appearance.colors.fg
    }
}
