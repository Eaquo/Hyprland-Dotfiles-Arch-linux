# Lancer une commande (comme rofi -show run) ; maj+entrée la lance dans un terminal
TEMPLATE=input
ICON="󰆍"
PLACEHOLDER="Commande…"
TABS=("󰀻|apps|apps" "󰉋|files|files" "󰆍|term|command" "󰖯|window|windows")

live()      { [ -n "$1" ] && compgen -c -- "$1" | sort -u | head -30; }
on_select() { [ -n "$1" ] && launch sh -c "$1"; }
