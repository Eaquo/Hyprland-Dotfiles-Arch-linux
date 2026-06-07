pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ── Color file ────────────────────────────────────────────────────────
    FileView {
        id: walFile
        path: "file://" + Quickshell.env("HOME") + "/.cache/wal/wal.json"
        watchChanges: true
        onFileChanged: walFile.reload()
        onLoaded: root._parse(walFile.text())
    }

    Component.onCompleted: walFile.reload()

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
            console.log("[Wallust] loaded:", _special.background)
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
        property color accent:  _palette.color11 || "#ffe066"
        property color dim:     _palette.color8  || "#4a4a4a"
        property color surface: _palette.color0  || "#0f0f0f"
        property color hi:      _palette.color11 || "#ffe066"
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

    // ── UI state ──────────────────────────────────────────────────────────
    property bool   calendarVisible: false
    property real   calPopupX:       0
    property real   calPopupW:       0
    property bool   eqVisible:       false
    property var    trayMenuHandle:  null
    property string trayMenuTitle:   ""
    property string trayMenuIcon:    ""
    property real   trayMenuX:       0
    property bool   trayMenuOpen:    false

    // ── EQ popup ─────────────────────────────────────────────────────────
    property real   eqPopupX:     0
    property real   eqPopupW:     0

    // ── Media player popup ────────────────────────────────────────────────
    property bool   mediaPopupOpen:  false
    property bool   mediaPopupHeld:  false
    property real   mediaPopupX:     0
    property real   mediaPopupWidth: 0
    property real   rightPillX:      0
    property real   rightPillW:      0
    property string mediaTitle:      ""
    property string mediaArtist:     ""
    property string mediaStatus:     "Stopped"
    property real   mediaPercent:    0
    property string mediaArtPath:    ""

    // ── Bar geometry ──────────────────────────────────────────────────────
    property QtObject bar: QtObject {
        property int height:     34
        property int topMargin:  3
        property int sideMargin: 10
        property int padding:    5
        property int pillPad:    8
        property int gap:        5
        property real radius:    16
        property real bgAlpha:   0.88
    }

    // ── Font ──────────────────────────────────────────────────────────────
    property QtObject font: QtObject {
        property string family: "JetBrainsMono Nerd Font, sans-serif"
        property int body:      16
        property int small:     14
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
    property int cornerRadius:           17
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
    property int dashboardWidth:         900
    property int dashboardHeight:        520
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
    property int animDuration:           320

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
