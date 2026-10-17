import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.core
import qs.core.functions

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

        // Emplacement sur l'écran tactile : [game] break_corner (haut-gauche par défaut)
        readonly property string corner: String(Config.get("game.break_corner", "top-left"))
        anchors {
            top:    corner.startsWith("top")
            bottom: corner.startsWith("bottom")
            left:   corner.endsWith("left")
            right:  corner.endsWith("right")
        }
        margins { top: 24; bottom: 24; left: 24; right: 24 }
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
                // rentrée de la valeur de l'arrondi : la jauge reste dans la partie droite de la pastille
                anchors.leftMargin:   parent.radius
                anchors.rightMargin:  parent.radius
                anchors.bottomMargin: 8
                height: 5
                radius: 3
                color:  ColorUtils.applyAlpha(Appearance.colors.dim, 0.4)
                visible: GameBreak.autoReturn
                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width:  parent.width * GameBreak.progress
                    radius: 3
                    color:  Appearance.colors.accent
                    Behavior on width { NumberAnimation { duration: Appearance.dur(100) } }
                }
            }

            RowLayout {
                id: content
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -3
                spacing: 18

                Text {
                    text: ""
                    font.family:    Appearance.font.family
                    font.pixelSize: 32
                    color: Appearance.colors.fg
                }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Pause"
                        font.family: Appearance.font.family
                        font.pixelSize: 18
                        font.bold: true
                        color: Appearance.colors.fg
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
                        text: "Retour"
                        font.family: Appearance.font.family
                        font.pixelSize: 17
                        font.bold: true
                        color: Appearance.colors.fg
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
