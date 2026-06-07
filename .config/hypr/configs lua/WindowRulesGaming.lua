-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                         DÉFINITION DES TAGS GAMING                       ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

hl.window_rule({ match = { class = "^(gamescope)$" },      tag = "+games" })
hl.window_rule({ match = { class = "^(steam_app_\\d+)$" }, tag = "+games" })
hl.window_rule({ match = { class = "^(.*.exe*)$" },        tag = "+games" })

hl.window_rule({ match = { class = "^([Ss]team)$" },                  tag = "+gamestore" })
hl.window_rule({ match = { title = "^([Ll]utris)$" },                  tag = "+gamestore" })
hl.window_rule({ match = { class = "^(com.heroicgameslauncher.hgl)$" }, tag = "+gamestore" })


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                            STEAM                                          ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- Fenêtre principale Steam → workspace 9 (launcher)
hl.window_rule({
    name      = "steam-main",
    match     = { class = "^([Ss]team)$" },
    workspace = "9 silent",
})

-- Dialogues et popups Steam (Library, About...)
hl.window_rule({
    name   = "steam-float-windows",
    match  = { class = "^([Ss]team)$", title = "^(L.*|Para.*|A.*)" },
    float  = true,
    center = true,
    size   = {"monitor_w*0.3", "monitor_h*0.4"},
})

-- Dialogues et popups Steam (Lancement)
hl.window_rule({
    name   = "steam-float-windows",
    match  = { class = "^([Ss]team)$", title = "^(L.*)" },
    float  = true,
    center = true,
    size   = {"monitor_w*0.2", "monitor_h*0.2"},
})

-- Jeux Steam (steam_app_* et steam_proton)
hl.window_rule({
    name            = "steam-games",
    match           = { class = "^(steam_proton|steam_app_).*" },
    workspace       = "1",
    content         = "game",
    center          = true,
    immediate       = true,
    no_blur         = true,
    idle_inhibit    = "focus",
    confine_pointer = true,
})


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                         LAUNCHERS                                         ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

hl.window_rule({
    name      = "heroic-launcher",
    match     = { class = "^(com.heroicgameslauncher.hgl)$" },
    workspace = "9 silent",
    tile      = true,
})

hl.window_rule({
    name      = "lutris-launcher",
    match     = { title = "^([Ll]utris)$" },
    workspace = "9 silent",
    tile      = true,
})


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                            GAMESCOPE                                      ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

hl.window_rule({
    name            = "gamescope",
    match           = { class = "^(gamescope)$" },
    workspace       = "1",
    content         = "game",
    center          = true,
    immediate       = true,
    no_blur         = true,
    idle_inhibit    = "focus",
    confine_pointer = true,
})


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                         JEUX SPÉCIFIQUES                                 ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- Magic: The Gathering Arena
hl.window_rule({
    name            = "mtga-steam",
    match           = { title = "^(MTGA).*" },
    workspace       = "1",
    content         = "game",
    center          = true,
    maximize        = true,
    no_blur         = true,
    idle_inhibit    = "focus",
    immediate       = true,
    confine_pointer = true,
})

-- Dofus (ultrawide 3440x1440 — taille quasi-plein écran avec marges)
hl.window_rule({
    name         = "dofus",
    match        = { class = "^(Dofus.x64)$" },
    workspace    = "1",
    float        = true,
    immediate    = true,
    center       = false,
    size         = {3438, 1390},
    move         = {1, 43},
    no_blur      = true,
    idle_inhibit = "focus",
})

-- Jeux Wine / Proton (.exe)
hl.window_rule({
    name            = "wine-games",
    match           = { title = ".*\\.exe" },
    workspace       = "1",
    content         = "game",
    center          = true,
    no_blur         = true,
    idle_inhibit    = "focus",
    immediate       = true,
    confine_pointer = true,
})


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                       RÈGLES GÉNÉRALES GAMING                            ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- Opacité légèrement réduite pour les launchers inactifs
hl.window_rule({ match = { tag = "gamestore" }, opacity = "0.95 0.9" })