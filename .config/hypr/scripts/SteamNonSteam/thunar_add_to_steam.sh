#!/bin/bash
# =============================================================================
#  thunar_add_to_steam.sh — Action clic-droit Thunar : "Ajouter à Steam"
#
#  Appelé avec le chemin du .exe sélectionné (%f dans Thunar).
#  Demande juste le nom du jeu, fait tout le reste tout seul :
#  fermeture Steam -> ajout shortcut + artworks -> relance Steam.
#
#  Dépendances : zenity, notify-send, python3 (+ vdf, requests)
#  Installation : sudo pacman -S zenity libnotify   (déjà présent sur la plupart des DE)
# =============================================================================
set -euo pipefail

EXE_PATH="$1"
CONFIG_DIR="$HOME/.config/steam-nonsteam-adder"
API_KEY_FILE="$CONFIG_DIR/api_key"

# Adapte ce chemin si tu ranges le script Python ailleurs
PYTHON_SCRIPT="$HOME/.config/hypr/scripts/SteamNonSteam/add_nonsteam_games.py"

mkdir -p "$CONFIG_DIR"

if [ ! -f "$EXE_PATH" ]; then
  zenity --error --title="Ajouter à Steam" --text="Fichier introuvable :\n$EXE_PATH"
  exit 1
fi

if [ ! -f "$PYTHON_SCRIPT" ]; then
  zenity --error --title="Ajouter à Steam" \
    --text="Script introuvable :\n$PYTHON_SCRIPT\n\nModifie la variable PYTHON_SCRIPT dans thunar_add_to_steam.sh."
  exit 1
fi

# --- Clé API SteamGridDB : demandée une seule fois, puis réutilisée ---------
if [ ! -f "$API_KEY_FILE" ]; then
  API_KEY=$(zenity --entry --title="Clé API SteamGridDB" \
    --text="Colle ta clé API SteamGridDB (demandé une seule fois, stocké dans $API_KEY_FILE) :")
  [ -n "$API_KEY" ] || exit 1
  umask 177
  echo "$API_KEY" > "$API_KEY_FILE"
fi
API_KEY=$(cat "$API_KEY_FILE")

# --- Nom du jeu : pré-rempli avec le nom du dossier parent (souvent plus propre
#     que le nom de l'exe, ex: "Expedition 33" plutôt que "Expedition33_Steam") --
GAME_DIR=$(dirname "$EXE_PATH")
DEFAULT_NAME=$(basename "$GAME_DIR")

NAME=$(zenity --entry --title="Ajouter à Steam" \
  --text="Nom du jeu :" --entry-text="$DEFAULT_NAME")
[ -n "$NAME" ] || exit 0   # annulé par l'utilisateur

# --- JSON temporaire pour ce seul jeu ---------------------------------------
TMP_JSON=$(mktemp --suffix=.json)
trap 'rm -f "$TMP_JSON"' EXIT

python3 - "$NAME" "$EXE_PATH" "$GAME_DIR" "$TMP_JSON" <<'PYEOF'
import json, sys
name, exe, start_dir, out = sys.argv[1:5]
json.dump([{"name": name, "exe": exe, "start_dir": start_dir}], open(out, "w"))
PYEOF

# --- Fermer Steam si lancé (obligatoire pour ne pas perdre les changements) --
STEAM_WAS_RUNNING=0
if pgrep -x steam >/dev/null; then
  STEAM_WAS_RUNNING=1
  notify-send -i /home/florian/.config/swaync/icons/Steam_2.png "Steam" "Fermeture de Steam pour appliquer les changements..."
  steam -shutdown
  # Attend que Steam ait vraiment quitté (jusqu'à 15s)
  for _ in $(seq 1 15); do
    pgrep -x steam >/dev/null || break
    sleep 1
  done
fi

# --- Ajout + artworks --------------------------------------------------------
if python3 "$PYTHON_SCRIPT" --config "$TMP_JSON" --api-key "$API_KEY"; then
  notify-send -i /home/florian/.config/swaync/icons/Steam_2.png "Steam" "« $NAME » ajouté avec ses artworks."
else
  notify-send -i /home/florian/.config/swaync/icons/Steam_2.png -u critical "Steam" "Échec de l'ajout de « $NAME ». Voir le terminal pour le détail."
fi

# --- Relance Steam si on l'a fermé -------------------------------------------
if [ "$STEAM_WAS_RUNNING" = "1" ]; then
  nohup steam >/dev/null 2>&1 &
  disown
fi
