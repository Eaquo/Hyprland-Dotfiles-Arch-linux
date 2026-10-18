# Chercher un fichier dans le dossier personnel (aperçu à droite), entrée l'ouvre
TEMPLATE=files
ICON="󰉋"
PLACEHOLDER="Nom de fichier…"
NO_CUSTOM=1
TABS=("󰀻|apps|apps" "󰉋|files|files" "󰆍|term|command" "󰖯|window|windows")

live() {
    [ -n "$1" ] || { ls -t "$HOME"/Downloads/* "$HOME"/Documents/* 2>/dev/null | head -40; return; }
    fd -i --max-results 80 --exclude .cache --exclude .local/share/Steam "$1" "$HOME" 2>/dev/null
}
MESSAGE="entrée : ouvrir avec le bon programme  ·  ctrl+entrée : ouvrir avec…"
KEYS=("Control-Return")

# dossier → Thunar · fichier → le programme par défaut de son type (xdg-mime, ~/.config/mimeapps.list)
on_select() { if [ -d "$1" ]; then launch thunar "$1"; else open "$1"; fi; }
# ctrl+entrée : choisir parmi les programmes capables d'ouvrir ce type de fichier
on_key_1() {
    local f=$1 mime ids id app
    mime=$( [ -d "$f" ] && echo inode/directory || xdg-mime query filetype "$f" 2>/dev/null)
    ids=$(LC_ALL=C gio mime "$mime" 2>/dev/null | awk '/^Registered applications:/{r=1;next} /^[A-Z]/{r=0} r{print $1}')
    [ -z "$ids" ] && { notify "Aucun programme pour $mime"; return; }
    app=$(for id in $ids; do
            local d; d=$(find /usr/share/applications ~/.local/share/applications -name "$id" 2>/dev/null | head -1)
            [ -n "$d" ] && item "$(grep -m1 '^Name=' "$d" | cut -d= -f2-)" id="$id" icon="$(grep -m1 '^Icon=' "$d" | cut -d= -f2-)" sub="$mime"
          done | "$QBMENU" --template list -p "Ouvrir avec" --icon "󰏌" -mesg "$(basename "$f")" -no-custom)
    [ -n "$app" ] && setsid -f gtk-launch "${app%.desktop}" "$f" >/dev/null 2>&1
}
