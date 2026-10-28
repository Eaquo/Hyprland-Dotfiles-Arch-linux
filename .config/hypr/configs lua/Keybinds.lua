-- Keybinds (fichier principal) - migré vers Lua (Hyprland 0.55)
-- Fichier : ~/.config/hypr/keybinds-main.lua
-- Chargé depuis hyprland.lua via : require("keybinds-main")
--
-- ⚠  NOTES DE MIGRATION :
--   - $planning n'est jamais défini dans ce fichier → à déclarer ou supprimer
--   - "bind = $mainMod, M, exec, exec control..." → double "exec" corrigé
--   - "ALT, TAB, cyclenext, prev~/.config/..." → corruption corrigée → cyclenext prev
--   - $monitor est une commande shell → remplacée par hl.exec_cmd() si besoin

-- ── Variables ─────────────────────────────────────────────────────────────────
local mainMod = "SUPER"
local home = os.getenv("HOME")
local scripts = home .. "/.config/hypr/scripts"
local userScripts = home .. "/.config/hypr/UserScripts"

local files = "thunar"
local browser = "zen-browser"
local term = "kitty"
local editor = "windsurf"
local media = "org.jellyfin.JellyfinDesktop"
local game = "env QT_QPA_PLATFORM=wayland steam -silent"
local manga = "manga-reader"
local melanger = "pavucontrol"
local btop = "btop"
local guitare = "ToneLib-Metal"

-- TODO : définir $planning (non défini dans le fichier original)
-- local planning = home .. "/.config/hypr/scripts/planning.py"

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                         SYSTÈME                                           ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

hl.bind("CTRL + ALT + Delete", hl.dsp.exit())
-- verrouillage Quick-Bar (panels/LockScreen.qml, bind généré dans Quick-Bar/hypr/quickbar.lua)
-- hl.bind("CTRL + ALT + L", hl.dsp.exec_cmd("hyprlock -q"))
-- → déplacé dans Quick-Bar/hypr/quickbar.lua (Réglages › Raccourcis de Quick-Bar)
-- hl.bind("CTRL + ALT + P", hl.dsp.exec_cmd(scripts .. "/Wlogout.sh"))
-- verrouillage Quick-Bar (panels/LockScreen.qml, bind généré dans Quick-Bar/hypr/quickbar.lua)
-- hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(scripts .. "/LockScreen.sh"))

-- Fenêtres
-- Fermer la fenêtre active (gamescope : tué, il ne se ferme pas proprement autrement)
hl.bind(mainMod .. " + Q", function()
	local w = hl.get_active_window()
	if w and w.class == "gamescope" then
		hl.exec_cmd("pkill -9 gamescope")
	else
		hl.dispatch(hl.dsp.window.close())
	end
end)
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.window.kill())
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + ALT + F", hl.dsp.exec_cmd("hyprctl dispatch workspaceopt allfloat"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())

hl.bind(mainMod .. " + O", hl.dsp.window.move({ monitor = "+1" }))

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                         APPLICATIONS                                      ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd(files))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(editor))
hl.bind(mainMod .. " + J", hl.dsp.exec_cmd(media))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd(game))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("wezterm"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(term .. " -e " .. btop))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd(term .. " --class manga -e " .. manga))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("discord || (sleep 3s && hyprctl dispatch closewindow class:discord)"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("control -V --single-instance")) -- corrigé : double "exec" supprimé

hl.bind("CTRL + Tab", function()
	local ws = hl.get_active_workspace()
	if ws == nil then
		return
	end

	local windows = ws:get_windows()
	local has_tiled = false
	for _, w in ipairs(windows) do
		if not w.floating then
			has_tiled = true
			break
		end
	end

	for _, w in ipairs(windows) do
		if has_tiled and not w.floating then
			hl.dispatch(hl.dsp.window.float({ window = "address:" .. w.address }))
		elseif not has_tiled and w.floating then
			hl.dispatch(hl.dsp.window.float({ action = "unset", window = "address:" .. w.address }))
		end
	end
end)

