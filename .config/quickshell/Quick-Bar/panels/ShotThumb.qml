import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.core
import qs.core.functions
import qs.services

// ShotThumb — vignette de la dernière capture (services/Shots.qml), en bas à droite de l'écran principal :
// glisse depuis la droite, reste 7 s (le survol la garde), actions Copier · Annoter (satty, sinon swappy) · Ouvrir ·
// Dossier · Supprimer. Toucher la miniature l'ouvre.
PanelWindow {
    id: root
    screen: Quickshell.screens.find(s => !Config.isTouch(s)) || Quickshell.screens[0]
    color: "transparent"
    anchors { bottom: true; right: true }
    margins { bottom: 24; right: 24 }
    implicitWidth: 400; implicitHeight: 300
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:shot"
    mask: Region { item: card }

    property string file: ""
    property bool shown: false
    Connections {
        target: Shots
        function onLatestChanged() {
            if (Shots.latest !== "") { root.file = Shots.latest; root.shown = true } else root.shown = false
        }
    }
    Component.onCompleted: if (Shots.latest !== "") { file = Shots.latest; shown = true }

    function act(cmd) { Quickshell.execDetached(["sh", "-c", cmd, "_", root.file]); }

    Rectangle {                                  // fond plein (ClippingRectangle rendait le fond translucide)
        id: card
        width: parent.width; height: parent.height
        x: root.shown ? 0 : width + 40
        Behavior on x { NumberAnimation { duration: Appearance.dur(420); easing.type: Easing.OutCubic } }
        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Appearance.dur(300) } }
        radius: 20
        color: Appearance.colors.bg
        border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.5)
        HoverHandler { onHoveredChanged: Shots.hovered = hovered }

        ClippingRectangle {
            id: shot
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            height: parent.height - 12 - 64
            radius: 12
            color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.05)
            Image { anchors.fill: parent; fillMode: Image.PreserveAspectFit; asynchronous: true
                    source: root.file ? "file://" + root.file : ""; sourceSize: Qt.size(760, 460) }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { root.act('xdg-open "$1"'); Shots.close() } }
        }
        // temps restant (s'arrête au survol)
        Rectangle {
            anchors { left: parent.left; bottom: parent.bottom }
            height: 3; color: Appearance.colors.accent
            width: parent.width
            NumberAnimation on width { id: bar; running: root.shown && !Shots.hovered; from: card.width; to: 0; duration: Shots.holdMs }
        }
        Row {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 12 }
            spacing: 8
            Repeater {
                model: [
                    { g: "󰆏", t: "Copier",    c: 'wl-copy < "$1"', close: true },
                    { g: "󰏫", t: "Annoter",   c: 'command -v satty >/dev/null && exec satty --filename "$1" --output-filename "$1" --copy-command wl-copy || exec swappy -f "$1"', close: true },
                    { g: "󰈈", t: "Ouvrir",    c: 'xdg-open "$1"', close: true },
                    { g: "󰉋", t: "Dossier",   c: 'xdg-open "$(dirname "$1")"', close: true },
                    { g: "󰆴", t: "Supprimer", c: 'gio trash "$1"', close: true, danger: true }
                ]
                delegate: Rectangle {
                    id: b
                    required property var modelData
                    width: 66; height: 44; radius: 12
                    color: bMa.pressed ? ColorUtils.applyAlpha(b.modelData.danger ? Appearance.colors.color13 : Appearance.colors.accent, 0.4)
                                       : ColorUtils.applyAlpha(Appearance.colors.fg, bMa.containsMouse ? 0.12 : 0.05)
                    border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.2)
                    Text { anchors.centerIn: parent; text: b.modelData.g; font.family: Appearance.font.family; font.pixelSize: 20
                           color: b.modelData.danger ? Appearance.colors.color13 : Appearance.colors.accent }
                    MouseArea { id: bMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { root.act(b.modelData.c); if (b.modelData.close) Shots.close() } }
                }
            }
        }
    }
}
