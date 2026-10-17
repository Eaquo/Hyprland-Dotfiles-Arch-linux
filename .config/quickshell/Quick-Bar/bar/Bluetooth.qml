pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.core
import qs.core.functions

// Rangée en barre horizontale, colonne en barre verticale ([bar] position)
GridLayout {
    flow: Appearance.bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    id: root
    rowSpacing: 3; columnSpacing: 3

    property bool powered: false
    property int  conns:   0

    Process {
        id: btQuery
        command: ["bash", "-c",
            "bluetoothctl show 2>/dev/null | grep -c 'Powered: yes'; bluetoothctl devices Connected 2>/dev/null | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n")
                root.powered = parseInt(lines[0] || "0") > 0
                root.conns   = parseInt(lines[1] || "0")
            }
        }
    }

    Timer {
        interval: Config.ms("bluetooth", 5); running: true; repeat: true; triggeredOnStart: true
        onTriggered: btQuery.running = true
    }

    Process { id: blueman; command: ["blueman-manager"] }

    Text {
        Layout.alignment: Qt.AlignCenter
        text: !root.powered  ? "  "
            : root.conns > 0 ? " 󰂱 "
            :                   "  "
        font.family: Appearance.font.family
        font.pixelSize: Appearance.bar.icon
        color: root.conns > 0   ? Appearance.colors.color10
             : root.powered     ? Appearance.colors.color10
             :                    ColorUtils.applyAlpha(Appearance.colors.color5, 0.4)

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: blueman.running = true
        }
    }

    Text {
        Layout.alignment: Qt.AlignCenter
        visible: root.conns > 0
        text: root.conns.toString()
        font.pixelSize: Appearance.bar.small
        color: Appearance.colors.color10
    }
}
