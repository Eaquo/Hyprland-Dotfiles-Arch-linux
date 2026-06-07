import QtQuick
import Quickshell.Io

// Lit `sensors` toutes les 2s : temp CPU (AMD k10temp Tctl/Tdie, ou Intel Package)
// + vitesses ventilo. Temp GPU AMD (amdgpu) lue via sysfs hwmon.
//
// Exposes:
//   real   cpuTemp / gpuTemp     °C, 0 si non lu
//   int    fan1Rpm / fan2Rpm / fanCount
//   string cpuTempStr / gpuTempStr / fan1Str / fan2Str

QtObject {
    id: root

    property bool   active:     true
    property real   cpuTemp:    0
    property real   gpuTemp:    0
    property int    fan1Rpm:    0
    property int    fan2Rpm:    0
    property int    fanCount:   0
    property string cpuTempStr: "—"
    property string gpuTempStr: "—"
    property string fan1Str:    "—"
    property string fan2Str:    "—"

    // ── sensors (CPU + ventilos) ────────────────────────────────────────────
    property var _proc: Process {
        command: ["sh", "-c", "sensors 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
    }

    // ── Temp GPU AMD via sysfs hwmon amdgpu ─────────────────────────────────
    property var _gpuProc: Process {
        command: ["sh", "-c",
            "for h in /sys/class/drm/card*/device/hwmon/hwmon*; do " +
            "  [ \"$(cat $h/name 2>/dev/null)\" = amdgpu ] && cat $h/temp1_input 2>/dev/null && break; " +
            "done"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var t = parseFloat(text.trim())
                if (!isNaN(t) && t > 0) {
                    root.gpuTemp    = t / 1000.0
                    root.gpuTempStr = (t / 1000.0).toFixed(0) + "°C"
                }
            }
        }
    }

    property var _timer: Timer {
        interval: 2000
        running:  root.active
        repeat:   true
        onTriggered: root._run()
    }

    function _run() {
        _proc.running    = false; _proc.running    = true
        _gpuProc.running = false; _gpuProc.running = true
    }

    function _parse(text) {
        var lines = text.split("\n")
        var cpu   = -1
        var fans  = []

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]

            // CPU temp — AMD: "Tctl: +53.9°C" / "Tdie: …" ; Intel: "Package id 0: +52.0°C"
            if (cpu < 0 && /^(Tctl|Tdie|Package id 0)\s*:/i.test(line)) {
                var m = line.match(/\+([0-9.]+)\s*°?C/)
                if (m) cpu = parseFloat(m[1])
                continue
            }

            // Ventilos — "fan1: 2400 RPM"
            var fm = line.match(/fan\d\s*:\s+([0-9]+)\s+RPM/i)
            if (fm) { fans.push(parseInt(fm[1])); continue }
        }

        if (cpu >= 0) {
            root.cpuTemp    = cpu
            root.cpuTempStr = cpu.toFixed(0) + "°C"
        }

        root.fanCount = fans.length
        root.fan1Rpm  = fans.length > 0 ? fans[0] : 0
        root.fan2Rpm  = fans.length > 1 ? fans[1] : 0
        root.fan1Str  = fans.length > 0 ? fans[0] + " RPM" : "—"
        root.fan2Str  = fans.length > 1 ? fans[1] + " RPM" : "—"
    }

    Component.onCompleted: _run()
}
