#!/bin/sh
# float_grid.sh — passe toutes les fenêtres du workspace courant en flottant
# et les range en grille (sans superposition), en tenant compte de la barre
# (reserved), des gaps et du scale du moniteur.
#
# Ce Hyprland route `dispatch` vers Lua (hl.dispatch) : on génère donc un chunk
# lua avec hl.dsp.window.{float,resize,move} et on l'exécute via `hyprctl eval`.

gap=12

ws=$(hyprctl -j activeworkspace | jq '.id')
mon=$(hyprctl -j activeworkspace | jq -r '.monitor')

# Géométrie + reserved [left, top, right, bottom] + scale du moniteur
set -- $(hyprctl -j monitors | jq -r --arg m "$mon" \
    '.[] | select(.name==$m) | "\(.x) \(.y) \(.width) \(.height) \(.scale) \(.reserved[0]) \(.reserved[1]) \(.reserved[2]) \(.reserved[3])"')
mx=$1; my=$2; mw=$3; mh=$4; sc=$5; rl=$6; rt=$7; rr=$8; rb=$9
[ -z "$mw" ] && exit 0

# Dimensions logiques (hyprctl monitors = pixels physiques)
mw=$(awk "BEGIN{printf \"%d\", $mw/$sc}")
mh=$(awk "BEGIN{printf \"%d\", $mh/$sc}")

# Zone utilisable (hors barre + gaps de bord)
ux=$((mx + rl + gap))
uy=$((my + rt + gap))
uw=$((mw - rl - rr - gap*2))
uh=$((mh - rt - rb - gap*2))

# Fenêtres mappées du workspace courant
addrs=$(hyprctl -j clients | jq -r --argjson ws "$ws" \
    '.[] | select(.workspace.id==$ws and .mapped==true) | .address')
n=$(printf '%s\n' "$addrs" | grep -c .)
[ "$n" -eq 0 ] && exit 0

# Grille : cols = ceil(sqrt(n)), rows = ceil(n/cols)
cols=$(awk "BEGIN{c=int(sqrt($n)); if(c*c<$n)c++; print c}")
rows=$(awk "BEGIN{print int(($n + $cols - 1)/$cols)}")

cellw=$(( (uw - (cols-1)*gap) / cols ))
cellh=$(( (uh - (rows-1)*gap) / rows ))

# Un SEUL chunk lua (les evals en rafale corrompent le buffer du socket).
# D'abord tout flotter, puis tout positionner.
lua=""
for a in $addrs; do
    lua="$lua hl.dispatch(hl.dsp.window.float({ action='set', window='address:$a' }));"
done
i=0
for a in $addrs; do
    r=$(( i / cols ))
    c=$(( i % cols ))
    x=$(( ux + c*(cellw+gap) ))
    y=$(( uy + r*(cellh+gap) ))
    lua="$lua hl.dispatch(hl.dsp.window.resize({ x=$cellw, y=$cellh, relative=false, window='address:$a' }));"
    lua="$lua hl.dispatch(hl.dsp.window.move({ x=$x, y=$y, relative=false, window='address:$a' }));"
    i=$((i+1))
done

hyprctl eval "$lua" >/dev/null 2>&1
