pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../Common/"
import "../Common/functions/"
import "./"
import "../Windows/"

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: root
            required property var modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "quickshell:bar"
            WlrLayershell.layer: WlrLayer.Top

            anchors { top: true; left: true; right: true }
            margins {
                top:   Appearance.bar.topMargin
                left:  Appearance.bar.sideMargin
                right: Appearance.bar.sideMargin
            }

            implicitHeight: Appearance.bar.height
            exclusiveZone:  Appearance.bar.height + Appearance.bar.topMargin

            Item {
                anchors.fill: parent

                // ── LEFT PILL ──────────────────────────────────────────────
                Rectangle {
                    id: leftPill
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    height: Appearance.bar.height
                    width:  leftRow.implicitWidth + Appearance.bar.pillPad * 2
                    radius: Appearance.bar.radius
                    border.color: Appearance.colors.color15
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 600; easing.type: Easing.InOutQuad } }

                    gradient: Gradient {
                        GradientStop {
                            position: 0.7
                            color: Appearance.colors.bg
                            Behavior on color { ColorAnimation { duration: 600; easing.type: Easing.InOutQuad } }
                        }
                        GradientStop {
                            position: 1.0
                            color: ColorUtils.applyAlpha(Appearance.colors.color0, 0.80)
                            Behavior on color { ColorAnimation { duration: 600; easing.type: Easing.InOutQuad } }
                        }
                    }

                    RowLayout {
                        id: leftRow
                        anchors { centerIn: parent }
                        spacing: Appearance.bar.gap

                        AppLauncher {}
                        BarSeparator {}
                        SysStats {}
                    }
                }

                // ── CENTER PILL ────────────────────────────────────────────
                Rectangle {
                    id: centerPill
                    anchors { centerIn: parent }
                    height: Appearance.bar.height
                    width:  centerRow.implicitWidth + Appearance.bar.pillPad * 2
                    radius: Appearance.bar.radius
                    border.color: Appearance.colors.color15
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 600; easing.type: Easing.InOutQuad } }

                    onXChanged: updateRightPill()
                    onWidthChanged: updateRightPill()
                    Component.onCompleted: updateRightPill()

                    gradient: Gradient {
                        GradientStop {
                            position: 0.7
                            color: Appearance.colors.bg
                            Behavior on color { ColorAnimation { duration: 600; easing.type: Easing.InOutQuad } }
                        }
                        GradientStop {
                            position: 1.0
                            color: ColorUtils.applyAlpha(Appearance.colors.color0, 0.80)
                            Behavior on color { ColorAnimation { duration: 600; easing.type: Easing.InOutQuad } }
                        }
                    }

                    function updateRightPill() {
                        var g = mapToGlobal(0, 0)
                        Appearance.rightPillX = g.x
                        Appearance.rightPillW = width
                    }

                    RowLayout {
                        id: centerRow
                        anchors { centerIn: parent }
                        spacing: Appearance.bar.gap

                        Notifications {}
                        BarSeparator {}
                        Cava {}
                        BarSeparator {}
                        Clock {}
                        BarSeparator {}
                        Workspaces {}
                        BarSeparator {}
                        LayoutDisplayer {}
                        BarSeparator {}
                        LocalSend {}
                    }
                }

                // ── RIGHT PILL ─────────────────────────────────────────────
                Rectangle {
                    id: rightPill
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    height: Appearance.bar.height
                    width:  rightRow.implicitWidth + Appearance.bar.pillPad * 2
                    radius: Appearance.bar.radius
                    border.color: Appearance.colors.color15
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 600; easing.type: Easing.InOutQuad } }

                    gradient: Gradient {
                        GradientStop {
                            position: 0.7
                            color: Appearance.colors.bg
                            Behavior on color { ColorAnimation { duration: 600; easing.type: Easing.InOutQuad } }
                        }
                        GradientStop {
                            position: 1.0
                            color: ColorUtils.applyAlpha(Appearance.colors.color0, 0.80)
                            Behavior on color { ColorAnimation { duration: 600; easing.type: Easing.InOutQuad } }
                        }
                    }

                    onXChanged: {
                        var g = mapToGlobal(0, 0)
                        Appearance.rightPillX = g.x
                        Appearance.rightPillW = width
                    }
                    onWidthChanged: {
                        var g = mapToGlobal(0, 0)
                        Appearance.rightPillX = g.x
                        Appearance.rightPillW = width
                    }
                    Component.onCompleted: {
                        var g = mapToGlobal(0, 0)
                        Appearance.rightPillX = g.x
                        Appearance.rightPillW = width
                    }

                    RowLayout {
                        id: rightRow
                        anchors { centerIn: parent }
                        spacing: Appearance.bar.gap

                        Updates { id: upd }
                        BarSeparator {}
                        // MediaPlayer { id: mp }
                        // BarSeparator { visible: mp.hasContent }
                        // Eq { visible: mp.hasContent }
                        // BarSeparator { visible: mp.hasContent }
                        SysTray {}
                        BarSeparator {}
                        Audio {}
                        BarSeparator {}
                        PowerButtons {}
                    }
                }
            }
        }
    }
}
