pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// État + config des effets wallpaper (glitch, screen shader).
// Persisté dans user_data/wallpaper_fx.json. Partagé entre Wallpaper.qml
// (rendu) et l'onglet Wallpaper du dashboard (contrôles).
QtObject {
    id: root

    readonly property string _path:
        Quickshell.env("HOME") + "/.config/quickshell/Quick-Bar/user_data/wallpaper_fx.json"

    // ── Config ────────────────────────────────────────────────────────────────
    property bool   glitchEnabled:   true     // burst glitch sur le wallpaper
    property string glitchTheme:     "matrix"     // thème d'animation (= un shader .frag)
    property int    glitchInterval:  4000     // ms moyens entre bursts (latence)
    property int    glitchDuration:  280      // ms, durée d'un burst
    property real   glitchSpeed:     1.0      // multiplicateur de vitesse de l'anim
    property real   glitchIntensity: 1.0      // 0..1, pic d'intensité
    property bool   glitchContinuous: false   // effet en continu (sinon par bursts)
    property string glitchColor:     ""        // couleur de l'effet "#rrggbb" ; vide = accent wallust
    readonly property color fxColor: glitchColor !== "" ? glitchColor : Appearance.colors.accent
    property bool   wsFxEnabled:     true      // screen shader au changement de workspace
    // Rotation : change de wallpaper tout seul, au hasard, toutes les autoMinutes.
    property bool   autoChange:      false
    property int    autoMinutes:     15

    // Thèmes disponibles (nom = fichier shaders/<nom>.frag.qsb)
    readonly property var themes: ["matrix", "aurora", "underwater", "fireworks"]

    // ── État courant (rempli par Wallpaper.qml / le picker) ────────────────────
    property string currentWall: ""
    property bool   videoMode:   false   // wallpaper vidéo actif → glitch off + Quickshell masqué

    property bool _loading: false

    function _parse(txt) {
        if (!txt || txt.length === 0) return
        try {
            var d = JSON.parse(txt)
            root._loading = true
            if (d.glitchEnabled   !== undefined) root.glitchEnabled   = d.glitchEnabled
            if (themes.includes(d.glitchTheme))    root.glitchTheme     = d.glitchTheme
            if (d.glitchInterval  !== undefined) root.glitchInterval  = d.glitchInterval
            if (d.glitchDuration  !== undefined) root.glitchDuration  = d.glitchDuration
            if (d.glitchSpeed     !== undefined) root.glitchSpeed     = d.glitchSpeed
            if (d.glitchIntensity !== undefined) root.glitchIntensity = d.glitchIntensity
            if (d.glitchContinuous !== undefined) root.glitchContinuous = d.glitchContinuous
            if (d.glitchColor     !== undefined) root.glitchColor     = d.glitchColor
            if (d.wsFxEnabled     !== undefined) root.wsFxEnabled     = d.wsFxEnabled
            if (d.autoChange      !== undefined) root.autoChange      = d.autoChange
            if (d.autoMinutes     !== undefined) root.autoMinutes     = d.autoMinutes
            root._loading = false
        } catch (e) { root._loading = false }
    }

    function save() {
        if (root._loading) return
        var json = JSON.stringify({
            glitchEnabled:   root.glitchEnabled,
            glitchTheme:     root.glitchTheme,
            glitchInterval:  root.glitchInterval,
            glitchDuration:  root.glitchDuration,
            glitchSpeed:     root.glitchSpeed,
            glitchIntensity: root.glitchIntensity,
            glitchContinuous: root.glitchContinuous,
            glitchColor:     root.glitchColor,
            wsFxEnabled:     root.wsFxEnabled,
            autoChange:      root.autoChange,
            autoMinutes:     root.autoMinutes
        })
        saveProc.command = ["bash", "-c", "printf '%s' \"$1\" > \"$2\"", "_", json, root._path]
        saveProc.running = false
        saveProc.running = true
    }

    property var _fv: FileView {
        path:         "file://" + root._path
        watchChanges: true
        onFileChanged: reload()
        onLoaded:      root._parse(text())
    }
    property var _saveProc: Process { id: saveProc }

    onGlitchEnabledChanged:   save()
    onGlitchThemeChanged:     save()
    onGlitchIntervalChanged:  save()
    onGlitchDurationChanged:  save()
    onGlitchSpeedChanged:     save()
    onGlitchIntensityChanged: save()
    onGlitchContinuousChanged: save()
    onGlitchColorChanged:     save()
    onWsFxEnabledChanged:     save()
    onAutoChangeChanged:      save()
    onAutoMinutesChanged:     save()

    // ── Wallpaper aléatoire / rotation automatique ─────────────────────────────
    // Tire une image au hasard dans ~/Pictures/wallpapers (pas la courante, pas
    // les vidéos) et l'applique par set-wallpaper.sh (→ wallust → couleurs).
    function randomWall() {
        randomProc.running = false
        randomProc.running = true
    }
    property var _randomProc: Process {
        id: randomProc
        command: ["bash", "-c",
            "f=$(find \"$HOME/Pictures/wallpapers\" -maxdepth 1 -type f " +
            "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) " +
            "! -path \"$1\" | shuf -n1); [ -n \"$f\" ] || exit 1; " +
            "pkill -x gslapper 2>/dev/null; \"$HOME/.config/hypr/scripts/set-wallpaper.sh\" \"$f\" >/dev/null; echo \"$f\"",
            "_", root.currentWall]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim()
                if (f !== "") { root.currentWall = f; root.videoMode = false }
            }
        }
    }
    // En pause pendant un jeu (pas de recoloration en pleine partie) et en mode vidéo.
    property var _autoTimer: Timer {
        interval: Math.max(1, root.autoMinutes) * 60000
        repeat: true
        running: root.autoChange && !root.videoMode && !GameMode.active
        onTriggered: root.randomWall()
    }
}
