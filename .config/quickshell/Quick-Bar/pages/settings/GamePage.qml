import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.core

// GamePage — Réglages › Jeu › Mode jeu ([game] dans config.toml, lu par core/GameMode.qml).
// Un jeu = une fenêtre avec le tag Hyprland « games » (WindowRulesGaming.lua).
ColumnLayout {
    id: page
    spacing: 18

    property var presets: []
    property var rgbModes: []
    Process {
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/audio/eq_control.py", "list"]
        stdout: StdioCollector { onStreamFinished: { try { page.presets = JSON.parse(text).presets.filter(p => p !== "quickbar_eq") } catch (e) {} } }
    }
    Process {
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/rgb/backend.py"]
        stdout: StdioCollector { onStreamFinished: { try { page.rgbModes = JSON.parse(text).modes.map(m => [String(m.command).trim().split(/\s+/).pop(), m.name]) } catch (e) {} } }
    }

    PageHeader { title: "Mode jeu"; sub: "[game] dans config.toml" + (GameMode.active ? " · en jeu : " + GameMode.gameTitle : "") }

    SetCard {
        title: "Égaliseur"
        SetRow {
            title: "Changer d'EQ en jeu"; desc: "le preset d'avant revient à la sortie du jeu"
            SetSwitch { on: GameMode.switchEq; onToggled: Config.set("game.switch_eq", on ? false : null) }
        }
        SetRow {
            title: "Preset en jeu"; wide: true
            opacity: GameMode.switchEq ? 1 : 0.4
            Flow {
                width: parent ? parent.width : 600
                spacing: 6
                SetButton { label: "Auto (Bose-FPS / KZ-FPS)"; active: GameMode.eqPreset === ""; onTap: Config.set("game.eq_preset", null) }
                Repeater {
                    model: page.presets
                    delegate: SetButton { required property string modelData; label: modelData; active: GameMode.eqPreset === modelData
                                          onTap: Config.set("game.eq_preset", modelData) }
                }
            }
        }
    }

    SetCard {
        title: "Éclairage RGB"
        SetRow {
            title: "LED à la couleur du jeu"; desc: "couleur dominante de la bannière Steam"
            SetSwitch { on: GameMode.syncRgb; onToggled: Config.set("game.sync_rgb", on ? false : null) }
        }
        SetRow {
            title: "Sinon, mode RGB"; desc: "jeux sans bannière, ou couleur du jeu désactivée"; wide: true
            Flow {
                width: parent ? parent.width : 600
                spacing: 6
                SetButton { label: "Inchangé"; active: GameMode.rgbMode === ""; onTap: Config.set("game.rgb_mode", null) }
                Repeater {
                    model: page.rgbModes
                    delegate: SetButton { required property var modelData; label: modelData[1]; active: GameMode.rgbMode === modelData[0]
                                          onTap: Config.set("game.rgb_mode", modelData[0]) }
                }
            }
        }
    }

    SetCard {
        title: "Ce qui compte comme un jeu"
        resetKeys: ["game.exclude"]
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Une fenêtre est un jeu si Hyprland lui met le tag « games » (Steam, gamescope, programmes Windows .exe). Les logiciels Windows qui ne sont pas des jeux sont ignorés s'ils sont dans cette liste (un morceau de leur nom de fenêtre suffit)."
            font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim
        }
        SetRow {
            title: "Pas des jeux"; desc: "séparés par des virgules — ex. fusion360, autodesk, blender"; wide: true
            SetInput {
                width: parent ? parent.width : 500
                text: GameMode.exclude.join(", ")
                placeholder: "fusion360, autodesk, 7zfm, winecfg…"
                onCommitted: (t) => Config.set("game.exclude", t.split(",").map(x => x.trim()).filter(x => x !== ""))
            }
        }
    }

    SetCard {
        title: "Pendant le jeu"
        SetRow {
            title: "Ne pas déranger"; desc: "notifications coupées le temps du jeu"
            SetSwitch { on: Config.get("game.dnd", false) === true; onToggled: Config.set("game.dnd", on ? null : true) }
        }
        SetRow {
            title: "Pause tactile (SUPER+T)"; desc: GameBreak.autoReturn ? "retour au jeu après " + GameBreak.autoReturnMs / 1000 + " s" : "pas de retour automatique"
            SetButton { label: "󰦧  Régler"; onTap: Popups.settingsPage = "touch" }
        }
    }
}
