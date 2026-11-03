-- Mode fenêtres (façon Defi) : SUPER+MAJ+A entre dans le submap « fenetres », Quick-Bar affiche le HUD
-- (panels/WindowMode.qml, il suit l'événement submap). Échap / Entrée / SUPER+MAJ+A pour sortir.
--   Tab · MAJ+Tab          fenêtre suivante / précédente
--   & é " ' ( - è _ ç à    aller sur l'espace 1…10
--   MAJ + & é " ' …        envoyer la fenêtre sur l'espace 1…10 (et la suivre)
--   Z Q S D                ajuster la taille (Z/S hauteur, Q/D largeur)
--   MAJ + Z Q S D          déplacer la fenêtre dans la disposition (haut, gauche, bas, droite)
--   X fermer · F flottante · Espace plein écran

local azerty = { "ampersand", "eacute", "quotedbl", "apostrophe", "parenleft",
                 "minus", "egrave", "underscore", "ccedilla", "agrave" }
local step = 60

hl.bind("SUPER + SHIFT + A", hl.dsp.submap("fenetres"))

hl.define_submap("fenetres", function()
	hl.bind("Tab", hl.dsp.window.cycle_next({}))
	hl.bind("SHIFT + Tab", hl.dsp.window.cycle_next({ prev = true }))
	for i, key in ipairs(azerty) do
		hl.bind(key, hl.dsp.focus({ workspace = i }))
		hl.bind("SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
	end
	hl.bind("z", hl.dsp.window.resize({ x = 0, y = -step, relative = true }), { repeating = true })
	hl.bind("s", hl.dsp.window.resize({ x = 0, y = step, relative = true }), { repeating = true })
	hl.bind("q", hl.dsp.window.resize({ x = -step, y = 0, relative = true }), { repeating = true })
	hl.bind("d", hl.dsp.window.resize({ x = step, y = 0, relative = true }), { repeating = true })
	for key, dir in pairs({ z = "u", q = "l", s = "d", d = "r" }) do
		hl.bind("SHIFT + " .. key, hl.dsp.window.move({ direction = dir }))
	end
	hl.bind("x", hl.dsp.window.close())
	hl.bind("f", hl.dsp.window.float({ action = "toggle" }))
	hl.bind("space", hl.dsp.window.fullscreen())
	hl.bind("escape", hl.dsp.submap("reset"))
	hl.bind("Return", hl.dsp.submap("reset"))
	hl.bind("SUPER + SHIFT + A", hl.dsp.submap("reset"))
end)
