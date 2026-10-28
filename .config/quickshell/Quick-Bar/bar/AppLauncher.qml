pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.core

Text {
    id: root
    text: "  "
    font.family: Appearance.font.family
    font.pixelSize: Appearance.bar.icon + 2
    color: Appearance.colors.color15

    // même lanceur que Super seul (menus/scripts/apps.sh, IPC menu run apps) ; recliquer le referme
    function toggle() { Quickshell.execDetached(["qs", "-p", Quickshell.shellDir + "/shell.qml", "ipc", "call", "menu", "run", "apps"]) }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onEntered: root.color = Appearance.colors.color5
        onExited:  root.color = Appearance.colors.color15
        onClicked: root.toggle()
    }
}
