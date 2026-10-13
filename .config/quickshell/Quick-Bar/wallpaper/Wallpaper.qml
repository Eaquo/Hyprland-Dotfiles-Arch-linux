import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.core

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
                // Niveaux de détail de la texture : requis par les shaders qui floutent
                // via textureLod (rain = pluie sur vitre embuée).
                mipmap:        true
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
                // Couleur de l'effet = accent wallust, ou la couleur choisie dans l'onglet Wall
                property vector4d accent: Qt.vector4d(WallpaperState.fxColor.r,
                                                      WallpaperState.fxColor.g,
                                                      WallpaperState.fxColor.b, 1.0)

                // Thème d'animation = un .frag par thème (WallpaperState.themes)
                fragmentShader: Qt.resolvedUrl("shaders/" + WallpaperState.glitchTheme + ".frag.qsb")
            }

            // `time` avance seulement pendant un burst (coût nul au repos)
            FrameAnimation {
                running: glitch.intensity > 0.001
                onTriggered: glitch.time += frameTime * WallpaperState.glitchSpeed
            }

            // Mode continu : l'effet reste à l'intensité configurée (pas de bursts).
            // En jeu, tous les effets sont suspendus : le GPU va au jeu (le shader
            // repasse en simple passe-plat dès que l'intensité retombe à 0).
            readonly property bool fxAllowed: WallpaperState.glitchEnabled && !WallpaperState.videoMode
                                              && !GameMode.active
            readonly property bool continuous: fxAllowed && WallpaperState.glitchContinuous
            readonly property real holdLevel: continuous ? WallpaperState.glitchIntensity : 0
            onHoldLevelChanged: { burst.stop(); holdAnim.to = holdLevel; holdAnim.restart() }
            Component.onCompleted: if (continuous) glitch.intensity = holdLevel
            NumberAnimation { id: holdAnim; target: glitch; property: "intensity"; duration: 600; easing.type: Easing.InOutQuad }

            // Burst : intensité 0 → pic configuré → 0 sur la durée configurée
            SequentialAnimation {
                id: burst
                // Montée 15 % · palier 55 % · descente 30 % : sur un burst long, l'effet
                // reste à pleine intensité au lieu de s'effacer dès le départ.
                NumberAnimation { target: glitch; property: "intensity"; to: WallpaperState.glitchIntensity; duration: Math.round(WallpaperState.glitchDuration * 0.15); easing.type: Easing.OutQuad }
                PauseAnimation  { duration: Math.round(WallpaperState.glitchDuration * 0.55) }
                NumberAnimation { target: glitch; property: "intensity"; to: 0.0;                            duration: Math.round(WallpaperState.glitchDuration * 0.30); easing.type: Easing.InQuad }
            }

            // Déclenche le glitch ; l'intervalle configuré (± 30 %) est le REPOS entre
            // deux bursts : on y ajoute la durée du burst, sinon un effet long se
            // recouperait lui-même.
            Timer {
                id: glitchTimer
                running:  win.fxAllowed && !win.continuous
                repeat:   true
                interval: WallpaperState.glitchInterval
                onTriggered: {
                    burst.restart()
                    interval = WallpaperState.glitchDuration
                             + Math.round(WallpaperState.glitchInterval * (0.7 + Math.random() * 0.6))
                }
            }
        }
    }
}
