#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */
# KooL Quick Cheat Sheet - Personnalisé avec keybinds Florian

BACKEND=wayland

if pidof rofi > /dev/null; then pkill rofi; fi
if pidof yad > /dev/null; then pkill yad; fi

GDK_BACKEND=$BACKEND yad \
--center \
--title="KooL Quick Cheat Sheet" \
--no-buttons \
--list \
--column=Key: \
--column=Description: \
--column=Command: \
--timeout-indicator=bottom \
"ESC"                   "Fermer cette fenêtre"                  "" \
" = "                   "SUPER KEY (Touche Windows)"            "(SUPER KEY)" \
""                      ""                                      "" \
"━━━ SYSTÈME ━━━"       ""                                      "" \
"CTRL ALT Del"          "Quitter Hyprland"                      "(immédiat)" \
"CTRL ALT L"            "Verrouiller l'écran"                   "(hyprlock)" \
"CTRL ALT P"            "Menu d'extinction"                     "(wlogout)" \
" L"                    "Verrouiller l'écran"                   "(LockScreen.sh)" \
"PAUSE"                 "Freeze toutes les fenêtres"            "(wl-freeze)" \
""                      ""                                      "" \
"━━━ APPLICATIONS ━━━"  ""                                      "" \
" Return"               "Terminal"                              "(kitty)" \
" SHIFT Return"         "Terminal dropdown"                     "(pypr toggle term)" \
" Z"                    "Gestionnaire de fichiers"              "(thunar)" \
" B"                    "Navigateur"                            "(zen-browser)" \
" E"                    "Éditeur de code"                       "(windsurf)" \
" N"                    "Terminal alternatif"                   "(wezterm)" \
" J"                    "Lecteur média"                         "(jellyfin)" \
" S"                    "Steam"                                 "(wayland)" \
" C"                    "Moniteur système"                      "(btop)" \
" M"                    "Mixeur audio"                          "(control)" \
" D"                    "Discord"                               "" \
" ALT M"                "Guitare"                               "(ToneLib-Metal)" \
" SHIFT M"              "Manga reader"                          "(kitty)" \
"ALT C"                 "Claude.ai"                             "(claude-desktop)" \
""                      ""                                      "" \
"━━━ LANCEURS ━━━"      ""                                      "" \
" SUPER_L"              "Lanceur d'apps"                        "(rofi - release)" \
" D"                    "Lanceur d'apps"                        "(rofi)" \
" G  ou  F9"            "Game launcher"                         "(quickshell)" \
" O"                    "RGB Controller"                        "(quickshell)" \
"CTRL B"                "Bluetooth"                             "(rofi-bluetooth)" \
""                      ""                                      "" \
"━━━ PYPR TOGGLES ━━━"  ""                                      "" \
" SHIFT C"              "Horloge"                               "(pypr toggle clock)" \
" SHIFT S"              "Spotify"                               "(pypr toggle spot)" \
" SHIFT R"              "Ranger"                                "(pypr toggle ranger)" \
""                      ""                                      "" \
"━━━ FENÊTRES ━━━"      ""                                      "" \
" Q"                    "Fermer la fenêtre active"              "(close)" \
" SHIFT Q"              "Tuer la fenêtre active"                "(kill)" \
" F"                    "Plein écran"                           "(fullscreen)" \
" SHIFT F"              "Flottant toggle"                       "(fenêtre active)" \
" ALT F"                "Tout flottant toggle"                  "(workspace entier)" \
" P"                    "Pseudo-tile"                           "(dwindle)" \
" I"                    "Toggle split H/V"                      "(dwindle)" \
"ALT Tab"               "Cycle fenêtres"                        "(prev)" \
"CTRL Tab"              "Toggle all float"                      "(workspace)" \
""                      ""                                      "" \
"━━━ FOCUS ━━━"         ""                                      "" \
" ←↑↓→"                 "Déplacer le focus"                     "" \
" CTRL ←↑↓→"            "Déplacer la fenêtre"                   "" \
" CTRL ←→"              "Redimensionner H"                      "(-/+ 60px)" \
" mouse:272"            "Déplacer fenêtre (drag)"               "" \
" mouse:273"            "Redimensionner (drag)"                 "" \
" mouse:276"            "Minimiser"                             "(niflveil)" \
" mouse:275"            "Restaurer dernière"                    "(niflveil)" \
" mouse_up"             "Restaurer toutes"                      "(niflveil)" \
" mouse_down"           "Minimiser"                             "(niflveil)" \
""                      ""                                      "" \
"━━━ WORKSPACES ━━━"    ""                                      "" \
" Tab"                  "Workspace suivant"                     "" \
" SHIFT Tab"            "Workspace précédent"                   "" \
" period"               "Workspace existant suivant"            "" \
" comma"                "Workspace existant précédent"          "" \
" &éàçè..."             "Workspace 1-10"                        "(AZERTY)" \
" SHIFT &éàçè..."       "Envoyer vers workspace 1-10"           "(AZERTY)" \
" SHIFT []"             "Envoyer vers ±1"                       "(brackets)" \
" CTRL []"              "Envoyer silencieux ±1"                 "(brackets)" \
" U"                    "Toggle special workspace"              "" \
" SHIFT U"              "Envoyer vers special"                  "" \
" F6"                   "Toggle special:build"                  "" \
" grave"                "Toggle special:build"                  "(alt)" \
" SHIFT F6"             "Envoyer vers special:build"            "" \
""                      ""                                      "" \
"━━━ LAYOUT ━━━"        ""                                      "" \
" ALT L"                "Changer layout"                        "(ChangeLayout.sh)" \
" L"                    "Master layout"                         "(hyprctl keyword)" \
" SHIFT L"              "Dwindle layout"                        "(hyprctl keyword)" \
" M"                    "Swap with master"                      "" \
" CTRL D"               "Remove master"                         "" \
" CTRL Return"          "Swap with master"                      "" \
" F1/F2/F3"             "Split ratio 0.3/0.5/0.7"              "" \
"CTRL F1"               "Split ratio -0.3"                      "" \
""                      ""                                      "" \
"━━━ WALLPAPER ━━━"     ""                                      "" \
" W"                    "Choisir wallpaper"                     "(WallpaperSelect)" \
"ALT W"                 "Quickshell wallpaper"                  "(hyprquickpaper)" \
"CTRL ALT W"            "Wallpaper aléatoire"                   "(swww)" \
""                      ""                                      "" \
"━━━ MÉDIAS ━━━"        ""                                      "" \
"XF86AudioRaiseVolume"  "Volume +"                              "(repeating)" \
"XF86AudioLowerVolume"  "Volume -"                              "(repeating)" \
"XF86AudioMute"         "Mute"                                  "" \
"XF86AudioMicMute"      "Mute micro"                            "" \
" Y"                    "Mute micro"                            "" \
"XF86AudioPlay/Pause"   "Play / Pause"                          "" \
"XF86AudioNext/Prev"    "Suivant / Précédent"                   "" \
""                      ""                                      "" \
"━━━ SCREENSHOTS ━━━"   ""                                      "" \
" F12"                  "Screenshot immédiat"                   "(grim)" \
" SHIFT F12"            "Screenshot zone"                       "(grim+slurp)" \
" CTRL F12"             "Screenshot dans 5s"                    "" \
" ALT F12"              "Screenshot dans 10s"                   "" \
"ALT F12"               "Screenshot fenêtre active"             "" \
""                      ""                                      "" \
"━━━ EXTRAS ━━━"        ""                                      "" \
" H"                    "Cette cheat sheet"                     "" \
" SHIFT E"              "Éditer configs"                        "(QuickEdit)" \
" SHIFT G"              "Éditer script game"                    "(EditScriptGame)" \
" ALT R"                "Reload waybar/swaync/rofi"             "" \
" ALT E"                "Emojis"                                "(rofi)" \
" SHIFT Z"              "Recherche Google"                      "(rofi)" \
" SHIFT B"              "Toggle blur"                           "" \
" ALT V"                "Clipboard manager"                     "(cliphist)" \
" SHIFT N"              "Panel notifications"                   "(swaync)" \
" SHIFT P"              "Performance"                           "" \
" F5"                   "Build monitor"                         "(htop)" \
" SHIFT V"              "Build layout"                          "" \
" T"                    "Réorganiser moniteur"                  "" \
" SHIFT T"              "Toggle layout custom"                  "" \
" ALT P"                "Passthru (VM/Gamescope)"               "(submap)" \
"CTRL ALT L"            "Lock immédiat"                         "(hyprlock)" \
""                      ""                                      "" \