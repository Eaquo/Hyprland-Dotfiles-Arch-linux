pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Minimize — remplace niflveil : la fenêtre active part dans l'espace caché special:minimized,
// et revient sur l'espace où l'on se trouve (la dernière, une précise, ou toutes).
// IPC « minimize » (shell.qml) · raccourcis : services/KeybindService.qml · module de barre : bar/Minimized.qml
Singleton {
    id: root
    readonly property string ws: "special:minimized"
    // fenêtres réduites, suivies en direct par Hyprland (aussi celles d'avant un redémarrage de Quick-Bar)
    readonly property var windows: Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.name === ws)
    property var order: []      // adresses dans l'ordre de réduction (restoreLast prend la dernière)

    function _run(lua) { proc.command = ["hyprctl", "eval", lua]; proc.running = false; proc.running = true }
    function _back(addr) {        // vers l'espace courant, puis focus
        const w = Hyprland.focusedWorkspace
        const dest = w && w.id > 0 ? String(w.id) : "'" + (w ? w.name : "1") + "'"
        return "hl.dispatch(hl.dsp.window.move({ workspace = " + dest + ", follow = false, window = 'address:0x" + addr + "' })) "
    }

    function minimize() {
        const t = Hyprland.activeToplevel
        if (!t || !t.workspace || t.workspace.name === ws) return
        order = order.filter(a => a !== t.address).concat([t.address])
        _run("hl.dispatch(hl.dsp.window.move({ workspace = '" + ws + "', follow = false, window = 'address:0x" + t.address + "' }))")
    }
    function restore(addr) {
        order = order.filter(a => a !== addr)
        _run(_back(addr) + "hl.dispatch(hl.dsp.focus({ window = 'address:0x" + addr + "' }))")
    }
    function restoreLast() {
        const live = windows.map(t => t.address)
        const mine = order.filter(a => live.indexOf(a) >= 0)
        const addr = mine.length ? mine[mine.length - 1] : live[live.length - 1]
        if (addr) restore(addr)
    }
    function restoreAll() {
        if (!windows.length) return
        _run(windows.map(t => _back(t.address)).join(""))     // un seul eval pour toutes
        order = []
    }

    Process { id: proc }
}
