import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.core
import qs.core.functions

// AppsPage — Réglages › Panneaux › Apps : sections et applis de l'onglet Apps
// (core/AppDeck.qml → user_data/streamdeck.json) + affichage ([apps]).
// Chaque modification est enregistrée et appliquée tout de suite.
ColumnLayout {
    id: page
    spacing: 18

    readonly property var deck: AppDeck.sections
    function edit(fn) { const d = JSON.parse(JSON.stringify(deck)); fn(d); AppDeck.save(d) }
    function swap(a, i, j) { if (j < 0 || j >= a.length) return; const t = a[i]; a[i] = a[j]; a[j] = t }
    function col(slot) { return AppDeck.color(slot) }

    // Appli en cours d'édition : "section/index" ; sélecteur d'applis : index de la section
    property string editing: ""
    property int pickFor: -1
    property string armed: ""                 // suppression d'une section en attente de confirmation
    Timer { id: disarm; interval: 3500; onTriggered: page.armed = "" }

    // Applications installées (fichiers .desktop)
    property var installed: []
    property string query: ""
    Process {
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/apps/desktop_apps.py"]
        stdout: StdioCollector { onStreamFinished: { try { page.installed = JSON.parse(text) } catch (e) {} } }
    }
    readonly property var found: installed.filter(a => query === "" || (a.name + " " + a.comment + " " + a.exec).toLowerCase().includes(query.toLowerCase())).slice(0, 120)
    function addApp(si, a) {
        edit(d => d[si].items.push({ label: a.name, exec: a.terminal ? Config.terminal + " -e " + a.exec : a.exec, appicon: a.icon }))
    }

    PageHeader { title: "Apps"; sub: "onglet Apps du panneau tactile · user_data/streamdeck.json · [apps] dans config.toml" }

    SetCard {
        title: "Affichage"
        resetKeys: ["apps.tile_size", "apps.labels", "apps.main_screen"]
        SetRow { title: "Taille des tuiles"; SetSlider { implicitWidth: 300; from: 90; to: 200; step: 5; suffix: " px"; value: AppDeck.tileSize
                 onMoved: (v) => Config.set("apps.tile_size", v === 130 ? null : v) } }
        SetRow { title: "Noms sous les icônes"; SetSwitch { on: AppDeck.labels; onToggled: Config.set("apps.labels", on ? false : null) } }
        SetRow { title: "Ouvrir sur l'écran principal"; desc: "sinon l'appli s'ouvre là où est le focus (souvent le tactile)"
                 SetSwitch { on: AppDeck.mainScreen; onToggled: Config.set("apps.main_screen", on ? false : null) } }
    }

    // ── Sections ──
    Repeater {
        model: page.deck
        delegate: SetCard {
            id: sc
            required property var modelData
            required property int index
            readonly property var items: modelData.items || []
            readonly property int slot: modelData.accent !== undefined ? modelData.accent : 11
            title: ""

            // en-tête de section : nom, couleur, ordre, suppression
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Rectangle { width: 14; height: 14; radius: 7; color: page.col(sc.slot) }
                SetInput { Layout.fillWidth: true; text: sc.modelData.title || ""; placeholder: "Nom de la section"
                           onCommitted: (t) => { if (t !== (sc.modelData.title || "")) page.edit(d => d[sc.index].title = t) } }
                SetButton { label: "󰁝"; onTap: page.edit(d => page.swap(d, sc.index, sc.index - 1)) }
                SetButton { label: "󰁅"; onTap: page.edit(d => page.swap(d, sc.index, sc.index + 1)) }
                SetButton { label: page.armed === "s" + sc.index ? "Supprimer ?" : "󰆴"; active: page.armed === "s" + sc.index
                            onTap: { if (page.armed === "s" + sc.index) { page.armed = ""; page.edit(d => d.splice(sc.index, 1)) }
                                     else { page.armed = "s" + sc.index; disarm.restart() } } }
            }
            // couleur de la section (palette)
            Row {
                spacing: 5
                Repeater {
                    model: 15
                    delegate: Rectangle {
                        required property int index
                        readonly property int s: index + 1
                        width: 20; height: 20; radius: 6
                        color: page.col(s)
                        border.width: sc.slot === s ? 2 : 0; border.color: Appearance.colors.fg
                        scale: sc.slot === s ? 1.15 : 1
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.edit(d => d[sc.index].accent = parent.s) }
                    }
                }
            }

            // applis de la section
            Repeater {
                model: sc.items
                delegate: ColumnLayout {
                    id: it
                    required property var modelData
                    required property int index
                    readonly property string key: sc.index + "/" + index
                    readonly property bool open: page.editing === key
                    Layout.fillWidth: true
                    spacing: 6
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 50; radius: 10
                        color: it.open ? ColorUtils.applyAlpha(page.col(sc.slot), 0.12) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.04)
                        border.width: 1; border.color: it.open ? ColorUtils.applyAlpha(page.col(sc.slot), 0.6) : ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
                            spacing: 10
                            Item {
                                Layout.preferredWidth: 30; Layout.preferredHeight: 30
                                Image { id: ic; anchors.fill: parent; source: AppDeck.iconSource(it.modelData.appicon); sourceSize: Qt.size(60, 60)
                                        fillMode: Image.PreserveAspectFit; asynchronous: true; visible: status === Image.Ready }
                                Text { anchors.centerIn: parent; visible: !ic.visible; text: it.modelData.icon || "󰀻"
                                       font.family: Appearance.font.family; font.pixelSize: 20; color: page.col(sc.slot) }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text { Layout.fillWidth: true; elide: Text.ElideRight; text: it.modelData.label || "(sans nom)"
                                       font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 1; color: Appearance.colors.fg }
                                Text { Layout.fillWidth: true; elide: Text.ElideRight; text: it.modelData.exec || ""
                                       font.family: "JetBrains Mono"; font.pixelSize: 10; color: Appearance.colors.dim }
                            }
                            SetButton { label: "󰐊"; onTap: AppDeck.launch(it.modelData.exec) }
                            SetButton { label: "󰁝"; onTap: page.edit(d => page.swap(d[sc.index].items, it.index, it.index - 1)) }
                            SetButton { label: "󰁅"; onTap: page.edit(d => page.swap(d[sc.index].items, it.index, it.index + 1)) }
                            // déplacer vers la section suivante (boucle)
                            SetButton { visible: page.deck.length > 1; label: "󰁔 " + ((page.deck[(sc.index + 1) % page.deck.length] || {}).title || "")
                                        onTap: page.edit(d => { const a = d[sc.index].items.splice(it.index, 1)[0]; d[(sc.index + 1) % d.length].items.push(a) }) }
                            SetButton { label: "󰏫"; active: it.open; onTap: page.editing = it.open ? "" : it.key }
                            SetButton { label: "󰆴"; onTap: { page.editing = ""; page.edit(d => d[sc.index].items.splice(it.index, 1)) } }
                        }
                    }
                    // édition de l'appli
                    GridLayout {
                        visible: it.open
                        Layout.fillWidth: true; Layout.leftMargin: 12
                        columns: 2; columnSpacing: 10; rowSpacing: 6
                        Text { text: "Nom"; font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim }
                        SetInput { Layout.fillWidth: true; text: it.modelData.label || ""; onCommitted: (t) => page.edit(d => d[sc.index].items[it.index].label = t) }
                        Text { text: "Commande"; font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim }
                        SetInput { Layout.fillWidth: true; text: it.modelData.exec || ""; placeholder: "ex. steam, flatpak run …, kitty -e btop"
                                   onCommitted: (t) => page.edit(d => d[sc.index].items[it.index].exec = t) }
                        Text { text: "Icône"; font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim }
                        SetInput { Layout.fillWidth: true; text: it.modelData.appicon || ""; placeholder: "nom d'icône du thème ou /chemin/image.png"
                                   onCommitted: (t) => page.edit(d => d[sc.index].items[it.index].appicon = t) }
                        Text { text: "Glyphe"; font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim }
                        SetInput { Layout.fillWidth: true; text: it.modelData.icon || ""; placeholder: "Nerd Font, si pas d'icône (ex. 󰊴)"
                                   onCommitted: (t) => page.edit(d => d[sc.index].items[it.index].icon = t) }
                    }
                }
            }

            RowLayout {
                spacing: 8
                SetButton { label: "󰐕  Ajouter une appli"; primary: page.pickFor === sc.index
                            onTap: { page.pickFor = page.pickFor === sc.index ? -1 : sc.index; page.query = "" } }
                SetButton { label: "󰆍  Commande perso"
                            onTap: { page.edit(d => d[sc.index].items.push({ label: "Nouvelle appli", exec: "", appicon: "", icon: "󰀻" }))
                                     page.editing = sc.index + "/" + sc.items.length } }
            }

            // sélecteur d'applis installées
            ColumnLayout {
                visible: page.pickFor === sc.index
                Layout.fillWidth: true
                spacing: 8
                SetInput { Layout.fillWidth: true; placeholder: "󰍉  Chercher parmi " + page.installed.length + " applis…"
                           onTextChanged: page.query = text }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 280; radius: 10
                    color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.55)
                    border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.08)
                    clip: true
                    GridView {
                        anchors { fill: parent; margins: 6 }
                        cellWidth: width / Math.max(1, Math.floor(width / 220)); cellHeight: 52
                        model: page.found
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Item {
                            id: ap
                            required property var modelData
                            readonly property bool added: sc.items.some(x => x.exec === modelData.exec)
                            width: GridView.view.cellWidth; height: 52
                            Rectangle {
                                anchors { fill: parent; margins: 3 }
                                radius: 8
                                color: apMa.containsMouse ? ColorUtils.applyAlpha(page.col(sc.slot), 0.16) : "transparent"
                                RowLayout {
                                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                    spacing: 8
                                    Image { Layout.preferredWidth: 28; Layout.preferredHeight: 28; source: AppDeck.iconSource(ap.modelData.icon)
                                            sourceSize: Qt.size(56, 56); fillMode: Image.PreserveAspectFit; asynchronous: true }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text { Layout.fillWidth: true; elide: Text.ElideRight; text: ap.modelData.name
                                               font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 2; color: Appearance.colors.fg }
                                        Text { Layout.fillWidth: true; elide: Text.ElideRight; text: ap.modelData.comment
                                               font.family: Appearance.font.family; font.pixelSize: 9; color: Appearance.colors.dim }
                                    }
                                    Text { text: ap.added ? "✓" : "󰐕"; font.family: Appearance.font.family; font.pixelSize: 14
                                           color: ap.added ? "#7ee2a8" : Appearance.colors.dim }
                                }
                                MouseArea { id: apMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: if (!ap.added) page.addApp(sc.index, ap.modelData) }
                            }
                        }
                    }
                    Text { anchors.centerIn: parent; visible: page.found.length === 0
                           text: page.installed.length ? "Aucune appli ne correspond" : "Lecture des applis…"
                           font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim }
                }
            }
        }
    }

    RowLayout {
        spacing: 8
        SetButton { label: "󰐕  Nouvelle section"; primary: true
                    onTap: page.edit(d => d.push({ title: "Nouvelle section", accent: 1 + (d.length * 2 + 3) % 15, items: [] })) }
        SetButton { label: "󰐊  Voir l'onglet Apps"
                    onTap: {
                        // active l'onglet s'il était masqué, allume le panneau et bascule dessus
                        if (!TouchTabs.tabs.some(t => t.key === "deck" && t.on))
                            TouchTabs.save(TouchTabs.tabs.map(t => Object.assign({}, t, t.key === "deck" ? { on: true } : {})))
                        ShellState.touchPanelOn = true
                        Popups.touchPage = "deck"
                    } }
    }
}
