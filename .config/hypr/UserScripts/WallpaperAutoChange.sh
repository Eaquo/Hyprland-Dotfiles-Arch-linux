#!/bin/bash
# Script for Auto-changing Wallpaper with notifications
wallDIR="${1:-$HOME/Pictures/wallpapers}"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
INTERVAL="${2:-1800}"
SCRIPT_NAME="$(basename "$0")"
PID_FILE="/tmp/wallpaper_autochange.pid"
NOTIFY_ICON="$HOME/.config/swaync/icons/ja.png"
SWWW_PARAMS="--transition-fps $FPS --transition-type $TYPE --transition-duration $DURATION --resize fit"

# Kill any existing instances
if [[ -f "$PID_FILE" ]]; then
    old_pid=$(cat "$PID_FILE")
    if ps -p "$old_pid" > /dev/null 2>&1; then
        kill "$old_pid" 2>/dev/null
    fi
fi

pgrep WallpaperSel > /dev/null && pkill WallpaperSel
echo $$ > "$PID_FILE"

cleanup() {
    notify-send -i "$NOTIFY_ICON" "Wallpaper Autochange" "Stopped"
    rm -f "$PID_FILE" "$WALLPAPER_LIST"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Validate directory
[[ ! -d "$wallDIR" ]] && notify-send "Error" "Directory not found: $wallDIR" && exit 1

# Check if gslapper is active
should_run_swww() {
    pgrep -x "gslapper" > /dev/null && return 1
    return 0
}

# Ensure swww-daemon
ensure_swww() {
    if ! pgrep -x "awww-daemon" > /dev/null; then
        awww-daemon --format xrgb &
        sleep 0.5
    fi
}

# Build wallpaper list (cached)
WALLPAPER_LIST="/tmp/wallpaper_list_$$.txt"
find -L "$wallDIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) > "$WALLPAPER_LIST"

if [[ ! -s "$WALLPAPER_LIST" ]]; then
    notify-send "Error" "No wallpapers found in $wallDIR"
    exit 1
fi

WALLPAPER_COUNT=$(wc -l < "$WALLPAPER_LIST")
notify-send -i "$NOTIFY_ICON" "Wallpaper Autochange" "Started with $WALLPAPER_COUNT wallpapers\nInterval: ${INTERVAL}s"

# Apply wallpaper
apply_wallpaper() {
    local img="$1"
    local monitor="$2"
    local img_name="$(basename "$img")"


    export SWWW_TRANSITION_FPS=60
    export SWWW_TRANSITION_TYPE=simple
    
    awww img -o "$monitor" "$img"&

    # Notify with wallpaper name
    notify-send -i "$img" "Wallpaper Changed" "$img_name" -t 3000
    
    sleep 0.5
    "$SCRIPTSDIR/WallustSwww.sh" &
    sleep 1
    "$SCRIPTSDIR/Refresh.sh" &
}

# Main loop
while true; do
    focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
    
    shuf "$WALLPAPER_LIST" | while IFS= read -r img; do
        if ! should_run_swww; then
            sleep "$INTERVAL"
            continue
        fi
        
        ensure_swww
        apply_wallpaper "$img" "$focused_monitor"
        sleep "$INTERVAL"
    done
done
