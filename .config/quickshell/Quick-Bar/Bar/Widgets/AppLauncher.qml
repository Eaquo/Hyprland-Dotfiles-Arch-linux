pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../Common/"

Text {
    id: root
    text: "  "
    font.family: Appearance.font.family
    font.pixelSize: Appearance.font.body + 2
    color: Appearance.colors.color15

    Process { id: rofiProc; command: ["bash", "-c", "pkill rofi || rofi -show drun -modi run,drun,filebrowser,window"] }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: root.color = Appearance.colors.color5
        onExited:  root.color = Appearance.colors.color3
        onClicked: rofiProc.running = true
    }
}
