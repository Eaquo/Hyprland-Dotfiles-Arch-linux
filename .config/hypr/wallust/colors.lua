-- Template wallust pour générer les couleurs en Lua
-- Emplacement du TEMPLATE : ~/.config/wallust/templates/hyprland-colors.lua
-- Emplacement de la SORTIE  : ~/.config/hypr/wallust/colors.lua
--
-- Dans ~/.config/wallust/wallust.toml, ajouter :
--
-- [templates.hyprland-colors]
-- template = "templates/hyprland-colors.lua"
-- target   = "~/.config/hypr/wallust/colors.lua"
--
-- NOTE : wallust génère #393A3A au format #RRGGBB
-- On expose deux versions :
--   c.color0     → "rgb(RRGGBB)"  pour les bordures / couleurs Hyprland
--   c.color0_hex → "#RRGGBB"      pour les plugins qui veulent du hex brut

local function rgba(hex)
    return "rgba(" .. hex:gsub("^#", "") .. "ff)"
end

local hex = {
    color0     = "#393A3A",
    color1     = "#0A0D0E",
    color2     = "#0B0E0E",
    color3     = "#363D3C",
    color4     = "#5E5247",
    color5     = "#535E5C",
    color6     = "#867464",
    color7     = "#D0C5BA",
    color8     = "#928A82",
    color9     = "#0E1213",
    color10    = "#0E1213",
    color11    = "#485150",
    color12    = "#7E6D5F",
    color13    = "#6E7E7B",
    color14    = "#B29B86",
    color15    = "#D0C5BA",
    background = "#111112",
    foreground = "#E4DCD5",
}

return {
    -- Format rgb() pour Hyprland (bordures, couleurs config)
    color0     = rgba(hex.color0),
    color1     = rgba(hex.color1),
    color2     = rgba(hex.color2),
    color3     = rgba(hex.color3),
    color4     = rgba(hex.color4),
    color5     = rgba(hex.color5),
    color6     = rgba(hex.color6),
    color7     = rgba(hex.color7),
    color8     = rgba(hex.color8),
    color9     = rgba(hex.color9),
    color10    = rgba(hex.color10),
    color11    = rgba(hex.color11),
    color12    = rgba(hex.color12),
    color13    = rgba(hex.color13),
    color14    = rgba(hex.color14),
    color15    = rgba(hex.color15),
    background = rgba(hex.background),
    foreground = rgba(hex.foreground),

    -- Format hex brut pour plugins (hy3, etc.)
    color0_hex     = hex.color0,
    color1_hex     = hex.color1,
    color2_hex     = hex.color2,
    color3_hex     = hex.color3,
    color4_hex     = hex.color4,
    color5_hex     = hex.color5,
    color6_hex     = hex.color6,
    color7_hex     = hex.color7,
    color8_hex     = hex.color8,
    color9_hex     = hex.color9,
    color10_hex    = hex.color10,
    color11_hex    = hex.color11,
    color12_hex    = hex.color12,
    color13_hex    = hex.color13,
    color14_hex    = hex.color14,
    color15_hex    = hex.color15,
    background_hex = hex.background,
    foreground_hex = hex.foreground,
}
