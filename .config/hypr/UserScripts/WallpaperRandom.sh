#!/bin/bash
# Script for Random Wallpaper (CTRL ALT W) - Version avec cache
wallDIR="$HOME/Pictures/wallpapers"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
CACHE_FILE="/tmp/wallpaper_cache.txt"

# Get focused monitor
focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')

# Kill swaybg if running
pidof swaybg > /dev/null && pkill swaybg

# Si gslapper tourne, on le tue
if pgrep -x "gslapper" > /dev/null; then
    pkill -x gslapper
    pkill -x awww-daemon 2>/dev/null
    sleep 0.3
fi

# Generate cache if doesn't exist or if wallDIR was modified
if [[ ! -f "$CACHE_FILE" ]] || [[ "$wallDIR" -nt "$CACHE_FILE" ]]; then
    find -L "$wallDIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) > "$CACHE_FILE"
fi

# Read from cache
mapfile -t PICS < "$CACHE_FILE"

# Check if wallpapers exist
if [[ ${#PICS[@]} -eq 0 ]]; then
    notify-send "Random Wallpaper" "No wallpapers found in $wallDIR"
    exit 1
fi

# Select random wallpaper
RANDOMPICS="${PICS[$RANDOM % ${#PICS[@]}]}"

# Transition config
FPS=30
TYPE="random"
DURATION=1
BEZIER=".43,1.19,1,.4"
SWWW_PARAMS="--transition-fps $FPS --transition-type $TYPE --transition-duration $DURATION --transition-bezier $BEZIER"

# Ensure swww-daemon is running
if ! pgrep -x "awww-daemon" > /dev/null; then
    awww-daemon --format xrgb &
    sleep 0.5
fi

# Apply wallpaper
awww img -o "$focused_monitor" "$RANDOMPICS" $SWWW_PARAMS &

# Run color scheme and refresh in background
sleep 0.5
"$SCRIPTSDIR/WallustSwww.sh" &
sleep 0.5
"$SCRIPTSDIR/Refresh.sh" &
