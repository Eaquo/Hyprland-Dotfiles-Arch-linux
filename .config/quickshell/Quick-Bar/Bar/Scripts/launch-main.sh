#!/bin/bash
# Lance une app sur l'écran PRINCIPAL (pas le tactile Xeneon), même quand le
# focus est sur le tactile (sinon l'app s'ouvre sur le workspace du tactile, sous
# le plein écran de Quick-Bar).
#
# Hyprland en config Lua → on passe par `hl.exec_cmd(cmd, { workspace = "N silent" })`
# via `hyprctl eval`. On cible le workspace actif de l'écran non-XENEON.
#
# Usage: launch-main.sh <commande…>

CMD="$*"
[ -z "$CMD" ] && exit 0

MAINWS=$(hyprctl -j monitors 2>/dev/null | jq -r \
  '[.[] | select((.model + .description | ascii_upcase | contains("XENEON")) | not)][0].activeWorkspace.id')

# Fallback : pas d'info moniteur → lancement normal.
if [ -z "$MAINWS" ] || [ "$MAINWS" = "null" ]; then
  exec $CMD
fi

hyprctl eval "hl.exec_cmd([[${CMD}]], { workspace = [[${MAINWS} silent]] })" >/dev/null 2>&1
