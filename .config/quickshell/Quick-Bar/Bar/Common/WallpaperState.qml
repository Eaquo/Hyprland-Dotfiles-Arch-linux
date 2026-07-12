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
    property string glitchTheme:     "cyberpunk"  // thème d'animation (= un shader .frag)
    property int    glitchInterval:  4000     // ms moyens entre bursts (latence)
    property int    glitchDuration:  280      // ms, durée d'un burst
    property real   glitchSpeed:     1.0      // multiplicateur de vitesse de l'anim
    property real   glitchIntensity: 1.0      // 0..1, pic d'intensité
    property bool   wsFxEnabled:     true      // screen shader au changement de workspace

    // Thèmes disponibles (nom = fichier shaders/<nom>.frag.qsb)
    readonly property var themes: ["cyberpunk", "vhs", "hologram", "synthwave", "bwpixel", "matrix"]

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
            if (d.glitchTheme     !== undefined) root.glitchTheme     = d.glitchTheme
            if (d.glitchInterval  !== undefined) root.glitchInterval  = d.glitchInterval
            if (d.glitchDuration  !== undefined) root.glitchDuration  = d.glitchDuration
            if (d.glitchSpeed     !== undefined) root.glitchSpeed     = d.glitchSpeed
            if (d.glitchIntensity !== undefined) root.glitchIntensity = d.glitchIntensity
            if (d.wsFxEnabled     !== undefined) root.wsFxEnabled     = d.wsFxEnabled
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
            wsFxEnabled:     root.wsFxEnabled
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
    onWsFxEnabledChanged:     save()
}
