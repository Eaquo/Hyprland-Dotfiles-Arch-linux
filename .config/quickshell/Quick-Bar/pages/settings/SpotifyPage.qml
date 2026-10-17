import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core

// SpotifyPage — Réglages › Panneaux › Spotify et média ([spotify] width · height).
ColumnLayout {
    id: page
    spacing: 18

    PageHeader { title: "Spotify et média"; sub: "[spotify] dans config.toml — SUPER+SHIFT+S ouvre le panneau" }

    SetCard {
        title: "Panneau Spotify"
        SetRow { title: "Largeur"; SetSlider { implicitWidth: 300; from: 360; to: 640; step: 10; suffix: " px"; value: Number(Config.get("spotify.width", 440))
                 onMoved: (v) => Config.set("spotify.width", v === 440 ? null : v) } }
        SetRow { title: "Hauteur"; SetSlider { implicitWidth: 300; from: 560; to: 1000; step: 10; suffix: " px"; value: Number(Config.get("spotify.height", 730))
                 onMoved: (v) => Config.set("spotify.height", v === 730 ? null : v) } }
        SetRow {
            title: "Aperçu"; desc: "ouvre le panneau pour voir la taille"
            SetButton { label: "󰓇  Ouvrir"; onTap: { Popups.settingsOpen = false; Popups.spotifyOpen = true } }
        }
    }
    SetCard {
        title: "Lecteur de la barre"
        SetRow {
            title: "Module Lecteur"; desc: "titre en cours dans la barre (masqué sans musique) — à placer dans Barre › Modules"
            SetButton { label: "󰍜  Modules"; onTap: Popups.settingsPage = "bar" }
        }
    }
}
