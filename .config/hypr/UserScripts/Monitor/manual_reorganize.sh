#!/bin/bash
# ~/.config/hypr/scripts/manual_reorganize.sh
# Réorganise manuellement les fenêtres selon le nombre actuel

# ~/.config/hypr/scripts/manual_reorganize.sh
# Réorganise manuellement les fenêtres selon le nombre actuel

# Lecture automatique de la configuration
HYPR_CONFIG_DIR="$HOME/.config/hypr"

get_screen_resolution() {
    local monitors_file="$HYPR_CONFIG_DIR/Monitors.conf"
    if [[ -f "$monitors_file" ]]; then
        local monitor_line=$(grep -E "^monitor=.*,[0-9]+x[0-9]+@" "$monitors_file" | head -1)
        if [[ -n "$monitor_line" ]]; then
            local resolution=$(echo "$monitor_line" | grep -oE '[0-9]+x[0-9]+' | head -1)
            if [[ -n "$resolution" ]]; then
                echo "$resolution"
                return 0
            fi
        fi
    fi
    local hyprctl_res=$(hyprctl monitors -j | jq -r '.[0] | "\(.width)x\(.height)"' 2>/dev/null)
    echo "${hyprctl_res:-3440x1440}"
}

get_gaps() {
    local user_settings="$HYPR_CONFIG_DIR/UserSettings.conf"
    local gaps_out=8
    if [[ -f "$user_settings" ]]; then
        local in_general=false
        while IFS= read -r line; do
            line=$(echo "$line" | sed 's/#.*$//' | xargs)
            if [[ "$line" == "general"* ]]; then
                in_general=true
            elif [[ "$line" == "}" && "$in_general" == true ]]; then
                in_general=false
            elif [[ "$in_general" == true && "$line" =~ ^gaps_out[[:space:]]*=[[:space:]]*([0-9]+) ]]; then
                gaps_out="${BASH_REMATCH[1]}"
            fi
        done < "$user_settings"
    fi
    echo "$gaps_out"
}

RESOLUTION=$(get_screen_resolution)
SCREEN_WIDTH=$(echo "$RESOLUTION" | cut -d'x' -f1)
SCREEN_HEIGHT=$(echo "$RESOLUTION" | cut -d'x' -f2)
GAPS_OUT=$(get_gaps)
USABLE_WIDTH=$((SCREEN_WIDTH - GAPS_OUT * 2))
USABLE_HEIGHT=$((SCREEN_HEIGHT - GAPS_OUT * 2))

get_workspace_windows() {
    local workspace_id=$(hyprctl activewindow -j | jq -r '.workspace.id')
    hyprctl clients -j | jq -r ".[] | select(.workspace.id == $workspace_id and .floating == false) | .address"
}

window_count=$(get_workspace_windows | wc -l)
windows=($(get_workspace_windows))

echo "Réorganisation manuelle de $window_count fenêtre(s)"

case $window_count in
    1)
        hyprctl dispatch resizewindowpixel exact ${USABLE_WIDTH} ${USABLE_HEIGHT},address:${windows[0]}
        hyprctl dispatch movewindowpixel exact ${GAPS_OUT} ${GAPS_OUT},address:${windows[0]}
        ;;
    2)
        half_width=$((USABLE_WIDTH / 2))
        hyprctl dispatch resizewindowpixel exact ${half_width} ${USABLE_HEIGHT},address:${windows[0]}
        hyprctl dispatch movewindowpixel exact ${GAPS_OUT} ${GAPS_OUT},address:${windows[0]}
        hyprctl dispatch resizewindowpixel exact ${half_width} ${USABLE_HEIGHT},address:${windows[1]}
        hyprctl dispatch movewindowpixel exact $((GAPS_OUT + half_width)) ${GAPS_OUT},address:${windows[1]}
        ;;
    3)
        third_width=$((USABLE_WIDTH / 3))
        hyprctl dispatch resizewindowpixel exact ${third_width} ${USABLE_HEIGHT},address:${windows[0]}
        hyprctl dispatch movewindowpixel exact ${GAPS_OUT} ${GAPS_OUT},address:${windows[0]}
        hyprctl dispatch resizewindowpixel exact ${third_width} ${USABLE_HEIGHT},address:${windows[1]}
        hyprctl dispatch movewindowpixel exact $((GAPS_OUT + third_width)) ${GAPS_OUT},address:${windows[1]}
        hyprctl dispatch resizewindowpixel exact ${third_width} ${USABLE_HEIGHT},address:${windows[2]}
        hyprctl dispatch movewindowpixel exact $((GAPS_OUT + third_width * 2)) ${GAPS_OUT},address:${windows[2]}
        ;;
    *)
        echo "$window_count fenêtres - mode dwindle normal (pas de réorganisation)"
        ;;
esac