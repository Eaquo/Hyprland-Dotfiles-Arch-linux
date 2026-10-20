import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.core.functions

// Scan — une tâche longue avec barre de progression (mises à jour…). Le 1er item porte `cmd` :
// une commande dont chaque ligne de sortie fait avancer l'affichage :
//   STEP <i> <n> <libellé>   étape i sur n          SUB <k> <m>   avancement dans l'étape
//   ITEM <texte>              un résultat trouvé     DONE          fin (le script enchaîne lui-même)
// La barre suit le style des menus (menu.style) : blocs (matrix), rayures (cyber), trait lumineux
// gradué (jarvis), trait fin (minimal), pilule (carte).
Item {
    id: t
    required property var menu
    property real prefW: 900
    readonly property real contentH: 330
    property int cols: 1
    property bool filter: false
    property bool search: false
    property string hints: ""

    readonly property string cmd: ((menu.req.items || [])[0] || {}).cmd || ""
    readonly property string st: menu.style
    property int stepI: 0
    property int stepN: 1
    property string label: "Préparation…"
    property real sub: 0
    property var found: []
    property bool done: false
    readonly property real target: done ? 1 : Math.max(0, Math.min(1, (Math.max(0, stepI - 1) + sub) / Math.max(1, stepN)))
    property real p: 0
    Behavior on p { NumberAnimation { duration: Appearance.dur(500); easing.type: Easing.OutCubic } }
    onTargetChanged: p = target

    Process {
        id: proc
        running: t.cmd !== ""
        command: ["bash", "-c", t.cmd]
        stdout: SplitParser {
            onRead: (l) => {
                const w = l.split(" ")
                if (w[0] === "STEP") { t.stepI = +w[1]; t.stepN = +w[2]; t.sub = 0; t.label = w.slice(3).join(" ") }
                else if (w[0] === "SUB") t.sub = Math.min(1, +w[1] / Math.max(1, +w[2]))
                else if (w[0] === "ITEM") t.found = t.found.concat([w.slice(1).join(" ")])
                else if (w[0] === "DONE") { t.done = true; t.label = t.found.length ? t.found.length + " mise(s) à jour trouvée(s)" : "Le système est à jour" }
            }
        }
    }
    Component.onDestruction: proc.running = false

    // ── en-tête : étape + pourcentage ─────────────────────────────────────────
    Row {
        id: head
        x: 34; y: 26
        spacing: 16
        Text {
            text: Math.round(t.p * 100) + (t.st === "matrix" || t.st === "cyber" ? "%" : " %")
            font.family: t.st === "matrix" || t.st === "cyber" ? "JetBrains Mono" : Appearance.font.family
            font.pixelSize: 54; font.weight: t.st === "minimal" || t.st === "jarvis" ? Font.Light : Font.Bold
            color: Appearance.colors.fg
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Text { text: t.done ? "TERMINÉ" : "ÉTAPE " + Math.max(1, t.stepI) + " / " + t.stepN
                   font.family: Appearance.font.family; font.pixelSize: 11; font.letterSpacing: 3; color: t.menu.glow }
            Text { text: t.label; font.family: Appearance.font.family; font.pixelSize: 17; color: Appearance.colors.fg }
        }
    }

    // ── la barre ──────────────────────────────────────────────────────────────
    Item {
        id: bar
        x: 34; y: head.y + head.height + 22
        width: parent.width - 68
        height: t.st === "jarvis" || t.st === "minimal" ? 4 : t.st === "matrix" ? 20 : 16
        readonly property real r: t.st === "matrix" ? 2 : t.menu.rad(height)

        // matrix : 48 blocs qui s'allument
        Row {
            visible: t.st === "matrix"
            anchors.fill: parent
            spacing: 4
            Repeater {
                model: 48
                Rectangle {
                    required property int index
                    width: (bar.width - 47 * 4) / 48; height: bar.height; radius: 2
                    readonly property bool lit: (index + 1) / 48 <= t.p + 0.001
                    color: lit ? t.menu.glow : ColorUtils.applyAlpha(Appearance.colors.fg, 0.07)
                    opacity: lit ? 0.55 + 0.45 * ((index % 6) === 0 ? 1 : 0.7) : 1
                    Behavior on color { ColorAnimation { duration: Appearance.dur(160) } }
                }
            }
        }
        // les autres : piste + remplissage
        Rectangle {
            id: track
            visible: t.st !== "matrix"
            anchors.fill: parent; radius: bar.r
            color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
            clip: true
            Rectangle {
                id: fill
                height: parent.height; width: Math.max(parent.height, parent.width * t.p); radius: bar.r
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: ColorUtils.applyAlpha(t.menu.glow, 0.55) }
                    GradientStop { position: 1.0; color: t.menu.glow }
                }
                clip: true
                // cyber : rayures qui défilent
                Row {
                    visible: t.st === "cyber"
                    x: -40 + stripeOff; spacing: 14
                    property real stripeOff: 0
                    NumberAnimation on stripeOff { from: 0; to: 28; duration: 600; loops: Animation.Infinite; running: t.st === "cyber" && !t.done }
                    Repeater {
                        model: Math.ceil(bar.width / 28) + 3
                        Rectangle { width: 14; height: 40; y: -12; rotation: 30; color: ColorUtils.applyAlpha("#000000", 0.22) }
                    }
                }
                // reflet qui glisse (carte, minimal, jarvis)
                Rectangle {
                    visible: t.st !== "cyber" && !t.done
                    width: 120; height: parent.height; x: shine * (fill.width + 240) - 120
                    property real shine: 0
                    NumberAnimation on shine { from: 0; to: 1; duration: 1400; loops: Animation.Infinite; running: !t.done }
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: ColorUtils.applyAlpha("#ffffff", 0.35) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }
        }
        // jarvis : graduations sous le trait, et la tête lumineuse
        Repeater {
            model: t.st === "jarvis" ? 21 : 0
            Rectangle {
                required property int index
                x: index / 20 * bar.width - 1; y: bar.height + 6
                width: 2; height: index % 5 === 0 ? 10 : 5
                color: ColorUtils.applyAlpha(index / 20 <= t.p ? t.menu.glow : Appearance.colors.fg, index / 20 <= t.p ? 0.9 : 0.18)
            }
        }
        Rectangle {
            visible: t.st === "jarvis" || t.st === "minimal"
            width: 12; height: 12; radius: 6
            x: bar.width * t.p - 6; anchors.verticalCenter: parent.verticalCenter
            color: Appearance.colors.fg
            border.width: 3; border.color: t.menu.glow
        }
    }

    // ── ce qui a été trouvé ───────────────────────────────────────────────────
    Text {
        id: fh
        x: 34; y: bar.y + bar.height + (t.st === "jarvis" ? 34 : 24)
        text: t.found.length ? "TROUVÉ · " + t.found.length : "RECHERCHE…"
        font.family: Appearance.font.family; font.pixelSize: 11; font.letterSpacing: 3; color: Appearance.colors.dim
    }
    Flow {
        x: 34; y: fh.y + fh.height + 10
        width: parent.width - 68; height: parent.height - y - 14
        spacing: 8
        clip: true
        Repeater {
            model: t.found.slice(-40)
            Rectangle {
                id: chip
                required property string modelData
                height: 30; width: ct.implicitWidth + 24; radius: t.menu.rad(30)
                color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.06)
                border.width: 1; border.color: ColorUtils.applyAlpha(t.menu.glow, 0.35)
                opacity: 0; scale: 0.8
                Component.onCompleted: { opacity = 1; scale = 1 }
                Behavior on opacity { NumberAnimation { duration: Appearance.dur(260) } }
                Behavior on scale { NumberAnimation { duration: Appearance.dur(260); easing.type: Easing.OutBack } }
                Text { id: ct; anchors.centerIn: parent; text: chip.modelData
                       font.family: "JetBrains Mono"; font.pixelSize: 12; color: Appearance.colors.fg }
            }
        }
    }

    // ligne de balayage sur toute la zone tant que ça cherche
    Rectangle {
        visible: !t.done && t.st !== "minimal"
        width: parent.width; height: 2
        y: sweep * parent.height
        property real sweep: 0
        NumberAnimation on sweep { from: 0; to: 1; duration: 1800; loops: Animation.Infinite; running: !t.done }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: ColorUtils.applyAlpha(t.menu.glow, 0.5) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
