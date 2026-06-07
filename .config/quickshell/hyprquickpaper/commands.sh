#!/bin/bash

WALLPAPER="$1"
SCRIPTSDIR="$HOME/.config/hypr/scripts"

FPS=60
TYPE="any"
DURATION=2
SWWW_PARAMS="--transition-fps $FPS --transition-type $TYPE --transition-duration $DURATION"

# Get focused monitor
focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')

# Kill gslapper if running, then ensure swww-daemon is up
if pgrep -x "gslapper" > /dev/null; then
    pkill -x gslapper
    pkill -x awww-daemon 2>/dev/null
    sleep 0.3
fi

pkill Multi_Workspace 2>/dev/null

if ! pgrep -x "swww-daemon" > /dev/null; then
    awww-daemon --format xrgb &
    sleep 0.5
fi

awww img -o "$focused_monitor" "$WALLPAPER" $SWWW_PARAMS &

sleep 1
"$SCRIPTSDIR/WallustSwww.sh" &
sleep 0.5
"$SCRIPTSDIR/Refresh.sh" &
