import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../Components/"
import "../Components/"
import "../Dashboard/"
import "../Services/"
import "../Common/"

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

    // ── Per-page content widths ───────────────────────────────────────────────
    readonly property var _pageWidths: ({
        "home":   900,
        "stats":  900,
        "kanban": 900,
        "files":  900,
        "wall":   900,
        "eq":     900,
        "discord":900,
        // "deck":   900,
        "games":  900
    })

    function _applyPageWidth(p) {
        var w = _pageWidths[p]
        Popups.dashboardPageWidth = (w !== undefined) ? w : 900
    }

    onPageChanged: _applyPageWidth(page)

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

    property bool windowVisible: false

    Connections {
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
    IpcHandler {
        target: "dashboard-home"
        function toggle() {
            if(Popups.anyOpen && !Popups.dashboardOpen){
                Popups.closeAll()
                Popups.dashboardOpen = true
                root.page = "home"
            } else if(Popups.dashboardOpen && root.page != "home") {
                root.page = "home"
            } else if(Popups.dashboardOpen && root.page == "home") {
                Popups.dashboardOpen = false
            } else {
                Popups.dashboardOpen = !Popups.dashboardOpen
                root.page = "home"
            }
        }
    }


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
        anchors.top:              parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        clip: true

        width:  Popups.dashboardOpen ? Popups.dashboardPageWidth + 2 * root.fw : Appearance.cNotchMinWidth + 2 * root.fw
        height: Popups.dashboardOpen ? Appearance.dashboardHeight : Appearance.notchHeight / 2

        Behavior on width  { NumberAnimation { duration: root.animDuration; easing.type: Easing.InOutCubic } }
        Behavior on height { NumberAnimation { duration: root.animDuration; easing.type: Easing.InOutCubic } }

        MouseArea {
            anchors.fill: parent
            onClicked:    {}
        }

        // ── Background ────────────────────────────────────────────────────────
        PopupShape {
            anchors.fill: parent
            attachedEdge: "top"
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
            anchors {
                fill:         parent
                topMargin:    root.fh + 8
                leftMargin:   root.fw + 8
                rightMargin:  root.fw + 8
                bottomMargin: 8
            }

            opacity: Popups.dashboardOpen ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Popups.dashboardOpen
                        ? root.animDuration * 0.5
                        : root.animDuration * 0.15
                }
            }

            Column {
                anchors.fill: parent
                spacing: 0

                // ── Tab bar ───────────────────────────────────────────────────
                TabSwitcher {
                    id: tabBar
                    orientation: "horizontal"
                    width:       parent.width
                    currentPage: root.page
                    model: [
                        { key: "home",   icon: "󰋜", label: "Home"   },
                        { key: "stats",  icon: "󰻠", label: "System" },
                        { key: "kanban", icon: "󰄬", label: "Tasks"  },
                        { key: "files",  icon: "󰉋", label: "Files"  },
                        { key: "wall",   icon: "󰸉", label: "Wall"   },
                        { key: "eq",     icon: "󰓃", label: "Eq"     },
                        { key: "discord",icon: "󰙯", label: "Discord"},
                        // { key: "deck",   icon: "󰀻", label: "Apps"   },
                        // { key: "games",  icon: "󰊴", label: "Games"  },
                    ]
                    onPageChanged: function(key) { root.page = key }
                }

                // ── Page area ─────────────────────────────────────────────────
                Item {
                    id: pageArea
                    focus: true

                    width:  parent.width
                    height: parent.height - tabBar.height

                    // Pages lazy-loadées : chargées seulement quand le popup est
                    // affiché ET que c'est l'onglet courant. `windowVisible` (et non
                    // Popups.dashboardOpen) garde la page pendant l'anim de fermeture,
                    // puis tout se libère → aucune page en RAM popup fermé.
                    Loader {
                        anchors.fill: parent
                        active: root.windowVisible && root.page === "home"
                        source: "../Services/home/DashHome.qml"
                    }
                    Loader {
                        anchors.fill: parent
                        active: root.windowVisible && root.page === "stats"
                        source: "../Dashboard/DashStats.qml"
                    }
                    Loader {
                        anchors.fill: parent
                        active: root.windowVisible && root.page === "kanban"
                        source: "../Services/KanbanBoard.qml"
                    }
                    Loader {
                        anchors.fill: parent
                        active: root.windowVisible && root.page === "files"
                        source: "../Services/FileBrowser.qml"
                    }
                    Loader {
                        anchors.fill: parent
                        active: root.windowVisible && root.page === "wall"
                        source: "../Services/WallpaperTab.qml"
                    }
                    Loader {
                        anchors.fill: parent
                        active: root.windowVisible && root.page === "eq"
                        source: "../Services/home/EqDash.qml"
                    }
                    Loader {
                        anchors.fill: parent
                        active: root.windowVisible && root.page === "discord"
                        source: "../Services/DiscordChat.qml"
                    }
                    Loader {
                        anchors.fill: parent
                        active: root.windowVisible && root.page === "deck"
                        source: "../Services/StreamDeck.qml"
                    }
                    Loader {
                        anchors.fill: parent
                        active: root.windowVisible && root.page === "games"
                        source: "../Services/GameTab.qml"
                    }

                    Keys.onEscapePressed: Popups.dashboardOpen = false
                }
            }
        }
    }
}
