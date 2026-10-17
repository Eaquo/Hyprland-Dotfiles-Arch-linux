import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.core
import qs.core.functions

// FontsPage — Réglages › Apparence › Police ([fonts] dans config.toml).
// Liste : scripts/system/fonts.py (fc-list) ; chaque nom est affiché dans sa propre police.
ColumnLayout {
    id: page
    spacing: 18

    property var fonts: []
    property string filter: "nerd"            // nerd · mono · all
    property string query: ""
    readonly property string current: Appearance.font.family
    readonly property bool installed: fonts.length === 0 || fonts.some(f => f.family === current)
    readonly property var shown: fonts.filter(f => (filter === "all" || (filter === "nerd" ? f.nerd : f.mono))
                                                   && f.family.toLowerCase().includes(query.toLowerCase()))

    Process {
        command: ["python3", Quickshell.shellDir + "/scripts/system/fonts.py"]
        running: true
        stdout: StdioCollector { onStreamFinished: { try { page.fonts = JSON.parse(text) } catch (e) {} } }
    }

    PageHeader { title: "Police"; sub: "[fonts] family · body · small dans config.toml — appliqué en direct" }

    SetCard {
        title: "Famille"
        SetRow {
            title: page.current
            desc: page.installed ? (page.fonts.find(f => f.family === page.current)?.nerd
                                    ? "Nerd Font : les icônes de la barre s'affichent."
                                    : "Pas une Nerd Font : certaines icônes de la barre peuvent manquer.")
                                 : "⚠ Cette police n'est pas installée : Qt affiche une police de remplacement. Choisis-en une dans la liste."
            Text { text: "Aa 󰍛 󰾆 󰋊"; font.family: page.current; font.pixelSize: 22; color: page.installed ? Appearance.colors.fg : Appearance.colors.color12 }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            SetInput { Layout.fillWidth: true; placeholder: "Filtrer " + page.fonts.length + " polices…"; onTextChanged: page.query = text }
            SetSeg { options: [["nerd", "Nerd Font"], ["mono", "Chasse fixe"], ["all", "Toutes"]]; current: page.filter; onPicked: (v) => page.filter = v }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 280
            radius: 10
            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.55)
            border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
            clip: true
            ListView {
                id: list
                anchors.fill: parent; anchors.margins: 4
                model: page.shown
                boundsBehavior: Flickable.StopAtBounds
                spacing: 2
                delegate: Rectangle {
                    id: it
                    required property var modelData
                    readonly property bool on: modelData.family === page.current
                    width: ListView.view.width; height: 38; radius: 8
                    color: on ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.22)
                         : itMa.containsMouse ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.06) : "transparent"
                    Behavior on color { ColorAnimation { duration: Appearance.dur(140) } }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 10
                        Text { Layout.fillWidth: true; text: it.modelData.family; elide: Text.ElideRight
                               font.family: it.modelData.family; font.pixelSize: 16; color: Appearance.colors.fg }
                        Text { visible: it.modelData.mono; text: "mono"; font.family: Appearance.font.family; font.pixelSize: 10; color: Appearance.colors.dim }
                        Text { visible: it.modelData.nerd; text: "icônes ✓"; font.family: Appearance.font.family; font.pixelSize: 10; color: Appearance.colors.accent }
                    }
                    MouseArea { id: itMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: Config.set("fonts.family", it.modelData.family) }
                }
            }
            Text { anchors.centerIn: parent; visible: page.shown.length === 0
                   text: page.fonts.length ? "Aucune police ne correspond" : "Lecture des polices…"
                   font.family: Appearance.font.family; font.pixelSize: Appearance.font.small; color: Appearance.colors.dim }
        }
        Text { text: page.shown.length + " police(s)"; font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim }
    }

    SetCard {
        title: "Tailles"
        resetKeys: ["fonts.body", "fonts.small"]
        SetRow {
            title: "Texte normal"; desc: "barre, panneaux, cartes"
            SetSlider { implicitWidth: 320; from: 10; to: 22; step: 1; suffix: " px"; value: Appearance.font.body; onMoved: (v) => Config.set("fonts.body", v) }
        }
        SetRow {
            title: "Petit texte"; desc: "libellés, sous-titres"
            SetSlider { implicitWidth: 320; from: 9; to: 18; step: 1; suffix: " px"; value: Appearance.font.small; onMoved: (v) => Config.set("fonts.small", v) }
        }
        Rectangle {
            Layout.fillWidth: true; implicitHeight: sample.implicitHeight + 24; radius: 10
            color: "transparent"; border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.12)
            Column {
                id: sample
                x: 14; y: 12; spacing: 4
                Text { text: "Quick-Bar · 20:12 · 󰍛 5%  󰾆 10.2G  󰔏 58°  󰋊 54%"; font.family: Appearance.font.family; font.pixelSize: Appearance.font.body; color: Appearance.colors.fg }
                Text { text: "Petit texte · libellés · sous-titres · 0123456789"; font.family: Appearance.font.family; font.pixelSize: Appearance.font.small; color: Appearance.colors.dim }
            }
        }
    }
}
