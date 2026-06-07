#!/bin/bash

# URL de la page de planning
PLANNING_URL="https://anime-sama.fr/planning/"

# Récupérer la page
PAGE_CONTENT=$(curl -s "$PLANNING_URL")

# Fonction pour extraire les animes du jour
extract_today_releases() {
    # Obtenir l'heure actuelle
    CURRENT_HOUR=$(date +%H)
    CURRENT_MINUTE=$(date +%M)
    CURRENT_TIME="${CURRENT_HOUR}h${CURRENT_MINUTE}"
    
    # Extraire les informations des cartes d'anime
    echo "$PAGE_CONTENT" | grep -oP '(?<=<h1 class="text-gray-200 font-semibold text-sm text-center uppercase line-clamp-2 md:line-clamp-3 hover:text-clip">).*?(?=</h1>)' | while read -r titre; do
        # Chercher l'heure correspondante
        heure=$(echo "$PAGE_CONTENT" | grep -A 10 -B 10 "$titre" | grep -oP '(?<=Heure">)[^<]*' | head -1)
        
        # Chercher le type (VOSTFR/VF)
        type=$(echo "$PAGE_CONTENT" | grep -A 10 -B 10 "$titre" | grep -oP '(?<=uppercase mx-0.5 mt-1 px-1 py-0.5">)[^<]*' | head -1)
        
        if [[ "$heure" != "?" && "$heure" != "" ]]; then
            echo "$titre - $heure ($type)"
        fi
    done
}

# Fonction pour extraire uniquement les sorties du jour avec heure proche
extract_upcoming_releases() {
    CURRENT_HOUR=$(date +%H)
    
    echo "🎬 Sorties d'anime aujourd'hui :"
    echo "================================"
    
    # Extraire et trier par heure
    extract_today_releases | sort -t'-' -k2 | while read -r line; do
        if [[ "$line" != *"Reporté"* && "$line" != *"?"* ]]; then
            echo "• $line"
        fi
    done
    
    # Afficher les reports
    echo ""
    echo "⚠️ Reports :"
    echo "============"
    echo "$PAGE_CONTENT" | grep -oP '(?<=opacity-50">).*?(?=</h1>)' | while read -r titre_reporte; do
        echo "• $titre_reporte - Reporté"
    done
}

# Exécuter et envoyer notification
RELEASES=$(extract_upcoming_releases)

if command -v notify-send &> /dev/null; then
    notify-send "Planning Anime du jour" "$RELEASES" -t 10000
else
    echo "$RELEASES"
fi

# Optionnel : sauvegarder dans un fichier log
echo "$(date): $RELEASES" >> ~/anime_releases.log
