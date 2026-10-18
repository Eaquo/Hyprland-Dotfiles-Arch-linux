pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../Common/"

RowLayout {
    id: root
    spacing: 3

    property string netType:  "none"   // "wifi" | "ethernet" | "none"
    property int    strength: 0        // wifi 0-100
    property string connName: ""

    // ── Query via nmcli ───────────────────────────────────────────────────
    Process {
        id: query
        command: ["bash", "-c",
            "nmcli -t -f TYPE,STATE,CONNECTION dev 2>/dev/null | grep ':connected:' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var line = text.trim()
                if (!line) { root.netType = "none"; root.connName = ""; return }
                var p = line.split(":")
                root.netType  = p[0] || "none"
                root.connName = p[2] || ""
                if (root.netType === "wifi") sigQuery.running = true
            }
        }
    }

    Process {
        id: sigQuery
        command: ["bash", "-c",
            "nmcli -t -f IN-USE,SIGNAL dev wifi 2>/dev/null | grep '^\\*' | cut -d: -f2 | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var s = parseInt(text.trim())
                root.strength = isNaN(s) ? 0 : s
            }
        }
    }

    Timer {
        interval: 8000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: query.running = true
    }

    Process { id: nmtui; command: ["kitty", "nmtui"] }

    // ── Icon ─────────────────────────────────────────────────────────────
    Text {
        text: {
            if (root.netType === "ethernet") return "󰌘"
            if (root.netType === "none")     return "󰌙"
            var s = root.strength
            if (s >= 80) return "󰤨"
            if (s >= 60) return "󰤥"
            if (s >= 40) return "󰤢"
            if (s >= 20) return "󰤟"
            return "󰤯"
        }
        font.pixelSize: Appearance.font.body
        color: root.netType === "none" ? Appearance.colors.red : Appearance.colors.blue

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.RightButton
            onClicked: nmtui.running = true
        }
    }
}
