import QtQuick
import QtQuick.Layouts
import qs.core

// StatsPage — Réglages › Système › Stats et seuils : affichage des stats de la barre et
// seuils d'alerte (ShellState.statsPrefs, mêmes réglages que les menus clic droit des stats).
ColumnLayout {
    id: page
    spacing: 18

    readonly property var prefs: ShellState.statsPrefs
    function setPref(k, v) { const p = Object.assign({}, ShellState.statsPrefs); p[k] = v; ShellState.statsPrefs = p }

    PageHeader { title: "Stats et seuils"; sub: "user_data/shell_state.json (statsPrefs) — aussi au clic droit sur une stat" }

    SetCard {
        title: "Affichage"
        SetRow { title: "Mémoire"; SetSeg { options: [[false, "Go utilisés"], [true, "%"]]; current: !!page.prefs.ramPct; onPicked: (v) => page.setPref("ramPct", v) } }
        SetRow { title: "Disque"; SetSeg { options: [[false, "% utilisé"], [true, "Go libres"]]; current: !!page.prefs.diskFree; onPicked: (v) => page.setPref("diskFree", v) } }
    }
    SetCard {
        title: "Alertes de température"
        canReset: true
        onResetRequested: { page.setPref("tempAlert", 82); page.setPref("gpuAlert", 95); page.setPref("nvmeAlert", 70) }
        Text { text: "La puce passe à l'orange 10–12° avant le seuil, au rouge au seuil."
               font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim }
        SetRow { title: "Processeur"; SetSlider { implicitWidth: 300; from: 60; to: 100; suffix: "°"; value: page.prefs.tempAlert || 82; onMoved: (v) => page.setPref("tempAlert", v) } }
        SetRow { title: "Carte graphique (junction)"; SetSlider { implicitWidth: 300; from: 70; to: 110; suffix: "°"; value: page.prefs.gpuAlert || 95; onMoved: (v) => page.setPref("gpuAlert", v) } }
        SetRow { title: "SSD NVMe"; SetSlider { implicitWidth: 300; from: 50; to: 85; suffix: "°"; value: page.prefs.nvmeAlert || 70; onMoved: (v) => page.setPref("nvmeAlert", v) } }
    }
    SetCard {
        title: "Rafraîchissement"
        SetRow { title: "Intervalles des stats"; desc: "2 s au repos, 1 s au survol par défaut"
                 SetButton { label: "󰔛  Rafraîchissement"; onTap: Popups.settingsPage = "barint" } }
    }
}
