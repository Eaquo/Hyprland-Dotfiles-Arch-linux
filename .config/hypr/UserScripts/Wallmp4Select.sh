#!/bin/bash
# WALLPAPERS PATH

wallDIR="$HOME/Pictures/wallpapers/Video"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
THUMBNAIL_DIR="/tmp/video_thumbnails"
Rofi_Dir="$HOME/.config/rofi"
mkdir -p "$THUMBNAIL_DIR"

# Variables
rofi_theme="~/.config/rofi/config-wallpaper.rasi"

# Get monitor info ONCE
get_monitor_info() {
    local monitor_data=$(hyprctl monitors -j)
    focused_monitor=$(jq -r '.[] | select(.focused) | .name' <<< "$monitor_data")
    local monitor_width=$(jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .width' <<< "$monitor_data")
    local scale_factor=$(jq -r --arg mon "$focused_monitor" '.[] | select(.name == $mon) | .scale' <<< "$monitor_data")
    
    icon_size=$(awk "BEGIN {printf \"%.0f\", ($monitor_width * 8) / ($scale_factor * 100)}")
    rofi_override="element-icon{size:${icon_size}px;}"
}

# Generate thumbnail
generate_thumbnail() {
    local video_path="$1"
    local thumbnail_path="${THUMBNAIL_DIR}/$(basename "$video_path").png"
    
    [[ -f "$thumbnail_path" ]] && echo "$thumbnail_path" && return
    ffmpegthumbnailer -i "$video_path" -o "$thumbnail_path" -s 256 2>/dev/null && echo "$thumbnail_path"
}

# Build menu
menu() {
    local RANDOM_PIC="${PICS[$RANDOM % ${#PICS[@]}]}"
    local random_thumbnail=$(generate_thumbnail "$RANDOM_PIC")
    
    # Return option
    printf "%s\x00icon\x1f%s\n" ". return"
    # Random option
    printf "%s\x00icon\x1f%s\n" ". random" "$random_thumbnail"
    
    # Sorted video list
    printf '%s\n' "${PICS[@]}" | sort | while IFS= read -r pic_path; do
        local pic_name="${pic_path##*/}"
        local pic_basename="${pic_name%.*}"
        local thumbnail=$(generate_thumbnail "$pic_path")
        
        [[ ! "$pic_name" =~ \.gif$ ]] && \
            printf "%s\x00icon\x1f%s\n" "$pic_basename" "$thumbnail" || \
            printf "%s\n" "$pic_name"
    done
}

# Apply video wallpaper
apply_video_wallpaper() {
    local video="$1"
    
    # Kill gslapper s'il tourne déjà (pour changer de vidéo)
    pkill -x gslapper 2>/dev/null
    
    # IMPORTANT : Tuer swww-daemon pour que gslapper prenne le contrôle
    if pgrep -x "awww-daemon" > /dev/null; then
        swww kill 2>/dev/null
        pkill -x awww-daemon 2>/dev/null
        sleep 0.3
    fi
    
    # Generate thumbnail for wallust
    rm -f "$Rofi_Dir/.current_wallpaper"
    ffmpegthumbnailer -i "$video" -o "$Rofi_Dir/.current_wallpaper" -s 1024 -q 10 2>/dev/null
    
    # Launch scripts in background
    "$SCRIPTSDIR/WallustSwww.sh" &
    sleep 0.5
    "$SCRIPTSDIR/Refresh.sh" &
    
    # Launch gslapper (exec to replace current process)
    exec gslapper -v -o "loop stretch" "$focused_monitor" "$video"
}

# Main logic
main() {
    local choice
    choice=$(menu | rofi -i -show -dmenu -config "$rofi_theme" -theme-str "$rofi_override")
    choice="${choice## }"; choice="${choice%% }"
    
    [[ -z "$choice" ]] && exit 0
    
    # Handle return
    if [[ "$choice" == ". return" ]]; then
        exec "$HOME/.config/hypr/UserScripts/WallpaperSelect.sh"
    fi
    
    # Handle random
    if [[ "$choice" == ". random" ]]; then
        apply_video_wallpaper "${PICS[$RANDOM % ${#PICS[@]}]}"
        exit 0
    fi
    
    # Find selected video
    local selected_video=""
    for pic in "${PICS[@]}"; do
        [[ "$(basename "$pic")" == "$choice"* ]] && selected_video="$pic" && break
    done
    
    if [[ -n "$selected_video" ]]; then
        apply_video_wallpaper "$selected_video"
    else
        echo "Video not found."
        exit 1
    fi
}

# Main execution
pidof rofi > /dev/null && pkill rofi

get_monitor_info

# Read videos into array
mapfile -d '' PICS < <(find "$wallDIR" -type f -iname "*.mp4" -print0)

[[ ${#PICS[@]} -eq 0 ]] && echo "No videos found in $wallDIR" && exit 1

main