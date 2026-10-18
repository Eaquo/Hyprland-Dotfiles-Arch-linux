#!/bin/bash
# Visuels d'un jeu Steam pour la page Game (GameMode.qml).
#   game_art.sh <appid>  → ligne 1 : bannière (library_hero.jpg), ligne 2 : logo prêt à afficher,
#                          ligne 3 : couleurs vives de la bannière « #RRGGBB,#RRGGBB,… » (LED, accents)
# Le logo est rogné (marge transparente retirée) et passé en blanc s'il est foncé
# (ex. MTGA : logo noir pensé pour fond clair → invisible sur le TouchPanel).
# Résultat mis en cache dans /tmp. Lignes vides si rien n'est trouvé.

# game_art.sh <appid|classe> [pid] : sans appid, on le cherche dans l'environnement du processus
# du jeu et de ses enfants / parents (SteamAppId / SteamGameId, posés par Steam, Proton, gamescope).
id="$1"
if ! [[ "$id" =~ ^[0-9]+$ ]] && [ -n "$2" ]; then
    pids="$2 $(pgrep -P "$2" 2>/dev/null) $(for c in $(pgrep -P "$2" 2>/dev/null); do pgrep -P "$c"; done 2>/dev/null)"
    p="$2"; for _ in 1 2 3 4; do p=$(awk '/^PPid:/{print $2}' "/proc/$p/status" 2>/dev/null); [ -n "$p" ] && [ "$p" != 1 ] && pids="$pids $p"; done
    for p in $pids; do
        v=$(tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | grep -m1 -E '^(SteamAppId|SteamGameId)=[0-9]+$' | cut -d= -f2)
        [ -n "$v" ] && [ "$v" != 0 ] && { id="$v"; break; }
    done
fi
[[ "$id" =~ ^[0-9]+$ ]] || { echo; echo; echo; exit 0; }

dir="$HOME/.local/share/Steam/appcache/librarycache/$id"
cdn="https://cdn.akamai.steamstatic.com/steam/apps/$id"
# Bannière : library_hero.jpg, sinon l'image la plus large du cache (Steam les nomme maintenant
# par empreinte), sinon téléchargée une fois depuis le CDN Steam.
hero=$(find "$dir" -name library_hero.jpg 2>/dev/null | head -1)
if [ -z "$hero" ]; then
    hero=$(for f in $(find "$dir" -name '*.jpg' 2>/dev/null); do
               w=$(magick identify -format '%w %h' "$f" 2>/dev/null); set -- $w
               [ -n "$1" ] && [ "$1" -ge 1900 ] && [ "$1" -gt $(( ${2:-1} * 2 )) ] && echo "$1 $f"
           done | sort -rn | head -1 | cut -d' ' -f2-)
fi
if [ -z "$hero" ]; then
    t="/tmp/quickbar-gamehero-$id.jpg"
    [ -s "$t" ] || curl -sfL -m 6 -o "$t" "$cdn/library_hero.jpg" || rm -f "$t"
    [ -s "$t" ] && hero="$t"
fi
logo=$(find "$dir" -name logo.png 2>/dev/null | head -1)
if [ -z "$logo" ]; then
    t="/tmp/quickbar-gamelogo-src-$id.png"
    [ -s "$t" ] || curl -sfL -m 6 -o "$t" "$cdn/logo.png" || rm -f "$t"
    [ -s "$t" ] && logo="$t"
fi

out=""
if [ -n "$logo" ]; then
    out="/tmp/quickbar-gamelogo-$id.png"
    if [ ! -s "$out" ]; then
        # Luminosité moyenne des seules parties opaques = mean(lum·alpha) / mean(alpha)
        a=$(magick "$logo" -alpha extract -format "%[fx:mean]" info: 2>/dev/null)
        b=$(magick "$logo" -background black -alpha remove -alpha off -colorspace gray -format "%[fx:mean]" info: 2>/dev/null)
        if awk -v a="${a:-1}" -v b="${b:-1}" 'BEGIN { exit !(b < 0.35 * a) }'; then
            magick "$logo" -trim +repage -fill white -colorize 100 "$out" 2>/dev/null
        else
            magick "$logo" -trim +repage "$out" 2>/dev/null
        fi
    fi
    [ -s "$out" ] || out="$logo"     # ImageMagick absent ou en échec → logo brut
fi

# Couleurs dominantes de la bannière, ravivées (LED et accents de la page Game).
colors=""
if [ -n "$hero" ]; then
    colors=$(magick "$hero" -resize 160x -colors 10 -format %c histogram:info: 2>/dev/null | python3 -c '
import sys, re, colorsys
cs = []
for l in sys.stdin:
    m = re.search(r"(\d+):.*#([0-9A-Fa-f]{6})", l)
    if not m: continue
    n, hx = int(m.group(1)), m.group(2)
    h, s, v = colorsys.rgb_to_hsv(*(int(hx[i:i+2], 16) / 255 for i in (0, 2, 4)))
    cs.append((s * v * n ** 0.3, h, s, v))
cs.sort(reverse=True)
out, hues = [], []
for _, h, s, v in cs:
    if s < 0.15 or any(min(abs(h - u), 1 - abs(h - u)) < 0.06 for u in hues): continue   # gris / teinte déjà prise
    hues.append(h)
    r, g, b = colorsys.hsv_to_rgb(h, max(s, 0.75), max(v, 0.9))
    out.append("#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255)))
    if len(out) == 4: break
print(",".join(out))')
fi

echo "$hero"
echo "$out"
echo "$colors"
echo "$id"
