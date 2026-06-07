#!/bin/bash
# Multi-Monitor Workspace Wallpaper Manager (with proper instance protection)

# PID file to prevent multiple instances
PID_FILE="/tmp/hypr/mrk/wallpaper_multiwork.pid"

# Check if another instance is running and kill it
if [[ -f "$PID_FILE" ]]; then
    old_pid=$(cat "$PID_FILE")
    # Only kill if it's not us and if it's still running
    if [[ "$old_pid" != "$$" ]] && ps -p "$old_pid" > /dev/null 2>&1; then
        echo "Killing previous instance (PID: $old_pid)..."
        kill "$old_pid" 2>/dev/null
        sleep 0.5
    fi
fi

pgrep WallpaperSel > /dev/null && pkill WallpaperSel
pgrep WallpaperAut > /dev/null && pkill WallpaperAut
pgrep WallpaperRan > /dev/null && pkill WallpaperRan
pgrep Wallmp4Sel > /dev/null && pkill Wallmp4Sel
pgrep WallpaperEf > /dev/null && pkill WallpaperEf

# Save current PID
echo $$ > "$PID_FILE"

# Monitor configuration
mon_r="HDMI-A-2"
mon_m="DP-2"
mon_l="HDMI-A-1"

config="$HOME/.config/hypr/ipc_config.json"
wallDIR="$HOME/Pictures/wallpapers"
CACHE_FILE="/tmp/hypr/mrk/wallpaper_cache.txt"
SCRIPTSDIR="$HOME/.config/hypr/scripts"

# Animation settings
TRANSITION_TYPE="fade"
TRANSITION_DURATION=1.5
TRANSITION_FPS=60
TRANSITION_ANGLE=45
TRANSITION_BEZIER=".43,1.19,1,.4"

# Create directories
mkdir -p "/tmp/hypr/mrk"

# Cleanup on exit
cleanup() {
    echo "Stopping Multi Workspace manager (PID: $$)..."
    [[ -f "$PID_FILE" ]] && rm -f "$PID_FILE"
    exit 0
}

trap cleanup SIGTERM SIGINT EXIT

# Build wallpaper cache at startup (ONCE)
build_wallpaper_cache() {
    echo "Building wallpaper cache..."
    find -L "$wallDIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) > "$CACHE_FILE"
    
    if [[ ! -s "$CACHE_FILE" ]]; then
        notify-send "Multi Workspace" "No wallpapers found in $wallDIR"
        exit 1
    fi
    
    echo "Cache built: $(wc -l < "$CACHE_FILE") wallpapers"
}

# Rebuild cache if wallpaper directory is newer
if [[ ! -f "$CACHE_FILE" ]] || [[ "$wallDIR" -nt "$CACHE_FILE" ]]; then
    build_wallpaper_cache
fi

