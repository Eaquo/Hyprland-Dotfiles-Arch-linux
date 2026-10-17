import QtQuick
import qs.core
import qs.core.functions

// SetSeg — choix exclusif : options = [[valeur, libellé], …], current = valeur active.
Row {
    id: seg
    property var options: []
    property var current
    signal picked(var v)
    spacing: 4
    Repeater {
        model: seg.options
        delegate: Rectangle {
            required property var modelData
            readonly property bool on: modelData[0] === seg.current
            width: lbl.implicitWidth + 24; height: 30; radius: 9
            color: on ? Appearance.colors.fg : ColorUtils.applyAlpha(Appearance.colors.fg, 0.06)
            Behavior on color { ColorAnimation { duration: Appearance.dur(180) } }
            Text {
                id: lbl
                anchors.centerIn: parent
                text: parent.modelData[1]
                font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 1
                color: parent.on ? Appearance.colors.bg : Appearance.colors.fg
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: seg.picked(parent.modelData[0]) }
        }
    }
}
