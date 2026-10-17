pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// AppDeck — tuiles de l'onglet Apps (pages/apps/StreamDeck.qml), éditées dans Réglages › Apps.
// Données : user_data/streamdeck.json
//   [{ "title": "Dev", "accent": 4, "items": [{ label, exec, appicon, icon, color }, …] }, …]
// (un tableau plat reste accepté → une seule section sans titre)
// Affichage : [apps] tile_size · labels · main_screen dans config.toml.
QtObject {
    id: root

    readonly property string path: Quickshell.shellDir + "/user_data/streamdeck.json"
    property var sections: []

    readonly property int  tileSize:   Config.get("apps.tile_size", 130)
    readonly property bool labels:     Config.get("apps.labels", true) !== false
    readonly property bool mainScreen: Config.get("apps.main_screen", true) !== false   // ouvrir sur l'écran principal

    function _parse(txt) {
        try {
            const d = JSON.parse(txt)
            if (Array.isArray(d) && d.length && d[0] && d[0].items !== undefined) sections = d
            else if (Array.isArray(d)) sections = [{ title: "", accent: 11, items: d }]
            else sections = []
        } catch (e) { sections = [] }
    }
    // Enregistre une nouvelle liste de sections (copie profonde pour la réactivité)
    function save(list) {
        sections = JSON.parse(JSON.stringify(list))
        file.setText(JSON.stringify(sections, null, 2) + "\n")
    }

    // Couleur d'une section : colorN de la palette, éclaircie seulement si elle est sombre
    function color(slot) {
        const c = Appearance.colors["color" + (slot !== undefined ? slot : 11)] || Appearance.colors.accent
        return c.hslLightness < 0.45 ? Qt.lighter(c, 1.4) : c
    }

    // Logo : nom d'icône du thème ou chemin absolu
    function iconSource(a) {
        if (!a) return ""
        return a.charAt(0) === "/" ? "file://" + a : "image://icon/" + a
    }
    function launch(cmd) {
        if (!cmd) return
        runner.command = mainScreen ? ["bash", Quickshell.shellDir + "/scripts/hypr/launch-main.sh", cmd]
                                    : ["sh", "-c", "setsid -f " + cmd + " >/dev/null 2>&1"]
        runner.environment = { QB_TOUCH: Config.touchMatch }
        runner.running = false
        runner.running = true
    }

    property var _file: FileView {
        id: file
        path: "file://" + root.path
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root._parse(text())
    }
    property var _runner: Process { id: runner }
}
