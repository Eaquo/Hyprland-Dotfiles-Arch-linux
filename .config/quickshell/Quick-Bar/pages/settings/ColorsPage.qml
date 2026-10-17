import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.core
import qs.core.functions

// ColorsPage — Réglages › Apparence › Couleurs : source de la palette ([theme]).
// Wallust et Matugen sont exclusifs ; Appearance suit `theme.palette` en direct.
ColumnLayout {
    id: page
    spacing: 18

    readonly property string source: Appearance.paletteSource
    function pick(src) { Config.set("theme.palette", src) }

    PageHeader { title: "Couleurs"; sub: "[theme] palette · wallust_path · matugen_path dans config.toml" }

    SetCard {
        title: "Source des couleurs"
        SourceRow {
            key: "wallust"
            title: "Palette Wallust"
            desc: "Couleurs générées par wallust depuis le fond d'écran (Hyprland, kitty et rofi la suivent aussi)."
            pathKey: "theme.wallust_path"; defaultPath: "~/.cache/wal/wal.json"
        }
        SourceRow {
            key: "matugen"
            title: "Palette Matugen"
            desc: "Couleurs Material You générées par matugen — exclusif avec Wallust. Quick-Bar relance matugen à chaque changement de fond d'écran."
            pathKey: "theme.matugen_path"; defaultPath: "~/.cache/matugen/quickbar_colors.json"
        }
    }

    SetCard {
        title: "Matugen"
        opacity: page.source === "matugen" ? 1 : 0.45
        Behavior on opacity { NumberAnimation { duration: Appearance.dur(200) } }
        SetRow {
            title: "Couleur source"
            desc: "Quand l'image a plusieurs couleurs dominantes, laquelle garder."
            SetSeg {
                options: [["saturation", "Saturée"], ["value", "Lumineuse"], ["darkness", "Sombre"], ["less-saturation", "Douce"]]
                current: String(Config.get("theme.matugen_prefer", "saturation"))
                onPicked: (v) => { Config.set("theme.matugen_prefer", v); regen.restart() }
            }
        }
        SetRow {
            title: "Mode"
            SetSeg {
                options: [["dark", "Sombre"], ["light", "Clair"]]
                current: String(Config.get("theme.matugen_mode", "dark"))
                onPicked: (v) => { Config.set("theme.matugen_mode", v); regen.restart() }
            }
        }
        SetRow {
            title: "Régénérer maintenant"
            desc: "Relance matugen sur le fond d'écran actuel."
            SetButton { label: "󰑓  Régénérer"; onTap: Appearance.regenerateMatugen() }
        }
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Modèle : ~/.config/matugen/templates/quickbar.json (même format que wallust). Hyprland, kitty et rofi restent sur wallust tant que leurs propres modèles matugen ne sont pas ajoutés."
            font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 3; color: Appearance.colors.dim
        }
    }
    // laisse Config écrire la préférence avant de relancer matugen
    Timer { id: regen; interval: 450; onTriggered: Appearance.regenerateMatugen() }

    // ── Une source de palette : interrupteur exclusif + chemin + aperçu des couleurs ──
    component SourceRow: Rectangle {
        id: sr
        property string key: ""
        property string title: ""
        property string desc: ""
        property string pathKey: ""
        property string defaultPath: ""
        readonly property bool on: page.source === key
        readonly property string path: String(Config.get(pathKey, defaultPath))
        property var pal: []
        Layout.fillWidth: true
        implicitHeight: srCol.implicitHeight + 24
        radius: 12
        color: on ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.08) : "transparent"
        border.width: 1; border.color: on ? Appearance.colors.accent : ColorUtils.applyAlpha(Appearance.colors.fg, 0.1)
        Behavior on color { ColorAnimation { duration: Appearance.dur(220) } }

        FileView {
            path: "file://" + (sr.path.startsWith("~") ? Quickshell.env("HOME") + sr.path.slice(1) : sr.path)
            watchChanges: true
            onFileChanged: reload()
            onLoaded: { try { const j = JSON.parse(text()); sr.pal = [j.special.background, j.special.foreground]
                              .concat(Array.from({ length: 16 }, (_, i) => j.colors["color" + i])) } catch (e) { sr.pal = [] } }
            onLoadFailed: sr.pal = []
        }

        ColumnLayout {
            id: srCol
            x: 14; y: 12; width: parent.width - 28
            spacing: 10
            SetRow {
                title: sr.title; desc: sr.desc
                SetSwitch { on: sr.on; onToggled: page.pick(sr.on ? (sr.key === "wallust" ? "matugen" : "wallust") : sr.key) }
            }
            SetInput {
                Layout.fillWidth: true
                text: sr.path
                placeholder: sr.defaultPath
                onCommitted: (t) => Config.set(sr.pathKey, t === "" || t === sr.defaultPath ? null : t)
            }
            Row {
                spacing: 4
                Repeater {
                    model: sr.pal
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: 20; height: 20; radius: 6
                        color: modelData || "transparent"
                        border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.15)
                    }
                }
                Text { visible: sr.pal.length === 0; text: "fichier introuvable ou illisible"
                       font.family: Appearance.font.family; font.pixelSize: Appearance.font.small - 2; color: Appearance.colors.color12 }
            }
        }
    }
}
