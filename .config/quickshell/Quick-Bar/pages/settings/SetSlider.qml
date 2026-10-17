import QtQuick
import qs.core
import qs.core.functions

// SetSlider — curseur avec valeur affichée ; `moved(v)` à chaque déplacement (valeur arrondie au pas).
Item {
    id: sl
    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 1
    property string suffix: ""
    property int decimals: 0
    signal moved(real v)
    implicitWidth: 300; implicitHeight: 30
    readonly property real frac: Math.max(0, Math.min(1, (value - from) / (to - from)))
    Text {
        id: val
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        width: 64; horizontalAlignment: Text.AlignRight
        text: sl.value.toFixed(sl.decimals).replace(".", ",") + sl.suffix
        font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 1
        color: Appearance.colors.accent
    }
    Item {
        id: track
        anchors { left: parent.left; right: val.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
        height: 26
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.12)
            Rectangle { width: Math.max(6, parent.width * sl.frac); height: 6; radius: 3; color: Appearance.colors.accent } }
        Rectangle {
            width: ma.pressed ? 22 : 18; height: width; radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: track.width * sl.frac - width / 2
            color: "#ffffff"
            Behavior on width { NumberAnimation { duration: Appearance.dur(160); easing.type: Easing.OutBack } }
        }
        MouseArea {
            id: ma
            anchors.fill: parent; anchors.margins: -6
            preventStealing: true; cursorShape: Qt.PointingHandCursor
            function upd(mx) {
                const f = Math.max(0, Math.min(1, (mx - 6) / track.width))
                const v = Math.round((sl.from + f * (sl.to - sl.from)) / sl.step) * sl.step
                sl.moved(Number(v.toFixed(4)))
            }
            onPressed: (e) => upd(e.x)
            onPositionChanged: (e) => { if (pressed) upd(e.x) }
        }
    }
}
