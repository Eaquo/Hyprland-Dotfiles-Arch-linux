import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.core
import qs.core.functions
import qs.services

// NotifToasts — les notifications qui apparaissent (NotificationService.toasts), dans un coin
// ([notifications] position : top-right · top-left · bottom-right · bottom-left). Animation d'arrivée
// selon le style des menus ([menu] style, sinon [session] style). Survol = pause ; clic = action ;
// clic molette ou × = fermer. Créé seulement quand il y a des toasts (LazyLoader dans shell.qml).
PanelWindow {
    id: root

    screen: {
        const all = Quickshell.screens
        return all.find(s => !Config.isTouch(s)) || all[0]
    }
    readonly property string pos: String(Config.get("notifications.position", "top-right"))
    readonly property bool atTop: !pos.startsWith("bottom")
    readonly property bool atLeft: pos.endsWith("left")
    anchors { top: atTop; bottom: !atTop; left: atLeft; right: !atLeft }
    // sous la barre si elle est du même côté
    margins {
        top: atTop && !Appearance.bar.atBottom && !Appearance.bar.vertical ? Appearance.bar.thickness + 14 : 14
        bottom: !atTop && Appearance.bar.atBottom ? Appearance.bar.thickness + 14 : 14
        right: 14; left: 14
    }
    implicitWidth: 460
    implicitHeight: Math.max(1, stack.height + 30)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property string style: String(Config.get("menu.style", Config.get("session.style", "matrix")))
    readonly property bool busy: NotificationService.toasts.length > 0

    Column {
        id: stack
        x: 20; y: 10
        spacing: 12
        Repeater {
            model: ScriptModel { values: NotificationService.toasts }
            delegate: Item {
                id: t
                required property var modelData
                width: 420; height: c.implicitHeight
                property real k: 0                 // arrivée 0 → 1
                property real gone: 0              // départ 0 → 1
                property real gl: 0                // glitch (Netrunner)
                property real remain: 1            // temps restant 1 → 0
                readonly property int ms: NotificationService.toastMs(modelData)
                opacity: Math.min(1, t.k * 1.4) * (1 - t.gone)
                transform: [
                    Translate { x: (root.style === "card" ? (1 - t.k) * 460 : 0) * (root.atLeft ? -1 : 1) + t.gone * 460 * (root.atLeft ? -1 : 1)
                                     + (Math.random() - 0.5) * 22 * t.gl
                                y: root.style === "minimal" ? (1 - t.k) * (root.atTop ? -16 : 16) : 0 },
                    Scale { origin.y: t.height / 2; yScale: root.style === "matrix" ? Math.max(0.02, t.k) : 1 }
                ]
                Component.onCompleted: inA.start()
                SequentialAnimation {
                    id: inA
                    NumberAnimation { target: t; property: "k"; to: 1; duration: Appearance.dur(root.style === "matrix" ? 260 : 380); easing.type: root.style === "card" ? Easing.OutBack : Easing.OutCubic }
                    ScriptAction { script: if (t.ms > 0) life.start() }
                }
                SequentialAnimation {
                    running: root.style === "cyber" && t.k > 0 && t.k < 1
                    NumberAnimation { target: t; property: "gl"; to: 1; duration: 40 }
                    NumberAnimation { target: t; property: "gl"; to: 0.3; duration: 60 }
                    NumberAnimation { target: t; property: "gl"; to: 0.9; duration: 40 }
                    NumberAnimation { target: t; property: "gl"; to: 0; duration: 160 }
                }
                // temps de vie : en pause au survol
                NumberAnimation { id: life; target: t; property: "remain"; from: 1; to: 0; duration: t.ms; paused: c.hovered && running; onFinished: t.leave() }
                function leave() { if (!outA.running) outA.start() }
                SequentialAnimation {
                    id: outA
                    NumberAnimation { target: t; property: "gone"; to: 1; duration: Appearance.dur(280); easing.type: Easing.InCubic }
                    ScriptAction { script: NotificationService.hideToast(t.modelData) }
                }
                // Matrix : flash d'allumage · Jarvis : trait de balayage
                Rectangle { anchors.fill: parent; radius: c.rad(height); color: "white"; z: 2
                            opacity: root.style === "matrix" ? Math.max(0, 0.5 - t.k * 0.5) * (t.k > 0 ? 1 : 0) : 0 }
                Rectangle { visible: root.style === "jarvis" && t.k < 1; z: 2
                            x: 0; width: parent.width; height: 2; y: t.k * parent.height; color: c.glow }
                NotifCard {
                    id: c
                    anchors.fill: parent
                    notif: t.modelData
                    progress: t.ms > 0 ? t.remain : -1
                    onCloseRequested: t.leave()
                    // Jarvis : le contenu se révèle sous le trait
                    layer.enabled: root.style === "jarvis" && t.k < 1
                }
            }
        }
    }
}
