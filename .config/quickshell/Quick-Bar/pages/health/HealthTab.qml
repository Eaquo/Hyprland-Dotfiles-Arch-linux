import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.core.functions
import qs.services

// HealthTab — bilan de santé (TouchPanel), 4 colonnes × 5 lignes. Toucher une ligne ouvre ce
// qu'elle surveille (site, appli, service…) ; « Réparer » quand elle est en panne.
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

        // 4 colonnes visibles, 5 lignes par colonne : la 6ᵉ vérification ouvre une nouvelle
        // colonne (défilement horizontal au-delà de 20)
        Flickable {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            readonly property int rowsPer: 5
            readonly property int gap: 14
            readonly property real colW: (width - gap * 3) / 4
            readonly property real cellH: (height - gap * (rowsPer - 1)) / rowsPer
            contentWidth: Math.max(width, Math.ceil(Health.rows.length / rowsPer) * (colW + gap) - gap)
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Repeater {
                model: Health.rows
                delegate: Rectangle {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property color tint: modelData.ok ? Appearance.colors.accent : Appearance.colors.color13
                    readonly property bool fixable: modelData.fix && !modelData.ok
                    readonly property var action: Health.openAction(modelData.id)
                    x: Math.floor(index / grid.rowsPer) * (grid.colW + grid.gap)
                    y: (index % grid.rowsPer) * (grid.cellH + grid.gap)
                    width: grid.colW; height: grid.cellH
                    radius: 18
                    color: tap.pressed && cell.action ? ColorUtils.applyAlpha(cell.tint, 0.16) : ColorUtils.applyAlpha(Appearance.colors.bg, 0.55)
                    border.width: modelData.ok ? 1 : 2
                    border.color: ColorUtils.applyAlpha(tint, modelData.ok ? 0.25 : 0.9)
                    scale: tap.pressed && cell.action ? 0.97 : 1
                    Behavior on scale { NumberAnimation { duration: Appearance.dur(110) } }
                    Behavior on color { ColorAnimation { duration: Appearance.dur(110) } }

                    // Toucher la ligne = ouvrir ce qu'elle surveille (site, appli, service…)
                    MouseArea {
                        id: tap
                        anchors.fill: parent
                        enabled: !!cell.action
                        onClicked: { Health.open(cell.modelData.id); GameBreak.extend() }
                    }

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 18; anchors.rightMargin: 12
                        spacing: 14
                        Rectangle { width: 14; height: 14; radius: 7; color: cell.tint }
                        Column {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                width: parent.width
                                text: cell.modelData.label
                                font.family: Appearance.font.family; font.pixelSize: 18; font.weight: Font.Medium
                                color: Appearance.colors.fg; elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: cell.modelData.detail
                                font.family: Appearance.font.family; font.pixelSize: 13
                                color: cell.modelData.ok ? Appearance.colors.dim : Appearance.colors.fg
                                elide: Text.ElideRight
                            }
                        }
                        // Réparer (en panne) sinon l'action d'ouverture
                        Rectangle {
                            visible: cell.fixable
                            implicitWidth: fx.implicitWidth + 26; implicitHeight: 46; radius: 13
                            color: Appearance.colors.accent
                            opacity: Health.fixing !== "" ? 0.5 : 1
                            Text {
                                id: fx
                                anchors.centerIn: parent
                                text: Health.fixing === cell.modelData.id ? "En cours…"
                                    : Health.lastTried === cell.modelData.id ? "Réessayer" : "Réparer"
                                font.family: Appearance.font.family; font.pixelSize: 15; font.weight: Font.Bold
                                color: Appearance.textOn(Appearance.colors.accent)
                            }
                            MouseArea { anchors.fill: parent; onClicked: { Health.fix(cell.modelData.id); GameBreak.extend() } }
                        }
                        Text {
                            visible: !cell.fixable && !!cell.action
                            text: cell.action ? cell.action.icon : ""
                            font.family: Appearance.font.family; font.pixelSize: 20
                            color: Appearance.colors.dim
                        }
                    }
                }
            }
        }
        // indicateur de colonnes quand elles dépassent l'écran
        Row {
            Layout.alignment: Qt.AlignHCenter
            visible: grid.contentWidth > grid.width + 1
            spacing: 6
            Repeater {
                model: Math.max(1, Math.ceil(Health.rows.length / grid.rowsPer) - 3)
                delegate: Rectangle {
                    required property int index
                    readonly property bool on: Math.round(grid.contentX / (grid.colW + grid.gap)) === index
                    width: on ? 22 : 8; height: 8; radius: 4
                    color: on ? Appearance.colors.accent : ColorUtils.applyAlpha(Appearance.colors.fg, 0.25)
                    Behavior on width { NumberAnimation { duration: Appearance.dur(160) } }
                }
            }
        }
    }
}
