#!/bin/bash
# ~/.config/hypr/UserScripts/Monitor/toggle_custom_layout.sh
# Active/désactive le gestionnaire personnalisé

SCRIPT_NAME="window_manager.sh"
PID_FILE="/tmp/hypr_window_manager.pid"

if pgrep -f "$SCRIPT_NAME" > /dev/null; then
    echo "Arrêt du gestionnaire personnalisé"
    pkill -f "$SCRIPT_NAME"
    rm -f "$PID_FILE"
    echo "Mode dwindle normal activé"
else
    echo "Démarrage du gestionnaire personnalisé"
    ~/.config/hypr/UserScripts/Monitor/window_manager.sh &
    echo $! > "$PID_FILE"
    echo "Mode layout personnalisé activé"
fi
