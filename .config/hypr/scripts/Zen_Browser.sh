#!/bin/bash

# Script pour gérer Zen Browser sur Hyprland
# Vérifie si Zen est ouvert, sinon le lance
# Si ouvert, va sur le workspace et fait un split vertical

# Nom du processus Zen (à ajuster si nécessaire)
ZEN_PROCESS="zen"

# Commande pour lancer Zen
ZEN_COMMAND="zen-browser"

# Vérifie si Zen Browser est déjà en cours d'exécution via hyprctl
ZEN_CLIENTS=$(hyprctl clients -j | jq -r '.[] | select(.class == "zen") | .pid' | wc -l)

if [ "$ZEN_CLIENTS" -gt 0 ]; then
    echo "Zen Browser est déjà ouvert"
    
    # Récupère les informations sur les fenêtres Zen
    ZEN_WINDOW=$(hyprctl clients -j | jq -r '.[] | select(.class == "zen") | .workspace.id' | head -n1)
    CURRENT_WORKSPACE=$(hyprctl activeworkspace -j | jq -r '.id')
    ACTIVE_WINDOW_CLASS=$(hyprctl activewindow -j | jq -r '.class')
    
    if [ -n "$ZEN_WINDOW" ]; then
        echo "Zen trouvé sur le workspace $ZEN_WINDOW"
        echo "Workspace actuel : $CURRENT_WORKSPACE"
        echo "Fenêtre active : $ACTIVE_WINDOW_CLASS"
        
        # Si on est déjà sur le bon workspace ET sur une fenêtre Zen
        if [ "$ZEN_WINDOW" = "$CURRENT_WORKSPACE" ] && [ "$ACTIVE_WINDOW_CLASS" = "zen" ]; then
            echo "Déjà focus sur Zen, création du split directement..."
            hyprctl dispatch focuswindow "class:zen"
            
            # Attend un peu pour s'assurer que le focus est correct
            sleep 0.3
            wtype -M alt -M ctrl -k v
            
        # Si on est sur le bon workspace mais pas focus sur Zen
        elif [ "$ZEN_WINDOW" = "$CURRENT_WORKSPACE" ]; then
            echo "Sur le bon workspace, focus sur Zen puis split..."
            hyprctl dispatch focuswindow "class:zen"
            
        else
            echo "Changement vers le workspace $ZEN_WINDOW puis split..."
            
            # Va sur le workspace où se trouve Zen
            hyprctl dispatch workspace "$ZEN_WINDOW"
            
            # Attend un peu pour le changement de workspace
            sleep 0.2
            
            # Focus sur la fenêtre Zen
            hyprctl dispatch focuswindow "class:zen"
            
            # Attend un peu pour s'assurer que le focus est correct
            sleep 0.3
            
            # Simule le raccourci Alt+Ctrl+V pour faire un split vertical
            wtype -M alt -M ctrl -k v
        fi
    else
        echo "Fenêtre Zen non trouvée, lancement d'une nouvelle instance"
        hyprctl dispatch exec "$ZEN_COMMAND"
    fi
else
    echo "Zen Browser n'est pas ouvert, lancement..."
    hyprctl dispatch exec "$ZEN_COMMAND"
fi