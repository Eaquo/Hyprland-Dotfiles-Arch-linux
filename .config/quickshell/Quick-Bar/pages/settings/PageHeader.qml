import QtQuick
import QtQuick.Layouts
import qs.core

// PageHeader — titre de page + sous-titre (souvent : où c'est rangé dans config.toml).
RowLayout {
    property string title: ""
    property string sub: ""
    Layout.fillWidth: true
    spacing: 14
    Text { text: parent.title; font.family: Appearance.font.family; font.pixelSize: 26; font.weight: Font.Bold; color: Appearance.colors.fg }
    Text { Layout.fillWidth: true; text: parent.sub; elide: Text.ElideRight
           font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 2; color: Appearance.colors.dim }
}
