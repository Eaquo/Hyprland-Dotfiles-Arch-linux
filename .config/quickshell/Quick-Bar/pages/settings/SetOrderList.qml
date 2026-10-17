import QtQuick
import QtQuick.Layouts
import qs.core
import qs.core.functions

// SetOrderList — liste d'éléments à réordonner (flèches) et activer (interrupteur).
// items = [{ key, icon, label, on, locked? }] ; edited(list) renvoie la liste complète modifiée.
ColumnLayout {
    id: ol
    property var items: []
    signal edited(var list)
    spacing: 6

    function _move(i, d) {
        const l = items.slice(), j = i + d
        if (j < 0 || j >= l.length) return
        const t = l[i]; l[i] = l[j]; l[j] = t
        edited(l)
    }
    function _toggle(i) {
        const l = items.map(t => Object.assign({}, t))
        l[i].on = !l[i].on
        if (!l.some(t => t.on)) return          // garde au moins un élément actif
        edited(l)
    }

    Repeater {
        model: ol.items
        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            Layout.fillWidth: true
            implicitHeight: 44; radius: 10
            color: ColorUtils.applyAlpha(Appearance.colors.fg, row.modelData.on ? 0.05 : 0.02)
            border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
            opacity: row.modelData.on ? 1 : 0.55
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                spacing: 10
                Text { text: (row.index + 1) + "."; font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim
                       Layout.preferredWidth: 22 }
                Text { text: row.modelData.icon || ""; font.family: Appearance.font.family; font.pixelSize: 16; color: Appearance.colors.accent }
                Text { Layout.fillWidth: true; text: row.modelData.label; elide: Text.ElideRight
                       font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 1; color: Appearance.colors.fg }
                Text { visible: !!row.modelData.note; text: row.modelData.note || ""
                       font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 4; color: Appearance.colors.dim }
                Arrow { glyph: "󰁝"; enabled: row.index > 0; onTap: ol._move(row.index, -1) }
                Arrow { glyph: "󰁅"; enabled: row.index < ol.items.length - 1; onTap: ol._move(row.index, 1) }
                SetSwitch { on: row.modelData.on; visible: !row.modelData.locked; onToggled: ol._toggle(row.index) }
            }
        }
    }

    component Arrow: Rectangle {
        id: ar
        property string glyph: ""
        signal tap()
        implicitWidth: 30; implicitHeight: 30; radius: 8
        opacity: enabled ? 1 : 0.25
        color: arMa.containsMouse && enabled ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.12) : "transparent"
        Text { anchors.centerIn: parent; text: ar.glyph; font.family: Appearance.font.family; font.pixelSize: 15; color: Appearance.colors.fg }
        MouseArea { id: arMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (ar.enabled) ar.tap() }
    }
}
