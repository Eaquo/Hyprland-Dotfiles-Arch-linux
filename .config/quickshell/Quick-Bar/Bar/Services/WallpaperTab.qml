import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import "../Common/"
import "../Common/functions/"

// WallpaperTab — onglet dashboard : picker de wallpapers (vignettes) + contrôles
// des effets (on/off glitch, thème, intervalle/latence, intensité, WS FX).
Item {
    id: root

    readonly property string setScript:   Quickshell.env("HOME") + "/.config/hypr/scripts/set-wallpaper.sh"
    readonly property string videoScript: Quickshell.env("HOME") + "/.config/hypr/scripts/set-video-wallpaper.sh"

    // Sélecteur de thème : dropdown + preview live au survol
    property bool   themeMenuOpen: false
    property string previewTheme:  ""    // thème survolé (preview), "" = thème courant

    readonly property string listScript: Quickshell.env("HOME") + "/.config/hypr/scripts/list-wallpapers.sh"
    property var items: []

    Process {
        id: listProc
        command: ["bash", root.listScript]
        stdout: StdioCollector {
            onStreamFinished: { try { root.items = JSON.parse(text) } catch (e) { root.items = [] } }
        }
    }
    Component.onCompleted: listProc.running = true

    // Referme le dropdown thème quand le dashboard se ferme
    Connections {
        target: Popups
        function onDashboardOpenChanged() { if (!Popups.dashboardOpen) root.themeMenuOpen = false }
    }

    Process { id: applyProc }

    // Image statique → Quickshell rend (tue gslapper, sort du mode vidéo)
    function apply(path) {
        applyProc.command = ["bash", "-c", "pkill -x gslapper 2>/dev/null; exec \"$1\" \"$2\"", "_", root.setScript, path]
        applyProc.running = false
        applyProc.running = true
        WallpaperState.currentWall = path
        WallpaperState.videoMode   = false
    }

    // Vidéo → gslapper prend le fond (tue awww), Quickshell passe en mode vidéo (glitch off)
    function applyVideo(path) {
        var mon = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        applyProc.command = ["bash", "-c",
            "exec >>/tmp/qs-video.log 2>&1; echo \"[$(date +%T)] mon='$1' path='$2'\"; " +
            "\"$3\" \"$1\" \"$2\" && echo '→ launched' || echo '→ FAILED'",
            "_", mon, path, root.videoScript]
        applyProc.running = false
        applyProc.running = true
        WallpaperState.videoMode = true
    }

    // ── Petit interrupteur réutilisable ────────────────────────────────────────
    component Toggle: Rectangle {
        id: tg
        property bool on: false
        property string label: ""
        signal toggled()
        implicitWidth: tgRow.implicitWidth + 16
        implicitHeight: 30
        radius: 8
        color: on ? Qt.rgba(Appearance.colors.accent.r, Appearance.colors.accent.g, Appearance.colors.accent.b, 0.14)
                  : Qt.rgba(1, 1, 1, 0.05)
        border.color: on ? Qt.rgba(Appearance.colors.accent.r, Appearance.colors.accent.g, Appearance.colors.accent.b, 0.35)
                         : Qt.rgba(1, 1, 1, 0.10)
        border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }
        Row {
            id: tgRow
            anchors.centerIn: parent
            spacing: 8
            Rectangle {
                width: 30; height: 16; radius: 8
                anchors.verticalCenter: parent.verticalCenter
                color: tg.on ? Appearance.colors.accent : Qt.rgba(1, 1, 1, 0.18)
                Behavior on color { ColorAnimation { duration: 120 } }
                Rectangle {
                    width: 12; height: 12; radius: 6
                    anchors.verticalCenter: parent.verticalCenter
                    x: tg.on ? parent.width - width - 2 : 2
                    color: "#ffffff"
                    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: tg.label
                font.pixelSize: Appearance.font.small - 2
                font.family: Appearance.font.family
                font.weight: Font.Medium
                color: tg.on ? Appearance.colors.fg : Qt.rgba(1, 1, 1, 0.55)
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tg.toggled() }
    }

    // ── Slider horizontal réutilisable ─────────────────────────────────────────
    component MiniSlider: Item {
        id: sl
        property real value: 0     // 0..1 normalisé
        property string label: ""
        property string valueText: ""
        signal moved(real v)
        implicitHeight: 34

        Text {
            id: slLbl
            anchors { left: parent.left; top: parent.top }
            text: sl.label
            font.pixelSize: 9; font.weight: Font.Bold
            color: Qt.rgba(Appearance.colors.accent.r, Appearance.colors.accent.g, Appearance.colors.accent.b, 0.6)
        }
        Text {
            anchors { right: parent.right; top: parent.top }
            text: sl.valueText
            font.pixelSize: 9; font.family: "JetBrains Mono"
            color: Appearance.colors.dim
        }
        Rectangle {
            id: slTrack
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 2 }
            height: 5; radius: 2.5
            color: Qt.rgba(1, 1, 1, 0.12)
            Rectangle {
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                width: Math.max(radius * 2, parent.width * sl.value)
                radius: parent.radius; color: Appearance.colors.accent
            }
            Rectangle {
                width: 12; height: 12; radius: 6; color: "#ffffff"
                anchors.verticalCenter: parent.verticalCenter
                x: (parent.width - width) * sl.value
            }
            MouseArea {
                anchors.fill: parent; anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                function upd(mx) { sl.moved(Math.max(0, Math.min(1, mx / slTrack.width))) }
                onPressed:         (e) => upd(e.x)
                onPositionChanged: if (pressed) upd(mouseX)
            }
        }
    }

    // ── Layout ──────────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // ── En-tête : titre + toggles + thème ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle { width: 7; height: 7; radius: 3.5; color: Appearance.colors.accent }
            Text {
                text: "Wallpaper FX"
                font.family: Appearance.font.family
                font.pixelSize: Appearance.font.body
                font.weight: Font.Medium
                color: Appearance.colors.fg
            }

            Item { Layout.fillWidth: true }

            Toggle {
                on: WallpaperState.glitchEnabled
                label: "WALL FX"
                onToggled: WallpaperState.glitchEnabled = !WallpaperState.glitchEnabled
            }
            Toggle {
                on: WallpaperState.wsFxEnabled
                label: "WS FX"
                onToggled: WallpaperState.wsFxEnabled = !WallpaperState.wsFxEnabled
            }
        }

        // ── Thème + sliders ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            // Sélecteur de thème (déroulant + preview live au survol)
            Rectangle {
                id: themeBtn
                implicitWidth: thSelRow.implicitWidth + 20
                implicitHeight: 30
                radius: 8
                color: root.themeMenuOpen
                       ? Qt.rgba(Appearance.colors.accent.r, Appearance.colors.accent.g, Appearance.colors.accent.b, 0.16)
                       : Qt.rgba(1, 1, 1, 0.06)
                border.color: Qt.rgba(1, 1, 1, 0.12)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                Row {
                    id: thSelRow
                    anchors.centerIn: parent
                    spacing: 8
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "󰊹"; font.family: Appearance.font.family; font.pixelSize: 13; color: Appearance.colors.accent }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: WallpaperState.glitchTheme; font.pixelSize: Appearance.font.small - 1; font.family: Appearance.font.family; font.weight: Font.Medium; color: Appearance.colors.fg }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: root.themeMenuOpen ? "▴" : "▾"; font.pixelSize: 9; color: Appearance.colors.dim }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.themeMenuOpen = !root.themeMenuOpen }
            }

            MiniSlider {
                Layout.fillWidth: true
                label: "FRÉQUENCE (LATENCE)"
                // 2000..10000 ms  →  0..1
                value: (WallpaperState.glitchInterval - 2000) / 8000
                valueText: (WallpaperState.glitchInterval / 1000).toFixed(1) + "s"
                onMoved: (v) => WallpaperState.glitchInterval = Math.round(2000 + v * 8000)
            }

            MiniSlider {
                Layout.fillWidth: true
                label: "INTENSITÉ"
                value: WallpaperState.glitchIntensity
                valueText: Math.round(WallpaperState.glitchIntensity * 100) + "%"
                onMoved: (v) => WallpaperState.glitchIntensity = Math.max(0.1, v)
            }
        }

        // ── Durée + vitesse ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            MiniSlider {
                Layout.fillWidth: true
                label: "DURÉE DU BURST"
                // 100..800 ms  →  0..1
                value: (WallpaperState.glitchDuration - 100) / 700
                valueText: WallpaperState.glitchDuration + "ms"
                onMoved: (v) => WallpaperState.glitchDuration = Math.round(100 + v * 700)
            }

            MiniSlider {
                Layout.fillWidth: true
                label: "VITESSE"
                // 0.2..3.0×  →  0..1
                value: (WallpaperState.glitchSpeed - 0.2) / 2.8
                valueText: WallpaperState.glitchSpeed.toFixed(1) + "×"
                onMoved: (v) => WallpaperState.glitchSpeed = Math.max(0.2, 0.2 + v * 2.8)
            }
        }

        // ── Grille de wallpapers ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 10
            color: Qt.rgba(1, 1, 1, 0.03)
            border.color: Qt.rgba(1, 1, 1, 0.07)
            border.width: 1
            clip: true

            GridView {
                id: grid
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                cellWidth:  Math.floor(width / Math.max(1, Math.floor(width / 180)))
                cellHeight: Math.round(cellWidth * 0.6)
                model: root.items
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: cell
                    required property var modelData
                    width:  grid.cellWidth
                    height: grid.cellHeight

                    readonly property bool isVideo:   modelData.type === "video"
                    readonly property bool isCurrent: !WallpaperState.videoMode
                                                      && WallpaperState.currentWall === modelData.path

                    ClippingRectangle {
                        anchors.fill: parent
                        anchors.margins: 5
                        radius: 8
                        color: Qt.rgba(0, 0, 0, 0.2)
                        border.color: cell.isCurrent ? Appearance.colors.accent
                                                     : (cellHov.hovered ? Qt.rgba(1, 1, 1, 0.25) : "transparent")
                        border.width: cell.isCurrent ? 2 : 1

                        Image {
                            anchors.fill: parent
                            source:       "file://" + cell.modelData.thumb
                            fillMode:     Image.PreserveAspectCrop
                            asynchronous: true
                            // cache:false → vignettes libérées quand l'onglet Wall se
                            // ferme (lazy-loadé) au lieu de rester en cache Qt.
                            cache:        false
                            sourceSize.width:  360
                            sourceSize.height: 216
                        }

                        // Badge vidéo
                        Rectangle {
                            visible: cell.isVideo
                            anchors { right: parent.right; top: parent.top; margins: 6 }
                            width: 22; height: 22; radius: 11
                            color: Qt.rgba(0, 0, 0, 0.55)
                            Text { anchors.centerIn: parent; text: "󰐊"; font.family: Appearance.font.family; font.pixelSize: 12; color: "#ffffff" }
                        }
                    }

                    HoverHandler { id: cellHov; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cell.isVideo ? root.applyVideo(cell.modelData.path)
                                                : root.apply(cell.modelData.path)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.items.length === 0
                text: "Aucun wallpaper trouvé"
                color: Appearance.colors.dim
                font.family: Appearance.font.family
                font.pixelSize: 12
            }
        }
    }

    // ── Overlay dropdown thèmes + preview live ────────────────────────────────
    MouseArea {
        anchors.fill: parent; z: 90
        visible: root.themeMenuOpen
        onClicked: root.themeMenuOpen = false
    }

    Rectangle {
        id: themeMenu
        z: 100
        visible: root.themeMenuOpen
        anchors { left: parent.left; top: parent.top; leftMargin: 14; topMargin: 92 }
        width:  menuRow.implicitWidth + 16
        height: menuRow.implicitHeight + 16
        radius: 12
        color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.98)
        border.color: Appearance.colors.color15
        border.width: 1

        RowLayout {
            id: menuRow
            anchors.centerIn: parent
            spacing: 12

            // Liste des thèmes
            ColumnLayout {
                spacing: 3
                Repeater {
                    model: WallpaperState.themes
                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool active: WallpaperState.glitchTheme === modelData
                        Layout.preferredWidth:  130
                        Layout.preferredHeight: 28
                        radius: 6
                        color: active ? Qt.rgba(Appearance.colors.accent.r, Appearance.colors.accent.g, Appearance.colors.accent.b, 0.18)
                                      : (itHov.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                        Behavior on color { ColorAnimation { duration: 90 } }
                        Text {
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            text: parent.modelData
                            color: parent.active ? Appearance.colors.accent : Appearance.colors.fg
                            font.pixelSize: Appearance.font.small - 1
                            font.family: Appearance.font.family
                            font.weight: parent.active ? Font.Medium : Font.Normal
                        }
                        HoverHandler { id: itHov; cursorShape: Qt.PointingHandCursor; onHoveredChanged: root.previewTheme = hovered ? modelData : "" }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { WallpaperState.glitchTheme = modelData; root.themeMenuOpen = false }
                        }
                    }
                }
            }

            // Preview : wallpaper courant + effet du thème (survolé ou courant), animé
            Rectangle {
                id: prevBox
                width: 260; height: 146; radius: 8; clip: true
                color: "black"
                border.color: Qt.rgba(1, 1, 1, 0.15); border.width: 1
                readonly property string theme: root.previewTheme !== "" ? root.previewTheme : WallpaperState.glitchTheme

                Image {
                    id: prevImg
                    anchors.fill: parent; visible: false
                    source: WallpaperState.currentWall !== "" ? "file://" + WallpaperState.currentWall : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 520; sourceSize.height: 292
                }
                ShaderEffect {
                    id: prevShader
                    anchors.fill: parent
                    property variant source:     prevImg
                    property real     intensity:  0.7
                    property real     time:       0
                    property vector2d resolution: Qt.vector2d(width, height)
                    property vector4d accent: Qt.vector4d(Appearance.colors.accent.r, Appearance.colors.accent.g, Appearance.colors.accent.b, 1.0)
                    fragmentShader: Qt.resolvedUrl("../Windows/shaders/" + prevBox.theme + ".frag.qsb")
                }
                FrameAnimation { running: themeMenu.visible; onTriggered: prevShader.time += frameTime * WallpaperState.glitchSpeed }

                Rectangle {
                    anchors { left: parent.left; bottom: parent.bottom; margins: 6 }
                    width: lbl.implicitWidth + 12; height: 18; radius: 4
                    color: Qt.rgba(0, 0, 0, 0.55)
                    Text { id: lbl; anchors.centerIn: parent; text: prevBox.theme; color: "#ffffff"; font.pixelSize: 10; font.family: Appearance.font.family }
                }
            }
        }
    }
}
