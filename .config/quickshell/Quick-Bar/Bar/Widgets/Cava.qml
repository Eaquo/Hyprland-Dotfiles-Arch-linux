pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../Common/"

Item {
    id: root

    readonly property int barCount: 14
    readonly property int barW:     3
    readonly property int barGap:   2
    readonly property int innerGap: 5

    // Jaquette ronde visible dès qu'un lecteur est actif
    readonly property bool showArt: Appearance.mediaStatus !== "Stopped"
    readonly property int  artSize: implicitHeight

    readonly property int barsWidth: barCount * barW + (barCount - 1) * barGap

    implicitWidth:  barsWidth + (showArt ? artSize + innerGap : 0)
    implicitHeight: Appearance.bar.height - 12

    property var levels: new Array(barCount).fill(0)

    SplitParser {
        id: cavaParser
        splitMarker: "\n"
        onRead: (line) => {
            var t = line.trim()
            if (t.length === 0) return
            var arr = []
            for (var i = 0; i < t.length; i++) {
                var n = t.charCodeAt(i) - 48
                if (n >= 0 && n <= 7) arr.push(n)
            }
            if (arr.length > 0) root.levels = arr
        }
    }

    Process {
        running: true
        command: [
            "bash", "-c",
            "printf '[general]\\nbars = 14\\nsleep_timer = 0\\n\\n[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\nascii_max_range = 7\\n\\n[input]\\nmethod = pulse\\nsource = auto\\n' > /tmp/qs-cava.conf && exec /usr/bin/cava -p /tmp/qs-cava.conf"
        ]
        stdout: cavaParser
    }

    // Poller média permanent → alimente Appearance.media* (jaquette).
    // (MediaPlayerPopup ne met à jour que quand sa popup est ouverte.)
    Process {
        id: mediaInfoProc
        command: ["bash", Qt.resolvedUrl("../Scripts/music_info.sh").toString().replace("file://", "")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(text.trim())
                    Appearance.mediaStatus  = d.status  || "Stopped"
                    Appearance.mediaArtPath = d.artPath || ""
                    Appearance.mediaTitle   = d.title   || ""
                    Appearance.mediaArtist  = d.artist  || ""
                } catch(e) {}
            }
        }
    }
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: mediaInfoProc.running = true
    }

    // Clic sur le Cava → ouvre/ferme le Dashboard (page home)
    MouseArea {
        anchors.fill: parent
        cursorShape:  Qt.PointingHandCursor
        z: 10
        onClicked: {
            var next = !Popups.dashboardOpen
            Popups.closeAll()
            Popups.dashboardOpen = next
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: root.innerGap

        // ── Jaquette ronde ────────────────────────────────────────────────
        Item {
            id: art
            width:   root.artSize
            height:  root.artSize
            visible: root.showArt
            anchors.verticalCenter: parent.verticalCenter

            // Fallback ♪ quand pas de pochette
            Rectangle {
                anchors.fill: parent
                radius:       width / 2
                visible:      Appearance.mediaArtPath === ""
                color:        Qt.rgba(Appearance.colors.accent.r, Appearance.colors.accent.g, Appearance.colors.accent.b, 0.18)
                border.width: 1
                border.color: Qt.rgba(Appearance.colors.accent.r, Appearance.colors.accent.g, Appearance.colors.accent.b, 0.38)
                Text {
                    anchors.centerIn: parent
                    text:           "♪"
                    font.pixelSize: parent.width * 0.5
                    color:          Appearance.colors.accent
                }
            }

            // Masque circulaire pour l'image
            Rectangle {
                id:            artMask
                anchors.fill:  parent
                radius:        width / 2
                visible:       false
                layer.enabled: true
            }

            Image {
                anchors.fill:  parent
                source:        Appearance.mediaArtPath
                fillMode:      Image.PreserveAspectCrop
                smooth:        true
                cache:         true
                visible:       Appearance.mediaArtPath !== ""
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled:      true
                    maskSource:       artMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin:  1.0
                }
            }
        }

        // ── Barres cava ───────────────────────────────────────────────────
        Row {
            spacing: root.barGap
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: root.barCount

                Item {
                    id: barSlot
                    required property int index
                    property real level: root.levels.length > index ? root.levels[index] / 7.0 : 0.0

                    width:  root.barW
                    height: root.implicitHeight

                    // Barre centrée verticalement (grandit vers le haut ET le bas),
                    // bout arrondi en pilule, opacité pilotée par l'amplitude.
                    Rectangle {
                        anchors.centerIn: parent
                        width:  root.barW
                        height: Math.max(root.barW, parent.height * barSlot.level)
                        radius: width / 2
                        color:  Appearance.specColor(barSlot.index / root.barCount + Appearance.specPhase)
                        opacity: 0.28 + 0.72 * barSlot.level

                        Behavior on height  { NumberAnimation { duration: 50; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 50 } }
                    }
                }
            }
        }
    }
}
