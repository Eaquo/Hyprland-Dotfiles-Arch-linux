import QtQuick
import QtQuick.Layouts
import qs.core

// RefreshPage — Réglages › Barre › Rafraîchissement : intervalles de mise à jour ([refresh], en secondes).
// Plus long = moins de processus lancés, donc moins de CPU au repos.
ColumnLayout {
    id: page
    spacing: 18

    // [clé, titre, description, défaut, min, max, pas, unité affichée (1 = s, 60 = min)]
    readonly property var groups: [
        ["Barre", [
            ["stats", "Stats système", "CPU, RAM, disque, températures (démon, sans sous-processus)", 2, 1, 10, 1, 1],
            ["stats_hover", "Stats au survol", "pendant qu'une carte de stats est ouverte", 1, 0.5, 5, 0.5, 1],
            ["audio", "Volume", "", 2, 1, 10, 1, 1],
            ["media", "Lecteur et visualiseur", "titre en cours", 2, 1, 10, 1, 1],
            ["network", "Réseau", "", 8, 2, 60, 1, 1],
            ["bluetooth", "Bluetooth", "", 5, 2, 60, 1, 1],
            ["notifications", "Notifications", "compteur de swaync", 3, 1, 30, 1, 1],
            ["localsend", "LocalSend", "", 3, 1, 30, 1, 1],
            ["layout", "Disposition", "", 4, 1, 30, 1, 1]
        ]],
        ["Tâches de fond", [
            ["updates", "Mises à jour", "vérification des paquets", 1800, 300, 14400, 300, 60],
            ["health", "Bilan de santé", "disques, services, Proxmox…", 300, 60, 3600, 60, 60]
        ]]
    ]

    PageHeader { title: "Rafraîchissement"; sub: "[refresh] dans config.toml — en secondes" }

    Repeater {
        model: page.groups
        delegate: SetCard {
            id: g
            required property var modelData
            title: modelData[0]
            Repeater {
                model: g.modelData[1]
                delegate: SetRow {
                    id: r
                    required property var modelData
                    readonly property real unit: modelData[7]
                    title: modelData[1]
                    desc: modelData[2] + (modelData[2] ? " · " : "") + "défaut " + (modelData[3] / unit) + (unit === 60 ? " min" : " s")
                    SetSlider {
                        implicitWidth: 300
                        from: r.modelData[4] / r.unit; to: r.modelData[5] / r.unit; step: r.modelData[6] / r.unit
                        decimals: r.modelData[6] < 1 ? 1 : 0
                        suffix: r.unit === 60 ? " min" : " s"
                        value: Config.ms(r.modelData[0], r.modelData[3]) / 1000 / r.unit
                        onMoved: (v) => Config.set("refresh." + r.modelData[0], v * r.unit === r.modelData[3] ? null : v * r.unit)
                    }
                }
            }
        }
    }
    Text {
        Layout.fillWidth: true; wrapMode: Text.WordWrap
        text: "Les stats du dashboard ne tournent que lorsqu'il est ouvert. L'horloge suit son format (Barre › Modules)."
        font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim
    }
}
