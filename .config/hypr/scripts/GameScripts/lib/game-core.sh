#!/bin/bash
# =============================================================================
#  game-core.sh — Moteur partagé pour lancer des jeux via Hyprland + AMD
#
#  Usage dans un script de jeu :
#     #!/bin/bash
#     GAME_PERF="True"
#     FSR="False"
#     ...
#     source "$(dirname "$(readlink -f "$0")")/lib/game-core.sh"
#     run_game "$@"
#
#  Les variables définies AVANT le source ont la priorité (voir : "${X:=...}").
# =============================================================================

# ----- État interne (pour le cleanup) ----------------------------------------
_SPLIT_LOCK_TOUCHED="False"
_VRR_TOUCHED="False"
GAME_WINDOW_CLASS=""

# ----- Game mode Hyprland : coupe anims, wallpaper et barre ------------------
enable_hyprland_gamemode() {
  [ "$ANIMATION" = "True" ] || return 0
  hyprctl eval 'hl.config({
    general    = { no_focus_fallback = true, gaps_in = 0, gaps_out = 0, border_size = 1 },
    misc       = { focus_on_activate = false, layers_hog_keyboard_focus = false },
    animations = { enabled = false },
    decoration = { rounding = 0, shadow = { enabled = false }, blur = { enabled = false } },
  })'
  hyprctl eval 'hl.window_rule({ match = { class = ".*" }, opacity = "1 override 1 override 1 override" })'
  # Coupe le wallpaper (awww) et la barre (quickshell) pendant le jeu
  awww kill 2>/dev/null
 # pkill -x quickshell 2>/dev/null
}

# hyprctl reload remet toute la config Lua : options, VRR, règles ajoutées par eval.
disable_hyprland_gamemode() {
  hyprctl reload
  [ "$ANIMATION" = "True" ] || return 0
  # Relance le wallpaper
  if ! pgrep -x awww >/dev/null; then
    awww-daemon &
    sleep 1
    awww img "$WALLPAPER_IMG"
  fi
  # Relance la barre quickshell (setsid -f : survit à la sortie du script)
  if ! pgrep -x quickshell >/dev/null; then
    sleep 1.5
    setsid -f quickshell -p /home/florian/.config/quickshell/Quick-Bar/shell.qml >/dev/null 2>&1
  fi
}

# ----- Cleanup : appelé sur sortie normale ET Ctrl-C / crash (trap) ----------
_cleanup() {
  # Évite la double exécution
  trap - EXIT INT TERM

  # Hook optionnel de sortie (ex: sauvegarde de profil) défini par le script de jeu
  declare -F game_on_exit >/dev/null && game_on_exit

  [ "$_VRR_TOUCHED" = "True" ] && notify-send -e -u normal " Disabling VRR Hyprland"

  if [ "$_SPLIT_LOCK_TOUCHED" = "True" ]; then
    echo "Réactivation du split lock mitigate..."
    sudo sysctl kernel.split_lock_mitigate=1
  fi

  disable_hyprland_gamemode
}

