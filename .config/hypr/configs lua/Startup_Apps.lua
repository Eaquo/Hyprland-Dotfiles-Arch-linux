-- ── Chemins ───────────────────────────────────────────────────────────────────
local home = os.getenv("HOME")
local scripts = home .. "/.config/hypr/scripts"
local userScripts = home .. "/.config/hypr/UserScripts"
local wallDir = home .. "/Pictures/wallpapers"

-- ── Curseur ───────────────────────────────────────────────────────────────────
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- ── Démarrage ─────────────────────────────────────────────────────────────────
hl.on("hyprland.start", function()
	-- DBus / Session
	hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
	hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

	-- Polkit
	hl.exec_cmd(scripts .. "/Polkit.sh")

	-- Wallpaper
	--    hl.exec_cmd("awww query || awww-daemon")
	-- hl.exec_cmd(userScripts .. "/WallpaperRandom.sh " .. wallDir)

	-- OpenRGB : lancé par le service systemd utilisateur openrgb.service (un seul serveur ; deux
	-- instances se disputaient le matériel). Ne pas le relancer ici.
	-- hl.exec_cmd("openrgb --server --startminimized")
	-- Démon RGB : reprend la séquence enregistrée (conf/sequence.txt) ; Quick-Bar
	-- (onglet RGB) ne fait ensuite que changer de mode. `ensure` = jamais en double.
	hl.exec_cmd("bash -c 'sleep 12 && " .. home .. "/.config/quickshell/Quick-Bar/scripts/rgb/rgb_watch.sh ensure'")

	-- Bar / Notifications
	-- MALLOC_MMAP_THRESHOLD_ : les gros tampons (décodage des wallpapers 5K…) sont
	-- rendus au système une fois libérés au lieu de rester dans le tas (~80 Mo).
	-- (lanceur unique de Quick-Bar : fixe aussi QML_IMPORT_PATH pour le terminal du TouchPanel)
	hl.exec_cmd(home .. "/.config/quickshell/Quick-Bar/scripts/launch.sh")
	-- swaync remplacé par le démon de notifications de Quick-Bar (services/NotificationService.qml)
	-- hl.exec_cmd("swaync")

	-- Système
	hl.exec_cmd("nm-applet --indicator")
	hl.exec_cmd("wl-paste --type text  --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")

	-- Effets visuels
	hl.exec_cmd(userScripts .. "/RainbowBorders.sh")
	hl.exec_cmd("easyeffects")
	hl.exec_cmd("vader5d -c " .. home .. "/.config/vader5/config.toml")

	-- Idle / Lock
	hl.exec_cmd("hypridle")

	-- Démons
	hl.exec_cmd("pypr")

	-- Plugin hy3
	-- hy3 buildé manuellement (tag hl0.55.0 = compatible 0.55.4 ; hyprpm prenait master cassé).
	-- À rebuild après chaque update Hyprland : ~/.config/hypr/scripts/rebuild-hy3.sh
	hl.exec_cmd("hyprctl plugin load " .. home .. "/.config/hypr/plugins/libhy3.so")

	-- Steam Colors
	hl.exec_cmd(home .. "/.config/hypr/scripts/WallustSteam.sh")

	-- Corsair display default
	-- hl.exec_cmd("bash -c 'sleep 5 && hyprctl dispatch workspace 8'")
	hl.exec_cmd("[workspace special:magic silent] spotify")
	hl.exec_cmd("[workspace special:magic silent] discord")
end)

-- ── Optionnel : actions à l'extinction ───────────────────────────────────────
-- hl.on("hyprland.shutdown", function()
--     hl.exec_cmd("killall waybar")
-- end)
