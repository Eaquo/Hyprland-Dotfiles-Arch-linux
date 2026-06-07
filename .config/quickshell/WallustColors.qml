import QtQuick
import Quickshell.Io

QtObject {
    id: root

    // ── Fichier source ─────────────────────────────────────────────────────
    property string walPath: Qt.resolvedUrl(
        "file://" + StandardPaths.writableLocation(StandardPaths.HomeLocation)
        + "/.cache/wal/colors.json"
    )

    // ── Couleurs exposées (valeurs par défaut = Catppuccin Mocha fallback) ─
    readonly property color base:     _p.base
    readonly property color surface0: _p.surface0
    readonly property color surface1: _p.surface1
    readonly property color surface2: _p.surface2
    readonly property color overlay0: _p.overlay0
    readonly property color overlay1: _p.overlay1
    readonly property color overlay2: _p.overlay2
    readonly property color text:     _p.text
    readonly property color subtext0: _p.subtext0
    readonly property color subtext1: _p.subtext1
    readonly property color blue:     _p.blue
    readonly property color sapphire: _p.sapphire
    readonly property color mauve:    _p.mauve
    readonly property color pink:     _p.pink
    readonly property color red:      _p.red
    readonly property color yellow:   _p.yellow

    // ── Interne : état parsé ───────────────────────────────────────────────
    property QtObject _p: QtObject {
        // Fallback Catppuccin Mocha
        property color base:     "#1e1e2e"
        property color surface0: "#313244"
        property color surface1: "#45475a"
        property color surface2: "#585b70"
        property color overlay0: "#6c7086"
        property color overlay1: "#7f849c"
        property color overlay2: "#9399b2"
        property color text:     "#cdd6f4"
        property color subtext0: "#a6adc8"
        property color subtext1: "#bac2de"
        property color blue:     "#89b4fa"
        property color sapphire: "#74c7ec"
        property color mauve:    "#cba6f7"
        property color pink:     "#f5c2e7"
        property color red:      "#f38ba8"
        property color yellow:   "#f9e2af"
    }

    // ── Lecteur de fichier avec hot-reload ─────────────────────────────────
    FileView {
        id: walFile
        path: Qt.resolvedUrl(
            "file://" + StandardPaths.writableLocation(StandardPaths.HomeLocation)
            + "/.cache/wal/colors.json"
        )
        watchChanges: true   // Re-lit automatiquement quand wallust regénère

        onTextChanged: root._parseColors(text)
    }

    // ── Parser ─────────────────────────────────────────────────────────────
    function _parseColors(raw) {
        if (!raw || raw.trim() === "") return

        var data
        try {
            data = JSON.parse(raw)
        } catch(e) {
            console.warn("[WallustColors] JSON parse error:", e)
            return
        }

        var c = data.colors   || {}
        var s = data.special  || {}

        // Helpers
        function col(key, fallback) {
            var v = c[key] || fallback
            return v ? v : fallback
        }
        function darken(hex, factor) {
            // Assombrit une couleur hex d'un facteur 0-1
            var r = parseInt(hex.slice(1,3), 16)
            var g = parseInt(hex.slice(3,5), 16)
            var b = parseInt(hex.slice(5,7), 16)
            r = Math.round(r * factor); g = Math.round(g * factor); b = Math.round(b * factor)
            return "#" + r.toString(16).padStart(2,"0")
                       + g.toString(16).padStart(2,"0")
                       + b.toString(16).padStart(2,"0")
        }
        function lighten(hex, factor) {
            var r = parseInt(hex.slice(1,3), 16)
            var g = parseInt(hex.slice(3,5), 16)
            var b = parseInt(hex.slice(5,7), 16)
            r = Math.min(255, Math.round(r + (255-r)*factor))
            g = Math.min(255, Math.round(g + (255-g)*factor))
            b = Math.min(255, Math.round(b + (255-b)*factor))
            return "#" + r.toString(16).padStart(2,"0")
                       + g.toString(16).padStart(2,"0")
                       + b.toString(16).padStart(2,"0")
        }

        // ── Mapping pywal → Catppuccin-style ────────────────────────────────
        // color0  = noir/fond le plus sombre
        // color1  = rouge
        // color2  = vert
        // color3  = jaune
        // color4  = bleu
        // color5  = mauve/magenta
        // color6  = cyan/sapphire
        // color7  = blanc/texte clair
        // color8  = gris foncé (variant sombre des bases)
        // color9-15 = variantes lumineuses de 1-7

        var bg = s.background || col("color0", "#1e1e2e")
        var fg = s.foreground || col("color15", "#cdd6f4")

        _p.base     = bg
        _p.surface0 = darken(bg, 0.7)   // légèrement plus sombre que bg... non
        // En fait on veut surface0 un peu plus clair que base
        _p.surface0 = lighten(bg, 0.08)
        _p.surface1 = lighten(bg, 0.15)
        _p.surface2 = lighten(bg, 0.25)
        _p.overlay0 = lighten(bg, 0.35)
        _p.overlay1 = lighten(bg, 0.50)
        _p.overlay2 = lighten(bg, 0.65)
        _p.text     = fg
        _p.subtext0 = darken(fg, 0.75)
        _p.subtext1 = darken(fg, 0.88)
        _p.blue     = col("color4",  "#89b4fa")
        _p.sapphire = col("color6",  "#74c7ec")
        _p.mauve    = col("color5",  "#cba6f7")
        _p.pink     = col("color13", "#f5c2e7")
        _p.red      = col("color1",  "#f38ba8")
        _p.yellow   = col("color3",  "#f9e2af")
    }
}
