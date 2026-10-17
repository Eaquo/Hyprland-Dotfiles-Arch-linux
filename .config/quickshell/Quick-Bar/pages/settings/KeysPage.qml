import QtQuick
import QtQuick.Layouts
import qs.core
import qs.pages.config

// KeysPage — Réglages › Avancé › Raccourcis : la page Keybinds existante (pages/config/KeybindsPage.qml).
ColumnLayout {
    id: page
    spacing: 18

    PageHeader { title: "Raccourcis"; sub: "raccourcis Hyprland — clique un raccourci pour le modifier" }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 620
        radius: Appearance.cornerRadius - 4
        color: "transparent"
        border.width: 1; border.color: Qt.rgba(Appearance.colors.fg.r, Appearance.colors.fg.g, Appearance.colors.fg.b, 0.08)
        clip: true
        KeybindsPage { anchors.fill: parent; anchors.margins: 8 }
    }
}
