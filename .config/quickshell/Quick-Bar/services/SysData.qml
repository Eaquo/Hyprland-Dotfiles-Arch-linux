pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// SysData — stats système partagées : un seul démon (scripts/system/sysstats.py) pour la
// barre (bar/SysStats.qml) et les pages System du dashboard et du tactile.
//   une ligne JSON toutes les [refresh] stats s ; mode « détail » (processus, place
//   récupérable, profil d'énergie, [refresh] stats_hover s) tant qu'un demandeur le veut :
//   SysData.want("id", true/false).
Singleton {
    id: root

    // ── Données ───────────────────────────────────────────────────────────
    property var d: null                        // dernière ligne du démon
    property var hist: ({ cpu: [], ram: [], tcpu: [], tgpu: [], tnvme: [], rd: [], wr: [], rx: [], tx: [] })
    property int histRev: 0                     // incrémenté à chaque échantillon → courbes redessinées
    property string profileSet: ""              // profil choisi, avant que le démon le relise

    readonly property var prefs: ShellState.statsPrefs
    function setPref(k, v) { const p = Object.assign({}, ShellState.statsPrefs); p[k] = v; ShellState.statsPrefs = p }

    readonly property int    cpu:      d ? d.cpu : 0
    readonly property real   memTotal: d ? d.mem.total : 1
    readonly property real   memUsed:  d ? d.mem.used : 0
    readonly property int    memPct:   Math.round(memUsed / memTotal * 100)
    readonly property var    rootDisk: d ? (d.disks.find(x => x.mount === "/") || d.disks[0] || null) : null
    readonly property int    diskPct:  rootDisk ? rootDisk.pct : 0
    readonly property real   cpuT:  d ? (d.temps.cpu.tctl || 0) : 0
    readonly property real   gpuT:  d ? (d.temps.gpu.junction || 0) : 0
    readonly property real   nvmeT: d && d.temps.nvme.length ? Math.max(...d.temps.nvme.map(n => n.temp)) : 0   // le plus chaud
    readonly property int    cpuAlert:  prefs.tempAlert ?? 82
    readonly property int    gpuAlert:  prefs.gpuAlert ?? 95
    readonly property int    nvmeAlert: prefs.nvmeAlert ?? 70
    readonly property string profile: profileSet !== "" ? profileSet : (d && d.profile ? d.profile : "")
    readonly property var    net: d && d.net ? d.net : ({ iface: "", rx: 0, tx: 0 })

    function push(a, v) { a.push(v); if (a.length > 60) a.shift() }
    function ingest(line) {
        let j
        try { j = JSON.parse(line) } catch (e) { return }
        push(hist.cpu, j.cpu); push(hist.ram, j.mem.used); push(hist.rd, j.io.rd); push(hist.wr, j.io.wr)
        if (j.net) { push(hist.rx, j.net.rx); push(hist.tx, j.net.tx) }
        d = j
        push(hist.tcpu, cpuT); push(hist.tgpu, gpuT); push(hist.tnvme, nvmeT)
        if (profileSet !== "" && j.profile === profileSet) profileSet = ""
        histRev++
    }

    // ── Mode détail : actif tant qu'au moins un demandeur le veut ─────────
    property var _wants: ({})
    function want(id, on) {
        const w = Object.assign({}, _wants)
        if (on) w[id] = true; else delete w[id]
        _wants = w
    }
    readonly property bool detail: Object.keys(_wants).length > 0
    onDetailChanged: if (daemon.running) daemon.write(detail ? "detail on\n" : "detail off\n")

    property var _daemon: Process {
        id: daemon
        running: true
        stdinEnabled: true
        command: ["python3", Quickshell.shellDir + "/scripts/system/sysstats.py", String(Config.ms("stats", 2) / 1000), String(Config.ms("stats_hover", 1) / 1000)]
        // nouvel intervalle → relance du démon (respawn le redémarre)
        onCommandChanged: if (running) running = false
        onRunningChanged: if (running && root.detail) write("detail on\n")
        stdout: SplitParser { onRead: line => root.ingest(line) }
        onExited: respawn.start()
    }
    property var _respawn: Timer { id: respawn; interval: 3000; onTriggered: daemon.running = true }

    // ── Formats ───────────────────────────────────────────────────────────
    function gb(b) { return (b / 1073741824).toFixed(1).replace(".", ",") + " Go" }
    function size(b) {
        if (b >= 1099511627776) return (b / 1099511627776).toFixed(1).replace(".", ",") + " To"
        if (b >= 1073741824)    return gb(b)
        return Math.round(b / 1048576) + " Mo"
    }
    function mbs(b) { return (b / 1048576).toFixed(b < 10485760 ? 1 : 0).replace(".", ",") + " Mo/s" }
    function rate(b) { return b >= 1048576 ? mbs(b) : Math.round(b / 1024) + " Ko/s" }
    function mountName(m) { return m === "/" ? "Système" : m.split("/").pop() }
    function lvl(v, warn, crit, base) { return v > crit ? Appearance.colors.color4 : v > warn ? Appearance.colors.color12 : base }

    readonly property color cpuCol:   lvl(cpu, 50, 85, Appearance.colors.color13)
    readonly property color ramCol:   lvl(memPct, 60, 85, Appearance.colors.color6)
    readonly property color tcpuCol:  lvl(cpuT,  cpuAlert - 12,  cpuAlert,  Appearance.colors.color15)
    readonly property color tgpuCol:  lvl(gpuT,  gpuAlert - 12,  gpuAlert,  Appearance.colors.color15)
    readonly property color tnvmeCol: lvl(nvmeT, nvmeAlert - 10, nvmeAlert, Appearance.colors.color15)
    readonly property color diskCol:  lvl(diskPct, 75, 90, Appearance.colors.color14)

    // ── Actions ───────────────────────────────────────────────────────────
    function run(cmd) { Quickshell.execDetached(cmd) }
    function notify(t, b) { run(["notify-send", "-a", "Quick-Bar", t, b || ""]) }
    // Outil détaillé de chaque stat (clic sur une puce ou une carte)
    function open(kind) {
        if (kind === "tcpu") run(Config.term("Capteurs", ["watch", "-n", "2", "sensors"]))
        else if (kind === "tgpu") run(Config.term("GPU", ["amdgpu_top"]))
        else if (kind === "tnvme") run(Config.term("NVMe", ["watch", "-n", "2", "sensors 'nvme-*'"]))
        else if (kind === "disk") run(Config.term("Disque", ["ncdu", "--color", "dark", "/"]))
        else if (kind === "net") run(Config.term("Réseau", ["sh", "-c", "command -v nload >/dev/null && exec nload || exec btop"]))
        else run(Config.term("System", ["btop"]))
    }
}
