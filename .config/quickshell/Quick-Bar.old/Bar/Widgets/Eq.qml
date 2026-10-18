pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../Common/"

Item {
    id: root

    implicitWidth: 38                    // taille normale
    implicitHeight: Appearance.bar.height

    property real hoveredWidth: 72       // ← largeur quand hover

    // Animation fluide
    Behavior on implicitWidth {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    // L'icône reste toujours au centre
    Text {
        id: lbl
        anchors.centerIn: parent          // ← important
        text: " 󰓃 "
        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.body
        color: Appearance.eqVisible ? Appearance.colors.accent : Appearance.colors.dim
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        onEntered: {
            root.implicitWidth = hoveredWidth

            // Mise à jour de la position avec la nouvelle largeur
            var globalPos = root.mapToGlobal(0, 0)
            Appearance.eqPopupX = globalPos.x
            Appearance.eqPopupW = root.implicitWidth

            Appearance.eqVisible = true
        }

        onExited: {
            root.implicitWidth = 38
        }
    }

    // Fond qui apparaît au hover
    Rectangle {
        anchors.fill: parent
        radius: Appearance.bar.radius
        color: root.hovered ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.08) : "transparent"
        z: -1
    }
}