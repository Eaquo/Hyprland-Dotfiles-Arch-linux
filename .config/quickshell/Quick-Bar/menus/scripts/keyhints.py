#!/usr/bin/env python3
"""keyhints.py — lit les raccourcis Hyprland directement dans les configs Lua (menu keyhints.sh).

Rien à maintenir à la main : chaque hl.bind(...) actif des fichiers ci-dessous devient une ligne
du menu, avec à droite une fiche (touches, action, fichier:ligne, extrait du code, doublons).
"""
import os, re, sys

HOME = os.path.expanduser("~")
HYPR = os.path.join(os.environ.get("XDG_CONFIG_HOME", f"{HOME}/.config"), "hypr")
INCLUDE = re.compile(r'^\s*(require|dofile)\s*\(\s*(.+?)\s*\)')


def discover(entry=os.path.join(HYPR, "hyprland.lua")):
    """Les fichiers que Hyprland charge vraiment : hyprland.lua, puis chaque require("…") / dofile("…")
    qu'il contient (récursivement, sans doublon, lignes commentées ignorées)."""
    seen, todo = [], [entry]
    while todo:
        path = os.path.realpath(todo.pop(0))
        if path in seen or not os.path.isfile(path):
            continue
        seen.append(path)
        for line in open(path, encoding="utf-8", errors="ignore"):
            m = INCLUDE.match(line)
            if not m:
                continue
            target = os.path.expanduser(resolve(m.group(2), {"home": HOME}).replace('os.getenv("HOME")', HOME))
            if m.group(1) == "require":            # require("configs lua/Keybinds") → <hypr>/configs lua/Keybinds.lua
                target = os.path.join(HYPR, target.replace(".", "/") + ".lua")
            todo.append(target)
    return seen


BIND = re.compile(r'^\s*hl\.bind\((.*)$')
SECTION = re.compile(r'║\s+(.+?)\s+║')            # titres encadrés  ║   SYSTÈME   ║


LOCAL = re.compile(r'^\s*local\s+(\w+)\s*=\s*(.+?)\s*(--.*)?$')


def split_top(s):
    """Découpe « a, f(b, c), { d } » aux virgules de premier niveau (hors parenthèses et chaînes)."""
    parts, depth, cur, quote = [], 0, "", None
    for ch in s:
        if quote:
            cur += ch
            if ch == quote:
                quote = None
            continue
        if ch in "\"'":
            quote = ch
        elif ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
            if depth < 0:                          # parenthèse fermante de hl.bind( … )
                break
        elif ch == "," and depth == 0:
            parts.append(cur.strip()); cur = ""; continue
        cur += ch
    if cur.strip():
        parts.append(cur.strip())
    return parts


def resolve(expr, env):
    """« mainMod .. " + Q" » → « SUPER + Q » ; un nom inconnu (variable de boucle) reste en <nom>."""
    out = ""
    for tok in re.split(r'\s*\.\.\s*', expr.strip()):
        tok = tok.strip()
        if len(tok) >= 2 and tok[0] in "\"'" and tok[-1] == tok[0]:
            out += tok[1:-1]
        elif tok in env:
            out += env[tok]
        else:
            out += f"<{tok}>"
    return out


def locals_of(lines, env):
    """Les « local x = "..." » (et leurs concaténations) du fichier, ajoutés à env."""
    for line in lines:
        m = LOCAL.match(line)
        if m and not m.group(2).startswith(("function", "{", "hl.", "os.getenv")):
            env[m.group(1)] = resolve(m.group(2), env)
        elif m and m.group(2).startswith("os.getenv(\"HOME\")"):
            env[m.group(1)] = HOME
    return env


def scan(path):
    """Les hl.bind actifs d'un fichier : (n° de ligne, texte du bind, section)."""
    lines = open(path, encoding="utf-8").read().splitlines()
    section = os.path.basename(path).removesuffix(".lua")
    submap = None                                  # dans hl.define_submap("x", function() … end) : mode x
    out = []
    for i, line in enumerate(lines):
        m = SECTION.search(line)
        if m:
            section = m.group(1).strip().title()
        s = re.match(r'^\s*hl\.define_submap\("([^"]+)"', line)
        if s:
            submap = s.group(1)
        elif submap and line.startswith("end)"):
            submap = None
        if BIND.match(line):                      # les binds commentés (-- hl.bind) ne matchent pas
            out.append((i + 1, line.strip(), f"Mode « {submap} »" if submap else section, lines))
    return out


KEYNAMES = {"period": ".", "comma": ",", "bracketleft": "[", "bracketright": "]", "Return": "Entrée",
            "ESCAPE": "Échap", "Escape": "Échap", "Delete": "Suppr", "Print": "Impr", "space": "Espace",
            "SUPER_L": "(seul)", "mouse_down": "molette ↓", "mouse_up": "molette ↑",
            "mouse:272": "clic gauche", "mouse:273": "clic droit", "left": "←", "right": "→", "up": "↑", "down": "↓"}

