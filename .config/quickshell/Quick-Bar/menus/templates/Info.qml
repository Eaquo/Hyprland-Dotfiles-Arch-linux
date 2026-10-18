import QtQuick
import qs.core
import qs.core.functions

// Info — affichage seul (aide-mémoire, raccourcis…) : « touche<TAB>description<TAB>détail »,
// sections avec nonselectable. Les touches (1re colonne) sont dessinées en touches de clavier.
// Deux colonnes si la fenêtre est assez large. Entrée ou Échap ferment.
Item {
    id: t
    required property var menu
    property real prefW: 1300
    readonly property int nCol: width > 1000 ? 2 : 1
    readonly property real rowH: 36
    readonly property real contentH: Math.min(Math.ceil(menu.items.length / nCol) * rowH, 640)
    property int cols: 1
    property bool filter: true
    property bool search: true
    property string hints: "tape pour filtrer"

    Flickable {
        anchors.fill: parent
        contentHeight: flow.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Flow {
            id: flow
            width: parent.width
            flow: Flow.TopToBottom
            height: Math.ceil(t.menu.items.length / t.nCol) * t.rowH
            Repeater {
                model: t.menu.items
                delegate: Item {
                    id: r
                    required property var modelData
                    required property int index
                    readonly property bool head: t.menu.isHead(modelData)
                    readonly property var c: modelData.t.split("\t")
                    width: flow.width / t.nCol; height: t.rowH
                    opacity: t.menu.settled ? 1 : 0
                    Component.onCompleted: if (!t.menu.settled) fade.start()
                    NumberAnimation { id: fade; target: r; property: "opacity"; to: 1; duration: Appearance.dur(220) }
                    Text {
                        visible: r.head
                        anchors.verticalCenter: parent.verticalCenter; x: 6
                        text: r.c[0].replace(/━/g, "").trim().toUpperCase()
                        font.family: Appearance.font.family; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 2
                        color: t.menu.glow
                    }
                    Row {
                        visible: !r.head
                        anchors.verticalCenter: parent.verticalCenter; x: 6
                        spacing: 5
                        Item { width: 230; height: 26
                            Row {
                                spacing: 4; anchors.verticalCenter: parent.verticalCenter
                                Repeater {
                                    model: r.c[0].trim().split(/\s+/).filter(k => k !== "")
                                    Rectangle {
                                        required property string modelData
                                        height: 24; radius: 6; width: kt.implicitWidth + 14
                                        color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
                                        border.width: 2; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
                                        Text { id: kt; anchors.centerIn: parent; text: parent.modelData
                                               font.family: Appearance.font.family; font.pixelSize: 12; color: Appearance.colors.fg }
                                    }
                                }
                            }
                        }
                        Text { width: r.width * 0.42; text: t.menu.mark(r.c[1] || ""); textFormat: Text.StyledText; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter
                               font.family: Appearance.font.family; font.pixelSize: 14; color: Appearance.colors.fg }
                        Text { width: r.width - 230 - r.width * 0.42 - 30; text: r.c[2] || ""; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter
                               font.family: Appearance.font.family; font.pixelSize: 12; color: Appearance.colors.dim }
                    }
                }
            }
        }
    }
}
