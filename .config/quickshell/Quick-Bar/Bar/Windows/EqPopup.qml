pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../Common/"
import "../Common/functions/"

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: eqWin
            required property var modelData
            screen: modelData

            visible: Appearance.eqVisible
            WlrLayershell.namespace: "quickshell:eq"
            WlrLayershell.layer:     WlrLayer.Overlay
            exclusiveZone: -1

            anchors { top: true; left: true; right: true; bottom: true }
            color: "transparent"

            readonly property real cardY: Appearance.bar.topMargin + Appearance.bar.height - 1

            // ── State ─────────────────────────────────────────────────
            property var    gains:         [0,0,0,0,0,0,0,0,0,0]
            property string currentPreset: ""
            readonly property var freqLabels: ["32","64","125","250","500","1k","2k","4k","8k","16k"]
            readonly property string scriptPath:
                Qt.resolvedUrl("../Scripts/eq_control.py").toString().replace("file://", "")

            function setGain(idx, val) {
                var arr = eqWin.gains.slice()
                arr[idx] = Math.round(val * 2) / 2
                eqWin.gains = arr
                applyTimer.restart()
            }

            function applyGains() {
                var args = ["python3", eqWin.scriptPath, "set_gains"]
                for (var i = 0; i < 10; i++) args.push(eqWin.gains[i].toFixed(1))
                setGainsProc.command = args
                setGainsProc.running = true
            }

            // ── Processes ─────────────────────────────────────────────
            Process {
                id: getProc
                command: ["python3", eqWin.scriptPath, "get"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            var d = JSON.parse(text.trim())
                            eqWin.gains         = d.gains
                            eqWin.currentPreset = d.preset
                        } catch(e) {}
                    }
                }
            }

            Process { id: setGainsProc }

            Process {
                id: loadPresetProc
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            var d = JSON.parse(text.trim())
                            if (d.gains)  eqWin.gains         = d.gains
                            if (d.preset) eqWin.currentPreset = d.preset
                        } catch(e) {}
                    }
                }
            }
            MouseArea {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                y: Appearance.bar.topMargin + Appearance.bar.height
                onClicked: Appearance.eqVisible = false
            }

            // Hotspot zone du widget MediaPlayer dans la barre → switch vers MP popup
            MouseArea {
                x: Appearance.mediaPopupX - eqWin.screen.x - Appearance.mediaPopupWidth / 2 - 6
                y: 0
                width:  Appearance.mediaPopupWidth + 12
                height: Appearance.bar.topMargin + Appearance.bar.height
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: {
                    closeTimer.stop()
                    Appearance.eqVisible = false
                    Appearance.mediaPopupOpen = true
                }
            }

            Timer {
                id: applyTimer
                interval: 250; repeat: false
                onTriggered: eqWin.applyGains()
            }

            Timer {
                id: closeTimer
                interval: 80; repeat: false
                onTriggered: Appearance.eqVisible = false
            }

            Connections {
                target: Appearance
                function onEqVisibleChanged() {
                    if (Appearance.eqVisible) getProc.running = true
                }
            }

            // ── Card ──────────────────────────────────────────────────
            Rectangle {
                id: eqCard

                x: Math.max(8, Math.min(Appearance.eqPopupX - width / 2, eqWin.width - width - 8))
                y: eqWin.cardY + 6

                width: cardCol.implicitWidth + 48
                height: cardCol.implicitHeight + 36

                radius: Appearance.bar.radius

                color: ColorUtils.applyAlpha(Appearance.colors.bg, Appearance.bar.bgAlpha)
                border.color: Appearance.colors.color15
                border.width: 1

                opacity: Appearance.eqVisible ? 1 : 0
                scale: Appearance.eqVisible ? 1 : 0.97
                transformOrigin: Item.TopRight

                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: closeTimer.stop()
                    onExited:  closeTimer.restart()
                }

                ColumnLayout {
                    id: cardCol
                    anchors {
                        left: parent.left; right: parent.right; top: parent.top
                        leftMargin: 16; rightMargin: 16; topMargin: 10
                    }
                    spacing: 18

                    // ── Header ────────────────────────────────────────
                    RowLayout {
                        spacing: 10
                        Layout.fillWidth: true

                        Rectangle {
                            width: 7; height: 7; radius: 3.5
                            color: Appearance.colors.accent
                        }
                        Text {
                            text: "Equalizer"
                            font.family:    Appearance.font.family
                            font.pixelSize: Appearance.font.body - 1
                            font.weight:    Font.Medium
                            color:          Appearance.colors.fg
                        }

                        Item { Layout.fillWidth: true }

                        // Preset pills
                        Repeater {
                            model: ["HP", "Bose", "Flat"]
                            Rectangle {
                                required property string modelData
                                property bool active: eqWin.currentPreset === modelData
                                implicitWidth:  pLbl.implicitWidth + 20
                                implicitHeight: 24
                                radius: 12
                                color: active
                                    ? Appearance.colors.accent
                                    : ColorUtils.applyAlpha(Appearance.colors.fg, 0.07)
                                border.color: active
                                    ? "transparent"
                                    : ColorUtils.applyAlpha(Appearance.colors.fg, 0.12)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    id: pLbl
                                    anchors.centerIn: parent
                                    text: parent.modelData
                                    font.pixelSize: Appearance.font.small - 2
                                    font.family:    Appearance.font.family
                                    font.weight:    Font.Medium
                                    color: parent.active ? Appearance.colors.color8 : Appearance.colors.color10
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        loadPresetProc.command = ["python3", eqWin.scriptPath, "load_preset", parent.modelData]
                                        loadPresetProc.running = true
                                        eqWin.currentPreset    = parent.modelData
                                    }
                                }
                            }
                        }

                        // Close button
                        Rectangle {
                            implicitWidth: 24; implicitHeight: 24; radius: 12
                            color: closeArea.containsMouse
                                ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.12)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: 10
                                color: closeArea.containsMouse ? Appearance.colors.fg : Appearance.colors.dim
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            MouseArea {
                                id: closeArea
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: Appearance.eqVisible = false
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.07)
                    }

                    // ── Sliders ───────────────────────────────────────
                    RowLayout {
                        spacing: 12
                        Layout.alignment: Qt.AlignHCenter

                        // dB scale
                        Item {
                            implicitWidth: 26
                            implicitHeight: 120
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 14

                            Repeater {
                                model: 5
                                Text {
                                    required property int modelData
                                    anchors.right: parent.right
                                    y: (modelData / 4.0) * 120 - implicitHeight / 2
                                    text: {
                                        var db = 12 - modelData * 6
                                        return db > 0 ? "+" + db : String(db)
                                    }
                                    font.pixelSize: 8
                                    font.family:    Appearance.font.family
                                    color: (12 - modelData * 6) === 0
                                        ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.40)
                                        : Appearance.colors.dim
                                }
                            }
                        }

                        // Vertical separator
                        Rectangle {
                            implicitWidth: 1; implicitHeight: 120
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 14
                            color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.07)
                        }

                        // Band sliders
                        Row {
                            spacing: 8

                            Repeater {
                                model: 10

                                Item {
                                    id: band
                                    required property int modelData
                                    property real   gain: eqWin.gains.length > modelData ? eqWin.gains[modelData] : 0.0
                                    property string freq: eqWin.freqLabels[modelData]

                                    readonly property int trackH: 120
                                    width:  28
                                    height: trackH + 38

                                    // Gain label
                                    Text {
                                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
                                        text: band.gain === 0 ? "·"
                                            : (band.gain > 0 ? "+" : "") + band.gain.toFixed(1)
                                        font.pixelSize: 9
                                        font.family:    Appearance.font.family
                                        color: band.gain > 0 ? Appearance.colors.accent
                                             : band.gain < 0 ? Appearance.colors.red
                                             : ColorUtils.applyAlpha(Appearance.colors.fg, 0.20)
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }

                                    // Track
                                    Rectangle {
                                        id: track
                                        width:  6
                                        height: band.trackH
                                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 14 }
                                        radius: 3
                                        color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)

                                        // Positive fill
                                        Rectangle {
                                            visible: band.gain > 0
                                            width: parent.width; radius: parent.radius
                                            height: Math.max(0, (band.gain / 12.0) * (track.height / 2))
                                            y: track.height / 2 - height
                                            color: Appearance.colors.accent
                                            opacity: 0.85
                                            Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                                            Behavior on y      { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                                        }

                                        // Negative fill
                                        Rectangle {
                                            visible: band.gain < 0
                                            width: parent.width; radius: parent.radius
                                            height: Math.max(0, (-band.gain / 12.0) * (track.height / 2))
                                            y: track.height / 2
                                            color: Appearance.colors.red
                                            opacity: 0.75
                                            Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                                        }

                                        // 0 dB line
                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: track.height / 2 - 1
                                            width: 10; height: 1
                                            color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.22)
                                        }

                                        // Handle
                                        Rectangle {
                                            id: handle
                                            width: 14; height: 14; radius: 7
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: (1.0 - (band.gain + 12.0) / 24.0) * (track.height - height)
                                            color: Math.abs(band.gain) < 0.1
                                                ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.45)
                                                : Appearance.colors.accent

                                            Rectangle {
                                                anchors { top: parent.top; topMargin: 2; horizontalCenter: parent.horizontalCenter }
                                                width: parent.width - 6; height: 3; radius: 1.5
                                                color: ColorUtils.applyAlpha("#ffffff", 0.25)
                                            }

                                            Behavior on y     { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                                            Behavior on color { ColorAnimation  { duration: 120 } }
                                        }
                                    }

                                    // Mouse interaction
                                    MouseArea {
                                        x: track.x - 11; y: track.y
                                        width: 28; height: track.height
                                        cursorShape: Qt.SizeVerCursor

                                        function gainAt(my) {
                                            var ratio = 1.0 - Math.max(0, Math.min(track.height, my)) / track.height
                                            return Math.max(-12.0, Math.min(12.0, ratio * 24.0 - 12.0))
                                        }
                                        onEntered: { closeTimer.stop(); Appearance.eqVisible = true }
                                        onExited:  closeTimer.restart()
                                        onPressed:       (ev) => eqWin.setGain(band.modelData, gainAt(ev.y))
                                        onMouseYChanged: if (pressed) eqWin.setGain(band.modelData, gainAt(mouseY))
                                        onDoubleClicked: eqWin.setGain(band.modelData, 0.0)
                                        onWheel: (ev) => {
                                            var step = ev.modifiers & Qt.ShiftModifier ? 0.1 : 0.5
                                            eqWin.setGain(band.modelData, band.gain + (ev.angleDelta.y > 0 ? step : -step))
                                        }
                                    }

                                    // Frequency label
                                    Text {
                                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                                        text: band.freq
                                        font.pixelSize: 9
                                        font.family:    Appearance.font.family
                                        color: Appearance.colors.dim
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
