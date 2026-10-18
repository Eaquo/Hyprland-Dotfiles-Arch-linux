pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.DBusMenu
import Quickshell.Wayland
import "../Common/"
import "../Common/functions/"

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: menuWin
            required property var modelData
            screen: modelData

            visible: Appearance.trayMenuOpen
            WlrLayershell.namespace: "quickshell:traymenu"
            WlrLayershell.layer:     WlrLayer.Overlay
            exclusiveZone: -1
            anchors { top: true; left: true; right: true; bottom: true }
            color: "transparent"

            QsMenuOpener {
                id: opener
                menu: Appearance.trayMenuHandle
            }

            Timer {
                id: closeTimer
                interval: 80
                repeat: false
                onTriggered: Appearance.trayMenuOpen = false
            }

            // Click outside → ferme (même pattern que EqPopup/CalendarWindow)
            MouseArea {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                y: Appearance.bar.topMargin + Appearance.bar.height
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: Appearance.trayMenuOpen = false
            }

            // ── Card ──────────────────────────────────────────────────
            Rectangle {
                id: card

                readonly property real preferredX: Appearance.trayMenuX - width / 2
                x: Math.max(8, Math.min(preferredX, menuWin.width - width - 8))
                y: Appearance.bar.topMargin + Appearance.bar.height + 6

                implicitWidth:  Math.max(230, cardCol.implicitWidth + 28)
                implicitHeight: cardCol.implicitHeight + 16

                radius: 16
                color: "transparent"

                opacity: Appearance.trayMenuOpen ? 1.0 : 0.0
                scale:   Appearance.trayMenuOpen ? 1.0 : 0.94
                transformOrigin: Item.Top
                Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on scale   { NumberAnimation { duration: 180; easing.type: Easing.OutExpo  } }

                // ── HoverHandler — ne touche JAMAIS aux clics ─────────
                HoverHandler {
                    onHoveredChanged: {
                        if (hovered) closeTimer.stop()
                        else         closeTimer.restart()
                    }
                }

                // ── Bloque les clics du fond sans casser les items ────
                // Déclaré AVANT le contenu → sous les items en z-order
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    hoverEnabled: false
                    onClicked: (ev) => ev.accepted = true   // absorbe sans fermer
                }

                // 1. Glow
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 20
                    height: parent.height + 20
                    radius: parent.radius + 10
                    color: "transparent"
                    border.color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.08)
                    border.width: 8
                }

                // 2. Background
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.92)
                    border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
                    border.width: 1

                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        anchors { topMargin: 1; leftMargin: 1; rightMargin: 1 }
                        height: parent.radius
                        radius: parent.radius
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.06) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }
                }

                // 3. Contenu — déclaré APRÈS le MouseArea de blocage
                //    donc au-dessus → reçoit les clics en priorité
                ColumnLayout {
                    id: cardCol
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    anchors { topMargin: 10; leftMargin: 6; rightMargin: 6; bottomMargin: 6 }
                    spacing: 1

                    // ── Header ────────────────────────────────────────
                    RowLayout {
                        spacing: 10
                        Layout.leftMargin:   6
                        Layout.rightMargin:  6
                        Layout.bottomMargin: 6
                        Layout.topMargin:    2

                        Rectangle {
                            visible: Appearance.trayMenuIcon !== ""
                            width: 28; height: 28; radius: 8
                            color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.12)
                            Image {
                                anchors.centerIn: parent
                                width: 16; height: 16
                                source: {
                                    var ic = Appearance.trayMenuIcon
                                    if (ic === "") return ""
                                    if (ic.startsWith("/") || ic.startsWith("file://") || ic.startsWith("image://")) return ic
                                    return "image://icon/" + ic
                                }
                                fillMode:   Image.PreserveAspectFit
                                sourceSize: Qt.size(32, 32)
                                smooth: true; mipmap: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text:  Appearance.trayMenuTitle
                                font.family:    Appearance.font.family
                                font.pixelSize: Appearance.font.body - 1
                                font.weight:    Font.DemiBold
                                color:          Appearance.colors.fg
                                elide: Text.ElideRight
                            }
                            Text {
                                visible: text !== ""
                                text: "Application"
                                font.family:    Appearance.font.family
                                font.pixelSize: Appearance.font.small - 2
                                color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.40)
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin:   4
                        Layout.rightMargin:  4
                        Layout.bottomMargin: 4
                        height: 1
                        color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.07)
                    }

                    // ── Items ─────────────────────────────────────────
                    Repeater {
                        model: opener.children

                        Item {
                            id: entry
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: entry.modelData.isSeparator ? 13 : 36

                            RowLayout {
                                visible: entry.modelData.isSeparator
                                anchors {
                                    verticalCenter: parent.verticalCenter
                                    left: parent.left; right: parent.right
                                    leftMargin: 10; rightMargin: 10
                                }
                                spacing: 8
                                Rectangle {
                                    Layout.fillWidth: true; height: 1
                                    color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.07)
                                }
                            }

                            Rectangle {
                                id: itemBg
                                visible: !entry.modelData.isSeparator
                                anchors { fill: parent; topMargin: 1; bottomMargin: 1 }
                                radius: 10
                                color: rowHover.containsMouse && entry.modelData.enabled
                                    ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.12)
                                    : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: "transparent"
                                    border.color: rowHover.containsMouse && entry.modelData.enabled
                                        ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.20)
                                        : "transparent"
                                    border.width: 1
                                    Behavior on border.color { ColorAnimation { duration: 100 } }
                                }

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 10; rightMargin: 12 }
                                    spacing: 10

                                    Item {
                                        implicitWidth: 20; implicitHeight: 20

                                        Image {
                                            anchors.centerIn: parent
                                            width: 16; height: 16
                                            visible: entry.modelData.icon !== ""
                                            source: {
                                                var ic = entry.modelData.icon
                                                if (ic === "") return ""
                                                if (ic.startsWith("/") || ic.startsWith("file://") || ic.startsWith("image://")) return ic
                                                return "image://icon/" + ic
                                            }
                                            fillMode:   Image.PreserveAspectFit
                                            sourceSize: Qt.size(32, 32)
                                            smooth: true; mipmap: true
                                            opacity: entry.modelData.enabled ? 1.0 : 0.30
                                        }

                                        Rectangle {
                                            anchors.centerIn: parent
                                            visible: entry.modelData.icon === "" &&
                                                     entry.modelData.buttonType === QsMenuButtonType.CheckBox
                                            width: 15; height: 15; radius: 4
                                            color: entry.modelData.checkState === Qt.Checked
                                                ? Appearance.colors.accent : "transparent"
                                            border.color: entry.modelData.checkState === Qt.Checked
                                                ? Appearance.colors.accent
                                                : ColorUtils.applyAlpha(Appearance.colors.fg, 0.30)
                                            border.width: 1.5
                                            Behavior on color        { ColorAnimation { duration: 120 } }
                                            Behavior on border.color { ColorAnimation { duration: 120 } }
                                            Text {
                                                anchors.centerIn: parent
                                                visible: entry.modelData.checkState === Qt.Checked
                                                text: "✓"; font.pixelSize: 9; font.weight: Font.Bold
                                                color: Appearance.colors.color0
                                            }
                                        }

                                        Rectangle {
                                            anchors.centerIn: parent
                                            visible: entry.modelData.icon === "" &&
                                                     entry.modelData.buttonType === QsMenuButtonType.RadioButton
                                            width: 15; height: 15; radius: 8
                                            color: "transparent"
                                            border.color: entry.modelData.checkState === Qt.Checked
                                                ? Appearance.colors.accent
                                                : ColorUtils.applyAlpha(Appearance.colors.fg, 0.30)
                                            border.width: 1.5
                                            Behavior on border.color { ColorAnimation { duration: 120 } }
                                            Rectangle {
                                                anchors.centerIn: parent
                                                visible: entry.modelData.checkState === Qt.Checked
                                                width: 7; height: 7; radius: 4
                                                color: Appearance.colors.accent
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: entry.modelData.text
                                        font.family:    Appearance.font.family
                                        font.pixelSize: Appearance.font.body - 2
                                        font.weight:    rowHover.containsMouse ? Font.Medium : Font.Normal
                                        color: entry.modelData.enabled
                                            ? Appearance.colors.fg
                                            : ColorUtils.applyAlpha(Appearance.colors.fg, 0.30)
                                        elide: Text.ElideRight
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }

                                    Text {
                                        visible: entry.modelData.hasChildren
                                        text: "›"
                                        font.pixelSize: Appearance.font.body + 2
                                        color: rowHover.containsMouse
                                            ? Appearance.colors.accent
                                            : Appearance.colors.dim
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }
                                }

                                MouseArea {
                                    id: rowHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !entry.modelData.isSeparator && entry.modelData.enabled
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        entry.modelData.triggered()
                                        Qt.callLater(() => { Appearance.trayMenuOpen = false })
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
