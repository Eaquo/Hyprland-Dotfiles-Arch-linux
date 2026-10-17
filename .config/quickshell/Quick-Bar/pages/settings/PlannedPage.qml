import QtQuick
import QtQuick.Layouts
import qs.core

// PlannedPage — page de réglages pas encore construite : ce qu'elle contiendra.
ColumnLayout {
    id: page
    property string title: ""
    property var items: []          // [[titre, description], …]
    spacing: 18

    PageHeader { title: page.title; sub: "bientôt — prévu pour une prochaine étape" }
    Repeater {
        model: page.items
        delegate: SetCard {
            id: pc
            required property var modelData
            title: modelData[0]
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: pc.modelData[1]
                font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 1; color: Appearance.colors.dim
            }
        }
    }
}
