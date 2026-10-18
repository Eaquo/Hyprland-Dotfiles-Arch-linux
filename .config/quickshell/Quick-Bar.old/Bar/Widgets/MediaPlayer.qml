pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../Common/"
import "../Common/functions/"

Item {
    id: root

    property string title:    ""
    property string artist:   ""
    property string status:   "Stopped"
    property real   percent:  0
    property string artPath:  ""

    property bool hasContent: status !== "Stopped" && title !== ""
    property bool isPlaying:  status === "Playing"
    property bool hovered:    false

    implicitWidth:  hasContent ? mainRow.implicitWidth : 0
    implicitHeight: mainRow.implicitHeight
    Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    // ── Data ─────────────────────────────────────────────────────────────
    readonly property string scriptPath:
        Qt.resolvedUrl("../Scripts/music_info.sh").toString().replace("file://", "")

    Process {
        id: infoProc
        command: ["bash", root.scriptPath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d        = JSON.parse(text.trim())
                    root.title   = d.title   || ""
                    root.artist  = d.artist  || ""
                    root.status  = d.status  || "Stopped"
                    root.percent = d.percent || 0
                    root.artPath = d.artPath || ""
                    Appearance.mediaTitle   = root.title
                    Appearance.mediaArtist  = root.artist
                    Appearance.mediaStatus  = root.status
                    Appearance.mediaPercent = root.percent
                    Appearance.mediaArtPath = root.artPath
                } catch(e) { root.status = "Stopped" }
            }
        }
    }

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: infoProc.running = true
    }

    // ── Controls ─────────────────────────────────────────────────────────
    Process { id: prevProc;  command: ["playerctl", "previous"];   onRunningChanged: if (!running) infoProc.running = true }
    Process { id: pauseProc; command: ["playerctl", "play-pause"]; onRunningChanged: if (!running) infoProc.running = true }
    Process { id: nextProc;  command: ["playerctl", "next"];       onRunningChanged: if (!running) infoProc.running = true }

    MouseArea {
        anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton
        onEntered: {
            root.hovered = true
            var pos = root.mapToGlobal(root.implicitWidth / 2, 0)
            Appearance.mediaPopupX     = pos.x
            Appearance.mediaPopupWidth = root.implicitWidth
            Appearance.mediaPopupOpen  = true
        }
        onExited: root.hovered = false
    }

    // ── Layout ───────────────────────────────────────────────────────────
    RowLayout {
        id: mainRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7
        visible: root.hasContent

        // ── Cover art ─────────────────────────────────────────────────
        Rectangle {
            width:  Appearance.bar.height - 8
            height: Appearance.bar.height - 8
            radius: width / 2
            color:  ColorUtils.applyAlpha(Appearance.colors.dim, 0.5)
            clip:   true
            Layout.leftMargin: 10

            Image {
                anchors.fill: parent
                source:       root.artPath !== "" ? ("file://" + root.artPath) : ""
                fillMode:     Image.PreserveAspectCrop
                smooth:       true
                visible:      root.artPath !== ""
            }

            Text {
                anchors.centerIn: parent
                visible:  root.artPath === ""
                text:     "󰎇"
                font.pixelSize: 13
                color:    Appearance.colors.dim
            }
        }

        // ── Controls + title + progress ───────────────────────────────
        ColumnLayout {
            spacing: 3

            RowLayout {
                spacing: 5

                // Play / Pause
                Text {
                    text: root.isPlaying ? " 󰏤 " : " 󰐊 "
                    font.family:    Appearance.font.family
                    font.pixelSize: 15
                    color: Appearance.colors.color13
                    Behavior on color { ColorAnimation { duration: 150 } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pauseProc.running = true }
                }

                // Scrolling title
                Item {
                    implicitWidth:  120
                    implicitHeight: scrollText.implicitHeight
                    clip: true

                    Text {
                        id: scrollText
                        text: root.artist !== "" ? root.artist + " – " + root.title : root.title
                        font.pixelSize: Appearance.font.small
                        font.family:    Appearance.font.family
                        color: root.isPlaying
                            ? Appearance.colors.color4
                            : ColorUtils.applyAlpha(Appearance.colors.color12, 0.50)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        SequentialAnimation on x {
                            running: scrollText.implicitWidth > 100 && root.hasContent
                            loops:   Animation.Infinite
                            PauseAnimation  { duration: 2500 }
                            NumberAnimation { to: -(scrollText.implicitWidth - 100); duration: scrollText.implicitWidth * 38; easing.type: Easing.Linear }
                            PauseAnimation  { duration: 1200 }
                            NumberAnimation { to: 0; duration: 350; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            // ── Progress bar ──────────────────────────────────────────
            Item {
                implicitWidth:  120
                implicitHeight: 3

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.12)
                }

                Rectangle {
                    width:  parent.width * root.percent
                    height: parent.height
                    radius: 6
                    color:  Appearance.colors.color15
                    Behavior on width { NumberAnimation { duration: 1800; easing.type: Easing.Linear } }
                }
            }
        }
    }
}
