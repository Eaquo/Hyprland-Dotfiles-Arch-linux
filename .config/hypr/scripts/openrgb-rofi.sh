#!/bin/bash
# Script Rofi pour contrôler OpenRGB
# Utilisation: ./openrgb-rofi.sh

CONFIG_DIR="$HOME/.config/rofi"
CONTROLLER_SCRIPT="$HOME/.config/hypr/Openrgb/OpenRGB_Controller.py"
PID_FILE="/tmp/openrgb_controller.pid"
LOGDIR="$HOME/.config/hypr/Openrgb"

# Vérifications
if [ ! -f "$CONFIG_DIR/config-openrgb.rasi" ]; then
    echo "❌ Fichier config-openrgb.rasi manquant dans $CONFIG_DIR"
    exit 1
fi

if [ ! -f "$CONFIG_DIR/config-color-picker.rasi" ]; then
    echo "❌ Fichier config-color-picker.rasi manquant dans $CONFIG_DIR"
    exit 1
fi

if [ ! -f "$CONTROLLER_SCRIPT" ]; then
    echo "❌ Contrôleur OpenRGB manquant: $CONTROLLER_SCRIPT"
    exit 1
fi

# Fonction pour tuer le processus précédent
kill_previous() {
    if [ -f "$PID_FILE" ]; then
        local old_pid=$(cat "$PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            echo "🛑 Arrêt du processus précédent (PID: $old_pid)"
            kill "$old_pid"
            sleep 1
            # Force kill si nécessaire
            if kill -0 "$old_pid" 2>/dev/null; then
                kill -9 "$old_pid"
            fi
        fi
        rm -f "$PID_FILE"
    fi
    
    # Nettoyer tous les processus OpenRGB_Controller qui traînent
    pkill -f "OpenRGB_Controller.py" 2>/dev/null || true
}

# Options du menu avec icônes et descriptions dans l'ordre souhaité
declare -a menu_order=(
    "🌑 Mode OFF"
    "🌈 Séquence 1"
    "🌊 Séquence 2"
    "💨 Séquence 3"
    "🌆 Séquence 4"
    "👨🏻‍💻 Séquence 5"
    "🎨 Couleur fixe"
    "🔄 Recharger"
    "❌ Quitter"
)

declare -A options
options["🌑 Mode OFF"]="off|Éteindre toutes les lumières RGB"
options["🌈 Séquence 1"]="sequence_1|Animation originale avec LEDs aléatoires"
options["🌊 Séquence 2"]="sequence_2|Vagues de couleurs douces"
options["💨 Séquence 3"]="sequence_3|Effet de respiration synchronisé"
options["🌆 Séquence 4"]="sequence_4|Effet Cyberpunk"
options["👨🏻‍💻 Séquence 5"]="sequence_5|Effet Matrix"
options["🎨 Couleur fixe"]="color_picker|Choisir une couleur fixe"
options["🔄 Recharger"]="reload|Recharger les couleurs depuis wallust"
options["❌ Quitter"]="quit|Fermer le menu"

# Fonction pour le sélecteur de couleurs
show_color_picker() {
    # Palette de couleurs avec émojis et noms
    declare -a color_order=(
        "🔴 Rouge"
        "🟢 Vert" 
        "🔵 Bleu"
        "🩵 Cyan"
        "🟣 Magenta"
        "🟣 Violet"
        "🟡 Jaune"
        "⚪ Blanc"
        "🟠 Orange"
        "🩷 Rose"
        "🟢 Lime"
        "🔵 Azure"
    )
    
    declare -A color_options
    color_options["🔴 Rouge"]="fixed_rouge"
    color_options["🟢 Vert"]="fixed_vert"
    color_options["🔵 Bleu"]="fixed_bleu"
    color_options["🩵 Cyan"]="fixed_cyan"
    color_options["🟣 Magenta"]="fixed_magenta"
    color_options["🟡 Jaune"]="fixed_jaune"
    color_options["⚪ Blanc"]="fixed_blanc"
    color_options["🟠 Orange"]="fixed_orange"
    color_options["🟢 Violet"]="fixed_violet"
    color_options["🩷 Rose"]="fixed_rose"
    color_options["🟢 Lime"]="fixed_lime"
    color_options["🔵 Azure"]="fixed_azure"
    
    # Créer le contenu pour rofi
    local color_menu_content=""
    for color_name in "${color_order[@]}"; do
        color_menu_content+="$color_name\n"
    done
    
    # Afficher le sélecteur de couleurs
    local selected_color=$(echo -e "$color_menu_content" | rofi \
        -dmenu \
        -i \
        -p "Couleur RGB" \
        -theme "$CONFIG_DIR/config-color-picker.rasi" \
        -no-custom \
        -format "s")
    
    if [ -n "$selected_color" ]; then
        local color_action="${color_options[$selected_color]}"
        if [ -n "$color_action" ]; then
            echo "🎨 Activation couleur: $selected_color"
            kill_previous
            
            # Notification
            notify-send "🎨 OpenRGB Controller" "Couleur activée: $selected_color" -t 3000
            
            # Appliquer la couleur
            python3 "$CONTROLLER_SCRIPT" "$color_action"
            echo "✅ Couleur $selected_color appliquée"
        fi
    fi
}

# Créer le contenu pour rofi dans l'ordre défini
menu_content=""
for display_name in "${menu_order[@]}"; do
    menu_content+="$display_name\n"
done

# Afficher le menu rofi
selected=$(echo -e "$menu_content" | rofi \
    -dmenu \
    -i \
    -p "RGB Controller" \
    -theme "$CONFIG_DIR/config-openrgb.rasi" \
    -no-custom \
    -format "s")

# Traitement de la sélection
if [ -n "$selected" ]; then
    IFS='|' read -r action description <<< "${options[$selected]}"
    
    case "$action" in
        "off"|"sequence_1"|"sequence_2"|"sequence_3"|"sequence_4"|"sequence_5")
            echo "🎮 Activation du mode: $selected"
            kill_previous
            
            # Notification
            notify-send "🌈 OpenRGB Controller" "Mode activé: $selected" -t 3000
            
            if [ "$action" = "off" ]; then
                # Pour le mode OFF, pas besoin de processus permanent
                rm -f "$LOGDIR/sequence.txt"
                touch "$LOGDIR/sequence.txt"
                echo "$action" > "$LOGDIR/sequence.txt"
                python3 "$CONTROLLER_SCRIPT" "$action"
                echo "✅ Mode OFF appliqué"
            else
                # Pour les autres modes, lancer en arrière-plan
                rm -f "$LOGDIR/sequence.txt"
                touch "$LOGDIR/sequence.txt"
                echo "$action" > "$LOGDIR/sequence.txt"
                python3 "$CONTROLLER_SCRIPT" "$action" &
                echo $! > "$PID_FILE"
                echo "🚀 Mode $action démarré (PID: $!)"
            fi
            ;;
        "color_picker")
            echo "🎨 Ouverture du sélecteur de couleurs..."
            show_color_picker
            ;;
        "reload")
            echo "🔄 Rechargement des couleurs..."
            kill_previous
            # Redémarrer le dernier mode actif (ici on utilise sequence_1 par défaut)
            notify-send "🔄 OpenRGB Controller" "Couleurs rechargées depuis wallust" -t 3000
            python3 "$CONTROLLER_SCRIPT" "sequence_4" &
            echo $! > "$PID_FILE"
            ;;
        "quit")
            echo "❌ Fermeture du contrôleur"
            kill_previous
            notify-send "🛑 OpenRGB Controller" "Contrôleur arrêté" -t 2000
            ;;
        *)
            echo "❓ Action inconnue: $action"
            ;;
    esac
else
    echo "🚫 Aucune sélection"
fi