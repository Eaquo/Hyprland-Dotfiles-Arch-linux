pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// GameBreak — « pause tactile » pendant un jeu.
//
// Pourquoi : WindowRulesGaming.lua pose `confine_pointer = true` sur toutes les
// règles de jeu (steam-games, gamescope, wine-games, mtga…). Tant que la fenêtre
// du jeu a le focus, Hyprland confine le pointeur dedans et le tactile du Xeneon
// ne clique plus. Hyprland relâche la contrainte dès que la fenêtre perd le
// focus — d'où l'astuce : focaliser DP-2 quelques secondes, puis rendre le focus
// au jeu PAR ADRESSE (donc sans changer de workspace, le jeu ne bouge pas).
//
//   start()   mémorise la fenêtre active puis focalise l'écran tactile
//   extend()  relance le compte à rebours (appelé aussi sur interaction)
//   stop()    rend le focus à la fenêtre mémorisée
//   toggle()  l'un ou l'autre — c'est ce que bind le raccourci Hyprland
//
// Piloté depuis l'extérieur via IPC (voir GameBreakBar.qml) :
//   qs -p ~/.config/quickshell/Quick-Bar/shell.qml ipc call gamebreak toggle
QtObject {
    id: root

    // ── Réglages ──────────────────────────────────────────────────────────────
    // Durée de la pause avant retour automatique au jeu. Toute interaction sur
    // la barre (ou un changement d'onglet du TouchPanel) la relance à zéro.
    property int autoReturnMs: 20000
    // Mis à false pour rester sur le tactile jusqu'au clic « Revenir au jeu ».
    property bool autoReturn: true
    // Ouvre le TouchPanel pendant la pause (et le referme au retour s'il était
    // fermé). À false si tu préfères te servir de ce qui tourne sur le ws 10.
    property bool openTouchPanel: true

    // ── État ──────────────────────────────────────────────────────────────────
    property bool   active:      false
    property string heldAddress: ""     // adresse Hyprland du jeu (0x…)
    property string heldTitle:   ""
    property int    remainingMs: 0
    property bool   _hadTouchPanel: false   // état du TouchPanel avant la pause

    readonly property real progress:
        autoReturnMs > 0 ? Math.max(0, Math.min(1, remainingMs / autoReturnMs)) : 0

    // Écran tactile = Xeneon Edge (par modèle), sinon le plus petit écran.
    // Même résolution que TouchPanel.qml pour ne pas dupliquer un "DP-2" en dur.
    readonly property string touchMonitor: {
        var all = Quickshell.screens
        for (var i = 0; i < all.length; i++)
            if ((all[i].model || "").toUpperCase().indexOf("XENEON") !== -1) return all[i].name
        var n = "", best = 1e12
        for (var j = 0; j < all.length; j++) {
            var a = all[j].width * all[j].height
            if (a < best) { best = a; n = all[j].name }
        }
        return n
    }

    // ── API ───────────────────────────────────────────────────────────────────
    function toggle() { root.active ? root.stop() : root.start() }

    function start() {
        if (root.active) { root.extend(); return }
        if (root.touchMonitor === "") return
        // Capture de la fenêtre active AVANT de bouger le focus.
        grabProc.running = false
        grabProc.running = true
    }

    function extend() {
        if (!root.active) return
        root.remainingMs = root.autoReturnMs
    }

    function stop() {
        if (!root.active) return
        root.active = false
        root.remainingMs = 0
        if (root.openTouchPanel && !root._hadTouchPanel) ShellState.touchPanelOn = false
        if (root.heldAddress !== "") {
            // focuswindow par adresse : ne change ni de workspace ni de moniteur
            // côté jeu, et re-warpe le curseur dedans (cursor:no_warps = false),
            // ce qui ré-arme le confine_pointer tout seul.
            _run("hl.dispatch(hl.dsp.focus({ window = [[address:" + root.heldAddress + "]] }))")
        }
        root.heldAddress = ""
        root.heldTitle   = ""
    }

    // ── Interne ───────────────────────────────────────────────────────────────
    function _run(lua) {
        cmdProc.command = ["hyprctl", "eval", lua]
        cmdProc.running = false
        cmdProc.running = true
    }

    property var _cmdProc: Process { id: cmdProc }

    property var _grabProc: Process {
        id: grabProc
        command: ["sh", "-c",
            "hyprctl -j activewindow 2>/dev/null | jq -r '(.address // \"\") + \"\\t\" + (.title // \"\")'"]
        stdout: StdioCollector {
            id: grabOut
            onStreamFinished: {
                var parts = grabOut.text.trim().split("\t")
                var addr  = (parts[0] || "").trim()
                if (addr.indexOf("0x") !== 0) return   // rien de focalisé → on ne fait rien
                root.heldAddress = addr
                root.heldTitle   = (parts[1] || "").trim()
                root.active      = true
                root.remainingMs = root.autoReturnMs
                root._hadTouchPanel = ShellState.touchPanelOn
                if (root.openTouchPanel) ShellState.touchPanelOn = true
                root._run("hl.dispatch(hl.dsp.focus({ monitor = [[" + root.touchMonitor + "]] }))")
            }
        }
    }

    // Compte à rebours (100 ms → barre de progression fluide sans coûter cher).
    property var _tick: Timer {
        interval: 100
        repeat:   true
        running:  root.active && root.autoReturn
        onTriggered: {
            root.remainingMs -= 100
            if (root.remainingMs <= 0) root.stop()
        }
    }
}
