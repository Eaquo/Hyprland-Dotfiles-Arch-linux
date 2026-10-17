import QtQuick
import QtQuick.Layouts
import qs.core

// TouchPage — Réglages › Panneaux › Panneau tactile : onglets (ShellState.touchTabs),
// zoom ([touchpanel] scale + [touchpanel.pages]), pause en jeu ([game] break_*).
ColumnLayout {
    id: page
    spacing: 18

    PageHeader { title: "Panneau tactile"; sub: "[touchpanel] dans config.toml · onglets dans user_data/shell_state.json" }

    SetCard {
        title: "Affichage"
        SetRow {
            title: "Panneau tactile"; desc: "plein écran sur l'écran tactile (choix de l'écran : Général)"
            SetSwitch { on: ShellState.touchPanelOn; onToggled: ShellState.touchPanelOn = !ShellState.touchPanelOn }
        }
        SetRow {
            title: "Zoom général"; desc: "textes, boutons et vignettes de toutes les pages"
            SetSlider { implicitWidth: 300; from: 0.7; to: 1.8; step: 0.05; decimals: 2; suffix: " ×"
                        value: Number(Config.get("touchpanel.scale", 1)); onMoved: (v) => Config.set("touchpanel.scale", v) }
        }
    }

    SetCard {
        title: "Onglets"
        Text { text: "Ordre et activation — l'onglet Game n'apparaît qu'en jeu. Zoom par page à droite."
               font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim }
        SetOrderList {
            Layout.fillWidth: true
            items: TouchTabs.tabs.map(t => Object.assign({}, t, { note: "×" + Number(Config.get("touchpanel.pages." + t.key, t.scale || 1)).toFixed(2) }))
            onEdited: (l) => TouchTabs.save(l)
        }
    }

    SetCard {
        title: "Zoom par page"
        Repeater {
            model: TouchTabs.all
            delegate: SetRow {
                id: zr
                required property var modelData
                title: modelData.icon + "  " + modelData.label
                SetSlider { implicitWidth: 300; from: 0.7; to: 2; step: 0.05; decimals: 2; suffix: " ×"
                            value: Number(Config.get("touchpanel.pages." + zr.modelData.key, zr.modelData.scale || 1))
                            onMoved: (v) => Config.set("touchpanel.pages." + zr.modelData.key, v === (zr.modelData.scale || 1) ? null : v) }
            }
        }
    }

    SetCard {
        title: "Pause en jeu (SUPER+T)"
        SetRow {
            title: "Retour automatique au jeu"; desc: "relancé à chaque interaction"
            SetSwitch { on: GameBreak.autoReturn; onToggled: Config.set("game.break_auto_return", on ? false : null) }
        }
        SetRow {
            title: "Durée avant retour"
            SetSlider { implicitWidth: 300; from: 5; to: 120; step: 5; suffix: " s"; value: GameBreak.autoReturnMs / 1000
                        onMoved: (v) => Config.set("game.break_seconds", v === 20 ? null : v) }
        }
        SetRow {
            title: "Ouvrir le panneau tactile pendant la pause"
            SetSwitch { on: GameBreak.openTouchPanel; onToggled: Config.set("game.break_open_touchpanel", on ? false : null) }
        }
    }
}
