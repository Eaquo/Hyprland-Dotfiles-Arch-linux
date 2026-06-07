-- Settings - migré vers Lua (Hyprland 0.55)
-- Fichier : ~/.config/hypr/configs lua/Settings.lua

local c = require("wallust.colors")

-- ── Config principale ─────────────────────────────────────────────────────────
hl.config({

    -- ── Dwindle layout ───────────────────────────────────────────────────────
    dwindle = {
        -- pseudotile = true,
        preserve_split         = true,
        special_scale_factor   = 0.8,
        force_split            = 2,
        split_width_multiplier = 1.5,
        use_active_for_splits  = true,
        smart_split            = false,
        precise_mouse_move     = true,
        -- default_split_ratio = 1.0,
    },

    -- ── Général ──────────────────────────────────────────────────────────────
    general = {
        gaps_in          = 4,
        gaps_out         = 8,
        border_size      = 2,
        resize_on_border = true,

        ["col.active_border"] = {
            colors = { c.color0, c.color2, c.color4, c.color6, c.color8 },
            angle  = 90,
        },
        ["col.inactive_border"] = {
            colors = { c.background },
            angle  = 0,
        },

        layout              = "hy3",  -- nécessite le plugin hy3
        -- layout           = "dwindle"
        -- layout           = "master"

        no_focus_fallback       = false,
        extend_border_grab_area = true,
        hover_icon_on_border    = false,
    },

    -- ── Master layout ────────────────────────────────────────────────────────
    master = {
        new_status  = "master",
        new_on_top  = false,
        mfact       = 0.33,
        orientation = "left",
        -- inherit_fullscreen = true,
    },

    -- ── Groups ───────────────────────────────────────────────────────────────
    group = {
        ["col.border_active"] = c.color15,
        groupbar = {
            ["col.active"] = c.color0,
        },
    },

    -- ── Input ────────────────────────────────────────────────────────────────
    input = {
        kb_layout                 = "fr",
        kb_variant                = "azerty",
        kb_model                  = "generic_104",
        kb_options                = "grp:alt_shift_toggle",
        kb_rules                  = "",
        repeat_rate               = 50,
        repeat_delay              = 300,
        numlock_by_default        = true,
        left_handed               = false,
        follow_mouse              = 1,
        mouse_refocus             = false,
        force_no_accel            = true,
        float_switch_override_focus = 2,
        scroll_factor             = 1,
        -- accel_profile          = "flat",
        natural_scroll            = false,
    },

    -- ── Curseur ──────────────────────────────────────────────────────────────
    cursor = {
        no_hardware_cursors      = true,
        enable_hyprcursor        = true,
        warp_on_change_workspace = false,
        no_warps                 = true,
        hide_on_key_press        = false,
        hide_on_touch            = false,
    },

    -- ── Misc ─────────────────────────────────────────────────────────────────
    misc = {
        disable_hyprland_logo        = true,
        disable_splash_rendering     = true,
        always_follow_on_dnd         = true,
        mouse_move_enables_dpms      = false,
        key_press_enables_dpms       = false,
        layers_hog_keyboard_focus    = false,
        vrr                          = 3,
        -- vfr                       = false,
        enable_swallow               = true,
        animate_manual_resizes       = false,
        animate_mouse_windowdragging = false,
        swallow_regex                = "^(kitty)$",
        disable_autoreload           = false,
        focus_on_activate            = true,
        close_special_on_empty       = true,
        allow_session_lock_restore   = true,
        initial_workspace_tracking   = 0,
    },

    -- ── Binds ────────────────────────────────────────────────────────────────
    binds = {
        workspace_back_and_forth = true,
        allow_workspace_cycles   = true,
        pass_mouse_when_bound    = true,
    },

    -- ── XWayland ─────────────────────────────────────────────────────────────
    xwayland = {
        enabled              = true,
        force_zero_scaling   = true,
        use_nearest_neighbor = true,
    },

    -- ── Render ───────────────────────────────────────────────────────────────
    render = {
        -- explicit_sync     = 2,
        -- explicit_sync_kms = 2,
        direct_scanout = false,
    },
})

-- ── Plugin hy3 ───────────────────────────────────────────────────────────────
if hl.plugin.hy3 ~= nil then
    hl.config({
        plugin = {
            hy3 = {
                tabs = {
                    height      = 21,
                    radius      = 8,
                    text_height = 10,
                    padding     = 3,
                    render_text = true,
                    text_center = true,
                
                    colors = {
                        active              = c.color13_hex,
                        active_border       = c.color8_hex,
                        active_text         = c.foreground_hex,
                
                        inactive            = c.background_hex,
                        inactive_border     = c.background_hex,
                        inactive_text       = c.color7_hex,
                
                        focused             = c.color13_hex,
                        focused_border      = c.color14_hex,
                        focused_text        = c.foreground_hex,
                
                        urgent              = c.color1_hex,
                        urgent_border       = c.color9_hex,
                        urgent_text         = c.foreground_hex,
                    },
                },
                autotile = {
                    enable           = true,
                    ephemeral_groups = true,
                    trigger_width    = 1140,
                    trigger_height   = 0,
                },
            }
        }
    })
end

-- ── Plugin dynamic-cursors ────────────────────────────────────────────────────
if hl.plugin["dynamic-cursors"] ~= nil then
    hl.config({
        plugin = {
            ["dynamic-cursors"] = {
                enabled   = true,
                mode      = "none",
                threshold = 1,
            }
        }
    })
end

-- ── Plugin overview ───────────────────────────────────────────────────────────
if hl.plugin.overview ~= nil then
    hl.config({
        plugin = {
            overview = {
                enabled          = true,
                disableBlur      = true,
                panelColor       = c.color4_hex,
                panelBorderColor = c.color12_hex,
                dragAlpha        = 0.8,
                panelHeight      = 200,
                workspaceMargin  = 6,
            }
        }
    })
end
