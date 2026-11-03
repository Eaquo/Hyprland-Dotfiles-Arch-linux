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
-- NOTE : wallust génère #140000 au format #RRGGBB
-- On expose deux versions :
--   c.color0     → "rgb(RRGGBB)"  pour les bordures / couleurs Hyprland
--   c.color0_hex → "#RRGGBB"      pour les plugins qui veulent du hex brut

local function rgba(hex)
    return "rgba(" .. hex:gsub("^#", "") .. "ff)"
end

local hex = {
    color0     = "#140000",
    color1     = "#764220",
    color2     = "#973807",
    color3     = "#665F5F",
    color4     = "#93652A",
    color5     = "#B89236",
    color6     = "#BF9B39",
    color7     = "#F6DE9D",
    color8     = "#AD9B6E",
    color9     = "#9D582A",
    color10    = "#C94A09",
    color11    = "#887F7F",
    color12    = "#C48738",
    color13    = "#F5C249",
    color14    = "#FFCE4C",
    color15    = "#F6DE9D",
    background = "#140000",
    foreground = "#FFEEC0",
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
