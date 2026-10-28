pragma Singleton
import QtQuick

// TouchTabs — catalogue des onglets du panneau tactile (TouchPanel.qml) et de leur état
// (ordre + activation dans ShellState.touchTabs). Édité par le bouton ⚙ du panneau
// et par Réglages › Panneaux › Panneau tactile.
//   key    identifiant (sauvé dans user_data/shell_state.json)
//   icon   glyphe Nerd Font · label  texte de la pastille
//   src    page QML, chemin relatif à panels/TouchPanel.qml
//   scale  zoom par défaut de la page (1.0) — remplacé par config.toml [touchpanel.pages]
//   keep   true = reste chargée même cachée (page par défaut, ou scan coûteux)
//   def    false = désactivé tant que l'utilisateur ne l'active pas
QtObject {
    readonly property var all: [
        { key: "game",    icon: "󰮂", label: "Game",    src: "../pages/game/GameModeTab.qml" },   // visible seulement en jeu
        { key: "home",    icon: "󰋜", label: "Home",    src: "../pages/home/TouchHome.qml",  keep: true },
        { key: "grid",    icon: "󰕰", label: "Grid",    src: "../pages/grid/GridDash.qml" },
        { key: "ws",      icon: "󱂬", label: "Spaces",  src: "../pages/spaces/WorkspacesTab.qml" },
        { key: "stats",   icon: "󰻠", label: "System",  src: "../pages/stats/TouchStats.qml", scale: 1.15 },
        { key: "kanban",  icon: "󰄬", label: "Tasks",   src: "../pages/kanban/KanbanBoard.qml", scale: 1.15, def: false },
        { key: "files",   icon: "󰉋", label: "Files",   src: "../pages/files/FileBrowser.qml", scale: 1.35 },
        { key: "wall",    icon: "󰸉", label: "Wall",    src: "../pages/wall/WallpaperTab.qml" },
        { key: "colors",  icon: "󰏘", label: Appearance.paletteName, src: "../pages/wallust/WallustTab.qml" },
        { key: "devices", icon: "󰁹", label: "Devices", src: "../pages/battery/DashBattery.qml" },
        { key: "eq",      icon: "󰓃", label: "Eq",      src: "../pages/eq/EqDash.qml" },
        { key: "mixer",   icon: "󰕾", label: "Mixer",   src: "../pages/mixer/MixerTab.qml" },
        { key: "discord", icon: "󰙯", label: "Discord", src: "../pages/discord/DiscordChat.qml" },
        { key: "deck",    icon: "󰀻", label: "Apps",    src: "../pages/apps/StreamDeck.qml" },
        { key: "games",   icon: "󰊴", label: "Games",   src: "../pages/games/GameTab.qml" },   // déchargé hors de l'onglet : le scan des jeux ne prend que 0,1 s
        { key: "rgb",     icon: "󰌵", label: "RGB",     src: "../pages/rgb/RgbTab.qml" },
        { key: "health",  icon: "󰓙", label: "Santé",   src: "../pages/health/HealthTab.qml" },
    ]

    // Catalogue fusionné avec la config sauvée : [{ key, icon, label, on, … }].
    readonly property var tabs: {
        const byKey = {}, seen = {}, out = []
        for (const t of all) byKey[t.key] = t
        for (const s of (ShellState.touchTabs || []))
            if (byKey[s.key] && !seen[s.key]) {
                seen[s.key] = true
                out.push(Object.assign({}, byKey[s.key], { on: s.on !== false }))
            }
        for (const t of all)
            if (!seen[t.key]) out.push(Object.assign({}, t, { on: t.def !== false }))
        return out
    }
    function save(list) { ShellState.touchTabs = list.map(t => ({ key: t.key, on: t.on })) }
}
