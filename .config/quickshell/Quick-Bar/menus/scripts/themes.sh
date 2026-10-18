# Palettes wallust prêtes à l'emploi : aperçu des couleurs, entrée applique à tout le système
TEMPLATE=theme
PROMPT="Palettes"
ICON="󰏘"
COLUMNS=4
NO_CUSTOM=1

THEMES=(Catppuccin-Mocha Tokyo-Night Nord Gruvbox-Dark Dracula Rosé-Pine Everforest-Dark-Medium Kanagawa-Wave
        One-Dark Solarized-Dark Synthwave Oxocarbon-Dark)

items() {
    local t c
    for t in "${THEMES[@]}"; do
        c=$(wallust theme -p "$t" 2>/dev/null | head -1 | grep -oP '48;2;\K[0-9;]+(?=m)' | awk -F';' '{printf "#%02x%02x%02x,", $1, $2, $3}')
        item "$t" colors="${c%,}"
    done
}
on_select() { wallust theme -q "$1" && "$HOME/.config/hypr/scripts/Refresh.sh"; }
