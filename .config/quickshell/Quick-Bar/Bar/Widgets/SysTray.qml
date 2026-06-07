pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.DBusMenu
import Quickshell.Services.SystemTray
import "../Common/"
import "../Common/functions/"

RowLayout {
    id: root
    spacing: 2

    Repeater {
        model: SystemTray.items

        Item {
            id: trayItem
            required property SystemTrayItem modelData

            readonly property int sz:  Appearance.bar.height - 12
            readonly property int pad: 4

            implicitWidth:  sz + pad * 2
            implicitHeight: sz + pad * 2

            // Position absolue dans la fenêtre pour le tooltip reparenté
            property point globalPos: Qt.point(0, 0)
            onVisibleChanged: updatePos()
            Component.onCompleted: updatePos()
            function updatePos() {
                var p = trayItem.mapToItem(trayItem.Window.contentItem, 0, 0)
                globalPos = Qt.point(p.x, p.y)
            }

            // ── Hover background ──────────────────────────────────────
            Rectangle {
                anchors.fill: parent
                radius: 6
                color: hoverArea.containsMouse
                    ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.10)
                    : "transparent"
                Behavior on color { ColorAnimation { duration: 130 } }
            }

            // ── Icon ──────────────────────────────────────────────────
            Image {
                id: iconImg
                anchors.centerIn: parent
                width:  trayItem.sz
                height: trayItem.sz

                source: IconUtils.resolve(trayItem.modelData.icon, "application-x-executable")

                fillMode:   Image.PreserveAspectFit
                sourceSize: Qt.size(trayItem.sz * 2, trayItem.sz * 2)
                smooth:     true
                mipmap:     true

                opacity: hoverArea.containsMouse ? 1.0 : 0.75
                Behavior on opacity { NumberAnimation { duration: 130 } }

            }

            // ── Tooltip ───────────────────────────────────────────────
            // Reparenté sur le contentItem pour sortir des bounds de la bar
            // → position calculée manuellement, pas d'anchors
            Rectangle {
                id: tooltip

                parent: trayItem.Window.contentItem
                z: 9999

                // Position calculée depuis les coordonnées globales
                x: trayItem.globalPos.x + trayItem.implicitWidth / 2 - width / 2
                y: trayItem.globalPos.y + trayItem.implicitHeight + 6

                width:  ttText.implicitWidth + 14
                height: ttText.implicitHeight + 8
                radius: 6

                visible: opacity > 0
                opacity: hoverArea.containsMouse ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 120 } }

                color:        ColorUtils.applyAlpha(Appearance.colors.bg, 0.95)
                border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
                border.width: 1

                // Flèche pointant vers le haut (vers la bar)
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.top
                    anchors.bottomMargin: -1
                    width: 8; height: 8
                    rotation: 45
                    color: tooltip.color
                    border.color: tooltip.border.color
                    border.width: tooltip.border.width
                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: parent.height / 2 + 1
                        color: tooltip.color
                        border.width: 0
                    }
                }

                Text {
                    id: ttText
                    anchors.centerIn: parent
                    text: {
                        var t = trayItem.modelData.tooltipTitle
                        if (t !== "") return t
                        var t2 = trayItem.modelData.title
                        if (t2 !== "") return t2
                        return trayItem.modelData.icon
                    }
                    font.pixelSize: Appearance.font.small - 1
                    font.family:    Appearance.font.family
                    color:          Appearance.colors.fg
                }
            }

            // ── Mouse ─────────────────────────────────────────────────
            MouseArea {
                id: hoverArea
                anchors.fill:    parent
                hoverEnabled:    true    // ← était false
                cursorShape:     Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                // Recalcule la position quand le hover s'active
                onEntered: trayItem.updatePos()

                onClicked: (ev) => {
                    if (ev.button === Qt.RightButton ||
                        (ev.button === Qt.LeftButton && trayItem.modelData.onlyMenu))
                    {
                        if (trayItem.modelData.hasMenu) {
                            var pos = trayItem.mapToGlobal(trayItem.implicitWidth / 2, 0)
                            Appearance.trayMenuHandle = trayItem.modelData.menu
                            Appearance.trayMenuTitle  = trayItem.modelData.tooltipTitle !== ""
                                ? trayItem.modelData.tooltipTitle
                                : trayItem.modelData.title !== ""
                                    ? trayItem.modelData.title
                                    : "Menu"
                            Appearance.trayMenuIcon   = trayItem.modelData.icon
                            Appearance.trayMenuX      = pos.x
                            Qt.callLater(() => { Appearance.trayMenuOpen = true })
                        } else {
                            trayItem.modelData.secondaryActivate()
                        }
                    } else if (ev.button === Qt.MiddleButton) {
                        trayItem.modelData.secondaryActivate()
                    } else {
                        trayItem.modelData.activate()
                    }
                }
            }
        }
    }
}
