import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../Common/"
import "../Common/functions/"

// ColorPicker — sélecteur de couleur tactile (HSV) en surimpression.
// À poser en dernier enfant de la page (il la recouvre) :
//
//   ColorPicker { id: picker; onPicked: (hex, tag) => … }
//   picker.open("#4f23c1", "color11", "Accent", "color11")
//
// Carré = saturation (x) / luminosité (y), barre = teinte. OK émet picked(hex,
// tag) ; Annuler ou un tap à côté ferme sans rien émettre. `tag` est rendu tel
// quel (pour savoir quelle couleur on éditait).
Item {
    id: picker
    anchors.fill: parent
    visible: opened
    z: 100

    property bool   opened: false
    property string title: ""
    property string subtitle: ""
    property string tag: ""
    property color  original: "black"
    property real h: 0
    property real s: 0
    property real v: 0
    readonly property color value: Qt.hsva(h, s, v, 1)
    signal picked(string hex, string tag)

    function open(color, titleText, subtitleText, tagText) {
        const c = Qt.color(color)
        original = c
        h = Math.max(0, c.hsvHue); s = c.hsvSaturation; v = c.hsvValue
        title = titleText || ""; subtitle = subtitleText || ""; tag = tagText || ""
        opened = true
    }
    function hex(c) {
        const p = x => ("0" + Math.round(x * 255).toString(16)).slice(-2)
        return "#" + p(c.r) + p(c.g) + p(c.b)
    }

    // Fond modal : tap à côté = annuler.
    Rectangle {
        anchors.fill: parent
        color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.6)
        MouseArea { anchors.fill: parent; onClicked: picker.opened = false }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width, 880); height: Math.min(parent.height, 520)
        radius: 22
        color: Appearance.colors.bg
        border.width: 2; border.color: Appearance.colors.accent
        MouseArea { anchors.fill: parent }   // absorbe les taps

        RowLayout {
            anchors.fill: parent; anchors.margins: 22
            spacing: 22

            // Carré saturation (x) / luminosité (y)
            Rectangle {
                id: sv
                Layout.fillHeight: true
                Layout.preferredWidth: height
                radius: 10
                color: Qt.hsva(picker.h, 1, 1, 1)
                Rectangle {
                    anchors.fill: parent; radius: 10
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "white" }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
                Rectangle {
                    anchors.fill: parent; radius: 10
                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 1; color: "black" }
                    }
                }
                Rectangle {   // curseur
                    width: 30; height: 30; radius: 15
                    x: picker.s * sv.width - 15
                    y: (1 - picker.v) * sv.height - 15
                    color: picker.value
                    border.width: 3; border.color: picker.v > 0.5 ? "black" : "white"
                }
                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    function upd(m) {
                        picker.s = Math.max(0, Math.min(1, m.x / width))
                        picker.v = 1 - Math.max(0, Math.min(1, m.y / height))
                    }
                    onPressed: (m) => upd(m)
                    onPositionChanged: (m) => upd(m)
                }
            }

            // Barre de teinte (verticale)
            Rectangle {
                id: hueBar
                Layout.fillHeight: true
                Layout.preferredWidth: 56
                radius: 10
                gradient: Gradient {
                    GradientStop { position: 0/6; color: "#ff0000" }
                    GradientStop { position: 1/6; color: "#ffff00" }
                    GradientStop { position: 2/6; color: "#00ff00" }
                    GradientStop { position: 3/6; color: "#00ffff" }
                    GradientStop { position: 4/6; color: "#0000ff" }
                    GradientStop { position: 5/6; color: "#ff00ff" }
                    GradientStop { position: 6/6; color: "#ff0000" }
                }
                Rectangle {
                    width: parent.width + 10; height: 12; radius: 6
                    x: -5; y: picker.h * hueBar.height - 6
                    color: "transparent"; border.width: 3; border.color: "white"
                }
                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    function upd(m) { picker.h = Math.max(0, Math.min(0.999, m.y / height)) }
                    onPressed: (m) => upd(m)
                    onPositionChanged: (m) => upd(m)
                }
            }

            // Aperçu avant/après + valider
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14
                Text {
                    text: picker.title
                    font.family: Appearance.font.family; font.pixelSize: 24; font.weight: Font.Bold
                    color: Appearance.colors.fg
                }
                Text {
                    Layout.fillWidth: true
                    visible: picker.subtitle !== ""
                    text: picker.subtitle
                    font.family: Appearance.font.family; font.pixelSize: 14
                    color: Appearance.colors.dim
                    wrapMode: Text.WordWrap
                }
                ClippingRectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.2)
                    Column {
                        anchors.fill: parent
                        Rectangle { width: parent.width; height: parent.height / 2; color: picker.value }
                        Rectangle { width: parent.width; height: parent.height / 2; color: picker.original }
                    }
                }
                Text {
                    text: picker.hex(picker.value).toUpperCase() + "   (bas : " + picker.hex(picker.original).toUpperCase() + ")"
                    font.family: Appearance.font.family; font.pixelSize: 16
                    color: Appearance.colors.dim
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Repeater {
                        model: [ { glyph: "󰜺", label: "Annuler", ok: false }, { glyph: "󰄬", label: "OK", ok: true } ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 64; radius: 18
                            color: modelData.ok ? Appearance.colors.accent : ColorUtils.applyAlpha(Appearance.colors.bg, 0.6)
                            border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
                            Row {
                                anchors.centerIn: parent; spacing: 10
                                Text {
                                    text: modelData.glyph; font.family: Appearance.font.family; font.pixelSize: 24
                                    color: modelData.ok ? Appearance.colors.bg : Appearance.colors.fg
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label; font.family: Appearance.font.family; font.pixelSize: 18; font.weight: Font.Bold
                                    color: modelData.ok ? Appearance.colors.bg : Appearance.colors.fg
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (modelData.ok) picker.picked(picker.hex(picker.value), picker.tag)
                                    picker.opened = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
