#!/bin/bash

# Script pour lancer MuPDF avec des paramètres optimisés pour Hyprland
# Ce script ajuste temporairement le scroll_factor pour améliorer l'expérience de lecture

# Vérifier si hyprctl est disponible (c'est-à-dire si on est sous Hyprland)
if command -v hyprctl &> /dev/null; then
    # Sauvegarde de la valeur actuelle du scroll_factor
    CURRENT_SCROLL=$(hyprctl getoption input:scroll_factor | grep "float" | awk '{print $2}')

    # Si on n'a pas pu récupérer la valeur actuelle, on utilise 1.0 par défaut
    if [ -z "$CURRENT_SCROLL" ]; then
        CURRENT_SCROLL=1.0
    fi

    # Définir le nouveau scroll_factor pour MuPDF (ajustez cette valeur selon vos préférences)
    hyprctl keyword input:scroll_factor 10
fi

# Lancer MuPDF avec tous les arguments passés
mupdf "$@"
EXIT_CODE=$?

# Une fois MuPDF fermé, restaurer le scroll_factor original si on est sous Hyprland
if command -v hyprctl &> /dev/null; then
    hyprctl keyword input:scroll_factor $CURRENT_SCROLL
fi

exit $EXIT_CODE