WINDOW = {"close": "Fermer la fenêtre", "kill": "Tuer la fenêtre (forcer)", "fullscreen": "Plein écran",
          "float": "Fenêtre flottante / en tuile", "pseudo": "Pseudo-tuile", "pin": "Épingler la fenêtre",
          "cycle_next": "Fenêtre suivante", "center": "Centrer la fenêtre", "resize": "Redimensionner la fenêtre",
          "move": "Déplacer la fenêtre", "swap": "Échanger la fenêtre", "toggle_group": "Grouper les fenêtres"}
DIRS = {"l": "à gauche", "r": "à droite", "u": "en haut", "d": "en bas"}


def pretty_keys(keys):
    """« SUPER + SHIFT + <key> » → « SUPER + SHIFT + 1…0 », « period » → « . »."""
    keys = re.sub(r'(code:)?<[^>]*>', "1…0", keys)
    parts = []
    for k in keys.split(" + "):
        if k.startswith("<"):
            k = "1…0"
        parts.append(KEYNAMES.get(k, k))
    return " + ".join(parts)


def hand_written(b, lines):
    """Description écrite à la main : description = "…", commentaire en fin de ligne, ou juste au-dessus."""
    m = re.search(r'description\s*=\s*"([^"]+)"', b["opts"])
    if m:
        return m.group(1)
    line = lines[b["line"] - 1]
    m = re.search(r'\)\s*--\s*(.+)$', line)
    if m and not re.match(r'(corrigé|todo|fixme|→|note)', m.group(1).strip(), re.I):
        return m.group(1).strip()
    above = lines[b["line"] - 2].strip() if b["line"] >= 2 else ""
    # au-dessus : la description de CE bind s'il est seul sous le commentaire, ou une vraie phrase ;
    # « -- Fenêtres » au-dessus de plusieurs binds est un titre de groupe
    text = above.lstrip("- ").strip()
    alone = b["line"] >= len(lines) or not BIND.match(lines[b["line"]])
    prev = lines[b["line"] - 3].strip() if b["line"] >= 3 else ""
    if prev.startswith("--") and not re.search(r'[═║╔╚─]', prev) and len(prev.lstrip("- ").split()) > 3:
        return ""                                  # fin d'un paragraphe de commentaires : pas une description
    if above.startswith("--") and not re.search(r'[═║╔╚─]|hl\.bind', above) and (alone or len(text.split()) > 3):
        return text
    return ""


def explain(action, env):
    """Description déduite de l'action, et son type (pour la fiche)."""
    a = action.strip()
    m = re.match(r'hl\.dsp\.exec_cmd\((.*)\)$', a)
    if m:
        cmd = resolve(m.group(1), env)
        q = re.search(r'ipc call (.+)$', cmd)
        if q:
            return "Quick-Bar : " + q.group(1), "Quick-Bar", cmd
        h = re.match(r'hyprctl dispatch (.+)$', cmd)
        if h:
            return "Hyprland : " + h.group(1), "Hyprland", cmd
        words = [w for w in cmd.split() if "=" not in w and w != "env"]
        if "-e" in words and words.index("-e") + 1 < len(words):      # kitty -e btop → btop
            words = words[words.index("-e") + 1:]
        if words[:2] == ["pypr", "toggle"] and len(words) > 2:
            return f"Afficher / masquer {words[2]} (pypr)", "Commande", cmd
        prog = os.path.basename(words[0]).removesuffix(".sh") if words else cmd
        arg = words[1] if len(words) > 1 and words[1].startswith("-") and len(words[1]) < 14 else ""
        return f"Lancer {prog} {arg}".strip(), "Commande", cmd
   vscode-webview://0vat442rlp83nufue86jn2neq78pcomokmbsp2hh3q8ubi5q96iq/index.html?id=90f6c04b-e04a-4557-a842-8e522300728a&parentId=1&origin=da3b6280-5c34-44f9-9441-e62d669533fa&swVersion=4&extensionId=Anthropic.claude-code&platform=electron&vscode-resource-base-authority=vscode-resource.vscode-cdn.net&parentOrigin=vscode-file%3A%2F%2Fvscode-app&session=8697338d-099a-4435-9ba3-d9a3c2bbe518# m = re.match(r'hl\.dsp\.window\.(\w+)\((.*)\)$', a)
    if m:
        name, arg = m.groups()
        w = re.search(r'workspace\s*=\s*"?([^",}]+)', arg)
        d = re.search(r'direction\s*=\s*"(\w)"', arg)
        if name == "move" and w:
            return "Envoyer la fenêtre sur l'espace " + ("1…0" if w.group(1).strip() == "i" else w.group(1)), "Fenêtre", a
        if name == "move" and "monitor" in arg:
            return "Envoyer la fenêtre sur l'autre écran", "Fenêtre", a
        if d:
            return WINDOW.get(name, name) + " " + DIRS.get(d.group(1), d.group(1)), "Fenêtre", a
        return WINDOW.get(name, "Fenêtre : " + name), "Fenêtre", a
    m = re.match(r'hl\.dsp\.focus\((.*)\)$', a)
    if m:
        arg = m.group(1)
        w = re.search(r'workspace\s*=\s*"?([^",}]+)', arg)
        d = re.search(r'direction\s*=\s*"(\w)"', arg)
        if w:
            v = w.group(1).strip()
            return {"m+1": "Espace suivant (écran)", "m-1": "Espace précédent (écran)", "e+1": "Espace suivant",
                    "e-1": "Espace précédent", "i": "Aller sur l'espace 1…0"}.get(v, "Aller sur l'espace " + v), "Espace", a
        if d:
            return "Focus " + DIRS.get(d.group(1), d.group(1)), "Focus", a
        return "Focus", "Focus", a
    m = re.match(r'hl\.dsp\.submap\("(\w+)"\)', a)
    if m:
        return ("Quitter le mode" if m.group(1) == "reset" else f"Mode « {m.group(1)} »"), "Mode", a
    if a.startswith("hl.dsp.exit"):
        return "Quitter Hyprland", "Session", a
    m = re.match(r'hl\.dsp\.workspace\.toggle_special\("(\w+)"\)', a)
    if m:
        return f"Afficher / masquer l'espace spécial {m.group(1)}", "Espace", a
    if a.startswith("hl.plugin."):
        return "Plugin : " + a.split("(")[0].removeprefix("hl.plugin."), "Plugin", a
    if a.startswith("function"):
        return "Fonction Lua (voir le code)", "Lua", a
    return a.removeprefix("hl.dsp."), "Autre", a


