pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// CodingMode — mode Coding du soir (tuile des réglages rapides) : un thème wallust fixe et reposant pour tout le
// système, lumière chaude (hyprsunset) et effets animés du fond coupés. Deux variantes : sombre / claire.
// Le travail système est fait par scripts/system/coding-mode.sh (marqueur ~/.cache/quickbar/coding-mode).
//   [coding] variant = "dark" | "light" · dark_theme (coding-dark) / light_theme (wallpaper-light = le fond en clair ; ou coding-light,
//   ~/.config/wallust/colorschemes/ ; ou un nom de `wallust theme list`) · temperature (K, 0 = sans)
Singleton {
    id: root
    readonly property string marker: Quickshell.env("HOME") + "/.cache/quickbar/coding-mode"
    property bool active: false
    readonly property string variant: Config.get("coding.variant", "dark") === "light" ? "light" : "dark"
    readonly property string theme: variant === "light" ? String(Config.get("coding.light_theme", "wallpaper-light"))
                                                        : String(Config.get("coding.dark_theme", "coding-dark"))
    // protection des yeux (lumière chaude) : interrupteur à part, la tuile « Night Light », comme en temps normal ;
    // [coding] temperature = 4500 pour que le mode l'allume tout seul (0 = ne pas y toucher, par défaut)
    readonly property int temperature: Number(Config.get("coding.temperature", 0))
    readonly property string label: variant === "light" ? "Clair" : "Sombre"

    function toggle() { _touched = true; active ? stop() : start() }
    function start() {
        // l'effet animé du fond distrait : coupé pendant le mode, remis à la sortie
        if (!active) { _fxWas = WallpaperState.glitchEnabled; WallpaperState.glitchEnabled = false }
        active = true
        _matugen()
        _run(["on", theme, String(temperature)])
    }
    function stop() {
        active = false
        WallpaperState.glitchEnabled = _fxWas
        _matugen()
        _run(["off"])
    }
    // clic droit : sombre ⇄ clair (appliqué tout de suite si le mode est actif)
    function switchVariant() {
        _touched = true
        Config.set("coding.variant", variant === "light" ? "dark" : "light")
        if (active) Qt.callLater(() => { _run(["on", theme, String(temperature)]); _matugen() })
    }

    property bool _touched: false
    property bool _fxWas: true
    // Quick-Bar sur matugen : le mode Coding lui donne matugen clair/sombre en préférence « douce »
    // ([coding] matugen_prefer) ; à la sortie, les réglages matugen habituels reviennent
    function _matugen() {
        if (Appearance.paletteSource !== "matugen") return
        Appearance.matugenModeOverride = active ? variant : ""
        Appearance.matugenPreferOverride = active ? String(Config.get("coding.matugen_prefer", "less-saturation")) : ""
        Qt.callLater(Appearance.regenerateMatugen)
    }
    // lancement détaché : un Process relancé juste après la création du service perdait parfois l'appel
    function _run(args) { Quickshell.execDetached([Quickshell.shellDir + "/scripts/system/coding-mode.sh"].concat(args)) }
    // état au démarrage de Quick-Bar : le marqueur dit si le mode était actif
    Process {
        running: true
        command: ["test", "-f", root.marker]
        onExited: (code) => { if (!root._touched) root.active = (code === 0) }   // une action de l'utilisateur prime
    }
}
