# Calculatrice (qalculate) : résultat en direct, entrée copie le résultat
TEMPLATE=input
PROMPT="Calcul"
ICON="󰃬"
PLACEHOLDER="12*7 + 15 %, 3 km en miles, 2^10…"

live()      { [ -n "$1" ] && qalc -t -- "$1"; }
on_select() { copy "$1"; }
