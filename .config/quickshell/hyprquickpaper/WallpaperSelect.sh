#!/bin/bash
# WALLPAPERS PATH
terminal=kitty
wallDIR="$HOME/Pictures/wallpapers"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
USERSCRIPTSDIR="$HOME/.config/hypr/UserScripts"
wallpaper_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
mpvDIR="$HOME/Pictures/wallpapers/Video"
THUMBNAIL_DIR="/tmp/video_thumbnails"
mkdir -p "$THUMBNAIL_DIR"

# Directory for swaync
iDIR="$HOME/.config/swaync/images"
iDIRi="$HOME/.config/swaync/icons"

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

# Ensure swww-daemon is running (but NOT if gslapper is active)
ensure_swww() {
    # Si gslapper tourne, on ne lance PAS swww
    if pgrep -x "gslapper" > /dev/null; then
        return 0
    fi
    
    if ! pgrep -x "awww-daemon" > /dev/null; then
        awww-daemon --format xrgb &
        sleep 0.5
    fi
}

# swww transition config
FPS=60
TYPE="any"
DURATION=2
SWWW_PARAMS="--transition-fps $FPS --transition-type $TYPE --transition-duration $DURATION"

# Check if swaybg is running
pidof swaybg > /dev/null && pkill swaybg

# Check processus Wall

pgrep WallpaperMul > /dev/null && pkill WallpaperMult
pgrep WallpaperAut > /dev/null && pkill WallpaperAut
# Read wallpapers
mapfile -d '' PICS < <(find -L "$wallDIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.webp" \) -print0)
mapfile -d '' PICS_MPV < <(find "$mpvDIR" -type f -iname "*.mp4" -print0)

# Random selections
RANDOM_PIC="${PICS[$RANDOM % ${#PICS[@]}]}"
MULTI_PIC="${PICS[$RANDOM % ${#PICS[@]}]}"
MPV_PIC="${PICS_MPV[$RANDOM % ${#PICS_MPV[@]}]}"
EFFECT_PIC="${PICS[$RANDOM % ${#PICS[@]}]}"
AUTO_PIC="${PICS[$RANDOM % ${#PICS[@]}]}"

# Menu
menu() {
    IFS=$'\n' sorted_options=($(printf '%s\n' "${PICS[@]}" | sort))
    
    printf "%s\x00icon\x1f%s\n" ". random" "$RANDOM_PIC"
    printf "%s\x00icon\x1f%s\n" ". Multi_Work" "$MULTI_PIC"
    
    local mpv_thumbnail=$(generate_thumbnail "$MPV_PIC")
    printf "%s\x00icon\x1f%s\n" ". mpv" "$mpv_thumbnail"
    printf "%s\x00icon\x1f%s\n" ". effect" "$EFFECT_PIC"
    printf "%s\x00icon\x1f%s\n" ". auto" "$AUTO_PIC"
    
    for pic_path in "${sorted_options[@]}"; do
        local pic_name="${pic_path##*/}"
        local pic_basename="${pic_name%.*}"
        
        [[ ! "$pic_name" =~ \.gif$ ]] && \
            printf "%s\x00icon\x1f%s\n" "$pic_basename" "$pic_path" || \
            printf "%s\n" "$pic_name"
    done
}

# Apply wallpaper
apply_wallpaper() {
    local wallpaper="$1"
    
    # Kill gslapper et swww-daemon pour un wallpaper statique
    if pgrep -x "gslapper" > /dev/null; then
        pkill -x gslapper
        pkill -x awww-daemon 2>/dev/null
        sleep 0.3
    fi
    
    pkill Multi_Workspace 2>/dev/null
    
    # Maintenant on peut lancer swww
    if ! pgrep -x "swww-daemon" > /dev/null; then
        awww-daemon --format xrgb &
        sleep 0.5
    fi
    
    awww img -o "$focused_monitor" "$wallpaper" $SWWW_PARAMS &
    
    sleep 1
    "$SCRIPTSDIR/WallustSwww.sh" &
    sleep 0.5
    "$SCRIPTSDIR/Refresh.sh" &
}

# Main logic
main() {
    local choice
    choice=$(menu | rofi -i -show -dmenu -config "$rofi_theme" -theme-str "$rofi_override")
    choice="${choice## }"; choice="${choice%% }"
    
    [[ -z "$choice" ]] && exit 0
    
    case "$choice" in
        ". Multi_Work")
            # Si gslapper tourne, on le tue avant Multi_Workspace
            pgrep -x "gslapper" > /dev/null && pkill -x gslapper
            "$USERSCRIPTSDIR/WallpaperMultiWork.sh"
            ;;
        ". random")
            apply_wallpaper "$RANDOM_PIC"
            ;;
        ". mpv")
            exec "$USERSCRIPTSDIR/Wallmp4Select.sh"
            ;;
        ". effect")
            # Si gslapper tourne, on le tue avant les effets
            pgrep -x "gslapper" > /dev/null && pkill -x gslapper
            "$USERSCRIPTSDIR/WallpaperEffects.sh"
            ;;
        ". auto")
            # Si gslapper tourne, on le tue avant l'autochange
            pgrep -x "gslapper" > /dev/null && pkill -x gslapper
            exec "$USERSCRIPTSDIR/WallpaperAutoChange.sh"
            ;;
        *)
            # Find selected image
            local pic_index=-1
            for i in "${!PICS[@]}"; do
                [[ "$(basename "${PICS[$i]}")" == "$choice"* ]] && pic_index=$i && break
            done
            
            if [[ $pic_index -ne -1 ]]; then
                apply_wallpaper "${PICS[$pic_index]}"
            else
                echo "Image not found."
                exit 1
            fi
            ;;
    esac
}

# Kill rofi if running
pidof rofi > /dev/null && pkill rofi

get_monitor_info
ensure_swww  # Ne lance swww QUE si gslapper n'est pas actif
main

# SDDM background prompt (only if a wallpaper was selected)
if [[ -n "$choice" && "$choice" != ". mpv" && "$choice" != ". Multi_Work" && "$choice" != ". effect" ]]; then
    sddm_sequoia="/usr/share/sddm/themes/sequoia_2"
    if [[ -d "$sddm_sequoia" ]]; then
        notify-send -i "$iDIR/ja.png" "Set wallpaper" "as SDDM background?" \
            -t 10000 \
            -A "yes=Yes" \
            -A "no=No" \
            -h string:x-canonical-private-synchronous:wallpaper-notify
        
        dbus-monitor "interface='org.freedesktop.Notifications',member='ActionInvoked'" 2>/dev/null |
        while read -r line; do
            if echo "$line" | grep -q "yes"; then
                if ! command -v "$terminal" &>/dev/null; then
                    notify-send -i "$iDIR/ja.png" "Missing $terminal" "Install $terminal to enable setting of wallpaper background"
                    exit 1
                fi
                
                $terminal -e bash -c "echo 'Enter your password to set wallpaper as SDDM Background'; \
                sudo cp -r '$wallpaper_current' '$sddm_sequoia/backgrounds/default' && \
                notify-send -i '$iDIR/ja.png' 'SDDM' 'Background SET'"
                break
            elif echo "$line" | grep -q "no"; then
                break
            fi
        done &
    fi
fi