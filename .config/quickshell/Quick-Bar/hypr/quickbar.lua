-- ==============================================================================
-- Quick-Bar — raccourcis clavier
-- Généré par Quick-Bar (Réglages › Raccourcis) : ne pas modifier à la main.
-- Chargé par ~/.config/hypr/hyprland.lua : dofile(".../Quick-Bar/hypr/quickbar.lua")
-- ==============================================================================

local qb = "qs -p /home/florian/.config/quickshell/Quick-Bar/shell.qml ipc call "

-- ==============================================================================
-- BrainShell Capture Submap (Disables all normal binds during recording)
-- ==============================================================================
hl.define_submap("BrainShell_clean", function()
    -- Emergency exit in case the shell crashes during capture
    hl.bind("CTRL + ESCAPE", function()
        hl.dispatch(hl.dsp.exec_cmd("notify-send 'BrainShell' 'Emergency Exit: Keybinds re-enabled.'"))
        hl.dispatch(hl.dsp.submap("reset"))
    end, { description = "Emergency return to global submap" })
end)

-- ==============================================================================
-- User Defined Bindings
-- ==============================================================================

-- Panneaux
hl.bind("SUPER + F1", hl.dsp.exec_cmd(qb .. "settings toggle"), { description = "Réglages" })
hl.bind("SUPER + SHIFT + D", hl.dsp.exec_cmd(qb .. "dashboard-home toggle"), { description = "Dashboard" })
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd(qb .. "spotify toggle"), { description = "Panneau Spotify" })
hl.bind("SUPER + A", hl.dsp.exec_cmd(qb .. "overview toggle"), { description = "Vue d'ensemble des espaces" })
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd(qb .. "notifications toggle"), { description = "Centre de notifications" })
hl.bind("SUPER + L", hl.dsp.exec_cmd(qb .. "lock lock"), { description = "Verrouiller" })
hl.bind("CTRL + ALT + L", hl.dsp.exec_cmd(qb .. "lock lock"), { description = "Verrouiller" })
hl.bind("CTRL + ALT + P", hl.dsp.exec_cmd(qb .. "session toggle"), { description = "Session (verrouiller, éteindre…)" })

-- Menus
hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd(qb .. "menu run apps"), { description = "Lanceur d'applications (Super seul)", release = true })
hl.bind("SUPER + SHIFT + G", hl.dsp.exec_cmd(qb .. "menu run game-scripts"), { description = "Scripts de jeux" })
hl.bind("SUPER + H", hl.dsp.exec_cmd(qb .. "menu run keyhints"), { description = "Aide-mémoire des raccourcis" })
hl.bind("ALT + C", hl.dsp.exec_cmd(qb .. "menu run cours"), { description = "Carte du cours de programmation" })
hl.bind("CTRL + B", hl.dsp.exec_cmd(qb .. "menu run bluetooth"), { description = "Bluetooth" })
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd(qb .. "menu run quickedit"), { description = "Éditer une config" })

-- Fenêtres
hl.bind("ALT + Tab", hl.dsp.exec_cmd(qb .. "alttab next"), { description = "Changer de fenêtre" })
hl.bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd(qb .. "alttab prev"), { description = "Changer de fenêtre (retour)" })
hl.bind("ALT + ALT_L", hl.dsp.exec_cmd(qb .. "alttab commit"), { description = "Aller sur la fenêtre (relâcher Alt)", release = true })
hl.bind("SUPER + mouse:276", hl.dsp.exec_cmd(qb .. "minimize minimize"), { description = "Réduire la fenêtre" })
hl.bind("SUPER + mouse_down", hl.dsp.exec_cmd(qb .. "minimize minimize"), { description = "Réduire la fenêtre (molette)" })
hl.bind("SUPER + mouse:275", hl.dsp.exec_cmd(qb .. "minimize restoreLast"), { description = "Ramener la dernière réduite" })
hl.bind("SUPER + mouse_up", hl.dsp.exec_cmd(qb .. "minimize restoreAll"), { description = "Ramener toutes les réduites" })

-- Fond d'écran
hl.bind("SUPER + W", hl.dsp.exec_cmd(qb .. "wallpicker toggle"), { description = "Fond d'écran : carrousel" })
hl.bind("ALT + W", hl.dsp.exec_cmd(qb .. "wallcinema toggle"), { description = "Fond d'écran : Cinéma" })
hl.bind("CTRL + ALT + W", hl.dsp.exec_cmd(qb .. "wallpicker random"), { description = "Fond d'écran au hasard" })

-- Jeu
hl.bind("SUPER + T", hl.dsp.exec_cmd(qb .. "gamebreak toggle"), { description = "Pause tactile en jeu" })

-- Réglages rapides
hl.bind("SUPER + F2", hl.dsp.exec_cmd(qb .. "focus-toggle toggle"), { description = "Mode focus" })
hl.bind("ALT + F9", hl.dsp.exec_cmd(qb .. "screenrec-on toggle"), { description = "Capture vidéo" })
