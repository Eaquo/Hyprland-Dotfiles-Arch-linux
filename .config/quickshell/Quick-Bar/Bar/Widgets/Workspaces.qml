pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "../Common/"
import "../Common/functions/"

RowLayout {
    id: root
    spacing: 8

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
            required property int modelData
            property bool   isActive:  root.activeId === wsBtn.modelData
            property bool   isHovered: false
            property string wsIcon:    root.wsIcons[wsBtn.modelData] || root.defaultIcon

            implicitHeight: Appearance.bar.height - 8
            implicitWidth:  wsLabel.implicitWidth + (wsBtn.isActive ? 8 : 4)
            radius: 9

            color: wsBtn.isActive
                ? Appearance.colors.accent
                : wsBtn.isHovered
                    ? ColorUtils.applyAlpha(Appearance.colors.color8, 0.60)
                    : "transparent"

            Text {
                id: wsLabel
                anchors.centerIn: parent
                text: " " + wsBtn.modelData + " " + wsBtn.wsIcon + " "
                font.pixelSize: Appearance.font.small
                font.family:    Appearance.font.family
                color: wsBtn.isActive
                    ? Appearance.colors.color13
                    : wsBtn.isHovered
                        ? Appearance.colors.color13
                        : ColorUtils.applyAlpha(Appearance.colors.color15, 0.80)

                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on color         { ColorAnimation  { duration: 150 } }

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
