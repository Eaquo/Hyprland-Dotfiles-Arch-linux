import QtQuick
import QtQuick.Layouts
import qs.core

// SessionPage — Réglages › Panneaux › Écran de session ([session] style, lu par panels/SessionPanel.qml).
ColumnLayout {
    id: page
    spacing: 18

    PageHeader { title: "Écran de session"; sub: "[session] dans config.toml — CTRL+ALT+P ou ⏻ dans la barre" }

    SetCard {
        title: "Style"
        resetKeys: ["session.style"]
        SetRow {
            title: "Apparence"; desc: "Matrix : pluie et terminal · Minimal : grande heure · Netrunner : breach protocol · Jarvis : HUD à réacteur · Carte : carte centrée"
            SetSeg {
                options: [["matrix", "Matrix"], ["minimal", "Minimal"], ["cyber", "Netrunner"], ["jarvis", "Jarvis"], ["card", "Carte"]]
                current: String(Config.get("session.style", "matrix"))
                onPicked: (v) => Config.set("session.style", v === "matrix" ? null : v)
            }
        }
        SetRow {
            title: "Aperçu"; desc: "ouvre l'écran de session (Échap pour revenir)"
            SetButton { label: "󰐥  Ouvrir"; onTap: Popups.sessionOpen = true }
        }
    }
}
