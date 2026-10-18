# Emojis : chercher en anglais (smile, heart, cat…), entrée copie — SUPER+ALT+E
TEMPLATE=emoji
PROMPT="Emoji"
ICON="󰞅"
PLACEHOLDER="smile, heart, cat, fire…"
NO_CUSTOM=1

items() { sed '1,/^# # DATA # #$/d' "$HOME/.config/hypr/scripts/RofiEmoji.sh"; }
on_select() { copy "${1%% *}"; }
