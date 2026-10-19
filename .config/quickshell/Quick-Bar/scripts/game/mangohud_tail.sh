#!/usr/bin/env bash
# mangohud_tail.sh — FPS et temps de trame de la dernière ligne du journal MangoHud en cours
# (/tmp/qb-mangohud, écrit par game-core.sh). Rien si aucun journal frais (< 4 s).
f=$(ls -t /tmp/qb-mangohud/*.csv 2>/dev/null | head -1)
[ -n "$f" ] || exit 0
[ $(( $(date +%s) - $(stat -c %Y "$f") )) -lt 4 ] || exit 0
awk -F, '/^fps,/{for(i=1;i<=NF;i++){if($i=="fps")a=i;if($i=="frametime")b=i};h=1;next} h&&NF>2{l=$0} END{split(l,v,",");if(a)print v[a], v[b]}' "$f"
