pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Updates — paquets à mettre à jour, partagés par la barre (bar/Updates.qml), la grille du tactile
// et le menu « Mises à jour » (menus/scripts/updates.sh). Dépôts : checkupdates · AUR : paru -Qua.
// Relu toutes les [refresh] updates s (30 min) et après une mise à jour.
Singleton {
    id: root
    property int repoCount: 0
    property int aurCount: 0
    readonly property int count: repoCount + aurCount
    property var list: []            // [{ name, from, to, aur }]
    property bool checking: query.running

    function refresh() { query.running = false; query.running = true }
    // tout mettre à jour dans un terminal ([general] update_command), puis relire
    function upgrade() { upgradeProc.running = true }
    function openMenu() { Quickshell.execDetached([Quickshell.shellDir + "/menus/run.sh", "updates"]) }

    property var _query: Process {
        id: query
        // la liste sert aussi de cache au menu (ouverture directe, sans re-scan)
        command: ["bash", "-c", "d=${XDG_RUNTIME_DIR:-/tmp}/qb-updates; mkdir -p \"$d\"; { checkupdates 2>/dev/null | sed 's/^/R /'; paru -Qua 2>/dev/null | sed 's/^/A /'; } > \"$d/list.tmp\"; mv \"$d/list.tmp\" \"$d/list.txt\"; cat \"$d/list.txt\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n").filter(x => x.length > 2).map(x => {
                    const p = x.substring(2).split(/\s+/)          // nom ancienne -> nouvelle
                    return { name: p[0], from: p[1] || "", to: p[3] || "", aur: x.startsWith("A ") }
                })
                root.list = l
                root.repoCount = l.filter(x => !x.aur).length
                root.aurCount = l.filter(x => x.aur).length
            }
        }
    }
    property var _upgrade: Process {
        id: upgradeProc
        command: Config.term("update", ["bash", "-c",
            Config.get("general.update_command", "cachy-update") + "; notify-send 'Système mis à jour' -e; echo; read -n1 -rp 'Appuie sur une touche pour fermer…'"])
        onRunningChanged: if (!running) after.start()
    }
    property var _after: Timer { id: after; interval: 3000; onTriggered: root.refresh() }
    property var _poll: Timer { interval: Config.ms("updates", 1800); running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
