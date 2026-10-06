import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../Common/"
import "../Common/functions/"

// GameBreakBar — pastille flottante affichée sur le Xeneon pendant une pause jeu.
//
// Elle n'existe que le temps de la pause (GameBreak.active) et donne les deux
// seules actions utiles au doigt : prolonger, ou revenir au jeu tout de suite.
// Layer Overlay et déclarée APRÈS TouchPanel dans shell.qml → elle passe
// au-dessus du panneau tactile quand celui-ci est ouvert.
Scope {
    id: root

    // ── IPC : point d'entrée du raccourci Hyprland ────────────────────────────
    //   qs -p ~/.config/quickshell/Quick-Bar/shell.qml ipc call gamebreak toggle
    IpcHandler {
        target: "gamebreak"
        function toggle() { GameBreak.toggle() }
        function start()  { GameBreak.start()  }
        function stop()   { GameBreak.stop()   }
        function extend() { GameBreak.extend() }
    }

    readonly property var targetScreen: {
        var all = Quickshell.screens
        for (var i = 0; i < all.length; i++)
            if (all[i].name === GameBreak.touchMonitor) return all[i]
        return null
    }

    PanelWindow {
        id: win
        screen:  root.targetScreen
        visible: GameBreak.active && root.targetScreen !== null
        color:   "transparent"

        WlrLayershell.layer:         WlrLayer.Overlay
        WlrLayershell.namespace:     "quickshell:gamebreak"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors { bottom: true }
        margins { bottom: 24 }
        implicitWidth:  pill.implicitWidth
        implicitHeight: pill.implicitHeight

        Rectangle {
            id: pill
            implicitWidth:  content.implicitWidth + 44
            implicitHeight: 92
            radius: 26
            color:  ColorUtils.applyAlpha(Appearance.colors.bg, 0.92)
            border.width: 2
            border.color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.55)

            // Jauge du temps restant : se vide de droite à gauche sous la pastille.
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                anchors.margins: 6
                height: 5
                radius: 3
                color:  ColorUtils.applyAlpha(Appearance.colors.dim, 0.4)
                visible: GameBreak.autoReturn
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width:  parent.width * GameBreak.progress
                    radius: 3
                    color:  Appearance.colors.accent
                    Behavior on width { NumberAnimation { duration: 100 } }
                }
            }

            RowLayout {
                id: content
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -3
                spacing: 18

                Text {
                    text: "󰊴"
                    font.family:    Appearance.font.family
                    font.pixelSize: 32
                    color: Appearance.colors.accent
                }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Pause jeu — tactile actif"
                        font.family: Appearance.font.family
                        font.pixelSize: 18
                        font.bold: true
                        color: Appearance.colors.fg
                    }
                    Text {
                        // Fenêtre à laquelle on rendra le focus.
                        text: GameBreak.heldTitle !== "" ? GameBreak.heldTitle : "fenêtre mémorisée"
                        font.family: Appearance.font.family
                        font.pixelSize: 14
                        color: Appearance.colors.dim
                        elide: Text.ElideRight
                        Layout.maximumWidth: 320
                    }
                }

                // ── Compte à rebours ──────────────────────────────────────────
                // Sur sa propre pastille : dans le sous-titre il se faisait élider
                // par les titres de fenêtre à rallonge.
                Rectangle {
                    Layout.preferredWidth:  62
                    Layout.preferredHeight: 62
                    radius: 31
                    color: "transparent"
                    border.width: 2
                    border.color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.6)
                    visible: GameBreak.autoReturn
                    Text {
                        anchors.centerIn: parent
                        text: Math.ceil(GameBreak.remainingMs / 1000) + "s"
                        font.family: Appearance.font.family
                        font.pixelSize: 20
                        font.bold: true
                        color: Appearance.colors.accent
                    }
                }

                // ── Prolonger ─────────────────────────────────────────────────
                Rectangle {
                    Layout.preferredWidth:  96
                    Layout.preferredHeight: 56
                    radius: 18
                    color: extendMa.pressed
                        ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.45)
                        : ColorUtils.applyAlpha(Appearance.colors.accent, 0.18)
                    border.width: 1
                    border.color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.5)
                    visible: GameBreak.autoReturn
                    Text {
                        anchors.centerIn: parent
                        text: "+ " + Math.round(GameBreak.autoReturnMs / 1000) + " s"
                        font.family: Appearance.font.family
                        font.pixelSize: 17
                        font.bold: true
                        color: Appearance.colors.fg
                    }
                    MouseArea {
                        id: extendMa
                        anchors.fill: parent
                        onClicked: GameBreak.extend()
                    }
                }

                // ── Revenir au jeu ────────────────────────────────────────────
                Rectangle {
                    Layout.preferredWidth:  186
                    Layout.preferredHeight: 56
                    radius: 18
                    color: backMa.pressed
                        ? Qt.darker(Appearance.colors.accent, 1.2)
                        : Appearance.colors.accent
                    Text {
                        anchors.centerIn: parent
                        text: "Revenir au jeu"
                        font.family: Appearance.font.family
                        font.pixelSize: 17
                        font.bold: true
                        color: Appearance.colors.bg
                    }
                    MouseArea {
                        id: backMa
                        anchors.fill: parent
                        onClicked: GameBreak.stop()
                    }
                }
            }
        }
    }
}
