import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.core
import qs.core.functions

// WindowMode — mode fenêtres plein écran (façon Defi), affiché tant que le submap Hyprland « fenetres » est actif
// (SUPER+MAJ+A, ~/.config/hypr/configs lua/WindowMode.lua). Les touches sont gérées par Hyprland ; ici on montre
// le bureau qui se dézoome en carte (aperçus live à leur vraie place, fenêtre active cerclée d'accent), le numéro
// d'espace en grand et les espaces 1…10 au-dessus, la fenêtre active dessous, l'aide-mémoire en pied d'écran
// (la touche utilisée s'allume). Sortie : la carte replonge en plein écran.
// Ne prend ni le clavier ni la souris. Créé à l'entrée du mode, détruit à la sortie (shell.qml).
PanelWindow {
    id: root
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) || Quickshell.screens[0]
    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:winmode"
    mask: Region {}

    property bool shown: true             // false = en train de partir (shell.qml détruit après le zoom)
    readonly property var mon: Hyprland.focusedMonitor
    readonly property var mo: mon?.lastIpcObject ?? ({})
    readonly property int wsId: mon?.activeWorkspace?.id ?? 1
    readonly property var wins: Hyprland.toplevels.values.filter(t => t.workspace?.id === wsId && t.lastIpcObject?.mapped !== false)
    readonly property var act: Hyprland.activeToplevel
    readonly property bool actHere: !!act && act.workspace?.id === wsId
    readonly property color accent: Appearance.contrastRatio(Appearance.colors.accent, Appearance.colors.bg) < 3.5
                                    ? Qt.lighter(Appearance.colors.accent, 1.7) : Appearance.colors.accent
    readonly property color fg: Appearance.colors.fg
    readonly property string font: Appearance.font.family
    readonly property string wallSrc: WallpaperState.videoMode
        ? "file://" + Quickshell.env("HOME") + "/.curr_wall_static.jpg"
        : (WallpaperState.currentWall !== "" ? "file://" + WallpaperState.currentWall : "")
    function appName(cls) { return DesktopEntries.heuristicLookup(cls ?? "")?.name ?? cls ?? "" }
    function iconOf(cls) { return Quickshell.iconPath(DesktopEntries.heuristicLookup(cls ?? "")?.icon ?? (cls ?? ""), "application-x-executable") }

    // ponytail: pas d'événement Hyprland pour un redimensionnement → rafraîchi 5×/s, uniquement pendant le mode
    // (requête socket, pas de processus)
    Timer { interval: 200; running: root.shown; repeat: true; triggeredOnStart: true
            onTriggered: { Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces(); Hyprland.refreshMonitors() } }

    // ── zoom : 0 = plein écran (le bureau), 1 = carte au centre ──
    readonly property real sc: Number(Config.get("winmode.scale", 0.6))
    property real z: 0
    readonly property real ez: 1 - Math.pow(1 - z, 4)            // sortie douce, sans rebond
    NumberAnimation on z { id: zIn; running: true; to: 1; duration: Appearance.dur(560) }
    onShownChanged: if (!shown) { zIn.stop(); zOut.start() }
    NumberAnimation { id: zOut; target: root; property: "z"; to: 0; duration: Appearance.dur(420); easing.type: Easing.InOutCubic }
    // le décor arrive après la carte
    readonly property real ui: Math.max(0, Math.min(1, (z - 0.45) / 0.55))
    readonly property real cw: width * sc
    readonly property real ch: height * sc
    readonly property real cx: (width - cw) / 2
    readonly property real cy: (height - ch) / 2 + 20

    // ── la touche utilisée s'allume dans l'aide-mémoire ──
    property string lit: ""
    function flash(k) { lit = k; litOff.restart() }
    Timer { id: litOff; interval: 520; onTriggered: root.lit = "" }
    property int _ws: 0
    property real slide: 0                // glissement de la carte au changement d'espace
    onWsIdChanged: {
        flash("espace")
        if (_ws > 0) { slideAnim.from = wsId > _ws ? 1 : -1; slideAnim.restart() }
        _ws = wsId
    }
    NumberAnimation { id: slideAnim; target: root; property: "slide"; to: 0; duration: Appearance.dur(420); easing.type: Easing.OutQuart }
    onActChanged: if (actHere) flash("fenêtre")
    readonly property string actSize: JSON.stringify(act?.lastIpcObject?.size ?? [])
    readonly property string actAt: JSON.stringify(act?.lastIpcObject?.at ?? [])
    readonly property bool actFloat: act?.lastIpcObject?.floating ?? false
    readonly property bool actFull: (act?.lastIpcObject?.fullscreen ?? 0) > 0
    property var _was: null               // ne pas confondre un changement de fenêtre avec un redimensionnement
    onActSizeChanged: { if (act === _was) flash("taille"); _was = act }
    onActAtChanged: { if (act === _was && lit !== "taille") flash("déplacer"); _was = act }
    onActFloatChanged: if (act === _was) flash("flottante")
    onActFullChanged: if (act === _was) flash("plein écran")

    // ── fond : fond d'écran très flouté, voile et vignettage ──
    Image { id: wall; anchors.fill: parent; visible: false; source: root.wallSrc; fillMode: Image.PreserveAspectCrop
            asynchronous: true; sourceSize.width: 1280 }
    Item {
        anchors.fill: parent
        opacity: root.ez
        MultiEffect { anchors.fill: parent; source: wall; blurEnabled: true; blur: 1; blurMax: 64; saturation: -0.3 }
        Rectangle { anchors.fill: parent; color: Appearance.colors.bg; opacity: 0.72 }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: ColorUtils.applyAlpha("#000000", 0.35) }
                GradientStop { position: 0.35; color: "transparent" }
                GradientStop { position: 0.75; color: "transparent" }
                GradientStop { position: 1.0; color: ColorUtils.applyAlpha("#000000", 0.45) }
            }
        }
    }

    // ── la carte : le bureau, qui rétrécit vers sa place ──
    Item {
        id: stage
        anchors.fill: parent
        readonly property real k: 1 / root.sc + (1 - 1 / root.sc) * root.ez
        transform: [
            Scale { origin.x: root.width / 2; origin.y: root.cy + root.ch / 2; xScale: stage.k; yScale: stage.k },
            Translate { y: ((root.height / 2) - (root.cy + root.ch / 2)) * (1 - root.ez) }
        ]

        RectangularShadow {                  // ombre portée profonde, neutre
            x: root.cx; y: root.cy + 28; width: root.cw; height: root.ch
            radius: card.radius; blur: 90; spread: -10
            color: ColorUtils.applyAlpha("#000000", 0.6 * root.ez)
        }
        ClippingRectangle {
            id: card
            x: root.cx; y: root.cy; width: root.cw; height: root.ch
            radius: 18 * root.ez
            color: Appearance.colors.bg
            readonly property real k: width / ((root.mo.width || 3440) / (root.mo.scale || 1))

            Image { anchors.fill: parent; source: root.wallSrc; fillMode: Image.PreserveAspectCrop; asynchronous: true
                    sourceSize.width: 1920 }
            Rectangle { anchors.fill: parent; color: Appearance.colors.bg; opacity: 0.2 * root.ez }
            Column {
                anchors.centerIn: parent; visible: root.wins.length === 0; opacity: root.ui; spacing: 10
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Espace libre"
                       font.family: root.font; font.pixelSize: 30; font.weight: Font.Light; font.letterSpacing: 2; color: root.fg }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Maj + & é \" '…  pour y envoyer une fenêtre"
                       font.family: root.font; font.pixelSize: 15; color: Appearance.colors.dim }
            }

            Item {
                anchors.fill: parent
                opacity: 1 - Math.abs(root.slide) * 0.8
                transform: Translate { x: root.slide * 70 }
                Repeater {
                    model: root.wins
                    delegate: Item {
                        id: w
                        required property var modelData
                        readonly property var o: modelData.lastIpcObject ?? ({})
                        readonly property bool act: modelData.activated
                        x: ((o.at?.[0] ?? 0) - (root.mo.x || 0)) * card.k
                        y: ((o.at?.[1] ?? 0) - (root.mo.y || 0)) * card.k
                        width: Math.max(8, (o.size?.[0] ?? 0) * card.k); height: Math.max(8, (o.size?.[1] ?? 0) * card.k)
                        z: act ? 2 : (o.floating ? 1 : 0)
                        Behavior on x { NumberAnimation { duration: Appearance.dur(260); easing.type: Easing.OutQuart } }
                        Behavior on y { NumberAnimation { duration: Appearance.dur(260); easing.type: Easing.OutQuart } }
                        Behavior on width { NumberAnimation { duration: Appearance.dur(260); easing.type: Easing.OutQuart } }
                        Behavior on height { NumberAnimation { duration: Appearance.dur(260); easing.type: Easing.OutQuart } }

                        RectangularShadow {
                            anchors.fill: parent; radius: 10; blur: 28; spread: 0
                            color: ColorUtils.applyAlpha(w.act ? root.accent : "#000000", (w.act ? 0.35 : 0.25) * root.ez)
                            Behavior on color { ColorAnimation { duration: Appearance.dur(260) } }
                        }
                        ClippingRectangle {
                            anchors.fill: parent
                            radius: 10 * root.ez
                            color: Appearance.colors.color0
                            ScreencopyView { id: shot; anchors.fill: parent; captureSource: w.modelData.wayland; live: true }
                            Image {
                                anchors.centerIn: parent; visible: !shot.hasContent
                                width: Math.min(parent.width, parent.height) * 0.35; height: width; sourceSize: Qt.size(128, 128)
                                source: root.iconOf(w.o.class)
                            }
                            // les autres fenêtres s'effacent
                            Rectangle { anchors.fill: parent; color: Appearance.colors.bg; opacity: w.act ? 0 : 0.5 * root.ez
                                        Behavior on opacity { NumberAnimation { duration: Appearance.dur(260) } } }
                            // nom de l'appli sur un fondu en bas
                            Item {
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                height: 56; visible: w.width > 160 && w.height > 90; opacity: root.ui
                                Rectangle { anchors.fill: parent
                                            gradient: Gradient {
                                                GradientStop { position: 0; color: "transparent" }
                                                GradientStop { position: 1; color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.85) } } }
                                Row {
                                    anchors { left: parent.left; leftMargin: 14; bottom: parent.bottom; bottomMargin: 12 }
                                    spacing: 9
                                    Image { width: 18; height: 18; sourceSize: Qt.size(36, 36); source: root.iconOf(w.o.class)
                                            anchors.verticalCenter: parent.verticalCenter }
                                    Text { anchors.verticalCenter: parent.verticalCenter
                                           text: root.appName(w.o.class).toUpperCase() + (w.o.floating ? "   ·   FLOTTANTE" : "")
                                           font.family: root.font; font.pixelSize: 12; font.letterSpacing: 2.5; font.weight: Font.Medium
                                           color: w.act ? root.fg : Appearance.colors.dim }
                                }
                            }
                        }
                        // filet : accent pour l'active, à peine visible pour les autres
                        Rectangle { anchors.fill: parent; anchors.margins: -1; radius: 11 * root.ez; color: "transparent"
                                    opacity: root.ez
                                    border.width: w.act ? 2 : 1
                                    border.color: w.act ? root.accent : ColorUtils.applyAlpha(root.fg, 0.10) }
                    }
                }
            }
        }
        // filet autour de la carte
        Rectangle { x: root.cx - 1; y: root.cy - 1; width: root.cw + 2; height: root.ch + 2; radius: card.radius + 1
                    color: "transparent"; border.width: 1; border.color: ColorUtils.applyAlpha(root.fg, 0.14); opacity: root.ez }
    }

    // ── au-dessus : grand numéro d'espace à gauche, index des espaces à droite ──
    Item {
        x: root.cx; width: root.cw; height: 110
        y: root.cy - height - 26 + (1 - root.ui) * 16
        opacity: root.ui

        Column {
            anchors { left: parent.left; bottom: parent.bottom }
            spacing: 0
            Text { text: "MODE FENÊTRES"; font.family: root.font; font.pixelSize: 12; font.letterSpacing: 6
                   color: root.accent }
            Row {
                spacing: 14
                Text {
                    id: big
                    text: String(root.wsId).padStart(2, "0")
                    font.family: root.font; font.pixelSize: 84; font.weight: Font.Thin; color: root.fg
                    Connections { target: root; function onWsIdChanged() { bigIn.restart() } }
                    ParallelAnimation { id: bigIn
                        NumberAnimation { target: big; property: "opacity"; from: 0; to: 1; duration: Appearance.dur(360) }
                        NumberAnimation { target: bigT; property: "y"; from: 18; to: 0; duration: Appearance.dur(420); easing.type: Easing.OutQuart } }
                    transform: Translate { id: bigT }
                }
                Column {
                    anchors.bottom: big.bottom; anchors.bottomMargin: 16
                    spacing: 2
                    Text { text: "ESPACE"; font.family: root.font; font.pixelSize: 12; font.letterSpacing: 4; color: Appearance.colors.dim }
                    Text { text: root.wins.length === 0 ? "vide" : root.wins.length + (root.wins.length > 1 ? " fenêtres" : " fenêtre")
                           font.family: root.font; font.pixelSize: 14; color: root.fg }
                }
            }
        }

        // index 1…10 : chiffre, point si occupé, filet d'accent qui glisse sous l'espace courant
        Item {
            id: idx
            anchors { right: parent.right; bottom: parent.bottom; bottomMargin: 18 }
            readonly property real step: 46
            width: step * 10; height: 44
            Repeater {
                model: 10
                delegate: Item {
                    id: ws
                    required property int index
                    readonly property int wid: index + 1
                    readonly property bool cur: wid === root.wsId
                    readonly property int n: Hyprland.workspaces.values.find(w => w.id === wid)?.lastIpcObject?.windows ?? 0
                    x: index * idx.step; width: idx.step; height: idx.height
                    Text { anchors.horizontalCenter: parent.horizontalCenter; y: 4
                           text: ws.wid; font.family: root.font; font.pixelSize: 18
                           font.weight: ws.cur ? Font.DemiBold : Font.Light
                           color: ws.cur ? root.accent : ws.n > 0 ? root.fg : ColorUtils.applyAlpha(root.fg, 0.28)
                           Behavior on color { ColorAnimation { duration: Appearance.dur(240) } } }
                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 32; width: 4; height: 4; radius: 2
                                visible: ws.n > 0 && !ws.cur; color: ColorUtils.applyAlpha(root.fg, 0.5) }
                }
            }
            Rectangle {
                y: 34; height: 2; radius: 1; width: 22
                x: (root.wsId - 1) * idx.step + (idx.step - width) / 2
                visible: root.wsId >= 1 && root.wsId <= 10
                color: root.accent
                Behavior on x { NumberAnimation { duration: Appearance.dur(380); easing.type: Easing.OutQuart } }
            }
        }
    }

    // ── dessous : la fenêtre active ──
    Row {
        x: root.cx; y: root.cy + root.ch + 26 - (1 - root.ui) * 12
        opacity: root.ui * (root.actHere ? 1 : 0)
        Behavior on opacity { NumberAnimation { duration: Appearance.dur(200) } }
        spacing: 14
        Rectangle { width: 2; height: 38; radius: 1; color: root.accent; anchors.verticalCenter: parent.verticalCenter }
        Column {
            spacing: 3
            Text { text: root.actHere ? root.appName(root.act.lastIpcObject?.class).toUpperCase() : ""
                   font.family: root.font; font.pixelSize: 11; font.letterSpacing: 3; color: Appearance.colors.dim }
            Text { text: root.actHere ? root.act.title : ""; width: Math.min(implicitWidth, root.cw * 0.55); elide: Text.ElideRight
                   font.family: root.font; font.pixelSize: 17; color: root.fg }
        }
    }

    // ── pied d'écran : aide-mémoire sur une ligne, la touche utilisée s'allume ──
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - 74 + (1 - root.ui) * 12
        opacity: root.ui
        spacing: 26
        Repeater {
            model: [["TAB", "fenêtre"], ["& É \" '", "espace"], ["⇧ & É \" '", "envoyer"], ["Z Q S D", "taille"],
                    ["⇧ Z Q S D", "déplacer"], ["X", "fermer"], ["F", "flottante"], ["␣", "plein écran"], ["ÉCHAP", "quitter"]]
            delegate: Row {
                id: hint
                required property var modelData
                readonly property bool on: root.lit === modelData[1]
                spacing: 9
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: kt.implicitWidth + 16; height: 24; radius: 6
                    color: hint.on ? ColorUtils.applyAlpha(root.accent, 0.18) : "transparent"
                    border.width: 1; border.color: hint.on ? root.accent : ColorUtils.applyAlpha(root.fg, 0.22)
                    Behavior on color { ColorAnimation { duration: Appearance.dur(220) } }
                    Behavior on border.color { ColorAnimation { duration: Appearance.dur(220) } }
                    Text { id: kt; anchors.centerIn: parent; text: hint.modelData[0]
                           font.family: root.font; font.pixelSize: 11; font.letterSpacing: 1.5; font.weight: Font.Medium
                           color: hint.on ? root.accent : root.fg
                           Behavior on color { ColorAnimation { duration: Appearance.dur(220) } } }
                }
                Text { anchors.verticalCenter: parent.verticalCenter; text: hint.modelData[1]
                       font.family: root.font; font.pixelSize: 12
                       color: hint.on ? root.fg : Appearance.colors.dim
                       Behavior on color { ColorAnimation { duration: Appearance.dur(220) } } }
            }
        }
    }
}
