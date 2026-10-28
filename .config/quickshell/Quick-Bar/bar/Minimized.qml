pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.core
import qs.core.functions
import qs.services

// Fenêtres réduites (services/Minimize.qml, remplace niflveil) : caché s'il n'y en a pas ; sinon logo dock
// + nombre, puis une icône par fenêtre. Clic sur une icône : la ramener sur l'espace courant ·
// clic sur le logo ou clic droit : toutes les ramener.
// largeur 0 quand vide : Bar.qml masque alors le module et son séparateur
Item {
    id: root
    readonly property int count: Minimize.windows.length
    visible: count > 0
    implicitWidth: count > 0 ? grid.implicitWidth : 0
    implicitHeight: count > 0 ? grid.implicitHeight : 0

    GridLayout {
        id: grid
        anchors.centerIn: parent
        flow: Appearance.bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 4; columnSpacing: 4

        Item {
            Layout.alignment: Qt.AlignCenter
            implicitWidth: logo.implicitWidth + num.implicitWidth + 3; implicitHeight: logo.implicitHeight
            HoverHandler { id: lhov; cursorShape: Qt.PointingHandCursor }
            TapHandler { acceptedButtons: Qt.LeftButton | Qt.RightButton; onTapped: Minimize.restoreAll() }
            Text {
                id: logo
                text: "󱂩"
                font.family: Appearance.font.family; font.pixelSize: Appearance.bar.icon
                color: lhov.hovered ? Appearance.colors.color13 : Appearance.colors.color11
                Behavior on color { ColorAnimation { duration: Appearance.dur(120) } }
            }
            Text {
                id: num
                anchors { left: logo.right; leftMargin: 3; verticalCenter: logo.verticalCenter }
                text: root.count
                font.pixelSize: Appearance.bar.small
                color: logo.color
            }
        }

        Repeater {
            model: Minimize.windows
            delegate: Item {
                id: win
                required property var modelData
                readonly property string cls: modelData.lastIpcObject?.class ?? modelData.wayland?.appId ?? ""
                Layout.alignment: Qt.AlignCenter
                implicitWidth: Appearance.bar.icon + 6; implicitHeight: Appearance.bar.icon + 6

                Rectangle {
                    anchors.fill: parent; radius: 6
                    color: Appearance.colors.color11
                    opacity: hov.hovered ? 0.22 : 0
                    Behavior on opacity { NumberAnimation { duration: Appearance.dur(120) } }
                }
                IconImage {
                    anchors.centerIn: parent
                    implicitSize: Appearance.bar.icon
                    source: IconUtils.resolve(DesktopEntries.heuristicLookup(win.cls)?.icon ?? win.cls, "application-x-executable", false)
                    opacity: hov.hovered ? 1 : 0.75
                }
                HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                TapHandler { acceptedButtons: Qt.LeftButton; onTapped: Minimize.restore(win.modelData.address) }
                TapHandler { acceptedButtons: Qt.RightButton; onTapped: Minimize.restoreAll() }
            }
        }
    }
}
