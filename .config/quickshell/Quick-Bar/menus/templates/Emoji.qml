import QtQuick
import "." as T
import qs.core
import qs.core.functions

// Emoji — grille dense : le premier mot de chaque ligne est affiché en grand, le reste sert à chercher.
// Le nom de l'emoji choisi s'affiche en bas.
T.Grid {
    id: e
    prefW: 900
    cols: 12
    rows: 6
    ratio: 1
    hints: (menu.items[menu.cur] ? menu.items[menu.cur].t.split(" ").slice(1).join(" ") + "  ·  " : "") + "entrée copier"
    tile: Component {
        Item {
            property var it: ({ t: "" })
            property bool on: false
            Rectangle {
                anchors.fill: parent; radius: menu.rad(height)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: ColorUtils.applyAlpha(Appearance.colors.fg, on ? 0.065 : 0.05) }
                    GradientStop { position: 1.0; color: ColorUtils.applyAlpha(Appearance.colors.fg, on ? 0.03 : 0.012) }
                }
            }
            Text { anchors.centerIn: parent; text: it.t.split(" ")[0]; font.pixelSize: on ? 40 : 32
                   Behavior on font.pixelSize { NumberAnimation { duration: Appearance.dur(140) } } }
        }
    }
}
