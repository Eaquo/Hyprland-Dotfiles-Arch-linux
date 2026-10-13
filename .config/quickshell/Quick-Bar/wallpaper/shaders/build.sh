#!/usr/bin/env bash
# Compile les shaders GLSL (.frag) en .qsb pour Qt6/Quickshell.
# Nécessite qt6-shadertools (fournit `qsb`).
set -e
cd "$(dirname "$0")"

# qsb n'est pas dans le PATH standard sur Arch (→ /usr/lib/qt6/bin/qsb)
QSB=$(command -v qsb || echo /usr/lib/qt6/bin/qsb)
[ -x "$QSB" ] || { echo "✖ qsb introuvable — installe qt6-shadertools"; exit 1; }

for f in *.frag; do
    [ -e "$f" ] || continue
    "$QSB" --qt6 -o "${f}.qsb" "$f"
    echo "✔ ${f} → ${f}.qsb"
done
