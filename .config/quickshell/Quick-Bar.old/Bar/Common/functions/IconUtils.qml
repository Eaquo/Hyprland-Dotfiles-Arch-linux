pragma Singleton
import Quickshell

Singleton {
    id: root

    // Populated at startup from the GTK icon theme directory.
    // Any binding that calls resolve() re-evaluates when this changes.
    property var themeIconMap: null

    function resolve(ic, fallback) {
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
