pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Config — réglages généraux lus dans config.toml (à la racine du projet).
// Rechargé à chaud quand le fichier change. Une clé absente ou un fichier
// invalide → la valeur par défaut passée par l'appelant est gardée.
//
//   Config.get("fonts.body", 16)
//   Config.pageScale("wall", 1.0)   // zoom d'une page du TouchPanel (global × page)
//   Config.dir("wallpaper.dir", "~/Pictures/wallpapers")   // « ~ » développé
//   Config.set("fonts.body", 17)    // écrit dans config.toml (commentaires gardés), appliqué tout de suite
//   Config.set("theme.x", null)     // supprime la clé (retour à la valeur par défaut)
QtObject {
    id: root

    readonly property string path: Quickshell.shellDir + "/config.toml"
    property var data: ({})

    function get(key, fallback) {
        let v = data
        for (const k of key.split(".")) {
            if (v === null || typeof v !== "object" || !(k in v)) return fallback
            v = v[k]
        }
        return v
    }
    // Chemin de dossier : « ~ » remplacé par $HOME
    function dir(key, fallback) {
        const v = String(get(key, fallback))
        return v.startsWith("~") ? Quickshell.env("HOME") + v.slice(1) : v
    }
    // ── Général ([general]) — Réglages › Général ──────────────────────────
    // Commande pour lancer `argv` dans le terminal choisi, avec un titre de fenêtre.
    readonly property string terminal: String(get("general.terminal", "kitty"))
    function term(title, argv) {
        const t = terminal
        switch (t.split("/").pop()) {
        case "kitty": case "foot":  return [t, "-T", title].concat(argv)
        case "alacritty": case "xterm": return [t, "-T", title, "-e"].concat(argv)
        case "ghostty":   return [t, "--title=" + title, "-e"].concat(argv)
        case "wezterm":   return [t, "start", "--"].concat(argv)
        case "konsole":   return [t, "-p", "tabtitle=" + title, "-e"].concat(argv)
        case "gnome-terminal": case "ptyxis": return [t, "--title", title, "--"].concat(argv)
        default:          return [t, "-e"].concat(argv)
        }
    }
    // Écran tactile : nom, modèle ou description contenant general.touch_screen (« XENEON » par défaut)
    readonly property string touchMatch: String(get("general.touch_screen", "XENEON")).toUpperCase()
    function isTouch(s) {
        if (!s || touchMatch === "") return false
        return ((s.name || "") + " " + (s.model || "") + " " + (s.description || "")).toUpperCase().indexOf(touchMatch) !== -1
    }
    readonly property string userName: String(get("general.name", Quickshell.env("USER") || ""))
    readonly property string avatar: dir("general.avatar", "~/.face")

    // Intervalle de rafraîchissement ([refresh] <clé> en secondes) → ms, 250 ms minimum
    function ms(key, defSec) { return Math.max(250, Number(get("refresh." + key, defSec)) * 1000) }

    // ── Écriture ──────────────────────────────────────────────────────────
    // La valeur est appliquée tout de suite en mémoire (l'interface suit sans attendre),
    // puis écrite par lots : les modifications rapprochées (un curseur qu'on glisse)
    // partent en une seule écriture, 350 ms après la dernière.
    signal saved()                              // config.toml vient d'être écrit
    property var _pending: ({})
    function set(key, value) {
        const d = JSON.parse(JSON.stringify(data))
        const parts = key.split(".")
        let n = d
        for (const p of parts.slice(0, -1)) { if (typeof n[p] !== "object" || n[p] === null) n[p] = {}; n = n[p] }
        if (value === null || value === undefined) delete n[parts[parts.length - 1]]
        else n[parts[parts.length - 1]] = value
        data = d
        const pend = Object.assign({}, _pending); pend[key] = (value === undefined ? null : value); _pending = pend
        writeTimer.restart()
    }
    property var _writeTimer: Timer {
        id: writeTimer; interval: 350
        onTriggered: {
            if (writer.running) { restart(); return }
            writer.command = ["python3", Quickshell.shellDir + "/scripts/config/config_set.py", root.path, JSON.stringify(root._pending)]
            root._pending = ({})
            writer.running = true
        }
    }
    property var _writer: Process {
        id: writer
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") console.warn("[Config] écriture :", text.trim()) }
        onExited: (code) => { if (code === 0) root.saved() }
    }

    function pageScale(key, fallback) {
        const g = Number(get("touchpanel.scale", 1.0)) || 1.0
        const p = Number(get("touchpanel.pages." + key, fallback)) || fallback
        return Math.max(0.5, Math.min(3.0, g * p))
    }

    // QML ne lit pas le TOML : python (tomllib) le convertit en JSON.
    property var _parse: Process {
        id: parse
        command: ["python3", "-c",
            "import tomllib, json, sys; print(json.dumps(tomllib.load(open(sys.argv[1], 'rb'))))", root.path]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "") return          // lecture interrompue par un rechargement
                try { root.data = JSON.parse(text) }
                catch (e) { console.warn("[Config] config.toml invalide, valeurs précédentes gardées") }
            }
        }
    }
    // Les éditeurs enregistrent en plusieurs écritures : on attend que le fichier soit posé.
    function reload() { debounce.restart() }
    property var _debounce: Timer { id: debounce; interval: 200; onTriggered: { parse.running = false; parse.running = true } }
    property var _watch: FileView {
        path: "file://" + root.path
        watchChanges: true
        onFileChanged: root.reload()
    }
    Component.onCompleted: reload()
}
