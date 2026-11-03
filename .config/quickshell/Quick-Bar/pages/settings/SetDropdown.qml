import QtQuick
import qs.core
import qs.core.functions

// SetDropdown — liste déroulante : options = [[valeur, libellé], …], current = valeur active, busy = « … » à droite.
// Se déroule sur place (pousse le contenu dessous) : rien ne déborde de la carte ni de la page qui défile.
Column {
    id: dd
    property var options: []
    property var current
    property bool busy: false
    property bool open: false
    property real u: 1                    // échelle (onglet Wall du panneau tactile : root.u)
    signal picked(var v)
    width: 260
    spacing: 4
    readonly property string currentLabel: (options.find(o => o[0] === current) || ["", "—"])[1]

    Rectangle {
        width: parent.width; height: 34 * dd.u; radius: 9 * dd.u
        color: ColorUtils.applyAlpha(Appearance.colors.fg, hdMa.containsMouse || dd.open ? 0.1 : 0.05)
        border.width: 1; border.color: ColorUtils.applyAlpha(dd.open ? Appearance.colors.accent : Appearance.colors.fg, dd.open ? 0.6 : 0.1)
        Behavior on color { ColorAnimation { duration: Appearance.dur(150) } }
        Text {
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter; right: chev.left; rightMargin: 8 }
            text: dd.currentLabel + (dd.busy ? "  …" : ""); elide: Text.ElideRight
            font.family: Appearance.font.family; font.pixelSize: (Appearance.font.small - 1) * dd.u; color: Appearance.colors.fg
        }
        Text {
            id: chev
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            text: "󰅀"; rotation: dd.open ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: Appearance.dur(200); easing.type: Easing.OutCubic } }
            font.family: Appearance.font.family; font.pixelSize: Appearance.font.small * dd.u; color: Appearance.colors.dim
        }
        MouseArea { id: hdMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dd.open = !dd.open }
    }

    Rectangle {
        width: parent.width
        height: dd.open ? list.implicitHeight + 8 : 0
        visible: height > 0
        clip: true
        radius: 9
        color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.04)
        border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
        Behavior on height { NumberAnimation { duration: Appearance.dur(220); easing.type: Easing.OutCubic } }
        Column {
            id: list
            x: 4; y: 4; width: parent.width - 8
            Repeater {
                model: dd.options
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: modelData[0] === dd.current
                    width: list.width; height: 30 * dd.u; radius: 7 * dd.u
                    color: on ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.3)
                              : ColorUtils.applyAlpha(Appearance.colors.fg, itMa.containsMouse ? 0.08 : 0)
                    Text {
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        text: parent.modelData[1]
                        font.family: Appearance.font.family; font.pixelSize: (Appearance.font.small - 1) * dd.u; color: Appearance.colors.fg
                    }
                    Text {
                        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                        visible: parent.on; text: "󰄬"
                        font.family: Appearance.font.family; font.pixelSize: Appearance.font.small * dd.u; color: Appearance.colors.accent
                    }
                    MouseArea { id: itMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onWheel: (w) => w.accepted = false
                                onClicked: { dd.open = false; dd.picked(parent.modelData[0]) } }
                }
            }
        }
    }
}