-- Launchers
hl.bind("SUPER + G", hl.dsp.exec_cmd(home .. "/.config/quickshell/game-launcher/toggle.sh"))
hl.bind("F9", hl.dsp.exec_cmd(home .. "/.config/quickshell/game-launcher/toggle.sh"))
-- rgb-launcher retiré (plus utilisé) : SUPER+O = envoyer la fenêtre sur l'autre écran
-- hl.bind("SUPER + O", hl.dsp.exec_cmd(home .. "/.config/quickshell/rgb-launcher/toggle.sh"))
-- SUPER+SHIFT+G : scripts de jeux Quick-Bar (menus/scripts/game-scripts.sh, bind généré dans Quick-Bar/hypr/quickbar.lua)
-- hl.bind(mainMod .. " + SHIFT + G", hl.dsp.exec_cmd(userScripts .. "/EditScriptGame.sh"))
-- SUPER+SHIFT+E : éditer une config, menu Quick-Bar (menus/scripts/quickedit.sh, bind généré dans Quick-Bar/hypr/quickbar.lua)
-- hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(userScripts .. "/QuickEdit.sh"))
-- CTRL+B : menu Bluetooth Quick-Bar (menus/scripts/bluetooth.sh, bind généré dans Quick-Bar/hypr/quickbar.lua)
-- hl.bind("CTRL + B", hl.dsp.exec_cmd("rofi-bluetooth"))

-- Master layout
hl.bind(mainMod .. " + I", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + U", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + U", hl.dsp.window.move({ workspace = "special:magic" }))

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                         FEATURES / EXTRAS                                 ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

hl.bind(mainMod .. " + ALT + R", hl.dsp.exec_cmd(scripts .. "/Refresh.sh"))
hl.bind(mainMod .. " + ALT + E", hl.dsp.exec_cmd(scripts .. "/RofiEmoji.sh"))
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.exec_cmd(scripts .. "/RofiSearch.sh"))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd(scripts .. "/ChangeBlur.sh"))
hl.bind(mainMod .. " + ALT + V", hl.dsp.exec_cmd(scripts .. "/ClipManager.sh"))
-- SUPER+SHIFT+N : centre de notifications Quick-Bar (panels/NotifCenter.qml, bind généré dans Quick-Bar/hypr/quickbar.lua)
-- hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("swaync-client -t -sw"))

-- Wallpaper
-- Sélecteurs de Quick-Bar : SUPER+W carrousel, ALT+W « Cinéma », CTRL+ALT+W fond au hasard
-- (anciens : WallpaperSelect.sh, hyprquickpaper, WallpaperRandom.sh)
-- → déplacé dans Quick-Bar/hypr/quickbar.lua (Réglages › Raccourcis de Quick-Bar)
-- hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("qs -p " .. home .. "/.config/quickshell/Quick-Bar/shell.qml ipc call wallpicker toggle"))
-- → déplacé dans Quick-Bar/hypr/quickbar.lua (Réglages › Raccourcis de Quick-Bar)
-- hl.bind("ALT + W", hl.dsp.exec_cmd("qs -p " .. home .. "/.config/quickshell/Quick-Bar/shell.qml ipc call wallcinema toggle"))
-- → déplacé dans Quick-Bar/hypr/quickbar.lua (Réglages › Raccourcis de Quick-Bar)
-- hl.bind("CTRL + ALT + W", hl.dsp.exec_cmd("qs -p " .. home .. "/.config/quickshell/Quick-Bar/shell.qml ipc call wallpicker random"))

-- Cheat sheet → menu Quick-Bar automatique (menus/scripts/keyhints.sh, bind généré dans Quick-Bar/hypr/quickbar.lua)
-- hl.bind(mainMod .. " + H", hl.dsp.exec_cmd(scripts .. "/KeyHints.sh"))

-- Bascule DP-1 SDR <-> HDR (hdredid) — bref écran noir : mode-set colorimétrie
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.exec_cmd(scripts .. "/HdrToggle.sh toggle"))

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                         FOCUS / DÉPLACEMENT                               ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- Focus
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "r" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "u" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "d" }))

-- Cycle fenêtres (corrigé : "cyclenext, prev~/.config/..." → cyclenext prev)
-- ALT+Tab : changeur de fenêtres Quick-Bar (panels/AltTab.qml, binds générés dans Quick-Bar/hypr/quickbar.lua)
-- hl.bind("ALT + Tab", hl.dsp.window.cycle_next({ prev = true }))

-- Déplacer fenêtres
hl.bind(mainMod .. " + CTRL + left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + mouse_down", hl.dsp.window.move({ direction = "l" }), { mouse = true })
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + mouse_up", hl.dsp.window.move({ direction = "r" }), { mouse = true })
hl.bind(mainMod .. " + CTRL + up", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + CTRL + mouse_down", hl.dsp.window.move({ direction = "u" }), { mouse = true })
hl.bind(mainMod .. " + CTRL + down", hl.dsp.window.move({ direction = "d" }))
hl.bind(mainMod .. " + CTRL + mouse_up", hl.dsp.window.move({ direction = "d" }), { mouse = true })

-- Redimensionner (repeating) → retiré : SUPER+flèches = focus (plus haut), en double
-- hl.bind(mainMod .. " + left", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true })
-- hl.bind(mainMod .. " + right", hl.dsp.window.resize({ x = 50, y = 0, relative = true }), { repeating = true })
-- hl.bind(mainMod .. " + up", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true })
-- hl.bind(mainMod .. " + down", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { repeating = true })

