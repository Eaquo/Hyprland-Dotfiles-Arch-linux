-- ── Variables ─────────────────────────────────────────────────────────────────
local mainMod = "SUPER"
local home = os.getenv("HOME")
local scripts = home .. "/.config/hypr/scripts"
local userScripts = home .. "/.config/hypr/UserScripts"
local term = "kitty"
local files = "thunar"

-- ── Freeze ────────────────────────────────────────────────────────────────────
hl.bind("PAUSE", hl.dsp.exec_cmd("wl-freeze -a"))

-- ── Lanceurs ──────────────────────────────────────────────────────────────────
-- Super seul : lanceur d'apps Quick-Bar (menus/scripts/apps.sh, bind généré dans Quick-Bar/hypr/quickbar.lua)
-- hl.bind(
-- 	mainMod .. " + SUPER_L",
-- 	hl.dsp.exec_cmd("pkill rofi || rofi -show drun -modi drun,filebrowser,run,window"),
-- 	{ release = true }
-- )

-- Rofi via Super+D → retiré : SUPER+D = Discord (Keybinds.lua), le lanceur d'applis = Super seul (Quick-Bar)
-- hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("pkill rofi || rofi -show drun -modi drun,filebrowser,run,window"))

-- Claude.ai
hl.bind("ALT + C", hl.dsp.exec_cmd("claude-desktop"))

-- ── Apps ──────────────────────────────────────────────────────────────────────
-- Terminal
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(term))

-- Pypr toggles
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd("pypr toggle term"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("pypr toggle clock"))
-- Panneau Spotify de Quick-Bar (bord droit). La fenêtre Spotify (scratchpad pypr
-- « spot ») s'ouvre depuis le bouton 󰏌 du panneau.
-- → déplacé dans Quick-Bar/hypr/quickbar.lua (Réglages › Raccourcis de Quick-Bar)
-- hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("qs -p " .. os.getenv("HOME") .. "/.config/quickshell/Quick-Bar/shell.qml ipc call spotify toggle"))
-- Fenêtre Réglages de Quick-Bar
-- → déplacé dans Quick-Bar/hypr/quickbar.lua (Réglages › Raccourcis de Quick-Bar)
-- hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd("qs -p " .. os.getenv("HOME") .. "/.config/quickshell/Quick-Bar/shell.qml ipc call settings toggle"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("pypr toggle ranger"))

-- ── JARVIS ────────────────────────────────────────────────────────────────────
-- jarvis-panel bascule le scratchpad pypr ET accorde le casque Bluetooth:
-- panneau visible = profil micro, panneau masque = profil musique. Le micro
-- d'un casque Bluetooth n'existe que dans le profil headset, qui degrade le
-- son: on n'y reste donc que le temps d'utiliser JARVIS.
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd(home .. "/.local/bin/jarvis-panel"))

-- ── Vues / Overview ───────────────────────────────────────────────────────────
-- SUPER+A : vue d'ensemble Quick-Bar (panels/Overview.qml, bind généré dans Quick-Bar/hypr/quickbar.lua)
-- hl.bind(mainMod .. " + A", function()
-- 	hl.plugin.scrolloverview.overview("toggle")
-- end)

-- ── Performance / Utilitaires ─────────────────────────────────────────────────
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(userScripts .. "/Performance.sh"))

-- Gamescope force quit → fusionné dans SUPER+Q (Keybinds.lua : tue gamescope seulement s'il a le focus)
-- hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd("pkill -9 gamescope"))

-- ── Build / Monitoring ────────────────────────────────────────────────────────
hl.bind(mainMod .. " + F5", hl.dsp.exec_cmd(term .. " --title 'Build Monitor' -e htop"))

hl.bind(mainMod .. " + F6", hl.dsp.exec_cmd("hyprctl dispatch togglespecialworkspace build"))

hl.bind(mainMod .. " + SHIFT + F6", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace special:build"))

hl.bind(mainMod .. " + grave", hl.dsp.exec_cmd("hyprctl dispatch togglespecialworkspace build"))

hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd(scripts .. "/build_layout.sh"))

-- ── Redimensionnement ── retiré : SUPER+CTRL+flèches = déplacer la fenêtre (Keybinds.lua), en double
-- hl.bind(mainMod .. " + CTRL + left", hl.dsp.window.resize({ x = -60, y = 0, relative = true }))
-- hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 60, y = 0, relative = true }))

-- ── Submap : passthru (VM / Gamescope) ───────────────────────────────────────
hl.bind(mainMod .. " + ALT + P", hl.dsp.submap("passthru"))

hl.define_submap("passthru", function()
	-- Toujours actif pour pouvoir sortir
	hl.bind(mainMod .. " + ALT + P", hl.dsp.submap("reset"), { submap_universal = true })
end)
