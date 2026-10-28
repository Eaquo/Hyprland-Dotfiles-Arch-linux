# Carte du cours de programmation (~/Samsung_Game/Cours code) : modules, exercices, Claude prof — ALT+C
# Les modules sont lus dans le dossier (<langage>/NN-module/), l'état des exercices dans progression.md.
TEMPLATE=files
PROMPT="Cours"
ICON="󰑴"
WIDTH=1400
PLACEHOLDER="Chercher un module, un exercice…"
MESSAGE="entrée : ouvrir (nvim en haut, Claude prof et terminal fish en bas)  ·  à droite : la fiche du module"
NO_CUSTOM=1

COURS=${COURS_DIR:-"$HOME/Samsung_Game/Cours code"}
CARDS=${XDG_RUNTIME_DIR:-/tmp}/qb-cours

# ── la carte : modules, état des exercices (progression.md), fiches ────────
items() {
    [ -d "$COURS" ] || { item "Dossier du cours introuvable" id=none glyph="󰀦" sub="$COURS"; return; }
    mkdir -p "$CARDS"
    python3 - "$COURS" "$CARDS" <<'PY'
import os, re, sys, glob
cours, cards = sys.argv[1], sys.argv[2]
prog = open(os.path.join(cours, "progression.md"), encoding="utf-8").read() if os.path.exists(os.path.join(cours, "progression.md")) else ""

def out(text, **meta):
    print(text + ("\0" + "\x1f".join(f"{k}\x1f{v}" for k, v in meta.items()) if meta else ""))

# état des exercices : « | 02 — Tables | ✅ | — | … | » → {"02": ["✅", "—", …]}
status = {}
for row in re.findall(r'^\|\s*(\d+)\s*—[^|]*\|(.*)\|\s*$', prog, re.M):
    status[row[0]] = [c.strip() for c in row[1].split("|")]
current = (re.search(r'\*\*Module actuel\*\*\s*:\s*`([^`]+)`', prog) or [None, ""])[1]
lang_now = (re.search(r'\*\*Langage en cours\*\*\s*:\s*(.+)', prog) or [None, ""])[1].strip()

modules = sorted(d for d in glob.glob(os.path.join(cours, "*", "[0-9][0-9]-*")) if os.path.isdir(d))

def exos(d):
    return sorted((os.path.basename(f) for f in glob.glob(os.path.join(d, "exo*.*"))),
                  key=lambda n: int(re.sub(r'\D', '', n) or 0))

def next_exo(d):
    st = status.get(os.path.basename(d)[:2], [])
    for i, e in enumerate(exos(d)):
        if i >= len(st) or "✅" not in st[i]:
            return e
    return None

# « Continuer » : le module actuel et son prochain exercice
cur = os.path.join(cours, current) if current else (modules[-1] if modules else "")
if cur and os.path.isdir(cur):
    nx = next_exo(cur) or ""
    card = os.path.join(cards, "_continuer.txt")
    with open(card, "w", encoding="utf-8") as f:
        f.write(f"Continuer : {current}\n\nProchain exercice : {nx or 'module terminé → « leçon suivante »'}\n"
                f"Langage en cours : {lang_now}\n\nOuvre nvim sur la leçon et l'exercice, avec Claude (prof) en bas\n"
                f"et le terminal de tests à droite.\n\n" + "─" * 46 + "\n\n" + prog)
    out("Continuer", id=f"go:{cur}:{nx}", glyph="󰐊", path=card,
        sub=f"{os.path.basename(cur)} · {nx or 'terminé'}")

lang = None
for d in modules:
    l = os.path.basename(os.path.dirname(d))
    if l != lang:
        lang = l
        out(l.upper(), nonselectable="true")
    num, name = os.path.basename(d)[:2], os.path.basename(d)[3:].replace("-", " ")
    st = status.get(num, [])
    ex = exos(d)
    done = sum(1 for i in range(len(ex)) if i < len(st) and "✅" in st[i])
    lecon = os.path.join(d, "lecon.md")
    text = open(lecon, encoding="utf-8").read() if os.path.exists(lecon) else "(pas de leçon)"
    objectif = (re.search(r'\*\*Objectif\*\*\s*:\s*(.+?)(?:\n\n|\n>?\s*\n)', text, re.S) or [None, ""])[1]
    objectif = re.sub(r'\s*\n>\s*', ' ', objectif).strip()
    card = os.path.join(cards, os.path.basename(d) + ".txt")
    with open(card, "w", encoding="utf-8") as f:
        f.write(f"{l} · module {num} — {name}\n\n{objectif}\n\n")
        for i, e in enumerate(ex):
            s = st[i] if i < len(st) else "—"
            f.write(f"  {s if s not in ('', '—') else '·'}  {e}\n")
        f.write(f"\n  {done}/{len(ex)} réussis\n\n" + "─" * 46 + "\n\n" + text)
    mark = "✅" if ex and done == len(ex) else ("●" if os.path.basename(d) == os.path.basename(cur) else "")
    out(f"{num} · {name}", id=f"mod:{d}", glyph="󰂺", path=card, sub=f"{mark} {done}/{len(ex)}".strip())

out("PROF", nonselectable="true")
for cmd, glyph, sub in [("bilan", "󰄬", "résume ta progression"), ("quiz", "󰘥", "5 questions rapides"),
                        ("révision", "󰑓", "exos sur tes points faibles"), ("leçon suivante", "󰒭", "crée le module suivant"),
                        ("projet", "󰏗", "un projet qui combine les modules")]:
    out(f"Claude : {cmd}", id=f"ask:{cmd}", glyph=glyph, sub=sub, path=os.path.join(cours, "CLAUDE.md"))
out("Progression", id=f"file:{os.path.join(cours, 'progression.md')}", glyph="󰄨", sub="progression.md",
    path=os.path.join(cours, "progression.md"))
PY
}

