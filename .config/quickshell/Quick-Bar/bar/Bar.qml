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

            anchors { top: true; left: true; right: true }
            margins {
                top:   Appearance.bar.topMargin
                left:  Appearance.bar.sideMargin
                right: Appearance.bar.sideMargin
            }

            implicitHeight: Appearance.bar.height
            exclusiveZone:  Appearance.bar.height + Appearance.bar.topMargin

            Item {
                anchors.fill: parent

                Pill { side: "left"; anchors { left: parent.left; verticalCenter: parent.verticalCenter } }
                Pill { side: "center"; anchors.centerIn: parent }
                Pill { side: "right"; anchors { right: parent.right; verticalCenter: parent.verticalCenter } }
            }
        }
    }

    // Une pilule de la barre : les modules de [bar.layout].<side>, séparés par des traits.
    // Masquée si elle est vide.
    component Pill: Rectangle {
        id: pill
        required property string side
        readonly property var keys: BarModules.layout(side)
        visible: keys.length > 0
        height: Appearance.bar.height
        width:  row.implicitWidth + Appearance.bar.pillPad * 2
        radius: Appearance.bar.radius
        border.color: Appearance.outline
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: Appearance.dur(600); easing.type: Easing.InOutQuad } }

        // Composants des modules, par clé de BarModules
        readonly property var mods: ({
            launcher: launcherC, stats: statsC, notifications: notifC, cava: cavaC, clock: clockC,
            workspaces: wsC, layout: layoutC, localsend: lsC, updates: updC, media: mediaC, eq: eqC,
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
        Component { id: mediaC; MediaPlayer {} }
        Component { id: eqC; Eq {} }
        Component { id: trayC; SysTray {} }
        Component { id: netC; Network {} }
        Component { id: btC; Bluetooth {} }
        Component { id: audioC; Audio {} }
        Component { id: powerC; PowerButtons {} }

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

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Appearance.bar.gap
            Repeater {
                model: pill.keys
                delegate: RowLayout {
                    id: slot
                    required property string modelData
                    required property int index
                    spacing: Appearance.bar.gap
                    // un module vide (lecteur sans musique…) ne laisse pas de trait orphelin
                    visible: ld.implicitWidth > 0
                    BarSeparator { visible: slot.index > 0 && BarModules.separators }
                    Loader { id: ld; sourceComponent: pill.mods[slot.modelData] }
                }
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
}
