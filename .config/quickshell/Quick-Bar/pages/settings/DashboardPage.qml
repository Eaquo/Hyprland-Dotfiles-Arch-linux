import QtQuick
import QtQuick.Layouts
import qs.core

// DashboardPage — Réglages › Panneaux › Dashboard ([dashboard] width · height · tabs).
ColumnLayout {
    id: page
    spacing: 18

    // Même catalogue que panels/Dashboard.qml (allTabs)
    readonly property var all: [
        { key: "home", icon: "󰋜", label: "Home" }, { key: "stats", icon: "󰻠", label: "System" },
        { key: "kanban", icon: "󰄬", label: "Tasks" }, { key: "files", icon: "󰉋", label: "Files" },
        { key: "wall", icon: "󰸉", label: "Wall" }, { key: "eq", icon: "󰓃", label: "Eq" },
        { key: "discord", icon: "󰙯", label: "Discord" }
    ]
    readonly property var items: {
        const on = Config.get("dashboard.tabs", all.map(t => t.key))
        const keys = Array.isArray(on) ? on : []
        const first = keys.map(k => all.find(t => t.key === k)).filter(t => t).map(t => Object.assign({}, t, { on: true }))
        return first.concat(all.filter(t => keys.indexOf(t.key) < 0).map(t => Object.assign({}, t, { on: false })))
    }

    PageHeader { title: "Dashboard"; sub: "[dashboard] dans config.toml — s'ouvre par un clic sur l'horloge ou le visualiseur" }

    SetCard {
        title: "Taille"
        SetRow { title: "Largeur"; SetSlider { implicitWidth: 300; from: 700; to: 1400; step: 20; suffix: " px"; value: Appearance.dashboardWidth
                 onMoved: (v) => Config.set("dashboard.width", v === 900 ? null : v) } }
        SetRow { title: "Hauteur"; SetSlider { implicitWidth: 300; from: 400; to: 900; step: 20; suffix: " px"; value: Appearance.dashboardHeight
                 onMoved: (v) => Config.set("dashboard.height", v === 520 ? null : v) } }
    }

    SetCard {
        title: "Onglets"
        Text {
            text: "Ordre des onglets ; le premier actif est la page d'accueil."
            font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim
        }
        SetOrderList {
            Layout.fillWidth: true
            items: page.items
            onEdited: (l) => {
                const keys = l.filter(t => t.on).map(t => t.key)
                Config.set("dashboard.tabs", keys.join() === page.all.map(t => t.key).join() ? null : keys)
            }
        }
    }
}
