pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../Common/"

RowLayout {
    id: root
    spacing: 3

    property int  count: 0
    property bool dnd:   false

    Process {
        id: swayncQuery
        command: ["bash", "-c",
            "swaync-client -swb 2>/dev/null || echo '{\"text\":\"0\",\"class\":\"none\"}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text.trim())
                    root.count = parseInt(d.text) || 0
                    root.dnd   = (d.class || "").indexOf("dnd") >= 0
                } catch(e) {
                    root.count = 0
                }
            }
        }
    }

    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: swayncQuery.running = true
    }

    Process { id: toggleNotif; command: ["swaync-client", "-t", "-sw"] }

    Text {
        text: root.dnd       ? " 󰂛 "
            : root.count > 0 ? " 󰂚 "
            :                  " 󰂜 "
        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.body
        color: root.count > 0 ? Appearance.colors.color10
             : root.dnd       ? Appearance.colors.color11
             :                  Appearance.colors.color12

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleNotif.running = true
        }
    }

    Text {
        visible: root.count > 0
        text: root.count.toString()
        font.pixelSize: Appearance.font.small
        color: Appearance.colors.color10
    }
}
