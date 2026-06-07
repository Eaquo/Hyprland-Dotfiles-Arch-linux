import QtQuick
import Quickshell.Io

// AMD GPU (amdgpu) via sysfs.
//
// Exposes (noms igpu/dgpu conservés pour compat DashStats) :
//   igpu.freqPercent  — utilisation GPU 0–100 (gpu_busy_percent)
//   igpu.curMhz       — VRAM "x.x / y.y GB"
//   dgpu.active       — true si un GPU AMD est détecté (gère l'affichage temp)

QtObject {
    id: root

    property bool   active:   true
    property string envyMode: "integrated"   // conservé (DashStats le passe), non utilisé

    property QtObject igpu: QtObject {
        property real   freqPercent: 0.0       // = utilisation GPU %
        property string curMhz:      "— GB"    // = VRAM utilisée / totale
        property string maxMhz:      "— MHz"
    }

    property QtObject dgpu: QtObject {
        property bool   active:       false
        property real   usagePercent: 0.0
        property string usedVram:     "— MB"
        property string totalVram:    "— MB"
    }

    // ── Utilisation GPU ───────────────────────────────────────────────────────
    property var _busyProc: Process {
        command: ["sh", "-c", "cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var v = parseInt(text.trim())
                if (!isNaN(v)) {
                    root.igpu.freqPercent  = v
                    root.dgpu.active       = true
                    root.dgpu.usagePercent = v
                }
            }
        }
    }

    // ── VRAM utilisée / totale ─────────────────────────────────────────────────
    property var _vramProc: Process {
        command: ["sh", "-c",
            "u=$(cat /sys/class/drm/card*/device/mem_info_vram_used 2>/dev/null | head -1); " +
            "t=$(cat /sys/class/drm/card*/device/mem_info_vram_total 2>/dev/null | head -1); " +
            "echo \"$u $t\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split(/\s+/)
                if (p.length < 2) return
                var u = parseFloat(p[0]), t = parseFloat(p[1])
                if (isNaN(u) || isNaN(t) || t <= 0) return
                var gb = 1073741824
                root.igpu.curMhz    = (u / gb).toFixed(1) + " / " + (t / gb).toFixed(1) + " GB"
                root.dgpu.usedVram  = (u / 1048576).toFixed(0) + " MB"
                root.dgpu.totalVram = (t / 1048576).toFixed(0) + " MB"
            }
        }
    }

    // ── Poll ────────────────────────────────────────────────────────────────
    property var _timer: Timer {
        interval: 1000
        running:  root.active
        repeat:   true
        onTriggered: {
            _busyProc.running = false; _busyProc.running = true
            _vramProc.running = false; _vramProc.running = true
        }
    }

    Component.onCompleted: {
        _busyProc.running = true
        _vramProc.running = true
    }
}
