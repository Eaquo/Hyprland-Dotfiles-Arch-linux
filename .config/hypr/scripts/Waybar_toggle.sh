#!/bin/bash
# ~/.config/hypr/scripts/waybar_toggle.sh
# Script avec feedback visuel/sonore

if pgrep waybar > /dev/null; then
    killall waybar
    notify-send "Waybar" "🔴 Cachée" -t 1000 -u low
    
else
    waybar &
    

    notify-send "Waybar" "🟢 Affichée" -t 1000 -u low
    
    
fi
