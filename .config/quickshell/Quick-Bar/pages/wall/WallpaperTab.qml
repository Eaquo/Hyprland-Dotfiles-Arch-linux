import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.components
import qs.core
import qs.core.functions

// WallpaperTab — galerie de wallpapers à gauche, panneau des effets à droite
// (disposition « A », pensée pour le tactile du Xeneon : cibles ≥ 56 px, thèmes
// en cartes animées au lieu d'un menu au survol). Le popup Dashboard (~900 px)
// garde la même disposition en plus compact, panneau défilant.
Item {
    id: root

    readonly property string setScript:   Quickshell.env("HOME") + "/.config/hypr/scripts/set-wallpaper.sh"
    readonly property string videoScript: Quickshell.env("HOME") + "/.config/hypr/scripts/set-video-wallpaper.sh"
    readonly property string listScript:  Quickshell.env("HOME") + "/.config/hypr/scripts/list-wallpapers.sh"
    readonly property string imgDir: Config.dir("wallpaper.dir", "~/Pictures/wallpapers")      // config.toml [wallpaper]
    readonly property string vidDir: Config.dir("wallpaper.videos", imgDir + "/Video")
    onImgDirChanged: { listProc.running = false; listProc.running = true }
    onVidDirChanged: { listProc.running = false; listProc.running = true }

    readonly property bool wide: width >= 1300      // TouchPanel (large) vs popup Dashboard (~900)
    readonly property real u: wide ? 1.0 : 0.72     // échelle des commandes
    readonly property var  minutes: [1, 5, 15, 30, 60, 120]
    readonly property color accent: Appearance.colors.accent
    property var  items: []
    property bool introDone: false                  // cascade d'entrée des vignettes jouée une fois
    property real fxTime: 0                         // horloge partagée des aperçus de thème

    Process {
        id: listProc
        command: ["bash", root.listScript, root.imgDir, root.vidDir]
        stdout: StdioCollector {
            onStreamFinished: { try { root.items = JSON.parse(text) } catch (e) { root.items = [] } }
        }
    }
    Component.onCompleted: listProc.running = true
    Timer { interval: 1200; running: root.items.length > 0; onTriggered: root.introDone = true }

    // Tout toucher prolonge la pause jeu (passif : ne vole aucun geste)
    PointHandler { onActiveChanged: if (active) GameBreak.extend() }


    // Application : core/WallpaperState.qml (partagée avec le sélecteur SUPER+W)
    function apply(path) {
        WallpaperState.applyImage(path)
        toast.say(Appearance.paletteSource + " recolore Quick-Bar…")
    }
    function applyVideo(path) {
        WallpaperState.applyVideo(path)
        toast.say("Vidéo lancée")
    }

    // Fait défiler la galerie jusqu'au wallpaper courant s'il est hors de vue
    function revealCurrent() {
        const i = root.items.findIndex(it => it.path === WallpaperState.currentWall)
        if (i < 0 || grid.width <= 0) return
        const cols = Math.max(1, Math.floor(grid.width / grid.cellWidth))
        const y = Math.floor(i / cols) * grid.cellHeight
        if (y >= grid.contentY && y + grid.cellHeight <= grid.contentY + grid.height) return
        scrollAnim.to = Math.max(0, Math.min(y - (grid.height - grid.cellHeight) / 2, grid.contentHeight - grid.height))
        scrollAnim.restart()
    }
    Connections {
        target: WallpaperState
        function onCurrentWallChanged() { root.revealCurrent() }
    }

    // Source et horloge des aperçus de thème (un seul décodage, une seule horloge)
    Image {
        id: fxSrc
        visible: false
        source: WallpaperState.videoMode ? "file://" + Quickshell.env("HOME") + "/.curr_wall_static.jpg"
              : WallpaperState.currentWall !== "" ? "file://" + WallpaperState.currentWall : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 480; sourceSize.height: 300
        asynchronous: true; cache: false
    }
    FrameAnimation { running: root.visible; onTriggered: root.fxTime += frameTime * WallpaperState.glitchSpeed }

    // ── Interrupteur : bouton à ressort, la pastille s'étire à l'appui ─────────
    component Toggle: Rectangle {
        id: tg
        property bool on: false
        property string label: ""
        signal toggled()
        implicitWidth: tgRow.implicitWidth + 30 * root.u
        implicitHeight: 64 * root.u
        radius: 20 * root.u
        color: on ? ColorUtils.applyAlpha(root.accent, 0.26) : Qt.rgba(1, 1, 1, 0.05)
        border.width: 1.5
        border.color: on ? ColorUtils.applyAlpha(root.accent, 0.7) : Qt.rgba(1, 1, 1, 0.10)
        scale: tgMa.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: Appearance.dur(260); easing.type: Easing.OutBack; easing.overshoot: 3 } }
        Behavior on color { ColorAnimation { duration: Appearance.dur(220) } }
        Behavior on border.color { ColorAnimation { duration: Appearance.dur(220) } }
        Row {
            id: tgRow
            anchors.centerIn: parent
            spacing: 12 * root.u
            Rectangle {
                width: 56 * root.u; height: 32 * root.u; radius: height / 2
                anchors.verticalCenter: parent.verticalCenter
                color: tg.on ? root.accent : Qt.rgba(1, 1, 1, 0.18)
                Behavior on color { ColorAnimation { duration: Appearance.dur(220) } }
                Rectangle {
                    height: parent.height - 8 * root.u
                    width: tgMa.pressed ? height + 10 * root.u : height
                    radius: height / 2
                    y: 4 * root.u
                    x: tg.on ? parent.width - width - 4 * root.u : 4 * root.u
                    color: "#ffffff"
                    Behavior on x { SpringAnimation { spring: 5; damping: 0.3; epsilon: 0.25 } }
                    Behavior on width { NumberAnimation { duration: Appearance.dur(140); easing.type: Easing.OutCubic } }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: tg.label
                font.family: Appearance.font.family
                font.pixelSize: 17 * root.u; font.weight: Font.DemiBold; font.letterSpacing: 1.2
                color: tg.on ? Appearance.colors.fg : Qt.rgba(1, 1, 1, 0.6)
                Behavior on color { ColorAnimation { duration: Appearance.dur(220) } }
            }
        }
        MouseArea { id: tgMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tg.toggled() }
    }

    // ── Curseur large : gros bouton, halo et bulle de valeur pendant le glissé ─
    component BigSlider: Item {
        id: sl
        property real value: 0      // 0..1 normalisé
        property string label: ""
        property string valueText: ""
        signal moved(real v)
        implicitHeight: 86 * root.u

        Text {
            anchors { left: parent.left; top: parent.top }
            text: sl.label
            font.family: Appearance.font.family
            font.pixelSize: 16 * root.u; font.weight: Font.Bold; font.letterSpacing: 1.6
            color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.7)
        }
        Text {
            anchors { right: parent.right; top: parent.top }
            text: sl.valueText
            font.family: "JetBrains Mono"; font.pixelSize: 19 * root.u; font.weight: Font.DemiBold
            color: Appearance.colors.fg
            scale: slMa.pressed ? 1.12 : 1
            transformOrigin: Item.Right
            Behavior on scale { NumberAnimation { duration: Appearance.dur(200); easing.type: Easing.OutBack } }
        }
        Item {
            id: hit
            // marges = demi-bouton : le bouton reste entier aux extrémités
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 23 * root.u; rightMargin: 23 * root.u }
            height: 52 * root.u

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 12 * root.u; radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.12)
                Rectangle {
                    height: parent.height; radius: parent.radius
                    width: Math.max(height, track.width * sl.value)
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: ColorUtils.applyAlpha(root.accent, 0.55) }
                        GradientStop { position: 1; color: root.accent }
                    }
                    Behavior on width { enabled: !slMa.pressed; NumberAnimation { duration: Appearance.dur(320); easing.type: Easing.OutCubic } }
                }
            }
            // halo
            Rectangle {
                anchors.centerIn: knob
                width: slMa.pressed ? knob.width + 30 * root.u : knob.width
                height: width; radius: width / 2
                color: ColorUtils.applyAlpha(root.accent, 0.35)
                Behavior on width { NumberAnimation { duration: Appearance.dur(260); easing.type: Easing.OutBack } }
            }
            Rectangle {
                id: knob
                anchors.verticalCenter: parent.verticalCenter
                width: (slMa.pressed ? 46 : 38) * root.u; height: width; radius: width / 2
                x: track.width * sl.value - width / 2
                color: "#ffffff"
                Behavior on width { NumberAnimation { duration: Appearance.dur(220); easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                Behavior on x { enabled: !slMa.pressed; NumberAnimation { duration: Appearance.dur(320); easing.type: Easing.OutCubic } }
            }
            // bulle de valeur
            Rectangle {
                z: 5
                width: bub.implicitWidth + 24 * root.u; height: 38 * root.u; radius: 12 * root.u
                x: knob.x + knob.width / 2 - width / 2
                y: knob.y - height - (slMa.pressed ? 14 : 2) * root.u
                opacity: slMa.pressed ? 1 : 0
                scale: slMa.pressed ? 1 : 0.5
                color: Appearance.colors.fg
                Behavior on opacity { NumberAnimation { duration: Appearance.dur(140) } }
                Behavior on scale { NumberAnimation { duration: Appearance.dur(240); easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                Behavior on y { NumberAnimation { duration: Appearance.dur(240); easing.type: Easing.OutBack } }
                Text {
                    id: bub
                    anchors.centerIn: parent
                    text: sl.valueText
                    font.family: "JetBrains Mono"; font.pixelSize: 18 * root.u; font.weight: Font.Bold
                    color: Appearance.colors.bg
                }
            }
            MouseArea {
                id: slMa
                anchors.fill: parent; anchors.margins: -10
                preventStealing: true
                cursorShape: Qt.PointingHandCursor
                function upd(mx) { sl.moved(Math.max(0, Math.min(1, (mx - 10) / track.width))) }
                onPressed:         (e) => upd(e.x)
                onPositionChanged: (e) => { if (pressed) upd(e.x) }
            }
        }
    }

    // ── Pastilles d'intervalle : la sélection glisse d'une pastille à l'autre ─
    component MinuteChips: Item {
        id: mc
        readonly property int sel: root.minutes.indexOf(WallpaperState.autoMinutes)
        implicitWidth: chipRow.implicitWidth
        implicitHeight: 64 * root.u
        opacity: WallpaperState.autoChange ? 1 : 0.35
        Behavior on opacity { NumberAnimation { duration: Appearance.dur(250) } }

        Rectangle {
            readonly property Item target: chipRep.count > mc.sel && mc.sel >= 0 ? chipRep.itemAt(mc.sel) : null
            visible: target !== null
            x: target ? target.x : 0
            width: target ? target.width : 0
            height: 56 * root.u; radius: 18 * root.u
            anchors.verticalCenter: parent.verticalCenter
            color: Appearance.colors.fg
            Behavior on x { SpringAnimation { spring: 4; damping: 0.32; epsilon: 0.25 } }
            Behavior on width { NumberAnimation { duration: Appearance.dur(260); easing.type: Easing.OutCubic } }
        }
        Row {
            id: chipRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.u
            Repeater {
                id: chipRep
                model: root.minutes
                delegate: Rectangle {
                    required property int modelData
                    required property int index
                    readonly property bool on: index === mc.sel
                    width: chipTxt.implicitWidth + 30 * root.u; height: 56 * root.u; radius: 18 * root.u
                    color: "transparent"
                    border.width: on ? 0 : 1.5; border.color: Qt.rgba(1, 1, 1, 0.12)
                    scale: chipMa.pressed ? 0.9 : 1
                    Behavior on scale { NumberAnimation { duration: Appearance.dur(220); easing.type: Easing.OutBack; easing.overshoot: 3 } }
                    Text {
                        id: chipTxt
                        anchors.centerIn: parent
                        text: modelData < 60 ? modelData + " min" : (modelData / 60) + " h"
                        font.family: "JetBrains Mono"; font.pixelSize: 18 * root.u; font.weight: Font.DemiBold
                        color: parent.on ? Appearance.colors.bg : Appearance.colors.fg
                        Behavior on color { ColorAnimation { duration: Appearance.dur(200) } }
                    }
                    MouseArea {
                        id: chipMa
                        anchors.fill: parent
                        enabled: WallpaperState.autoChange
                        cursorShape: Qt.PointingHandCursor
                        onClicked: WallpaperState.autoMinutes = modelData
                    }
                }
            }
        }
    }

    // ── Bouton plein (Aléatoire) : l'icône fait un tour à chaque appui ────────
    component PillButton: Rectangle {
        id: pb
        property string icon: ""
        property string label: ""
        property real spin: 0
        signal clicked()
        implicitWidth: pbRow.implicitWidth + 40 * root.u
        implicitHeight: 64 * root.u
        radius: 20 * root.u
        color: ColorUtils.applyAlpha(root.accent, pbMa.pressed ? 0.5 : 0.32)
        border.width: 1.5; border.color: ColorUtils.applyAlpha(root.accent, 0.8)
        scale: pbMa.pressed ? 0.93 : 1
        Behavior on scale { NumberAnimation { duration: Appearance.dur(260); easing.type: Easing.OutBack; easing.overshoot: 3 } }
        Behavior on color { ColorAnimation { duration: Appearance.dur(150) } }
        Row {
            id: pbRow
            anchors.centerIn: parent
            spacing: 12 * root.u
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pb.icon; rotation: pb.spin
                font.family: Appearance.font.family; font.pixelSize: 26 * root.u
                color: Appearance.colors.fg
                Behavior on rotation { NumberAnimation { duration: Appearance.dur(750); easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pb.label
                font.family: Appearance.font.family
                font.pixelSize: 19 * root.u; font.weight: Font.DemiBold; font.letterSpacing: 1.5
                color: Appearance.colors.fg
            }
        }
        MouseArea {
            id: pbMa
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: { pb.spin += 360; pb.clicked() }
        }
    }

    // ── Layout ──────────────────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        anchors.margins: 14 * root.u
        spacing: 20 * root.u

        // ══ Galerie ══════════════════════════════════════════════════════════
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 26 * root.u
            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.5)
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.07)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18 * root.u
                spacing: 12 * root.u

                // En-tête : rotation automatique (passe à la ligne si étroit) + aléatoire à droite
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12 * root.u
                  Flow {
                    Layout.fillWidth: true
                    spacing: 12 * root.u

                    Toggle {
                        on: WallpaperState.autoChange
                        label: "ROTATION"
                        onToggled: WallpaperState.autoChange = !WallpaperState.autoChange
                    }
                    MinuteChips {}
                  }
                    PillButton {
                        Layout.alignment: Qt.AlignTop
                        icon: "󰒝"; label: "ALÉATOIRE"
                        onClicked: WallpaperState.randomWall()
                    }
                }

                GridView {
                    id: grid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    cellWidth:  Math.floor(width / Math.max(1, Math.floor(width / (root.wide ? 300 : 190))))
                    cellHeight: Math.round(cellWidth * 0.6)
                    model: root.items
                    boundsBehavior: Flickable.DragOverBounds
                    flickDeceleration: 2500
                    snapMode: GridView.SnapToRow          // le défilement s'arrête sur une rangée
                    // Inclinaison liée à la vitesse du geste, lissée
                    property real tilt: Math.max(-14, Math.min(14, verticalVelocity / 180))
                    Behavior on tilt { NumberAnimation { duration: Appearance.dur(260); easing.type: Easing.OutCubic } }
                    onCountChanged: Qt.callLater(root.revealCurrent)

                    NumberAnimation { id: scrollAnim; target: grid; property: "contentY"; duration: Appearance.dur(650); easing.type: Easing.OutCubic }

                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index
                        width:  grid.cellWidth
                        height: grid.cellHeight

                        readonly property bool isVideo:   modelData.type === "video"
                        readonly property bool isCurrent: !WallpaperState.videoMode
                                                          && WallpaperState.currentWall === modelData.path

                        // Position dans la vue : -1 en haut, 0 au centre, 1 en bas.
                        // edge = 0 au cœur de la vue → 1 contre un bord (effet tambour).
                        readonly property real rel: Math.max(-1.6, Math.min(1.6,
                            ((y - grid.contentY + height / 2) / Math.max(1, grid.height)) * 2 - 1))
                        readonly property real edge: Math.min(1, Math.max(0, Math.abs(rel) - 0.5) / 0.7)

                        // Entrée en cascade (une seule fois), puis apparition simple au défilement
                        property real lift: root.introDone ? 0 : 28
                        opacity: root.introDone ? 1 : 0
                        Component.onCompleted: if (!root.introDone) intro.start()
                        SequentialAnimation {
                            id: intro
                            PauseAnimation { duration: Math.min(cell.index, 24) * 30 }
                            ParallelAnimation {
                                NumberAnimation { target: cell; property: "opacity"; to: 1; duration: Appearance.dur(380); easing.type: Easing.OutCubic }
                                NumberAnimation { target: cell; property: "lift"; to: 0; duration: Appearance.dur(560); easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                            }
                        }

                        Item {
                            id: body
                            anchors.fill: parent
                            anchors.margins: 8 * root.u
                            transform: [
                                Translate { y: cell.lift },
                                // bascule 3D : le haut part en arrière, le bas vers l'avant, + élan du geste
                                Rotation {
                                    origin.x: body.width / 2; origin.y: body.height / 2
                                    axis { x: 1; y: 0; z: 0 }
                                    angle: -cell.rel * cell.edge * 34 - grid.tilt
                                },
                                Scale {
                                    origin.x: body.width / 2; origin.y: body.height / 2
                                    xScale: 1 - 0.14 * cell.edge; yScale: xScale
                                }
                            ]
                            opacity: 1 - 0.6 * cell.edge
                            scale: cellMa.pressed ? 0.93 : (cellHov.hovered ? 1.02 : 1)
                            Behavior on scale { NumberAnimation { duration: Appearance.dur(280); easing.type: Easing.OutBack; easing.overshoot: 2.4 } }

                            // Anneau du wallpaper courant, qui « respire »
                            Rectangle {
                                id: ring
                                anchors.fill: parent; anchors.margins: -5 * root.u
                                radius: 22 * root.u
                                color: "transparent"
                                border.width: 4 * root.u; border.color: root.accent
                                opacity: cell.isCurrent ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 300 } }
                                SequentialAnimation on border.width {
                                    running: cell.isCurrent && root.visible
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 6 * root.u; duration: 900; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 3 * root.u; duration: 900; easing.type: Easing.InOutSine }
                                }
                            }

                            ClippingRectangle {
                                anchors.fill: parent
                                radius: 18 * root.u
                                color: Qt.rgba(0, 0, 0, 0.25)

                                Image {
                                    // parallaxe : 24 % plus haute que le cadre, glisse à l'inverse du défilement
                                    width: parent.width
                                    height: parent.height * 1.24
                                    y: -parent.height * 0.12 - cell.rel * parent.height * 0.1
                                    source:       "file://" + cell.modelData.thumb
                                    fillMode:     Image.PreserveAspectCrop
                                    asynchronous: true
                                    // cache:false → vignettes libérées quand l'onglet Wall se
                                    // ferme (lazy-loadé) au lieu de rester en cache Qt.
                                    cache:        false
                                    sourceSize.width:  360
                                    sourceSize.height: 216
                                    scale: cell.isCurrent ? 1.08 : 1
                                    opacity: status === Image.Ready ? 1 : 0
                                    Behavior on scale { NumberAnimation { duration: Appearance.dur(700); easing.type: Easing.OutCubic } }
                                    Behavior on opacity { NumberAnimation { duration: Appearance.dur(300) } }
                                }

                                // Onde au point de contact
                                Rectangle {
                                    id: ripple
                                    width: body.width * 2.4; height: width; radius: width / 2
                                    color: "#ffffff"; opacity: 0; scale: 0
                                    ParallelAnimation {
                                        id: rippleAnim
                                        NumberAnimation { target: ripple; property: "scale"; from: 0; to: 1; duration: Appearance.dur(600); easing.type: Easing.OutCubic }
                                        NumberAnimation { target: ripple; property: "opacity"; from: 0.4; to: 0; duration: Appearance.dur(600); easing.type: Easing.OutQuad }
                                    }
                                }

                                // Badge vidéo
                                Rectangle {
                                    visible: cell.isVideo
                                    anchors { right: parent.right; top: parent.top; margins: 10 * root.u }
                                    width: vidRow.implicitWidth + 20 * root.u; height: 32 * root.u; radius: height / 2
                                    color: Qt.rgba(0, 0, 0, 0.6)
                                    Row {
                                        id: vidRow
                                        anchors.centerIn: parent; spacing: 6
                                        Text { text: "󰐊"; font.family: Appearance.font.family; font.pixelSize: 15 * root.u; color: "#ffffff" }
                                        Text { text: "vidéo"; font.family: Appearance.font.family; font.pixelSize: 13 * root.u; color: "#ffffff" }
                                    }
                                }

                                // Coche du wallpaper courant (apparition élastique)
                                Rectangle {
                                    anchors { left: parent.left; top: parent.top; margins: 10 * root.u }
                                    width: 40 * root.u; height: width; radius: width / 2
                                    color: root.accent
                                    scale: cell.isCurrent ? 1 : 0
                                    Behavior on scale { NumberAnimation { duration: Appearance.dur(420); easing.type: Easing.OutBack; easing.overshoot: 3 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰄬"; font.family: Appearance.font.family; font.pixelSize: 22 * root.u
                                        color: Appearance.textOn(root.accent)
                                    }
                                }
                            }
                        }

                        HoverHandler { id: cellHov; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            id: cellMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onPressed: (e) => {
                                ripple.x = e.x - body.x - ripple.width / 2
                                ripple.y = e.y - body.y - ripple.height / 2
                                rippleAnim.restart()
                            }
                            onClicked: cell.isVideo ? root.applyVideo(cell.modelData.path)
                                                    : root.apply(cell.modelData.path)
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.items.length === 0
                    text: "Aucun wallpaper trouvé dans " + root.imgDir
                    color: Appearance.colors.dim
                    font.family: Appearance.font.family
                    font.pixelSize: 16 * root.u
                }
            }
        }

        // ══ Panneau des effets ═══════════════════════════════════════════════
        Rectangle {
            id: side
            Layout.fillHeight: true
            Layout.preferredWidth: root.wide ? Math.min(820, root.width * 0.34) : 380
            radius: 26 * root.u
            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.55)
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.07)

            // Glisse depuis la droite à l'ouverture de l'onglet
            opacity: 0
            property real slide: 60
            transform: Translate { x: side.slide }
            Component.onCompleted: sideIntro.start()
            ParallelAnimation {
                id: sideIntro
                NumberAnimation { target: side; property: "opacity"; to: 1; duration: Appearance.dur(450); easing.type: Easing.OutCubic }
                NumberAnimation { target: side; property: "slide"; to: 0; duration: Appearance.dur(650); easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            }

            Flickable {
                id: sideFlick
                anchors.fill: parent
                anchors.margins: 22 * root.u
                clip: true
                contentHeight: sideCol.implicitHeight
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: sideCol
                    width: sideFlick.width
                    // centré verticalement quand il reste de la place
                    y: Math.max(0, (sideFlick.height - implicitHeight) / 2)
                    spacing: 22 * root.u

                    // Interrupteurs
                    Flow {
                        Layout.fillWidth: true
                        spacing: 10 * root.u

                        Toggle {
                            on: WallpaperState.glitchEnabled
                            label: "FX"
                            onToggled: WallpaperState.glitchEnabled = !WallpaperState.glitchEnabled
                        }
                        Toggle {
                            on: WallpaperState.glitchContinuous
                            label: "CONTINU"
                            onToggled: WallpaperState.glitchContinuous = !WallpaperState.glitchContinuous
                        }
                        Toggle {
                            on: WallpaperState.wsFxEnabled
                            label: "WS FX"
                            onToggled: WallpaperState.wsFxEnabled = !WallpaperState.wsFxEnabled
                        }
                    }

                    // Thèmes : cartes avec l'effet animé en direct sur le wallpaper courant
                    GridLayout {
                        Layout.fillWidth: true
                        visible: WallpaperState.themes.length > 1     // un seul thème → pas de choix
                        columns: 4
                        columnSpacing: 12 * root.u; rowSpacing: 12 * root.u

                        Repeater {
                            model: WallpaperState.themes
                            delegate: Item {
                                id: tc
                                required property string modelData
                                readonly property bool active: WallpaperState.glitchTheme === modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: width * (root.wide ? 0.5 : 0.72)
                                scale: tcMa.pressed ? 0.92 : 1
                                Behavior on scale { NumberAnimation { duration: Appearance.dur(280); easing.type: Easing.OutBack; easing.overshoot: 2.5 } }

                                Rectangle {
                                    anchors.fill: parent; anchors.margins: -5 * root.u
                                    radius: 21 * root.u
                                    color: "transparent"
                                    border.width: 4 * root.u; border.color: root.accent
                                    opacity: tc.active ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: Appearance.dur(300) } }
                                }
                                ClippingRectangle {
                                    anchors.fill: parent
                                    radius: 16 * root.u
                                    color: "black"
                                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)

                                    ShaderEffect {
                                        anchors.fill: parent
                                        property variant  source:     fxSrc
                                        property real     intensity:  0.25 + 0.75 * WallpaperState.glitchIntensity
                                        property real     time:       root.fxTime
                                        property vector2d resolution: Qt.vector2d(width, height)
                                        property vector4d accent: Qt.vector4d(WallpaperState.fxColor.r, WallpaperState.fxColor.g, WallpaperState.fxColor.b, 1.0)
                                        fragmentShader: Qt.resolvedUrl("../../wallpaper/shaders/" + tc.modelData + ".frag.qsb")
                                    }
                                    // FX coupé : aperçu voilé
                                    Rectangle {
                                        anchors.fill: parent
                                        color: Appearance.colors.bg
                                        opacity: WallpaperState.glitchEnabled ? 0 : 0.6
                                        Behavior on opacity { NumberAnimation { duration: Appearance.dur(300) } }
                                    }
                                    Rectangle {
                                        anchors { left: parent.left; bottom: parent.bottom; margins: 8 * root.u }
                                        width: tcLbl.implicitWidth + 18 * root.u; height: 28 * root.u; radius: 9 * root.u
                                        color: tc.active ? root.accent : Qt.rgba(0, 0, 0, 0.6)
                                        Behavior on color { ColorAnimation { duration: Appearance.dur(250) } }
                                        Text {
                                            id: tcLbl
                                            anchors.centerIn: parent
                                            text: tc.modelData
                                            font.family: Appearance.font.family
                                            font.pixelSize: 15 * root.u; font.weight: Font.DemiBold; font.letterSpacing: 1
                                            color: tc.active ? Appearance.textOn(root.accent) : "#ffffff"
                                        }
                                    }
                                }
                                MouseArea {
                                    id: tcMa
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: WallpaperState.glitchTheme = tc.modelData
                                }
                            }
                        }

                        // Couleur de l'effet : tap = sélecteur ; ↺ = revenir à l'accent wallust
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: width * (root.wide ? 0.5 : 0.72)
                            radius: 16 * root.u
                            color: WallpaperState.fxColor
                            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.2)
                            scale: swMa.pressed ? 0.92 : 1
                            Behavior on color { ColorAnimation { duration: Appearance.dur(400) } }
                            Behavior on scale { NumberAnimation { duration: Appearance.dur(280); easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                            MouseArea {
                                id: swMa
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: fxPicker.open(WallpaperState.fxColor, "Couleur de l'effet",
                                                         "Remplace l'accent " + Appearance.paletteSource + " pour l'effet du wallpaper (" + WallpaperState.glitchTheme + ")", "")
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "󰏘"; font.family: Appearance.font.family; font.pixelSize: 30 * root.u
                                color: Appearance.textOn(WallpaperState.fxColor)
                            }
                            Rectangle {
                                anchors { left: parent.left; bottom: parent.bottom; margins: 8 * root.u }
                                width: ccLbl.implicitWidth + 18 * root.u; height: 28 * root.u; radius: 9 * root.u
                                color: Qt.rgba(0, 0, 0, 0.6)
                                Text {
                                    id: ccLbl
                                    anchors.centerIn: parent
                                    text: WallpaperState.glitchColor !== "" ? "perso" : Appearance.paletteSource
                                    font.family: Appearance.font.family
                                    font.pixelSize: 15 * root.u; font.weight: Font.DemiBold; font.letterSpacing: 1
                                    color: "#ffffff"
                                }
                            }
                            // ↺ n'apparaît que si la couleur est surchargée
                            Rectangle {
                                anchors { right: parent.right; top: parent.top; margins: 6 * root.u }
                                width: 44 * root.u; height: width; radius: width / 2
                                visible: scale > 0.01
                                scale: WallpaperState.glitchColor !== "" ? (rstMa.pressed ? 0.85 : 1) : 0
                                color: Qt.rgba(0, 0, 0, 0.6)
                                Behavior on scale { NumberAnimation { duration: Appearance.dur(300); easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰑓"; font.family: Appearance.font.family; font.pixelSize: 22 * root.u
                                    color: "#ffffff"
                                }
                                MouseArea { id: rstMa; anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: WallpaperState.glitchColor = "" }
                            }
                        }
                    }

                    // Réglages fins
                    GridLayout {
                        Layout.fillWidth: true
                        columns: root.wide ? 2 : 1
                        columnSpacing: 56 * root.u; rowSpacing: 10 * root.u

                        BigSlider {
                            Layout.fillWidth: true
                            label: "INTENSITÉ"
                            value: WallpaperState.glitchIntensity
                            valueText: Math.round(WallpaperState.glitchIntensity * 100) + " %"
                            onMoved: (v) => WallpaperState.glitchIntensity = Math.max(0.1, v)
                        }
                        BigSlider {
                            Layout.fillWidth: true
                            label: "FRÉQUENCE"
                            // 2000..10000 ms  →  0..1
                            value: (WallpaperState.glitchInterval - 2000) / 8000
                            valueText: (WallpaperState.glitchInterval / 1000).toFixed(1) + " s"
                            onMoved: (v) => WallpaperState.glitchInterval = Math.round(2000 + v * 8000)
                        }
                        BigSlider {
                            Layout.fillWidth: true
                            label: "DURÉE"
                            // 0,1 s → 6 s (les effets longs comme le vol Matrix ont besoin de durée)
                            value: (WallpaperState.glitchDuration - 100) / 5900
                            valueText: WallpaperState.glitchDuration < 1000 ? WallpaperState.glitchDuration + " ms"
                                                                             : (WallpaperState.glitchDuration / 1000).toFixed(1) + " s"
                            onMoved: (v) => WallpaperState.glitchDuration = Math.round((100 + v * 5900) / 50) * 50
                        }
                        BigSlider {
                            Layout.fillWidth: true
                            label: "VITESSE"
                            // 0.2..3.0×  →  0..1
                            value: (WallpaperState.glitchSpeed - 0.2) / 2.8
                            valueText: WallpaperState.glitchSpeed.toFixed(1) + " ×"
                            onMoved: (v) => WallpaperState.glitchSpeed = Math.max(0.2, 0.2 + v * 2.8)
                        }
                    }
                }
            }
        }
    }

    // ── Toast : glisse depuis le bas quand un wallpaper est appliqué ──────────
    Rectangle {
        id: toast
        property bool shown: false
        function say(t) { toastTxt.text = t; shown = true; toastTimer.restart() }
        z: 50
        anchors.horizontalCenter: parent.horizontalCenter
        y: shown ? parent.height - height - 30 * root.u : parent.height + 10
        width: toastRow.implicitWidth + 44 * root.u; height: 56 * root.u; radius: height / 2
        color: Appearance.colors.fg
        opacity: shown ? 1 : 0
        Behavior on y { NumberAnimation { duration: Appearance.dur(420); easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
        Behavior on opacity { NumberAnimation { duration: Appearance.dur(250) } }
        Timer { id: toastTimer; interval: 2200; onTriggered: toast.shown = false }
        Row {
            id: toastRow
            anchors.centerIn: parent
            spacing: 12 * root.u
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰑓"; font.family: Appearance.font.family; font.pixelSize: 22 * root.u
                color: Appearance.colors.bg
                RotationAnimation on rotation { running: toast.shown; loops: Animation.Infinite; from: 0; to: 360; duration: 900 }
            }
            Text {
                id: toastTxt
                anchors.verticalCenter: parent.verticalCenter
                font.family: Appearance.font.family; font.pixelSize: 19 * root.u; font.weight: Font.DemiBold
                color: Appearance.colors.bg
            }
        }
    }

    // Sélecteur de couleur de l'effet (components/ColorPicker.qml)
    ColorPicker { id: fxPicker; onPicked: (hex, tag) => WallpaperState.glitchColor = hex }
}
