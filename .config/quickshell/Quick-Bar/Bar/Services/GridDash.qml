import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../Common/"
import "../Common/functions/"
import "../Services/"
import "home"

// GridDash — page « Grid » : tableau de widgets déplaçables/redimensionnables
// façon écran d'accueil (Nothing). Mode édition (crayon) → glisser, redimensionner
// (poignée bas-droite), supprimer (×) ; palette en bas pour ajouter des widgets.
// Layout persisté dans user_data/grid_layout.json.
Item {
    id: root

    // ── Grille snap ──────────────────────────────────────────────────────────
    readonly property int  cols: 12
    readonly property int  rows: 6
    readonly property int  gap:  10
    readonly property real cellW: (gridArea.width  - gap * (cols + 1)) / cols
    readonly property real cellH: (gridArea.height - gap * (rows + 1)) / rows
    function px(gx) { return gap + gx * (cellW + gap) }
    function py(gy) { return gap + gy * (cellH + gap) }
    function wpx(w) { return cellW * w + gap * (w - 1) }
    function hpx(h) { return cellH * h + gap * (h - 1) }

    property bool editMode: false
    property var  widgets: []          // [{ id, type, x, y, w, h, page }]
    property int  pageCount: 1         // nombre de pages de la grille (« workspaces »)
    property int  curPage:   0         // page affichée
    // Widgets de la page courante uniquement (le Repeater n'affiche que ceux-là).
    readonly property var pageWidgets: root.widgets.filter(function (w) { return (w.page || 0) === root.curPage })

    // ── Services ─────────────────────────────────────────────────────────────
    CpuService     { id: cpu;     active: root.visible }
    MemService     { id: mem;     active: root.visible }
    GpuService     { id: gpu;     active: root.visible }
    NetService     { id: net;     active: root.visible }
    ThermalService { id: thermal; active: root.visible }
    DiskService    { id: disk;    active: root.visible }

    // RGB — mode courant lu depuis conf/sequence.txt
    property string rgbMode: ""
    property var _rgbSeq: FileView {
        path: "file://" + Quickshell.env("HOME")
              + "/.config/quickshell/Quick-Bar/Bar/Scripts/rgb/script/conf/sequence.txt"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.rgbMode = text().trim()
    }
    // Modes RGB (via backend.py) → nom/icône/description conviviaux (comme RgbTab)
    property var rgbModes: []
    readonly property var rgbCur: {
        for (var i = 0; i < rgbModes.length; i++) {
            var p = String(rgbModes[i].command || "").trim().split(/\s+/)
            if (p[p.length - 1] === root.rgbMode) return rgbModes[i]
        }
        return null
    }
    function _rgbWc(name) {
        if (!name) return Appearance.colors.accent
        if (name === "foreground") return Appearance.colors.fg
        return Appearance.colors["color" + (name.indexOf("color") === 0 ? name.substring(5) : "11")]
    }
    property var _rgbBackend: Process {
        id: rgbBackendProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/Quick-Bar/Bar/Scripts/rgb/backend.py"]
        stdout: StdioCollector { onStreamFinished: {
            try { var d = JSON.parse(text); root.rgbModes = (d && d.modes) ? d.modes : [] }
            catch (e) { root.rgbModes = [] }
        } }
    }

    // Lanceurs d'app — réutilise user_data/streamdeck.json + launch-main.sh
    property var launcherSections: []
    readonly property var launcherApps: {
        var out = []
        for (var i = 0; i < launcherSections.length; i++) {
            var it = launcherSections[i].items || []
            for (var j = 0; j < it.length; j++) out.push(it[j])
        }
        return out
    }
    readonly property string _launcher:
        Quickshell.env("HOME") + "/.config/quickshell/Quick-Bar/Bar/Scripts/launch-main.sh"
    function launchApp(cmd) {
        if (!cmd) return
        launchProc.command = ["bash", root._launcher, cmd]
        launchProc.running = false; launchProc.running = true
    }
    property var _launchProc: Process { id: launchProc }
    function runPower(cmd) {
        powerProc.command = ["bash", "-c", cmd]
        powerProc.running = false; powerProc.running = true
    }
    property var _powerProc: Process { id: powerProc }
    property var _deckFile: FileView {
        path: "file://" + Quickshell.env("HOME") + "/.config/quickshell/Quick-Bar/user_data/streamdeck.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { var d = JSON.parse(text()); root.launcherSections = Array.isArray(d) ? d : [] }
            catch (e) { root.launcherSections = [] }
        }
    }

    // Volume (Pipewire) — garde le sink lié pour que volume/muted se mettent à jour
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    // Uptime
    property string uptimeStr: ""
    property var _uptimeProc: Process {
        id: uptimeProc
        command: ["sh", "-c", "uptime -p | sed 's/^up //'"]
        stdout: StdioCollector { onStreamFinished: root.uptimeStr = text.trim() }
    }
    property var _uptimeTimer: Timer {
        interval: 60000; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: { uptimeProc.running = false; uptimeProc.running = true }
    }

    // Load average (/proc/loadavg)
    property real   loadAvg1: 0
    property string loadStr:  ""
    property var _loadProc: Process {
        id: loadProc
        command: ["cat", "/proc/loadavg"]
        stdout: StdioCollector { onStreamFinished: {
            var p = text.trim().split(/\s+/)
            root.loadAvg1 = parseFloat(p[0]) || 0
            root.loadStr  = (p[1] || "—") + " / " + (p[2] || "—")
        } }
    }
    property var _loadTimer: Timer {
        interval: 3000; running: root.visible; repeat: true; triggeredOnStart: true
        onTriggered: { loadProc.running = false; loadProc.running = true }
    }

    // ── Catalogue (palette) ──────────────────────────────────────────────────
    readonly property var catalog: [
        { type: "cpu",   cat: "Système", label: "CPU",     icon: "󰻠", w: 3, h: 2, col: Appearance.colors.color4  },
        { type: "ram",   cat: "Système", label: "RAM",     icon: "󰍛", w: 3, h: 2, col: Appearance.colors.color5  },
        { type: "gpu",   cat: "Système", label: "GPU",     icon: "󰢮", w: 3, h: 2, col: Appearance.colors.color6  },
        { type: "vram",  cat: "Système", label: "VRAM",    icon: "󰍹", w: 3, h: 2, col: Appearance.colors.color9  },
        { type: "net",   cat: "Système", label: "Réseau",  icon: "󰤨", w: 4, h: 2, col: Appearance.colors.color2  },
        { type: "disk",  cat: "Système", label: "Disque",  icon: "󰋊", w: 4, h: 2, col: Appearance.colors.color3  },
        { type: "disks", cat: "Système", label: "Disques", icon: "󰋊", w: 4, h: 4, col: Appearance.colors.color3  },
        { type: "fan",   cat: "Système", label: "Ventilo", icon: "󰈐", w: 3, h: 2, col: Appearance.colors.color12 },
        { type: "temp",  cat: "Système", label: "Temp CPU",    icon: "󰔏", w: 3, h: 2, col: "#fab387" },
        { type: "temp",  cat: "Système", label: "Temp GPU",    icon: "󰔏", w: 3, h: 2, col: "#fab387" },
        { type: "load",  cat: "Système", label: "Charge",  icon: "󰬢", w: 3, h: 2, col: Appearance.colors.color13 },
        { type: "uptime",cat: "Système", label: "Uptime",  icon: "󰔟", w: 3, h: 2, col: Appearance.colors.color6  },

        { type: "media",  cat: "Média", label: "Media",  icon: "󰎈", w: 5, h: 2, col: Appearance.colors.color13 },
        { type: "cava",   cat: "Média", label: "Cava",   icon: "󰝚", w: 5, h: 2, col: Appearance.colors.color11 },
        { type: "volume", cat: "Média", label: "Volume", icon: "󰕾", w: 3, h: 2, col: Appearance.colors.color14 },
        { type: "rgb",    cat: "Média", label: "RGB",    icon: "󰌵", w: 3, h: 2, col: Appearance.colors.color11 },

        { type: "clock",    cat: "Cartes", label: "Horloge",    icon: "󰅐", w: 4, h: 2, col: Appearance.colors.color4  },
        { type: "analog",   cat: "Cartes", label: "Analogique", icon: "󰀠", w: 3, h: 3, col: Appearance.colors.color4  },
        { type: "palette",  cat: "Cartes", label: "Palette",    icon: "󰸌", w: 4, h: 2, col: Appearance.colors.color11 },
        { type: "wall",     cat: "Cartes", label: "Wallpaper",  icon: "󰸉", w: 4, h: 3, col: Appearance.colors.color10 },
        { type: "calendar", cat: "Cartes", label: "Calendrier", icon: "󰃭", w: 4, h: 4, col: Appearance.colors.color10 },
        { type: "qs",       cat: "Cartes", label: "Réglages",   icon: "󰒓", w: 4, h: 4, col: Appearance.colors.color14 },
        { type: "profile",  cat: "Cartes", label: "Profil",     icon: "󰀄", w: 4, h: 2, col: Appearance.colors.color13 },
        { type: "apps",     cat: "Cartes", label: "Apps",       icon: "󰀻", w: 5, h: 3, col: Appearance.colors.color4  },

        { type: "pomodoro", cat: "Outils", label: "Pomodoro",      icon: "󰔟", w: 3, h: 3, col: "#f38ba8" },
        { type: "notif",    cat: "Outils", label: "Notifications", icon: "󰂚", w: 4, h: 3, col: Appearance.colors.color10 },
        { type: "note",     cat: "Outils", label: "Pense-bête",    icon: "󰎞", w: 4, h: 3, col: Appearance.colors.color5  },
        { type: "power",    cat: "Outils", label: "Power",         icon: "󰐥", w: 3, h: 3, col: "#f38ba8" }
    ]
    function catalogFor(t) {
        for (var i = 0; i < catalog.length; i++) if (catalog[i].type === t) return catalog[i]
        return { type: t, label: t, icon: "", w: 3, h: 2, col: Appearance.colors.accent }
    }
    function tempCol(t) {
        if (t <= 0)  return Appearance.colors.dim
        if (t < 50)  return "#89dceb"
        if (t < 70)  return "#a6e3a1"
        if (t < 82)  return "#f9e2af"
        if (t < 90)  return "#fab387"
        return "#f38ba8"
    }

    // ── Persistance ──────────────────────────────────────────────────────────
    readonly property string _path:
        Quickshell.env("HOME") + "/.config/quickshell/Quick-Bar/user_data/grid_layout.json"
    property bool _loading: false

    function _defaults() {
        return [
            { id: "w1", type: "clock", x: 0, y: 0, w: 4, h: 2, page: 0 },
            { id: "w2", type: "cpu",   x: 4, y: 0, w: 3, h: 2, page: 0 },
            { id: "w3", type: "ram",   x: 7, y: 0, w: 3, h: 2, page: 0 },
            { id: "w4", type: "net",   x: 0, y: 2, w: 4, h: 2, page: 0 }
        ]
    }
    function _parse(txt) {
        if (!txt || txt.length === 0) { root.widgets = _defaults(); return }
        try {
            var d = JSON.parse(txt)
            if (Array.isArray(d)) {                              // ancien format : simple liste
                root.widgets = d.length ? d : _defaults()
            } else {
                root.widgets = (d.widgets && d.widgets.length) ? d.widgets : _defaults()
                if (d.pageCount) root.pageCount = Math.max(1, d.pageCount)
            }
        } catch (e) { root.widgets = _defaults() }
    }
    function _save() {
        if (root._loading) return
        var json = JSON.stringify({ pageCount: root.pageCount, widgets: root.widgets })
        saveProc.command = ["bash", "-c", "printf '%s' \"$1\" > \"$2\"", "_", json, root._path]
        saveProc.running = false
        saveProc.running = true
    }
    property var _fv: FileView {
        path: "file://" + root._path
        onLoaded: { root._loading = true; root._parse(text()); root._loading = false }
    }
    property var _saveProc: Process { id: saveProc }
    Component.onCompleted: {
        if (root.widgets.length === 0) root.widgets = _defaults()
        rgbBackendProc.running = true
    }

    // ── Mutations par id (la page est filtrée → l'index n'est plus fiable) ────
    // Placement/resize LIBRES (aucun refus).
    function _idx(id) {
        for (var i = 0; i < root.widgets.length; i++) if (root.widgets[i].id === id) return i
        return -1
    }
    function _patch(id, obj) {
        var i = root._idx(id); if (i < 0) return
        var a = root.widgets.slice(); a[i] = Object.assign({}, a[i], obj)
        root.widgets = a; _save()
    }
    function moveWidget(id, nx, ny) { root._patch(id, { x: nx, y: ny }) }
    function resizeWidget(id, nw, nh) { root._patch(id, { w: nw, h: nh }) }
    function setWidgetProp(id, key, val) { var o = {}; o[key] = val; root._patch(id, o) }
    function removeWidget(id) {
        var i = root._idx(id); if (i < 0) return
        var a = root.widgets.slice(); a.splice(i, 1); root.widgets = a; _save()
    }
    // Occupation / case libre : uniquement sur la page courante.
    function _occupied(x, y, w, h, skipId) {
        for (var i = 0; i < root.widgets.length; i++) {
            var o = root.widgets[i]
            if (o.id === skipId || (o.page || 0) !== root.curPage) continue
            if (x < o.x + o.w && x + w > o.x && y < o.y + o.h && y + h > o.y) return true
        }
        return false
    }
    function _freeSlot(w, h) {
        for (var y = 0; y <= root.rows - h; y++)
            for (var x = 0; x <= root.cols - w; x++)
                if (!root._occupied(x, y, w, h, "")) return { x: x, y: y }
        return { x: 0, y: 0 }
    }
    // Pages
    function setPageCount(n) {
        root.pageCount = Math.max(1, Math.min(9, n))
        if (root.curPage >= root.pageCount) root.curPage = root.pageCount - 1
        _save()
    }
    function addWidget(t) {
        var c = catalogFor(t); var slot = root._freeSlot(c.w, c.h); var a = root.widgets.slice()
        a.push({ id: "w" + Date.now(), type: t, x: slot.x, y: slot.y, w: c.w, h: c.h, page: root.curPage })
        root.widgets = a; _save()
    }

    // ── Composants de contenu par type ───────────────────────────────────────
    // Map type→Component en BINDING (et non dans une fonction) : garantit que les
    // id des Component sont bien exposés (sinon ReferenceError sur ceux-ci).
    readonly property var compMap: ({
        "clock": cClock, "cpu": cCpu, "ram": cRam, "gpu": cGpu, "vram": cVram,
        "net": cNet, "disk": cDisk, "fan": cFan, "media": cMedia, "rgb": cRgb,
        "cava": cCava, "calendar": cCalendar, "qs": cQs, "profile": cProfile,
        "apps": cApps, "volume": cVolume, "uptime": cUptime,
        "load": cLoad, "temp": cTemp,
        "disks": cDisks, "pomodoro": cPomodoro, "notif": cNotif,
        "analog": cAnalog, "palette": cPalette, "wall": cWall, "note": cNote, "power": cPower
    })

    // Catégories de la palette (ordre d'apparition dans le catalogue)
    readonly property var palCats: {
        var seen = [], out = []
        for (var i = 0; i < catalog.length; i++) {
            var c = catalog[i].cat || "Autres"
            if (seen.indexOf(c) === -1) { seen.push(c); out.push(c) }
        }
        return out
    }
    property string palCat: "Système"

    // Widget métrique stylé : icône + label, gros chiffre + unité, waveform neon en
    // fond, min/max ▲▼ (ou `sub`), détail en haut-droite, couleur d'accent.
    component Metric: Item {
        id: mc
        property string icon: ""
        property string label: ""
        property color  col: Appearance.colors.accent
        property real   value: 0
        property string unit: ""
        property int    decimals: 0
        property string valueText: ""      // remplace le gros chiffre (RGB, débit…)
        property string rightText: ""      // détail haut-droite (temp, VRAM…)
        property string sub: ""            // ligne du bas (remplace min/max)
        property color  valueColor: Appearance.colors.fg
        property bool   spark: true        // waveform de fond
        property var    hist: []
        property int    maxPts: 40
        readonly property real vmin: hist.length ? Math.min.apply(Math, hist) : value
        readonly property real vmax: hist.length ? Math.max.apply(Math, hist) : value

        Timer {
            interval: 1000; running: mc.spark && mc.visible; repeat: true
            onTriggered: {
                var h = mc.hist.slice(); h.push(mc.value)
                if (h.length > mc.maxPts) h.shift()
                mc.hist = h; sparkC.requestPaint()
            }
        }
        Canvas {
            id: sparkC
            anchors.fill: parent
            visible: mc.spark
            onPaint: {
                var ctx = getContext("2d"); ctx.reset()
                var W = width, H = height, pts = mc.hist
                if (pts.length < 2) return
                var lo = mc.vmin, hi = mc.vmax; if (hi - lo < 1) hi = lo + 1
                var gy = H * 0.99, gh = H * 0.5
                ctx.beginPath()
                for (var i = 0; i < pts.length; i++) {
                    var xx = W * i / (mc.maxPts - 1)
                    var yy = gy - gh * ((pts[i] - lo) / (hi - lo))
                    if (i === 0) ctx.moveTo(xx, yy); else ctx.lineTo(xx, yy)
                }
                ctx.lineWidth = 2; ctx.lineCap = "round"; ctx.lineJoin = "round"
                ctx.strokeStyle = Qt.rgba(mc.col.r, mc.col.g, mc.col.b, 0.7); ctx.stroke()
                var lastX = W * (pts.length - 1) / (mc.maxPts - 1)
                ctx.lineTo(lastX, gy); ctx.lineTo(0, gy); ctx.closePath()
                var g = ctx.createLinearGradient(0, gy - gh, 0, gy)
                g.addColorStop(0, Qt.rgba(mc.col.r, mc.col.g, mc.col.b, 0.16))
                g.addColorStop(1, Qt.rgba(mc.col.r, mc.col.g, mc.col.b, 0.0))
                ctx.fillStyle = g; ctx.fill()
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }
        Row {
            anchors { top: parent.top; left: parent.left }
            spacing: 6
            Text { visible: mc.icon !== ""; text: mc.icon
                   font.family: Appearance.font.family; font.pixelSize: 14; color: mc.col }
            Text { text: mc.label
                   font.family: Appearance.font.family; font.pixelSize: 13; font.weight: Font.Bold; color: mc.col }
        }
        Text {
            visible: mc.rightText !== ""
            anchors { top: parent.top; right: parent.right }
            text: mc.rightText
            font.family: "JetBrains Mono"; font.pixelSize: 11; color: Appearance.colors.dim
        }
        Text {
            id: bigNum
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; verticalCenterOffset: 2 }
            text: mc.valueText !== "" ? mc.valueText : mc.value.toFixed(mc.decimals)
            font.family: Appearance.font.family; font.pixelSize: 36; font.weight: Font.Bold
            color: mc.valueColor
        }
        Text {
            visible: mc.unit !== ""
            anchors { left: bigNum.right; leftMargin: 3; baseline: bigNum.baseline }
            text: mc.unit
            font.family: Appearance.font.family; font.pixelSize: 14; font.weight: Font.Bold; color: mc.col
        }
        Text {
            anchors { left: parent.left; top: bigNum.bottom; topMargin: -2 }
            text: mc.sub !== "" ? mc.sub
                  : (mc.spark ? "▲ " + mc.vmax.toFixed(mc.decimals) + "  ▼ " + mc.vmin.toFixed(mc.decimals) : "")
            font.family: "JetBrains Mono"; font.pixelSize: 11; color: Appearance.colors.dim
        }
    }

    Component { id: cUnknown
        Item { Text { anchors.centerIn: parent; text: "?"; color: Appearance.colors.dim } }
    }
    Component { id: cClock
        Item {
            property var _now: new Date()
            Timer { interval: 1000; running: true; repeat: true; onTriggered: parent._now = new Date() }
            Column {
                anchors.centerIn: parent
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(parent.parent._now, "HH:mm")
                    font.family: Appearance.font.family; font.pixelSize: 46; font.weight: Font.Bold
                    color: Appearance.colors.fg
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(parent.parent._now, "dddd d MMMM")
                    font.family: Appearance.font.family; font.pixelSize: 13; color: Appearance.colors.dim
                }
            }
        }
    }
    Component { id: cCpu
        Metric { icon: "󰻠"; label: "CPU"; col: Appearance.colors.color4
            value: cpu.usagePercent; unit: "%"; rightText: Math.round(thermal.cpuTemp) + "°" }
    }
    Component { id: cRam
        Metric { icon: "󰍛"; label: "RAM"; col: Appearance.colors.color5
            value: mem.usagePercent; unit: "%"; rightText: mem.usedStr }
    }
    Component { id: cGpu
        Metric { icon: "󰢮"; label: "GPU"; col: Appearance.colors.color6
            value: gpu.igpu.freqPercent; unit: "%"; rightText: Math.round(thermal.gpuTemp) + "°" }
    }
    Component { id: cNet
        Metric { icon: "󰤨"; label: net.iface; col: Appearance.colors.color2
            value: net.downKbps; valueText: net.downSpeed; sub: "↑ " + net.upSpeed }
    }
    Component { id: cVram
        Metric { icon: "󰍹"; label: "VRAM"; col: Appearance.colors.color9
            value: gpu.igpu.vramPercent; unit: "%"; rightText: gpu.igpu.vramUsedStr }
    }
    Component { id: cDisk
        Item {
            id: dw
            property var d: disk.disks.length ? disk.disks[0] : null
            Metric {
                anchors.fill: parent
                icon: "󰋊"; label: dw.d ? "Disk " + dw.d.mount : "Disk"
                col: Appearance.colors.color3; spark: false
                value: dw.d ? dw.d.usedPct : 0; unit: "%"
                sub: dw.d ? (dw.d.usedStr + " / " + dw.d.totalStr) : ""
            }
        }
    }
    Component { id: cFan
        Metric { icon: "󰈐"; label: "Ventilo"; col: Appearance.colors.color12
            value: thermal.fan1Rpm; unit: "rpm" }
    }
    Component { id: cMedia
        PlayerCard {}   // réutilise la carte lecteur complète (pochette + contrôles)
    }
    Component { id: cRgb
        Item {
            readonly property var    m:    root.rgbCur
            readonly property string nm:   m && m.name ? m.name : (root.rgbMode !== "" ? root.rgbMode : "—")
            readonly property string ic:   m && m.icon ? m.icon : "󰌵"
            readonly property string desc: m && m.description ? m.description : "mode actif"
            readonly property color  acol: root._rgbWc(m ? m.icon_color : "")

            Text {
                anchors { top: parent.top; left: parent.left }
                text: "󰌵 RGB"
                font.family: Appearance.font.family; font.pixelSize: 13; font.weight: Font.Bold
                color: Appearance.colors.color11
            }
            Rectangle {
                anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 2 }
                width: 46; height: 46; radius: 23
                color: ColorUtils.applyAlpha(parent.acol, 0.16)
                border.color: ColorUtils.applyAlpha(parent.acol, 0.5); border.width: 1
                Text { anchors.centerIn: parent; text: parent.parent.ic
                       font.family: Appearance.font.family; font.pixelSize: 22; color: parent.parent.acol }
            }
            Column {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                spacing: 0
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: parent.parent.nm
                    font.family: Appearance.font.family; font.pixelSize: 22; font.weight: Font.Bold
                    color: parent.parent.acol
                }
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: parent.parent.desc
                    font.family: "JetBrains Mono"; font.pixelSize: 11; color: Appearance.colors.dim
                }
            }
        }
    }
    Component { id: cLoad
        Metric { icon: "󰬢"; label: "Charge"; col: Appearance.colors.color13
            value: root.loadAvg1; decimals: 2; sub: "5m/15m : " + root.loadStr }
    }
    Component { id: cTemp
        Metric { icon: "󰔏"; label: "Temp CPU"; col: root.tempCol(thermal.cpuTemp)
            value: thermal.cpuTemp; unit: "°"; valueColor: root.tempCol(thermal.cpuTemp)
            rightText: "GPU " + Math.round(thermal.gpuTemp) + "°" }
    }
    // Disques multiples — tous les points de montage en barres
    Component { id: cDisks
        Item {
            Text {
                anchors { top: parent.top; left: parent.left }
                text: "󰋊 Disques"
                font.family: Appearance.font.family; font.pixelSize: 13; font.weight: Font.Bold
                color: Appearance.colors.color3
            }
            Column {
                id: dkCol
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 24 }
                spacing: 8
                Repeater {
                    model: disk.disks
                    delegate: Item {
                        required property var modelData
                        width: dkCol.width; height: 24
                        Row {
                            width: parent.width; spacing: 8
                            Text {
                                width: 48; anchors.verticalCenter: parent.verticalCenter
                                text: modelData.mount; elide: Text.ElideRight
                                font.family: Appearance.font.family; font.pixelSize: 11; color: Appearance.colors.fg
                            }
                            Rectangle {
                                width: parent.width - 48 - 8 - 46; height: 7; radius: 4
                                anchors.verticalCenter: parent.verticalCenter
                                color: Qt.rgba(1, 1, 1, 0.1)
                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(1, (modelData.usedPct || 0) / 100))
                                    height: parent.height; radius: parent.radius
                                    color: (modelData.usedPct > 88) ? "#f38ba8" : Appearance.colors.color3
                                }
                            }
                            Text {
                                width: 46; horizontalAlignment: Text.AlignRight
                                anchors.verticalCenter: parent.verticalCenter
                                text: Math.round(modelData.usedPct || 0) + "%"
                                font.family: "JetBrains Mono"; font.pixelSize: 10; color: Appearance.colors.dim
                            }
                        }
                    }
                }
            }
        }
    }
    // Pomodoro / minuteur
    Component { id: cPomodoro
        Item {
            id: pom
            property int total:  25 * 60
            property int remain: 25 * 60
            property bool running: false
            function fmt(s) { var m = Math.floor(s / 60); var ss = s % 60; return m + ":" + (ss < 10 ? "0" : "") + ss }
            function setPreset(mins) { pom.total = mins * 60; pom.remain = mins * 60; pom.running = false }
            Timer {
                interval: 1000; running: pom.running && pom.remain > 0; repeat: true
                onTriggered: { pom.remain--; if (pom.remain <= 0) pom.running = false }
            }
            Text {
                anchors { top: parent.top; left: parent.left }
                text: "󰔟 Pomodoro"
                font.family: Appearance.font.family; font.pixelSize: 13; font.weight: Font.Bold
                color: "#f38ba8"
            }
            Text {
                id: pomBig
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 24 }
                text: pom.fmt(pom.remain)
                font.family: Appearance.font.family; font.pixelSize: 40; font.weight: Font.Bold
                color: pom.remain <= 0 ? "#f38ba8" : Appearance.colors.fg
            }
            Rectangle {
                id: pomTrack
                anchors { left: parent.left; right: parent.right; top: pomBig.bottom; topMargin: 6 }
                height: 6; radius: 3; color: Qt.rgba(1, 1, 1, 0.1)
                Rectangle {
                    width: parent.width * (pom.total > 0 ? (1 - pom.remain / pom.total) : 0)
                    height: parent.height; radius: parent.radius; color: "#f38ba8"
                }
            }
            Row {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                spacing: 8
                component PBtn: Rectangle {
                    property string glyph: ""
                    property color gcol: Appearance.colors.fg
                    signal tapped()
                    width: 34; height: 30; radius: 8
                    color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.5)
                    border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1
                    Text { anchors.centerIn: parent; text: parent.glyph
                           font.family: Appearance.font.family; font.pixelSize: 14; color: parent.gcol }
                    MouseArea { anchors.fill: parent; onClicked: parent.tapped() }
                }
                PBtn { glyph: pom.running ? "󰏤" : "󰐊"; gcol: "#f38ba8"; onTapped: pom.running = !pom.running }
                PBtn { glyph: "󰑙"; onTapped: { pom.remain = pom.total; pom.running = false } }
                PBtn { glyph: "25"; onTapped: pom.setPreset(25) }
                PBtn { glyph: "5";  onTapped: pom.setPreset(5) }
            }
        }
    }
    // Notifications — dernière notif + compteur (NotificationService singleton)
    Component { id: cNotif
        Item {
            readonly property int  cnt:  NotificationService.count
            readonly property var  last: cnt > 0 ? NotificationService.list[0] : null
            Text {
                anchors { top: parent.top; left: parent.left }
                text: "󰂚 Notifications" + (cnt > 0 ? "  (" + cnt + ")" : "")
                font.family: Appearance.font.family; font.pixelSize: 13; font.weight: Font.Bold
                color: Appearance.colors.color10
            }
            Text {
                anchors.centerIn: parent
                visible: parent.cnt === 0
                text: "Aucune notification"
                font.family: Appearance.font.family; font.pixelSize: 13; color: Appearance.colors.dim
            }
            Column {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; verticalCenterOffset: 6 }
                visible: parent.cnt > 0
                spacing: 2
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: parent.parent.last ? (parent.parent.last.appName || "") : ""
                    font.family: Appearance.font.family; font.pixelSize: 10; color: Appearance.colors.color10
                }
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: parent.parent.last ? (parent.parent.last.summary || "") : ""
                    font.family: Appearance.font.family; font.pixelSize: 15; font.weight: Font.Bold; color: Appearance.colors.fg
                }
                Text {
                    width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                    text: parent.parent.last ? (parent.parent.last.body || "") : ""
                    font.family: Appearance.font.family; font.pixelSize: 11; color: Appearance.colors.dim
                }
            }
        }
    }
    // Visualiseur audio (CavaService singleton : 32 barres, valeur 0..100)
    Component { id: cCava
        Item {
            Text {
                anchors { top: parent.top; left: parent.left }
                text: "󰝚 Cava"
                font.family: Appearance.font.family; font.pixelSize: 13; font.weight: Font.Bold
                color: Appearance.colors.color11
            }
            Item {
                id: barArea
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: parent.top; topMargin: 20 }
                readonly property int n: 32
                readonly property real bgap: 3
                readonly property real bw: (width - (n - 1) * bgap) / n
                Repeater {
                    model: barArea.n
                    delegate: Rectangle {
                        required property int index
                        width: barArea.bw
                        x: index * (barArea.bw + barArea.bgap)
                        radius: 2
                        height: Math.max(2, barArea.height * Math.min(1, (CavaService.bars[index] || 0) / 100))
                        y: barArea.height - height
                        color: Qt.lighter(Appearance.colors.color11, 1.0 + 0.4 * (index / barArea.n))
                    }
                }
            }
        }
    }
    Component { id: cCalendar; CalendarCard {} }
    Component { id: cQs;       QuickSettings {} }
    Component { id: cProfile;  ProfileCard {} }

    // Lanceurs d'app (grille de tuiles depuis streamdeck.json ; tap → launch-main.sh)
    Component { id: cApps
        Item {
            Text {
                anchors { top: parent.top; left: parent.left }
                text: "󰀻 Apps"
                font.family: Appearance.font.family; font.pixelSize: 13; font.weight: Font.Bold
                color: Appearance.colors.color4
            }
            Flow {
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 22 }
                spacing: 8
                Repeater {
                    model: root.launcherApps
                    delegate: Rectangle {
                        required property var modelData
                        width: 62; height: 62; radius: 12
                        color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.45)
                        border.color: tapA.pressed ? Appearance.colors.accent : Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1
                        scale: tapA.pressed ? 0.94 : 1
                        Behavior on scale { NumberAnimation { duration: 90 } }
                        Column {
                            anchors.centerIn: parent; spacing: 3
                            Image {
                                id: icoImg
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 30; height: 30
                                visible: (modelData.appicon || "") !== "" && status === Image.Ready
                                source: {
                                    var a = modelData.appicon || ""
                                    if (a === "") return ""
                                    return (a.startsWith("/") || a.startsWith("file://") || a.startsWith("image://"))
                                           ? a : "image://icon/" + a
                                }
                                sourceSize: Qt.size(48, 48); smooth: true
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: (modelData.appicon || "") === "" || icoImg.status === Image.Error
                                text: modelData.icon || "󰀻"
                                font.family: Appearance.font.family; font.pixelSize: 24; color: Appearance.colors.fg
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 56; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                                text: modelData.label || ""
                                font.family: Appearance.font.family; font.pixelSize: 9; color: Appearance.colors.dim
                            }
                        }
                        MouseArea { id: tapA; anchors.fill: parent; onClicked: root.launchApp(modelData.exec) }
                    }
                }
            }
        }
    }

    // Volume (Pipewire) — % + barre tappable
    Component { id: cVolume
        Item {
            id: volW
            readonly property var _sink: Pipewire.defaultAudioSink
            readonly property real vol: volW._sink?.audio?.volume ?? 0
            readonly property bool muted: volW._sink?.audio?.muted ?? false
            Text {
                anchors { top: parent.top; left: parent.left }
                text: (volW.muted ? "󰖁 " : (volW.vol > 0.5 ? "󰕾 " : "󰖀 ")) + "Volume"
                font.family: Appearance.font.family; font.pixelSize: 13; font.weight: Font.Bold
                color: Appearance.colors.color14
            }
            Text {
                id: volBig
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; verticalCenterOffset: -4 }
                text: Math.round(volW.vol * 100)
                font.family: Appearance.font.family; font.pixelSize: 34; font.weight: Font.Bold
                color: volW.muted ? Appearance.colors.dim : Appearance.colors.fg
            }
            Text {
                anchors { left: volBig.right; leftMargin: 3; baseline: volBig.baseline }
                text: "%"; font.family: Appearance.font.family; font.pixelSize: 14; font.weight: Font.Bold
                color: Appearance.colors.color14
            }
            Rectangle {
                id: track
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 4 }
                height: 8; radius: 4; color: Qt.rgba(1, 1, 1, 0.1)
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, volW.vol)); height: parent.height; radius: parent.radius
                    color: volW.muted ? Appearance.colors.dim : Appearance.colors.color14
                }
                MouseArea {
                    anchors.fill: parent; anchors.margins: -8
                    function setv(mx) {
                        if (!volW._sink || !volW._sink.audio) return
                        volW._sink.audio.volume = Math.max(0, Math.min(1, mx / track.width))
                    }
                    onPressed: (e) => setv(e.x)
                    onPositionChanged: (e) => setv(e.x)
                }
            }
        }
    }

    // Uptime (uptime -p)
    Component { id: cUptime
        Item {
            Text {
                anchors { top: parent.top; left: parent.left }
                text: "󰔟 Uptime"
                font.family: Appearance.font.family; font.pixelSize: 13; font.weight: Font.Bold
                color: Appearance.colors.color6
            }
            Text {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; verticalCenterOffset: 4 }
                text: root.uptimeStr !== "" ? root.uptimeStr : "—"
                wrapMode: Text.WordWrap
                font.family: Appearance.font.family; font.pixelSize: 20; font.weight: Font.Bold
                color: Appearance.colors.fg
            }
        }
    }

    // Horloge analogique
    Component { id: cAnalog
        Item {
            property var _now: new Date()
            Timer { interval: 1000; running: true; repeat: true; onTriggered: { parent._now = new Date(); acv.requestPaint() } }
            Canvas {
                id: acv
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) - 6; height: width
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset()
                    var cx = width / 2, cy = height / 2, r = Math.min(cx, cy) - 3
                    if (r <= 0) return
                    // cadran
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.12); ctx.lineWidth = 2
                    ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke()
                    // graduations
                    for (var i = 0; i < 12; i++) {
                        var a = i * Math.PI / 6
                        var r1 = r * (i % 3 === 0 ? 0.82 : 0.9)
                        ctx.beginPath()
                        ctx.moveTo(cx + r1 * Math.sin(a), cy - r1 * Math.cos(a))
                        ctx.lineTo(cx + r * 0.98 * Math.sin(a), cy - r * 0.98 * Math.cos(a))
                        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.22); ctx.lineWidth = (i % 3 === 0 ? 2.5 : 1.2); ctx.stroke()
                    }
                    var n = parent._now
                    var hh = (n.getHours() % 12) + n.getMinutes() / 60
                    var mm = n.getMinutes() + n.getSeconds() / 60
                    var ss = n.getSeconds()
                    function hand(ang, len, w, col) {
                        ctx.beginPath(); ctx.moveTo(cx, cy)
                        ctx.lineTo(cx + len * Math.sin(ang), cy - len * Math.cos(ang))
                        ctx.strokeStyle = col; ctx.lineWidth = w; ctx.lineCap = "round"; ctx.stroke()
                    }
                    hand(hh * Math.PI / 6, r * 0.5,  3.5, String(Appearance.colors.fg))
                    hand(mm * Math.PI / 30, r * 0.72, 2.5, String(Appearance.colors.fg))
                    hand(ss * Math.PI / 30, r * 0.82, 1.2, String(Appearance.colors.accent))
                    ctx.beginPath(); ctx.arc(cx, cy, 3, 0, Math.PI * 2); ctx.fillStyle = String(Appearance.colors.accent); ctx.fill()
                }
                onWidthChanged: requestPaint(); onHeightChanged: requestPaint()
            }
        }
    }
    // Palette wallust (color0..15)
    Component { id: cPalette
        Item {
            Text {
                anchors { top: parent.top; left: parent.left }
                text: "󰸌 Palette"
                font.family: Appearance.font.family; font.pixelSize: 13; font.weight: Font.Bold
                color: Appearance.colors.color11
            }
            Grid {
                id: palGrid
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 22 }
                columns: 8; rowSpacing: 4; columnSpacing: 4
                Repeater {
                    model: 16
                    delegate: Rectangle {
                        required property int index
                        width: Math.floor((palGrid.width - 7 * 4) / 8)
                        height: Math.floor((palGrid.height - 4) / 2)
                        radius: 5
                        color: Appearance.colors["color" + index]
                        border.color: Qt.rgba(1, 1, 1, 0.1); border.width: 1
                    }
                }
            }
        }
    }
    // Wallpaper courant (vignette)
    Component { id: cWall
        Item {
            Rectangle {
                anchors.fill: parent; radius: 10; clip: true; color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.5)
                Image {
                    anchors.fill: parent
                    source: WallpaperState.videoMode
                            ? "file://" + Quickshell.env("HOME") + "/.curr_wall_static.jpg"
                            : (WallpaperState.currentWall !== "" ? "file://" + WallpaperState.currentWall : "")
                    fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; sourceSize.width: 600
                }
                Rectangle {
                    anchors { left: parent.left; bottom: parent.bottom }
                    width: wlLbl.width + 16; height: wlLbl.height + 8
                    color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.7); radius: 8
                    Text { id: wlLbl; anchors.centerIn: parent; text: "󰸉 Wallpaper"
                           font.family: Appearance.font.family; font.pixelSize: 11; font.weight: Font.Bold; color: Appearance.colors.fg }
                }
            }
        }
    }
    // Pense-bête (note persistée par widget, éditable hors mode édition)
    Component { id: cNote
        Item {
            id: noteW
            readonly property var    wd:  noteW.parent ? noteW.parent.wdata : null
            readonly property string wid: noteW.parent ? noteW.parent.wid : ""
            Text {
                anchors { top: parent.top; left: parent.left }
                text: "󰎞 Note"
                font.family: Appearance.font.family; font.pixelSize: 13; font.weight: Font.Bold
                color: Appearance.colors.color5
            }
            Flickable {
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 22 }
                contentHeight: noteEdit.height; clip: true
                TextEdit {
                    id: noteEdit
                    width: parent.width
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    font.family: Appearance.font.family; font.pixelSize: 13
                    color: Appearance.colors.fg
                    Component.onCompleted: text = (noteW.wd && noteW.wd.note) ? noteW.wd.note : ""
                    onActiveFocusChanged: if (!activeFocus && noteW.wid !== "") root.setWidgetProp(noteW.wid, "note", text)
                    Text {
                        anchors.fill: parent
                        visible: noteEdit.text.length === 0
                        text: "Écris une note…"
                        font: noteEdit.font; color: Qt.rgba(1, 1, 1, 0.3)
                    }
                }
            }
        }
    }
    // Power (verrou / quitter / reboot / arrêt) — 2 taps pour confirmer
    Component { id: cPower
        Item {
            id: pw
            property int armed: -1
            readonly property var acts: [
                { ic: "󰌾", label: "Verrou",  cmd: "loginctl lock-session", col: Appearance.colors.color6 },
                { ic: "󰍃", label: "Quitter", cmd: "hyprctl dispatch exit",   col: Appearance.colors.color13 },
                { ic: "󰜉", label: "Reboot",  cmd: "systemctl reboot",        col: "#fab387" },
                { ic: "󰐥", label: "Arrêt",   cmd: "systemctl poweroff",      col: "#f38ba8" }
            ]
            Timer { id: pwDisarm; interval: 2500; onTriggered: pw.armed = -1 }
            Text {
                anchors { top: parent.top; left: parent.left }
                text: "󰐥 Power"
                font.family: Appearance.font.family; font.pixelSize: 13; font.weight: Font.Bold
                color: "#f38ba8"
            }
            Grid {
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 24 }
                columns: 2; rowSpacing: 8; columnSpacing: 8
                Repeater {
                    model: pw.acts
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool arm: pw.armed === index
                        width: Math.floor((parent.width - 8) / 2)
                        height: Math.floor((parent.height - 8) / 2)
                        radius: 10
                        color: arm ? ColorUtils.applyAlpha(modelData.col, 0.85) : ColorUtils.applyAlpha(Appearance.colors.bg, 0.5)
                        border.color: ColorUtils.applyAlpha(modelData.col, arm ? 0.9 : 0.4); border.width: 1
                        Column {
                            anchors.centerIn: parent; spacing: 2
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.ic
                                   font.family: Appearance.font.family; font.pixelSize: 20; color: arm ? Appearance.colors.bg : modelData.col }
                            Text { anchors.horizontalCenter: parent.horizontalCenter
                                   text: arm ? "Confirmer ?" : modelData.label
                                   font.family: Appearance.font.family; font.pixelSize: 11; color: arm ? Appearance.colors.bg : Appearance.colors.fg }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (pw.armed === index) { root.runPower(modelData.cmd); pw.armed = -1; pwDisarm.stop() }
                                else { pw.armed = index; pwDisarm.restart() }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Barre du haut : titre + bouton édition ───────────────────────────────
    Item {
        id: topbar
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 44
        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: "Grille"
            font.family: Appearance.font.family; font.pixelSize: 18; font.weight: Font.Bold
            color: Appearance.colors.fg
        }
        Rectangle {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 128; height: 34; radius: 10
            color: root.editMode ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.85)
                                 : ColorUtils.applyAlpha(Appearance.colors.bg, 0.5)
            border.color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.5); border.width: 1
            Text {
                anchors.centerIn: parent
                text: root.editMode ? "  Terminer" : "  Éditer"
                font.family: Appearance.font.family; font.pixelSize: 13; font.weight: Font.Bold
                color: root.editMode ? Appearance.colors.bg : Appearance.colors.fg
            }
            MouseArea { anchors.fill: parent; onClicked: root.editMode = !root.editMode }
        }
    }

    // ── Palette (mode édition) : onglets par catégorie + widgets ─────────────
    Column {
        id: palette
        visible: root.editMode
        anchors { top: topbar.bottom; left: parent.left; right: parent.right; topMargin: 4 }
        spacing: 6

        // Onglets de catégorie
        Row {
            spacing: 6
            Repeater {
                model: root.palCats
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool sel: root.palCat === modelData
                    width: ctLbl.width + 22; height: 28; radius: 8
                    color: sel ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.85)
                               : ColorUtils.applyAlpha(Appearance.colors.bg, 0.5)
                    border.color: ColorUtils.applyAlpha(Appearance.colors.accent, sel ? 0.9 : 0.3); border.width: 1
                    Text {
                        id: ctLbl; anchors.centerIn: parent; text: modelData
                        font.family: Appearance.font.family; font.pixelSize: 12; font.weight: Font.Bold
                        color: sel ? Appearance.colors.bg : Appearance.colors.fg
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.palCat = modelData }
                }
            }
        }

        // Widgets de la catégorie sélectionnée
        Flow {
            width: parent.width
            spacing: 8
            Repeater {
                model: root.catalog.filter(function (c) { return (c.cat || "Autres") === root.palCat })
                delegate: Rectangle {
                    required property var modelData
                    width: pLbl.width + 34; height: 32; radius: 8
                    color: ColorUtils.applyAlpha(modelData.col, 0.18)
                    border.color: ColorUtils.applyAlpha(modelData.col, 0.6); border.width: 1
                    Row {
                        id: pLbl; anchors.centerIn: parent; spacing: 6
                        Text { text: "+"; color: modelData.col; font.family: Appearance.font.family
                               font.pixelSize: 15; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: modelData.label; color: Appearance.colors.fg; font.family: Appearance.font.family
                               font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { anchors.fill: parent; onClicked: root.addWidget(modelData.type) }
                }
            }
        }
    }

    // ── Zone de grille ───────────────────────────────────────────────────────
    Item {
        id: gridArea
        anchors {
            top: root.editMode ? palette.bottom : topbar.bottom
            left: parent.left; right: parent.right; bottom: parent.bottom
            topMargin: 6
            bottomMargin: (root.pageCount > 1 || root.editMode) ? 30 : 0
        }
        clip: true

        // Guides de grille (mode édition)
        Canvas {
            anchors.fill: parent
            visible: root.editMode
            onPaint: {
                var ctx = getContext("2d"); ctx.reset()
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.06); ctx.lineWidth = 1
                for (var c = 0; c <= root.cols; c++) {
                    var x = root.px(c) - root.gap / 2
                    ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke()
                }
                for (var r = 0; r <= root.rows; r++) {
                    var y = root.py(r) - root.gap / 2
                    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
                }
            }
            Component.onCompleted: requestPaint()
            onWidthChanged: requestPaint(); onHeightChanged: requestPaint()
        }

        Repeater {
            model: root.pageWidgets
            delegate: Item {
                id: frame
                required property var modelData
                required property int index
                property int gw: modelData.w
                property int gh: modelData.h
                property real startW: 0
                property real startH: 0
                // Widgets déjà stylés (StatCard/PlayerCard) : cadre transparent +
                // sans marge → on garde leur look de base, pas de carte-dans-carte.
                readonly property bool bare: ["media", "calendar", "qs", "profile"].indexOf(modelData.type) !== -1
                readonly property color accentCol: root.catalogFor(modelData.type).col

                width:  root.wpx(gw)
                height: root.hpx(gh)
                x: root.px(modelData.x)
                y: root.py(modelData.y)
                z: (dragMA.pressed || resizeMA.pressed) ? 20 : 1

                Rectangle {
                    anchors.fill: parent; radius: 16
                    color: (frame.bare && !root.editMode) ? "transparent"
                                                          : ColorUtils.applyAlpha(Appearance.colors.bg, 0.5)
                    border.color: root.editMode ? ColorUtils.applyAlpha(Appearance.colors.accent, 0.7)
                                                : (frame.bare ? "transparent" : ColorUtils.applyAlpha(frame.accentCol, 0.30))
                    border.width: root.editMode ? 2 : (frame.bare ? 0 : 1)
                }

                Loader {
                    anchors { fill: parent; margins: frame.bare ? 0 : 14 }
                    // Exposé au contenu (widgets à config par instance : note, etc.)
                    property var    wdata: frame.modelData
                    property string wid:   frame.modelData.id
                    sourceComponent: root.compMap[frame.modelData.type] || cUnknown
                }

                // Surface de déplacement (mode édition) — AU-DESSUS du contenu pour
                // que même les widgets interactifs (Media, Réglages, Volume, Apps,
                // Pomodoro…) soient déplaçables et que le contenu ne capte pas le geste.
                MouseArea {
                    id: dragMA
                    visible: root.editMode
                    enabled: root.editMode
                    z: 3
                    anchors.fill: parent
                    preventStealing: true
                    cursorShape: Qt.SizeAllCursor
                    property real ox: 0
                    property real oy: 0
                    onPressed: (mouse) => {
                        var p = dragMA.mapToItem(gridArea, mouse.x, mouse.y)
                        dragMA.ox = p.x - frame.x
                        dragMA.oy = p.y - frame.y
                    }
                    onPositionChanged: (mouse) => {
                        var p = dragMA.mapToItem(gridArea, mouse.x, mouse.y)
                        frame.x = p.x - dragMA.ox
                        frame.y = p.y - dragMA.oy
                    }
                    onReleased: {
                        var ngx = Math.round((frame.x - root.gap) / (root.cellW + root.gap))
                        var ngy = Math.round((frame.y - root.gap) / (root.cellH + root.gap))
                        ngx = Math.max(0, Math.min(root.cols - frame.gw, ngx))
                        ngy = Math.max(0, Math.min(root.rows - frame.gh, ngy))
                        root.moveWidget(frame.modelData.id, ngx, ngy)
                        frame.x = Qt.binding(function () { return root.px(frame.modelData.x) })
                        frame.y = Qt.binding(function () { return root.py(frame.modelData.y) })
                    }
                }

                // Supprimer (mode édition)
                Rectangle {
                    visible: root.editMode
                    z: 6
                    anchors { top: parent.top; right: parent.right; topMargin: -6; rightMargin: -6 }
                    width: 26; height: 26; radius: 13
                    color: "#f38ba8"
                    Text { anchors.centerIn: parent; text: "×"; color: "white"; font.pixelSize: 16; font.weight: Font.Bold }
                    MouseArea { anchors.fill: parent; onClicked: root.removeWidget(frame.modelData.id) }
                }

                // Poignée de redimensionnement (mode édition) — MouseArea (preventStealing)
                // pour ne pas se faire voler le geste par le DragHandler du cadre.
                Rectangle {
                    id: rHandle
                    visible: root.editMode
                    z: 5
                    anchors { bottom: parent.bottom; right: parent.right; bottomMargin: 3; rightMargin: 3 }
                    width: 26; height: 26; radius: 6
                    color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.9)
                    Text { anchors.centerIn: parent; text: "󰩨"; color: Appearance.colors.bg; font.family: Appearance.font.family; font.pixelSize: 12 }
                    MouseArea {
                        id: resizeMA
                        anchors { fill: parent; margins: -8 }
                        preventStealing: true
                        onPositionChanged: (mouse) => {
                            var p = resizeMA.mapToItem(gridArea, mouse.x, mouse.y)
                            frame.width  = Math.max(root.cellW, p.x - frame.x)
                            frame.height = Math.max(root.cellH, p.y - frame.y)
                        }
                        onReleased: {
                            var nw = Math.round((frame.width  + root.gap) / (root.cellW + root.gap))
                            var nh = Math.round((frame.height + root.gap) / (root.cellH + root.gap))
                            nw = Math.max(1, Math.min(root.cols - frame.modelData.x, nw))
                            nh = Math.max(1, Math.min(root.rows - frame.modelData.y, nh))
                            root.resizeWidget(frame.modelData.id, nw, nh)
                            frame.width  = Qt.binding(function () { return root.wpx(frame.gw) })
                            frame.height = Qt.binding(function () { return root.hpx(frame.gh) })
                        }
                    }
                }
            }
        }
    }

    // ── Sélecteur de pages (« workspaces » de la grille) ─────────────────────
    Row {
        id: pageSwitcher
        visible: root.pageCount > 1 || root.editMode
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 8 }
        spacing: 8

        // − (édition) : retirer une page
        Rectangle {
            visible: root.editMode
            width: 26; height: 20; radius: 6; anchors.verticalCenter: parent.verticalCenter
            color: ColorUtils.applyAlpha(Appearance.colors.bg, 0.6)
            border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1
            Text { anchors.centerIn: parent; text: "−"; color: Appearance.colors.fg; font.pixelSize: 15; font.weight: Font.Bold }
            MouseArea { anchors.fill: parent; onClicked: root.setPageCount(root.pageCount - 1) }
        }

        // Points de page
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            Repeater {
                model: root.pageCount
                delegate: Rectangle {
                    required property int index
                    readonly property bool cur: index === root.curPage
                    width: cur ? 24 : 10; height: 10; radius: 5
                    anchors.verticalCenter: parent.verticalCenter
                    color: cur ? Appearance.colors.accent : ColorUtils.applyAlpha(Appearance.colors.fg, 0.3)
                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    MouseArea { anchors.fill: parent; anchors.margins: -7; onClicked: root.curPage = index }
                }
            }
        }

        // + (édition) : ajouter une page
        Rectangle {
            visible: root.editMode
            width: 26; height: 20; radius: 6; anchors.verticalCenter: parent.verticalCenter
            color: ColorUtils.applyAlpha(Appearance.colors.accent, 0.85)
            Text { anchors.centerIn: parent; text: "+"; color: Appearance.colors.bg; font.pixelSize: 15; font.weight: Font.Bold }
            MouseArea { anchors.fill: parent; onClicked: root.setPageCount(root.pageCount + 1) }
        }
    }

    // Astuce mode édition (en bas à gauche pour ne pas gêner le sélecteur)
    Text {
        visible: root.editMode
        anchors { bottom: parent.bottom; left: parent.left; bottomMargin: 8; leftMargin: 4 }
        text: "Glisse · poignée = taille · × = retirer · points = pages"
        font.family: Appearance.font.family; font.pixelSize: 11; color: Appearance.colors.dim
    }
}
