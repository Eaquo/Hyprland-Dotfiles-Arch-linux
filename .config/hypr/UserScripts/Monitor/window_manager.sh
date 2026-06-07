#!/bin/bash
# ~/.config/hypr/UserScripts/Monitor/window_manager.sh
# Script de gestion des fenêtres Hyprland pour 3 fenêtres (centrage en tiers)

# Paramètres de configuration
PID_FILE="/tmp/hypr_window_manager.pid"
STATUS_FILE="/tmp/hypr_window_manager_status.txt"
EVENT_TRIGGER_FILE="/tmp/hypr_wm_event_trigger"
LOCK_FILE="/tmp/hypr_wm_resize_lock"
HYPR_CONFIG_DIR="$HOME/.config/hypr/UserConfig"
HYPR_MONITORS_CONF="$HYPR_CONFIG_DIR/Monitors.conf"
HYPR_SETTINGS_CONF="$HYPR_CONFIG_DIR/UserSettings.conf"
DEFAULT_RESOLUTION="3440x1440"
DEFAULT_GAPS_IN=4
DEFAULT_GAPS_OUT=8
SCRIPT_NAME="window_manager.sh"
SOCKET_PATH="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
DEBUG_LOG="/tmp/hypr_wm_debug.log"
POLL_INTERVAL=0.3
DEBOUNCE_INTERVAL=1.5

# Vérifier les dépendances
check_dependencies() {
    local deps=("jq" "hyprctl" "socat" "pgrep" "pkill")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo "Erreur : dépendance '$dep' non installée."
            exit 1
        fi
    done
}