# Load wallpapers into array for faster access
mapfile -t WALLPAPERS < "$CACHE_FILE"
WALLPAPER_COUNT=${#WALLPAPERS[@]}

echo "Multi Workspace started (PID: $$) with $WALLPAPER_COUNT wallpapers"

# Check if wallpaper changes are allowed
should_change_wallpaper() {
    # Check config file
    if [[ -f "$config" ]]; then
        local disable_shuffle=$(jq -r '.disable_wallpaper_shuffle // false' "$config")
        [[ "$disable_shuffle" == "true" ]] && return 1
    fi
    
    # Don't change if gslapper is active
    pgrep -x "gslapper" > /dev/null && return 1
    
    return 0
}

# Ensure swww-daemon is running
ensure_swww() {
    if ! pgrep -x "awww-daemon" > /dev/null; then
        awww-daemon --format xrgb &
        sleep 0.3
    fi
}

# Get random wallpaper (from cache)
get_random_wallpaper() {
    echo "${WALLPAPERS[$RANDOM % $WALLPAPER_COUNT]}"
}

# Handle workspace changes
handle_workspace() {
    should_change_wallpaper || return 0
    
    # Parse workspace event: workspacev2>>ID,NAME
    local workspace_data="${1#*>>}"
    local workspace_id="${workspace_data%%,*}"
    
    # Validate it's a number
    [[ ! "$workspace_id" =~ ^[0-9]+$ ]] && return 0
    
    # Get monitor for this workspace
    local monitor=$(hyprctl workspaces -j | jq -r --argjson id "$workspace_id" \
        '.[] | select(.id == $id) | .monitor')
    
    [[ -z "$monitor" ]] && return 0
    
    ensure_swww
    
    # Get random wallpaper from cache
    local wallpaper=$(get_random_wallpaper)
    
    # Apply wallpaper with smooth animation
    awww img \
        --resize crop \
        --transition-type "$TRANSITION_TYPE" \
        --transition-duration "$TRANSITION_DURATION" \
        --transition-fps "$TRANSITION_FPS" \
        --transition-angle "$TRANSITION_ANGLE" \
        --transition-bezier "$TRANSITION_BEZIER" \
        --outputs "$monitor" \
        "$wallpaper" &
}

# Handle workspace creation
handle_workspaces() {
    local workspace_data="${1#*>>}"
    local ws="${workspace_data%%,*}"
    
    [[ ! "$ws" =~ ^[0-9]+$ ]] && return 0
    
    # WS 1-10 -> middle monitor
    if [[ $ws -gt 0 && $ws -lt 11 ]]; then
        hyprctl dispatch moveworkspacetomonitor "$ws" "$mon_m" >/dev/null
    # WS 11-20 -> left monitor
    elif [[ $ws -gt 10 && $ws -lt 21 ]]; then
        hyprctl dispatch moveworkspacetomonitor "$ws" "$mon_l" >/dev/null
    # WS 21-30 -> right monitor
    elif [[ $ws -gt 20 && $ws -lt 31 ]]; then
        hyprctl dispatch moveworkspacetomonitor "$ws" "$mon_r" >/dev/null
    fi
}

# Kill Steam Special Offers window
handle_steam() {
    local window_data="${1#*>>}"
    local address="${window_data%%,*}"
    
    local client_info=$(hyprctl clients -j | jq -r --arg addr "0x$address" \
        '.[] | select(.address == $addr) | "\(.class)|\(.title)"')
    
    [[ -z "$client_info" ]] && return 0
    
    local class="${client_info%%|*}"
    local title="${client_info#*|}"
    
    [[ "$class" != "steam" ]] && return 0
    [[ "$title" == "Special Offers" ]] && \
        hyprctl dispatch closewindow "address:0x$address" >/dev/null
}

# Move Firefox windows (only once)
left_moved=0
main_moved=0

handle_firefox() {
    [[ $left_moved -eq 1 && $main_moved -eq 1 ]] && return 0
    
    local window_data="${1#*>>}"
    local address="${window_data%%,*}"
    
    local client_info=$(hyprctl clients -j | jq -r --arg addr "0x$address" \
        '.[] | select(.address == $addr) | "\(.class)|\(.title)"')
    
    [[ -z "$client_info" ]] && return 0
    
    local class="${client_info%%|*}"
    local title="${client_info#*|}"
    
    [[ "$class" != "firefox" ]] && return 0
    
    if [[ $title =~ ^\[Main\] && $main_moved -eq 0 ]]; then
        main_moved=1
        hyprctl dispatch movetoworkspacesilent "1,address:0x$address" >/dev/null
    elif [[ $title =~ ^\[Left\ Mon\] && $left_moved -eq 0 ]]; then
        left_moved=1
        hyprctl dispatch movetoworkspacesilent "21,address:0x$address" >/dev/null
    fi
}

# Main event handler
handle() {
    case "$1" in
        createworkspacev2*) handle_workspaces "$1" ;;
        windowtitle*) handle_firefox "$1" ;;
        openwindow*) handle_steam "$1" ;;
        workspacev2*) handle_workspace "$1" ;;
    esac
}

# Ensure swww is ready at startup
ensure_swww

# Main event loop
echo "Listening for Hyprland events..."
socat - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | \
    while read -r line; do
        handle "$line"
    done