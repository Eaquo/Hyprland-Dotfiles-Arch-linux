#!/bin/bash
# wlogout (Power, Screen Lock, Suspend, etc)
# Thème « grille de cartes » wallust, aligné sur la barre Quickshell.
# Fond : vidéo aléatoire via mpvpaper (couche « top », sous l'overlay wlogout).

WLOGOUT_DIR="$HOME/.config/wlogout"
STYLE="$WLOGOUT_DIR/style.css"
LAYOUT="$WLOGOUT_DIR/layout"
WAL="$HOME/.cache/wal/wal.json"
COLORS="$WLOGOUT_DIR/colors-wlogout.css"
VIDEO_DIR="$HOME/Pictures/wallpapers/Video"

# Parameters for screen resolutions
declare -A resolutions=(
    [2160]=450
    [1600]=450
    [1440]=450
    [1080]=350
    [720]=175
)

# Check if wlogout is already running, if so, kill it.
# Fermer wlogout débloque l'instance au premier plan qui nettoie mpvpaper.
if pgrep -x "wlogout" > /dev/null; then
    pkill -x "wlogout"
    exit 0
fi

# Régénère colors-wlogout.css depuis wal.json (même source que la barre Quickshell)
# → wlogout suit toujours le wallpaper courant.
if [[ -f "$WAL" ]]; then
    jq -r '
        "@define-color background \(.special.background);",
        "@define-color foreground \(.special.foreground);",
        "@define-color cursor \(.special.cursor);",
        (.colors | to_entries[] | "@define-color \(.key) \(.value);")
    ' "$WAL" > "$COLORS"
fi

# Detect the current monitor's native resolution, width, name and scale
monitor_info=$(hyprctl -j monitors | jq -r '.[] | select(.focused==true)')

resolution=$(echo "$monitor_info" | jq -r '.height')
width=$(echo "$monitor_info" | jq -r '.width')
monitor_name=$(echo "$monitor_info" | jq -r '.name')
hypr_scale=$(echo "$monitor_info" | jq -r '.scale')

# Round hypr_scale to 2 decimal places for accurate comparison
rounded_scale=$(echo "scale=2; $hypr_scale/1" | bc)

# ── Marges wlogout selon le moniteur ─────────────────────────────────────────
# Base commune : grille 3 colonnes × 2 rangées, thème wallust.
wlogout_args=(--protocol layer-shell -l "$LAYOUT" -C "$STYLE" -b 3 -c 15 -r 15)

# If resolution or scale is invalid or hypr_scale >= 1.25, use fixed margins
if [[ -z "$resolution" || ! "$resolution" =~ ^[0-9]+$ || -z "$hypr_scale" || $(echo "$rounded_scale >= 1.25" | bc) -eq 1 ]]; then
    echo "Hypr_scale >= 1.25 or resolution could not be detected, using fixed margins"
    wlogout_args+=(-T 100 -B 100 -L 250 -R 250)
else
    # Determine the appropriate resolution range
    if   ((resolution >= 2160)); then res_key=2160
    elif ((resolution >= 1600)); then res_key=1600
    elif ((resolution >= 1440)); then res_key=1440
    elif ((resolution >= 1080)); then res_key=1080
    else                              res_key=720
    fi

    # Grille 3×2 → deux rangées : marge verticale divisée par 2 vs la rangée
    # unique d'origine pour garder les cartes centrées sans les écraser.
    T_val=$(awk "BEGIN {printf \"%.0f\", ${resolutions[$res_key]} * $res_key * $hypr_scale / $resolution / 2}")
    B_val=$T_val
    # Marges latérales : compriment la grille vers le centre (cartes carrées).
    L_val=$(awk "BEGIN {printf \"%.0f\", $width * 0.16}")
    R_val=$L_val

    echo "Setting parameters for resolution >= $res_key"
    wlogout_args+=(-T "$T_val" -B "$B_val" -L "$L_val" -R "$R_val")
fi

# ── Fond vidéo aléatoire (mpvpaper) ──────────────────────────────────────────
# Couche « top » : au-dessus des fenêtres mais SOUS l'overlay wlogout, quel que
# soit l'ordre de mapping. La vidéo transparaît via le scrim de style.css.
mpv_pid=""
video="$VIDEO_DIR/cyber-oni.mp4"
if command -v mpvpaper >/dev/null 2>&1 && [[ -f "$video" && -n "$monitor_name" ]]; then
    mpvpaper -l top -o "no-audio loop hwdec=auto panscan=1.0 really-quiet" \
        "$monitor_name" "$video" &
    mpv_pid=$!
fi

# ── wlogout au premier plan, puis nettoyage de la vidéo ─────────────────────
wlogout "${wlogout_args[@]}"
[[ -n "$mpv_pid" ]] && kill "$mpv_pid" 2>/dev/null
