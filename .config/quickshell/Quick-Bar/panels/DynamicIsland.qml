import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.core
import qs.core.functions
import qs.services

// DynamicIsland — la pastille de services/Island.qml, par-dessus le centre de la barre de l'écran principal.
// Ouverture : pilule de la hauteur de la barre qui s'élargit, puis descend en carte (image + titre + détail) ;
// fermeture inverse. Toucher la pastille la referme tout de suite. Seule la pastille capte la souris.
PanelWindow {
    id: root
    screen: Quickshell.screens.find(s => !Config.isTouch(s)) || Quickshell.screens[0]
    color: "transparent"
    anchors { top: true }
    margins.top: Appearance.bar.topMargin
    implicitWidth: 640; implicitHeight: 130
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:island"
    mask: Region { item: pill }
    readonly property var ev: Island.current

    // 0 = petite pilule, 1 = élargie, 2 = carte ouverte
    property real wk: 0
    property real hk: 0
    SequentialAnimation {
        id: openAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "wk"; to: 1; duration: Appearance.dur(280); easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "hk"; to: 0; duration: 1 }
        }
        NumberAnimation { target: root; property: "hk"; to: 1; duration: Appearance.dur(320); easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: closeAnim
        NumberAnimation { target: root; property: "hk"; to: 0; duration: Appearance.dur(220); easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "wk"; to: 0; duration: Appearance.dur(220); easing.type: Easing.InCubic }
    }
    Connections {
        target: Island
        function onOpenChanged() { if (Island.open) { closeAnim.stop(); openAnim.restart() } else { openAnim.stop(); closeAnim.restart() } }
    }
    Component.onCompleted: if (Island.open) openAnim.restart()

    readonly property color accent: ev && ev.accent ? ev.accent : Appearance.colors.accent
    Rectangle {                                  // fond plein ; le contenu est rogné par clip
        id: pill
        clip: true
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: 180 + (Math.min(root.width - 20, 560) - 180) * root.wk
        height: Appearance.bar.height + (96 - Appearance.bar.height) * root.hk
        radius: Math.min(height / 2, 28)
        opacity: Math.min(1, root.wk * 3 + 0.2)
        color: Appearance.colors.bg
        border.width: 1; border.color: ColorUtils.applyAlpha(root.accent, 0.6)

        Item {
            anchors.fill: parent
            opacity: root.hk
            // image : photo (chemin), pochette (URL, via CachedArt), sinon glyphe
            CachedArt { id: art; url: root.ev?.art ?? "" }
            ClippingRectangle {
                id: thumb
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                width: 64; height: 64; radius: root.ev?.art ? 14 : 32
                color: ColorUtils.applyAlpha(root.accent, 0.15)
                Image {
                    anchors.fill: parent; anchors.margins: root.ev?.image ? 6 : 0
                    fillMode: root.ev?.image ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                    source: root.ev?.image ? "file://" + root.ev.image : art.local
                    sourceSize: Qt.size(128, 128); asynchronous: true
                    visible: status === Image.Ready
                }
                Text { anchors.centerIn: parent; visible: !(root.ev?.image) && art.local === ""
                       text: root.ev?.glyph ?? "󰋼"; font.family: Appearance.font.family; font.pixelSize: 28; color: root.accent }
            }
            Column {
                anchors { left: thumb.right; leftMargin: 16; right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                spacing: 4
                Text { width: parent.width; elide: Text.ElideRight; text: root.ev?.title ?? ""
                       font.family: Appearance.font.family; font.pixelSize: 17; font.weight: Font.DemiBold; color: Appearance.colors.fg }
                Text { width: parent.width; elide: Text.ElideRight; text: root.ev?.sub ?? ""; visible: text !== ""
                       font.family: Appearance.font.family; font.pixelSize: 13; color: Appearance.colors.dim }
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Island.dismiss() }
    }
}