# ── ouvrir : un kitty en trois, fish partout (sans fastfetch : QB_CLEAN) ────────
#   haut        : nvim, la leçon et l'exercice côte à côte
#   bas gauche  : Claude (prof), à la racine du cours, connecté à ce nvim (--ide : diffs dans nvim),
#                 avec le message déjà envoyé s'il y en a un
#   bas droite  : fish dans le dossier du module (lua exoN.lua, tests…)
# work <dossier du module> [message pour Claude] [exercice]
work() {
    local dir=${1:-$COURS} msg=${2:-} exo=${3:-} session="$CARDS/session.kitty" files=()
    mkdir -p "$CARDS"
    if [ -f "$dir/lecon.md" ]; then files+=("$dir/lecon.md"); else files+=("$COURS/progression.md"); fi
    [ -n "$exo" ] && files+=("$dir/$exo")
    local cmd="sleep 1; claude --ide"; [ -n "$msg" ] && cmd="$cmd ${msg@Q}"
    local nv="nvim -O"; local f; for f in "${files[@]}"; do nv="$nv ${f@Q}"; done
    local load="lua require('lazy').load({ plugins = { 'claudecode.nvim' } })"   # serveur pour claude --ide
    nv="$nv -c ${load@Q}"
    {
        echo "layout splits"
        echo "launch --title nvim --cwd ${COURS@Q} --env QB_CLEAN=1 $nv"
        echo "launch --title Claude --location=hsplit --bias=38 --cwd ${COURS@Q} --env QB_CLEAN=1 fish -C ${cmd@Q}"
        echo "launch --title Terminal --location=vsplit --bias=40 --cwd ${dir@Q} --env QB_CLEAN=1 fish"
        echo "focus_matching_window title:nvim"
    } > "$session"
    launch kitty --session "$session"
}

on_select() {
    case $1 in
        go:*)
            local rest=${1#go:} d exo; d=${rest%:*}; exo=${rest##*:}
            work "$d" "" "$exo" ;;
        mod:*)
            local d=${1#mod:} choice e names=()
            for e in "$d"/exo*.*; do names+=("$(basename "$e")"); done
            choice=$(ask "$(basename "$d")" "Ouvrir la leçon" "${names[@]}" "Lancer les tests" "Faire corriger un exercice") || return
            case $choice in
                "Ouvrir la leçon") work "$d" ;;
                "Lancer les tests") term --hold --directory "$d" -e lua tests/run.lua ;;
                "Faire corriger un exercice")
                    e=$(ask "Corriger" "${names[@]}") || return
                    work "$d" "corrige ${e%.*}" "$e" ;;
                exo*) work "$d" "" "$choice" ;;
            esac ;;
        ask:*) work "$COURS" "${1#ask:}" ;;
        file:*) work "$COURS" ;;
    esac
}
