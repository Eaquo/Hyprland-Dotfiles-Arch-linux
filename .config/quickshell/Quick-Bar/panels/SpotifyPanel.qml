import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import qs.components
import qs.core
import qs.core.functions
import qs.services

// SpotifyPanel — panneau Spotify qui sort du bord DROIT de l'écran principal,
// dans l'esprit du Dashboard (PopupShape + contour wallust animé).
// Ouvert par SUPER+SHIFT+S :  qs -p …/shell.qml ipc call spotify toggle
//
// Pilote le client Spotify officiel par MPRIS (lecture, piste, position,
// aléatoire, boucle) ; le volume passe par PipeWire (celui de MPRIS reste à 0
// chez Spotify). La fenêtre Spotify elle-même reste le scratchpad pypr « spot ».
// Clavier : Échap ferme · Espace lecture/pause · ←/→ piste · ↑/↓ volume.
PanelWindow {
    id: root

    readonly property int fw: Appearance.notchRadius
    readonly property int fh: Appearance.notchRadius
    readonly property int animDuration: Appearance.animDuration
    readonly property int panelWidth:  Config.get("spotify.width", 440)    // [spotify] dans config.toml
    readonly property int panelHeight: Config.get("spotify.height", 730)
    // Toujours du côté opposé à la barre : à gauche quand la barre est à droite
    readonly property bool onLeft: Appearance.bar.position === "right"

    // Écran principal = tout sauf le tactile Xeneon.
    screen: {
        const all = Quickshell.screens
        return all.find(s => !Config.isTouch(s)) || all[0]
    }

    color:   "transparent"
    visible: windowVisible
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.namespace:     "quickshell:spotify"
    WlrLayershell.keyboardFocus: (windowVisible && Popups.spotifyOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool windowVisible: false
    // créé par un LazyLoader (shell.qml) quand on l'ouvre, détruit après la fermeture : aucune RAM fermé
    Component.onCompleted: { if (Popups.spotifyOpen) openConn.onSpotifyOpenChanged() }
    Connections {
        id: openConn
        target: Popups
        function onSpotifyOpenChanged() {
            if (Popups.spotifyOpen) { closeTimer.stop(); root.windowVisible = true; keys.forceActiveFocus(); slideTimer.restart() }
            else { slideTimer.stop(); root.slid = false; closeTimer.restart() }
        }
    }
    // Le glissement ne démarre qu'une fois la fenêtre affichée (sa création prend
    // quelques dizaines de ms) : sinon le début de l'animation est perdu.
    property bool slid: false
    Timer { id: slideTimer; interval: 60; onTriggered: root.slid = true }
    // La fenêtre reste affichée le temps de l'animation de fermeture (reveal.closeAnim)
    Timer { id: closeTimer; interval: 1550; onTriggered: root.windowVisible = false }

    // commandes IPC : dans shell.qml (le panneau n'existe que lorsqu'il est ouvert)

    // ── Spotify (MPRIS) ───────────────────────────────────────────────────────
    readonly property var player: Mpris.players.values.find(p =>
        (p.identity || "").toLowerCase() === "spotify" || (p.dbusName || "").indexOf("spotify") !== -1) || null
    readonly property bool playing: player?.playbackState === MprisPlaybackState.Playing

    // La position MPRIS ne se met à jour que sur demande.
    Timer {
        interval: 1000; repeat: true
        running: root.windowVisible && root.playing
        onTriggered: root.player.positionChanged()
    }
    function fmt(s) {
        s = Math.max(0, Math.floor(s))
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
    }

    // ── Volume de Spotify (flux PipeWire) ─────────────────────────────────────
    // Logique audio partagée : services/Mixer.qml
    readonly property var streams: Mixer.streamsOf("spotify")
    readonly property real volume: streams.length ? streams[0].audio.volume : 0
    function setVolume(v) { Mixer.setVolume(streams, v) }

    // Fenêtre Spotify = scratchpad pypr « spot » (le lance aussi s'il est fermé).
    Process { id: winProc; command: ["pypr", "toggle", "spot"] }
    function openWindow() { Popups.spotifyOpen = false; winProc.running = false; winProc.running = true }

    CachedArt { id: art; url: root.player?.trackArtUrl ?? "" }

    // Clic à côté = fermer
    MouseArea { anchors.fill: parent; onClicked: Popups.spotifyOpen = false }

    Item {
        id: sizer
        // Bande pleine hauteur (pour le trait du bord droit) ; le panneau lui-même
        // garde sa taille et reste centré dedans : [bodyY, bodyY + bodyH].
        anchors { top: parent.top; bottom: parent.bottom
                  right: root.onLeft ? undefined : parent.right; left: root.onLeft ? parent.left : undefined }
        width: root.panelWidth
        clip: true
        // Côté gauche : toute la forme (trait du bord, raccords, animation) est retournée en miroir ;
        // le contenu est retourné une 2e fois pour rester lisible.
        transform: Scale { origin.x: sizer.width / 2; xScale: root.onLeft ? -1 : 1 }
        readonly property real bodyH: root.panelHeight + 2 * root.fh
        // Centré sur la hauteur de l'ÉCRAN, pas de la fenêtre : celle-ci vaut 0 un
        // instant à chaque ouverture, ce qui faisait arriver le panneau en diagonale.
        readonly property real bodyY: Math.round(((root.screen?.height ?? height) - bodyH) / 2)

        Item {
            id: keys
            focus: true
            Keys.onEscapePressed: Popups.spotifyOpen = false
            Keys.onSpacePressed:  root.player?.togglePlaying()
            Keys.onRightPressed:  root.player?.next()
            Keys.onLeftPressed:   root.player?.previous()
            Keys.onUpPressed:     root.setVolume(root.volume + 0.05)
            Keys.onDownPressed:   root.setVolume(root.volume - 0.05)
        }

        // Ouverture — la forme animée est une vraie PopupShape (trait du bord + raccords
        // creux + corps, d'un seul tracé), donc toujours rattachée au bord comme le panneau fini :
        //   1. le trait du bord droit pousse depuis le centre vers le haut et le bas
        //   2. une demi-sphère naît contre ce trait, déjà raccordée par ses arrondis creux
        //   3. elle s'étire à la verticale, moitié vers le haut, moitié vers le bas
        //   4. elle s'élargit vers la gauche jusqu'aux dimensions exactes du panneau,
        //      puis le contenu apparaît ; le vrai panneau (identique) prend le relais
        // Fermeture : le même chemin à l'envers, jusqu'au trait qui se rétracte au centre.
        //
        // morphFill (dessous) : fond de la forme, raccords compris
        // reveal (milieu)     : découpe le vrai panneau + son contenu à la taille du corps
        // morphLine (dessus)  : bordure en dégradé de la forme
        component MorphShape: PopupShape {
            x: root.panelWidth - Math.max(reveal.rw, 2)
            width: Math.max(reveal.rw, 2)
            y: reveal.cy - reveal.lineH / 2
            height: Math.max(reveal.lineH, 1)
            attachedEdge: "right-full"
            bodyY:      reveal.cy - reveal.rh / 2 - flareHeight - y
            bodyHeight: reveal.rh + 2 * flareHeight
            // le corps doit loger l'arrondi ET le raccord : rayon ≤ largeur − raccord
            flareWidth:  Math.min(root.fw * reveal.flare, width)
            radius:      Math.max(0, Math.min(reveal.mr, reveal.rh / 2, reveal.rw - flareWidth))
            flareHeight: root.fh * reveal.flare
            opacity: reveal.lineOp
            visible: opacity > 0.01 && reveal.lineH > 0.5
        }
        MorphShape {
            id: morphFill
            color: Appearance.background
        }

        ClippingRectangle {
            id: reveal
            readonly property real cy: sizer.bodyY + sizer.bodyH / 2
            readonly property real dot: 34
            // Hauteur de l'ÉCRAN : la fenêtre vaut 0 un instant à l'ouverture (cf. sizer.bodyY)
            readonly property real fullH: root.screen?.height ?? sizer.height
            // Corps du panneau sans ses raccords : le déroulé s'arrête là
            readonly property real bodyH: root.panelHeight
            // état de départ = fermé (le panneau est créé à l'ouverture) ; finish() pose l'état final
            property real rw: 0                     // largeur du corps, comptée depuis le bord droit
            property real rh: 0                     // hauteur du corps
            property real mr: 0                     // rayon des coins de gauche
            property real flare: 0                  // taille des raccords creux (0 → 1)
            property real content: 0
            property real lineH: 0                  // longueur du trait du bord droit
            property real lineOp: 1                 // opacité de la forme animée (0 = vrai panneau)
            property bool done: false               // animation finie : plus de découpe
            // État final (aussi appliqué si l'animation est interrompue)
            function finish() {
                rw = Qt.binding(() => root.panelWidth); rh = Qt.binding(() => bodyH)
                mr = Appearance.cornerRadius; flare = 1; content = 1
                lineH = Qt.binding(() => fullH); done = true
            }
            // pendant l'animation : découpe au corps (le côté droit dépasse, hors écran) ;
            // ensuite : toute la bande, pour laisser voir les raccords du vrai panneau
            x: done ? 0 : root.panelWidth - rw
            y: done ? 0 : cy - rh / 2
            width: done ? root.panelWidth : rw + mr
            height: done ? fullH : rh
            radius: done ? 0 : Math.min(mr, rh / 2)
            color: "transparent"

            Connections {
                target: root
                function onSlidChanged() {
                    if (root.slid) { closeAnim.stop(); openAnim.restart() }
                    else { openAnim.stop(); closeAnim.restart() }
                }
            }
            SequentialAnimation {
                id: openAnim
                ScriptAction { script: {
                    reveal.done = false
                    reveal.rw = 0; reveal.rh = 0; reveal.mr = 0; reveal.flare = 0; reveal.content = 0
                    reveal.lineH = 0; reveal.lineOp = 1
                } }
                // 1. le trait du bord pousse depuis le centre
                NumberAnimation { target: reveal; property: "lineH"; to: reveal.fullH; duration: Appearance.dur(420); easing.type: Easing.OutCubic }
                // 2. la demi-sphère naît, raccordée au trait
                ParallelAnimation {
                    NumberAnimation { target: reveal; property: "rw"; to: reveal.dot + root.fw; duration: Appearance.dur(340); easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                    NumberAnimation { target: reveal; property: "rh"; to: reveal.dot * 2; duration: Appearance.dur(340); easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                    NumberAnimation { target: reveal; property: "mr"; to: reveal.dot; duration: Appearance.dur(340); easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                    NumberAnimation { target: reveal; property: "flare"; to: 1; duration: Appearance.dur(340); easing.type: Easing.OutCubic }
                }
                // 3. déroulé vertical, centré (50 % en haut, 50 % en bas)
                NumberAnimation { target: reveal; property: "rh"; to: reveal.bodyH; duration: Appearance.dur(480); easing.type: Easing.OutCubic }
                // 4. élargissement vers la gauche, coins qui prennent le rayon du panneau
                ParallelAnimation {
                    NumberAnimation { target: reveal; property: "rw"; to: root.panelWidth; duration: Appearance.dur(460); easing.type: Easing.OutCubic }
                    NumberAnimation { target: reveal; property: "mr"; to: Appearance.cornerRadius; duration: Appearance.dur(460); easing.type: Easing.InOutCubic }
                    SequentialAnimation {
                        PauseAnimation { duration: Appearance.dur(200) }
                        NumberAnimation { target: reveal; property: "content"; to: 1; duration: Appearance.dur(340); easing.type: Easing.OutCubic }
                    }
                }
                ScriptAction { script: reveal.finish() }
                // le vrai panneau, identique, prend le relais de la forme animée
                NumberAnimation { target: reveal; property: "lineOp"; to: 0; duration: Appearance.dur(220) }
            }
            // Fermeture : le chemin inverse
            SequentialAnimation {
                id: closeAnim
                ScriptAction { script: {
                    reveal.lineOp = 1; reveal.rw = root.panelWidth; reveal.rh = reveal.bodyH
                    reveal.mr = Appearance.cornerRadius; reveal.flare = 1; reveal.lineH = reveal.fullH
                    reveal.done = false
                } }
                NumberAnimation { target: reveal; property: "content"; to: 0; duration: Appearance.dur(180); easing.type: Easing.InCubic }
                // 4⁻¹. resserrement vers le bord, coins qui s'arrondissent en demi-sphère
                ParallelAnimation {
                    NumberAnimation { target: reveal; property: "rw"; to: reveal.dot + root.fw; duration: Appearance.dur(360); easing.type: Easing.InOutCubic }
                    NumberAnimation { target: reveal; property: "mr"; to: reveal.dot; duration: Appearance.dur(360); easing.type: Easing.OutCubic }
                }
                // 3⁻¹. la bande se replie en demi-sphère
                NumberAnimation { target: reveal; property: "rh"; to: reveal.dot * 2; duration: Appearance.dur(380); easing.type: Easing.InOutCubic }
                // 2⁻¹. la demi-sphère rentre dans le trait
                ParallelAnimation {
                    NumberAnimation { target: reveal; property: "rw"; to: 0; duration: Appearance.dur(260); easing.type: Easing.InBack; easing.overshoot: 1.4 }
                    NumberAnimation { target: reveal; property: "rh"; to: 0; duration: Appearance.dur(260); easing.type: Easing.InCubic }
                    NumberAnimation { target: reveal; property: "mr"; to: 0; duration: Appearance.dur(260); easing.type: Easing.InCubic }
                    NumberAnimation { target: reveal; property: "flare"; to: 0; duration: Appearance.dur(260); easing.type: Easing.InCubic }
                }
                // 1⁻¹. le trait se rétracte vers le centre
                NumberAnimation { target: reveal; property: "lineH"; to: 0; duration: Appearance.dur(300); easing.type: Easing.InCubic }
            }

        // Corps du panneau, pleine taille, recalé sous la zone révélée
        Item {
            x: -reveal.x
            y: -reveal.y
            width: root.panelWidth
            height: reveal.fullH

            // Absorbe les clics sur le panneau seulement (au-dessus/en dessous,
            // un clic ferme comme partout ailleurs).
            MouseArea { y: sizer.bodyY; width: parent.width; height: sizer.bodyH }

            PopupShape {
                anchors.fill: parent
                attachedEdge: "right-full"
                bodyY:        sizer.bodyY
                bodyHeight:   sizer.bodyH
                color:        Appearance.background
                radius:       Appearance.cornerRadius
                flareWidth:   root.fw
                flareHeight:  root.fh
                borderColor:    Appearance.outline
                // masquée pendant l'animation : le contour animé la dessine à la même place,
                // elle ne revient qu'à la fin (une seule ligne visible à tout moment)
                borderWidth:    reveal.content >= 0.999 ? 2 : 0
                borderAnimated: root.windowVisible && Appearance.animationsEnabled
            }

            ColumnLayout {
                x: 22; width: parent.width - 44
                y: sizer.bodyY + root.fh + 18 + (1 - reveal.content) * 10
                transform: Scale { origin.x: (root.panelWidth - 44) / 2; xScale: root.onLeft ? -1 : 1 }
                opacity: reveal.content
                height: root.panelHeight - 36
                spacing: 14

                // ── En-tête ───────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        text: ""
                        font.family: Appearance.font.family; font.pixelSize: 26
                        color: Appearance.colors.accent
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Spotify"
                        font.family: Appearance.font.family; font.pixelSize: 19; font.weight: Font.Bold
                        color: Appearance.colors.fg
                    }
                    IconBtn { glyph: "󰏌"; onTap: root.openWindow() }      // fenêtre Spotify
                    IconBtn { glyph: "󰅖"; onTap: Popups.spotifyOpen = false }
                }

                // ── Spotify fermé ─────────────────────────────────────────────
                Item {
                    visible: root.player === null
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Column {
                        anchors.centerIn: parent
                        spacing: 16
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰓇"; font.family: Appearance.font.family; font.pixelSize: 90
                            color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Spotify n'est pas lancé"
                            font.family: Appearance.font.family; font.pixelSize: 16
                            color: Appearance.colors.dim
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: launchTxt.implicitWidth + 44; height: 46; radius: 23
                            color: Appearance.colors.accent
                            Text {
                                id: launchTxt
                                anchors.centerIn: parent; text: "Lancer Spotify"
                                font.family: Appearance.font.family; font.pixelSize: 15; font.weight: Font.Bold
                                color: Appearance.textOn(Appearance.colors.accent)
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openWindow() }
                        }
                    }
                }

                // ── Lecteur ───────────────────────────────────────────────────
                ClippingRectangle {
                    visible: root.player !== null
                    Layout.fillWidth: true
                    Layout.preferredHeight: width
                    radius: 18
                    color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.06)
                    Text {
                        anchors.centerIn: parent; visible: cover.status !== Image.Ready
                        text: "󰝚"; font.family: Appearance.font.family; font.pixelSize: 80
                        color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
                    }
                    Image {
                        id: cover
                        anchors.fill: parent
                        source: art.local
                        sourceSize.width: 800
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                Column {
                    visible: root.player !== null
                    Layout.fillWidth: true
                    spacing: 3
                    Text {
                        width: parent.width
                        text: root.player?.trackTitle || "Rien en lecture"
                        font.family: Appearance.font.family; font.pixelSize: 19; font.weight: Font.Bold
                        color: Appearance.colors.fg; elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: [root.player?.trackArtist, root.player?.trackAlbum].filter(x => x).join("  ·  ")
                        font.family: Appearance.font.family; font.pixelSize: 14
                        color: Appearance.colors.dim; elide: Text.ElideRight
                    }
                }

                // Progression (clic/glisser = se déplacer dans le morceau)
                ColumnLayout {
                    visible: root.player !== null
                    Layout.fillWidth: true
                    spacing: 4
                    Slider {
                        Layout.fillWidth: true
                        value: root.player && root.player.length > 0 ? root.player.position / root.player.length : 0
                        enabled: root.player?.canSeek ?? false
                        onMoved: (v) => { if (root.player) root.player.position = v * root.player.length }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: root.fmt(root.player?.position ?? 0); font.family: Appearance.font.family; font.pixelSize: 12; color: Appearance.colors.dim }
                        Item { Layout.fillWidth: true }
                        Text { text: root.fmt(root.player?.length ?? 0); font.family: Appearance.font.family; font.pixelSize: 12; color: Appearance.colors.dim }
                    }
                }

                // Commandes
                RowLayout {
                    visible: root.player !== null
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 14
                    IconBtn {
                        glyph: "󰒝"; on: root.player?.shuffle ?? false
                        enabled: root.player?.shuffleSupported ?? false
                        onTap: root.player.shuffle = !root.player.shuffle
                    }
                    IconBtn { glyph: "󰒮"; size: 52; onTap: root.player?.previous() }
                    IconBtn { glyph: root.playing ? "󰏤" : "󰐊"; size: 68; primary: true; onTap: root.player?.togglePlaying() }
                    IconBtn { glyph: "󰒭"; size: 52; onTap: root.player?.next() }
                    IconBtn {
                        readonly property int st: root.player?.loopState ?? MprisLoopState.None
                        glyph: st === MprisLoopState.Track ? "󰑘" : "󰑖"; on: st !== MprisLoopState.None
                        enabled: root.player?.loopSupported ?? false
                        // Aucune → playlist → morceau → aucune
                        onTap: root.player.loopState = st === MprisLoopState.None ? MprisLoopState.Playlist
                                                     : st === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
                    }
                }

                // Volume de Spotify
                RowLayout {
                    visible: root.player !== null && root.streams.length > 0
                    Layout.fillWidth: true
                    spacing: 12
                    Text {
                        text: root.volume < 0.01 ? "󰖁" : root.volume < 0.5 ? "󰖀" : "󰕾"
                        font.family: Appearance.font.family; font.pixelSize: 20; color: Appearance.colors.dim
                    }
                    Slider { Layout.fillWidth: true; value: root.volume; onMoved: (v) => root.setVolume(v) }
                    Text {
                        Layout.preferredWidth: 34; horizontalAlignment: Text.AlignRight
                        text: Math.round(root.volume * 100)
                        font.family: Appearance.font.family; font.pixelSize: 13; color: Appearance.colors.dim
                    }
                }

                Item { Layout.fillHeight: true; visible: root.player !== null }
            }
        }
        }

        // Bordure de la forme animée (trait du bord + raccords + corps, un seul tracé),
        // en dégradé animé comme celle du panneau fini
        MorphShape {
            id: morphLine
            color: "transparent"
            borderColor: Appearance.outline
            borderWidth: 2
            borderAnimated: Appearance.animationsEnabled && visible
        }
    }

    // ── Bouton rond ───────────────────────────────────────────────────────────
    component IconBtn: Rectangle {
        id: btn
        property string glyph
        property int size: 40
        property bool on: false
        property bool primary: false
        signal tap()
        implicitWidth: size; implicitHeight: size; radius: size / 2
        opacity: enabled ? 1 : 0.35
        color: primary ? Appearance.colors.accent
             : hov.hovered ? ColorUtils.applyAlpha(Appearance.colors.fg, 0.14)
             : on ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.25) : "transparent"
        Behavior on color { ColorAnimation { duration: Appearance.dur(120) } }
        Text {
            anchors.centerIn: parent; text: btn.glyph
            font.family: Appearance.font.family; font.pixelSize: btn.size * 0.5
            color: btn.primary ? Appearance.textOn(Appearance.colors.accent)
                 : btn.on ? Appearance.colors.accent : Appearance.colors.fg
        }
        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
        MouseArea { anchors.fill: parent; onClicked: btn.tap() }
    }

    // ── Curseur horizontal (progression, volume) ──────────────────────────────
    component Slider: Item {
        id: sl
        property real value: 0
        signal moved(real v)
        implicitHeight: 18
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 6; radius: 3
            color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.12)
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, sl.value)); height: parent.height; radius: 3
                color: Appearance.colors.accent
            }
        }
        Rectangle {
            visible: sl.enabled
            x: sl.width * Math.max(0, Math.min(1, sl.value)) - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14; radius: 7
            color: Appearance.colors.fg
        }
        MouseArea {
            anchors.fill: parent; anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            function at(m) { sl.moved(Math.max(0, Math.min(1, (m.x - 6) / sl.width))) }
            onPressed: (m) => at(m)
            onPositionChanged: (m) => at(m)
        }
    }
}
