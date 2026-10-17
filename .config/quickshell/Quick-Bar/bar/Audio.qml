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
    rowSpacing: 7; columnSpacing: 7

    property int  volume:    0
    property bool muted:     false
    property int  micVolume: 0
    property bool micMuted:  false

    // ── Speaker query ─────────────────────────────────────────────────────
    Process {
        id: spkQuery
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = text.trim().match(/Volume:\s*([\d.]+)(\s+\[MUTED\])?/)
                if (m) {
                    root.volume = Math.round(parseFloat(m[1]) * 100)
                    root.muted  = !!m[2]
                }
            }
        }
    }

    // ── Mic query ─────────────────────────────────────────────────────────
    Process {
        id: micQuery
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var m = text.trim().match(/Volume:\s*([\d.]+)(\s+\[MUTED\])?/)
                if (m) {
                    root.micVolume = Math.round(parseFloat(m[1]) * 100)
                    root.micMuted  = !!m[2]
                }
            }
        }
    }

    Timer {
        interval: Config.ms("audio", 2); running: true; repeat: true; triggeredOnStart: true
        onTriggered: { spkQuery.running = true; micQuery.running = true }
    }

    Process { id: toggleMute;    command: ["wpctl", "set-mute",   "@DEFAULT_AUDIO_SINK@",   "toggle"] }
    Process { id: volUp;         command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@",   "5%+"]    }
    Process { id: volDown;       command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@",   "5%-"]    }
    Process { id: toggleMicMute; command: ["wpctl", "set-mute",   "@DEFAULT_AUDIO_SOURCE@", "toggle"] }
    Process { id: pavu;          command: ["pavucontrol", "-t", "3"] }

    // ── Speaker icon ─────────────────────────────────────────────────────
    Text {
        Layout.alignment: Qt.AlignCenter
        text: root.muted        ? "󰖁"
            : root.volume > 70  ? "󰕾"
            : root.volume > 30  ? ""
            :                     ""
        font.family: Appearance.font.family
        font.pixelSize: Appearance.bar.icon
        color: root.muted ? Appearance.color.color13 : Appearance.color.accent

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (ev) => {
                if (ev.button === Qt.LeftButton) {
                    toggleMute.running = true
                    Qt.callLater(() => spkQuery.running = true)
                } else {
                    pavu.running = true
                }
            }
            onWheel: (ev) => {
                if (ev.angleDelta.y > 0) volUp.running = true
                else volDown.running = true
                Qt.callLater(() => spkQuery.running = true)
            }
        }
    }

    // ── Speaker volume ────────────────────────────────────────────────────
    Text {
        Layout.alignment: Qt.AlignCenter
        text: root.muted ? "" : root.volume + "%"
        font.pixelSize: Appearance.bar.text
        color: root.muted ? Appearance.color.color10 : Appearance.color.accent
        Layout.maximumWidth: root.muted ? 0 : 60
        clip: true
        Behavior on Layout.maximumWidth { NumberAnimation { duration: Appearance.dur(150); easing.type: Easing.OutCubic } }
    }
    

    // ── Mic icon ─────────────────────────────────────────────────────────
    Text {
        Layout.alignment: Qt.AlignCenter
        text: root.micMuted ? " 󰍭" : " 󰍬"
        font.family: Appearance.font.family
        font.pixelSize: Appearance.bar.icon
        color: root.micMuted ? Appearance.color.color10 : Appearance.color.accent

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (ev) => {
                if (ev.button === Qt.LeftButton) {
                    toggleMicMute.running = true
                    Qt.callLater(() => micQuery.running = true)
                } else {
                    pavu.running = true
                }
            }
        }
    }

    // ── Mic volume ────────────────────────────────────────────────────────
    Text {
        Layout.alignment: Qt.AlignCenter
        text: root.micMuted ? "" : root.micVolume + "%"
        font.pixelSize: Appearance.bar.text
        color: root.micMuted ? Appearance.color.color13 : Appearance.color.accent
        Layout.maximumWidth: root.micMuted ? 0 : 60
        clip: true
        Behavior on Layout.maximumWidth { NumberAnimation { duration: Appearance.dur(150); easing.type: Easing.OutCubic } }
    }
}
