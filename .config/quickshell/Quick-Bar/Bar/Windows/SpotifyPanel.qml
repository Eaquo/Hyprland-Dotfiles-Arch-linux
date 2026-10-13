import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../Components/"
import "../Common/"
import "../Common/functions/"

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
    readonly property int panelWidth:  440
    readonly property int panelHeight: 730

    // Écran principal = tout sauf le tactile Xeneon.
    screen: {
        const all = Quickshell.screens
        return all.find(s => (s.model || "").toUpperCase().indexOf("XENEON") === -1) || all[0]
    }

    color:   "transparent"
    visible: windowVisible
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.namespace:     "quickshell:spotify"
    WlrLayershell.keyboardFocus: (windowVisible && Popups.spotifyOpen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool windowVisible: false
    Connections {
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
    Timer { id: closeTimer; interval: root.animDuration + 20; onTriggered: root.windowVisible = false }

    IpcHandler {
        target: "spotify"
        function toggle() {
            if (!Popups.spotifyOpen) Popups.closeAll()
            Popups.spotifyOpen = !Popups.spotifyOpen
        }
    }

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
    // On suit TOUS les flux de lecture : leurs propriétés (nom d'appli) ne sont
    // chargées qu'une fois suivis, on ne peut donc filtrer qu'après.
    readonly property var playback: Pipewire.nodes.values.filter(n => n.isStream && n.isSink && n.audio)
    PwObjectTracker { objects: root.playback }
    readonly property var streams: playback.filter(n =>
        ((n.properties || {})["application.name"] || "").toLowerCase() === "spotify")
    readonly property real volume: streams.length ? streams[0].audio.volume : 0
    function setVolume(v) { for (const n of streams) n.audio.volume = Math.max(0, Math.min(1, v)) }

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
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: root.panelWidth
        clip: true
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

        // Glissement : le corps entier se déplace, de hors écran (à droite) vers
        // sa place à l'ouverture, et repart vers la droite à la fermeture.
        Item {
            width: root.panelWidth
            height: parent.height
            x: root.slid ? 0 : root.panelWidth
            Behavior on x {
                NumberAnimation {
                    duration: root.animDuration
                    easing.type: root.slid ? Easing.OutCubic : Easing.InCubic
                }
            }

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
                borderWidth:    2          // gardé pendant le glissement de fermeture
                borderAnimated: root.windowVisible && Appearance.animationsEnabled
            }

            ColumnLayout {
                x: 22; width: parent.width - 44
                y: sizer.bodyY + root.fh + 18
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
                ColumnLayout {
                    visible: root.player === null
                    Layout.fillWidth: true; Layout.fillHeight: true
                    spacing: 16
                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰓇"; font.family: Appearance.font.family; font.pixelSize: 90
                        color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Spotify n'est pas lancé"
                        font.family: Appearance.font.family; font.pixelSize: 16
                        color: Appearance.colors.dim
                    }
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
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
                    Item { Layout.fillHeight: true }
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
        Behavior on color { ColorAnimation { duration: 120 } }
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
