import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.core
import qs.core.functions
import qs.pages.settings

// SettingsPanel — fenêtre Réglages, au centre de l'écran principal.
// Ouverture : tuile « Config » des réglages rapides, SUPER+F1, `qs ipc call settings toggle`
// (ou `open <page>`). Les pages sont dans pages/settings/ ; tout s'écrit dans config.toml
// via Config.set() (commentaires gardés, appliqué en direct).
PanelWindow {
    id: root

    // Écran principal = tout sauf le tactile Xeneon
    screen: {
        const all = Quickshell.screens
        return all.find(s => !Config.isTouch(s)) || all[0]
    }
    color: "transparent"
    visible: windowVisible
    // Fenêtre flottante de la taille du panneau (plus de voile plein écran) : le reste de l'écran
    // reste utilisable pour voir les changements ; fermeture par la croix, Échap ou SUPER+F1.
    // Déplaçable en glissant le titre « Réglages ».
    anchors { top: true; left: true }
    margins { left: Math.round(posX); top: Math.round(posY) }
    implicitWidth:  fullW + 8
    implicitHeight: fullH + 8
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell:settings"
    WlrLayershell.keyboardFocus: (windowVisible && Popups.settingsOpen) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    readonly property real scrW: screen ? screen.width : 1920
    readonly property real scrH: screen ? screen.height : 1080
    property real posX: (scrW - implicitWidth) / 2
    property real posY: (scrH - implicitHeight) / 2

    // ── Pages ─────────────────────────────────────────────────────────────
    // src = page construite (voir pageLoader.pages) ; sinon PlannedPage avec `plan`.
    readonly property var tabs: [
        { key: "general", group: "Général", ic: "󰒓", name: "Général", kw: "profil avatar photo nom terminal kitty éditeur mise à jour écrans tactile xeneon", src: "general" },
        { key: "theme", group: "Apparence", ic: "󰏘", name: "Thème", kw: "thèmes préréglages presets accent bordures animées contour vitesse arrondi rayon formes", src: "theme" },
        { key: "colors", group: "Apparence", ic: "󰸌", name: "Couleurs", kw: "palette wallust matugen material you chemin", src: "colors" },
        { key: "fonts", group: "Apparence", ic: "󰛖", name: "Police", kw: "police famille taille texte nerd font", src: "fonts" },
        { key: "anim", group: "Apparence", ic: "󰑓", name: "Animations", kw: "durée vitesse ouverture rapide instantané aucune animation onglets transition goutte bulle iris rebond carte tourbillon rideau zoom montée glissement fondu", src: "anim" },
        { key: "bar", group: "Barre", ic: "󰍜", name: "Modules", kw: "barre modules ordre gauche centre droite masquer options géométrie hauteur séparateurs horloge format", src: "bar" },
        { key: "barint", group: "Barre", ic: "󰔛", name: "Rafraîchissement", kw: "intervalles mises à jour réseau bluetooth stats volume santé secondes cpu", src: "refresh" },
        { key: "dash", group: "Panneaux", ic: "󰕮", name: "Dashboard", kw: "taille onglets accueil", src: "dashboard" },
        { key: "touch", group: "Panneaux", ic: "󰦧", name: "Panneau tactile", kw: "zoom onglets pause jeu xeneon", src: "touch" },
        { key: "devices", group: "Panneaux", ic: "󰁹", name: "Périphériques", kw: "périphériques devices batterie photo image souris manette casque notification connexion boutique", src: "devices" },
        { key: "apps", group: "Panneaux", ic: "󰀻", name: "Apps", kw: "applications lanceurs deck tuiles sections raccourcis apps", src: "apps" },
        { key: "spotify", group: "Panneaux", ic: "󰓇", name: "Spotify et média", kw: "spotify lecteur pochette", src: "spotify" },
        { key: "session", group: "Panneaux", ic: "󰐥", name: "Écran de session", kw: "session déconnexion éteindre redémarrer verrouiller veille bios matrix minimal ctrl alt p", src: "session" },
        { key: "notif", group: "Panneaux", ic: "󰂚", name: "Notifications", kw: "toasts swaync durée position ne pas déranger", src: "notif" },
        { key: "wall", group: "Multimédia", ic: "󰸉", name: "Fond d'écran", kw: "dossiers rotation effets shaders", src: "wall" },
        { key: "audio", group: "Multimédia", ic: "󰓃", name: "Audio et EQ", kw: "égaliseur presets easyeffects sortie", src: "audio" },
        { key: "rec", group: "Multimédia", ic: "󰻂", name: "Capture d'écran", kw: "enregistrement dossier format wf-recorder", src: "capture" },
        { key: "game", group: "Jeu", ic: "󰊴", name: "Mode jeu", kw: "jeu eq rgb pause tactile gamemode", src: "game" },
        { key: "system", group: "Système", ic: "󰍛", name: "Stats et seuils", kw: "stats seuils alertes cpu gpu nvme énergie", src: "stats" },
        { key: "health", group: "Système", ic: "󰓙", name: "Santé", kw: "proxmox bilan santé intervalle", src: "health" },
        { key: "deps", group: "Système", ic: "󰏗", name: "Dépendances", kw: "logiciels paquets polices modules python manquants installer distribution", src: "deps" },
        { key: "keys", group: "Avancé", ic: "󰌌", name: "Raccourcis", kw: "keybinds hyprland", src: "keys" },
        { key: "data", group: "Avancé", ic: "󰆓", name: "Données", kw: "sauvegarde export réinitialiser config.toml", src: "data" }
    ]
    // Onglet actif, retenu entre deux ouvertures et deux sessions (user_data/shell_state.json)
    property string page: ShellState.settingsTab
    onPageChanged: if (tabs.some(t => t.key === page)) ShellState.settingsTab = page
    property string query: ""
    readonly property var matches: query.trim() === "" ? []
        : tabs.filter(t => (t.name + " " + t.kw).toLowerCase().includes(query.trim().toLowerCase())).map(t => t.key)
    onMatchesChanged: if (matches.length && matches.indexOf(page) < 0) page = matches[0]

    // ── Ouverture / fermeture ─────────────────────────────────────────────
    property bool windowVisible: false
    // créé par un LazyLoader (shell.qml) quand on l'ouvre, détruit après la fermeture : aucune RAM fermé
    Component.onCompleted: { if (Popups.settingsOpen) openConn.onSettingsOpenChanged() }
    Connections {
        id: openConn
        target: Popups
        function onSettingsOpenChanged() {
            if (Popups.settingsOpen) {
                if (Popups.settingsPage !== "") { root.page = Popups.settingsPage; Popups.settingsPage = "" }
                closeTimer.stop(); root.windowVisible = true; keys.forceActiveFocus()
                closeAnim.stop(); openAnim.restart()
            } else {
                openAnim.stop(); closeAnim.restart(); closeTimer.restart()
            }
        }
    }
    // Saut vers une page pendant que la fenêtre est ouverte (liens entre pages)
    Connections {
        target: Popups
        function onSettingsPageChanged() {
            if (Popups.settingsOpen && Popups.settingsPage !== "") { root.page = Popups.settingsPage; Popups.settingsPage = "" }
        }
    }
    Timer { id: closeTimer; interval: 760; onTriggered: root.windowVisible = false }

    // commandes IPC : dans shell.qml (le panneau n'existe que lorsqu'il est ouvert)

    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: Popups.settingsOpen = false
    }


    // ── Fenêtre : forme animée (ligne → pilule → déroulé) ─────────────────
    readonly property real fullW: Math.min(1180, scrW - 80)
    readonly property real fullH: Math.min(780, scrH - 100)
    // état de départ = fermé (le panneau est créé à l'ouverture : sinon 1re image en grand, puis l'animation)
    property real mw: 2
    property real mh: 2
    property real mr: Appearance.cornerRadius
    property real content: 0

    SequentialAnimation {
        id: openAnim
        ScriptAction { script: { root.mw = 2; root.mh = 2; root.mr = 1; root.content = 0 } }
        // 1. une ligne s'étire depuis le centre
        NumberAnimation { target: root; property: "mw"; to: root.fullW * 0.8; duration: Appearance.dur(340); easing.type: Easing.OutCubic }
        // 2. elle s'épaissit en pilule et prend toute la largeur
        ParallelAnimation {
            NumberAnimation { target: root; property: "mh"; to: 44; duration: Appearance.dur(300); easing.type: Easing.OutBack; easing.overshoot: 1.6 }
            NumberAnimation { target: root; property: "mr"; to: 22; duration: Appearance.dur(300); easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "mw"; to: root.fullW; duration: Appearance.dur(300); easing.type: Easing.OutCubic }
        }
        // 3. elle se déroule vers le haut et le bas, le contenu apparaît en fin de course
        ParallelAnimation {
            NumberAnimation { target: root; property: "mh"; to: root.fullH; duration: Appearance.dur(460); easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "mr"; to: Appearance.cornerRadius; duration: Appearance.dur(460); easing.type: Easing.InOutCubic }
            SequentialAnimation {
                PauseAnimation { duration: Appearance.dur(220) }
                NumberAnimation { target: root; property: "content"; to: 1; duration: Appearance.dur(300); easing.type: Easing.OutCubic }
            }
        }
        ScriptAction { script: { root.mw = Qt.binding(() => root.fullW); root.mh = Qt.binding(() => root.fullH) } }
    }
    SequentialAnimation {
        id: closeAnim
        ScriptAction { script: { root.mw = root.fullW; root.mh = root.fullH } }
        NumberAnimation { target: root; property: "content"; to: 0; duration: Appearance.dur(140) }
        ParallelAnimation {
            NumberAnimation { target: root; property: "mh"; to: 44; duration: Appearance.dur(300); easing.type: Easing.InOutCubic }
            NumberAnimation { target: root; property: "mr"; to: 22; duration: Appearance.dur(300); easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "mw"; to: 2; duration: Appearance.dur(260); easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "mh"; to: 2; duration: Appearance.dur(260); easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "mr"; to: 1; duration: Appearance.dur(260); easing.type: Easing.InCubic }
        }
    }

    ClippingRectangle {
        id: box
        x: (root.width - root.mw) / 2
        y: (root.height - root.mh) / 2
        width: root.mw; height: root.mh
        radius: Math.min(root.mr, height / 2)
        color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.97)
        // absorbe les clics (ne ferme pas la fenêtre)
        MouseArea { anchors.fill: parent }

        // Contenu pleine taille, recalé au centre pendant la transformation
        Item {
            x: (root.mw - root.fullW) / 2
            y: (root.mh - root.fullH) / 2
            width: root.fullW; height: root.fullH
            opacity: root.content
            transform: Translate { y: (1 - root.content) * 10 }

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // ── Barre latérale ──
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 250
                    color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.02)
                    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.07) }

                    ColumnLayout {
                        anchors { fill: parent; margins: 16 }
                        spacing: 12
                        RowLayout {
                            spacing: 10
                            Rectangle { width: 30; height: 30; radius: 10; color: Appearance.colors.accent
                                Text { anchors.centerIn: parent; text: "󰒓"; font.family: Appearance.font.family; font.pixelSize: 16; color: Appearance.textOn(Appearance.colors.accent) } }
                            Text {
                                text: "Réglages"; font.family: Appearance.font.family; font.pixelSize: 20; font.weight: Font.Bold; color: Appearance.colors.fg
                                // glisser le titre = déplacer la fenêtre
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -8
                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    property point start
                                    onPressed: (e) => start = mapToGlobal(e.x, e.y)
                                    onPositionChanged: (e) => {
                                        const g = mapToGlobal(e.x, e.y)
                                        root.posX = Math.max(0, Math.min(root.scrW - root.implicitWidth, root.posX + g.x - start.x))
                                        root.posY = Math.max(0, Math.min(root.scrH - root.implicitHeight, root.posY + g.y - start.y))
                                        start = g
                                    }
                                }
                            }
                        }
                        SetInputLite {
                            id: search
                            Layout.fillWidth: true
                            onTextChanged: root.query = text
                        }
                        Flickable {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            contentHeight: tabCol.implicitHeight
                            clip: true; boundsBehavior: Flickable.StopAtBounds
                            ColumnLayout {
                                id: tabCol
                                width: parent.width
                                spacing: 2
                                Repeater {
                                    model: root.tabs
                                    delegate: ColumnLayout {
                                        id: tabItem
                                        required property var modelData
                                        required property int index
                                        readonly property bool firstOfGroup: index === 0 || root.tabs[index - 1].group !== modelData.group
                                        readonly property bool on: root.page === modelData.key
                                        readonly property bool hit: root.matches.indexOf(modelData.key) >= 0
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            visible: tabItem.firstOfGroup
                                            Layout.topMargin: tabItem.index === 0 ? 0 : 10
                                            leftPadding: 10
                                            text: tabItem.modelData.group
                                            font.family: Appearance.font.family; font.pixelSize: 10; font.weight: Font.DemiBold
                                            font.letterSpacing: 1.8; font.capitalization: Font.AllUppercase
                                            color: Appearance.colors.dim
                                        }
                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 34; radius: 10
                                            color: tabItem.on ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.22)
                                                 : tabMa.containsMouse ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.06) : "transparent"
                                            border.width: tabItem.hit ? 1 : 0; border.color: Appearance.colors.accent
                                            Behavior on color { ColorAnimation { duration: Appearance.dur(150) } }
                                            Rectangle { visible: tabItem.on; x: 0; y: 8; width: 3; height: parent.height - 16; radius: 2; color: Appearance.colors.accent }
                                            RowLayout {
                                                anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
                                                spacing: 10
                                                Text { text: tabItem.modelData.ic; font.family: Appearance.font.family; font.pixelSize: 15
                                                       color: tabItem.on ? Appearance.colors.accent : Appearance.colors.dim }
                                                Text { Layout.fillWidth: true; text: tabItem.modelData.name; elide: Text.ElideRight
                                                       font.family: Appearance.font.family; font.pixelSize: Appearance.font.small
                                                       color: tabItem.on ? Appearance.colors.fg : ColorUtils.applyAlpha(Appearance.colors.fg, 0.7) }
                                                Text { visible: !tabItem.modelData.src; text: "bientôt"; font.family: Appearance.font.family; font.pixelSize: 9; color: Appearance.colors.dim }
                                            }
                                            MouseArea { id: tabMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.page = tabItem.modelData.key }
                                        }
                                    }
                                }
                            }
                        }
                        // État d'enregistrement : clignote à chaque écriture de config.toml
                        Column {
                            spacing: 3
                            Text {
                                id: savedTxt
                                text: "● enregistré"
                                font.family: Appearance.font.family; font.pixelSize: 11; color: "#7ee2a8"
                                SequentialAnimation on scale {
                                    id: flash; running: false
                                    NumberAnimation { to: 1.15; duration: Appearance.dur(120) }
                                    NumberAnimation { to: 1; duration: Appearance.dur(260); easing.type: Easing.OutBack }
                                }
                                Connections { target: Config; function onSaved() { flash.restart() } }
                            }
                            Text { text: "config.toml · appliqué en direct"; font.family: Appearance.font.family; font.pixelSize: 10; color: Appearance.colors.dim }
                        }
                    }
                }

                // ── Contenu de la page ──
                Flickable {
                    id: pageFlick
                    Layout.fillWidth: true; Layout.fillHeight: true
                    contentHeight: pageLoader.item ? pageLoader.item.implicitHeight + 56 : 0
                    clip: true; boundsBehavior: Flickable.StopAtBounds
                    Loader {
                        id: pageLoader
                        x: 28; y: 24
                        width: pageFlick.width - 56
                        readonly property var tab: root.tabs.find(t => t.key === root.page) || root.tabs[0]
                        onTabChanged: {
                            pageFlick.contentY = 0
                            sourceComponent = pages[tab.src || "plan"]
                        }
                        Component.onCompleted: tabChanged()
                        onLoaded: if (item) item.width = Qt.binding(() => pageLoader.width)
                        readonly property var pages: ({ colors: colorsC, fonts: fontsC, deps: depsC, bar: barC, theme: themeC, general: generalC, anim: animC, refresh: refreshC, dashboard: dashboardC, touch: touchC, devices: devicesC, spotify: spotifyC, notif: notifC, wall: wallC, audio: audioC, capture: captureC, game: gameC, stats: statsC, health: healthC, keys: keysC, data: dataC, apps: appsC, session: sessionC, plan: planC })
                        Component { id: colorsC; ColorsPage {} }
                        Component { id: fontsC; FontsPage {} }
                        Component { id: depsC; DepsPage {} }
                        Component { id: barC; BarPage {} }
                        Component { id: themeC; ThemePage {} }
                        Component { id: generalC; GeneralPage {} }
                        Component { id: animC; AnimPage {} }
                        Component { id: refreshC; RefreshPage {} }
                        Component { id: dashboardC; DashboardPage {} }
                        Component { id: touchC; TouchPage {} }
                        Component { id: devicesC; DevicesPage {} }
                        Component { id: spotifyC; SpotifyPage {} }
                        Component { id: notifC; NotifPage {} }
                        Component { id: wallC; WallPage {} }
                        Component { id: audioC; AudioPage {} }
                        Component { id: captureC; CapturePage {} }
                        Component { id: gameC; GamePage {} }
                        Component { id: statsC; StatsPage {} }
                        Component { id: healthC; HealthPage {} }
                        Component { id: keysC; KeysPage {} }
                        Component { id: dataC; DataPage {} }
                        Component { id: appsC; AppsPage {} }
                        Component { id: sessionC; SessionPage {} }
                        Component { id: planC; PlannedPage { title: pageLoader.tab.name; items: pageLoader.tab.plan } }
                        opacity: status === Loader.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Appearance.dur(180) } }
                    }
                }
            }

            // Fermer
            Rectangle {
                anchors { top: parent.top; right: parent.right; margins: 14 }
                width: 32; height: 32; radius: 10
                color: ColorUtils.applyAlpha(Appearance.colors.fg, xMa.containsMouse ? 0.12 : 0.05)
                Text { anchors.centerIn: parent; text: "󰅖"; font.family: Appearance.font.family; font.pixelSize: 15; color: Appearance.colors.fg }
                MouseArea { id: xMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Popups.settingsOpen = false }
            }
        }
    }

    // Bordure en dégradé animé, qui suit la forme
    GradientBorder {
        x: box.x; y: box.y; width: box.width; height: box.height
        radius: box.radius
        borderWidth: 2
        visible: Appearance.animationsEnabled && root.windowVisible
    }
    Rectangle {
        x: box.x; y: box.y; width: box.width; height: box.height
        radius: box.radius; color: "transparent"
        border.width: 2; border.color: Appearance.outline
        visible: !Appearance.animationsEnabled && root.windowVisible
    }

    // Champ de recherche de la barre latérale
    component SetInputLite: Rectangle {
        property alias text: inp.text
        implicitHeight: 36; radius: 10
        color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.05)
        border.width: 1; border.color: inp.activeFocus ? Appearance.colors.accent : ColorUtils.applyAlpha(Appearance.colors.fg, 0.1)
        Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "󰍉"; font.family: Appearance.font.family; font.pixelSize: 14; color: Appearance.colors.dim }
        TextInput {
            id: inp
            anchors { fill: parent; leftMargin: 32; rightMargin: 10 }
            verticalAlignment: TextInput.AlignVCenter
            clip: true; selectByMouse: true
            font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 1; color: Appearance.colors.fg
            Keys.onEscapePressed: { if (text !== "") text = ""; else Popups.settingsOpen = false }
            Text { anchors.verticalCenter: parent.verticalCenter; visible: inp.text === "" && !inp.activeFocus
                   text: "Rechercher un réglage…"; font: inp.font; color: Appearance.colors.dim }
        }
    }
}
