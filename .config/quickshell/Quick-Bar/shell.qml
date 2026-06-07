//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

import "./Bar/Common/"
import "./Bar/Common/functions/"
import "./Bar/Widgets/"
import "./Bar/Windows/"


import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Io

ShellRoot {
    Bar {}
    CalendarWindow {}
    EqPopup {}
    SysTrayPopup {}
    MediaPlayerPopup {}
    Dashboard {}

    // Builds a name→path cache from the GTK icon theme directory.
    // Assigns IconUtils.themeIconMap once when done to trigger reactivity.
    Process {
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
            IconUtils.themeIconMap = map
        }
    }
}
