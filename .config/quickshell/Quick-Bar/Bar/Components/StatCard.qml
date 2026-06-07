import QtQuick
import QtQuick.Effects
import "../Common/"

// Reusable card background. Wrap any stats panel in this for
// a consistent surface across the stats tab and future dashboard panels.
//
// Usage:
//   StatCard {
//       width: ...; height: ...
//       SomeContent { anchors.fill: parent }
//   }
//
// Optionnel : artPath = chemin d'une image → fond jaquette flou + assombri
// (même rendu que le lecteur média), masqué aux coins arrondis.

Item {
    id: root

    default property alias content: inner.data
    property int    padding: 12
    property string artPath: ""

    // Surface de base
    Rectangle {
        anchors.fill: parent
        radius:       Appearance.cornerRadius
        color:        Qt.rgba(1, 1, 1, 0.04)
        border.color: Qt.rgba(1, 1, 1, 0.07)
        border.width: 1
    }

    // ── Fond jaquette optionnel (flou + assombri) ─────────────────────────────
    Item {
        id: bgSource
        anchors.fill:  parent
        opacity:       0
        layer.enabled: true
        visible:       root.artPath !== ""

        Item {
            id: artSource
            anchors.fill:  parent
            layer.enabled: true
            Image {
                anchors.fill: parent
                source:   root.artPath !== "" ? ("file://" + root.artPath) : ""
                fillMode: Image.PreserveAspectCrop
                smooth:   true
            }
        }

        MultiEffect {
            source:       artSource
            anchors.fill: parent
            blurEnabled:  true
            blur:         0.5
            blurMax:      32
            saturation:   0.2
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.38) }
                GradientStop { position: 0.4; color: Qt.rgba(0, 0, 0, 0.50) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.88) }
            }
        }
    }

    Rectangle {
        id: bgMask
        anchors.fill:  parent
        radius:        Appearance.cornerRadius
        visible:       false
        layer.enabled: true
    }

    MultiEffect {
        source:           bgSource
        anchors.fill:     parent
        visible:          root.artPath !== ""
        maskEnabled:      true
        maskSource:       bgMask
        maskThresholdMin: 0.5
        maskSpreadAtMin:  1.0
    }

    Item {
        id: inner
        anchors {
            fill:         parent
            margins:      root.padding
        }
    }
}
