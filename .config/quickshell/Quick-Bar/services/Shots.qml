pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Shots — nouvelle capture d'écran → vignette flottante (panels/ShotThumb.qml). Surveille les dossiers de
// captures par inotify (aucun sondage) : ~/Pictures/Screenshots (ScreenShot.sh, SUPER+F12, mode jeu). [capture] thumbnail = false pour couper.
Singleton {
    id: root
    property string latest: ""            // capture affichée ("" = aucune)
    property bool hovered: false           // survol : la vignette reste
    readonly property int holdMs: 7000

    Process {
        running: Config.get("capture.thumbnail", true) !== false
        // un seul dossier si les deux chemins sont le même (dossiers XDG en anglais : ~/Pictures) — sinon double annonce
        command: ["sh", "-c", 'a="$HOME/Pictures/Screenshots"; b="$(xdg-user-dir PICTURES)/Screenshots"; mkdir -p "$a" "$b"; '
                + '[ "$(readlink -f "$a")" = "$(readlink -f "$b")" ] && set -- "$a" || set -- "$a" "$b"; '
                + 'exec setpriv --pdeathsig TERM inotifywait -m -q -e close_write -e moved_to --format "%w%f" "$@"']
        stdout: SplitParser {
            onRead: (line) => {
                if (!/\.(png|jpe?g|webp)$/i.test(line)) return
                root.latest = line
                hide.restart()
                Island.show({ title: "Capture enregistrée", sub: line.split("/").pop(), image: line, glyph: "󰄀", ms: 2600 })
            }
        }
    }
    Timer { id: hide; interval: root.holdMs; onTriggered: if (root.hovered) restart(); else root.latest = "" }
    function close() { hide.stop(); latest = "" }
}
