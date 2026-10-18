pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../Common/"
import "../Common/functions/"

RowLayout {
    id: root
    spacing: 2

    // ── State ─────────────────────────────────────────────────────────────
    property int    cpuPercent: 0
    property real   memPercent: 0
    property string memUsed:    "0G"
    property int    tempC:      0
    property int    diskPercent: 0
    property string diskUsed:   "0%"
    property var    _prev:      null

    // ── Queries ───────────────────────────────────────────────────────────
    Process {
        id: cpuQuery
        command: ["bash", "-c",
            "awk '/^cpu /{u=$2+$3+$4; t=u+$5+$6+$7+$8; print u,t}' /proc/stat"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split(" ")
                if (p.length < 2) return
                var active = parseInt(p[0])
                var total  = parseInt(p[1])
                if (root._prev) {
                    var da = active - root._prev.active
                    var dt = total  - root._prev.total
                    if (dt > 0) root.cpuPercent = Math.round(da / dt * 100)
                }
                root._prev = { active: active, total: total }
            }
        }
    }

    Process {
        id: memQuery
        command: ["bash", "-c", "free -m | awk '/^Mem:/{printf \"%.1f %.0f\", $3/1024, $3/$2*100}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split(" ")
                root.memUsed    = p[0] + "G"
                root.memPercent = parseInt(p[1]) || 0
            }
        }
    }

    Process {
        id: tempQuery
        command: ["bash", "-c",
            "cat /sys/class/hwmon/hwmon1/temp1_input 2>/dev/null || cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: root.tempC = Math.round(parseInt(text.trim()) / 1000)
        }
    }

    Process {
        id: diskQuery
        command: ["bash", "-c", "df / | awk 'NR==2{gsub(/%/,\"\",$5); print $5}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.diskPercent = parseInt(text.trim()) || 0
                root.diskUsed    = root.diskPercent + "%"
            }
        }
    }

    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            cpuQuery.running  = true
            memQuery.running  = true
            tempQuery.running = true
            diskQuery.running = true
        }
    }

    // ── Launch actions ────────────────────────────────────────────────────
    Process { id: btopProc;    command: ["kitty", "-T", "System",   "btop"] }
    Process { id: sensorsProc; command: ["kitty", "-T", "Capteurs", "watch", "-n", "2", "sensors"] }
    Process { id: ncduProc;    command: ["kitty", "-T", "Disque",   "ncdu", "--color", "dark", "/"] }

    // ── Chip component ────────────────────────────────────────────────────
    component StatChip: Item {
        id: chip

        property string icon:    ""
        property string label:   ""
        property color  iconCol: Appearance.colors.fg
        property int    percent: -1          // -1 = pas de barre
        property var    action:  null

        // Couleur dynamique exposée pour que le parent puisse la surcharger
        property color  valueCol: Appearance.colors.color15

        implicitWidth:  chipRow.implicitWidth + 14
        implicitHeight: Appearance.bar.height - 4

        // Fond hover
        Rectangle {
            anchors.fill: parent
            radius: 7
            color: ma.containsMouse
                ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
                : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5

            // Icône
            Text {
                text: chip.icon
                font.family:    Appearance.font.family
                font.pixelSize: Appearance.font.body
                color: chip.iconCol
                opacity: ma.containsMouse ? 1.0 : 0.75
                Behavior on opacity { NumberAnimation { duration: 120 } }
                Behavior on color   { ColorAnimation  { duration: 200 } }
            }

            // Valeur + mini barre empilées verticalement
            Column {
                spacing: 2

                Text {
                    text: chip.label
                    font.family:    Appearance.font.family
                    font.pixelSize: Appearance.font.body
                    color: chip.valueCol
                    opacity: ma.containsMouse ? 1.0 : 0.80
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    Behavior on color   { ColorAnimation  { duration: 200 } }
                }

                // Mini barre de progression (optionnelle)
                Item {
                    visible: chip.percent >= 0
                    width:   chipRow.implicitWidth - 22   // largeur du texte
                    height:  2

                    Rectangle {
                        anchors.fill: parent
                        radius: 1
                        color: ColorUtils.applyAlpha(Appearance.colors.color15, 0.10)
                    }

                    Rectangle {
                        width:  Math.max(2, parent.width * chip.percent / 100)
                        height: parent.height
                        radius: 1
                        color:  chip.iconCol
                        opacity: 0.75
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation  { duration: 200 } }
                    }
                }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            onClicked: { if (chip.action) chip.action.running = true }
        }
    }

    // ── CPU ───────────────────────────────────────────────────────────────
    StatChip {
        icon:     "󰍛"
        label:    root.cpuPercent + "%"
        percent:  root.cpuPercent
        action:   btopProc
        iconCol:  root.cpuPercent > 80 ? Appearance.colors.color4
                : root.cpuPercent > 50 ? Appearance.colors.color12
                :                        Appearance.colors.color13
        valueCol: root.cpuPercent > 80 ? Appearance.colors.color4
                : root.cpuPercent > 50 ? Appearance.colors.color12
                :                        Appearance.colors.color15
    }

    // Séparateur
    Rectangle { width: 1; height: 12; radius: 1; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.12) }

    // ── RAM ───────────────────────────────────────────────────────────────
    StatChip {
        icon:    "󰾆"
        label:   root.memUsed
        percent: root.memPercent
        action:  btopProc
        iconCol: root.memPercent > 80 ? Appearance.colors.color4
               : root.memPercent > 60 ? Appearance.colors.color12
               :                        Appearance.colors.color6
        valueCol: iconCol
    }

    // Séparateur
    Rectangle { width: 1; height: 12; radius: 1; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.12) }

    // ── Température ───────────────────────────────────────────────────────
    StatChip {
        icon:    "󰈸"
        label:   root.tempC + "°"
        percent: Math.min(100, Math.round((root.tempC - 30) / 70 * 100))
        action:  sensorsProc
        iconCol: root.tempC > 82 ? Appearance.colors.color4
               : root.tempC > 70 ? Appearance.colors.color12
               :                   Appearance.colors.color15
        valueCol: iconCol
    }

    // Séparateur
    Rectangle { width: 1; height: 12; radius: 1; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.12) }

    // ── Disk ─────────────────────────────────────────────────────────────
    StatChip {
        icon:    "󰋊"
        label:   root.diskUsed
        percent: root.diskPercent
        action:  ncduProc
        iconCol: root.diskPercent > 90 ? Appearance.colors.color4
               : root.diskPercent > 75 ? Appearance.colors.color12
               :                         Appearance.colors.color14
        valueCol: iconCol
    }
}
