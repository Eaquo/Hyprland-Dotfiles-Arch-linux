pragma Singleton
import QtQuick
import qs.core
import Quickshell
import Quickshell.Io

// Health — bilan de santé de ce dont Quick-Bar dépend (OpenRGB, EasyEffects,
// hy3, wallust…). Toute la logique est dans scripts/health/check.sh ; ce service
// le lance au démarrage (avec une notification si quelque chose ne répond pas),
// puis toutes les 5 minutes, et à la demande.
//
//   Health.rows       [{ id, label, ok, detail, fix }]
//   Health.failCount  nombre de points en échec
//   Health.refresh()  ·  Health.fix(id)
QtObject {
    id: root

    readonly property string script: Quickshell.shellDir + "/scripts/health/check.sh"
    property var  rows: []
    property bool busy: false
    property string fixing: ""            // id en cours de réparation
    property string lastTried: ""         // dernier id réparé (toujours rouge après → « Réessayer »)
    readonly property int failCount: rows.filter(r => !r.ok).length

    function refresh() {
        if (busy) return
        busy = true
        checkProc.running = true
    }
    function fix(id) {
        if (fixing !== "") return
        fixing = id
        lastTried = id
        fixProc.command = ["bash", script, "fix", id]
        fixProc.running = true
    }

    // Vérifications désactivées + vérifications de l'utilisateur ([health] skip · [[health.custom]])
    readonly property var env: ({
        QB_HEALTH_SKIP: (Config.get("health.skip", []) || []).join(" "),
        QB_HEALTH_CUSTOM: JSON.stringify(Config.get("health.custom", []) || [])
    })
    // ── Ouvrir ce qu'une ligne surveille (toucher la ligne) ──────────────────
    // → { icon, label, cmd } ou null. Sites et machines dans le navigateur, services dans
    // un terminal (status + journal), applis : leur fenêtre, fichiers et montages : l'explorateur.
    function _custom(id) {
        const m = /^custom(\d+)$/.exec(id)
        return m ? (Config.get("health.custom", []) || [])[Number(m[1]) - 1] : null
    }
    function _path(p) { return String(p).startsWith("~") ? Quickshell.env("HOME") + String(p).slice(1) : String(p) }
    function _web(t) { return /^[a-z]+:\/\//.test(t) ? t : "http://" + t }
    function openAction(id) {
        const c = _custom(id)
        if (c) {
            const t = String(c.target || "")
            switch (c.type) {
            case "url":     return { icon: "󰖟", label: "Ouvrir le site", cmd: ["xdg-open", _web(t)] }
            case "host":    return { icon: "󰖟", label: "Interface web", cmd: ["xdg-open", _web(t)] }
            case "port":    return { icon: "󰖟", label: "Ouvrir", cmd: ["xdg-open", _web(t)] }
            case "mount":
            case "file":    return { icon: "󰉋", label: "Ouvrir", cmd: ["xdg-open", _path(t)] }
            case "service": return { icon: "󰆍", label: "État et journal", cmd: Config.term(t, ["sh", "-c",
                "{ systemctl --user status \"$0\" --no-pager 2>/dev/null || systemctl status \"$0\" --no-pager; } ; echo; "
                + "journalctl --user -u \"$0\" -n 40 --no-pager 2>/dev/null | tail -40; read -p 'Entrée pour fermer' _", t]) }
            case "process": return { icon: "󰖯", label: "Afficher", cmd: ["sh", "-c",
                "a=$(hyprctl clients -j | jq -r --arg p \"$0\" '[.[] | select((.class + \" \" + .initialClass) | ascii_downcase | contains($p | ascii_downcase))][0].address // empty'); "
                + "[ -n \"$a\" ] && hyprctl eval \"hl.dispatch(hl.dsp.focus({ window = [[address:$a]] }))\" "
                + "|| notify-send -a Quick-Bar \"$0\" 'Aucune fenêtre ouverte'", t] }
            case "command": return { icon: "󰆍", label: "Lancer", cmd: Config.term(c.name || "Commande", ["sh", "-c",
                "$0; echo; echo \"→ code de sortie : $?\"; read -p 'Entrée pour fermer' _", t]) }
            }
            return null
        }
        switch (id) {
        case "proxmox":     return Config.get("health.proxmox", "") ? { icon: "󰖟", label: "Interface web", cmd: ["xdg-open", "https://" + Config.get("health.proxmox", "") + ":8006"] } : null
        case "openrgb":     return { icon: "󰌵", label: "OpenRGB", cmd: ["sh", "-c", "setsid -f openrgb >/dev/null 2>&1"] }
        case "easyeffects": return { icon: "󰓃", label: "EasyEffects", cmd: ["sh", "-c", "setsid -f easyeffects >/dev/null 2>&1"] }
        case "hy3":
        case "hyprpm":      return { icon: "󰆍", label: "Plugins", cmd: Config.term("hyprpm", ["sh", "-c", "hyprpm list; read -p 'Entrée pour fermer' _"]) }
        case "instances":   return { icon: "󰆍", label: "Processus", cmd: Config.term("Instances", ["sh", "-c", "pgrep -af 'quickshell|qs ' ; read -p 'Entrée pour fermer' _"]) }
        }
        return null
    }
    function open(id) { const a = openAction(id); if (a) Quickshell.execDetached(a.cmd) }

    property bool _notified: false
    property var _check: Process {
        id: checkProc
        command: ["bash", root.script]
        environment: root.env
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.rows = JSON.parse(text) } catch (e) {}
                root.busy = false
                // Une seule notification, au premier bilan après le démarrage
                if (!root._notified) {
                    root._notified = true
                    const ko = root.rows.filter(r => !r.ok)
                    if (ko.length)
                        Quickshell.execDetached(["notify-send", "-u", "normal", "-a", "Quick-Bar",
                            "Bilan de santé : " + ko.length + " point(s) à voir",
                            ko.map(r => "• " + r.label + " — " + r.detail).join("\n")])
                }
            }
        }
    }
    property var _fix: Process {
        id: fixProc
        environment: root.env
        onExited: { root.fixing = ""; root.busy = false; root.refresh() }
    }
    // Premier bilan 25 s après le lancement (le temps que la session démarre), puis toutes les 5 min
    property var _boot: Timer { interval: 25000; running: true; onTriggered: root.refresh() }
    property var _tick: Timer { interval: Config.ms("health", 300); running: true; repeat: true; onTriggered: root.refresh() }
}
