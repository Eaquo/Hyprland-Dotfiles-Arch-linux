#!/bin/bash

# Configuration
SCRIPT_DIR="/home/florian/.config/hypr/Openrgb"
PYTHON_SCRIPT="$SCRIPT_DIR/OpenRGB_Controller.py"
LOG_FILE="$SCRIPT_DIR/openwal.log"
MAX_RETRIES=6  # Augmenté pour plus de tentatives
DEFAULT_PORT=6742
PORT_RANGE_MIN=6742
PORT_RANGE_MAX=65535
CURRENT_PORT=$DEFAULT_PORT

# Supprimer l'ancien fichier de log
rm -f "$LOG_FILE"

# Fonction de log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Vérifier et créer le répertoire si nécessaire
if [ ! -d "$SCRIPT_DIR" ]; then
    log "📁 Création du répertoire $SCRIPT_DIR"
    mkdir -p "$SCRIPT_DIR" || {
        log "❌ ERREUR: Impossible de créer le répertoire $SCRIPT_DIR"
        exit 1
    }
fi

# Attendre que le réseau soit disponible
log "⏳ Attente de la disponibilité du réseau..."
until ping -c 1 127.0.0.1 >/dev/null 2>&1; do
    sleep 1
done
log "✅ Réseau disponible"

# Fonction pour vérifier si un port est libre
check_port_available() {
    local port=$1
    ss -tuln | grep -q ":$port " && return 1 || return 0
}

# Fonction pour générer un port aléatoire
generate_random_port() {
    echo $((RANDOM % (PORT_RANGE_MAX - PORT_RANGE_MIN + 1) + PORT_RANGE_MIN))
}

# Fonction pour vérifier si OpenRGB server est disponible
check_openrgb_server() {
    local port=${1:-$DEFAULT_PORT}
    local output
    local args=""
    [ "$port" != "$DEFAULT_PORT" ] && args="--client --port $port"
    output=$(openrgb $args --autostart-check 2>&1)
    log "🔍 Sortie de openrgb --autostart-check: $output"  # Débogage
    
    if echo "$output" | grep -q "Connected to server"; then
        log "✅ OpenRGB server connecté sur le port $port (via --autostart-check)"
        CURRENT_PORT=$port
        return 0
    elif ss -tuln | grep -q ":$port " && pgrep -f "openrgb.*--server-port $port" >/dev/null; then
        log "✅ OpenRGB server détecté sur le port $port (via ss et PID)"
        CURRENT_PORT=$port
        return 0
    else
        log "❌ OpenRGB server non disponible sur le port $port"
        return 1
    fi
}

# Fonction pour démarrer OpenRGB server
start_openrgb_server() {
    local port=${1:-$DEFAULT_PORT}
    
    log "🚀 Démarrage d'OpenRGB server sur le port $port..."
    
    # Arrêter les processus OpenRGB existants si nécessaire
    if pgrep -x "openrgb" >/dev/null; then
        log "🔄 Arrêt des processus OpenRGB existants..."
        pkill -x "openrgb"
        sleep 2
    fi
    
    # Vérifier si le port est libre
    if ! check_port_available "$port"; then
        log "⚠️ Port $port occupé, tentative avec un autre port"
        return 1
    fi
    
    # Démarrer le serveur
    local args=""
    [ "$port" != "$DEFAULT_PORT" ] && args="--server --server-port $port"
    openrgb $args --startminimized &
    local server_pid=$!
    log "📡 OpenRGB server démarré (PID: $server_pid)"
    
    # Attendre que le serveur soit prêt
    local retry_count=0
    while [ $retry_count -lt $MAX_RETRIES ]; do
        sleep 3  # Augmenté à 3 secondes pour plus de stabilité
        if check_openrgb_server "$port"; then
            log "✅ OpenRGB server prêt sur le port $port"
            return 0
        fi
        retry_count=$((retry_count + 1))
    done
    
    log "❌ ERREUR: OpenRGB server non démarré après $MAX_RETRIES tentatives"
    return 1
}

