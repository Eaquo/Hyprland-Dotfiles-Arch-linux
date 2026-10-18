-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                         DÉFINITION DES TAGS GAMING                       ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

hl.window_rule({ match = { class = "^(gamescope)$" }, tag = "+games" })
hl.window_rule({ match = { class = "^(steam_app_\\d+)$" }, tag = "+games" })
hl.window_rule({ match = { class = "^(.*.exe*)$" }, tag = "+games" })
-- Logiciels Wine qui ne sont pas des jeux : on leur retire le tag (Quick-Bar les ignore aussi, [game] exclude)
hl.window_rule({ match = { class = "^(fusion360\\.exe|.*[Aa]utodesk.*|7zFM\\.exe|winecfg\\.exe|explorer\\.exe|notepad\\.exe|regedit\\.exe)$" }, tag = "-games" })
hl.window_rule({ match = { title = "^([Ll]utris)$" }, tag = "+gamestore" })
hl.window_rule({ match = { class = "^(com.heroicgameslauncher.hgl)$" }, tag = "+gamestore" })

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                            STEAM                                          ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- Fenêtre principale Steam
hl.window_rule({
	name = "steam-main",
	match = { class = "^([Ss]team)$", title = "^(Steam)$" },
	workspace = "9 silent",
	tag = "+gamestore",
	float = false,
})

-- Login + tous les popups Steam
hl.window_rule({
	name = "steam-popups",
	match = { class = "^([Ss]team)$", title = "negative:^(Steam)$" },
	workspace = "9 silent",
	tag = "+gamestore",
	float = true,
	center = true,
	size = { "monitor_w*0.3", "monitor_h*0.4" },
})

hl.on("window.open", function(w)
	if w.class:match("^[Ss]team$") then
		local current = hl.get_active_window()
		hl.exec_cmd("hyprctl dispatch movetoworkspacesilent 9,address:" .. w.address)
		if current then
			hl.exec_cmd("hyprctl dispatch focuswindow address:" .. current.address)
		end
	end
end)

-- Jeux Steam
hl.window_rule({
	name = "steam-games",
	match = { class = "^(steam_proton|steam_app_).*" },
	workspace = "1",
	content = "game",
	center = true,
	immediate = true,
	no_blur = true,
	idle_inhibit = "focus",
	confine_pointer = true,
})

hl.window_rule({
	name = "Fusion",
	match = { class = "fusion360.exe" },
	workspace = "1",
})
-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                         LAUNCHERS                                         ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

hl.window_rule({
	name = "heroic-launcher",
	match = { class = "^(com.heroicgameslauncher.hgl)$" },
	workspace = "9 silent",
	tile = true,
	center = true,
})

hl.window_rule({
	name = "lutris-launcher",
	match = { title = "^([Ll]utris)$" },
	workspace = "9 silent",
	tile = true,
})

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                            GAMESCOPE                                      ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

hl.window_rule({
	name = "gamescope",
	match = { class = "^(gamescope)$" },
	workspace = "1",
	content = "game",
	center = true,
	immediate = true,
	no_blur = true,
	idle_inhibit = "focus",
	confine_pointer = true,
})

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                         JEUX SPÉCIFIQUES                                 ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- Magic: The Gathering Arena
hl.window_rule({
	name = "mtga-steam",
	match = { title = "^(MTGA).*" },
	workspace = "1",
	content = "game",
	center = true,
	maximize = true,
	no_blur = true,
	idle_inhibit = "focus",
	immediate = true,
	confine_pointer = true,
})

-- Dofus (ultrawide 3440x1440)
hl.window_rule({
	name = "dofus",
	match = { class = "^(Dofus.x64)$" },
	workspace = "1",
	float = true,
	immediate = true,
	center = false,
	size = { 3438, 1390 },
	move = { 1, 43 },
	no_blur = true,
	idle_inhibit = "focus",
})

-- Jeux Wine / Proton (.exe)
hl.window_rule({
	name = "wine-games",
	match = { title = ".*\\.exe" },
	workspace = "1",
	content = "game",
	center = true,
	no_blur = true,
	idle_inhibit = "focus",
	immediate = true,
	confine_pointer = true,
})

-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                       RÈGLES GÉNÉRALES GAMING                            ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

hl.window_rule({ match = { tag = "gamestore" }, opacity = "0.95 0.9" })
