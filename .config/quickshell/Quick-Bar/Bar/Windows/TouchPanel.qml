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

    // ── Onglets (mêmes pages que le Dashboard) ───────────────────────────────────
    readonly property var tabs: [
        { key: "home",   icon: "󰋜", label: "Home"   },
        { key: "stats",  icon: "󰻠", label: "System" },
        { key: "kanban", icon: "󰄬", label: "Tasks"  },
        { key: "files",  icon: "󰉋", label: "Files"  },
        { key: "wall",   icon: "󰸉", label: "Wall"   },
        { key: "eq",     icon: "󰓃", label: "Eq"     },
        { key: "discord",icon: "󰙯", label: "Discord"},
        { key: "deck",   icon: "󰀻", label: "Apps"   },
        { key: "games",  icon: "󰊴", label: "Games"  },
    ]

    // Palette wallust vive : chaque onglet cycle dessus (icône/label/pastille).
    readonly property var _wpal: [
        Appearance.colors.color4,  Appearance.colors.color5,  Appearance.colors.color6,
        Appearance.colors.color9,  Appearance.colors.color10, Appearance.colors.color11,
        Appearance.colors.color12, Appearance.colors.color13, Appearance.colors.color14
    ]

    // Facteur de zoom par page (tactile = grand écran → on agrandit les pages
    // pensées pour le popup ~900px). 1.0 = taille native. Réglable tab par tab.
    readonly property var pageScale: ({
        "home":   1.0,
        "stats":  1.15,
        "kanban": 1.15,
        "files":  1.35,
        "wall":   1.0,
        "eq":     1.0,
        "discord":1.0,
        "deck":   1.0,
        "games":  1.0
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
                root.page = "home"
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
        WlrLayershell.keyboardFocus: root.page === "discord"
            ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
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
            source: WallpaperState.videoMode
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

                // Onglets centrés horizontalement (droitier → main droite plus rapide).
                Row {
                    id: tabRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter:   parent.verticalCenter
                    spacing: 10
                    Repeater {
                        model: root.tabs
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
                                    text: modelData.label
                                    font.family: Appearance.font.family; font.pixelSize: 20
                                    font.weight: tab.isActive ? Font.Bold : Font.Medium
                                    color: tab.isActive ? Appearance.colors.bg : Appearance.colors.fg
                                }
                            }
                            MouseArea { anchors.fill: parent; onClicked: root.page = modelData.key }
                        }
                    }
                }

                // Horloge + bouton fermer, ancrés à droite.
                Row {
                    anchors.right:          parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16

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
                    visible: root.page === "home";   s: root.pageScale["home"]
                    TouchHome { anchors.fill: parent }
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
                    visible: root.page === "eq";     s: root.pageScale["eq"]
                    Loader { anchors.fill: parent; active: root.page === "eq"; source: "../Services/home/EqDash.qml" }
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
            }
        }
    }
}
