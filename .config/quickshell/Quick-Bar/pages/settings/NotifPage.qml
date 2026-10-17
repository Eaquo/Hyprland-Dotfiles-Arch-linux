import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.core

// NotifPage — Réglages › Panneaux › Notifications : swaync (~/.config/swaync/config.json,
// via scripts/config/swaync_set.py) + « Ne pas déranger » (ShellState.dnd, suivi par swaync).
ColumnLayout {
    id: page
    spacing: 18

    property var cfg: ({})
    readonly property string script: Quickshell.shellDir + "/scripts/config/swaync_set.py"
    function load() { getProc.running = false; getProc.running = true }
    function put(k, v) {
        const c = Object.assign({}, cfg); c[k] = v; cfg = c
        pending[k] = v; writeT.restart()
    }
    property var pending: ({})
    Timer { id: writeT; interval: 400
            onTriggered: { Quickshell.execDetached(["python3", page.script, JSON.stringify(page.pending)]); page.pending = ({}); Config.saved() } }
    Process { id: getProc; command: ["python3", page.script, "get"]; running: true
              stdout: StdioCollector { onStreamFinished: { try { page.cfg = JSON.parse(text) } catch (e) {} } } }

    PageHeader { title: "Notifications"; sub: "swaync · ~/.config/swaync/config.json (rechargé en direct)" }

    SetCard {
        title: "Ne pas déranger"
        SetRow {
            title: "Ne pas déranger"; desc: "coupe les notifications de Quick-Bar et de swaync"
            SetSwitch { on: ShellState.dnd; onToggled: ShellState.dnd = !ShellState.dnd }
        }
        SetRow {
            title: "Automatique en jeu"; desc: "activé au lancement d'un jeu, rétabli à la sortie"
            SetSwitch { on: Config.get("game.dnd", false) === true; onToggled: Config.set("game.dnd", on ? null : true) }
        }
    }

    SetCard {
        title: "Fenêtres de notification"
        opacity: Object.keys(page.cfg).length ? 1 : 0.4
        SetRow {
            title: "Position"
            SetSeg {
                options: [["left/top", "Haut gauche"], ["center/top", "Haut centre"], ["right/top", "Haut droite"], ["right/bottom", "Bas droite"]]
                current: (page.cfg.positionX || "right") + "/" + (page.cfg.positionY || "top")
                onPicked: (v) => { const p = v.split("/"); page.put("positionX", p[0]); page.put("positionY", p[1]) }
            }
        }
        SetRow { title: "Largeur"; SetSlider { implicitWidth: 300; from: 280; to: 600; step: 10; suffix: " px"; value: page.cfg["notification-window-width"] || 380
                 onMoved: (v) => { page.put("notification-window-width", v); page.put("control-center-width", v) } } }
        SetRow { title: "Durée d'affichage"; desc: "notifications normales"
                 SetSlider { implicitWidth: 300; from: 2; to: 30; suffix: " s"; value: page.cfg.timeout || 10; onMoved: (v) => page.put("timeout", v) } }
        SetRow { title: "Durée (faible priorité)"
                 SetSlider { implicitWidth: 300; from: 1; to: 20; suffix: " s"; value: page.cfg["timeout-low"] || 5; onMoved: (v) => page.put("timeout-low", v) } }
        SetRow { title: "Critiques"; desc: "restent jusqu'au clic"
                 SetSwitch { on: (page.cfg["timeout-critical"] || 0) === 0; onToggled: page.put("timeout-critical", on ? 15 : 0) } }
        SetRow {
            title: "Tester"
            SetButton { label: "󰂚  Envoyer une notification"; onTap: Quickshell.execDetached(["notify-send", "-a", "Quick-Bar", "Notification de test", "Position, largeur et durée actuelles."]) }
        }
    }
}