# Vérifier l'environnement Hyprland
check_hyprland_env() {
    if [[ -z "$XDG_RUNTIME_DIR" || -z "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
        echo "Erreur : environnement Hyprland non détecté."
        exit 1
    fi
    if [[ ! -S "$SOCKET_PATH" ]]; then
        echo "Erreur : socket Hyprland inaccessible."
        exit 1
    fi
}

# Nettoyer les fichiers temporaires au démarrage
cleanup_temp_files() {
    rm -f "$PID_FILE" "$STATUS_FILE" "$EVENT_TRIGGER_FILE" "$LOCK_FILE" 2>/dev/null || true
    pkill -f "socat.*hypr.*socket2.sock" 2>/dev/null || true
}

# Fonction pour mettre à jour le fichier de statut
update_status() {
    local workspace_id=$(hyprctl activewindow -j 2>/dev/null | jq -r '.workspace.id // empty')
    if [[ -z "$workspace_id" ]]; then
        echo "dwindle" > "$STATUS_FILE" 2>/dev/null         echo "dwindle"
        return
    fi

    local window_count=$(hyprctl clients -j 2>/dev/null | jq -r ".[] | select(.workspace.id == $workspace_id and .floating == false) | .address" | wc -l)
    if [[ -z "$window_count" || ! "$window_count" =~ ^[0-9]+$ ]]; then
        echo "dwindle" > "$STATUS_FILE" 2>/dev/null         echo "dwindle"
        return
    fi

    local status="dwindle"
    if [ "$window_count" -eq 3 ]; then
        status="managed-3"
    elif [ "$window_count" -gt 3 ]; then
        status="managed-normal"
    fi

    echo "$status" > "$STATUS_FILE" 2>/dev/null     echo "$status"
}

# Fonction pour obtenir l'état actuel
get_status() {
    update_status
}

# Fonction pour lire la résolution depuis Monitors.conf
get_screen_resolution() {
    if [[ -f "$HYPR_MONITORS_CONF" ]]; then
        local monitor_line=$(grep -E "^monitor=.*,[0-9]+x[0-9]+@" "$HYPR_MONITORS_CONF" | head -1)
        if [[ -n "$monitor_line" ]]; then
            local resolution=$(echo "$monitor_line" | grep -oE '[0-9]+x[0-9]+' | head -1)
            if [[ -n "$resolution" ]]; then
                    echo "$resolution"
                return 0
            fi
        fi
    fi

    local hyprctl_res=$(hyprctl monitors -j 2>/dev/null | jq -r '.[0] | "\(.width)x\(.height)"')
    if [[ -n "$hyprctl_res" && "$hyprctl_res" != "null" ]]; then
            echo "$hyprctl_res"
    else
        echo "$DEFAULT_RESOLUTION"
    fi
}

# Fonction pour lire les gaps depuis UserSettings.conf
get_gaps() {
    local gaps_in=$DEFAULT_GAPS_IN
    local gaps_out=$DEFAULT_GAPS_OUT

    if [[ -f "$HYPR_SETTINGS_CONF" ]]; then
        local in_general=false
        while IFS= read -r line; do
            line=$(echo "$line" | sed 's/#.*$//' | xargs)
            if [[ "$line" == "general"* ]]; then
                in_general=true
            elif [[ "$line" == "}" && "$in_general" == true ]]; then
                in_general=false
            elif [[ "$in_general" == true && "$line" =~ ^gaps_in[[:space:]]*=[[:space:]]*([0-9]+) ]]; then
                gaps_in="${BASH_REMATCH[1]}"
            elif [[ "$in_general" == true && "$line" =~ ^gaps_out[[:space:]]*=[[:space:]]*([0-9]+) ]]; then
                gaps_out="${BASH_REMATCH[1]}"
            fi
        done < "$HYPR_SETTINGS_CONF"
    fi

    echo "$gaps_in $gaps_out"
}

# Configuration
RESOLUTION=$(get_screen_resolution)
SCREEN_WIDTH=$(echo "$RESOLUTION" | cut -d'x' -f1)
SCREEN_HEIGHT=$(echo "$RESOLUTION" | cut -d'x' -f2)

GAPS_INFO=$(get_gaps)
GAPS_IN=$(echo "$GAPS_INFO" | cut -d' ' -f1)
GAPS_OUT=$(echo "$GAPS_INFO" | cut -d' ' -f2)

USABLE_WIDTH=$((SCREEN_WIDTH - GAPS_OUT * 2))
USABLE_HEIGHT=$((SCREEN_HEIGHT - GAPS_OUT * 2))

# Fonction pour obtenir les fenêtres sur l'espace de travail actuel
get_workspace_windows() {
    local workspace_id=$(hyprctl activewindow -j 2>/dev/null | jq -r '.workspace.id // 1')
    local windows=$(hyprctl clients -j 2>/dev/null | jq -r ".[] | select(.workspace.id == $workspace_id and .floating == false) | .address" 2>/dev/null || true)
    echo "$windows"
}

# Fonction pour obtenir le nombre de fenêtres tiling
get_tiling_window_count() {
    local count=$(get_workspace_windows | wc -l)
    echo "$count"
}

# Fonction pour obtenir l'espace de travail actuel
get_current_workspace() {
    local workspace=$(hyprctl activewindow -j 2>/dev/null | jq -r '.workspace.id // 1')
    echo "$workspace"
}

# Fonction pour analyser l'arrangement actuel des fenêtres
analyze_window_layout() {
    local workspace_id=$(hyprctl activewindow -j 2>/dev/null | jq -r '.workspace.id // 1')
    local windows_info=$(hyprctl clients -j 2>/dev/null | jq -r ".[] | select(.workspace.id == $workspace_id and .floating == false) | \"\(.address) \(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])\"")
    
    if [[ -z "$windows_info" ]]; then
        echo "unknown"
        return
    fi
    
    local window_count=$(echo "$windows_info" | wc -l)
    
    case $window_count in
        3)
            # Calculer les zones dynamiquement selon la résolution
            local left_zone=$((SCREEN_WIDTH / 3))        # Premier tiers
            local right_zone=$((SCREEN_WIDTH * 2 / 3))   # Deux tiers
            
            
            # Analyser la position X de chaque fenêtre
            local left_windows=$(echo "$windows_info" | awk -v zone="$left_zone" '$2 < zone' | wc -l)
            local middle_windows=$(echo "$windows_info" | awk -v left="$left_zone" -v right="$right_zone" '$2 >= left && $2 < right' | wc -l)
            local right_windows=$(echo "$windows_info" | awk -v zone="$right_zone" '$2 >= zone' | wc -l)
            
            
            # Analyser aussi la largeur des fenêtres pour détecter les colonnes
            local half_width=$((USABLE_WIDTH / 2))
            local narrow_windows=$(echo "$windows_info" | awk -v half="$half_width" '$4 < half' | wc -l)
            local wide_windows=$(echo "$windows_info" | awk -v half="$half_width" '$4 >= half' | wc -l)
            
            
            # Détection intelligente basée sur les largeurs ET positions
            if [[ $narrow_windows -eq 2 && $wide_windows -eq 1 ]]; then
                # 2 fenêtres étroites + 1 large = arrangement en colonnes
                if [[ $right_windows -eq 1 ]]; then
                    echo "2left-1right"
                else
                    echo "1left-2right"
                fi
            elif [[ $narrow_windows -eq 1 && $wide_windows -eq 2 ]]; then
                # 1 fenêtre étroite + 2 larges = aussi un arrangement en colonnes
                # Les 2 larges sont superposées (même position X)
                local same_x_count=$(echo "$windows_info" | awk '{print $2}' | sort | uniq -c | awk '$1 > 1' | wc -l)
                if [[ $same_x_count -gt 0 ]]; then
                    # Il y a des fenêtres avec la même position X = colonnes détectées
                    if [[ $left_windows -eq 1 ]]; then
                        echo "1left-2right"
                    else
                        echo "2left-1right"
                    fi
                else
                    echo "3-equal"
                fi
            else
                echo "3-equal"
            fi
            ;;
        4)
            echo "4-mixed"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Fonction pour réajustement intelligent selon l'arrangement détecté
smart_resize_windows() {
    local window_count=$1
    local layout_type=$(analyze_window_layout)
    local windows=($(get_workspace_windows))

    # Vérifier si un redimensionnement est déjà en cours
    if [[ -f "$LOCK_FILE" ]]; then
                return
    fi
    touch "$LOCK_FILE" 2>/dev/null || return 1

    if [ ${#windows[@]} -ne $window_count ]; then
        echo "Erreur : nombre de fenêtres incohérent (attendu: $window_count, trouvé: ${#windows[@]})"
        rm -f "$LOCK_FILE" 2>/dev/null
        return 1
    fi

    echo "Réajustement intelligent: $window_count fenêtres, layout: $layout_type"

    case "$window_count" in
        3)
            case "$layout_type" in
                "2left-1right"|"1left-2right")
                    # Arrangement en colonnes détecté - réajuster intelligemment
                    resize_3_columns_layout "$layout_type"
                    ;;
                *)
                    # Mode 3 tiers égaux par défaut
                    resize_3_equal_layout
                    ;;
            esac
            ;;
        *)
            echo "Mode dwindle pour $window_count fenêtres"
            update_status
            ;;
    esac

    rm -f "$LOCK_FILE" 2>/dev/null
}

