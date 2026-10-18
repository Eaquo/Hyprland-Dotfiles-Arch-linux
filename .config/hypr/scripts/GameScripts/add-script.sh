#!/bin/bash
# =============================================================================
#  add-script.sh — (Re)lie les scripts de JEU dans le PATH (/usr/local/bin)
#
#  - Symlinke uniquement les scripts de jeu exécutables.
#  - Exclut les utilitaires (assistant new-game, base, lui-même) et le dossier lib/.
#  - Nettoie les symlinks orphelins (jeux supprimés ou exclus).
# =============================================================================

SOURCE_DIR="/home/florian/.config/hypr/scripts/GameScripts"
DEST_DIR="/usr/local/bin"
SCRIPTS_ROOT=$(dirname "$SOURCE_DIR")   # .../hypr/scripts — pour reconnaître nos symlinks (même après renommage)

# Fichiers à NE PAS exposer comme commande de jeu
EXCLUDE=(
  "add-script.sh"
  "new-game"
  "Base_Script_Game"
)

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Erreur : le répertoire source $SOURCE_DIR n'existe pas." >&2
  exit 1
fi

is_excluded() {
  local name="$1" e
  for e in "${EXCLUDE[@]}"; do
    [ "$name" = "$e" ] && return 0
  done
  return 1
}

# --- 1. (Re)création des symlinks pour les jeux ------------------------------
linked=0
for script in "$SOURCE_DIR"/*; do
  [ -f "$script" ] && [ -x "$script" ] || continue   # ignore lib/ (dossier) & non-exécutables
  name=$(basename "$script")
  is_excluded "$name" && continue
  sudo ln -sf "$script" "$DEST_DIR/$name"
  echo "  + $name"
  ((linked++))
done

# --- 2. Nettoyage des symlinks orphelins ou exclus ---------------------------
pruned=0
for link in "$DEST_DIR"/*; do
  [ -L "$link" ] || continue
  target=$(readlink "$link")
  case "$target" in
    "$SCRIPTS_ROOT"/*) ;;    # symlink pointant dans notre arborescence de scripts (ancien ou nouveau chemin)
    *) continue ;;
  esac
  name=$(basename "$link")
  # supprime si : cible disparue (ancien dossier renommé), exclu, ou ne pointe plus vers le dossier courant
  if [ ! -e "$target" ] || is_excluded "$name" || [[ "$target" != "$SOURCE_DIR"/* ]]; then
    sudo rm -f "$link"
    echo "  - $name (orphelin/exclu)"
    ((pruned++))
  fi
done

echo
echo "Jeux liés : $linked   |   Symlinks nettoyés : $pruned"