def parse(path):
    """Chaque bind du fichier : touches lisibles, action brute, options, section, ligne."""
    lines = open(path, encoding="utf-8").read().splitlines()
    env = locals_of(lines, {"mainMod": "SUPER"})
    binds = []
    for n, text, sec, _ in scan(path):
        args = split_top(BIND.match(text).group(1))
        if not args:
            continue
        keys = re.sub(r'\s*\+\s*', " + ", resolve(args[0], env)).strip(" +")
        action = args[1] if len(args) > 1 else ""
        opts = args[2] if len(args) > 2 else ""
        b = {"keys": pretty_keys(keys), "action": action, "opts": opts, "section": sec,
             "file": path, "line": n}
        auto, b["kind"], b["detail"] = explain(action, env)
        b["desc"] = hand_written(b, lines) or auto
        b["auto"] = auto
        binds.append(b)
    return binds


CATS = ["Système", "Fenêtres", "Espaces de travail", "Applications", "Jeux", "Médias & captures",
        "Quick-Bar", "Modes", "Divers"]


def category(b):
    """Le type du raccourci, pour classer l'aide (ordre de CATS)."""
    k, d = b["kind"], b["detail"].lower()
    if b["section"].startswith("Mode") or k == "Mode":
        return "Modes"
    if k in ("Fenêtre", "Focus") or (k == "Lua" and re.search(r'fenêtre|window|float', b["desc"], re.I)):
        return "Fenêtres"
    if k == "Espace" or k == "Plugin" or re.search(r'workspace|special', d):
        return "Espaces de travail"
    if re.match(r'XF86Audio|XF86Mon', b["keys"]):
        return "Médias & captures"
    if k == "Session" or re.search(r'(^|[\s/])(lock lock|hyprlock|wlogout|loginctl|poweroff|reboot|wl-freeze|session)', d):
        return "Système"
    if k == "Quick-Bar":
        return "Quick-Bar"
    if k == "Hyprland":
        return "Fenêtres" if re.search(r'group|float|pin|fullscreen', d) else "Divers"
    if k == "Commande":
        if re.search(r'grim|slurp|screenshot|capture|record|wpctl|pamixer|pactl|playerctl|brightness|volume', d):
            return "Médias & captures"
        if re.search(r'steam|game|gamescope|lutris|heroic', d):
            return "Jeux"
        return "Applications"
    return "Divers"


def short(path):
    """Chemin lisible : relatif à la config Hyprland, sinon avec ~."""
    return os.path.relpath(path, HYPR) if path.startswith(HYPR) else path.replace(HOME, "~", 1)