# Fonction pour layout 3 tiers égaux
resize_3_equal_layout() {
    local windows=($(get_workspace_windows))
    echo "Mode 3 fenêtres : disposition en tiers égaux"
    
    # Calculs corrigés avec gaps horizontaux
    local gaps_between_windows=$((GAPS_IN * 2))  # 2 gaps entre 3 fenêtres
    local available_width=$((USABLE_WIDTH - gaps_between_windows))
    local third_width=$((available_width / 3))
    local remaining_width=$((available_width % 3))
    
    # Ajuster la première fenêtre pour compenser les pixels restants
    local first_width=$((third_width + remaining_width))
    

    # Positions calculées avec gaps
    local pos1_x=$GAPS_OUT
    local pos2_x=$((GAPS_OUT + first_width + GAPS_IN))
    local pos3_x=$((GAPS_OUT + first_width + GAPS_IN + third_width + GAPS_IN))
    
    # Redimensionner et positionner chaque fenêtre avec délais
    resize_and_move_window "${windows[0]}" "$first_width" "$USABLE_HEIGHT" "$pos1_x" "$GAPS_OUT" "1"
    resize_and_move_window "${windows[1]}" "$third_width" "$USABLE_HEIGHT" "$pos2_x" "$GAPS_OUT" "2"
    resize_and_move_window "${windows[2]}" "$third_width" "$USABLE_HEIGHT" "$pos3_x" "$GAPS_OUT" "3"
    
    sleep 0.3
    update_status
}

