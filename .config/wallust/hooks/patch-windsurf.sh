#!/usr/bin/env bash
# Injecte ~/.config/Windsurf/user.css dans le workbench Windsurf.
# À relancer après chaque mise à jour de Windsurf.

WORKBENCH="/usr/share/windsurf/resources/app/out/vs/code/electron-browser/workbench/workbench.html"
USER_CSS="$HOME/.config/Windsurf/user.css"
MARKER="<!-- windsurf-user-css -->"

if [[ ! -f "$USER_CSS" ]]; then
  echo "user.css introuvable : $USER_CSS"
  exit 1
fi

# Déjà patché ?
if grep -q "$MARKER" "$WORKBENCH" 2>/dev/null; then
  echo "Déjà patché, on remplace…"
  sudo python3 - "$WORKBENCH" "$USER_CSS" "$MARKER" << 'EOF'
import sys, re

wb_path, css_path, marker = sys.argv[1], sys.argv[2], sys.argv[3]
css = open(css_path).read()
html = open(wb_path).read()

block = f'\n\t\t{marker}\n\t\t<style>\n{css}\n\t\t</style>'
html = re.sub(
    rf'\n\t\t{re.escape(marker)}.*?</style>',
    block,
    html, flags=re.DOTALL
)
open(wb_path, 'w').write(html)
print("Mis à jour.")
EOF
else
  echo "Premier patch…"
  sudo python3 - "$WORKBENCH" "$USER_CSS" "$MARKER" << 'EOF'
import sys

wb_path, css_path, marker = sys.argv[1], sys.argv[2], sys.argv[3]
css = open(css_path).read()
html = open(wb_path).read()

inject = f'\n\t\t{marker}\n\t\t<style>\n{css}\n\t\t</style>\n\t</head>'
html = html.replace('\n\t</head>', inject, 1)
open(wb_path, 'w').write(html)
print("Patché.")
EOF
fi

echo "Redémarre Windsurf pour voir le résultat."
