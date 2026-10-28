pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ── Source des couleurs (Réglages › Couleurs, [theme] dans config.toml) ──
    // « wallust » : ~/.cache/wal/wal.json, écrit par wallust à chaque wallpaper.
    // « matugen » : couleurs Material You, même format JSON (modèle
    //   ~/.config/matugen/templates/quickbar.json) ; Quick-Bar relance matugen
    //   lui-même quand le wallpaper change, puisque set-wallpaper.sh ne lance que wallust.
    readonly property string paletteSource: Config.get("theme.palette", "wallust") === "matugen" ? "matugen" : "wallust"
    readonly property string paletteName: paletteSource === "matugen" ? "Matugen" : "Wallust"   // libellés de l'interface
    function _expand(p) { return String(p).startsWith("~") ? Quickshell.env("HOME") + String(p).slice(1) : String(p) }
    readonly property string palettePath: paletteSource === "matugen"
        ? _expand(Config.get("theme.matugen_path", "~/.cache/matugen/quickbar_colors.json"))
        : _expand(Config.get("theme.wallust_path", "~/.cache/wal/wal.json"))

    FileView {
        id: walFile
        path: "file://" + root.palettePath
        watchChanges: true
        onFileChanged: walFile.reload()
        onPathChanged: walFile.reload()
        onLoaded: {
            root._parse(walFile.text())
            // thème « Quick-Bar » d'Amethyst Mod Manager, recalculé sur la même palette
            Quickshell.execDetached(["python3", Quickshell.shellDir + "/scripts/apps/amethyst-theme.py",
                                     root.palettePath, root.paletteName, root.accentSlot])
        }
    }

    Component.onCompleted: walFile.reload()

    // Matugen : régénère la palette à chaque wallpaper (et au passage sur matugen)
    function regenerateMatugen() {
        if (paletteSource !== "matugen" || WallpaperState.currentWall === "") return
        // wallpaper vidéo : matugen ne lit pas les .mp4 → image fixe de la vidéo
        const img = WallpaperState.videoMode ? Quickshell.env("HOME") + "/.curr_wall_static.jpg" : WallpaperState.currentWall
        matugenProc.command = ["matugen", "image", img,
                               "--prefer", String(Config.get("theme.matugen_prefer", "saturation")),
                               "-m", String(Config.get("theme.matugen_mode", "dark"))]
        matugenProc.running = false
        matugenProc.running = true
    }
    onPaletteSourceChanged: regenerateMatugen()
    property var _matugenWall: Connections {
        target: WallpaperState
        function onCurrentWallChanged() { root.regenerateMatugen() }
    }
    property var _matugenProc: Process {
        id: matugenProc
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") console.warn("[Matugen]", text.trim().split("\n").slice(-3).join(" ")) }
    }

    property var _special: ({})
    property var _palette: ({})

    function _parse(rawText) {
        if (!rawText || rawText.length === 0) {
            console.warn("[Wallust] Colors file is empty")
            return
        }
        try {
            var parsed = JSON.parse(rawText)
            _special = parsed.special || {}
            _palette = parsed.colors  || {}
            console.log("[" + paletteSource + "] loaded:", _special.background)
        } catch (e) {
            console.warn("[Wallust] parse error:", e)
        }
    }

    // ── Color palette ─────────────────────────────────────────────────────
    // Access as Appearance.colors.* OR Appearance.color.* (alias below)
    property QtObject colors: QtObject {
        // ── raw color0–color15 ─────────────────────────────────────────
        property color color0:  _palette.color0  || "#0f0f0f"
        property color color1:  _palette.color1  || "#ff6b6b"
        property color color2:  _palette.color2  || "#51cf66"
        property color color3:  _palette.color3  || "#ffd43b"
        property color color4:  _palette.color4  || "#339af0"
        property color color5:  _palette.color5  || "#cc5de8"
        property color color6:  _palette.color6  || "#22b8cf"
        property color color7:  _palette.color7  || "#e8e8e8"
        property color color8:  _palette.color8  || "#4a4a4a"
        property color color9:  _palette.color9  || "#ff8787"
        property color color10: _palette.color10 || "#69db7c"
        property color color11: _palette.color11 || "#ffe066"
        property color color12: _palette.color12 || "#4dabf7"
        property color color13: _palette.color13 || "#da77f2"
        property color color14: _palette.color14 || "#3bc9db"
        property color color15: _palette.color15 || "#f8f8f8"
        // ── special ────────────────────────────────────────────────────
        property color bg:     _special.background || "#0f0f0f"
        property color fg:     _special.foreground || "#e8e8e8"
        property color cursor: _special.cursor     || "#e8e8e8"
        // ── semantic aliases ───────────────────────────────────────────
        // Réglages › Apparence › Thème : quelle couleur de la palette sert d'accent ([theme] accent)
        property color accent:  _palette[root.accentSlot] || _palette.color11 || "#ffe066"
        property color dim:     _palette.color8  || "#4a4a4a"
        property color surface: _palette.color0  || "#0f0f0f"
        property color hi:      accent
        property color overlay: _palette.color8  || "#4a4a4a"
        property color red:     _palette.color1  || "#ff6b6b"
        property color green:   _palette.color2  || "#51cf66"
        property color yellow:  _palette.color3  || "#ffd43b"
        property color blue:    _palette.color4  || "#339af0"
        property color mauve:   _palette.color5  || "#cc5de8"
        property color cyan:    _palette.color6  || "#22b8cf"
        property color orange:  _palette.color9  || "#ff8787"
        property color pink:    _palette.color13 || "#da77f2"
    }

    // alias so both Appearance.color.* and Appearance.colors.* work
    property alias color: root.colors

    // ── Auto-contraste (lisibilité wallust) ───────────────────────────────────
    // wallust tire les couleurs du wallpaper ; parfois un rôle "clair" tombe sombre.
    // On choisit des couleurs lisibles selon le contraste WCAG vs le fond.
    function _lin(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    function _lum(c) { return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b) }
    function contrastRatio(a, b) {
        var la = _lum(a) + 0.05, lb = _lum(b) + 0.05
        return la > lb ? la / lb : lb / la
    }
    // Première couleur de la liste qui atteint le contraste mini, sinon la plus contrastée.
    function _pickLegible(list, bg, minC) {
        var best = list[0], bestC = contrastRatio(list[0], bg)
        for (var i = 0; i < list.length; i++) {
            var c = contrastRatio(list[i], bg)
            if (c >= minC) return list[i]   // 1er dans l'ordre de préférence qui ressort
            if (c > bestC) { bestC = c; best = list[i] }
        }
        return best                          // sinon : le plus contrasté dispo
    }

    // Bordure/contour lisible : garde color15 s'il ressort (>=3), sinon couleur vive.
    readonly property color outline: _pickLegible(
        [colors.color15, colors.color13, colors.color11, colors.color12, colors.color14, colors.color6],
        colors.bg, 3.0)

    // Couleur de texte lisible SUR un fond donné `c` (renvoie bg ou fg, le + contrasté).
    // Évite le cas "texte même couleur que son pill" (dark16 fusionne color11/12/13).
    function textOn(c) {
        return contrastRatio(c, colors.bg) >= contrastRatio(c, colors.fg) ? colors.bg : colors.fg
    }

    // Palette vive & lisible (contraste >= 2.6) pour les dégradés animés.
    // Logo de chaque espace de travail (barre, onglet Spaces du tactile)
    readonly property var wsIcons: ({
        1:  "   ",
        2:  "   ",
        3:  "   ",
        4:  "   ",
        5:  "   ",
        6:  "   ",
        7:  " 󰏖  ",
        8:  "   ",
        9:  "   ",
        10: " 10 "
    })
    readonly property string wsDefaultIcon: "   "

    readonly property var legiblePalette: {
        var bg   = colors.bg
        var cand = [colors.color1, colors.color2, colors.color3,  colors.color4,  colors.color5,  colors.color6,
                    colors.color9, colors.color10, colors.color11, colors.color12, colors.color13, colors.color14]
        var out = []
        for (var i = 0; i < cand.length; i++)
            if (contrastRatio(cand[i], bg) >= 2.6) out.push(cand[i])
        if (out.length < 2) out = [colors.color13, colors.color11, colors.color15]
        return out
    }

    // ── UI state ──────────────────────────────────────────────────────────
    // ── Thème ([theme] dans config.toml — Réglages › Apparence › Thème) ──────
    readonly property string accentSlot: String(Config.get("theme.accent", "color11"))
    readonly property bool animationsEnabled: Config.get("theme.animated_borders", true) !== false   // bordures dégradé animées (dashboard + barre)
    readonly property real borderSpeed: Number(Config.get("theme.border_speed", 1))
    // Ouverture des onglets (panneau tactile) : morph · slide · fade · zoom · rise · curtain · none
    // morph = goutte → pilule → déroulé ; les cartes System/Apps s'ouvrent alors en cascade.
    readonly property string pageAnim: String(Config.get("theme.page_anim", "morph"))
    readonly property bool morphPages: pageAnim === "morph"
    readonly property string trayIcons: String(Config.get("theme.tray_icons", "color"))   // icônes de la zone de notification
    property bool   calendarVisible: false
    property real   calPopupX:       0
    property real   calPopupY:       0      // centre vertical du module (barre verticale)
    property real   calPopupW:       0
    property bool   eqVisible:       false
    property var    trayMenuHandle:  null
    property string trayMenuTitle:   ""
    property string trayMenuIcon:    ""
    property real   trayMenuX:       0
    property real   trayMenuY:       0
    property string trayMenuScreen:  ""     // écran (nom) où le menu a été demandé
    property bool   trayMenuOpen:    false

    // ── EQ popup ─────────────────────────────────────────────────────────
    property real   eqPopupX:     0
    property real   eqPopupY:     0
    property real   eqPopupW:     0

    // ── Media player popup ────────────────────────────────────────────────
    property bool   mediaPopupOpen:  false
    property bool   mediaPopupHeld:  false
    property real   mediaPopupX:     0
    property real   mediaPopupY:     0
    property real   mediaPopupWidth: 0
    property string mediaTitle:      ""
    property string mediaArtist:     ""
    property string mediaStatus:     "Stopped"
    property real   mediaPercent:    0
    property string mediaArtPath:    ""

    // ── Bar geometry ──────────────────────────────────────────────────────
    property QtObject bar: QtObject {
        // Réglables dans config.toml ([bar]) — Réglages › Barre › Modules
        property int height:     Config.get("bar.height", 34)
        property int topMargin:  Config.get("bar.top_margin", 3)
        property int sideMargin: Config.get("bar.side_margin", 10)
        property int padding:    5
        property int pillPad:    Config.get("bar.pill_padding", 8)
        property int gap:        Config.get("bar.gap", 5)
        // arrondi borné à la demi-épaisseur : au-delà, la bordure en dégradé déborde (trait parasite)
        readonly property real maxRadius: Math.floor((vertical ? thickness : height) / 2)
        property real radius:    Math.min(Config.get("bar.radius", 16), maxRadius)
        property real bgAlpha:   0.88
        // Position et forme : [bar] position (top · bottom) et style (pills = 3 barres,
        // split = 2 barres, full = 1 barre pleine largeur) — Réglages › Barre › Modules
        readonly property string position: ["top", "bottom", "left", "right"].indexOf(String(Config.get("bar.position", "top"))) >= 0 ? String(Config.get("bar.position", "top")) : "top"
        readonly property bool   atBottom: position === "bottom"
        readonly property bool   vertical: position === "left" || position === "right"
        // Épaisseur d'une barre verticale (largeur), [bar] thickness
        readonly property int    thickness: vertical ? Config.get("bar.thickness", 46) : height
        // Tailles des modules, proportionnelles à la barre (hauteur 34 px, ou largeur 46 px en vertical = 100 %) :
        // un seul réglage (hauteur / épaisseur) fait grandir icônes et textes ensemble.
        readonly property real   k:     vertical ? thickness / 46 : height / 34
        readonly property int    icon:  Math.round(16 * k)
        readonly property int    text:  Math.round((vertical ? 12 : 16) * k)
        readonly property int    small: Math.round((vertical ? 11 : 14) * k)
        readonly property string style: ["pills", "split", "full"].indexOf(String(Config.get("bar.style", "pills"))) >= 0 ? String(Config.get("bar.style", "pills")) : "pills"
        // Distance entre le bord de l'écran et le bord intérieur de la barre
        readonly property real edge: topMargin + thickness
        // y d'une carte de hauteur h qui s'ouvre depuis la barre, dans une fenêtre plein écran de hauteur winH.
        // Barre verticale : la carte s'aligne sur le module (anchorY = centre du module), bornée à l'écran.
        function popupY(winH, h, anchorY) {
            if (vertical) return Math.max(8, Math.min((anchorY ?? winH / 2) - h / 2, winH - h - 8))
            return atBottom ? winH - edge - 6 - h : edge + 5
        }
        // x d'une carte de largeur w (anchorX = centre du module, barre horizontale)
        function popupX(winW, w, anchorX) {
            if (position === "left")  return edge + 6
            if (position === "right") return winW - edge - 6 - w
            return Math.max(8, Math.min(anchorX - w / 2, winW - w - 8))
        }
    }

    // ── Font ──────────────────────────────────────────────────────────────
    property QtObject font: QtObject {
        // Réglables dans config.toml ([fonts])
        property string family: Config.get("fonts.family", "JetBrainsMono Nerd Font, sans-serif")
        property int body:      Config.get("fonts.body", 16)
        property int small:     Config.get("fonts.small", 14)
    }

    // ── Compat Dashboard Brain_Shell ────────────────────────────────────────
    // Anciens tokens "Theme.*" remappés ici. Les couleurs pointent sur la
    // palette wallust (Appearance.colors) → le dashboard suit le même thème
    // que la barre. Les tailles reprennent les valeurs du Theme d'origine.
    property color background: colors.bg
    property color active:     colors.accent
    property color text:       colors.fg
    property color subtext:    colors.dim
    property color icon:       colors.fg
    property color border:     colors.color15
    property color iconFont:   colors.bg

    property color wsBackground: "#20000000"
    property color wsActive:     "#FFFFFF"
    property color wsOccupied:   "#80FFFFFF"
    property color wsEmpty:      "#30FFFFFF"
    property color wsOverlay:    "#CC1e1e2e"
    property color wsUrgent:     "#fa6b94"

    property int borderWidth:            6
    property int cornerRadius:           Config.get("theme.radius", 17)
    property int notchRadius:            15
    property int notchHeight:            40
    property int exclusionGap:           34
    property int spacing:                10
    property int notchPadding:           16
    property int notchHorizontalPadding: 20
    property int notchVerticalPadding:   10
    property int notchSideMargin:        10
    property int lNotchMinWidth:         180
    property int lNotchMaxWidth:         360
    property int cNotchMinWidth:         300
    property int cNotchMaxWidth:         360
    property int rNotchMinWidth:         200
    property int rNotchMaxWidth:         360
    property int dashboardWidth:         Config.get("dashboard.width", 900)
    property int dashboardHeight:        Config.get("dashboard.height", 520)
    property int notificationsWidth:     400
    property int notificationToastWidth: notificationsWidth / 1.2
    property int networkPopupWidth:      480
    property int popupMinWidth:          160
    property int popupMaxWidth:          420
    property int popupMinHeight:         80
    property int popupMaxHeight:         520
    property int popupPadding:           16
    property int wsDotSize:              10
    property int wsActiveWidth:          24
    property int wsSpacing:              6
    property int wsPadding:              8
    property int wsRadius:               16
    // Vitesse des animations ([theme] anim_speed : 1 normale, 0.6 rapide, 0.35 très rapide, 0 aucune).
    // Plafonnée à 1 : les minuteurs de fermeture des panneaux sont calés sur la durée normale.
    readonly property real animSpeed: Math.max(0, Math.min(1, Number(Config.get("theme.anim_speed", 1))))
    function dur(ms) { return Math.round(ms * animSpeed) }
    property int animDuration:           dur(320)

    // ── Spectre multicolore (dégradé cyclique animé, partagé par tous les cava) ─
    property real specPhase: 0
    NumberAnimation on specPhase {
        from: 0; to: 1; duration: 8000
        loops: Animation.Infinite; running: true
    }
    function specColor(t) {
        var c = [colors.cyan, colors.blue, colors.mauve, colors.pink, colors.red, colors.accent]
        var n = c.length
        var x = (((t % 1) + 1) % 1) * n
        var i = Math.floor(x) % n
        var j = (i + 1) % n
        var f = x - Math.floor(x)
        var a = c[i], b = c[j]
        return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, 1)
    }
}
