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
