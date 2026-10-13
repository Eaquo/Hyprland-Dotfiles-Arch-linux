import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.core.functions
import qs.services

// HealthTab — bilan de santé (TouchPanel). Une ligne par dépendance de Quick-Bar :
// état, détail, et réparation au toucher de la ligne quand elle existe.
// Données et réparations : services/Health.qml → scripts/health/check.sh.
Item {
    id: root

    Component.onCompleted: Health.refresh()

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Text {
                text: Health.failCount === 0 ? "󰄬" : "󰀦"
                font.family: Appearance.font.family; font.pixelSize: 34
                color: Health.failCount === 0 ? Appearance.colors.accent : Appearance.colors.color13
            }
            Text {
                Layout.fillWidth: true
                text: Health.rows.length === 0 ? "Vérification…"
                    : Health.failCount === 0 ? "Tout répond"
                    : Health.failCount + " point" + (Health.failCount > 1 ? "s" : "") + " à voir"
                font.family: Appearance.font.family; font.pixelSize: 26; font.weight: Font.Bold
                color: Appearance.colors.fg
            }
            Rectangle {
                implicitWidth: rc.implicitWidth + 40; implicitHeight: 56; radius: 16
                opacity: Health.busy ? 0.5 : 1
                color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.6)
                border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
                Row {
                    id: rc
                    anchors.centerIn: parent; spacing: 10
                    Text { text: "󰑓"; font.family: Appearance.font.family; font.pixelSize: 22; color: Appearance.colors.fg }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Health.busy ? "Vérification…" : "Revérifier"
                        font.family: Appearance.font.family; font.pixelSize: 17; color: Appearance.colors.fg
                    }
                }
                MouseArea { anchors.fill: parent; onClicked: { Health.refresh(); GameBreak.extend() } }
            }
        }

        // Deux colonnes de lignes (l'écran est large et bas)
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            columnSpacing: 16; rowSpacing: 12

            Repeater {
                model: Health.rows
                delegate: Rectangle {
                    required property var modelData
                    readonly property color tint: modelData.ok ? Appearance.colors.accent : Appearance.colors.color13
                    readonly property bool fixable: modelData.fix && !modelData.ok
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.maximumHeight: 96
                    radius: 18
                    color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.55)
                    border.width: modelData.ok ? 1 : 2
                    border.color: ColorUtils.applyAlpha(tint, modelData.ok ? 0.25 : 0.9)

                    // Toute la ligne en panne est le bouton de réparation
                    MouseArea {
                        anchors.fill: parent
                        enabled: parent.fixable
                        onClicked: { Health.fix(modelData.id); GameBreak.extend() }
                    }

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 14
                        spacing: 16
                        Rectangle {
                            width: 16; height: 16; radius: 8
                            color: parent.parent.tint
                        }
                        Column {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                width: parent.width
                                text: modelData.label
                                font.family: Appearance.font.family; font.pixelSize: 19; font.weight: Font.Medium
                                color: Appearance.colors.fg; elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: modelData.detail
                                font.family: Appearance.font.family; font.pixelSize: 14
                                color: modelData.ok ? Appearance.colors.dim : Appearance.colors.fg
                                elide: Text.ElideRight
                                wrapMode: modelData.ok ? Text.NoWrap : Text.WordWrap; maximumLineCount: 2
                            }
                        }
                        Rectangle {
                            visible: parent.parent.fixable
                            implicitWidth: fx.implicitWidth + 32; implicitHeight: 52; radius: 14
                            color: Appearance.colors.accent
                            opacity: Health.fixing !== "" ? 0.5 : 1
                            Text {
                                id: fx
                                anchors.centerIn: parent
                                text: Health.fixing === modelData.id ? "En cours…"
                                    : Health.lastTried === modelData.id ? "Réessayer" : "Réparer"
                                font.family: Appearance.font.family; font.pixelSize: 16; font.weight: Font.Bold
                                color: Appearance.textOn(Appearance.colors.accent)
                            }
                        }
                    }
                }
            }
        }
    }
}
