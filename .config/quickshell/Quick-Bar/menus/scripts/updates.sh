# Mises à jour du système : la liste des paquets (dépôts et AUR), tout mettre à jour, voir un paquet
TEMPLATE=list
PROMPT="Mises à jour"
ICON="󰚰"
WIDTH=1000
PLACEHOLDER="Chercher un paquet…"
NO_CUSTOM=1

items() {
    local repo aur
    repo=$(checkupdates 2>/dev/null); aur=$(paru -Qua 2>/dev/null)
    local n=$(( $(grep -c . <<<"$repo") + $(grep -c . <<<"$aur") ))
    if [ "$n" -eq 0 ]; then item "Le système est à jour" id=none glyph="󰄬" sub="rien à installer"; return; fi
    item "Tout mettre à jour" id=all glyph="󰚰" sub="$n paquet(s) · dans un terminal"
    if [ -n "$repo" ]; then
        section "Dépôts officiels"
        while read -r name from _ to; do item "$name	$from → $to" id="repo:$name" glyph="󰏗"; done <<<"$repo"
    fi
    if [ -n "$aur" ]; then
        section "AUR"
        while read -r name from _ to; do item "$name	$from → $to" id="aur:$name" glyph="󰣇"; done <<<"$aur"
    fi
}
on_select() {
    case $1 in
        all)    qb updates upgrade ;;
        repo:*) open "https://archlinux.org/packages/?q=${1#repo:}" ;;
        aur:*)  open "https://aur.archlinux.org/packages/${1#aur:}" ;;
    esac
}
