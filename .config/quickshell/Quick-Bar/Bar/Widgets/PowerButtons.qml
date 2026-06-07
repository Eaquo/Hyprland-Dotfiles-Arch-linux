pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../Common/"

RowLayout {
    id: root
    spacing: 5

    Process { id: lockProc;   command: ["hyprlock"] }
    Process { id: logoutProc; command: ["wlogout"]  }

    // ── Power ─────────────────────────────────────────────────────────────
    Text {
        id: powerBtn
        text: " ⏻ "
        font.pixelSize: Appearance.font.body
        color: Appearance.colors.dim

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: powerBtn.color = Appearance.colors.red
            onExited:  powerBtn.color = Appearance.colors.dim
            onClicked: logoutProc.running = true
        }
    }
    
    // ── Lock ─────────────────────────────────────────────────────────────
    Text {
        id: lockBtn
        text: " 󰌾 "
        font.pixelSize: Appearance.font.body
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
