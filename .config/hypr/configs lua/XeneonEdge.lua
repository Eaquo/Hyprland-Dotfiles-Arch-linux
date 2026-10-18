-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                     CORSAIR XENEON EDGE 14.5"                            ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

local XENEON_OUTPUT = "desc:Cyrix Corporation XENEON EDGE 190025435656"

-- ── Moniteur ─────────────────────────────────────────────────────────────────
hl.monitor({
	output   = XENEON_OUTPUT,
	mode     = "2560x720@60",
	position = "440x1440",
	scale    = 1,
	bitdepth = 8,
	cm       = "srgb",
	vrr      = 0,   -- touch 60 Hz : VRR forcé OFF (n'hérite pas du misc:vrr=3 en 0.56+)
})

-- ── Workspace 10 dédié ───────────────────────────────────────────────────────
hl.workspace_rule({
	workspace = "10",
	monitor   = "DP-2",
	default   = true,
	persistent = true,
})

-- ── Touch ────────────────────────────────────────────────────────────────────
hl.device({
	name    = "wch.cn-touchscreen-1",
	output = "DP-2",
	enabled = true,  -- désactive le pointeur souris du touch
})

hl.device({
	name    = "wch.cn-touchscreen",
	enabled = true,
	output = "DP-2",
	region_position = { 440, 1440 },
	region_size     = { 2560, 720 },
})

-- ── Pause tactile pendant un jeu ─────────────────────────────────────────────
-- Les règles de WindowRulesGaming.lua posent `confine_pointer = true` : tant que
-- le jeu a le focus, le pointeur est confiné dans sa fenêtre et le tactile du
-- Xeneon ne clique plus. SUPER+T bascule une « pause jeu » (service GameBreak du
-- shell Quick-Bar) : le focus part sur DP-2 (ce qui relâche la contrainte), une
-- pastille tactile s'affiche en bas du Xeneon, et le focus revient au jeu PAR
-- ADRESSE au bout de 20 s ou au clic sur « Revenir au jeu » — sans changement de
-- workspace, donc le jeu ne bouge pas.
-- → déplacé dans Quick-Bar/hypr/quickbar.lua (Réglages › Raccourcis de Quick-Bar)
-- hl.bind("SUPER + T", hl.dsp.exec_cmd(
-- 	"qs -p " .. os.getenv("HOME") .. "/.config/quickshell/Quick-Bar/shell.qml ipc call gamebreak toggle"
-- ))

-- ── DP-2 : workspace 10 exclusivement ───────────────────────────────────────
hl.on("workspace.active", function(ws)
	if not ws.monitor then
		return
	end

	if ws.monitor.name == "DP-2" and tostring(ws.id) ~= "10" then
		hl.dispatch(
			hl.dsp.focus({
				workspace = 10,
				monitor = "DP-2",
			})
		)
	end
end)

-- ── Gestes Hyprgrass ─────────────────────────────────────────────────────────
-- Garde : sans ce test, un plugin non chargé (ABI cassée après upgrade Hyprland)
-- fait planter le fichier ICI et tout ce qui suit (window rules + hooks Jellyfin)
-- n'est jamais appliqué.
if hl.plugin["hyprgrass"] ~= nil then
	-- 2 doigts droite/gauche = changer workspace
	hl.plugin.hyprgrass.bind({
		pattern = { kind = "swipe", fingers = 2, direction = "r" },
		action  = hl.dsp.focus({ workspace = "e+1" }),
	})

	hl.plugin.hyprgrass.bind({
		pattern = { kind = "swipe", fingers = 2, direction = "l" },
		action  = hl.dsp.focus({ workspace = "e-1" }),
	})

	-- 3 doigts bas = envoyer fenêtre au scratchpad
	hl.plugin.hyprgrass.bind({
		pattern = { kind = "swipe", fingers = 3, direction = "d" },
		action  = hl.dsp.window.move({ workspace = "special:magic" }),
	})
end

-- ── Window Rules ─────────────────────────────────────────────────────────────
-- Spotify
hl.window_rule({
	match     = { class = "^(Spotify|spotify)$" },
			   workspace = "8 silent",
})

-- Discord
hl.window_rule({
	match     = { class = "^(discord)$" },
			   workspace = "8 silent",
})


-- Jellyfin → éteint le Xeneon
-- NB : pas d'auto-HDR ici. Jellyfin Media Player rend via l'API libmpv embarquée
-- (vo="libmpv", contexte GL) : mpv ne possède pas la surface Wayland et ne peut
-- donc pas signaler le HDR au compositeur — il tone-mappe en SDR en interne.
-- Basculer DP-1 en HDR pour JMP dégraderait l'image au lieu de l'améliorer.
-- Pour du vrai HDR : mpv standalone (vo=gpu-next) + scripts/HdrToggle.sh.

hl.on("window.open", function(w)
if w.class == "org.jellyfin.JellyfinDesktop" then
	hl.timer(function()
	hl.dispatch(hl.dsp.dpms({ action = "disable", monitor = "DP-2" }))
	end, { timeout = 500, type = "oneshot" })
	end
	end)

hl.on("window.close", function(w)
if w.class == "org.jellyfin.JellyfinDesktop" then
	hl.timer(function()
	hl.dispatch(hl.dsp.dpms({ action = "enable", monitor = "DP-2" }))
	end, { timeout = 500, type = "oneshot" })
	end
	end)

