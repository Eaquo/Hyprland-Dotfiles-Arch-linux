pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.services

// Rangée en barre horizontale, colonne en barre verticale ([bar] position)
GridLayout {
    flow: Appearance.bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    id: root
    rowSpacing: 3; columnSpacing: 3

    // données : le démon de notifications de Quick-Bar (services/NotificationService.qml)
    readonly property int  count: NotificationService.count
    readonly property bool dnd:   ShellState.dnd

    Text {
        Layout.alignment: Qt.AlignCenter
        text: root.dnd       ? " 󰂛 "
            : root.count > 0 ? " 󰂚 "
            :                  " 󰂜 "
        font.family: Appearance.font.family
        font.pixelSize: Appearance.bar.icon
        color: root.count > 0 ? Appearance.colors.color10
             : root.dnd       ? Appearance.colors.color11
             :                  Appearance.colors.color12

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            // clic : le centre de notifications · clic droit : ne pas déranger
            onClicked: (m) => {
                if (m.button === Qt.RightButton) { ShellState.dnd = !ShellState.dnd; return }
                if (!Popups.notifCenterOpen) Popups.closeAll()
                Popups.notifCenterOpen = !Popups.notifCenterOpen
            }
        }
    }

    Text {
        Layout.alignment: Qt.AlignCenter
        visible: root.count > 0
        text: root.count.toString()
        font.pixelSize: Appearance.bar.small
        color: Appearance.colors.color10
    }
}
