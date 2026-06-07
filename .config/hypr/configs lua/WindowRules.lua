-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                         DÉFINITION DES TAGS                              ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- ── Browser ───────────────────────────────────────────────────────────────────
hl.window_rule({ match = { class = "([Ff]irefox|org.mozilla.firefox|[Ff]irefox-esr|[Ff]irefox-bin)" }, tag = "+browser" })
hl.window_rule({ match = { class = "([Mm]icrosoft-edge)" },  tag = "+browser" })
hl.window_rule({ match = { class = "(zen-alpha|zen)" },      tag = "+browser" })

-- ── Email ─────────────────────────────────────────────────────────────────────
hl.window_rule({ match = { class = "([Tt]hunderbird|org.gnome.Evolution)" }, tag = "+email" })
hl.window_rule({ match = { class = "(eu.betterbird.Betterbird)" },           tag = "+email" })

-- ── IDEs / Projects ───────────────────────────────────────────────────────────
hl.window_rule({ match = { class = "(codium|codium-url-handler|VSCodium)" },  tag = "+projects" })
hl.window_rule({ match = { class = "(VSCode|code|code-oss|code-url-handler)" }, tag = "+projects" })
hl.window_rule({ match = { class = "(jetbrains-.+)" },                        tag = "+projects" })
hl.window_rule({ match = { class = "(windsurf)" },                            tag = "+projects" })

-- ── Terminal ──────────────────────────────────────────────────────────────────
hl.window_rule({ match = { class = "(Alacritty|kitty|kitty-dropterm|org.wezfurlong.wezterm)" }, tag = "+terminal" })

-- ── Messagerie instantanée ────────────────────────────────────────────────────
hl.window_rule({ match = { class = "([Dd]iscord|[Ww]ebCord|[Vv]esktop)" },              tag = "+im" })
hl.window_rule({ match = { class = "([Ff]erdium)" },                                    tag = "+im" })
hl.window_rule({ match = { class = "([Ww]hatsapp-for-linux)" },                         tag = "+im" })
hl.window_rule({ match = { class = "(ZapZap|com.rtosta.zapzap)" },                      tag = "+im" })
hl.window_rule({ match = { class = "(org.telegram.desktop|io.github.tdesktop_x64.TDesktop)" }, tag = "+im" })
hl.window_rule({ match = { class = "(teams-for-linux)" },                               tag = "+im" })
hl.window_rule({ match = { class = "(im.riot.Riot|Element)" },                          tag = "+im" })

-- ── Gestionnaire de fichiers ──────────────────────────────────────────────────
hl.window_rule({ match = { class = "([Tt]hunar|org.gnome.Nautilus|[Pp]cmanfm-qt)" }, tag = "+file-manager" })
hl.window_rule({ match = { class = "(app.drey.Warp)" },                               tag = "+file-manager" })

-- ── Multimédia ────────────────────────────────────────────────────────────────
hl.window_rule({ match = { class = "([Aa]udacious)" },                                        tag = "+multimedia" })
hl.window_rule({ match = { class = "([Mm]pv|vlc|com.github.iwalton3.jellyfin-media-player)" }, tag = "+multimedia_video" })

-- ── Paramètres / Outils système ───────────────────────────────────────────────
hl.window_rule({ match = { class = "(wihotspot(-gui)?)" },                            tag = "+settings" })
hl.window_rule({ match = { class = "([Bb]aobab|org.gnome.[Bb]aobab)" },              tag = "+settings" })
hl.window_rule({ match = { class = "(gnome-disks)" },                                tag = "+settings" })
hl.window_rule({ match = { title = "(Kvantum Manager)" },                            tag = "+settings" })
hl.window_rule({ match = { class = "(file-roller|org.gnome.FileRoller|org.kde.ark)" }, tag = "+settings" })
hl.window_rule({ match = { class = "(nm-applet|nm-connection-editor|blueman-manager)" }, tag = "+settings" })
hl.window_rule({ match = { class = "(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)" }, tag = "+settings" })
hl.window_rule({ match = { class = "(qt5ct|qt6ct|[Yy]ad)" },                         tag = "+settings" })
hl.window_rule({ match = { class = "(xdg-desktop-portal-gtk)" },                     tag = "+settings" })
hl.window_rule({ match = { class = "(org.kde.polkit-kde-authentication-agent-1)" },  tag = "+settings" })
hl.window_rule({ match = { class = "([Rr]ofi)" },                                    tag = "+settings" })

