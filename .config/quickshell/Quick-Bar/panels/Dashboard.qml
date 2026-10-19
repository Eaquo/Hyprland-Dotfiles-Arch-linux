import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.core
import qs.pages.apps
import qs.pages.discord
import qs.pages.eq
import qs.pages.files
import qs.pages.games
import qs.pages.home
import qs.pages.kanban
import qs.pages.stats
import qs.pages.wall

// Dashboard — PanelWindow required for TextInput keyboard focus on Wayland.
// Uses WlrKeyboardFocus.Exclusive so TextInputs inside pages receive key events.
//
// Positioning mirrors the original PopupWindow behaviour: the sizer's top sits
// exactly at the notch-bar bottom (topMargin: Appearance.notchHeight), so there is
// no vertical offset compared to the PopupWindow version.

PanelWindow {
    id: root

    readonly property int fw: Appearance.notchRadius
    readonly property int fh: Appearance.notchRadius
    readonly property int animDuration: Appearance.animDuration

    property string page: "home"
    // (ouverture à la création : voir plus bas)

    // ── Onglets et taille : [dashboard] dans config.toml (Réglages › Panneaux › Dashboard) ──
    readonly property var allTabs: [
        { key: "home",   icon: "󰋜", label: "Home"   },
        { key: "stats",  icon: "󰻠", label: "System" },
        { key: "kanban", icon: "󰄬", label: "Tasks"  },
        { key: "files",  icon: "󰉋", label: "Files"  },
        { key: "wall",   icon: "󰸉", label: "Wall"   },
        { key: "eq",     icon: "󰓃", label: "Eq"     },
        { key: "discord",icon: "󰙯", label: "Discord"}
    ]
    readonly property var tabs: {
        const keys = Config.get("dashboard.tabs", allTabs.map(t => t.key))
        const out = (Array.isArray(keys) ? keys : []).map(k => allTabs.find(t => t.key === k)).filter(t => t)
        return out.length ? out : [allTabs[0]]
    }
    readonly property string homeKey: tabs[0].key   // page ouverte par défaut = 1er onglet
    function _applyPageWidth(p) { Popups.dashboardPageWidth = Appearance.dashboardWidth }
    onPageChanged: _applyPageWidth(page)
    Connections { target: Appearance; function onDashboardWidthChanged() { root._applyPageWidth(root.page) } }

    color:   "transparent"
    visible: windowVisible

    anchors.top:   true
    anchors.left:  true
    anchors.right: true
    anchors.bottom: true

    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer:         WlrLayer.Overlay
    // Exclusive focus only when fully open and visible.
    WlrLayershell.keyboardFocus: (windowVisible && Popups.dashboardOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Le Dashboard s'ouvre toujours depuis le haut de l'écran, même barre en bas (choix de l'utilisateur).
    // true = accroché en bas (forme et contenu inversés, prêt mais désactivé).
    readonly property bool fromBottom: false
    property bool windowVisible: false

    // créé par un LazyLoader (shell.qml) quand on l'ouvre, détruit après la fermeture : aucune RAM fermé
    // ouvert « visuellement » : suit Popups.dashboardOpen, mais seulement une fois créé (sinon pas de transition)
    property bool isOpen: false
    Component.onCompleted: {
        page = homeKey
        if (Popups.dashboardOpen) openConn.onDashboardOpenChanged()
        openDelay.start()
    }
    // un court délai : la fenêtre doit être affichée pour que la transition se joue (comme Spotify)
    Timer { id: openDelay; interval: 60; onTriggered: root.isOpen = Qt.binding(() => Popups.dashboardOpen) }
    Connections {
        id: openConn
        target: Popups
        function onDashboardOpenChanged() {
            if (Popups.dashboardOpen) {
                closeTimer.stop()
                root.windowVisible = true
                root._applyPageWidth(root.page)
            } else {
                closeTimer.restart()
            }
        }
    }

    // ── IPC handlers for external toggle requests ─────────────────────────────
    // commandes IPC : dans shell.qml (le panneau n'existe que lorsqu'il est ouvert)


    Timer {
        id: closeTimer
        interval: root.animDuration + 20
        onTriggered: {
            root.windowVisible = false
            tabBar.reset()
        }
    }

    // ── Backdrop — closes popup when clicking outside the sizer ──────────────
    MouseArea {
        anchors.fill: parent
        onClicked:    Popups.dashboardOpen = false
    }

    // ── Sizer ─────────────────────────────────────────────────────────────────
    // topMargin: Appearance.notchHeight places the sizer top exactly at the notch
    // bottom — identical to where PopupWindow put it. No fh subtraction, which
    // was the source of the vertical offset in the text-working variant.
    Item {
        id: sizer
        // accroché au bord où se trouve la barre ([bar] position)
        anchors.top:              root.fromBottom ? undefined : parent.top
        anchors.bottom:           root.fromBottom ? parent.bottom : undefined
        anchors.horizontalCenter: parent.horizontalCenter
        clip: true

        width:  root.isOpen ? Popups.dashboardPageWidth + 2 * root.fw : Appearance.cNotchMinWidth + 2 * root.fw
        height: root.isOpen ? Appearance.dashboardHeight : Appearance.notchHeight / 2

        Behavior on width  { NumberAnimation { duration: root.animDuration; easing.type: Easing.InOutCubic } }
        Behavior on height { NumberAnimation { duration: root.animDuration; easing.type: Easing.InOutCubic } }

        MouseArea {
            anchors.fill: parent
            onClicked:    {}
        }

        // ── Background ────────────────────────────────────────────────────────
        PopupShape {
            anchors.fill: parent
            attachedEdge: root.fromBottom ? "bottom" : "top"
            color:        Appearance.background
            radius:       Appearance.cornerRadius
            flareWidth:   root.fw
            flareHeight:  root.fh
            // Contour dégradé wallust 45° animé, seulement quand le dashboard est ouvert
            borderColor:    Appearance.outline
            borderWidth:    Popups.dashboardOpen ? 2 : 0
            borderAnimated: Popups.dashboardOpen && Appearance.animationsEnabled
        }

        // ── Content ───────────────────────────────────────────────────────────
        Item {
            id: content
            // Taille fixe, accrochée au côté de la barre : la forme qui grandit la dévoile
            // depuis la barre (vers le bas si elle est en haut, vers le haut si elle est en bas)
            anchors {
                left:         parent.left
                right:        parent.right
                top:          root.fromBottom ? undefined : parent.top
                bottom:       root.fromBottom ? parent.bottom : undefined
                topMargin:    root.fh + 8
                bottomMargin: root.fh + 8
                leftMargin:   root.fw + 8
                rightMargin:  root.fw + 8
            }
            height: Appearance.dashboardHeight - root.fh - 16

            opacity: root.isOpen ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: root.isOpen
                        ? root.animDuration * 0.5
                        : root.animDuration * 0.15
                }
            }

            Item {
                anchors.fill: parent

                // ── Tab bar (côté barre) ──────────────────────────────────────
                TabSwitcher {
                    id: tabBar
                    orientation: "horizontal"
                    anchors.top:    root.fromBottom ? undefined : parent.top
                    anchors.bottom: root.fromBottom ? parent.bottom : undefined
                    width:       parent.width
                    currentPage: root.page
                    model: root.tabs
                    onPageChanged: function(key) { root.page = key }
                }

                // ── Page area ─────────────────────────────────────────────────
                Item {
                    id: pageArea
                    focus: true

                    y:      root.fromBottom ? 0 : tabBar.height
                    width:  parent.width
                    height: parent.height - tabBar.height

                    // Pages lazy-loadées : chargées seulement quand le popup est
                    // affiché ET que c'est l'onglet courant. `windowVisible` (et non
                    // Popups.dashboardOpen) garde la page pendant l'anim de fermeture,
                    // puis tout se libère → aucune page en RAM popup fermé.
                    Loader {
                        anchors.fill: parent
                        active: root.windowVisible && root.page === "home"
                        source: "../pages/home/DashHome.qml"
                    }
                    Loader {
                        anchors.fill: parent
                        active: root.windowVisible && root.page === "stats"
                        source: "../pages/stats/DashStats.qml"
                    }
                    Loader {
                        anchors.fill: parent
                        active: root.windowVisible && root.page === "kanban"
                        source: "../pages/kanban/KanbanBoard.qml"
                    }
                    Loader {
                        anchors.fill: parent
                        active: root.windowVisible && root.page === "files"
                        source: "../pages/files/FileBrowser.qml"
                    }
                    Loader {
                        anchors.fill: parent
                        active: root.windowVisible && root.page === "wall"
                        source: "../pages/wall/WallpaperTab.qml"
                    }
                    Loader {
                        anchors.fill: parent
                        active: root.windowVisible && root.page === "eq"
                        source: "../pages/eq/EqDash.qml"
                    }
                    Loader {
                        anchors.fill: parent
                        active: root.windowVisible && root.page === "discord"
                        source: "../pages/discord/DiscordChat.qml"
                    }
                    Loader {
                        anchors.fill: parent
                        active: root.windowVisible && root.page === "deck"
                        source: "../pages/apps/StreamDeck.qml"
                    }
                    Loader {
                        anchors.fill: parent
                        active: root.windowVisible && root.page === "games"
                        source: "../pages/games/GameTab.qml"
                    }

                    Keys.onEscapePressed: Popups.dashboardOpen = false
                }
            }
        }
    }
}
