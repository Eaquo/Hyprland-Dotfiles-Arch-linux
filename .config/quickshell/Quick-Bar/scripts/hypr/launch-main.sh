#!/bin/bash
# Lance une app sur l'écran PRINCIPAL (pas le tactile Xeneon), même quand le
# focus est sur le tactile (sinon l'app s'ouvre sur le workspace du tactile, sous
# le plein écran de Quick-Bar).
#
# Hyprland en config Lua → on passe par `hl.exec_cmd(cmd, { workspace = "N silent" })`
# via `hyprctl eval`. On cible le workspace actif de l'écran non tactile (QB_TOUCH, « XENEON » par défaut).
#
# Usage: launch-main.sh <commande…>

# Un seul argument = une ligne de commande shell (« kitty -e htop », « a || b »), passée telle quelle ;
# plusieurs = des arguments, chacun protégé (espaces dans un chemin, -c "lua …" de nvim…).
if [ $# -eq 1 ]; then CMD=$1; else CMD=$(printf '%q ' "$@"); fi
[ -z "$CMD" ] && exit 0

MAINWS=$(hyprctl -j monitors 2>/dev/null | jq -r --arg t "$(printf %s "${QB_TOUCH:-XENEON}" | tr a-z A-Z)" \
  '[.[] | select((.model + .description | ascii_upcase | contains($t)) | not)][0].activeWorkspace.id')

# Fallback : pas d'info moniteur → lancement normal.
if [ -z "$MAINWS" ] || [ "$MAINWS" = "null" ]; then
  exec $CMD
fi

hyprctl eval "hl.exec_cmd([==[${CMD}]==], { workspace = [[${MAINWS} silent]] })" >/dev/null 2>&1
