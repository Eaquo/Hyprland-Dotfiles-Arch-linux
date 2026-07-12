import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../Common/"

// Wallpaper — fond Quickshell (layer background) affichant l'image fixe courante.
// Source du futur shader glitch. Un par écran (Variants).
//
// Wallpaper courant = cible du symlink ~/.config/rofi/.current_wallpaper.
// Réactivité : chaque changement de wallpaper régénère wallust (wal.json) → on
// relit le symlink → l'Image recharge (le chemin réel change).
Scope {
    id: root

    readonly property string _symlink: Quickshell.env("HOME") + "/.config/rofi/.current_wallpaper"
    property string wallPath: ""

    Process {
        id: readlinkProc
        command: ["readlink", "-f", root._symlink]
        stdout: SplitParser {
            onRead: function(line) {
                var p = line.trim()
                if (p !== "") { root.wallPath = p; WallpaperState.currentWall = p }
            }
        }
    }
    Component.onCompleted: readlinkProc.running = true

    // Signal universel de changement de wallpaper : wal.json régénéré par wallust
    FileView {
        path: "file://" + Quickshell.env("HOME") + "/.cache/wal/wal.json"
        watchChanges: true
        onFileChanged: { readlinkProc.running = false; readlinkProc.running = true }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            WlrLayershell.layer:     WlrLayer.Background
            WlrLayershell.namespace: "quickshell:wallpaper"
            exclusiveZone: -1
            // Mode vidéo (gslapper) : fenêtre transparente → la vidéo dessous s'affiche
            color: WallpaperState.videoMode ? "transparent" : "black"

            anchors { top: true; left: true; right: true; bottom: true }

            // Image source (cachée) — fournit la texture au shader
            Image {
                id: wallImage
                anchors.fill:  parent
                visible:       false
                // En mode vidéo (gslapper), le shader est masqué → inutile de garder
                // la texture pleine résolution en mémoire (×chaque moniteur).
                source:        (!WallpaperState.videoMode && root.wallPath !== "")
                                   ? ("file://" + root.wallPath) : ""
                fillMode:      Image.PreserveAspectCrop
                smooth:        true
                asynchronous:  true
                cache:         false
            }

            // Wallpaper rendu via le shader glitch (passe-plat quand intensity == 0)
            ShaderEffect {
                id: glitch
                anchors.fill: parent
                visible: !WallpaperState.videoMode   // masqué quand une vidéo tourne

                property variant source:    wallImage
                property real     intensity: 0.0
                property real     time:      0.0
                property vector2d resolution: Qt.vector2d(width, height)
                // Couleur des arcs/liserés = accent wallust (réactif)
                property vector4d accent: Qt.vector4d(Appearance.colors.accent.r,
                                                      Appearance.colors.accent.g,
                                                      Appearance.colors.accent.b, 1.0)

                // Thème d'animation sélectionnable (cyberpunk, …) = un .frag par thème
                fragmentShader: Qt.resolvedUrl("shaders/" + WallpaperState.glitchTheme + ".frag.qsb")
            }

            // `time` avance seulement pendant un burst (coût nul au repos)
            FrameAnimation {
                running: glitch.intensity > 0.001
                onTriggered: glitch.time += frameTime * WallpaperState.glitchSpeed
            }

            // Burst : intensité 0 → pic configuré → 0 sur la durée configurée
            SequentialAnimation {
                id: burst
                NumberAnimation { target: glitch; property: "intensity"; to: WallpaperState.glitchIntensity; duration: Math.round(WallpaperState.glitchDuration * 0.2); easing.type: Easing.OutQuad }
                NumberAnimation { target: glitch; property: "intensity"; to: 0.0;                            duration: Math.round(WallpaperState.glitchDuration * 0.8); easing.type: Easing.InQuad }
            }

            // Déclenche le glitch à l'intervalle configuré ± 30 %
            Timer {
                id: glitchTimer
                running:  WallpaperState.glitchEnabled && !WallpaperState.videoMode
                repeat:   true
                interval: WallpaperState.glitchInterval
                onTriggered: {
                    burst.restart()
                    interval = Math.round(WallpaperState.glitchInterval * (0.7 + Math.random() * 0.6))
                }
            }
        }
    }
}
