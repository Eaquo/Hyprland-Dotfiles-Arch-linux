#!/usr/bin/env bash
# sync.sh — remet la sauvegarde à jour depuis la config en place (~/.config).
# Ne recopie que les dossiers déjà suivis ici (.config/*) ; un fichier supprimé chez toi l'est aussi ici.
# Jamais copiés : secrets (user_data/, tokens), caches, journaux, copies .bak.
#   ./sync.sh          aperçu (rien n'est modifié)
#   ./sync.sh --go     synchronise ; ensuite : git add -A && git commit && git push
set -euo pipefail
cd "$(dirname "$0")"

EXCLUDES=(
    --exclude 'user_data/' --exclude '.claude/' --exclude '.claude-history/' --exclude 'graphify-out/'
    --exclude '.discord_token' --exclude '.dl_secret'
    --exclude '__pycache__/' --exclude '*.pyc' --exclude '.git/'
    --exclude '*.bak' --exclude '*.bak-*' --exclude '*.bak.*' --exclude '*.log' --exclude '*.lock' --exclude '*.tmp'
    --exclude 'cache/' --exclude '*_OLD/' --exclude '*.so'
)
DRY=(--dry-run --itemize-changes)
[[ "${1:-}" == "--go" ]] && DRY=()

for d in .config/*; do
    n=${d#.config/}
    src="$HOME/.config/$n"
    [[ -e "$src" ]] || { echo "  (absent chez toi, gardé tel quel) $n"; continue; }
    if [[ -d "$src" ]]; then
        rsync -a --delete "${DRY[@]}" "${EXCLUDES[@]}" "$src/" "$d/" | sed "s|^|$n: |"
    else
        rsync -a "${DRY[@]}" "$src" "$d" | sed "s|^|$n: |"
    fi
done

# hors ~/.config : thème GTK (sources scss + css compilé, sans node_modules) et scripts maison de ~/.local/bin
rsync -a --delete "${DRY[@]}" "${EXCLUDES[@]}" --exclude 'node_modules/' --exclude '.idea/' \
    "$HOME/.themes/gtk/" .themes/gtk/ | sed "s|^|themes/gtk: |"
mkdir -p .local/bin
for f in thunar-zip send-to-jellyfin avalon-wallust fusion360 fusion-idmgr; do
    [[ -e "$HOME/.local/bin/$f" ]] && rsync -a "${DRY[@]}" "$HOME/.local/bin/$f" .local/bin/ | sed "s|^|local/bin: |"
done

if [[ ${#DRY[@]} -eq 0 ]]; then
    # garde-fou : rien qui ressemble à un secret dans ce qui va partir
    git add -A
    if git diff --cached | grep -qiE '^\+.*(password *[=:]|passwd|api[_-]?key *[=:]|BEGIN [A-Z ]*PRIVATE KEY|xox[bp]-|ghp_[A-Za-z0-9]{20})'; then
        echo "⚠ secret possible dans les changements — vérifie avec : git diff --cached" >&2
        exit 1
    fi
    git status --short | tail -n 40
    echo "Prêt : git commit -m '…' && git push"
fi