# Fonction pour layout en colonnes (2 à gauche, 1 à droite ou inverse)
resize_3_columns_layout() {
    local layout_type=$1
    local windows=($(get_workspace_windows))
    
    echo "Mode 3 fenêtres : réajustement colonnes ($layout_type)"
    
    # Configuration pour layout en colonnes
    local left_width=$((USABLE_WIDTH / 2 - GAPS_IN / 2))
    local right_width=$((USABLE_WIDTH / 2 - GAPS_IN / 2))
    local column_height=$((USABLE_HEIGHT / 2 - GAPS_IN / 2))
    
    
    case "$layout_type" in
        "2left-1right")
            # 2 fenêtres à gauche en colonne, 1 à droite
            local pos_left_x=$GAPS_OUT
            local pos_right_x=$((GAPS_OUT + left_width + GAPS_IN))
            
            resize_and_move_window "${windows[0]}" "$left_width" "$column_height" "$pos_left_x" "$GAPS_OUT" "1 (haut gauche)"
            resize_and_move_window "${windows[1]}" "$left_width" "$column_height" "$pos_left_x" "$((GAPS_OUT + column_height + GAPS_IN))" "2 (bas gauche)"
            resize_and_move_window "${windows[2]}" "$right_width" "$USABLE_HEIGHT" "$pos_right_x" "$GAPS_OUT" "3 (droite)"
            ;;
        "1left-2right")
            # 1 fenêtre à gauche, 2 à droite en colonne
            local pos_left_x=$GAPS_OUT
            local pos_right_x=$((GAPS_OUT + left_width + GAPS_IN))
            
            resize_and_move_window "${windows[0]}" "$left_width" "$USABLE_HEIGHT" "$pos_left_x" "$GAPS_OUT" "1 (gauche)"
            resize_and_move_window "${windows[1]}" "$right_width" "$column_height" "$pos_right_x" "$GAPS_OUT" "2 (haut droite)"
            resize_and_move_window "${windows[2]}" "$right_width" "$column_height" "$pos_right_x" "$((GAPS_OUT + column_height + GAPS_IN))" "3 (bas droite)"
            ;;
    esac
    
    sleep 0.3
    update_status
}

# Fonction utilitaire pour redimensionner et déplacer une fenêtre
resize_and_move_window() {
    local window_address=$1
    local width=$2
    local height=$3
    local x=$4
    local y=$5
    local window_name=$6
    
    
    if hyprctl dispatch resizewindowpixel exact ${width} ${height},address:${window_address} 2>/dev/null; then
        sleep 0.15
        hyprctl dispatch movewindowpixel exact ${x} ${y},address:${window_address} 2>/dev/null
    fi
    sleep 0.15
}

