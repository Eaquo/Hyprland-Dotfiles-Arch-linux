pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.core

// Rangée en barre horizontale, colonne en barre verticale ([bar] position)
GridLayout {
    flow: Appearance.bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    id: root
    rowSpacing: 3; columnSpacing: 3

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
        interval: Config.ms("notifications", 3); running: true; repeat: true; triggeredOnStart: true
        onTriggered: swayncQuery.running = true
    }

    Process { id: toggleNotif; command: ["swaync-client", "-t", "-sw"] }

    Text {
        Layout.alignment: Qt.AlignCenter
        text: root.dnd       ? " 󰂛 "
            : root.count > 0 ? " 󰂚 "
            :                  " 󰂜 "
        font.family: Appearance.font.family
        font.pixelSize: Appearance.bar.icon
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
        Layout.alignment: Qt.AlignCenter
        visible: root.count > 0
        text: root.count.toString()
        font.pixelSize: Appearance.bar.small
        color: Appearance.colors.color10
    }
}
