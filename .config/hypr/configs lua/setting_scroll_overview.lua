-- Garde : si le plugin scrolloverview n'est pas chargé (build cassé après un
-- upgrade Hyprland), on saute le submap au lieu de faire planter tout le fichier.
if hl.plugin["scrolloverview"] ~= nil then
hl.define_submap("scrolloverview", function()
hl.bind("left",   hl.plugin.scrolloverview.navigate("left"))
hl.bind("right",  hl.plugin.scrolloverview.navigate("right"))
hl.bind("up",     hl.plugin.scrolloverview.navigate("up"))
hl.bind("down",   hl.plugin.scrolloverview.navigate("down"))
hl.bind("return", hl.plugin.scrolloverview.overview("select"))
hl.bind("escape", hl.plugin.scrolloverview.overview("off"))
hl.bind("mouse:275", function()
-- Select the clicked window, or just the workspace if no window was clicked, then close the overview. This is the default behaviour if submap is not defined.
hl.plugin.scrolloverview.overview("select")
hl.plugin.scrolloverview.window("select")
hl.plugin.scrolloverview.overview("off")
end, { mouse = true })
hl.bind("mouse:274", hl.plugin.scrolloverview.window("close"), { mouse = true })
end)
end

-- Example Hyprland bind that keeps working inside the submap:
local mainMod = "ALT"

for i = 1, 10 do
    local keycode = 9 + i
    hl.bind(mainMod .. " + code:" .. keycode, hl.dsp.focus({ workspace = i }), { submap_universal = true })
end
