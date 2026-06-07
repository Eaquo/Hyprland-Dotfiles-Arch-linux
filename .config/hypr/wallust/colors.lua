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
-- NOTE : wallust génère #4A4150 au format #RRGGBB
-- On expose deux versions :
--   c.color0     → "rgb(RRGGBB)"  pour les bordures / couleurs Hyprland
--   c.color0_hex → "#RRGGBB"      pour les plugins qui veulent du hex brut

local function rgba(hex)
    return "rgba(" .. hex:gsub("^#", "") .. "ff)"
end

local hex = {
    color0     = "#4A4150",
    color1     = "#290C46",
    color2     = "#4B376D",
    color3     = "#8E0D3C",
    color4     = "#67598D",
    color5     = "#8A83B4",
    color6     = "#918CBC",
    color7     = "#D8D4F4",
    color8     = "#9794AB",
    color9     = "#36105D",
    color10    = "#644992",
    color11    = "#BD1150",
    color12    = "#8976BB",
    color13    = "#B8AFF0",
    color14    = "#C1BAFA",
    color15    = "#D8D4F4",
    background = "#231B28",
    foreground = "#E9E7FD",
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
