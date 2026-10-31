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

    // molette sur le volume ou le micro (icône ou %) : ±5 % ; clic gauche / clic molette : couper ;
    // clic droit : centre audio flottant (panels/EqCenter.qml)
    function step(node, ev) { if (node?.audio) Mixer.setVolume([node], node.audio.volume + (ev.angleDelta.y > 0 ? 0.05 : -0.05)) }
    function openCenter() { const o = !Popups.eqCenterOpen; Popups.closeAll(); Popups.eqCenterOpen = o }

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
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: (ev) => {
                if (ev.button === Qt.RightButton) root.openCenter()
                else Mixer.toggleMute([Mixer.sink])          // clic gauche ou molette : couper / rétablir
            }
            onWheel: (ev) => {
                root.step(Mixer.sink, ev)
            }
        }
    }

    // ── Speaker volume ────────────────────────────────────────────────────
    Text {
        Layout.alignment: Qt.AlignCenter
        text: root.muted ? "" : root.volume + "%"
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton; cursorShape: Qt.PointingHandCursor
                    onClicked: (ev) => ev.button === Qt.RightButton ? root.openCenter() : Mixer.toggleMute([Mixer.sink])
                    onWheel: (ev) => root.step(Mixer.sink, ev) }
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
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: (ev) => {
                if (ev.button === Qt.RightButton) root.openCenter()
                else Mixer.toggleMute([Mixer.source])        // clic gauche ou molette : couper / rétablir
            }
            onWheel: (ev) => root.step(Mixer.source, ev)
        }
    }

    // ── Mic volume ────────────────────────────────────────────────────────
    Text {
        Layout.alignment: Qt.AlignCenter
        text: root.micMuted ? "" : root.micVolume + "%"
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton; cursorShape: Qt.PointingHandCursor
                    onClicked: (ev) => ev.button === Qt.RightButton ? root.openCenter() : Mixer.toggleMute([Mixer.source])
                    onWheel: (ev) => root.step(Mixer.source, ev) }
        font.pixelSize: Appearance.bar.text
        color: root.micMuted ? Appearance.color.color13 : Appearance.color.accent
        Layout.maximumWidth: root.micMuted ? 0 : 60
        clip: true
        Behavior on Layout.maximumWidth { NumberAnimation { duration: Appearance.dur(150); easing.type: Easing.OutCubic } }
    }
}
