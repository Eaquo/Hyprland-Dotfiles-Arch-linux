#!/usr/bin/env bash
# Rebuild hy3 pour la version Hyprland courante.
# Contourne le bug hyprpm qui prend hy3 master (incompatible) au lieu du tag de ta version
# — typiquement parce que le commit de ton build Hyprland n'est pas dans les "pins" de hy3.
# À relancer après chaque mise à jour de Hyprland.
set -e

ver=$(hyprctl version | grep -oP 'Tag:\s*v\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
[ -z "$ver" ] && { echo "✖ version Hyprland introuvable"; exit 1; }
minor=$(echo "$ver" | cut -d. -f1,2)          # ex. 0.55
echo "Hyprland $ver (branche $minor)"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
echo "→ clone hy3…"
git clone --quiet https://github.com/outfoxxed/hy3 "$tmp/hy3"
cd "$tmp/hy3"

# tag hy3 le plus récent pour cette version mineure (ex. hl0.55*), sinon hl<minor>.0
tag=$(git tag -l "hl${minor}*" | sort -V | tail -1)
[ -z "$tag" ] && tag="hl${minor}.0"
echo "→ tag hy3: $tag"
git checkout --quiet "$tag"

echo "→ compilation…"
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build build >/dev/null

mkdir -p "$HOME/.config/hypr/plugins"
cp build/libhy3.so "$HOME/.config/hypr/plugins/libhy3.so"
echo "✔ installé: ~/.config/hypr/plugins/libhy3.so"

# recharge à chaud
hyprctl plugin unload "$HOME/.config/hypr/plugins/libhy3.so" 2>/dev/null || true
hyprctl plugin load   "$HOME/.config/hypr/plugins/libhy3.so" >/dev/null 2>&1 || true
if hyprctl plugins list | grep -qi hy3; then
    echo "✔ hy3 chargé (tag $tag)"
else
    echo "✖ échec de chargement — vérifie 'hyprctl plugins list'"
fi