# Fonction pour démarrer le serveur avec port aléatoire si nécessaire
start_openrgb_with_random_fallback() {
    log "🔍 Démarrage d'OpenRGB server..."
    
    # Essayer le port par défaut
    if check_port_available "$DEFAULT_PORT" && start_openrgb_server "$DEFAULT_PORT"; then
        return 0
    fi
    
    # Essayer un port aléatoire
    log "🎲 Port par défaut occupé, recherche d'un port aléatoire..."
    local random_port=$(generate_random_port)
    if check_port_available "$random_port" && start_openrgb_server "$random_port"; then
        log "🎉 OpenRGB server démarré sur le port aléatoire $random_port"
        return 0
    fi
    
    log "💥 ERREUR: Impossible de démarrer OpenRGB server"
    return 1
}

# Vérifier l'état du serveur OpenRGB
log "🔍 Vérification de l'état d'OpenRGB..."
if check_openrgb_server "$DEFAULT_PORT"; then
    log "🎯 OpenRGB server déjà actif sur le port $DEFAULT_PORT"
else
    log "🚀 Aucun serveur détecté, démarrage..."
    if ! start_openrgb_with_random_fallback; then
        log "💥 ERREUR CRITIQUE: Impossible de démarrer OpenRGB"
        exit 1
    fi
fi

# Vérifier les fichiers nécessaires
if [ ! -f "$PYTHON_SCRIPT" ]; then
    log "❌ ERREUR: Script Python non trouvé: $PYTHON_SCRIPT"
    exit 1
fi

WALLUST_FILE="/home/florian/.config/hypr/Openrgb/wal_rgb.json"
[ -f "$WALLUST_FILE" ] && log "📁 Fichier wallust trouvé" || log "⚠️ Fichier wallust non trouvé"

# Changer de répertoire
cd "$SCRIPT_DIR" || {
    log "❌ ERREUR: Impossible d'accéder à $SCRIPT_DIR"
    exit 1
}
#Supression /Creation du fichier current_port.txt
rm -f "$SCRIPT_DIR/current_port.txt"
touch "$SCRIPT_DIR/current_port.txt"

# Vérifier les périphériques RGB
log "🔌 Vérification des périphériques RGB..."
local args=""
[ "$CURRENT_PORT" != "$DEFAULT_PORT" ] && args="--client --port $CURRENT_PORT"
device_output=$(openrgb $args --list-devices 2>/dev/null)
device_count=$(echo "$device_output" | grep -c "Device" || echo "0")
log "📱 Périphériques RGB détectés: $device_count"

# Sauvegarder le port avec gestion d'erreur
log "💾 Tentative de sauvegarde du port $CURRENT_PORT dans $SCRIPT_DIR/current_port.txt"
if ! echo "$CURRENT_PORT" > "$SCRIPT_DIR/current_port.txt" 2>>"$LOG_FILE"; then
    log "❌ ERREUR: Impossible d'écrire dans $SCRIPT_DIR/current_port.txt"
    exit 1
else
    log "✅ Port $CURRENT_PORT sauvegardé dans $SCRIPT_DIR/current_port.txt"
fi

# Vérifier que le fichier a été créé correctement
if [ -f "$SCRIPT_DIR/current_port.txt" ]; then
    log "📄 Fichier current_port.txt vérifié, contenu: $(cat "$SCRIPT_DIR/current_port.txt")"
else
    log "❌ ERREUR: Fichier current_port.txt non créé"
    exit 1
fi

# Lancer le script Python
log "🐍 Lancement du script Python OpenWal..."
SEQ=$(cat $SCRIPT_DIR/sequence.txt)
log "Sequence du fichier de config: $SEQ"
if [ -z "$SEQ" ]; then
    SEQ="sequence_1"
fi
python3 "$SCRIPT_DIR/OpenRGB_Controller_Watch.py" 2>&1 | tee -a "$LOG_FILE" &
log "✅ Script Python démarré en arrière-plan"

# Nettoyage à la sortie
trap 'log "🧹 Nettoyage..."' EXIT INT TERM