import QtQuick
import QtQuick.Layouts
import qs.core
import qs.core.functions

// WallPage — Réglages › Multimédia › Fond d'écran : dossiers ([wallpaper]) et effets
// (WallpaperState, sauvé dans user_data/wallpaper_fx.json — mêmes réglages que l'onglet Wall).
ColumnLayout {
    id: page
    spacing: 18

    PageHeader { title: "Fond d'écran"; sub: "[wallpaper] dans config.toml · effets dans user_data/wallpaper_fx.json" }

    SetCard {
        title: "Dossiers"
        SetRow {
            title: "Images"; wide: true
            SetInput { width: parent ? parent.width : 300; text: String(Config.get("wallpaper.dir", "~/Pictures/wallpapers")); placeholder: "~/Pictures/wallpapers"
                       onCommitted: (t) => Config.set("wallpaper.dir", t.trim() === "" ? null : t.trim()) }
        }
        SetRow {
            title: "Vidéos"; wide: true
            SetInput { width: parent ? parent.width : 300; text: String(Config.get("wallpaper.videos", "")); placeholder: "par défaut : <dossier images>/Video"
                       onCommitted: (t) => Config.set("wallpaper.videos", t.trim() === "" ? null : t.trim()) }
        }
    }

    SetCard {
        title: "Rotation"
        SetRow {
            title: "Changer automatiquement"; desc: "un fond au hasard du dossier"
            SetSwitch { on: WallpaperState.autoChange; onToggled: WallpaperState.autoChange = !WallpaperState.autoChange }
        }
        SetRow {
            title: "Intervalle"
            SetSlider { implicitWidth: 300; from: 1; to: 120; suffix: " min"; value: WallpaperState.autoMinutes; onMoved: (v) => WallpaperState.autoMinutes = v }
        }
    }

    SetCard {
        title: "Effet animé"
        SetRow {
            title: "Effet sur le fond"
            SetSwitch { on: WallpaperState.glitchEnabled; onToggled: WallpaperState.glitchEnabled = !WallpaperState.glitchEnabled }
        }
        SetRow {
            title: "Thème"; wide: true
            Flow {
                width: parent ? parent.width : 600
                spacing: 6
                Repeater {
                    model: WallpaperState.themes
                    delegate: SetButton {
                        required property string modelData
                        label: modelData; active: WallpaperState.glitchTheme === modelData
                        onTap: WallpaperState.glitchTheme = modelData
                    }
                }
            }
        }
        SetRow { title: "Mode"; SetSeg { options: [[false, "Par salves"], [true, "En continu"]]; current: WallpaperState.glitchContinuous
                 onPicked: (v) => WallpaperState.glitchContinuous = v } }
        SetRow { title: "Intensité"; SetSlider { implicitWidth: 300; from: 0.1; to: 1; step: 0.05; decimals: 2; value: WallpaperState.glitchIntensity
                 onMoved: (v) => WallpaperState.glitchIntensity = v } }
        SetRow { title: "Vitesse"; SetSlider { implicitWidth: 300; from: 0.25; to: 3; step: 0.05; decimals: 2; suffix: " ×"; value: WallpaperState.glitchSpeed
                 onMoved: (v) => WallpaperState.glitchSpeed = v } }
        SetRow { title: "Écart entre salves"; desc: "en mode salves"
                 SetSlider { implicitWidth: 300; from: 1; to: 30; step: 0.5; decimals: 1; suffix: " s"; value: WallpaperState.glitchInterval / 1000
                 onMoved: (v) => WallpaperState.glitchInterval = Math.round(v * 1000) } }
        SetRow { title: "Durée d'une salve"; SetSlider { implicitWidth: 300; from: 100; to: 2000; step: 20; suffix: " ms"; value: WallpaperState.glitchDuration
                 onMoved: (v) => WallpaperState.glitchDuration = v } }
        SetRow {
            title: "Couleur de l'effet"; desc: "vide = accent " + Appearance.paletteName
            RowLayout {
                spacing: 8
                Rectangle { width: 26; height: 26; radius: 8; color: WallpaperState.fxColor; border.width: 1; border.color: ColorUtils.applyAlpha(Appearance.colors.fg, 0.2) }
                SetInput { implicitWidth: 140; text: WallpaperState.glitchColor; placeholder: "#rrggbb"
                           onCommitted: (t) => { const v = t.trim(); if (v === "" || /^#[0-9a-fA-F]{6}$/.test(v)) WallpaperState.glitchColor = v } }
            }
        }
        SetRow {
            title: "Effet au changement d'espace"; desc: "shader plein écran quand on change de workspace"
            SetSwitch { on: WallpaperState.wsFxEnabled; onToggled: WallpaperState.wsFxEnabled = !WallpaperState.wsFxEnabled }
        }
    }
}
