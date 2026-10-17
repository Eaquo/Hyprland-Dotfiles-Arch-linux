pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Populated at startup from the GTK icon theme directory.
    // Any binding that calls resolve() re-evaluates when this changes.
    property var themeIconMap: null
    // Relit le thème d'icônes GTK (après un changement dans Réglages › Thème)
    function reload() { iconCacheProc.buf = []; iconCacheProc.running = false; iconCacheProc.running = true }

    // Builds a name→path cache from the GTK icon theme directory.
    // Assigns themeIconMap once when done to trigger reactivity.
    property var _cache: Process {
        id: iconCacheProc
        running: true

        property var buf: []

        command: ["sh", "-c",
            "for f in \"$HOME/.config/gtk-4.0/settings.ini\" \"$HOME/.config/gtk-3.0/settings.ini\"; do " +
            "  [ -f \"$f\" ] && v=$(grep -m1 'gtk-icon-theme-name' \"$f\" | cut -d= -f2 | tr -d ' \\r'); " +
            "  [ -n \"$v\" ] && theme=\"$v\" && break; " +
            "done; " +
            "[ -z \"$theme\" ] && exit 0; " +
            "for base in \"$HOME/.local/share/icons/$theme\" \"/usr/share/icons/$theme\"; do " +
            "  [ -d \"$base\" ] && td=\"$base\" && break; " +
            "done; " +
            "[ -z \"$td\" ] && exit 0; " +
            // Emit name=path lines, lower-priority sizes first (last wins in QML)
            "for s in 16 22 24 32; do " +
            "  for c in status actions devices places apps; do " +
            "    d=\"$td/$c/$s\"; [ -d \"$d\" ] || continue; " +
            "    for f in \"$d\"/*.svg \"$d\"/*.png; do " +
            "      [ -f \"$f\" ] || continue; n=\"${f##*/}\"; echo \"${n%.*}=$f\"; " +
            "    done; " +
            "  done; " +
            "done; " +
            // apps/48 last = highest priority (overwrites smaller sizes)
            "d=\"$td/apps/48\"; [ -d \"$d\" ] || exit 0; " +
            "for f in \"$d\"/*.svg \"$d\"/*.png; do " +
            "  [ -f \"$f\" ] || continue; n=\"${f##*/}\"; echo \"${n%.*}=$f\"; " +
            "done"
        ]

        stdout: SplitParser {
            onRead: data => iconCacheProc.buf.push(data)
        }

        onRunningChanged: {
            if (running) return
            var map = {}
            for (var i = 0; i < buf.length; i++) {
                var line = buf[i].trim()
                var eq = line.indexOf('=')
                if (eq > 0) map[line.substring(0, eq)] = line.substring(eq + 1)
            }
            root.themeIconMap = map
        }
    }

    // symbolic = préférer les variantes monochromes du thème (-symbolic, -panel, _tray_mono)
    function resolve(ic, fallback, symbolic) {
        if (!ic) return fallback || ""

        var fb = fallback || "application-x-executable"
        var map = root.themeIconMap  // reactive: re-runs binding when map loads

        // Direct file/resource path — use as-is
        if (ic.startsWith("/") || ic.startsWith("file:") || ic.startsWith("qrc:"))
            return ic

        // Quickshell's image://icon/name?path=... — extract the icon name
        var name = ic
        if (ic.startsWith("image://icon/"))
            name = ic.substring("image://icon/".length).split("?")[0]

        // Build colorful alternatives to try before the raw name
        var candidates = []
        if (symbolic) {
            var base = name.replace(/(_tray_mono|_tray|_mono|-indicator)$/, "")
            candidates.push(base + "-symbolic", base + "-panel", name + "-symbolic", base + "_tray_mono", name)
        }
        if (name.match(/_tray_mono$/))
            candidates.push(name.replace(/_tray_mono$/, ""))
        if (name.match(/_tray$/) && !name.match(/_tray_mono$/))
            candidates.push(name.replace(/_tray$/, ""))
        if (name.match(/_mono$/) && !name.match(/_tray_mono$/))
            candidates.push(name.replace(/_mono$/, ""))
        if (name.match(/-linux-\d+$/)) {
            candidates.push(name.replace(/-linux-\d+$/, "-client"))
            candidates.push(name.replace(/-linux-\d+$/, ""))
        }
        if (name.match(/-indicator$/))
            candidates.push(name.replace(/-indicator$/, ""))
        candidates.push(name)

        // GTK theme map: direct file paths, no Qt theme system involved
        if (map) {
            for (var i = 0; i < candidates.length; i++) {
                var c = candidates[i]
                if (c && map[c]) return "file://" + map[c]
            }
        }

        // Fallback: Qt icon theme (Tokyonight-Dark or whatever qt6ct has)
        for (var j = 0; j < candidates.length; j++) {
            var alt = candidates[j]
            if (alt && Quickshell.hasThemeIcon(alt))
                return Quickshell.iconPath(alt, fb)
        }

        return ic.startsWith("image://") ? ic : Quickshell.iconPath(name, fb)
    }
}