def card(b, others):
    """La fiche de droite d'un raccourci (texte affiché par le template files)."""
    lines = open(b["file"], encoding="utf-8").read().splitlines()
    rule = "─" * 46
    out = [f"  ⌨  {b['keys']}", "", f"  {b['desc']}"]
    if b["desc"] != b["auto"]:
        out.append(f"  ({b['auto']})")
    out += ["", f"  Type      {b.get('cat', b['kind'])} ({b['kind']})", f"  Section   {b['section']}",
            f"  Fichier   {short(b['file'])} · ligne {b['line']}"]
    if b["kind"] in ("Commande", "Quick-Bar", "Hyprland"):
        out.append(f"  Commande  {b['detail']}")
    if others:
        out += ["", "  ⚠ Même combinaison ailleurs :"]
        out += [f"     {short(o['file'])}:{o['line']}  →  {o['desc']}" for o in others]
    out += ["", "  " + rule]
    lo, hi = max(1, b["line"] - 3), min(len(lines), b["line"] + 6)
    for n in range(lo, hi + 1):
        out.append(f" {'▶' if n == b['line'] else ' '}{n:4d} │ {lines[n - 1]}")
    out += ["", "  entrée : lancer  ·  ctrl+entrée : ouvrir la config à cette ligne"]
    return "\n".join(out) + "\n"


def menu():
    """Les lignes du menu (format qbmenu) : sections, touches, description, fiche à droite."""
    binds = [b for f in discover() for b in parse(f)]
    cards = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "qb-keyhints")
    os.makedirs(cards, exist_ok=True)
    by_keys = {}
    for b in binds:                                # même touches ET même mode = vrai conflit
        b["slot"] = (b["keys"].lower(), b["section"] if b["section"].startswith("Mode") else "")
        by_keys.setdefault(b["slot"], []).append(b)
    for b in binds:
        b["cat"] = category(b)
    binds.sort(key=lambda b: CATS.index(b["cat"]))   # tri stable : l'ordre des fichiers reste dans chaque type
    cat = None
    for i, b in enumerate(binds):
        if b["cat"] != cat:
            cat = b["cat"]
            n = sum(1 for x in binds if x["cat"] == cat)
            print(f"{cat}  ·  {n}\0nonselectable\x1ftrue")
        others = [o for o in by_keys[b["slot"]] if o is not b]
        path = os.path.join(cards, f"{i:03d}.txt")
        with open(path, "w", encoding="utf-8") as f:
            f.write(card(b, others))
        sub = ("⚠ doublon · " if others else "") + b["desc"]
        kw = f"{b['detail']} {b['section']} {b['kind']}".replace("\x1f", " ")     # cherchable, non affiché
        print(f"{b['keys']}\0id\x1f{b['file']}:{b['line']}\x1fpath\x1f{path}\x1fsub\x1f{sub}\x1fkw\x1f{kw}\x1fglyph\x1f󰌌")


def lua_body(lines, n):
    """Le corps d'un hl.bind(…, function() … end) qui commence à la ligne n."""
    first = lines[n - 1]
    indent = len(first) - len(first.lstrip())
    body = [first.split("function()", 1)[1]]
    for line in lines[n:]:
        if line.strip().startswith("end)") and len(line) - len(line.lstrip()) == indent:
            return "\n".join(body)
        body.append(line)
    return None


def run(ref):
    """Lance l'action du raccourci « fichier:ligne » comme si on avait appuyé dessus."""
    import subprocess
    path, line = ref.rsplit(":", 1)
    b = next((x for x in parse(path) if x["line"] == int(line)), None)
    if b is None:
        return "raccourci introuvable"
    if re.search(r'clic|molette|mouse', b["keys"]):
        return "raccourci à la souris : à faire à la main"
    if "1…0" in b["keys"]:
        return "raccourci par numéro (1…0) : appuie sur la touche voulue"
    lines = open(path, encoding="utf-8").read().splitlines()
    env = locals_of(lines, {"mainMod": "SUPER"})
    if b["kind"] in ("Commande", "Quick-Bar", "Hyprland"):
        lua = f"hl.exec_cmd([==[{b['detail']}]==])"
    elif b["kind"] == "Lua":
        body = lua_body(lines, b["line"])
        if body is None:
            return "fonction Lua illisible"
        decl = "".join(f"local {k} = [==[{v}]==]; " for k, v in env.items())
        lua = f"{decl}(function() {body} end)()"
    else:
        lua = f"hl.dispatch({b['action']})"
    out = subprocess.run(["hyprctl", "eval", lua], capture_output=True, text=True).stdout.strip()
    return "" if out in ("ok", "") else out


if __name__ == "__main__":
    if sys.argv[1:] == ["menu"]:
        menu()
    elif sys.argv[1:2] == ["run"] and len(sys.argv) == 3:
        msg = run(sys.argv[2])
        if msg:
            print(msg)
    else:                                          # sans argument : liste lisible (vérification)
        for f in discover():
            for b in parse(f):
                print(f"{b['keys']:<26} {b['desc'][:70]}")
