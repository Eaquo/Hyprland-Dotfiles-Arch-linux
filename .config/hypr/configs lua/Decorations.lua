local c = require("wallust.colors")
 
hl.config({
 
    -- ── Général (bordures / gaps) ─────────────────────────────────────────────
    general = {
        border_size              = 2,
        gaps_in                  = 4,
        gaps_out                 = 8,
        ["col.active_border"] = {
            colors = { c.color0, c.color2, c.color4, c.color6, c.color8 },
            angle  = 90,
        },

        ["col.inactive_border"] = {
            colors = { c.color5 },
            angle  = 0,
        },
    },
 
    -- ── Décoration ────────────────────────────────────────────────────────────
    decoration = {
        rounding           = 10,
        active_opacity     = 1.0,
        inactive_opacity   = 0.9,
        fullscreen_opacity  = 1.0,
        dim_inactive       = true,
        dim_strength       = 0.1,
        dim_special        = 0.8,
 
        shadow = {
            enabled        = true,
            range          = 3,
            render_power   = 1,
            color          = c.color12,
            color_inactive = c.color10,
        },
 
        blur = {
            enabled             = true,
            size                = 6,
            passes              = 2,
            ignore_opacity      = true,
            new_optimizations   = true,
            special             = true,
            popups              = true,
        },
    },
 
    -- ── Groupes ───────────────────────────────────────────────────────────────
    group = {
        ["col.border_active"] = c.color15,
        groupbar = {
            ["col.active"] = c.color0,
        },
    },
 
})
