pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.core
import qs.core.functions

Scope {
    Variants {
        model: {
            var all = Quickshell.screens
            if (!ShellState.barMainOnly) return all
            // Écran principal = le plus grand (l'ultrawide, pas le tactile)
            var main = null, best = -1
            for (var i = 0; i < all.length; i++) {
                var a = all[i].width * all[i].height
                if (a > best) { best = a; main = all[i] }
            }
            return main ? [main] : all
        }

        PanelWindow {
            id: root
            required property var modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell:bar"
            WlrLayershell.layer: WlrLayer.Top

            // [bar] position : haut, bas, gauche ou droite de l'écran
            readonly property string pos: Appearance.bar.position
            readonly property bool   vert: Appearance.bar.vertical
            anchors { top: pos !== "bottom"; bottom: pos !== "top"; left: pos !== "right"; right: pos !== "left" }
            margins {
                top:    pos === "top" ? Appearance.bar.topMargin : vert ? Appearance.bar.sideMargin : 0
                bottom: pos === "bottom" ? Appearance.bar.topMargin : vert ? Appearance.bar.sideMargin : 0
                left:   pos === "left" ? Appearance.bar.topMargin : vert ? 0 : Appearance.bar.sideMargin
                right:  pos === "right" ? Appearance.bar.topMargin : vert ? 0 : Appearance.bar.sideMargin
            }

            // Hyprland ne déplace pas une barre déjà affichée quand ses marges ou sa taille changent :
            // on la recrée (masquer / réafficher) dès que la géométrie bouge dans les réglages.
            readonly property string geom: [pos, Appearance.bar.topMargin, Appearance.bar.sideMargin, Appearance.bar.height, Appearance.bar.thickness].join()
            onGeomChanged: remap.restart()
            Timer { id: remap; interval: 250; onTriggered: { root.visible = false; Qt.callLater(() => root.visible = true) } }

            implicitHeight: vert ? 0 : Appearance.bar.height
            implicitWidth:  vert ? Appearance.bar.thickness : 0
            exclusiveZone:  Appearance.bar.thickness + Appearance.bar.topMargin

            Item {
                anchors.fill: parent

                // [bar] style : pills = 3 barres · split = 2 barres (gauche+centre | droite) · full = 1 barre
                readonly property string style: Appearance.bar.style
                Surface { anchors.fill: parent; visible: parent.style === "full" }
                // groupes : gauche / centre / droite, ou haut / milieu / bas en barre verticale
                Pill {
                    side: parent.style === "split" ? "leftcenter" : "left"; bare: parent.style === "full"
                    x: Appearance.bar.vertical ? (parent.width - width) / 2 : 0
                    y: Appearance.bar.vertical ? 0 : (parent.height - height) / 2
                }
                Pill { side: "center"; bare: parent.style === "full"; visible: parent.style !== "split" && keys.length > 0; anchors.centerIn: parent }
                Pill {
                    side: "right"; bare: parent.style === "full"
                    x: Appearance.bar.vertical ? (parent.width - width) / 2 : parent.width - width
                    y: Appearance.bar.vertical ? parent.height - height : (parent.height - height) / 2
                }
            }
        }
    }

    // Une pilule de la barre : les modules de [bar.layout].<side>, séparés par des traits.
    // Masquée si elle est vide.
    // Fond d'une barre : dégradé, contour, bordure animée
    component Surface: Rectangle {
        radius: Appearance.bar.radius
        border.color: Appearance.outline
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: Appearance.dur(600); easing.type: Easing.InOutQuad } }
        gradient: Gradient {
            GradientStop {
                position: 0.7
                color: Appearance.colors.bg
                Behavior on color { ColorAnimation { duration: Appearance.dur(600); easing.type: Easing.InOutQuad } }
            }
            GradientStop {
                position: 1.0
                color: ColorUtils.applyAlpha(Appearance.colors.color0, 0.80)
                Behavior on color { ColorAnimation { duration: Appearance.dur(600); easing.type: Easing.InOutQuad } }
            }
        }
        GradientBorder {
            anchors.fill: parent
            radius:       parent.radius
            borderWidth:  2
            visible:      Appearance.animationsEnabled
            z:            5
        }
    }

    // Groupe de modules ; bare = sans fond (dans la barre unique du style « full »)
    component Pill: Item {
        id: pill
        required property string side
        property bool bare: false
        readonly property var keys: side === "leftcenter" ? BarModules.layout("left").concat(BarModules.layout("center")) : BarModules.layout(side)
        visible: keys.length > 0
        readonly property bool vert: Appearance.bar.vertical
        height: vert ? row.implicitHeight + Appearance.bar.pillPad * 2 : Appearance.bar.height
        width:  vert ? Appearance.bar.thickness : row.implicitWidth + Appearance.bar.pillPad * 2
        Surface { anchors.fill: parent; visible: !pill.bare }
        // modules trop longs pour une barre verticale : tournés d'un quart de tour
        readonly property var rotated: ["cava", "media", "eq", "layout"]

        // Composants des modules, par clé de BarModules
        readonly property var mods: ({
            launcher: launcherC, stats: statsC, notifications: notifC, cava: cavaC, clock: clockC,
            workspaces: wsC, layout: layoutC, localsend: lsC, updates: updC, proxmox: pveC, minimized: minC, media: mediaC, eq: eqC,
            tray: trayC, network: netC, bluetooth: btC, audio: audioC, power: powerC
        })
        Component { id: launcherC; AppLauncher {} }
        Component { id: statsC; SysStats {} }
        Component { id: notifC; Notifications {} }
        Component { id: cavaC; Cava {} }
        Component { id: clockC; Clock {} }
        Component { id: wsC; Workspaces {} }
        Component { id: layoutC; LayoutDisplayer {} }
        Component { id: lsC; LocalSend {} }
        Component { id: updC; Updates {} }
        Component { id: pveC; Proxmox {} }
        Component { id: minC; Minimized {} }
        Component { id: mediaC; MediaPlayer {} }
        Component { id: eqC; Eq {} }
        Component { id: trayC; SysTray {} }
        Component { id: netC; Network {} }
        Component { id: btC; Bluetooth {} }
        Component { id: audioC; Audio {} }
        Component { id: powerC; PowerButtons {} }

        GridLayout {
            id: row
            anchors.centerIn: parent
            flow: pill.vert ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rowSpacing: Appearance.bar.gap; columnSpacing: Appearance.bar.gap
            Repeater {
                model: pill.keys
                delegate: GridLayout {
                    id: slot
                    required property string modelData
                    required property int index
                    readonly property bool rot: pill.vert && pill.rotated.indexOf(modelData) >= 0
                    flow: pill.vert ? GridLayout.TopToBottom : GridLayout.LeftToRight
                    rowSpacing: Appearance.bar.gap; columnSpacing: Appearance.bar.gap
                    Layout.alignment: Qt.AlignCenter
                    // un module vide (lecteur sans musique…) ne laisse pas de trait orphelin
                    visible: ld.implicitWidth > 0
                    BarSeparator { visible: slot.index > 0 && BarModules.separators; Layout.alignment: Qt.AlignCenter }
                    Item {
                        Layout.alignment: Qt.AlignCenter
                        implicitWidth:  slot.rot ? ld.implicitHeight : ld.implicitWidth
                        implicitHeight: slot.rot ? ld.implicitWidth : ld.implicitHeight
                        Loader { id: ld; anchors.centerIn: parent; rotation: slot.rot ? 90 : 0; sourceComponent: pill.mods[slot.modelData] }
                    }
                }
            }
        }
    }
}