# ----- Point d'entrée --------------------------------------------------------
run_game() {
  # --- Valeurs par défaut (n'écrasent pas ce que le script de jeu a défini) ---
  : "${GAMESCOPE_OPTIONS:=False}"
  : "${GAME_PERF:=True}"
  : "${GAME_VRR:=False}"
  : "${ANIMATION:=True}"
  : "${MANGOHUD_OPTION:=True}"
  : "${FSR:=False}"
  : "${HDR:=False}"
  : "${X11:=False}"
  : "${WAYLAND_NATIVE:=False}"   # Proton Wayland natif — exclusif avec X11
  : "${SPLIT_LOCK:=False}"
  : "${CPU_CCD:=False}"
  : "${UE4SS:=False}"
  : "${LANG_KEY:=fr}"
  : "${OPTION_AFTER:=}"

  # Écran / résolution
  : "${REFRESH_RATE:=165}"
  : "${RES_WIDTH:=3440}"
  : "${RES_HEIGHT:=1440}"
  : "${FSR_SHARPNESS:=3}"

  # Wallpaper / barre
  : "${WALLPAPER_IMG:=$HOME/.config/rofi/.current_wallpaper}"
  : "${QUICKSHELL_CMD:=quickshell -p /home/florian/.config/quickshell/Quick-Bar/shell.qml}"

  # CPU : 1 seul CCD pour éviter la latence inter-CCD.
  # Ryzen 5900X → CCD0 = cœurs 0-5 + leurs SMT 12-17. (Pas de V-cache sur ce CPU.)
  : "${CPU_CORES:=0-5,12-17}"

  # Détection de la fenêtre du jeu
  : "${DETECT_TIMEOUT:=10}"     # secondes max d'attente de la fenêtre
  : "${GAME_CLASS_MATCH:=}"     # regex de classe (fallback si le PID ne suffit pas, ex: MTGA)

  local SCRIPT_NAME
  SCRIPT_NAME=$(basename "$0")

  # ------------------------- ENVIRONNEMENT (AMD) ----------------------------
  # Valeurs par défaut, surchargeables depuis le script de jeu (export VAR=...).
  # Note : '-' (et non ':-') → une valeur explicitement vide est respectée (= désactivé).
  # RADV_PERFTEST : plus de valeur forcée (gpl et ngg sont actifs par défaut dans Mesa récent) ;
  # un script de jeu peut toujours l'exporter lui-même.
  export VKD3D_CONFIG="${VKD3D_CONFIG-pipeline_library}"  # cache pipelines DX12 (vkd3d-proton)
  MANGOHUD=$([ "$MANGOHUD_OPTION" = "True" ] && echo 1 || echo 0)
  export MANGOHUD
  # Quick-Bar : avec MangoHud, un journal continu (FPS, temps de trame) pour la page Game du tactile.
  # Copie de ta config + 4 lignes, dans /tmp (RAM) : MangoHud.conf et tes enregistrements manuels ne changent pas.
  if [ "$MANGOHUD" = 1 ]; then
    mkdir -p /tmp/qb-mangohud
    find /tmp/qb-mangohud -name '*.csv' -mmin +360 -delete 2>/dev/null
    { cat "$HOME/.config/MangoHud/MangoHud.conf" 2>/dev/null
      printf 'autostart_log=1\nlog_interval=500\nlog_duration=0\noutput_folder=/tmp/qb-mangohud\n'; } > /tmp/qb-mangohud/MangoHud.conf
    export MANGOHUD_CONFIGFILE=/tmp/qb-mangohud/MangoHud.conf
  fi
  [ "$HDR" = "True" ] && export DXVK_HDR=1

  # UE4SS : override dwmapi pour que Proton charge le bootstrap UE4SS.
  # N'écrase pas un WINEDLLOVERRIDES déjà défini par le script de jeu (ex: dinput8).
  if [ "$UE4SS" = "True" ]; then
    if [ -n "$WINEDLLOVERRIDES" ]; then
      export WINEDLLOVERRIDES="${WINEDLLOVERRIDES},dwmapi=n,b"
    else
      export WINEDLLOVERRIDES="dwmapi=n,b"
    fi
  fi

  # Affichage : X11 (XWayland) et Wayland natif sont mutuellement exclusifs.
  if [ "$X11" = "True" ]; then
    unset WAYLAND_DISPLAY
    export GDK_BACKEND=x11
    export QT_QPA_PLATFORM=xcb
  elif [ "$WAYLAND_NATIVE" = "True" ]; then
    export PROTON_ENABLE_WAYLAND=1
  else
    unset PROTON_ENABLE_WAYLAND   # hérité de Steam/Hyprland sinon : XWayland par défaut
  fi

  # Décommente au besoin (opt-in) :
  # export PROTON_ENABLE_NVAPI=1
  # export PROTON_USE_NTSYNC=1
  # export mesa_glthread=true

  # ------------------------- CONSTRUCTION COMMANDE --------------------------
  # PROTON_ENABLE_WAYLAND n'est plus forcé ici : seulement avec WAYLAND_NATIVE="True" (voir plus haut)
  local -a LAUNCH=(env SDL_VIDEO_DRIVER=wayland)

  if [ "$CPU_CCD" = "True" ]; then
    LAUNCH+=(taskset -c "$CPU_CORES")
  fi
  if [ "$GAME_PERF" = "True" ]; then
    LAUNCH+=(game-performance)
  fi
  if [ "$GAMESCOPE_OPTIONS" = "True" ]; then
    export XKB_DEFAULT_LAYOUT=$LANG_KEY
    LAUNCH+=(gamescope)
    [ "${GAMESCOPE_FULLSCREEN:-True}" = "True" ] && LAUNCH+=(-f)   # False = fenêtre tilable
    LAUNCH+=(-W "$RES_WIDTH" -H "$RES_HEIGHT" -r "$REFRESH_RATE"
             -w "${GAME_WIDTH:-$RES_WIDTH}" -h "${GAME_HEIGHT:-$RES_HEIGHT}")   # GAME_* : résolution vue par le jeu (bandes noires si autre format)
    [ "$FSR" = "True" ] && LAUNCH+=(-F fsr --fsr-sharpness "$FSR_SHARPNESS")
    [ "$HDR" = "True" ] && LAUNCH+=(--hdr-enabled)
    LAUNCH+=(--force-grab-cursor --)
  fi

  # ------------------------- SETUP SYSTÈME ----------------------------------
  trap _cleanup EXIT INT TERM

  if [ "$SPLIT_LOCK" = "True" ]; then
    echo "Désactivation du split lock mitigate..."
    sudo sysctl kernel.split_lock_mitigate=0 && _SPLIT_LOCK_TOUCHED="True"
  fi

  if [ "$GAME_VRR" = "True" ]; then
    notify-send -e -u normal " Enabling VRR Hyprland"
    # VRR toujours actif (DP-1 hérite de misc.vrr ; le Xeneon force vrr=0)
    hyprctl eval 'hl.config({ misc = { vrr = 1 } })'
    _VRR_TOUCHED="True"
  fi

  enable_hyprland_gamemode
  notify-send -e -u normal " Launching the game $SCRIPT_NAME"

  # ------------------------- LANCEMENT --------------------------------------
  "${LAUNCH[@]}" "$@" $OPTION_AFTER &
  local GAME_PID=$!

  # Détection de la fenêtre du jeu (retry, avec fallback regex de classe)
  local t
  for ((t = 0; t < DETECT_TIMEOUT; t++)); do
    GAME_WINDOW_CLASS=$(hyprctl clients | grep -A 3 "pid: $GAME_PID" | grep "class:" | awk '{print $2}')
    if [ -z "$GAME_WINDOW_CLASS" ] && [ -n "$GAME_CLASS_MATCH" ]; then
      GAME_WINDOW_CLASS=$(hyprctl clients -j \
        | jq -r --arg re "$GAME_CLASS_MATCH" '.[] | select(.class | test($re)) | .class' 2>/dev/null | head -1)
    fi
    [ -n "$GAME_WINDOW_CLASS" ] && break
    sleep 1
  done

  if [ -z "$GAME_WINDOW_CLASS" ]; then
    echo "Failed to detect game window class."
  else
    # immediate + workspace 1 : gérés par WindowRulesGaming.lua
    # Hook optionnel défini par le script de jeu (tiling, affinité CPU, etc.)
    declare -F game_post_window >/dev/null && game_post_window "$GAME_WINDOW_CLASS"
  fi

  wait $GAME_PID
  local GAME_EXIT_CODE=$?

  # _cleanup s'exécute automatiquement via le trap EXIT
  exit $GAME_EXIT_CODE
}
