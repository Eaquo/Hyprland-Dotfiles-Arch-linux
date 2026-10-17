import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.services

// CapturePage — Réglages › Multimédia › Capture d'écran ([capture] dans config.toml ;
// cible et audio dans user_data/screenrec.json, comme la tuile Screen Capture).
ColumnLayout {
    id: page
    spacing: 18

    PageHeader { title: "Capture d'écran"; sub: "[capture] dans config.toml — enregistrement par wf-recorder" }

    SetCard {
        title: "Fichiers"
        SetRow {
            title: "Dossier"; wide: true
            RowLayout {
                width: parent ? parent.width : 500
                spacing: 8
                SetInput { Layout.fillWidth: true; text: String(Config.get("capture.dir", "~/Videos/screen_recordings")); placeholder: "~/Videos/screen_recordings"
                           onCommitted: (t) => Config.set("capture.dir", t.trim() === "" || t.trim() === "~/Videos/screen_recordings" ? null : t.trim()) }
                SetButton { label: "󰉋  Ouvrir"; onTap: Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && xdg-open \"$1\"", "_", Config.dir("capture.dir", "~/Videos/screen_recordings")]) }
            }
        }
        SetRow {
            title: "Format"
            SetSeg { options: [["mp4", "MP4"], ["mkv", "MKV"], ["webm", "WebM"]]; current: String(Config.get("capture.format", "mp4"))
                     onPicked: (v) => { Config.set("capture.format", v === "mp4" ? null : v); if (v === "webm") Config.set("capture.codec", "libvpx-vp9") } }
        }
        SetRow {
            title: "Encodeur"; desc: "libx264rgb = qualité max (CPU) · h264_vaapi = GPU AMD/Intel, léger"
            SetSeg { options: [["libx264rgb", "x264 RGB"], ["libx264", "x264"], ["h264_vaapi", "VAAPI"], ["libvpx-vp9", "VP9"]]
                     current: String(Config.get("capture.codec", "libx264rgb"))
                     onPicked: (v) => Config.set("capture.codec", v === "libx264rgb" ? null : v) }
        }
        SetRow {
            title: "Images par seconde"; desc: "0 = celles de l'écran"
            SetSlider { implicitWidth: 300; from: 0; to: 144; step: 6; value: Number(Config.get("capture.fps", 0))
                        onMoved: (v) => Config.set("capture.fps", v === 0 ? null : v) }
        }
    }

    SetCard {
        title: "Par défaut"
        SetRow {
            title: "Cible"
            SetSeg { options: [["screen", "Écran"], ["window", "Fenêtre"], ["region", "Zone"]]; current: ScreenRecService.captureTarget
                     onPicked: (v) => { ScreenRecService.captureTarget = v; ScreenRecService.saveConfig() } }
        }
        SetRow { title: "Son du système"; SetSwitch { on: ScreenRecService.audioSystem; onToggled: { ScreenRecService.audioSystem = !on; ScreenRecService.saveConfig() } } }
        SetRow { title: "Micro"; SetSwitch { on: ScreenRecService.audioMic; onToggled: { ScreenRecService.audioMic = !on; ScreenRecService.saveConfig() } } }
    }
}
