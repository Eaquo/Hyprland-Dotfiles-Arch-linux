import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core

// SessionPage — Réglages › Panneaux › Écran de session ([session] style, lu par panels/SessionPanel.qml).
ColumnLayout {
    id: page
    spacing: 18

    PageHeader { title: "Écran de session"; sub: "[session] dans config.toml — CTRL+ALT+P ou ⏻ dans la barre" }

    SetCard {
        title: "Style"
        resetKeys: ["session.style", "menu.style"]
        SetRow {
            title: "Apparence"; desc: "Matrix : pluie et terminal · Minimal : grande heure · Netrunner : breach protocol · Jarvis : HUD à réacteur · Carte : carte centrée"
            SetSeg {
                options: [["matrix", "Matrix"], ["minimal", "Minimal"], ["cyber", "Netrunner"], ["jarvis", "Jarvis"], ["card", "Carte"]]
                current: String(Config.get("session.style", "matrix"))
                onPicked: (v) => Config.set("session.style", v === "matrix" ? null : v)
            }
        }
        SetRow {
            title: "Thème des menus"; desc: "menus Quick-Bar (SUPER, SUPER+MAJ+G…) : aussi dans le menu déroulant de leur en-tête"
            SetSeg {
                options: [["", "Comme la session"], ["matrix", "Matrix"], ["cyber", "Netrunner"], ["jarvis", "Jarvis"], ["minimal", "Minimal (palette)"], ["card", "Carte"],
                          ["cyberpunk", "Cyberpunk 2077"], ["synthwave", "Synthwave"], ["amber", "Ambre"], ["holo", "Hologramme"], ["glass", "Verre"]]
                current: String(Config.get("menu.style", ""))
                onPicked: (v) => Config.set("menu.style", v === "" ? null : v)
            }
        }
        SetRow {
            title: "Ouverture des menus"; desc: "le lanceur (Super) et les autres menus : instantané comme rofi, rapide, ou l'animation complète"
            SetSeg {
                options: [["0", "Instantané"], ["0.4", "Rapide"], ["1", "Complète"]]
                current: String(Config.get("menu.speed", 0.4))
                onPicked: (v) => Config.set("menu.speed", v === "0.4" ? null : Number(v))
            }
        }
        SetRow {
            title: "Aperçu"; desc: "ouvre l'écran de session (Échap pour revenir)"
            SetButton { label: "󰐥  Ouvrir"; onTap: Popups.sessionOpen = true }
        }
    }

    SetCard {
        title: "Verrouillage"
        resetKeys: ["lock.auto_minutes", "lock.screen_off_minutes"]
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Écran de verrouillage Quick-Bar : son fond suit le style ci-dessus. Les vidéos et les jeux qui bloquent la veille empêchent aussi le verrouillage automatique."
            font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim
        }
        SetRow {
            title: "Verrouiller automatiquement après"; desc: "0 = jamais"
            SetSlider { implicitWidth: 300; from: 0; to: 60; step: 1; suffix: " min"; value: Number(Config.get("lock.auto_minutes", 0))
                        onMoved: (v) => Config.set("lock.auto_minutes", v === 0 ? null : v) }
        }
        SetRow {
            title: "Éteindre l'écran après"; desc: "0 = jamais"
            SetSlider { implicitWidth: 300; from: 0; to: 60; step: 1; suffix: " min"; value: Number(Config.get("lock.screen_off_minutes", 0))
                        onMoved: (v) => Config.set("lock.screen_off_minutes", v === 0 ? null : v) }
        }
        SetRow {
            title: "Verrouiller maintenant"; desc: "SUPER+L"
            SetButton { label: "󰌾  Verrouiller"; onTap: Quickshell.execDetached(["qs", "-p", Quickshell.shellDir + "/shell.qml", "ipc", "call", "lock", "lock"]) }
        }
    }
}
