pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.core

// Rangée en barre horizontale, colonne en barre verticale ([bar] position)
GridLayout {
    flow: Appearance.bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    id: root
    rowSpacing: 3; columnSpacing: 3

    property int  updates:   0
    property int  repoCount: 0
    property int  aurCount:  0
    property var  pkgList:   []

    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
    TapHandler   { onTapped: upgradeProc.running = true }

    // Dépôts officiels (checkupdates) + AUR (paru -Qua), chaque ligne préfixée R/A
    Process {
        id: updateQuery
        command: ["bash", "-c",
            "checkupdates 2>/dev/null | sed 's/^/R /'; paru -Qua 2>/dev/null | sed 's/^/A /'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n").filter(l => l.length > 2)
                var repo = 0, aur = 0, list = []
                for (var i = 0; i < lines.length; i++) {
                    var l = lines[i]
                    if (l.startsWith("R ")) { repo++; list.push(l.substring(2)) }
                    else if (l.startsWith("A ")) { aur++; list.push(l.substring(2)) }
                }
                root.repoCount = repo
                root.aurCount  = aur
                root.updates   = repo + aur
                root.pkgList   = list
            }
        }
    }

    Process {
        id: upgradeProc
        command: Config.term("update", ["bash", "-c",
            Config.get("general.update_command", "cachy-update") + "; notify-send 'Système mis à jour' -i $HOME/.config/swaync/icons/hyprland.png -e; echo; read -n1 -rp 'Appuie sur une touche pour fermer...'"
        ])
        onRunningChanged: if (!running) refreshTimer.start()
    }

    // Poll toutes les 30 min (+ au démarrage)
    Timer {
        interval: Config.ms("updates", 1800); running: true; repeat: true; triggeredOnStart: true
        onTriggered: updateQuery.running = true
    }
    Timer {
        id: refreshTimer
        interval: 3000; repeat: false
        onTriggered: updateQuery.running = true
    }

    Text {
        Layout.alignment: Qt.AlignCenter
        text: " "
        font.family:    Appearance.font.family
        font.pixelSize: Appearance.bar.icon
        color: root.updates > 0
            ? (hov.hovered ? Appearance.colors.color13 : Appearance.colors.color5)
            : Appearance.colors.dim
        Behavior on color { ColorAnimation { duration: Appearance.dur(120) } }
    }

    Text {
        Layout.alignment: Qt.AlignCenter
        visible: root.updates > 0
        text:    root.updates.toString()
        font.pixelSize: Appearance.bar.small
        color: hov.hovered ? Appearance.colors.color13 : Appearance.colors.color5
        Behavior on color { ColorAnimation { duration: Appearance.dur(120) } }
    }
}