# Fonction simple pour 3 fenêtres en tiers égaux
simple_resize_3_windows() {
    local workspace_id=$(hyprctl activewindow -j 2>/dev/null | jq -r '.workspace.id // 1')
    
    echo "Redimensionnement simple: 3 tiers égaux"
    
    # Calcul corrigé: 3 tiers égaux avec gaps
    local gaps_between_windows=$((GAPS_IN * 2))  # 2 gaps entre 3 fenêtres
    local available_width=$((USABLE_WIDTH - gaps_between_windows))
    local third_width=$((available_width / 3))
    local remaining_pixels=$((available_width % 3))
    
    # Répartir les pixels restants
    local width1=$((third_width + (remaining_pixels > 0 ? 1 : 0)))
    local width2=$((third_width + (remaining_pixels > 1 ? 1 : 0)))
    local width3=$third_width
    
    # Positions corrigées avec gaps
    local pos1_x=$GAPS_OUT
    local pos2_x=$((GAPS_OUT + width1 + GAPS_IN))
    local pos3_x=$((GAPS_OUT + width1 + GAPS_IN + width2 + GAPS_IN))
    
    
    # Récupérer les fenêtres JUSTE avant le redimensionnement pour éviter les race conditions
    local windows_with_pos=$(hyprctl clients -j 2>/dev/null | jq -r ".[] | select(.workspace.id == $workspace_id and .floating == false) | \"\(.address) \(.at[0])\"" | sort -k2 -n)
    
    if [[ $(echo "$windows_with_pos" | wc -l) -ne 3 ]]; then
        update_status
        return
    fi
    
    # Extraire les adresses dans l'ordre de position X (gauche vers droite)
    local sorted_windows=($(echo "$windows_with_pos" | awk '{print $1}'))
    
    # Temporairement passer en mode floating pour éviter l'auto-réorganisation
    hyprctl dispatch togglefloating address:${sorted_windows[0]} 2>/dev/null
    hyprctl dispatch togglefloating address:${sorted_windows[1]} 2>/dev/null
    hyprctl dispatch togglefloating address:${sorted_windows[2]} 2>/dev/null
    sleep 0.1
    
    # Application des tailles et positions en mode floating
    
    # Redimensionner et positionner chaque fenêtre en mode floating
    hyprctl dispatch resizewindowpixel exact ${width1} ${USABLE_HEIGHT},address:${sorted_windows[0]} 2>/dev/null
    hyprctl dispatch movewindowpixel exact ${pos1_x} ${GAPS_OUT},address:${sorted_windows[0]} 2>/dev/null
    
    hyprctl dispatch resizewindowpixel exact ${width2} ${USABLE_HEIGHT},address:${sorted_windows[1]} 2>/dev/null
    hyprctl dispatch movewindowpixel exact ${pos2_x} ${GAPS_OUT},address:${sorted_windows[1]} 2>/dev/null
    
    hyprctl dispatch resizewindowpixel exact ${width3} ${USABLE_HEIGHT},address:${sorted_windows[2]} 2>/dev/null
    hyprctl dispatch movewindowpixel exact ${pos3_x} ${GAPS_OUT},address:${sorted_windows[2]} 2>/dev/null
    
    sleep 0.2
    
    # Retour en mode tiling - l'ordre et les tailles devraient être préservés
    hyprctl dispatch togglefloating address:${sorted_windows[0]} 2>/dev/null
    hyprctl dispatch togglefloating address:${sorted_windows[1]} 2>/dev/null
    hyprctl dispatch togglefloating address:${sorted_windows[2]} 2>/dev/null
    
    
    sleep 0.3
    update_status
}

