pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.core

// XeneonSend — SUPER+O (IPC « xeneon toggle ») : envoie la fenêtre active en plein écran sur l'écran tactile
// (Xeneon), puis la ramène, sur le même raccourci, dans l'espace d'où elle venait. Tant qu'une fenêtre est
// envoyée, le TouchPanel s'efface (Popups.touchHidden) pour la laisser visible ; il revient quand elle repart
// ou se ferme. Une seule lecture de `hyprctl activewindow` par appui, aucun sondage.
Singleton {
    id: root
    property var sent: ({})                       // "0xadresse" → espace d'origine

    function touchMonitor() {
        const s = Quickshell.screens.find(x => Config.isTouch(x))
        return s ? Hyprland.monitors.values.find(m => m.name === s.name) || null : null
    }
    function mainMonitor() {
        const s = Quickshell.screens.find(x => !Config.isTouch(x))
        return s ? Hyprland.monitors.values.find(m => m.name === s.name) || null : null
    }
    function update() { Popups.touchHidden = Object.keys(sent).length > 0 }

    Process { id: run }
    function hypr(lua) { run.command = ["hyprctl", "eval", lua]; run.running = false; run.running = true }

    Process {
        id: active
        command: ["hyprctl", "-j", "activewindow"]
        stdout: StdioCollector { onStreamFinished: {
            let w = null
            try { w = JSON.parse(text) } catch (e) {}
            if (!w || !w.address) return
            const tm = root.touchMonitor()
            if (!tm) return
            const win = "window = 'address:" + w.address + "'"
            const onTouch = w.monitor === tm.id
            if (!onTouch) {                                         // → Xeneon, plein écran
                const s = Object.assign({}, root.sent); s[w.address] = w.workspace.id; root.sent = s
                root.update()
                root.hypr("hl.dispatch(hl.dsp.window.move({ workspace = " + tm.activeWorkspace.id + ", " + win + " })) "
                        + "hl.dispatch(hl.dsp.focus({ " + win + " })) "
                        + (w.fullscreen ? "" : "hl.dispatch(hl.dsp.window.fullscreen({ " + win + " }))"))
            } else {                                                // ← retour à son espace d'origine
                const mm = root.mainMonitor()
                const back = root.sent[w.address] ?? (mm ? mm.activeWorkspace.id : 1)
                const s = Object.assign({}, root.sent); delete s[w.address]; root.sent = s
                root.update()
                root.hypr((w.fullscreen ? "hl.dispatch(hl.dsp.window.fullscreen({ " + win + " })) " : "")
                        + "hl.dispatch(hl.dsp.window.move({ workspace = " + back + ", " + win + " })) "
                        + "hl.dispatch(hl.dsp.focus({ " + win + " }))")
            }
        } }
    }
    function toggle() { active.running = false; active.running = true }

    // fenêtre envoyée fermée → on l'oublie (et le TouchPanel revient s'il n'en reste plus)
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "closewindow") return
            const a = "0x" + event.data
            if (root.sent[a] === undefined) return
            const s = Object.assign({}, root.sent); delete s[a]; root.sent = s
            root.update()
        }
    }
}
