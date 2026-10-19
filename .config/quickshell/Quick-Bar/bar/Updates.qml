pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.core
import qs.services

// Rangée en barre horizontale, colonne en barre verticale ([bar] position)
GridLayout {
    flow: Appearance.bar.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
    id: root
    rowSpacing: 3; columnSpacing: 3

    // données partagées : services/Updates.qml (aussi utilisées par la grille et le menu)
    readonly property int updates: Updates.count
    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
    // clic : le menu « Mises à jour » (liste, tout mettre à jour) · clic droit : mettre à jour tout de suite
    TapHandler { acceptedButtons: Qt.LeftButton; onTapped: Updates.openMenu() }
    TapHandler { acceptedButtons: Qt.RightButton; onTapped: Updates.upgrade() }
    Text {
        Layout.alignment: Qt.AlignCenter
        text: " "
        font.family:    Appearance.font.family
        font.pixelSize: Appearance.bar.icon
        color: root.updates > 0
            ? (hov.hovered ? Appearance.colors.color13 : Appearance.colors.color5)
            : Appearance.colors.dim
        Behavior on color { ColorAnimation { duration: Appearance.dur(120) } }
    }

    Text {
        Layout.alignment: Qt.AlignCenter
        visible: root.updates > 0
        text:    root.updates.toString()
        font.pixelSize: Appearance.bar.small
        color: hov.hovered ? Appearance.colors.color13 : Appearance.colors.color5
        Behavior on color { ColorAnimation { duration: Appearance.dur(120) } }
    }
}
