pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "../Common/"
import "../Common/functions/"

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            visible: Appearance.mediaPopupOpen
            WlrLayershell.namespace: "quickshell:mediaplayer"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusiveZone: -1
            anchors { top: true; left: true; right: true; bottom: true }
            color: "transparent"

            readonly property string scriptPath:
                Qt.resolvedUrl("../Scripts/music_info.sh").toString().replace("file://", "")

            Process {
                id: infoProc
                command: ["bash", win.scriptPath]
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            var d = JSON.parse(text.trim())
                            Appearance.mediaTitle   = d.title   || ""
                            Appearance.mediaArtist  = d.artist  || ""
                            Appearance.mediaStatus  = d.status  || "Stopped"
                            Appearance.mediaPercent = d.percent || 0
                            Appearance.mediaArtPath = d.artPath || ""
                        } catch(e) {}
                    }
                }
            }

            Timer {
                interval: 1000; running: Appearance.mediaPopupOpen
                repeat: true; triggeredOnStart: true
                onTriggered: infoProc.running = true
            }

            // ── Cava visualiser (tourne seulement quand la popup est ouverte) ──
            readonly property bool playing: Appearance.mediaStatus === "Playing"
            readonly property int  cavaBars: 28
            property var cavaLevels: (function() {
                var a = []; for (var i = 0; i < 28; i++) a.push(0); return a
            })()

            SplitParser {
                id: cavaPopupParser
                splitMarker: "\n"
                onRead: (line) => {
                    var t = line.trim()
                    if (t.length === 0) return
                    if (t.charAt(t.length - 1) === ";") t = t.slice(0, -1)
                    var parts = t.split(";")
                    if (parts.length !== win.cavaBars) return
                    var arr = []
                    for (var i = 0; i < parts.length; i++) arr.push(parseInt(parts[i]) || 0)
                    win.cavaLevels = arr
                }
            }

            Process {
                running: Appearance.mediaPopupOpen
                command: [
                    "bash", "-c",
                    "printf '[general]\\nbars = 28\\nframerate = 60\\nnoise_reduction = 77\\n\\n" +
                    "[output]\\nmethod = raw\\nraw_target = /dev/stdout\\n" +
                    "data_format = ascii\\nascii_max_range = 100\\n" +
                    "bar_delimiter = 59\\nframe_delimiter = 10\\n\\n" +
                    "[input]\\nmethod = pulse\\nsource = auto\\n' > /tmp/qs-cava-popup.conf && " +
                    "exec /usr/bin/cava -p /tmp/qs-cava-popup.conf 2>/dev/null"
                ]
                stdout: cavaPopupParser
            }

            Process { id: prevProc;  command: ["playerctl", "previous"];   onRunningChanged: if (!running) infoProc.running = true }
            Process { id: pauseProc; command: ["playerctl", "play-pause"]; onRunningChanged: if (!running) infoProc.running = true }
            Process { id: nextProc;  command: ["playerctl", "next"];       onRunningChanged: if (!running) infoProc.running = true }

            MouseArea {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                y: Appearance.bar.topMargin + Appearance.bar.height
                onClicked: Appearance.mediaPopupOpen = false
            }

            // Hotspot zone du bouton EQ dans la barre → switch vers EQ popup
            MouseArea {
                x: Appearance.eqPopupX - win.screen.x - Appearance.eqPopupW / 2 - 6
                y: 0
                width:  Appearance.eqPopupW + 12
                height: Appearance.bar.topMargin + Appearance.bar.height
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onEntered: {
                    closeTimer.stop()
                    Appearance.mediaPopupHeld = false
                    Appearance.mediaPopupOpen = false
                    Appearance.eqVisible = true
                }
            }

            Timer {
                id: closeTimer
                interval: 80; repeat: false
                onTriggered: {
                    Appearance.mediaPopupHeld = false
                    Appearance.mediaPopupOpen = false
                }
            }

            // ── Shared geometry ───────────────────────────────────────────
            readonly property real cardW: Math.max(260, Appearance.mediaPopupWidth)
            // Centré exactement sous le widget MediaPlayer
            readonly property real cardX: Math.max(8, Math.min(Appearance.mediaPopupX - cardW / 2, win.width - cardW - 8))
            readonly property real cardY: Appearance.bar.topMargin + Appearance.bar.height - 1

            // ── Card ──────────────────────────────────────────────────
            Rectangle {
                id: card

                width:  win.cardW
                height: cardCol.implicitHeight + 20 + 22   // +22 = bande visualiseur cava

                x: win.cardX
                y: win.cardY + 6

                radius: Appearance.bar.radius

                color:        Appearance.colors.bg
                border.color: Appearance.colors.color15
                border.width: 1

                // Masque la bordure du haut
                Rectangle {
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 0
                    color: Appearance.colors.bg
                    z: 1
                }   

                opacity: Appearance.mediaPopupOpen ? 1.0 : 0.0
                scale:   Appearance.mediaPopupOpen ? 1.0 : 0.97
                transformOrigin: Item.Top
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on scale   { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                // ── Fond : pochette floutée + dégradé sombre + barres cava ──────
                // Coupé aux coins arrondis de la carte.
                ClippingRectangle {
                    id: bgClip
                    anchors.fill: parent
                    radius: card.radius
                    color:  "transparent"

                    // Pochette source (cachée — rendue via le flou)
                    Image {
                        id: artSource
                        anchors.fill: parent
                        source:   Appearance.mediaArtPath !== "" ? "file://" + Appearance.mediaArtPath : ""
                        fillMode: Image.PreserveAspectCrop
                        smooth:   true
                        visible:  false
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source:      artSource
                        visible:     Appearance.mediaArtPath !== ""
                        blurEnabled: true
                        blur:        1.0
                        blurMax:     48
                        saturation:  0.10
                        brightness:  -0.08
                    }

                    // Dégradé sombre pour garder le texte lisible
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.74) }
                            GradientStop { position: 1.0; color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.93) }
                        }
                    }

                    // Barres cava — collées en bas, montent vers le haut
                    Row {
                        id: cavaRow
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        spacing: 2
                        readonly property real barW:
                            Math.max(1, (width - spacing * (win.cavaBars - 1)) / win.cavaBars)

                        Repeater {
                            model: win.cavaLevels
                            delegate: Item {
                                required property int modelData
                                required property int index
                                width:  cavaRow.barW
                                height: 26
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width:  parent.width
                                    readonly property real amp: win.playing ? (modelData / 100.0) : 0
                                    height: Math.max(2, amp * 26)
                                    radius: width / 2
                                    color:  ColorUtils.applyAlpha(Appearance.specColor(index / win.cavaBars + Appearance.specPhase), 0.25 + amp * 0.60)
                                    Behavior on height { NumberAnimation { duration: 60; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    }
                }

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: cardCol
                    anchors {
                        left: parent.left; right: parent.right; top: parent.top
                        leftMargin: 16; rightMargin: 16; topMargin: 10
                    }
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        ClippingRectangle {
                            width: 56; height: 56
                            radius: 8
                            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.90)

                            Image {
                                anchors.fill: parent
                                source:   Appearance.mediaArtPath !== "" ? "file://" + Appearance.mediaArtPath : ""
                                fillMode: Image.PreserveAspectCrop
                                smooth:   true
                                visible:  Appearance.mediaArtPath !== ""
                            }

                            Text {
                                anchors.centerIn: parent
                                visible:  Appearance.mediaArtPath === ""
                                text:     "󰎇"
                                font.family:    Appearance.font.family
                                font.pixelSize: 28
                                color: Appearance.colors.dim
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                Layout.fillWidth: true
                                text: Appearance.mediaTitle || "—"
                                font.family:    Appearance.font.family
                                font.pixelSize: Appearance.font.body
                                font.weight:    Font.DemiBold
                                color: Appearance.colors.fg
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: Appearance.mediaArtist
                                font.family:    Appearance.font.family
                                font.pixelSize: Appearance.font.small - 1
                                color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.60)
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 4

                        Rectangle {
                            anchors.fill: parent; radius: 4
                            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.90)
                        }
                        Rectangle {
                            width: Math.max(radius * 2, parent.width * Appearance.mediaPercent)
                            height: parent.height; radius: 4
                            color: Appearance.colors.accent
                            Behavior on width { NumberAnimation { duration: 1200; easing.type: Easing.Linear } }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 4
                        spacing: 0

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 34; height: 34; radius: 17
                            color: prevMa.containsMouse ? ColorUtils.applyAlpha(Appearance.colors.bg, 0.90) : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors.centerIn: parent
                                text: "󰒮"
                                font.family:    Appearance.font.family
                                font.pixelSize: Appearance.font.body + 2
                                color: prevMa.containsMouse ? Appearance.colors.fg : ColorUtils.applyAlpha(Appearance.colors.fg, 0.72)
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            MouseArea {
                                id: prevMa; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: prevProc.running = true
                            }
                        }

                        Item { width: 10 }

                        Rectangle {
                            width: 46; height: 46; radius: Appearance.bar.radius
                            color: pauseMa.containsMouse ? Appearance.colors.accent : ColorUtils.applyAlpha(Appearance.colors.accent, 0.82)
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors.centerIn: parent
                                text: Appearance.mediaStatus === "Playing" ? "󰏤" : "󰐊"
                                font.family:    Appearance.font.family
                                font.pixelSize: 24
                                color: Appearance.colors.color0
                            }
                            MouseArea {
                                id: pauseMa; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: pauseProc.running = true
                            }
                        }

                        Item { width: 10 }

                        Rectangle {
                            width: 34; height: 34; radius: 17
                            color: nextMa.containsMouse ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.10) : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                anchors.centerIn: parent
                                text: "󰒭"
                                font.family:    Appearance.font.family
                                font.pixelSize: Appearance.font.body + 2
                                color: nextMa.containsMouse ? Appearance.colors.fg : ColorUtils.applyAlpha(Appearance.colors.fg, 0.72)
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            MouseArea {
                                id: nextMa; anchors.fill: parent
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: nextProc.running = true
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onEntered: { closeTimer.stop(); Appearance.mediaPopupHeld = true }
                    onExited:  closeTimer.restart()
                }
            }
        }
    }
}
