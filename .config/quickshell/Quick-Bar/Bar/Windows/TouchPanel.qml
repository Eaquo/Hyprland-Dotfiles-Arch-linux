import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import "../Common/"
import "../Common/functions/"
import "../Services/"

// TouchPanel — panneau plein écran sur le tactile Corsair Xeneon Edge.
//
// Même principe que le Dashboard : une barre d'onglets (ici agrandie pour le
// tactile) qui réutilise directement les pages du Dashboard —
//   DashHome · DashStats · KanbanBoard · FileBrowser · WallpaperTab · EqDash.
//
// Layer Overlay opaque (fond = wallpaper courant flouté) → les applications sous
// le panneau sont masquées. Activé par ShellState.touchPanelOn (tuile Quick
// Settings). Écran cible = Xeneon Edge (par modèle), sinon le plus petit écran.
Scope {
    id: root

    property string page: "home"

    // Écran cible = Xeneon Edge (par modèle), sinon le plus petit écran.
    readonly property var targetScreen: {
        var all = Quickshell.screens
        for (var i = 0; i < all.length; i++)
            if ((all[i].model || "").toUpperCase().indexOf("XENEON") !== -1) return all[i]
        var s = null, best = 1e12
        for (var j = 0; j < all.length; j++) {
            var a = all[j].width * all[j].height
            if (a < best) { best = a; s = all[j] }
        }
        return s
    }

    // ── Onglets : catalogue (ordre/état par défaut) ─────────────────────────────
    // L'ordre et l'activation réels viennent de ShellState.touchTabs (bouton ⚙).
    // Un onglet ajouté ici plus tard apparaît automatiquement en fin de liste.
    readonly property var allTabs: [
        { key: "game",   icon: "󰮂", label: "Game"   },   // visible seulement en jeu
        { key: "home",   icon: "󰋜", label: "Home"   },
        { key: "grid",   icon: "󰕰", label: "Grid"   },
        { key: "ws",     icon: "󱂬", label: "Spaces" },
        { key: "stats",  icon: "󰻠", label: "System" },
        { key: "kanban", icon: "󰄬", label: "Tasks",  def: false },
        { key: "files",  icon: "󰉋", label: "Files"  },
        { key: "wall",   icon: "󰸉", label: "Wall"   },
        { key: "colors", icon: "󰏘", label: "Wallust"},
        { key: "eq",     icon: "󰓃", label: "Eq"     },
        { key: "mixer",  icon: "󰕾", label: "Mixer"  },
        { key: "discord",icon: "󰙯", label: "Discord"},
        { key: "deck",   icon: "󰀻", label: "Apps"   },
        { key: "games",  icon: "󰊴", label: "Games"  },
        { key: "rgb",    icon: "󰌵", label: "RGB"    },
    ]

    // Catalogue fusionné avec la config sauvée : [{ key, icon, label, on }].
    readonly property var tabs: {
        const byKey = {}, seen = {}, out = []
        for (const t of allTabs) byKey[t.key] = t
        for (const s of (ShellState.touchTabs || []))
            if (byKey[s.key] && !seen[s.key]) {
                seen[s.key] = true
                out.push(Object.assign({}, byKey[s.key], { on: s.on !== false }))
            }
        for (const t of allTabs)
            if (!seen[t.key]) out.push(Object.assign({}, t, { on: t.def !== false }))
        return out
    }
    readonly property var visibleTabs: tabs.filter(t => t.on && (t.key !== "game" || GameMode.active))

    // Mode jeu : bascule sur la page Game au lancement, revient après.
    property string _pageBeforeGame: ""
    Connections {
        target: GameMode
        function onActiveChanged() {
            if (GameMode.active) {
                if (root.page !== "game") root._pageBeforeGame = root.page
                root.page = "game"
            } else if (root._pageBeforeGame !== "") {
                root.page = root._pageBeforeGame
                root._pageBeforeGame = ""
            }
        }
    }

    function saveTabs(list) { ShellState.touchTabs = list.map(t => ({ key: t.key, on: t.on })) }
    function toggleTab(i) {
        const l = tabs.slice()
        // Au moins un onglet reste actif.
        if (l[i].on && visibleTabs.length <= 1) return
        l[i] = Object.assign({}, l[i], { on: !l[i].on })
        saveTabs(l)
    }
    function moveTab(i, d) {
        const j = i + d
        if (j < 0 || j >= tabs.length) return
        const l = tabs.slice()
        const t = l[i]; l[i] = l[j]; l[j] = t
        saveTabs(l)
    }
    // Page courante désactivée → bascule sur le 1er onglet visible.
    onVisibleTabsChanged: if (!visibleTabs.some(t => t.key === page) && visibleTabs.length) page = visibleTabs[0].key

    property bool configOpen: false

    // ── Transition entre onglets : la page arrive du côté de l'onglet choisi ──
    property int _lastIdx: 0
    property int slideDir: 1
    onPageChanged: {
        const i = visibleTabs.findIndex(t => t.key === page)
        slideDir = i >= _lastIdx ? 1 : -1
        _lastIdx = i
        pageSlide.restart()
    }
    function stepTab(d) {
        const i = visibleTabs.findIndex(t => t.key === page)
        const j = Math.max(0, Math.min(visibleTabs.length - 1, i + d))
        if (j !== i) { page = visibleTabs[j].key; GameBreak.extend() }
    }

    // Palette wallust vive : chaque onglet cycle dessus (icône/label/pastille).
    readonly property var _wpal: [
        Appearance.colors.color4,  Appearance.colors.color5,  Appearance.colors.color6,
        Appearance.colors.color9,  Appearance.colors.color10, Appearance.colors.color11,
        Appearance.colors.color12, Appearance.colors.color13, Appearance.colors.color14
    ]

    // Facteur de zoom par page (tactile = grand écran → on agrandit les pages
    // pensées pour le popup ~900px). 1.0 = taille native. Réglable tab par tab.
    readonly property var pageScale: ({
        "game":   1.0,
        "home":   1.0,
        "grid":   1.0,
        "ws":     1.0,
        "stats":  1.15,
        "kanban": 1.15,
        "files":  1.35,
        "wall":   1.0,
        "colors": 1.0,
        "eq":     1.0,
        "mixer":  1.0,
        "discord":1.0,
        "deck":   1.0,
        "games":  1.0,
        "rgb":    1.0
    })

    // ── Horloge (coin haut-droit) ────────────────────────────────────────────────
    property string clockH:    "--:--"
    property string clockDate: ""
    Timer {
        interval: 1000; running: ShellState.touchPanelOn; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date()
            root.clockH    = Qt.formatTime(d, "HH:mm")
            root.clockDate = Qt.formatDate(d, "dddd d MMMM")
        }
    }

    // À l'ouverture : reset sur "home" + focaliser le Xeneon. Une fois le
    // moniteur tactile focalisé, les taps 1 doigt cliquent nativement (sinon il
    // faut le tap 2 doigts hyprgrass juste pour prendre le focus). `silent` des
    // lancements d'apps → le focus reste sur le Xeneon pendant la session.
    Process { id: focusProc }
    Connections {
        target: ShellState
        function onTouchPanelOnChanged() {
            if (ShellState.touchPanelOn) {
                root.page = root.visibleTabs.length ? root.visibleTabs[0].key : "home"
                root.configOpen = false
                if (root.targetScreen) {
                    focusProc.command = ["hyprctl", "eval",
                        "hl.dispatch(hl.dsp.focus({ monitor = [[" + root.targetScreen.name + "]] }))"]
                    focusProc.running = false
                    focusProc.running = true
                }
            }
        }
    }


    PanelWindow {
        id: win
        screen:  root.targetScreen
        visible: ShellState.touchPanelOn && root.targetScreen !== null

        WlrLayershell.layer:     WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:touchpanel"
        // Focus clavier à la demande (onglet Discord) — permet à un TextInput de
        // recevoir la frappe. NB : sans clavier physique, la saisie tactile passe
        // par l'OSK (à ajouter). Sur le Dashboard (écran principal) ça marche déjà.
        // OnDemand permanent : n'importe quel TextInput (recherche, Discord, Files…)
        // peut prendre le focus clavier au clic, sans le voler autrement.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true; right: true; bottom: true }
        color: Appearance.colors.bg

        // ── Fond : wallpaper courant, flouté + voile sombre ────────────────────
        // En mode vidéo, currentWall est un .mp4 (non affichable par Image) → on
        // retombe sur la vignette statique écrite par set-video-wallpaper.sh.
        Image {
            id: bgWall
            anchors.fill: parent; visible: false
            cache: false
            // Fond fortement flouté → une basse résolution suffit largement et
            // économise beaucoup de mémoire texture (un 4K = ~35 Mo décodé).
            sourceSize.width: 1000
            // En jeu : bannière du jeu (cache Steam) au lieu du wallpaper.
            source: GameMode.active && GameMode.gameArt !== "" ? GameMode.gameArt
                : WallpaperState.videoMode
                ? "file://" + Quickshell.env("HOME") + "/.curr_wall_static.jpg"
                : (WallpaperState.currentWall !== "" ? "file://" + WallpaperState.currentWall : "")
            fillMode: Image.PreserveAspectCrop
        }
        MultiEffect {
            anchors.fill: parent
            source: bgWall
            // Visible dès que la vignette/le wallpaper est chargé — indépendant de
            // currentWall (vide en mode vidéo), sinon écran noir sur une vidéo.
            visible: bgWall.status === Image.Ready
            blurEnabled: true; blur: 0.6; blurMax: 24; brightness: -0.15
        }
        // Voile sombre pour la lisibilité des cartes des pages.
        Rectangle { anchors.fill: parent; color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.6) }

        // ── Contenu : barre d'onglets + zone de page ───────────────────────────
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 20

            // ══ Barre du haut : onglets CENTRÉS + horloge/fermer à droite ══
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 72

                // Swipe horizontal sur la barre → onglet voisin (les taps passent).
                DragHandler {
                    target: null
                    yAxis.enabled: false
                    onActiveChanged: if (!active) {
                        if (translation.x < -80) root.stepTab(1)
                        else if (translation.x > 80) root.stepTab(-1)
                    }
                }

                // Onglets centrés horizontalement (droitier → main droite plus rapide).
                // Trop d'onglets pour la largeur → compact : seul l'onglet actif
                // garde son libellé, les autres = icône seule.
                Row {
                    id: tabRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter:   parent.verticalCenter
                    spacing: 10
                    // Police monospace : ~12 px/caractère à 20 px ; icône 30 + marges 52 + espacement.
                    readonly property real fullWidth: root.visibleTabs.reduce(
                        (w, t) => w + t.label.length * 12 + 30 + 52 + 10, 0)
                    readonly property bool compact: fullWidth > parent.width - 2 * (rightBlock.width + 24)
                    Repeater {
                        model: root.visibleTabs
                        delegate: Rectangle {
                            id: tab
                            required property var modelData
                            required property int index
                            readonly property bool isActive: root.page === modelData.key
                            readonly property color wcol: root._wpal[index % root._wpal.length]
                            // Éclaircie pour rester lisible sur fond sombre.
                            readonly property color wbright: Qt.lighter(wcol, 1.35)
                            width:  tabContent.implicitWidth + 40
                            height: 72
                            radius: 20
                            // Actif : pastille pleine dans la couleur wallust de l'onglet.
                            // Inactif : teinte douce de la même couleur.
                            color: isActive
                                ? ColorUtils.applyAlpha(wbright, 0.9)
                                : ColorUtils.applyAlpha(wbright, 0.16)
                            border.color: isActive ? "transparent" : ColorUtils.applyAlpha(wbright, 0.5)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 140 } }

                            Row {
                                id: tabContent
                                anchors.centerIn: parent
                                spacing: 12
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.icon
                                    font.family: Appearance.font.family; font.pixelSize: 30
                                    color: tab.isActive ? Appearance.colors.bg : tab.wbright
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !tabRow.compact || tab.isActive
                                    text: modelData.label
                                    font.family: Appearance.font.family; font.pixelSize: 20
                                    font.weight: tab.isActive ? Font.Bold : Font.Medium
                                    color: tab.isActive ? Appearance.colors.bg : Appearance.colors.fg
                                }
                            }
                            // GameBreak.extend() : naviguer dans le panneau relance le
                            // compte à rebours de la pause jeu (sinon on est renvoyé
                            // au jeu en plein milieu d'une manip).
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { root.page = modelData.key; GameBreak.extend() }
                            }
                        }
                    }
                }

                // Horloge + bouton fermer, ancrés à droite.
                Row {
                    id: rightBlock
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16

                    // Config des onglets (activer / réordonner).
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 56; height: 56; radius: 16
                        color: root.configOpen ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.9)
                                               : ColorUtils.applyAlpha(Appearance.colors.bg, 0.45)
                        border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Text {
                            anchors.centerIn: parent; text: "󰒓"
                            font.family: Appearance.font.family; font.pixelSize: 26
                            color: root.configOpen ? Appearance.colors.bg : Appearance.colors.fg
                        }
                        MouseArea { anchors.fill: parent; onClicked: { root.configOpen = !root.configOpen; GameBreak.extend() } }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        Text {
                            anchors.right: parent.right
                            text: root.clockH
                            font.family: Appearance.font.family; font.pixelSize: 34; font.weight: Font.Bold
                            color: Appearance.colors.fg
                        }
                        Text {
                            anchors.right: parent.right
                            text: root.clockDate
                            font.family: Appearance.font.family; font.pixelSize: 14
                            color: Appearance.colors.dim
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 72; height: 72; radius: 20
                        color: closeHov.hovered ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.9)
                                                : ColorUtils.applyAlpha(Appearance.colors.bg, 0.45)
                        border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Text {
                            anchors.centerIn: parent; text: "󰅖"
                            font.family: Appearance.font.family; font.pixelSize: 30
                            color: closeHov.hovered ? Appearance.colors.bg : Appearance.colors.fg
                        }
                        HoverHandler { id: closeHov }
                        MouseArea { anchors.fill: parent; onClicked: ShellState.touchPanelOn = false }
                    }
                }
            }

            // ══ Zone de page — réutilise directement les pages du Dashboard ══
            Item {
                id: pageArea
                Layout.fillWidth: true
                Layout.fillHeight: true
                transform: Translate { id: pageShift }

                ParallelAnimation {
                    id: pageSlide
                    NumberAnimation {
                        target: pageShift; property: "x"
                        from: root.slideDir * 90; to: 0
                        duration: 280; easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: pageArea; property: "opacity"
                        from: 0.25; to: 1
                        duration: 240; easing.type: Easing.OutQuad
                    }
                }

                // Page zoomée : le contenu est mis en page dans une boîte logique
                // (taille / s) puis mise à l'échelle s → remplit toute la zone en
                // plus grand. Texte distance-field → reste net.
                component ScaledPage: Item {
                    id: sp
                    property real s: 1.0
                    anchors.fill: parent
                    default property alias content: holder.data
                    Item {
                        id: holder
                        width:  sp.width  > 0 ? sp.width  / sp.s : 0
                        height: sp.height > 0 ? sp.height / sp.s : 0
                        transformOrigin: Item.TopLeft
                        scale: sp.s
                    }
                }

                // home/stats/games restent instanciés (défaut + évite le re-scan
                // des jeux). Les autres sont lazy-loadés (Loader active) → libérés
                // quand l'onglet n'est pas affiché = grosse économie de RAM.
                ScaledPage {
                    visible: root.page === "game";   s: root.pageScale["game"]
                    Loader { anchors.fill: parent; active: root.page === "game"; source: "../Services/GameModeTab.qml" }
                }
                ScaledPage {
                    visible: root.page === "home";   s: root.pageScale["home"]
                    TouchHome { anchors.fill: parent }
                }
                ScaledPage {
                    visible: root.page === "grid";   s: root.pageScale["grid"]
                    Loader { anchors.fill: parent; active: root.page === "grid"; source: "../Services/GridDash.qml" }
                }
                ScaledPage {
                    visible: root.page === "ws";     s: root.pageScale["ws"]
                    Loader { anchors.fill: parent; active: root.page === "ws"; source: "../Services/WorkspacesTab.qml" }
                }
                ScaledPage {
                    visible: root.page === "stats";  s: root.pageScale["stats"]
                    TouchStats { anchors.fill: parent }
                }
                ScaledPage {
                    visible: root.page === "kanban"; s: root.pageScale["kanban"]
                    Loader { anchors.fill: parent; active: root.page === "kanban"; source: "../Services/KanbanBoard.qml" }
                }
                ScaledPage {
                    visible: root.page === "files";  s: root.pageScale["files"]
                    Loader { anchors.fill: parent; active: root.page === "files"; source: "../Services/FileBrowser.qml" }
                }
                ScaledPage {
                    visible: root.page === "wall";   s: root.pageScale["wall"]
                    Loader { anchors.fill: parent; active: root.page === "wall"; source: "../Services/WallpaperTab.qml" }
                }
                ScaledPage {
                    visible: root.page === "colors"; s: root.pageScale["colors"]
                    Loader { anchors.fill: parent; active: root.page === "colors"; source: "../Services/WallustTab.qml" }
                }
                ScaledPage {
                    visible: root.page === "eq";     s: root.pageScale["eq"]
                    Loader { anchors.fill: parent; active: root.page === "eq"; source: "../Services/home/EqDash.qml" }
                }
                ScaledPage {
                    visible: root.page === "mixer";  s: root.pageScale["mixer"]
                    Loader { anchors.fill: parent; active: root.page === "mixer"; source: "../Services/MixerTab.qml" }
                }
                ScaledPage {
                    visible: root.page === "discord"; s: root.pageScale["discord"]
                    Loader { anchors.fill: parent; active: root.page === "discord"; source: "../Services/DiscordChat.qml" }
                }
                ScaledPage {
                    visible: root.page === "deck"; s: root.pageScale["deck"]
                    Loader { anchors.fill: parent; active: root.page === "deck"; source: "../Services/StreamDeck.qml" }
                }
                ScaledPage {
                    visible: root.page === "games"; s: root.pageScale["games"]
                    GameTab { anchors.fill: parent }
                }
                ScaledPage {
                    visible: root.page === "rgb"; s: root.pageScale["rgb"]
                    Loader { anchors.fill: parent; active: root.page === "rgb"; source: "../Services/RgbTab.qml" }
                }
            }
        }

        // ══ Config des onglets : une carte par onglet, dans l'ordre de la barre ══
        // Tap interrupteur = activer/désactiver ; ◀ ▶ = déplacer. Sauvé à chaque
        // changement (ShellState.touchTabs → user_data/shell_state.json).
        Rectangle {
            anchors.fill: parent
            visible: root.configOpen
            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.75)
            MouseArea { anchors.fill: parent; onClicked: root.configOpen = false }

            Column {
                anchors.centerIn: parent
                spacing: 24

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Onglets — tap pour activer, ◀ ▶ pour réorganiser"
                    font.family: Appearance.font.family; font.pixelSize: 22; font.weight: Font.Bold
                    color: Appearance.colors.fg
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    Repeater {
                        model: root.tabs
                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            required property int index
                            readonly property color wcol: Qt.lighter(root._wpal[index % root._wpal.length], 1.35)
                            width: 168; height: 250; radius: 20
                            color: modelData.on ? ColorUtils.applyAlpha(wcol, 0.22) : ColorUtils.applyAlpha(Appearance.colors.bg, 0.6)
                            border.width: modelData.on ? 2 : 1
                            border.color: modelData.on ? wcol : ColorUtils.applyAlpha(Appearance.colors.fg, 0.1)
                            opacity: modelData.on ? 1 : 0.55
                            Behavior on color { ColorAnimation { duration: 140 } }
                            MouseArea { anchors.fill: parent }   // absorbe (ne ferme pas)

                            Column {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top; anchors.topMargin: 18
                                spacing: 8
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: card.modelData.icon
                                    font.family: Appearance.font.family; font.pixelSize: 42
                                    color: card.modelData.on ? card.wcol : Appearance.colors.dim
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: card.modelData.label
                                    font.family: Appearance.font.family; font.pixelSize: 18; font.weight: Font.Bold
                                    color: Appearance.colors.fg
                                }
                                // Interrupteur
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 76; height: 40; radius: 20
                                    color: card.modelData.on ? card.wcol : ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
                                    Rectangle {
                                        width: 32; height: 32; radius: 16
                                        y: 4; x: card.modelData.on ? parent.width - width - 4 : 4
                                        color: Appearance.colors.bg
                                        Behavior on x { NumberAnimation { duration: 120 } }
                                    }
                                    MouseArea { anchors.fill: parent; anchors.margins: -10; onClicked: { root.toggleTab(card.index); GameBreak.extend() } }
                                }
                            }

                            // ◀ ▶ déplacer
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                                spacing: 12
                                Repeater {
                                    model: [ { g: "󰁍", d: -1 }, { g: "󰁔", d: 1 } ]
                                    delegate: Rectangle {
                                        required property var modelData
                                        readonly property bool can: card.index + modelData.d >= 0 && card.index + modelData.d < root.tabs.length
                                        width: 64; height: 52; radius: 14
                                        opacity: can ? 1 : 0.25
                                        color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.7)
                                        border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
                                        Text {
                                            anchors.centerIn: parent; text: parent.modelData.g
                                            font.family: Appearance.font.family; font.pixelSize: 24
                                            color: Appearance.colors.fg
                                        }
                                        MouseArea {
                                            anchors.fill: parent; enabled: parent.can
                                            onClicked: { root.moveTab(card.index, parent.modelData.d); GameBreak.extend() }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Réinitialiser l'ordre/état par défaut.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: resetRow.implicitWidth + 40; height: 56; radius: 16
                    color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.7)
                    border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
                    Row {
                        id: resetRow
                        anchors.centerIn: parent; spacing: 10
                        Text { text: "󰑓"; font.family: Appearance.font.family; font.pixelSize: 22; color: Appearance.colors.fg }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Par défaut"; font.family: Appearance.font.family; font.pixelSize: 17
                            color: Appearance.colors.fg
                        }
                    }
                    MouseArea { anchors.fill: parent; onClicked: ShellState.touchTabs = [] }
                }
            }
        }
    }
}
