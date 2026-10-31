pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.core

// Mises à jour du serveur Proxmox (hôte + LXC) : scan silencieux de menus/scripts/proxmox.sh toutes
// les [refresh] proxmox s (1 h) ; la liste sert aussi de cache au menu. Clic : le menu « Proxmox ».
GridLayout {
    flow: Appearance.bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    id: root
    rowSpacing: 3; columnSpacing: 3
    // rien à mettre à jour → logo et nombre masqués : le module tombe à largeur nulle et bar/Bar.qml
    // le retire avec son séparateur

    // nombre de lignes de la liste (écrite par le scan) ; relue toutes les 30 s, sans processus
    property int updates: 0
    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: Quickshell.execDetached([Quickshell.shellDir + "/menus/run.sh", "proxmox"]) }

    FileView { id: list; path: Quickshell.env("XDG_RUNTIME_DIR") + "/qb-proxmox/list.txt"; printErrors: false
        onLoaded: root.updates = list.text().split("\n").filter(l => l.length > 0).length
        onLoadFailed: root.updates = 0 }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: list.reload() }
    Process { id: scan; command: ["bash", "-c", "QB_QUIET=1 \"$0\"/menus/run.sh proxmox --call scan >/dev/null 2>&1", Quickshell.shellDir]; onExited: list.reload() }
    Timer { interval: Config.ms("proxmox", 3600); running: true; repeat: true; triggeredOnStart: true; onTriggered: scan.running = true }

    Text {
        Layout.alignment: Qt.AlignCenter
        visible: root.updates > 0
        text: "󰒋"
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