-- Souris drag / resize
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Niflveil (minimise / restore) → remplacé par Quick-Bar (services/Minimize.qml, binds générés dans quickbar.lua)
-- hl.bind(mainMod .. " + mouse:276", hl.dsp.exec_cmd("/usr/local/bin/niflveil minimize"))
-- hl.bind(mainMod .. " + mouse:275", hl.dsp.exec_cmd("/usr/local/bin/niflveil restore-last"))
-- hl.bind(mainMod .. " + mouse_up", hl.dsp.exec_cmd("niflveil restore-all"))
-- hl.bind(mainMod .. " + mouse_down", hl.dsp.exec_cmd("niflveil minimize"))

-- Groupes
hl.bind("CTRL + Tab + Escape", hl.dsp.exec_cmd("hyprctl dispatch changegroupactive"))

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                         WORKSPACES                                        ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- Navigation tabs workspaces
hl.bind(mainMod .. " + Tab", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(mainMod .. " + period", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + comma", hl.dsp.focus({ workspace = "e-1" }))

-- ✅ Version AZERTY avec noms de touches
local azerty = {
	"ampersand", -- 1
	"eacute",    -- 2
	"quotedbl",  -- 3
	"apostrophe", -- 4
	"parenleft", -- 5
	"minus",     -- 6
	"egrave",    -- 7
	"underscore", -- 8
	"ccedilla",  -- 9
	"agrave",    -- 10
}

for i, key in ipairs(azerty) do
	-- Switch workspace
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	-- Move to workspace (suit le focus)
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Brackets
hl.bind(mainMod .. " + SHIFT + bracketleft", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace e-1"))
hl.bind(mainMod .. " + SHIFT + bracketright", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace e+1"))
hl.bind(mainMod .. " + CTRL + bracketleft", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspacesilent e-1"))
hl.bind(mainMod .. " + CTRL + bracketright", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspacesilent e+1"))

-- Special workspace : doublon de SUPER+U / SUPER+SHIFT+U (scratchpad « magic », plus haut) — retiré
-- hl.bind(mainMod .. " + U", hl.dsp.exec_cmd("hyprctl dispatch togglespecialworkspace"))
-- hl.bind(mainMod .. " + SHIFT + U", hl.dsp.exec_cmd("hyprctl dispatch movetoworkspace special"))

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                         TOUCHES SPÉCIALES / MÉDIA                         ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- Volume
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(scripts .. "/Volume.sh --inc"), { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(scripts .. "/Volume.sh --dec"), { repeating = true, locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(scripts .. "/Volume.sh --toggle-mic"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(scripts .. "/Volume.sh --toggle"), { locked = true })
hl.bind(mainMod .. " + Y", hl.dsp.exec_cmd(scripts .. "/Volume.sh --toggle-mic"))

hl.bind("XF86AudioPause", hl.dsp.exec_cmd(scripts .. "/MediaCtrl.sh --pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd(scripts .. "/MediaCtrl.sh --pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(scripts .. "/MediaCtrl.sh --nxt"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd(scripts .. "/MediaCtrl.sh --prv"), { locked = true })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd(scripts .. "/MediaCtrl.sh --stop"), { locked = true })

-- Système
hl.bind("XF86Sleep", hl.dsp.exec_cmd("systemctl suspend"))
hl.bind("XF86Rfkill", hl.dsp.exec_cmd(scripts .. "/AirplaneMode.sh"))

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                         SCREENSHOTS                                       ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

hl.bind(mainMod .. " + F12", hl.dsp.exec_cmd(scripts .. "/ScreenShot.sh --now"))
hl.bind(mainMod .. " + SHIFT + F12", hl.dsp.exec_cmd(scripts .. "/ScreenShot.sh --area"))
hl.bind(mainMod .. " + CTRL + F12", hl.dsp.exec_cmd(scripts .. "/ScreenShot.sh --in5"))
hl.bind(mainMod .. " + ALT + F12", hl.dsp.exec_cmd(scripts .. "/ScreenShot.sh --in10"))
hl.bind("ALT + F12", hl.dsp.exec_cmd(scripts .. "/ScreenShot.sh --active"))