-- ── Visionneuses ─────────────────────────────────────────────────────────────
hl.window_rule({ match = { class = "(gnome-system-monitor|org.gnome.SystemMonitor|io.missioncenter.MissionCenter)" }, tag = "+viewer" })
hl.window_rule({ match = { class = "(evince)" },      tag = "+viewer" })
hl.window_rule({ match = { class = "(eog|org.gnome.Loupe)" }, tag = "+viewer" })

-- ── Divers ────────────────────────────────────────────────────────────────────
hl.window_rule({ match = { class = "(com.obsproject.Studio)" },                       tag = "+screenshare" })
hl.window_rule({ match = { class = "([Ww]aytrogen)" },                               tag = "+wallpaper" })
hl.window_rule({ match = { class = "(swaync-control-center|swaync-notification-window|swaync-client)" }, tag = "+notif" })

-- ── KooL ─────────────────────────────────────────────────────────────────────
hl.window_rule({ match = { title = "^(KooL Quick Cheat Sheet)$" },   tag = "+KooL_Cheat" })
hl.window_rule({ match = { title = "^(KooL Hyprland Settings)$" },   tag = "+KooL_Settings" })
hl.window_rule({ match = { class = "(nwg-displays|nwg-look)" },       tag = "+KooL-Settings" })


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                    ASSIGNATION DES WORKSPACES                            ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

hl.window_rule({ name = "email-workspace",   match = { tag = "email" },                      workspace = "1" })
hl.window_rule({ name = "wezterm-workspace", match = { class = "org.wezfurlong.wezterm" },   workspace = "2" })
hl.window_rule({ name = "projects-workspace",match = { tag = "projects" },                   workspace = "3" })
hl.window_rule({ name = "nvim-workspace",    match = { title = ".*nvim.*" },                 workspace = "3" })
hl.window_rule({ name = "obs-workspace",     match = { class = "com.obsproject.Studio" },    workspace = "4" })
hl.window_rule({ name = "virt-workspace",    match = { class = "virt-manager" },             workspace = "6 silent" })
hl.window_rule({ name = "im-workspace",      match = { tag = "im" },                         workspace = "7 silent" })

