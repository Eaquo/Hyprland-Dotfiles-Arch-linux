import QtQuick
import qs.core
import qs.core.functions

// SetSwitch — interrupteur à ressort (même style que le reste de Quick-Bar).
Rectangle {
    id: sw
    property bool on: false
    signal toggled()
    implicitWidth: 46; implicitHeight: 26; radius: 13
    color: on ? Appearance.colors.accent : ColorUtils.applyAlpha(Appearance.colors.fg, 0.18)
    Behavior on color { ColorAnimation { duration: Appearance.dur(200) } }
    Rectangle {
        width: ma.pressed ? 26 : 20; height: 20; radius: 10; y: 3
        x: sw.on ? parent.width - width - 3 : 3
        color: "#ffffff"
        Behavior on x { SpringAnimation { spring: 5; damping: 0.3; epsilon: 0.25 } }
        Behavior on width { NumberAnimation { duration: Appearance.dur(120) } }
    }
    MouseArea { id: ma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled() }
}
