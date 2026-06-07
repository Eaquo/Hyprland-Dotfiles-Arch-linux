#!/bin/bash
# ~/.config/hypr/scripts/build_layout.sh

# Script pour créer un layout de build similaire à l'image

TEMP_DIR="/tmp/build_session_$$"
mkdir -p "$TEMP_DIR"

LOG_FILE="$TEMP_DIR/build.log"
PROGRESS_FILE="$TEMP_DIR/progress.log"

# Fonction pour lancer la fenêtre principale de build
launch_main_build() {
    local packages="$@"
    kitty --title "Build Main - $packages" \
          --override background_opacity=0.9 \
          bash -c "
            echo '=== Starting build for: $packages ==='
            echo 'Build log: $LOG_FILE'
            echo '=================================='
            
            # Lancer paru avec logging complet
            paru -S $packages 2>&1 | tee '$LOG_FILE'
            
            echo 'Build completed. Press Enter to close...'
            read
          " &
}

# Fonction pour lancer la fenêtre de détails flottante
launch_details_window() {
    sleep 2  # Attendre que le build commence
    
    kitty --title "Build Details" \
          --override background_opacity=0.85 \
          --override font_size=10 \
          bash -c "
            echo 'Build Details Monitor'
            echo '===================='
            echo ''
            
            while true; do
                if [[ -f '$LOG_FILE' ]]; then
                    clear
                    echo 'Last 30 lines of build log:'
                    echo '============================'
                    tail -n 30 '$LOG_FILE' 2>/dev/null || echo 'Waiting for build to start...'
                else
                    echo 'Waiting for build log...'
                fi
                sleep 2
            done
          " &
}

# Fonction pour lancer le moniteur de progression
launch_progress_monitor() {
    sleep 1
    
    kitty --title "Build Monitor" \
          --override background_opacity=0.8 \
          --override font_size=9 \
          bash -c "
            while true; do
                clear
                echo 'Build Progress Monitor'
                echo '====================='
                echo ''
                
                # Afficher les processus de build actifs
                echo 'Active build processes:'
                pgrep -f 'makepkg\|cargo\|cmake\|make' | head -5 | while read pid; do
                    ps -p \$pid -o pid,pcpu,pmem,comm --no-headers 2>/dev/null
                done
                
                echo ''
                echo 'System resources:'
                echo 'CPU:' \$(grep 'cpu ' /proc/stat | awk '{usage=(\$2+\$4)*100/(\$2+\$3+\$4+\$5)} END {print usage \"%\";}')
                echo 'RAM:' \$(free | grep Mem | awk '{printf \"%.1f%%\", \$3/\$2 * 100.0}')
                
                if [[ -f '$LOG_FILE' ]]; then
                    echo ''
                    echo 'Last build message:'
                    tail -n 1 '$LOG_FILE' 2>/dev/null | cut -c1-50
                fi
                
                sleep 3
            done
          " &
}

# Fonction principale
main() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 <package1> [package2] ..."
        echo "Enhanced build interface for Hyprland + Kitty"
        echo "Set BUILD_WORKSPACE=current to use current workspace"
        echo "Set BUILD_WORKSPACE=9 to use workspace 9"
        exit 1
    fi
    
    local packages="$*"
    
    echo "Setting up build environment for: $packages"
    
    # Gérer le workspace selon la variable d'environnement
    case "${BUILD_WORKSPACE:-current}" in
        "current")
            echo "Using current workspace"
            ;;
        "special")
            hyprctl dispatch workspace special:build
            ;;
        [0-9]*)
            echo "Using workspace $BUILD_WORKSPACE"
            hyprctl dispatch workspace "$BUILD_WORKSPACE"
            ;;
        *)
            echo "Using current workspace (invalid BUILD_WORKSPACE value)"
            ;;
    esac
    
    # Lancer les différentes fenêtres
    launch_main_build "$packages"
    launch_details_window
    launch_progress_monitor
    
    # Attendre un peu puis organiser les fenêtres
    sleep 3
    
    # Organiser les fenêtres (optionnel)
    hyprctl dispatch focuswindow "title:^Build Main"
    
    echo "Build environment set up!"
    echo "Use SUPER+grave to toggle build workspace"
    echo "Use SUPER+F6 to toggle build workspace"
    
    # Cleanup function
    trap 'cleanup' EXIT
}

cleanup() {
    echo "Cleaning up build session..."
    pkill -f "Build Details" 2>/dev/null || true
    pkill -f "Build Monitor" 2>/dev/null || true
    rm -rf "$TEMP_DIR" 2>/dev/null || true
}

# Vérifier qu'on est sous Hyprland
if [[ "$XDG_SESSION_DESKTOP" != "hyprland" ]] && [[ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
    echo "This script is designed for Hyprland"
    exit 1
fi

main "$@"