pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../Common/"
import "../Common/functions/"

RowLayout {
    id: root
    spacing: 3

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
        interval: 5000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: btQuery.running = true
    }

    Process { id: blueman; command: ["blueman-manager"] }

    Text {
        text: !root.powered  ? "  "
            : root.conns > 0 ? " 󰂱 "
            :                   "  "
        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.body
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
        visible: root.conns > 0
        text: root.conns.toString()
        font.pixelSize: Appearance.font.small
        color: Appearance.colors.color10
    }
}
