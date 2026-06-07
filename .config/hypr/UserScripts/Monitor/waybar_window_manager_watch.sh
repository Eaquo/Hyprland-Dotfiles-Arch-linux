#!/bin/bash
# ~/.config/hypr/scripts/waybar_window_manager_watch.sh
# Script de surveillance continue pour waybar (si nécessaire)

while true; do
    ~/.config/hypr/UserScripts/Monitor/waybar_window_manager.sh status
    sleep 1
done
