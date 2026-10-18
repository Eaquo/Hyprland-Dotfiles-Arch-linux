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
    rowSpacing: 5; columnSpacing: 5

    Process { id: lockProc;   command: ["hyprlock"] }
    // ⏻ ouvre le panneau de session de Quick-Bar (panels/SessionPanel.qml), plus wlogout

    // ── Power ─────────────────────────────────────────────────────────────
    Text {
        Layout.alignment: Qt.AlignCenter
        id: powerBtn
        text: " ⏻ "
        font.pixelSize: Appearance.bar.icon
        color: Appearance.colors.dim

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: powerBtn.color = Appearance.colors.red
            onExited:  powerBtn.color = Appearance.colors.dim
            onClicked: { Popups.closeAll(); Popups.sessionOpen = true }
        }
    }
    
    // ── Lock ─────────────────────────────────────────────────────────────
    Text {
        Layout.alignment: Qt.AlignCenter
        id: lockBtn
        text: " 󰌾 "
        font.pixelSize: Appearance.bar.icon
        color: Appearance.colors.dim

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: lockBtn.color = Appearance.colors.yellow
            onExited:  lockBtn.color = Appearance.colors.dim
            onClicked: lockProc.running = true
        }
    }
}
