#!/bin/bash
# ~/.config/hypr/UserScripts/Monitor/waybar_window_manager.sh
# Module Waybar pour afficher et contrôler le gestionnaire de fenêtres dans Hyprland

# Paramètres de configuration
PID_FILE="/tmp/hypr_window_manager.pid"
STATUS_FILE="/tmp/hypr_window_manager_status.txt"
EVENT_TRIGGER_FILE="/tmp/hypr_wm_event_trigger"
SCRIPT_NAME="window_manager.sh"
SOCKET_PATH="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
START_TIMEOUT=50  # 50 x 0.1s = 5s max
EVENT_STABILIZATION_DELAY=0.3  # Délai après un événement (en secondes)
DEBUG_LOG="/tmp/waybar_window_manager.log"

# Activer le mode débogage si DEBUG=1
DEBUG=${DEBUG:-0}

log_debug() {
    if [[ $DEBUG -eq 1 ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$DEBUG_LOG"
    fi
}

# Vérifier les dépendances
check_dependencies() {
    local deps=("jq" "hyprctl" "pgrep" "pkill")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo "Erreur : dépendance '$dep' non installée."
            log_debug "Erreur : dépendance '$dep' non installée."
            exit 1
        fi
    done
}

# Vérifier l'environnement Hyprland
check_hyprland_env() {
    if [[ -z "$XDG_RUNTIME_DIR" || -z "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
        echo "Erreur : environnement Hyprland non détecté (XDG_RUNTIME_DIR ou HYPRLAND_INSTANCE_SIGNATURE manquant)."
        log_debug "Erreur : environnement Hyprland non détecté."
        exit 1
    fi
    if [[ ! -S "$SOCKET_PATH" ]]; then
        echo "Erreur : socket Hyprland ($SOCKET_PATH) inaccessible."
        log_debug "Erreur : socket Hyprland ($SOCKET_PATH) inaccessible."
        exit 1
    fi
}

# Fonction pour vérifier si le gestionnaire est actif
is_manager_active() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [[ -n "$pid" ]] && pgrep -x "$SCRIPT_NAME" -P "$pid" >/dev/null 2>&1 || pgrep -f "$SCRIPT_NAME" >/dev/null 2>&1; then
            log_debug "Gestionnaire actif (PID: $pid)"
            return 0  # Actif
        fi
    fi
    log_debug "Gestionnaire inactif"
    return 1  # Inactif
}

# Fonction pour tuer tous les processus liés au gestionnaire
kill_all_manager_processes() {
    log_debug "Arrêt de tous les processus du gestionnaire"
    echo "Arrêt de tous les processus du gestionnaire..."

    if [[ -f "$PID_FILE" ]]; then
        local main_pid=$(cat "$PID_FILE" 2>/dev/null)
        if [[ -n "$main_pid" ]] && kill -0 "$main_pid" 2>/dev/null; then
            echo "Arrêt du processus principal (PID: $main_pid)"
            kill -TERM "$main_pid" 2>/dev/null || kill -KILL "$main_pid" 2>/dev/null
        fi
        rm -f "$PID_FILE" 2>/dev/null
    fi

    pkill -f "$SCRIPT_NAME" 2>/dev/null || true
    pkill -f "socat.*hypr.*socket2.sock" 2>/dev/null || true
    rm -f "$STATUS_FILE" "$EVENT_TRIGGER_FILE" 2>/dev/null || true

    local timeout=10
    while [ $timeout -gt 0 ] && pgrep -f "$SCRIPT_NAME" >/dev/null 2>&1; do
        sleep 0.1
        timeout=$((timeout - 1))
    done

    if pgrep -f "$SCRIPT_NAME" >/dev/null 2>&1; then
        echo "Nettoyage forcé..."
        pkill -9 -f "$SCRIPT_NAME" 2>/dev/null || true
        pkill -9 -f "socat.*hypr.*socket2.sock" 2>/dev/null || true
    fi

    echo "Gestionnaire arrêté"
    log_debug "Gestionnaire arrêté"
}

# Fonction pour démarrer le gestionnaire
start_manager() {
    log_debug "Démarrage du gestionnaire"
    echo "Démarrage du gestionnaire..."
    ~/.config/hypr/UserScripts/Monitor/window_manager.sh >/dev/null 2>&1 &

    local timeout=$START_TIMEOUT
    while [ $timeout -gt 0 ] && ! is_manager_active; do
        sleep 0.1
        timeout=$((timeout - 1))
    done

    if is_manager_active; then
        echo "Gestionnaire démarré avec succès"
        log_debug "Gestionnaire démarré avec succès"
    else
        echo "Erreur : impossible de démarrer le gestionnaire"
        log_debug "Erreur : impossible de démarrer le gestionnaire"
        return 1
    fi
}

# Fonction pour basculer l'état du gestionnaire
toggle_manager() {
    if is_manager_active; then
        kill_all_manager_processes
    else
        start_manager
    fi
}

# Fonction pour obtenir l'état actuel des fenêtres
get_window_state() {
    if ! is_manager_active; then
        log_debug "Gestionnaire inactif, retour à l'état dwindle"
        echo "dwindle"
        return
    fi

    # Attendre brièvement pour s'assurer que le fichier de statut est à jour
    sleep 0.1
    if [[ -f "$STATUS_FILE" ]]; then
        local status=$(cat "$STATUS_FILE" 2>/dev/null)
        if [[ -n "$status" ]]; then
            log_debug "État lu depuis $STATUS_FILE : $status"
            echo "$status"
            return
        fi
    fi

    log_debug "Échec de la lecture de $STATUS_FILE, mise à jour forcée"
    status=$("$HOME/.config/hypr/UserScripts/Monitor/window_manager.sh" get_status 2>/dev/null)
    if [[ $? -eq 0 && -n "$status" ]]; then
        log_debug "État obtenu via window_manager.sh : $status"
        echo "$status"
    else
        log_debug "Échec de la récupération de l'état via window_manager.sh, retour à dwindle"
        echo "dwindle"
    fi
}

# Fonction pour générer la sortie JSON pour Waybar
generate_waybar_output() {
    local state=$(get_window_state)
    local text=""
    local tooltip=""
    local class=""

    log_debug "Génération de la sortie Waybar pour l'état : $state"

    case "$state" in
        "dwindle")
            text="󱇙"
            tooltip="Mode Dwindle"
            class="dwindle"
            ;;
        "managed-3")
            text="󱒑"
            tooltip="Mode Ultrawide"
            class="managed active"
            ;;
        "managed-normal")
            text="󱇚"
            tooltip="Mode Dwindle"
            class="managed normal"
            ;;
        *)
    esac

    printf '{"text":"%s","tooltip":"%s","class":"%s"}' "$text" "$tooltip" "$class"
}

# Fonction pour forcer la mise à jour du statut
force_status_update() {
    if is_manager_active; then
        log_debug "Forçage de la mise à jour du statut"
        echo "FORCE_UPDATE" > "$EVENT_TRIGGER_FILE" 2>/dev/null || log_debug "Erreur : impossible d'écrire dans $EVENT_TRIGGER_FILE"
        sleep "$EVENT_STABILIZATION_DELAY"
    fi
}

# Fonction principale
main() {
    check_dependencies
    check_hyprland_env

    case "${1:-}" in
        "toggle")
            toggle_manager
            sleep "$EVENT_STABILIZATION_DELAY"
            force_status_update
            sleep "$EVENT_STABILIZATION_DELAY"
            generate_waybar_output
            ;;
        "status"|"")
            generate_waybar_output
            ;;
        "kill"|"stop")
            kill_all_manager_processes
            generate_waybar_output
            ;;
        "start")
            start_manager
            sleep "$EVENT_STABILIZATION_DELAY"
            force_status_update
            sleep "$EVENT_STABILIZATION_DELAY"
            generate_waybar_output
            ;;
        *)
            echo "Usage: $0 [toggle|status|kill|stop|start]"
            exit 1
            ;;
    esac
}

main "$@"