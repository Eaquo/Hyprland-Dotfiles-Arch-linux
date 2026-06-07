-- ── Courbes de Bézier ─────────────────────────────────────────────────────────
-- Conservées de ta config originale
hl.curve("wind",   { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } }) -- légère élasticité
hl.curve("winIn",  { type = "bezier", points = { {0.1,  1.1}, {0.1, 1.1}  } }) -- overshoot à l'ouverture
hl.curve("winOut", { type = "bezier", points = { {0.3, -0.3}, {0.0, 1.0}  } }) -- sortie rapide avec dip

-- Corrigé : "liner" → "linear" (typo dans ton .conf original)
hl.curve("linear", { type = "bezier", points = { {1.0, 1.0}, {1.0, 1.0}  } })

-- Nouvelles courbes bonus
hl.curve("smooth", { type = "bezier", points = { {0.25, 1.0}, {0.5, 1.0}  } }) -- fade doux sans rebond
hl.curve("snappy", { type = "bezier", points = { {0.15, 0.0}, {0.1, 1.0}  } }) -- rapide et précis pour les layers

-- ── Fenêtres ──────────────────────────────────────────────────────────────────
hl.animation({ leaf = "windows",     enabled = true, speed = 6, bezier = "wind",   style = "slide" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 6, bezier = "winIn",  style = "slide" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 5, bezier = "winOut", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "wind",   style = "slide" })

-- ── Bordures ─────────────────────────────────────────────────────────────────
hl.animation({ leaf = "border",      enabled = true, speed = 1,  bezier = "linear" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 30, bezier = "linear", style = "once" })

-- ── Fade (affiné par sous-animation) ─────────────────────────────────────────
-- global hérite vers tous les enfants si non défini
hl.animation({ leaf = "fade",        enabled = true, speed = 10, bezier = "smooth" })
hl.animation({ leaf = "fadeIn",      enabled = true, speed = 8,  bezier = "smooth" }) -- ouverture plus rapide
hl.animation({ leaf = "fadeOut",     enabled = true, speed = 5,  bezier = "smooth" }) -- fermeture plus douce
hl.animation({ leaf = "fadeDim",     enabled = true, speed = 8,  bezier = "smooth" }) -- dim des fenêtres inactives
hl.animation({ leaf = "fadeLayers",  enabled = true, speed = 6,  bezier = "smooth" }) -- waybar / rofi / swaync

-- ── Layers (waybar, swaync, rofi...) ─────────────────────────────────────────
hl.animation({ leaf = "layers",    enabled = true, speed = 4, bezier = "snappy", style = "slide" })
hl.animation({ leaf = "layersIn",  enabled = true, speed = 4, bezier = "winIn",  style = "slide" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 3, bezier = "winOut", style = "slide" })

-- ── Workspaces ────────────────────────────────────────────────────────────────
hl.animation({ leaf = "workspaces",    enabled = true, speed = 9, bezier = "wind", style = "slidefadevert 20%" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 8, bezier = "winIn" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 7, bezier = "winOut" })

-- ── Special Workspace (scratchpad etc.) ───────────────────────────────────────
hl.animation({ leaf = "specialWorkspace",    enabled = true, speed = 5, bezier = "wind",   style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceIn",  enabled = true, speed = 5, bezier = "winIn",  style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 4, bezier = "winOut", style = "slidevert" })