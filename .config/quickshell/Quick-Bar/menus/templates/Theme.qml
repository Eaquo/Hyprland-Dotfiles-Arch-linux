import QtQuick
import "." as T
import Quickshell.Widgets
import qs.core
import qs.core.functions

// Theme — cartes de thème : aperçu (icon = image) et/ou bande de couleurs (métadonnée colors="#a,#b,…").
T.Grid {
    prefW: 1100
    cols: menu.req.columns > 0 ? menu.req.columns : 4
    rows: 2
    ratio: 0.72
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
            readonly property var sw: (it.colors || "").split(",").filter(c => c !== "")
            ClippingRectangle {
                width: parent.width; height: parent.height - 28
                radius: menu.rad(height)
                color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.06)
                Image { anchors.fill: parent; visible: !!it.icon; source: menu.iconSrc(it.icon); fillMode: Image.PreserveAspectCrop
                        asynchronous: true; sourceSize: Qt.size(480, 360) }
                Row {
                    anchors.bottom: parent.bottom
                    width: parent.width; height: it.icon ? 22 : parent.height
                    Repeater {
                        model: sw
                        Rectangle { required property string modelData; width: parent.width / Math.max(1, sw.length); height: parent.height; color: modelData }
                    }
                }
                Text { anchors.centerIn: parent; visible: !it.icon && !sw.length; text: it.glyph || "󰏘"
                       font.family: Appearance.font.family; font.pixelSize: 44; color: Appearance.colors.fg }
            }
            Text {
                anchors.bottom: parent.bottom
                width: parent.width; horizontalAlignment: Text.AlignHCenter
                text: it.t; elide: Text.ElideRight
                font.family: Appearance.font.family; font.pixelSize: 14; font.weight: on ? Font.DemiBold : Font.Normal
                color: on ? Appearance.colors.fg : Appearance.colors.dim
            }
        }
    }
}
