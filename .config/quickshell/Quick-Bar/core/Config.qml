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
