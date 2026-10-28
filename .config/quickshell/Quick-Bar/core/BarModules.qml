pragma Singleton
import QtQuick

// BarModules — catalogue des modules de la barre et disposition ([bar.layout] dans config.toml).
// Bar.qml associe chaque clé à son composant ; la page Réglages › Barre › Modules édite la disposition.
QtObject {
    id: root

    readonly property var list: [
        { key: "launcher",      name: "Lanceur",           ic: "󰣇", desc: "menu des applications" },
        { key: "stats",         name: "Stats système",     ic: "󰍛", desc: "CPU, RAM, disque, températures" },
        { key: "notifications", name: "Notifications",     ic: "󰂚", desc: "centre de notifications" },
        { key: "cava",          name: "Visualiseur",       ic: "󰎈", desc: "barres audio, ouvre le dashboard" },
        { key: "clock",         name: "Horloge",           ic: "󰥔", desc: "heure, ouvre le dashboard" },
        { key: "workspaces",    name: "Espaces",           ic: "󰕰", desc: "espaces de travail Hyprland" },
        { key: "layout",        name: "Disposition",       ic: "󰕴", desc: "disposition des fenêtres" },
        { key: "localsend",     name: "LocalSend",         ic: "󰒗", desc: "partage de fichiers en local" },
        { key: "updates",       name: "Mises à jour",      ic: "󰚰", desc: "paquets à mettre à jour" },
        { key: "minimized",     name: "Fenêtres réduites", ic: "󱂩", desc: "SUPER + molette / boutons latéraux (remplace niflveil)" },
        { key: "proxmox",       name: "Proxmox",           ic: "󰒋", desc: "mises à jour de l'hôte et des LXC" },
        { key: "media",         name: "Lecteur",           ic: "󰝚", desc: "titre en cours (masqué sans musique)" },
        { key: "eq",            name: "Égaliseur",         ic: "󰓃", desc: "presets EasyEffects" },
        { key: "tray",          name: "Zone de notification", ic: "󰀻", desc: "icônes des applications" },
        { key: "network",       name: "Réseau",            ic: "󰤨", desc: "Wi-Fi / Ethernet" },
        { key: "bluetooth",     name: "Bluetooth",         ic: "󰂯", desc: "état et appareils" },
        { key: "audio",         name: "Volume",            ic: "󰕾", desc: "volume et sorties" },
        { key: "power",         name: "Alimentation",      ic: "󰐥", desc: "verrouiller, éteindre…" }
    ]
    readonly property var defaults: ({
        left:   ["launcher", "stats"],
        center: ["notifications", "cava", "clock", "workspaces", "layout", "localsend"],
        right:  ["updates", "tray", "audio", "power"]
    })

    function info(key) { return list.find(m => m.key === key) }
    // Clés inconnues ignorées, doublons retirés (un module n'apparaît qu'une fois)
    function layout(side) {
        const seen = []
        for (const s of ["left", "center", "right"]) {
            const v = Config.get("bar.layout." + s, defaults[s])
            const keys = (Array.isArray(v) ? v : defaults[s]).filter(k => info(k) && seen.indexOf(k) < 0)
            if (s === side) return keys
            seen.push(...keys)
        }
        return []
    }
    readonly property bool separators: Config.get("bar.separators", true) !== false
}
