-- ── Chemins ───────────────────────────────────────────────────────────────────
local home        = os.getenv("HOME")
local scripts     = home .. "/.config/hypr/scripts"
local userScripts = home .. "/.config/hypr/UserScripts"
local wallDir     = home .. "/Pictures/wallpapers"

-- ── Curseur ───────────────────────────────────────────────────────────────────
hl.env("XCURSOR_SIZE",    "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- ── Démarrage ─────────────────────────────────────────────────────────────────
hl.on("hyprland.start", function()

    -- DBus / Session
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

    -- Polkit
    hl.exec_cmd(scripts .. "/Polkit.sh")

    -- Wallpaper
    hl.exec_cmd("awww query || awww-daemon")
    hl.exec_cmd(userScripts .. "/WallpaperRandom.sh " .. wallDir)

    -- OpenRGB
    hl.exec_cmd("openrgb --server --startminimized")
    hl.exec_cmd("bash -c 'sleep 12 && python " .. home .. "/.config/quickshell/rgb-launcher/modules/script/OpenRGB_Controller_Watch.py'")

    -- Bar / Notifications
    hl.exec_cmd("quickshell -p " .. home .. "/.config/quickshell/Quick-Bar/shell.qml")
    hl.exec_cmd("swaync")

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
    hl.exec_cmd("hyprpm reload -n")

    -- Spicetify
    hl.exec_cmd("spicetify apply")

    -- Steam Colors
    hl.exec_cmd(home .. "/.config/hypr/scripts/WallustSteam.sh")

end)

-- ── Optionnel : actions à l'extinction ───────────────────────────────────────
-- hl.on("hyprland.shutdown", function()
--     hl.exec_cmd("killall waybar")
-- end)