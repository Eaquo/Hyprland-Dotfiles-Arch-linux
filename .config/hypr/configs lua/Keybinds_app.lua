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
-- Rofi via Super seul (release)
hl.bind(
	mainMod .. " + SUPER_L",
	hl.dsp.exec_cmd("pkill rofi || rofi -show drun -modi drun,filebrowser,run,window"),
	{ release = true }
)

-- Rofi via Super+D
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("pkill rofi || rofi -show drun -modi drun,filebrowser,run,window"))

-- Claude.ai
hl.bind("ALT + C", hl.dsp.exec_cmd("claude-desktop"))

-- ── Apps ──────────────────────────────────────────────────────────────────────
-- Terminal
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(term))

-- Pypr toggles
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd("pypr toggle term"))
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("pypr toggle clock"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("pypr reload && pypr toggle spot"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("pypr toggle ranger"))

-- ── Vues / Overview ───────────────────────────────────────────────────────────
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd(home .. "/.config/eww/dashboard/launch_dashboard"))

hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(scripts .. "/OverviewToggle.sh"), { description = "desktop overview" })

-- ── Performance / Utilitaires ─────────────────────────────────────────────────
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(userScripts .. "/Performance.sh"))

-- Gamescope force quit
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd("pkill -9 gamescope"))

-- ── Build / Monitoring ────────────────────────────────────────────────────────
hl.bind(mainMod .. " + F5", hl.dsp.exec_cmd(term .. " --title 'Build Monitor' -e htop"))

hl.bind(mainMod .. " + F6", hl.dsp.exec_cmd("hyprctl dispatch togglespecialworkspace build"))

hl.bind(mainMod .. " + SHIFT + F6", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace special:build"))

hl.bind(mainMod .. " + grave", hl.dsp.exec_cmd("hyprctl dispatch togglespecialworkspace build"))

hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd(scripts .. "/build_layout.sh"))

-- ── Redimensionnement ─────────────────────────────────────────────────────────
hl.bind(mainMod .. " + CTRL + left", hl.dsp.window.resize({ x = -60, y = 0, relative = true }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 60, y = 0, relative = true }))

-- ── Submap : passthru (VM / Gamescope) ───────────────────────────────────────
hl.bind(mainMod .. " + ALT + P", hl.dsp.submap("passthru"))

hl.define_submap("passthru", function()
	-- Toujours actif pour pouvoir sortir
	hl.bind(mainMod .. " + ALT + P", hl.dsp.submap("reset"), { submap_universal = true })
end)

