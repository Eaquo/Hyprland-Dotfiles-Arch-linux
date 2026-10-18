# Scripts de jeux (gamescope, MangoHud…) : ouvrir, créer, modifier le modèle — SUPER+MAJ+G
TEMPLATE=grid
PROMPT="Scripts de jeux"
ICON="󰊴"
PLACEHOLDER="Chercher un jeu…"
MESSAGE="󰊴  (~/.config/hypr/scripts/GameScripts)"
COLUMNS=5
NO_CUSTOM=1

DIR="$HOME/.config/hypr/scripts/GameScripts"
HIDE=" Base_Script_Game add-script.sh new-game "

items() {
    local names=() f n
    for f in "$DIR"/*; do
        n=$(basename "$f")
        [ -f "$f" ] && [ -x "$f" ] && [[ $HIDE != *" $n "* ]] && names+=("$n")
    done
    # jaquette du game-launcher dont le nom contient tous les mots du script (Elden_Mod → Elden Ring_Mod)
    python3 "$HOME/.config/quickshell/game-launcher/modules/service/backend.py" 2>/dev/null | python3 -c '
import json, re, sys
games = [(re.sub(r"[^a-z0-9]", "", g["name"].lower()), g.get("image", "")) for g in json.load(sys.stdin).get("games", [])]
for n in sys.argv[1:]:
    words = [w.lower() for w in re.findall(r"[A-Z]?[a-z]+|[0-9]+|[A-Z]+(?![a-z])", n)]
    hit = sorted((len(g), img) for g, img in games if img and all(w in g for w in words))
    print(n + "\t" + (hit[0][1] if hit else ""))' "${names[@]}" |
    while IFS=$'\t' read -r n img; do
        if [ -n "$img" ]; then item "$n" id="$DIR/$n" icon="$img"; else item "$n" id="$DIR/$n" glyph="󰊴"; fi
    done
    item "Nouveau script" id=new glyph="󰐕"
    item "Modèle de base" id=base glyph="󰈙"
    item "Mettre à jour Steam" id=update glyph="󰑓"
}

on_select() {
    case $1 in
        new)    term -e "$DIR/new-game" ;;
        base)   edit "$DIR/Base_Script_Game" ;;
        update) term --hold -e "$DIR/add-script.sh" ;;
        *)      edit "$1" ;;
    esac
}
