import QtQuick
import QtQuick.Effects
import qs.core
import qs.core.functions

// Confirm — une question (MESSAGE / TITLE) et des boutons (les items ; Oui / Non par défaut).
Item {
    id: t
    required property var menu
    property real prefW: 560
    readonly property real contentH: 80
    property int cols: 1
    property bool horizontal: true
    property bool filter: false
    property bool search: false
    property string hints: "←→ choisir  ·  entrée valider"
    Component.onCompleted: if (!(menu.req.items || []).length) menu.extra = [{ t: "Oui", glyph: "󰄬" }, { t: "Non", glyph: "󰅖" }]

    Row {
        anchors.centerIn: parent
        spacing: 14
        Repeater {
            model: t.menu.items
            delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool on: index === t.menu.cur
                width: Math.max(150, bl.implicitWidth + 48); height: 58; radius: t.menu.rad(height)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: ColorUtils.applyAlpha(Appearance.colors.fg, parent.on ? 0.1 : 0.05) }
                    GradientStop { position: 1.0; color: ColorUtils.applyAlpha(Appearance.colors.fg, parent.on ? 0.03 : 0.012) }
                }
                border.width: on ? 2 : 1; border.color: on ? ColorUtils.applyAlpha(t.menu.glow, 0.7) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
                scale: on ? 1.06 : 1
                Behavior on scale { NumberAnimation { duration: Appearance.dur(180); easing.type: Easing.OutBack } }
                Text { id: bl; anchors.centerIn: parent; text: (parent.modelData.glyph ? parent.modelData.glyph + "  " : "") + parent.modelData.t
                       font.family: Appearance.font.family; font.pixelSize: 17; font.weight: Font.DemiBold
                       color: parent.on ? t.menu.glow : Appearance.colors.fg }
                MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onEntered: if (t.menu.hoverReady) t.menu.cur = parent.index; onClicked: t.menu.choose(parent.index) }
            }
        }
    }
}
