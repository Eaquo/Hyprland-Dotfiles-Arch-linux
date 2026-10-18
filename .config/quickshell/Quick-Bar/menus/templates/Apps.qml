import QtQuick
import "." as T
import Quickshell
import qs.core
import qs.core.functions

// Apps — lanceur d'applications (les .desktop installés), comme rofi -show drun :
// icône au-dessus du nom, la tuile choisie encadrée. Aucune donnée à fournir.
T.Grid {
    id: a
    prefW: 1720
    cols: menu.req.columns > 0 ? menu.req.columns : 5
    rows: 5
    ratio: 0.3
    // liaison : se remplit dès que Quickshell a fini de lire les .desktop
    readonly property var apps: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .map(e => ({ t: e.name, sub: e.genericName || e.comment || "", icon: e.icon, entry: e }))
        .sort((x, y) => x.t.localeCompare(y.t))
    onAppsChanged: menu.extra = apps
    Component.onCompleted: menu.extra = apps
    tile: Component {
        Item {
            property var it: ({ t: "" })
            property bool on: false
            Rectangle {
                anchors.fill: parent; radius: a.menu.rad(height)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: ColorUtils.applyAlpha(Appearance.colors.fg, on ? 0.065 : 0.05) }
                    GradientStop { position: 1.0; color: ColorUtils.applyAlpha(Appearance.colors.fg, on ? 0.03 : 0.012) }
                }
                Rectangle { x: parent.radius; width: parent.width - parent.radius * 2; height: 1; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.1) }
            }
            Column {
                anchors.centerIn: parent
                spacing: 8
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 46; height: 46; sourceSize: Qt.size(96, 96)
                    source: a.menu.iconSrc(it.icon); asynchronous: true
                    scale: on ? 1.15 : 1
                    Behavior on scale { NumberAnimation { duration: Appearance.dur(180); easing.type: Easing.OutBack } }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: a.cw - 40; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                    text: a.menu.mark(it.t, "", on); textFormat: Text.StyledText
                    font.family: Appearance.font.family; font.pixelSize: 15
                    color: on ? a.menu.glow : Appearance.colors.fg
                }
            }
        }
    }
}
