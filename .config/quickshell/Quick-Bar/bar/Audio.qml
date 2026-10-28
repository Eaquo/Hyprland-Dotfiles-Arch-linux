pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.core
import qs.services

// Rangée en barre horizontale, colonne en barre verticale ([bar] position)
GridLayout {
    flow: Appearance.bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    id: root
    rowSpacing: 7; columnSpacing: 7

    // Pipewire natif (services/Mixer.qml) : mis à jour par événements, aucun sondage ni wpctl
    readonly property var  sink:      Mixer.sink?.audio ?? null
    readonly property var  source:    Mixer.source?.audio ?? null
    readonly property int  volume:    sink ? Math.round(sink.volume * 100) : 0
    readonly property bool muted:     sink ? sink.muted : false
    readonly property int  micVolume: source ? Math.round(source.volume * 100) : 0
    readonly property bool micMuted:  source ? source.muted : false

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
                    Mixer.toggleMute([Mixer.sink])
                } else {
                    pavu.running = true
                }
            }
            onWheel: (ev) => {
                if (root.sink) Mixer.setVolume([Mixer.sink], root.sink.volume + (ev.angleDelta.y > 0 ? 0.05 : -0.05))
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
                    Mixer.toggleMute([Mixer.source])
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
