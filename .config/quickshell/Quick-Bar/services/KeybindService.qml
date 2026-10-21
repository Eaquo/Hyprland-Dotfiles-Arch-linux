pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.panels

QtObject {
    id: root

    readonly property string _shellDir: Quickshell.shellDir
    // Raccourcis propres à Quick-Bar : générés dans Quick-Bar/hypr/, chargés par une ligne de
    // hyprland.lua (ajoutée si absente). Personnalisations : user_data/keybinds.json.
    readonly property string _configDir: _shellDir + "/hypr"
    readonly property string _luaPath:  _configDir + "/quickbar.lua"
    readonly property string _confPath: _configDir + "/quickbar.conf"
    readonly property string _jsonPath: _shellDir + "/user_data/keybinds.json"
    readonly property string _oldJson:  Quickshell.env("HOME") + "/.config/Brain_Shell/src/user_data/keybinds.json"
    
    property string configProvider: ShellState.configProvider

    // ── Capture gate ──────────────────────────────────────────────────────────
    // Set true by KeybindsPage while a combo is being recorded.
    // In your state handler (ShellState / Popups), observe this and dispatch:
    //   true  →  hyprctl dispatch submap, clean
    //   false →  hyprctl dispatch submap, reset
    property bool isCapturing: false

    // ── Defaults ──────────────────────────────────────────────────────────────
    // id → { mods, key, label, group, target (IpcHandler), fn (fonction appelée, « toggle » par défaut) }
    readonly property var _defaults: ({
        "settings":         { mods: "SUPER",       key: "F1",     label: "Réglages",                     group: "Panneaux",       target: "settings" },
        "dashboard-home":   { mods: "SUPER + SHIFT", key: "D",      label: "Dashboard",                    group: "Panneaux",       target: "dashboard-home" },
        "spotify":          { mods: "SUPER + SHIFT", key: "S",    label: "Panneau Spotify",              group: "Panneaux",       target: "spotify" },
        "overview":         { mods: "SUPER",       key: "A",      label: "Vue d'ensemble des espaces",   group: "Panneaux",       target: "overview" },
        "apps":             { mods: "SUPER",       key: "SUPER_L", label: "Lanceur d'applications (Super seul)", group: "Menus", target: "menu", fn: "run apps", release: true },
        "game-scripts":     { mods: "SUPER + SHIFT", key: "G",    label: "Scripts de jeux",              group: "Menus",          target: "menu", fn: "run game-scripts" },
        "keyhints":         { mods: "SUPER",       key: "H",      label: "Aide-mémoire des raccourcis",  group: "Menus",          target: "menu", fn: "run keyhints" },
        "alttab-next":      { mods: "ALT",         key: "Tab",    label: "Changer de fenêtre",           group: "Fenêtres",       target: "alttab", fn: "next" },
        "alttab-prev":      { mods: "ALT + SHIFT", key: "Tab",    label: "Changer de fenêtre (retour)",  group: "Fenêtres",       target: "alttab", fn: "prev" },
        "alttab-go":        { mods: "ALT",         key: "ALT_L",  label: "Aller sur la fenêtre (relâcher Alt)", group: "Fenêtres", target: "alttab", fn: "commit", release: true },
        "notifications":    { mods: "SUPER + SHIFT", key: "N",    label: "Centre de notifications",      group: "Panneaux",       target: "notifications", fn: "toggle" },
        "bluetooth":        { mods: "CTRL",        key: "B",      label: "Bluetooth",                    group: "Menus",          target: "menu", fn: "run bluetooth" },
        "quickedit":        { mods: "SUPER + SHIFT", key: "E",    label: "Éditer une config",            group: "Menus",          target: "menu", fn: "run quickedit" },
        "lock":             { mods: "SUPER",       key: "L",      label: "Verrouiller",                  group: "Panneaux",       target: "lock", fn: "lock" },
        "lock-alt":         { mods: "CTRL + ALT",  key: "L",      label: "Verrouiller",                  group: "Panneaux",       target: "lock", fn: "lock" },
        "session":          { mods: "CTRL + ALT",  key: "P",      label: "Session (verrouiller, éteindre…)", group: "Panneaux",   target: "session" },
        "wallpicker":       { mods: "SUPER",       key: "W",      label: "Fond d'écran : carrousel",     group: "Fond d'écran",   target: "wallpicker" },
        "wallcinema":       { mods: "ALT",         key: "W",      label: "Fond d'écran : Cinéma",        group: "Fond d'écran",   target: "wallcinema" },
        "wallpaper-random": { mods: "CTRL + ALT",  key: "W",      label: "Fond d'écran au hasard",       group: "Fond d'écran",   target: "wallpicker", fn: "random" },
        "gamebreak":        { mods: "SUPER",       key: "T",      label: "Pause tactile en jeu",         group: "Jeu",            target: "gamebreak" },
        "focus-toggle":     { mods: "SUPER",       key: "F2",      label: "Mode focus",                   group: "Réglages rapides", target: "focus-toggle" },
        "screenrec-on":     { mods: "ALT",         key: "F9",     label: "Capture vidéo",                group: "Réglages rapides", target: "screenrec-on" }
    })

    property var keybinds: ({})

    // ── Hyprland binds cache ──────────────────────────────────────────────────
    // Refreshed each time a BindRow enters capture mode.
    property var _hyprBinds: []

    property var _hyprBindsProc: Process {
        command: ["hyprctl", "binds", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try   { root._hyprBinds = JSON.parse(text.trim()) }
                catch (e) { root._hyprBinds = [] }
            }
        }
    }

    function loadHyprBinds() {
        _hyprBindsProc.running = false
        _hyprBindsProc.running = true
    }

    // Converts "SUPER + SHIFT" → Hyprland modmask integer
    function _modsToMask(modsStr) {
        var mask = 0
        var parts = modsStr.toUpperCase().split("+")
        for (var i = 0; i < parts.length; i++) {
            var p = parts[i].trim()
            if      (p === "SUPER") mask |= 64
            else if (p === "SHIFT") mask |= 1
            else if (p === "CTRL")  mask |= 4
            else if (p === "ALT")   mask |= 8
        }
        return mask
    }

    // Returns a short description of the conflicting Hyprland bind, or "".
    // Own shell binds (arg contains "qs ipc") are filtered out.
    function wouldConflictHypr(action, mods, key) {
        var mask = _modsToMask(mods)
        var k    = key.toLowerCase()
        for (var i = 0; i < root._hyprBinds.length; i++) {
            var b = root._hyprBinds[i]
            if (b.submap !== "")                        continue  // ignore submaps
            if (b.mouse)                                continue  // ignore mouse binds
            if (b.arg && (b.arg.indexOf("qs ipc") >= 0 || b.arg.indexOf("Quick-Bar/shell.qml ipc") >= 0)) continue  // nos propres raccourcis
            if (b.modmask === mask && (b.key || "").toLowerCase() === k) {
                var desc = b.dispatcher || ""
                if (b.arg) desc += ": " + b.arg.substring(0, 36)
                return desc || "Hyprland bind"
            }
        }
        return ""
    }

    // ── Internal duplicate detection ──────────────────────────────────────────
    readonly property var _comboMap: {
        var m = {}
        var ks = Object.keys(root.keybinds)
        for (var i = 0; i < ks.length; i++) {
            var b = root.keybinds[ks[i]]
            if (!b || !b.mods || !b.key) continue
            var combo = b.mods + "+" + b.key
            if (!m[combo]) m[combo] = [ks[i]]
            else           m[combo] = m[combo].concat([ks[i]])
        }
        return m
    }

    function isDuplicate(action) {
        var b = root.keybinds[action]
        if (!b || !b.mods || !b.key) return false
        var combo = b.mods + "+" + b.key
        return !!(root._comboMap[combo] && root._comboMap[combo].length > 1)
    }

    function conflictsWith(action) {
        var b = root.keybinds[action]
        if (!b || !b.mods || !b.key) return ""
        var list = root._comboMap[b.mods + "+" + b.key]
        if (!list || list.length < 2) return ""
        for (var i = 0; i < list.length; i++) {
            if (list[i] !== action) {
                var o = root.keybinds[list[i]]
                return o ? o.label : list[i]
            }
        }
        return ""
    }

    function wouldConflict(action, mods, key) {
        var combo = mods + "+" + key
        var ks    = Object.keys(root.keybinds)
        for (var i = 0; i < ks.length; i++) {
            if (ks[i] === action) continue
            var b = root.keybinds[ks[i]]
            if (b && b.mods + "+" + b.key === combo)
                return b.label || ks[i]
        }
        return ""
    }

    // ── Load ──────────────────────────────────────────────────────────────────
    property var _loadProc: Process {
        command: ["bash", "-c",
            "[ -f '" + root._jsonPath + "' ] && cat '" + root._jsonPath + "' || { [ -f '" + root._oldJson + "' ] && cat '" + root._oldJson + "' || echo '{}'; }"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var merged = {}
                var defs   = root._defaults
                var dkeys  = Object.keys(defs)
                for (var i = 0; i < dkeys.length; i++) {
                    var dk = dkeys[i]
                    merged[dk] = { mods: defs[dk].mods, key: defs[dk].key, label: defs[dk].label, group: defs[dk].group,
                                   target: defs[dk].target || dk, fn: defs[dk].fn || "toggle", release: defs[dk].release === true }
                }
                try {
                    var saved = JSON.parse(text.trim())
                    var sk = Object.keys(saved)
                    for (var j = 0; j < sk.length; j++) {
                        var s = sk[j]
                        if (!merged[s]) continue
                        if (saved[s].mods !== undefined) merged[s].mods = saved[s].mods
                        if (saved[s].key  !== undefined) merged[s].key  = saved[s].key
                    }
                } catch(e) {}
                root.keybinds = merged
                root._writeFiles()
                root._ensureInclude()
            }
        }
    }

    // ── Save / Reload ─────────────────────────────────────────────────────────
    function save() {
        var out  = {}
        var defs = root._defaults
        var ks   = Object.keys(root.keybinds)
        for (var i = 0; i < ks.length; i++) {
            var k = ks[i]
            if (!defs[k]) continue
            if (root.keybinds[k].mods !== defs[k].mods || root.keybinds[k].key !== defs[k].key)
                out[k] = { mods: root.keybinds[k].mods, key: root.keybinds[k].key }
        }
        var json = JSON.stringify(out, null, 2)
        _saveProc.command = ["bash", "-c",
            "mkdir -p \"$(dirname '" + root._jsonPath + "')\" && " +
            "printf '%s' '" + json.replace(/'/g, "'\\''") + "' > '" + root._jsonPath + "'"]
        _saveProc.running = false
        _saveProc.running = true
        root._writeFiles()
    }

    property var _saveProc: Process { command: []; running: false }

    property var _reloadProc: Process {
        command: ["hyprctl", "reload"]
        running: false
    }

    // Brief delay lets the file writes flush before hyprctl re-reads them
    property var _reloadTimer: Timer {
        interval: 300
        repeat:   false
        onTriggered: {
            root._reloadProc.running = false
            root._reloadProc.running = true
        }
    }

    function reload() {
        _reloadTimer.restart()
    }

    // Persist to disk and reload Hyprland in one call
    function saveAndReload() {
        save()
        reload()
    }

    // Updates in-memory only — does NOT persist.
    // Callers responsible for invoking saveAndReload() when ready.
    function updateBinding(action, newMods, newKey) {
        var old = root.keybinds[action]
        if (!old) return
        var m = newMods.toUpperCase().trim()
        var k = newKey.toUpperCase().trim()
        if (m === "" || k === "") return
        if (root.wouldConflict(action, m, k) !== "") return
        var copy     = Object.assign({}, root.keybinds)
        copy[action] = { mods: m, key: k, label: old.label, group: old.group }
        root.keybinds = copy
    }

    // Reset is always immediate — reverts to default and reloads right away
    function resetBinding(action) {
        var def = root._defaults[action]
        if (!def) return
        updateBinding(action, def.mods, def.key)
        saveAndReload()
    }

    // ── File generation ───────────────────────────────────────────────────────
    property var _writeProc: Process { command: []; running: false }

    function _writeFiles() {
        var lua = _genLua()
        var conf = _genConf()
        var le  = lua.replace(/\\/g, "\\\\").replace(/'/g, "'\\''")
        var ce  = conf.replace(/\\/g, "\\\\").replace(/'/g, "'\\''")
        
        // Write both files so the user has them regardless of what they switch to
        _writeProc.command = ["bash", "-c",
            "mkdir -p '" + root._configDir + "' && " +
            "printf '%s' '" + le + "' > '" + root._luaPath + "' && " +
            "printf '%s' '" + ce + "' > '" + root._confPath + "'"]
            
        _writeProc.running = false
        _writeProc.running = true
    }

    function _grouped() {
        var groups = {}; var order = []
        var ks = Object.keys(root.keybinds)
        for (var i = 0; i < ks.length; i++) {
            var k = ks[i]; var b = root.keybinds[k]
            if (!b || !b.mods || !b.key) continue
            var g = b.group || "Other"
            if (!groups[g]) { groups[g] = []; order.push(g) }
            groups[g].push({ k: k, mods: b.mods, key: b.key, label: b.label, target: b.target || k, fn: b.fn || "toggle", release: b.release === true })
        }
        return { groups: groups, order: order }
    }

    function _genLua() {
        var sd   = root._shellDir.replace(/"/g, "\\\"")
        var data = _grouped()
        
        var lines = [
            "-- ==============================================================================",
            "-- Quick-Bar — raccourcis clavier",
            "-- Généré par Quick-Bar (Réglages › Raccourcis) : ne pas modifier à la main.",
            "-- Chargé par ~/.config/hypr/hyprland.lua : dofile(\".../Quick-Bar/hypr/quickbar.lua\")",
            "-- ==============================================================================",
            "",
            "local qb = \"qs -p " + sd + "/shell.qml ipc call \"",
            "",
            "-- ==============================================================================",
            "-- BrainShell Capture Submap (Disables all normal binds during recording)",
            "-- ==============================================================================",
            "hl.define_submap(\"BrainShell_clean\", function()",
            "    -- Emergency exit in case the shell crashes during capture",
            "    hl.bind(\"CTRL + ESCAPE\", function()",
            "        hl.dispatch(hl.dsp.exec_cmd(\"notify-send 'BrainShell' 'Emergency Exit: Keybinds re-enabled.'\"))",
            "        hl.dispatch(hl.dsp.submap(\"reset\"))",
            "    end, { description = \"Emergency return to global submap\" })",
            "end)",
            "",
            "-- ==============================================================================",
            "-- User Defined Bindings",
            "-- ==============================================================================",
            ""
        ]
        
        for (var gi = 0; gi < data.order.length; gi++) {
            var g = data.order[gi]
            lines.push("-- " + g)
            var entries = data.groups[g]
            for (var ei = 0; ei < entries.length; ei++) {
                var e = entries[ei]
                lines.push("hl.bind(\"" + e.mods + " + " + e.key + "\", hl.dsp.exec_cmd(qb .. \"" + e.target + " " + e.fn + "\"), { description = \"" + e.label.replace(/"/g, "'") + "\"" + (e.release ? ", release = true" : "") + " })")
            }
            lines.push("")
        }
        return lines.join("\n")
    }

    function _genConf() {
        var data = _grouped()
        
        var lines = [
            "# ==============================================================================",
            "# Brain Shell Keybinds",
            "# Auto-generated by Quickshell. Do not edit manually.",
            "# ==============================================================================",
            "",
            "# ==============================================================================",
            "# BrainShell Capture Submap (Disables all normal binds during recording)",
            "# ==============================================================================",
            "submap = BrainShell_clean",
            "bind = CTRL, ESCAPE, exec, notify-send 'BrainShell' 'Emergency Exit: Keybinds re-enabled.'",
            "bind = CTRL, ESCAPE, submap, reset",
            "submap = reset",
            "",
            "# ==============================================================================",
            "# User Defined Bindings",
            "# ==============================================================================",
            ""
        ]
        
        for (var gi = 0; gi < data.order.length; gi++) {
            var g = data.order[gi]
            lines.push("# " + g)
            var entries = data.groups[g]
            for (var ei = 0; ei < entries.length; ei++) {
                var e = entries[ei]
                // Hyprland .conf format drops the '+' symbol between modifiers
                var confMods = e.mods.replace(/\s*\+\s*/g, " ")
                var cmd = "qs -p " + root._shellDir + "/shell.qml ipc call " + e.target + " " + e.fn
                lines.push("bind = " + confMods + ", " + e.key + ", exec, " + cmd)
            }
            lines.push("")
        }
        return lines.join("\n")
    }

    // ── Auto-include in hyprland configs ──────────────────────────────────────
    property var _includeProc: Process { command: []; running: false }

    // hyprland.lua charge quickbar.lua ; l'ancienne ligne Brain_Shell (même rôle) est remplacée
    function _ensureInclude() {
        var lp = root._luaPath.replace(/"/g, "\\\"")
        var cp = root._confPath.replace(/"/g, "\\\"")
        if (configProvider === "lua") {
            _includeProc.command = ["bash", "-c", [
                "LUA=\"$HOME/.config/hypr/hyprland.lua\"",
                "[ -f \"$LUA\" ] || exit 0",
                "sed -i '/^-- Brain_ShellKeybinds$/d; /Brain_Shell\\/Brain_ShellKeybinds.lua/d' \"$LUA\"",
                "grep -qF 'Quick-Bar/hypr/quickbar.lua' \"$LUA\" || printf '\\n-- Quick-Bar : raccourcis (Réglages › Raccourcis)\\ndofile(\"" + lp + "\")\\n' >> \"$LUA\""
            ].join("\n")]
        } else {
            _includeProc.command = ["bash", "-c", [
                "CONF=\"$HOME/.config/hypr/hyprland.conf\"",
                "[ -f \"$CONF\" ] || exit 0",
                "sed -i '/^# Brain_ShellKeybinds$/d; /Brain_ShellKeybinds.conf/d' \"$CONF\"",
                "grep -qF 'Quick-Bar/hypr/quickbar.conf' \"$CONF\" || printf '\\n# Quick-Bar : raccourcis\\nsource = " + cp + "\\n' >> \"$CONF\""
            ].join("\n")]
        }
        _includeProc.running = false
        _includeProc.running = true
    }

    Component.onCompleted: _loadProc.running = true
}
