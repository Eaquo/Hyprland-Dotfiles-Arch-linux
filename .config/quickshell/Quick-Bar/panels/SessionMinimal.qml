import QtQuick
import QtQuick.Effects
import Quickshell
import qs.core
import qs.core.functions

// SessionMinimal — style « minimal » du SessionPanel ([session] style = "minimal"), plein écran.
// Le fond d'écran flouté sous un voile, une grande heure aux chiffres qui roulent, six mots,
// un trait élastique qui glisse ; pendant un compte à rebours l'heure laisse place au chiffre.
Item {
    id: m
    anchors.fill: parent

    required property var p
    readonly property int outMs: Appearance.dur(480)

    property real intro: 0               // 0 → 1 : les éléments arrivent en cascade
    function open() { outAnim.stop(); inAnim.restart() }
    function close() { inAnim.stop(); outAnim.restart() }
    NumberAnimation { id: inAnim; target: m; property: "intro"; from: 0; to: 1; duration: Appearance.dur(1300) }
    NumberAnimation { id: outAnim; target: m; property: "intro"; to: 0; duration: Appearance.dur(460) }
    // progression locale d'un élément : démarre à `d`, dure `span` (sur 0..1), sortie en cubique
    function st(d, span) { const t = Math.max(0, Math.min(1, (intro - d) / span)); return 1 - Math.pow(1 - t, 3) }

    readonly property bool armedNow: p.armed !== ""
    readonly property color hot: armedNow ? p.tint(p.sel) : (Appearance.contrastRatio(Appearance.colors.accent, Appearance.colors.bg) < 3.5
                                                             ? Qt.lighter(Appearance.colors.accent, 1.7) : Appearance.colors.accent)
    readonly property string fam: "JetBrainsMono Nerd Font"
    readonly property real big: Math.min(height * 0.27, 420)
    readonly property real u: Math.max(1, height / 1080)       // textes à l'échelle de l'écran
    readonly property string thin: "JetBrains Mono"            // a une vraie graisse Thin

    // ── fond : le fond d'écran flouté, qui se pose ────────────────────────
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
        anchors.fill: parent
        source: wall
        visible: wall.status === Image.Ready
        blurEnabled: true; blur: 1; blurMax: 64
        saturation: -0.2
        opacity: m.st(0, 0.3)
        scale: 1.12 - 0.12 * m.st(0, 0.6)
    }
    Rectangle { anchors.fill: parent; color: Appearance.colors.bg; opacity: 0.82 * m.st(0, 0.25) }
    MouseArea { anchors.fill: parent; onClicked: { if (m.armedNow) m.p.cancel(); else Popups.sessionOpen = false } }

    // halo qui respire derrière l'heure
    Rectangle {
        id: glowSrc
        width: m.big * 2.6; height: width; radius: width / 2
        color: m.hot
        visible: false; layer.enabled: true
    }
    MultiEffect {
        source: glowSrc
        width: glowSrc.width; height: glowSrc.height
        x: (m.width - width) / 2; y: clock.y + clock.height / 2 - height / 2
        blurEnabled: true; blur: 1; blurMax: 64; blurMultiplier: 2
        autoPaddingEnabled: true
        opacity: (0.14 + 0.08 * breath.v) * m.st(0.1, 0.4) * (m.armedNow ? 1.6 : 1)
        scale: 0.9 + 0.12 * breath.v
    }
    QtObject {
        id: breath
        property real v: 0
        property var a: SequentialAnimation {
            running: m.visible && Appearance.animationsEnabled; loops: Animation.Infinite
            NumberAnimation { target: breath; property: "v"; to: 1; duration: 3200; easing.type: Easing.InOutSine }
            NumberAnimation { target: breath; property: "v"; to: 0; duration: 3200; easing.type: Easing.InOutSine }
        }
    }

    // ── salutation ────────────────────────────────────────────────────────
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: clock.y - height - 18 + 14 * (1 - m.st(0.05, 0.35))
        opacity: m.st(0.05, 0.35)
        text: m.p.greeting.toLowerCase() + ", " + Config.userName
        font.family: m.fam; font.pixelSize: 18 * m.u; font.weight: Font.Light
        color: Appearance.colors.dim
    }

    // ── l'heure : chiffres qui roulent ────────────────────────────────────
    component Digit: Item {
        id: dg
        property string ch: "0"
        property real d: 0                       // retard d'arrivée
        property string cur: ""
        property string prev: ""
        property real roll: 1
        width: tm.advanceWidth; height: tm.height
        clip: true
        onChChanged: { prev = cur; cur = ch; if (prev !== "") rollAnim.restart() }
        Component.onCompleted: cur = ch
        NumberAnimation { id: rollAnim; target: dg; property: "roll"; from: 0; to: 1; duration: Appearance.dur(650); easing.type: Easing.OutBack; easing.overshoot: 1.1 }
        TextMetrics { id: tm; text: "0"; font.family: m.thin; font.pixelSize: m.big; font.weight: Font.Thin }
        Text { y: -dg.roll * dg.height; visible: dg.roll < 1; text: dg.prev; font: tm.font; color: Appearance.colors.fg
               opacity: 1 - dg.roll }
        Text {
            readonly property real k: m.st(dg.d, 0.35)
            y: (1 - dg.roll) * dg.height + (1 - k) * dg.height * 0.6
            opacity: k
            text: dg.cur; font: tm.font; color: Appearance.colors.fg
        }
    }
    Row {
        id: clock
        anchors.horizontalCenter: parent.horizontalCenter
        y: m.height * 0.42 - height / 2
        opacity: m.armedNow ? 0.08 : 1
        scale: m.armedNow ? 0.92 : 1
        Behavior on opacity { NumberAnimation { duration: Appearance.dur(300) } }
        Behavior on scale { NumberAnimation { duration: Appearance.dur(400); easing.type: Easing.OutCubic } }
        readonly property string hm: Qt.formatTime(m.p.now, "HHmm")
        Digit { ch: clock.hm[0]; d: 0.12 }
        Digit { ch: clock.hm[1]; d: 0.17 }
        Text {
            text: ":"; font.family: m.thin; font.pixelSize: m.big; font.weight: Font.Thin
            color: m.hot
            opacity: m.st(0.22, 0.3) * (0.35 + 0.65 * Math.abs(Math.cos(Math.PI * sec.frac)))
        }
        Digit { ch: clock.hm[2]; d: 0.27 }
        Digit { ch: clock.hm[3]; d: 0.32 }
    }
    // compte à rebours : le chiffre prend la place de l'heure
    Text {
        id: count
        anchors.centerIn: clock
        readonly property int n: Math.ceil(3 - m.p.armT * 3)
        text: Math.max(1, n)
        visible: opacity > 0
        opacity: m.armedNow ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Appearance.dur(250) } }
        font.family: m.thin; font.pixelSize: m.big * 1.1; font.weight: Font.Thin
        color: m.hot
        onNChanged: if (m.armedNow) pulse.restart()
        NumberAnimation { id: pulse; target: count; property: "scale"; from: 1.25; to: 1; duration: Appearance.dur(500); easing.type: Easing.OutCubic }
    }

    // trait des secondes sous l'heure
    QtObject {
        id: sec
        property real frac: 0
    }
    FrameAnimation { running: m.visible; onTriggered: { const d = new Date(); sec.frac = (d.getSeconds() + d.getMilliseconds() / 1000) / 60 } }
    Item {
        id: secLine
        anchors.horizontalCenter: parent.horizontalCenter
        y: clock.y + clock.height + 6
        width: clock.width * m.st(0.3, 0.45); height: 2
        Rectangle { anchors.fill: parent; radius: 1; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.1) }
        Rectangle { height: 2; radius: 1; width: parent.width * (m.armedNow ? m.p.armT : sec.frac); color: m.hot }
    }

    // date
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: secLine.y + 30
        readonly property real k: m.st(0.35, 0.4)
        opacity: k
        text: m.armedNow ? (m.p.actions[m.p.sel][2] + " dans " + count.n + " s  ·  échap pour annuler").toUpperCase()
                         : m.p.now.toLocaleDateString(Qt.locale("fr_FR"), "dddd d MMMM").toUpperCase() + (m.p.uptime ? "  ·  " + m.p.uptime : "")
        font.family: m.fam; font.pixelSize: 15 * m.u
        font.letterSpacing: 4 + 18 * (1 - k)
        color: m.armedNow ? m.hot : Appearance.colors.dim
    }

    // ── les six mots, et le trait élastique ───────────────────────────────
    Item {
        id: words
        anchors.horizontalCenter: parent.horizontalCenter
        y: m.height * 0.8
        width: wRow.width; height: wRow.height + 18

        Row {
            id: wRow
            spacing: 64 * m.u
            Repeater {
                id: rep
                model: m.p.actions
                delegate: Text {
                    id: w
                    required property var modelData
                    required property int index
                    readonly property bool on: m.p.sel === index
                    readonly property real k: m.st(0.45 + index * 0.05, 0.3)
                    text: modelData[2].toLowerCase()
                    font.family: m.fam; font.pixelSize: 21 * m.u; font.weight: on ? Font.Normal : Font.Light
                    font.letterSpacing: on ? 1.5 : 0
                    Behavior on font.letterSpacing { NumberAnimation { duration: Appearance.dur(250) } }
                    color: on ? (w.isArmed ? m.hot : Appearance.colors.fg) : ColorUtils.applyAlpha(Appearance.colors.fg, wMa.containsMouse ? 0.7 : 0.38)
                    Behavior on color { ColorAnimation { duration: Appearance.dur(200) } }
                    readonly property bool isArmed: m.p.armed === modelData[0]
                    opacity: k
                    transform: Translate { y: (1 - w.k) * 16 + (w.on ? -4 : 0); Behavior on y { enabled: w.k >= 1; NumberAnimation { duration: Appearance.dur(250); easing.type: Easing.OutCubic } } }
                    MouseArea {
                        id: wMa
                        anchors.fill: parent; anchors.margins: -12
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: if (!m.armedNow) m.p.sel = w.index
                        onClicked: m.p.trigger(w.index)
                    }
                }
            }
        }
        // trait : le bord qui avance part vite, l'autre suit en retard → il s'étire
        property bool goRight: true
        property int last: 0
        Connections { target: m.p; function onSelChanged() { words.goRight = m.p.sel >= words.last; words.last = m.p.sel } }
        readonly property Item cw: { m.p.sel; rep.count; return rep.itemAt(m.p.sel) }
        property real l: cw ? cw.x : 0
        property real r: cw ? cw.x + cw.width : 0
        Behavior on l { NumberAnimation { duration: Appearance.dur(words.goRight ? 460 : 200); easing.type: Easing.OutCubic } }
        Behavior on r { NumberAnimation { duration: Appearance.dur(words.goRight ? 200 : 460); easing.type: Easing.OutCubic } }
        Rectangle {
            x: words.l; width: Math.max(2, words.r - words.l)
            y: wRow.height + 12; height: 2; radius: 1
            color: m.hot
            opacity: m.st(0.75, 0.25)
            Behavior on color { ColorAnimation { duration: Appearance.dur(250) } }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 36
        opacity: 0.6 * m.st(0.8, 0.2)
        text: "←  →   ·   entrée   ·   l u e r s b   ·   échap"
        font.family: m.fam; font.pixelSize: 12 * m.u; color: Appearance.colors.dim
    }
}
