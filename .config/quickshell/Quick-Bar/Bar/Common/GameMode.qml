pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// GameMode — bascule automatique quand un jeu tourne.
//
// Détection : une fenêtre porte le tag Hyprland « games » (posé par
// configs lua/WindowRulesGaming.lua : steam_app_*, gamescope, *.exe…).
// À l'entrée : preset EQ FPS du casque courant (Bose-* → Bose-FPS, sinon
// KZ-FPS), LED à la couleur principale du jeu (syncRgb) ou rgbMode, et stats
// de temps de jeu. À la sortie : session enregistrée, EQ et LED restaurés.
// Le TouchPanel suit `active` pour afficher/quitter sa page Game.
QtObject {
    id: root

    // ── Réglages ──────────────────────────────────────────────────────────────
    property bool   switchEq: true
    property bool   syncRgb:  true      // LED = couleur dominante de la bannière du jeu
    property string rgbMode:  ""        // repli sans couleurs de jeu (ex. "sequence_4") ; vide = inchangé

    // ── État ──────────────────────────────────────────────────────────────────
    property bool   active:    false
    property string gameTitle: ""
    property string gameClass: ""
    property string gameKey:   ""       // appid Steam, sinon classe de fenêtre
    property var    startedAt: null
    // Visuels du jeu (cache Steam), vides si inconnus.
    property string gameArt:    ""
    property string gameLogo:   ""
    property var    gameColors: []      // ["#rrggbb", …] couleurs vives de la bannière
    // Temps de jeu enregistré AVANT cette session (secondes).
    property int statsToday: 0
    property int statsWeek:  0
    property int statsTotal: 0

    property string _prevPreset: ""
    property string _prevRgb:    ""

    readonly property string _scripts: Quickshell.shellDir + "/Bar/Scripts"
    readonly property string _seqFile: _scripts + "/rgb/script/conf/sequence.txt"
    // État d'avant-jeu gardé hors mémoire : un redémarrage de Quickshell en plein
    // jeu ne doit pas prendre l'état « jeu » (déjà appliqué) pour « l'ancien ».
    readonly property string _prevFile:  "/tmp/quickbar-gamemode-preset"
    readonly property string _rgbFile:   "/tmp/quickbar-gamemode-rgb"
    readonly property string _startFile: "/tmp/quickbar-gamemode-start"

    property bool _seen: false
    function _update(clients) {
        const g = clients.find(c => (c.tags || []).some(t => t.replace("*", "") === "games"))
        // 1re lecture sans jeu : fichiers /tmp d'une session finie sans _exit()
        // (redémarrage, crash) → on les jette pour ne pas fausser la suivante.
        if (!_seen) { _seen = true; if (!g) _run(["rm", "-f", _prevFile, _rgbFile, _startFile]) }
        if (g && g.class !== gameClass) _identify(g.class)
        if (g) { gameTitle = g.title; gameClass = g.class }
        if (!!g === active) return
        active = !!g
        if (active) _enter(); else _exit()
    }

    function _enter() {
        startedAt = new Date()
        startProc.running = true                       // reprend l'heure de début si déjà en jeu
        if (switchEq) eqGet.running = true            // → _prevPreset (fichier sinon EQ) puis FPS
        statsProc.running = true
        _applyRgb()
    }
    function _exit() {
        if (startedAt && gameKey !== "")
            _run(["python3", _scripts + "/game_sessions.py", "add", gameKey, gameTitle,
                  String(Math.floor(startedAt / 1000)), String(Math.floor(Date.now() / 1000))])
        startedAt = null
        if (switchEq && _prevPreset !== "") _run(["python3", _scripts + "/eq_control.py", "load_preset", _prevPreset])
        if (_prevRgb !== "") _writeSeq(_prevRgb)
        _run(["rm", "-f", _prevFile, _rgbFile, _startFile])
        _prevPreset = ""; _prevRgb = ""
    }

    // Steam : appid + visuels du cache ; autres jeux : clé = classe, pas de visuels.
    function _identify(cls) {
        const m = /^steam_app_(\d+)/.exec(cls)
        gameKey = m ? m[1] : cls
        gameArt = ""; gameLogo = ""; gameColors = []
        if (!m) return
        artProc.command = ["bash", _scripts + "/game_art.sh", m[1]]
        artProc.running = true
    }

    // LED : couleur du jeu si connue, sinon rgbMode. Mémorise d'abord l'état courant.
    function _applyRgb() {
        const mode = (syncRgb && gameColors.length) ? "fixed_" + gameColors[0] : rgbMode
        if (!active || mode === "") return
        rgbGet.target = mode
        rgbGet.running = true
    }

    function _run(cmd) {
        const p = Qt.createQmlObject('import Quickshell.Io; Process {}', root)
        p.command = cmd
        p.exited.connect(() => p.destroy())
        p.running = true
    }
    // Le watcher RGB (seul maître) applique le mode écrit dans sequence.txt.
    function _writeSeq(mode) { _run(["sh", "-c", "printf '%s' \"$1\" > \"$2\"", "_", mode, _seqFile]) }

    // ── Détection (événements Hyprland, anti-rafale) ─────────────────────────
    property var _debounce: Timer { interval: 400; onTriggered: clientsProc.running = true }
    property var _conn: Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (["openwindow", "closewindow", "movewindow"].indexOf(ev.name) !== -1) root._debounce.restart()
        }
    }
    property var _clientsProc: Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { root._update(JSON.parse(text)) } catch (e) {} } }
    }

    property var _startProc: Process {
        id: startProc
        command: ["sh", "-c", "[ -s \"$1\" ] || date +%s > \"$1\"; cat \"$1\"", "_", root._startFile]
        stdout: StdioCollector {
            onStreamFinished: { const t = parseInt(text); if (root.active && t > 0) root.startedAt = new Date(t * 1000) }
        }
    }
    property var _artProc: Process {
        id: artProc
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n").map(x => x.trim())
                root.gameArt    = l[0] ? "file://" + l[0] : ""
                root.gameLogo   = l[1] ? "file://" + l[1] : ""
                root.gameColors = l[2] ? l[2].split(",") : []
                root._applyRgb()
            }
        }
    }
    property var _statsProc: Process {
        id: statsProc
        command: ["python3", root._scripts + "/game_sessions.py", "stats", root.gameKey]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    root.statsToday = d.today; root.statsWeek = d.week; root.statsTotal = d.total
                } catch (e) {}
            }
        }
    }

    property var _eqGet: Process {
        id: eqGet
        // Fichier existant (jeu déjà en cours avant un redémarrage) → on le garde ;
        // sinon on y écrit le preset courant.
        command: ["sh", "-c", "[ -s \"$1\" ] && cat \"$1\" || { python3 \"$2\" get | python3 -c 'import json,sys;print(json.load(sys.stdin)[\"preset\"])' | tee \"$1\"; }",
                  "_", root._prevFile, root._scripts + "/eq_control.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._prevPreset = text.trim()
                const fps = root._prevPreset.indexOf("Bose") === 0 ? "Bose-FPS" : "KZ-FPS"
                if (root.active && root._prevPreset !== fps)
                    root._run(["python3", root._scripts + "/eq_control.py", "load_preset", fps])
            }
        }
    }
    property var _rgbGet: Process {
        id: rgbGet
        property string target: ""
        // Même principe que le preset : l'état d'avant-jeu survit aux redémarrages.
        command: ["sh", "-c", "[ -s \"$1\" ] && cat \"$1\" || tee \"$1\" < \"$2\"", "_", root._rgbFile, root._seqFile]
        stdout: StdioCollector {
            onStreamFinished: {
                root._prevRgb = text.trim()
                if (root.active && rgbGet.target !== "") root._writeSeq(rgbGet.target)
            }
        }
    }
}