# Fonction de surveillance avec événements hybrides
monitor_windows() {
    # Lancer la surveillance des événements en arrière-plan
    {
        socat -U - UNIX-CONNECT:"$SOCKET_PATH" 2>>"$DEBUG_LOG" | while IFS= read -r line || [[ -n "$line" ]]; do
            event_type=$(echo "$line" | cut -d'>' -f1)
            case "$event_type" in
                "openwindow"|"closewindow"|"workspace")
                    # Marquer le type d'événement pour ajuster le délai
                    echo "$event_type" > "$EVENT_TRIGGER_FILE" 2>/dev/null
                    ;;
            esac
        done
        local exit_code=$?
        echo "Erreur : processus socat s'est arrêté (code de sortie $exit_code)"
        exit $exit_code
    } &
    local socat_pid=$!

    # Surveillance principale
    local last_window_count=$(get_tiling_window_count)
    local last_workspace=$(get_current_workspace)
    local last_resize_time=0

    while [[ -f "$PID_FILE" ]]; do
        local current_workspace=$(get_current_workspace)
        local current_count=$(get_tiling_window_count)
        local force_update=false
        local current_time=$(date +%s.%N)
        local time_since_last_resize=$(echo "$current_time - $last_resize_time" | bc)

        # Vérifier s'il y a eu un événement
        if [[ -f "$EVENT_TRIGGER_FILE" ]]; then
            local event_type=$(cat "$EVENT_TRIGGER_FILE" 2>/dev/null || echo "unknown")
            rm -f "$EVENT_TRIGGER_FILE" 2>/dev/null
            force_update=true
            
            # Délai adaptatif selon le type d'événement
            case "$event_type" in
                "closewindow")
                    sleep 1.0
                    ;;
                "openwindow")
                    sleep 0.5
                    ;;
                *)
                    sleep 0.3
                    ;;
            esac
        fi

        # Vérifier si quelque chose a changé ou si on force la mise à jour
        if [[ "$current_count" != "$last_window_count" ]] || [[ "$current_workspace" != "$last_workspace" ]] || [[ "$force_update" == true ]]; then
            # Appliquer un debouncing pour éviter les réorganisations trop fréquentes
            if (( $(echo "$time_since_last_resize < $DEBOUNCE_INTERVAL" | bc -l) )); then
                sleep "$POLL_INTERVAL"
                continue
            fi

            echo "Changement détecté: workspace=$current_workspace, fenêtres=$current_count"

            if [ "$current_count" -eq 3 ]; then
                echo "Mode 3 fenêtres : redimensionnement simple"
                simple_resize_3_windows
                last_resize_time=$(date +%s.%N)
            else
                echo "Mode dwindle normal pour $current_count fenêtres"
                update_status
            fi

            last_window_count=$current_count
            last_workspace=$current_workspace
        fi

        sleep "$POLL_INTERVAL"
    done

    # Nettoyer le processus socat
    kill $socat_pid 2>/dev/null || true
}

# Fonction de nettoyage
cleanup() {
    echo "Arrêt du gestionnaire de fenêtres"
    rm -f "$PID_FILE" "$STATUS_FILE" "$EVENT_TRIGGER_FILE" "$LOCK_FILE" 2>/dev/null || true
    pkill -f "socat.*hypr.*socket2.sock" 2>/dev/null || true
    exit 0
}

# Fonction principale
main() {
    check_dependencies
    check_hyprland_env
    cleanup_temp_files

    # Capturer les signaux, y compris SIGPIPE
    trap cleanup SIGTERM SIGINT SIGQUIT SIGPIPE

    case "${1:-}" in
        "get_status")
            get_status
            ;;
        "")
            # Écrire le PID
            echo $$ > "$PID_FILE"

            # Appliquer le verrouillage dès l'initialisation
            touch "$LOCK_FILE" 2>/dev/null || { echo "Erreur : impossible de créer fichier verrou"; exit 1; }

            # Démarrage
            echo "Démarrage du gestionnaire de fenêtres Hyprland (mode 3 fenêtres)"
            echo "Résolution: ${SCREEN_WIDTH}x${SCREEN_HEIGHT}"
            echo "Gaps: in=${GAPS_IN}, out=${GAPS_OUT}"
            echo "Zone utile: ${USABLE_WIDTH}x${USABLE_HEIGHT}"

            # Initialiser l'état
            local initial_count=$(get_tiling_window_count)
            if [ "$initial_count" -eq 3 ]; then
                echo "Initialisation: redimensionnement simple pour 3 fenêtres"
                simple_resize_3_windows
            else
                echo "Mode dwindle normal pour $initial_count fenêtres"
                update_status
            fi

            # Supprimer le verrou après l'initialisation
            rm -f "$LOCK_FILE" 2>/dev/null

            # Attendre pour ignorer les événements initiaux
            sleep 0.5

            # Démarrer la surveillance
            echo "Début de la surveillance hybride..."
            monitor_windows
            ;;
        *)
            echo "Usage: $0 [get_status]"
            exit 1
            ;;
    esac
}

main "$@"