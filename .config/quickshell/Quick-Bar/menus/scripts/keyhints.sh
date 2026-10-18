# Aide-mémoire des raccourcis clavier — SUPER+H
TEMPLATE=info
PROMPT="Raccourcis"
ICON="󰌌"
PLACEHOLDER="Filtrer : wallpaper, SHIFT, jeu…"

# la liste vit dans ~/.config/hypr/scripts/KeyHints.sh (triplets touche / description / commande)
items() {
    python3 - "$HOME/.config/hypr/scripts/KeyHints.sh" <<'PY'
import shlex, sys
src = open(sys.argv[1]).read().split("--timeout-indicator=bottom", 1)[-1]
rows = []
for line in src.splitlines()[1:]:          # les lignes de la liste finissent par « \ »
    rows.append(line.rstrip().rstrip("\\"))
    if not line.rstrip().endswith("\\"):
        break
parts = shlex.split(" ".join(rows))
for k, d, c in zip(parts[0::3], parts[1::3], parts[2::3]):
    if k.startswith("━"):
        print(k + "\0nonselectable\x1ftrue")
    elif k.strip() and k not in ("ESC", " = "):
        k = ("SUPER " + k.strip()) if k.startswith(" ") else k.strip()
        print(f"{k}\t{d}\t{c.strip('()')}")
PY
}
on_select() { :; }