-- Fix XWayland video bridge (fenêtre invisible nécessaire pour le partage d'écran)
hl.window_rule({
    name             = "xwayland-video-bridge-fixes",
    match            = { class = "xwaylandvideobridge" },
    no_initial_focus = true,
    no_focus         = true,
    no_anim          = true,
    no_blur          = true,
    max_size         = {1, 1},
    opacity          = "0.0",
})


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                         RÈGLES DE FLOTTEMENT                             ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- ── Float par tags ────────────────────────────────────────────────────────────
hl.window_rule({ match = { tag = "KooL_Cheat" },   float = true })
hl.window_rule({ match = { tag = "wallpaper" },    float = true })
hl.window_rule({ match = { tag = "settings" },     float = true, center = true })
hl.window_rule({ match = { tag = "viewer" },       float = true })
hl.window_rule({ match = { tag = "KooL-Settings"}, float = true })

-- ── Float apps spécifiques ────────────────────────────────────────────────────
hl.window_rule({ match = { class = "([Zz]oom|onedriver|onedriver-launcher)" }, float = true })
hl.window_rule({ match = { class = "([Qq]alculate-gtk)" }, float = true })
hl.window_rule({ match = { class = "([Ff]erdium)" },       float = true })
hl.window_rule({ match = { class = "(mpv|com.github.rafostar.Clapper)" }, float = true })

-- ── Float Calculator ──────────────────────────────────────────────────────────
hl.window_rule({
    name   = "calculator",
    match  = { class = "org.gnome.Calculator", title = "Calculator" },
    float  = true,
    center = true,
    persistent_size = true,
})

-- ── Float YouTube PiP ─────────────────────────────────────────────────────────
hl.window_rule({
    name  = "youtube-pip",
    match = { title = "Incrustation vidéo" },
    float = true,
    size  = {1100, 665},
    move  = {10, 765},
})

-- ── Float popups Thunar ───────────────────────────────────────────────────────
hl.window_rule({
    name   = "thunar-popups",
    match  = { class = "[Tt]hunar", title = "negative:.*[Tt]hunar.*" },
    float  = true,
    center = true,
    size   = {"monitor_w*0.2", "monitor_h*0.1"},
})

-- ── Float dialogs VSCode / Codium / Windsurf ──────────────────────────────────

hl.window_rule({
    name   = "ide-dialogs",
    match  = {
        class = "(codium|codium-url-handler|VSCodium|windsurf|VSCode|code-url-handler)",
        title = "negative:(.*codium.*|.*VSCodium.*|.*windsurf.*|.*Visual Studio Code.*)",
    },
    float  = false,
})

-- ── Float dialogs Heroic Games Launcher ───────────────────────────────────────

hl.window_rule({
    name   = "heroic-dialogs",
    match  = {
        class = "com.heroicgameslauncher.hgl",
        title = "negative:Heroic Games Launcher",
    },
    float  = true,
    center = true,
})

-- ── Dialogs génériques ────────────────────────────────────────────────────────
hl.window_rule({
    name   = "auth-dialog",
    match  = { title = "^(Authentication Required)$" },
    float  = true,
    center = true,
})

hl.window_rule({
    name   = "save-dialog",
    match  = { title = "^(Save As|Enregistrer sous)$" },
    float  = true,
    center = true,
    size   = {"monitor_w*0.4", "monitor_h*0.3"},
})

hl.window_rule({
    name   = "add-folder-dialog",
    match  = { title = "^(Add Folder to Workspace|Ajouter un dossier)$" },
    float  = true,
    center = true,
    size   = {"monitor_w*0.4", "monitor_h*0.3"},
})

hl.window_rule({
    name   = "open-files-dialog",
    match  = { initial_title = "(Open Files|Ouvrir des fichiers)" },
    float  = true,
    center = true,
    size   = {"monitor_w*0.7", "monitor_h*0.5"},
})

hl.window_rule({
    name   = "sddm-background",
    match  = { title = "^(SDDM Background)$" },
    float  = true,
    center = true,
    size   = {"monitor_w*0.16", "monitor_h*0.12"},
})

hl.window_rule({
    name   = "yad-wallpaper",
    match  = { class = "^(yad)$", title = "^(YAD)$" },
    float  = true,
    center = true,
    size   = {"monitor_w*0.2", "monitor_h*0.2"},
})

hl.window_rule({
    name        = "file-operations",
    match       = { title = "^(Open|Choose Files|Confirm to replace files|File Operation Progress|Rename|Delete|Supprimer|Renommer)$" },
    float       = true,
    center      = true,
    workspace   = "current",
    stay_focused = true,
    size        = {"monitor_w*0.40", "monitor_h*0.50"},
    opacity     = "0.97 0.97",
})


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                          RÈGLES DE POSITION                              ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

hl.window_rule({ match = { tag = "KooL_Cheat" },   center = true })
hl.window_rule({ match = { tag = "KooL-Settings"}, center = true })
hl.window_rule({ match = { title = "^(Keybindings)$" }, center = true })
hl.window_rule({ match = { class = "(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)" }, center = true })
hl.window_rule({ match = { class = "([Ww]hatsapp-for-linux|ZapZap|com.rtosta.zapzap)" }, center = true })
hl.window_rule({ match = { class = "([Ff]erdium)" }, center = true })


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                           RÈGLES D'OPACITÉ                               ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

hl.window_rule({ match = { tag = "browser" },      opacity = "0.99 0.8" })
hl.window_rule({ match = { tag = "projects" },     opacity = "0.9 0.8" })
hl.window_rule({ match = { tag = "im" },           opacity = "0.94 0.86" })
hl.window_rule({ match = { tag = "multimedia" },   opacity = "0.94 0.86" })
hl.window_rule({ match = { tag = "file-manager" }, opacity = "0.9 0.8" })
hl.window_rule({ match = { tag = "terminal" },     opacity = "0.9 0.7" })
hl.window_rule({ match = { tag = "settings" },     opacity = "0.8 0.7" })
hl.window_rule({ match = { tag = "viewer" },       opacity = "0.82 0.75" })
hl.window_rule({ match = { tag = "wallpaper" },    opacity = "0.9 0.7" })

hl.window_rule({ match = { class = "(gedit|org.gnome.TextEditor|mousepad)" }, opacity = "0.8 0.7" })
hl.window_rule({ match = { class = "(deluge)" },   opacity = "0.9 0.8" })
hl.window_rule({ match = { class = "(seahorse)" }, opacity = "0.9 0.8" })

-- Vidéo : opacité pleine + pas de blur (override pour ne pas multiplier)
hl.window_rule({ match = { tag = "multimedia_video" }, no_blur = true, opacity = "1.0 override 1.0 override" })


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                            RÈGLES DE TAILLE                              ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

hl.window_rule({ match = { tag = "KooL_Cheat" },  size = {"monitor_w*0.65", "monitor_h*0.9"} })
hl.window_rule({ match = { tag = "wallpaper" },   size = {"monitor_w*0.7",  "monitor_h*0.7"} })
hl.window_rule({ match = { tag = "settings" },    size = {"monitor_w*0.4",  "monitor_h*0.5"} })
hl.window_rule({ match = { class = "([Ww]hatsapp-for-linux|ZapZap|com.rtosta.zapzap)" }, size = {"monitor_w*0.6", "monitor_h*0.7"} })
hl.window_rule({ match = { class = "([Ff]erdium)" }, size = {"monitor_w*0.6", "monitor_h*0.7"} })


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                         RÈGLES SPÉCIALES                                 ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- Pas d'idle en plein écran
hl.window_rule({ match = { fullscreen = true }, idle_inhibit = "fullscreen" })

-- Pas de focus initial pour IntelliJ et Windsurf au démarrage
hl.window_rule({ match = { class = "jetbrains-.+" },  no_initial_focus = true })
hl.window_rule({ match = { title = "^(wind.*)$" },    no_initial_focus = true })

-- Fix XWayland drag (fenêtres sans classe ni titre, flottantes, non fullscreen, non épinglées)
hl.window_rule({
    name     = "xwayland-drag-fix",
    match    = { class = "^$", title = "^$", float = true, fullscreen = false, pin = false },
    no_focus = true,
})


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                    APPLICATIONS SPÉCIALISÉES                             ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- Picture-in-Picture
hl.window_rule({
    name  = "picture-in-picture",
    match = { title = "^(Picture-in-Picture)$" },
    pin   = true,
    float = true,
    persistent_size = true,
})


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                          RÈGLES DE CALQUES                               ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

hl.layer_rule({ match = { namespace = "rofi" },                       blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "notifications" },              blur = true })
hl.layer_rule({ match = { namespace = "quickshell:overview" },        blur = true, ignore_alpha = 0.5 })
hl.layer_rule({ match = { namespace = "quickshell:quickshell-game" }, blur = true, ignore_alpha = 0.5 })