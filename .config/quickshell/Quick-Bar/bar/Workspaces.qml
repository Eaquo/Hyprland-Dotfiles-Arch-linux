pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.core
import qs.core.functions

// Rangée en barre horizontale, colonne en barre verticale ([bar] position)
GridLayout {
    flow: Appearance.bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    id: root
    rowSpacing: 8; columnSpacing: 8

    property int activeId:    1
    property var visibleIds:  []

    readonly property var wsIcons: ({
        1:  "   ",
        2:  "   ",
        3:  "   ",
        4:  "   ",
        5:  "   ",
        6:  "   ",
        7:  " 󰏖  ",
        8:  "   ",
        9:  "   ",
        10: " 10 "
    })
    readonly property string defaultIcon: "   "

    function update() {
        var active = Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1
        var ids = {}
        // include all existing workspaces (1-10)
        var ws = Hyprland.workspaces.values
        for (var i = 0; i < ws.length; i++) {
            var id = ws[i].id
            if (id >= 1 && id <= 10) ids[id] = true
        }
        // active workspace always visible even if empty
        if (active >= 1 && active <= 10) ids[active] = true
        // build sorted array
        var arr = []
        for (var n = 1; n <= 10; n++) {
            if (ids[n]) arr.push(n)
        }
        root.activeId   = active
        root.visibleIds = arr
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) { root.update() }
    }

    Component.onCompleted: root.update()

    Repeater {
        model: root.visibleIds

        Rectangle {
            id: wsBtn
            Layout.alignment: Qt.AlignCenter
            required property int modelData
            property bool   isActive:  root.activeId === wsBtn.modelData
            property bool   isHovered: false
            property string wsIcon:    root.wsIcons[wsBtn.modelData] || root.defaultIcon

            // barre verticale : bouton de la largeur de la barre, numéro au-dessus de l'icône
            implicitHeight: Appearance.bar.vertical ? wsLabel.implicitHeight + (wsBtn.isActive ? 10 : 6) : Appearance.bar.height - 8
            implicitWidth:  Appearance.bar.vertical ? Appearance.bar.thickness - 10 : wsLabel.implicitWidth + (wsBtn.isActive ? 8 : 4)
            radius: 9

            color: wsBtn.isActive
                ? Appearance.colors.accent
                : wsBtn.isHovered
                    ? ColorUtils.applyAlpha(Appearance.colors.color8, 0.60)
                    : "transparent"

            Text {
                id: wsLabel
                anchors.centerIn: parent
                text: Appearance.bar.vertical ? wsBtn.modelData + "\n" + wsBtn.wsIcon : " " + wsBtn.modelData + " " + wsBtn.wsIcon + " "
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Appearance.bar.small
                font.family:    Appearance.font.family
                color: wsBtn.isActive
                    ? Appearance.textOn(Appearance.colors.accent)   // contraste garanti sur le pill actif
                    : wsBtn.isHovered
                        ? Appearance.colors.color13
                        : ColorUtils.applyAlpha(Appearance.colors.color15, 0.80)

                Behavior on color { ColorAnimation { duration: Appearance.dur(120) } }
            }

            Behavior on implicitWidth  { NumberAnimation { duration: Appearance.dur(200); easing.type: Easing.OutCubic } }
            Behavior on implicitHeight { NumberAnimation { duration: Appearance.dur(200); easing.type: Easing.OutCubic } }
            Behavior on color         { ColorAnimation  { duration: Appearance.dur(150) } }

            MouseArea {
                anchors.fill: parent
                cursorShape:  Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: wsBtn.isHovered = true
                onExited:  wsBtn.isHovered = false
                onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsBtn.modelData + " })")
                onWheel: (ev) => {
                    if (ev.angleDelta.y > 0) Hyprland.dispatch("workspace e+1")
                    else                     Hyprland.dispatch("workspace e-1")
                }
            }
        }
    }
}
