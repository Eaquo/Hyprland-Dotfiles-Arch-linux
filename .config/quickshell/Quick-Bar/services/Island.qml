pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.core

// Island — île dynamique (panels/DynamicIsland.qml) : une pastille au centre de la barre qui s'agrandit quelques
// secondes pour annoncer un événement, puis se rétracte. File d'attente : un événement à la fois.
//   Island.show({ title, sub, image (chemin), art (URL de pochette), glyph, accent, ms })
// Sources : morceau suivant (MPRIS, natif ; toast en haut à droite sauf [island] music = true), périphériques
// ([island] devices = true),
// capture d'écran (services/Shots.qml). [island] enabled, music, devices dans config.toml.
Singleton {
    id: root
    readonly property bool enabled: Config.get("island.enabled", true) !== false
    property var current: null            // événement affiché (gardé pendant la rétraction)
    property bool open: false             // pastille agrandie
    property var queue: []

    function show(o) {
        // en jeu : l'île se tait (morceau suivant, captures, périphériques) — sauf [island] in_game = true
        if (!enabled || !o || (GameMode.active && Config.get("island.in_game", false) !== true)) return
        queue = queue.concat([o])
        if (!current) next()
    }
    function next() {
        if (!queue.length) { current = null; return }
        current = queue[0]; queue = queue.slice(1)
        open = true
        hold.interval = current.ms || 4200
        hold.restart()
    }
    function dismiss() { hold.stop(); open = false; gap.restart() }
    Timer { id: hold; onTriggered: root.dismiss() }
    Timer { id: gap; interval: Appearance.dur(520); onTriggered: root.next() }   // le temps de se rétracter

    // ── morceau suivant : lecteur en lecture dont le titre change (rafale titre/artiste/pochette = 1 annonce) ──
    property bool armed: false
    Timer { interval: 6000; running: true; onTriggered: root.armed = true }     // pas d'annonce au démarrage
    property var _player: null
    property string _last: ""
    Instantiator {
        model: Mpris.players
        delegate: Connections {
            required property var modelData
            target: modelData
            function onTrackTitleChanged() { if (modelData.isPlaying) { root._player = modelData; trackKick.restart() } }
            function onIsPlayingChanged() { if (modelData.isPlaying) { root._player = modelData; trackKick.restart() } }
        }
    }
    Timer {
        id: trackKick; interval: 600
        onTriggered: {
            const p = root._player
            if (!root.armed || !p || !p.isPlaying || Config.get("island.music", true) === false) return
            const key = (p.trackTitle || "") + "|" + (p.trackArtist || "")
            if (!p.trackTitle || key === root._last) return
            root._last = key
            if (Config.get("island.music", false) === true) {   // [island] music = true : sur l'île au lieu d'un toast
                root.show({ title: p.trackTitle, sub: p.trackArtist || p.identity || "", art: p.trackArtUrl || "", glyph: "󰎆" })
                return
            }
            // toast en haut à droite comme les autres notifications, pochette en icône (téléchargée à part : pas
            // d'https dans une Image) ; au nom du lecteur, donc silencieux en jeu (services/NotificationService.qml)
            Quickshell.execDetached(["sh", "-c",
                'f="${XDG_RUNTIME_DIR:-/tmp}/qb-music-art"; : > "$f"; '
                + 'case "$1" in http*) curl -sfm 5 -o "$f" "$1" ;; file://*) cp "${1#file://}" "$f" ;; esac; '
                + '[ -s "$f" ] && i="$f" || i=audio-x-generic; exec notify-send -a "$2" -i "$i" "$3" "$4"',
                "sh", p.trackArtUrl || "", p.identity || "Musique", p.trackTitle, p.trackArtist || ""])
        }
    }
}
