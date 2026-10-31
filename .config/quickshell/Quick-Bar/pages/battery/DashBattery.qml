import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.components
import qs.core
import qs.core.functions
import qs.services

// DashBattery — page Devices du dashboard : une carte par périphérique de services/Batteries.qml
// (UPower suivi en direct + la Vader 5 Pro lue en HID), avec sa photo (assets/devices/, sinon l'icône).
// Mêmes cartes que la page System (MorphCard, ouverture en cascade).
Item {
    id: root
    readonly property int gap: 12
    readonly property bool shown: visible && width > 0
    property int cascade: 0
    onShownChanged: { if (shown && Appearance.morphPages) cascade++; if (shown) Batteries.refreshKeyboard() }

    Flickable {
        anchors.fill: parent
        contentHeight: grid.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        GridLayout {
            id: grid
            width: parent.width
            // cartes d'au moins ~420 px : la photo et les infos tiennent côte à côte
            columns: Math.max(1, Math.min(Batteries.all.length, Math.floor((width + root.gap) / 420)))
            columnSpacing: root.gap; rowSpacing: root.gap
            Repeater {
                model: Batteries.all
                delegate: Tile { required property var modelData; required property int index; dev: modelData; order: index }
            }
        }
    }

    // aucun appareil
    ColumnLayout {
        anchors.centerIn: parent
        visible: Batteries.all.length === 0
        spacing: 6
        Text { Layout.alignment: Qt.AlignHCenter; text: "󰂑"; font.family: Appearance.font.family; font.pixelSize: 34; color: Appearance.colors.dim }
        Text { Layout.alignment: Qt.AlignHCenter; text: "Aucun périphérique sur batterie"
               font.family: Appearance.font.family; font.pixelSize: 14; color: Appearance.colors.fg }
        Text { Layout.alignment: Qt.AlignHCenter; text: "souris, manettes et casques sans fil apparaissent ici quand ils sont connectés"
               font.family: Appearance.font.family; font.pixelSize: 11; color: Appearance.colors.dim }
    }

    component Tile: MorphCard {
        id: tile
        property var dev
        readonly property real pct: Math.round((dev ? dev.percentage : 0) * 100)
        readonly property color c: Batteries.col(pct)
        readonly property string link: Batteries.link(dev)
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        contentHeight: 200
        hotColor: c
        Connections { target: root; function onCascadeChanged() { tile.play() } }

        // photo sur une lueur à la couleur de l'accent ; l'icône si le modèle n'a pas de photo
        Item {
            id: photoBox
            x: 12; y: 12
            width: tile.dev.noBattery ? parent.width * 0.5 : Math.min(parent.width * 0.42, 220); height: parent.height - 24   // clavier : photo large
            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) * 0.92; height: width; radius: width / 2
                color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.10)
                Rectangle { anchors.centerIn: parent; width: parent.width * 0.62; height: width; radius: width / 2
                            color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.08) }
            }
            Image {
                id: img
                anchors.fill: parent; anchors.margins: 8
                source: Batteries.photo(tile.dev)
                fillMode: Image.PreserveAspectFit
                asynchronous: true; smooth: true; mipmap: true
                sourceSize.height: 360
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                visible: img.status !== Image.Ready
                text: Batteries.icon(tile.dev.type)
                font.family: Appearance.font.family; font.pixelSize: 64; color: Appearance.colors.accent
            }
        }

        ColumnLayout {
            x: photoBox.x + photoBox.width + 14; y: 16
            width: parent.width - x - 16
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text { Layout.fillWidth: true; elide: Text.ElideRight; text: tile.dev.model || Batteries.kind(tile.dev.type)
                       font.family: Appearance.font.family; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.5
                       font.capitalization: Font.AllUppercase; color: Appearance.colors.dim }
                Text { visible: tile.dev.state === UPowerDeviceState.Charging; text: "󱐋"
                       font.family: Appearance.font.family; font.pixelSize: 13; color: tile.c }
            }
            Text { text: Batteries.kind(tile.dev.type) + (tile.link ? " · " + tile.link : "")
                   font.family: "JetBrains Mono"; font.pixelSize: 11; color: Appearance.colors.dim }
            Item { Layout.fillHeight: true }
            // sans batterie (clavier) : disposition + voyants Verr. Maj / Verr. Num
            Text { visible: !!tile.dev.noBattery; text: tile.dev.layout || "—"; font.family: Appearance.font.family; font.pixelSize: 24
                   font.weight: Font.Bold; color: Appearance.colors.accent; Layout.fillWidth: true; elide: Text.ElideRight }
            Row {
                visible: !!tile.dev.noBattery
                spacing: 8
                Repeater {
                    model: [["Verr. Maj", !!tile.dev.caps], ["Verr. Num", !!tile.dev.num]]
                    delegate: Rectangle {
                        required property var modelData
                        width: lbl.implicitWidth + 22; height: 26; radius: 13
                        color: modelData[1] ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.25) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.06)
                        border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.accent, modelData[1] ? 0.8 : 0.15)
                        Text { id: lbl; anchors.centerIn: parent; text: (modelData[1] ? "󰄬 " : "") + modelData[0]
                               font.family: "JetBrains Mono"; font.pixelSize: 11; color: modelData[1] ? Appearance.colors.fg : Appearance.colors.dim }
                    }
                }
            }
            Text { visible: !tile.dev.noBattery; text: tile.pct + " %"; font.family: Appearance.font.family; font.pixelSize: 34; font.weight: Font.Bold; color: tile.c
                   Behavior on color { ColorAnimation { duration: Appearance.dur(250) } } }
            Rectangle {                                    // jauge
                visible: !tile.dev.noBattery
                Layout.fillWidth: true; Layout.preferredHeight: 10
                radius: 3; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
                Rectangle { height: parent.height; radius: 3; color: tile.c; width: parent.width * tile.pct / 100
                            Behavior on width { NumberAnimation { duration: Appearance.dur(450) } } }
            }
            Text {
                Layout.fillWidth: true; Layout.bottomMargin: 2; wrapMode: Text.WordWrap
                text: Batteries.stateText(tile.dev)
                font.family: "JetBrains Mono"; font.pixelSize: 11; color: Appearance.colors.dim
            }
        }
    }
}
