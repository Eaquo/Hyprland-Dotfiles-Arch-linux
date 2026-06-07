-- ── Wayland / Backend ─────────────────────────────────────────────────────────
hl.env("CLUTTER_BACKEND",                  "wayland")
hl.env("GDK_BACKEND",                      "wayland,x11")
 
-- ── Qt ───────────────────────────────────────────────────────────────────────
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR",      "1")
hl.env("QT_QPA_PLATFORM",                  "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME",             "qt6ct")
hl.env("QT_SCALE_FACTOR",                  "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
 
-- ── XDG ──────────────────────────────────────────────────────────────────────
hl.env("XDG_CURRENT_DESKTOP",              "Hyprland")
hl.env("XDG_SESSION_DESKTOP",              "Hyprland")
hl.env("XDG_SESSION_TYPE",                 "wayland")
 
-- ── Scale Fix XWayland ────────────────────────────────────────────────────────
hl.env("GDK_SCALE",                        "1")
 
-- ── Firefox ──────────────────────────────────────────────────────────────────
hl.env("MOZ_ENABLE_WAYLAND",               "1")
hl.env("GTK_IM_MODULE",                    "ibus")
hl.env("XKB_DEFAULT_LAYOUT",               "fr")
 
-- ── Electron ─────────────────────────────────────────────────────────────────
hl.env("ELECTRON_OZONE_PLATFORM_HINT",     "auto")
 
-- ── SDL (décommentez si besoin) ───────────────────────────────────────────────
-- hl.env("SDL_VIDEODRIVER", "wayland")
 
-- ── AMD / GPU Optimisations ───────────────────────────────────────────────────
hl.env("MESA_VK_WSI_PRESENT_MODE",         "mailbox")
hl.env("vblank_mode",                      "0")
hl.env("__GL_GSYNC_ALLOWED",               "1")
hl.env("__GL_VRR_ALLOWED",                 "1")
hl.env("PROTON_ENABLE_WAYLAND",            "1")
hl.env("VK_LAYER_PATH",                    "/usr/share/vulkan/explicit_layer.d")
