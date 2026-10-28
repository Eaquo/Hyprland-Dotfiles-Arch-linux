#!/usr/bin/env python3
# Régénère la section « Carte des fichiers » de docs/ARCHITECTURE.md depuis le code : rôle (commentaire
# d'en-tête du fichier, sinon celui déjà écrit dans la carte), lignes, singleton, et « Utilisé par »
# (fichiers qui instancient / appellent le type QML, ou qui lancent le script).
# Usage : scripts/dev/gen-map.py        (à relancer après l'ajout ou le déplacement de fichiers)
import os, re, sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DOC = os.path.join(ROOT, "docs", "ARCHITECTURE.md")
SKIP = {"user_data", "graphify-out", ".claude", "__pycache__", ".git", "assets", "docs", "hypr"}
EXT = (".qml", ".py", ".sh", ".lua")


def files():
    out = []
    for d, dirs, fs in os.walk(ROOT):
        dirs[:] = sorted(x for x in dirs if x not in SKIP and not x.startswith("backup-"))
        for f in sorted(fs):
            if f.endswith(EXT): out.append(os.path.relpath(os.path.join(d, f), ROOT))
    return out


def header(path, text):
    """première ligne de commentaire du fichier, sans le « Nom — » de tête"""
    mark = "//" if path.endswith(".qml") else "--" if path.endswith(".lua") else "#"
    for line in text.splitlines()[:40]:
        s = line.strip()
        if s.startswith("#!") or s.startswith("pragma") or not s.startswith(mark): continue
        s = s[len(mark):].strip(" -#/")
        name = os.path.splitext(os.path.basename(path))[0]
        s = re.sub(r"^" + re.escape(name) + r"(\.\w+)?\s*[—–:-]\s*", "", s)
        if len(s) > 8: return s.rstrip(".")
    return ""


def old_roles():
    roles = {}
    try: doc = open(DOC, encoding="utf-8").read()
    except OSError: return roles
    folder = ""
    for line in doc.splitlines():
        m = re.match(r"^### `(.+?)`", line)
        if m: folder = "" if m.group(1) == "racine" else m.group(1)
        m = re.match(r"^\| `([^`]+)`[^|]*\| (.+?) \|", line)
        if m and m.group(2) != "Rôle": roles[os.path.join(folder, m.group(1))] = m.group(2)
    return roles


def main():
    fl = files()
    texts = {f: open(os.path.join(ROOT, f), encoding="utf-8", errors="replace").read() for f in fl}
    roles = old_roles()
    groups = {}
    for f in fl:
        t = texts[f]
        name, ext = os.path.splitext(os.path.basename(f))
        users = []
        if ext == ".qml":
            pat = re.compile(r"(?<![\w.])" + re.escape(name) + r"\s*(\{|\.)")
            users = [os.path.splitext(os.path.basename(g))[0] for g in fl if g != f and g.endswith(".qml") and pat.search(texts[g])]
        else:
            base = os.path.basename(f)
            users = [os.path.basename(g) for g in fl if g != f and base in texts[g]]
        users = sorted(set(users))
        used = ", ".join(users[:5]) + (f" … (+{len(users) - 5})" if len(users) > 5 else "")
        if f == "shell.qml": used = "*(point d'entrée)*"
        meta = f"{t.count(chr(10)) + 1} l." + (" · singleton" if "pragma Singleton" in t else "")
        role = header(f, t) or roles.get(f, "—")
        groups.setdefault(os.path.dirname(f), []).append(f"| `{os.path.basename(f)}` ({meta}) | {role.replace('|', '/')} | {used or '—'} |")

    out = ["## Carte des fichiers", "",
           "Générée par `scripts/dev/gen-map.py` (rôle = commentaire d'en-tête du fichier). « Utilisé par » liste",
           "les fichiers qui instancient ou appellent le type, ou qui lancent le script.", ""]
    for g in sorted(groups, key=lambda x: (x != "", x)):
        out += [f"### `{g + '/' if g else 'racine'}`", "", "| Fichier | Rôle | Utilisé par |", "|---|---|---|", *groups[g], ""]
    doc = open(DOC, encoding="utf-8").read()
    start, end = doc.index("## Carte des fichiers"), doc.index("\n## ", doc.index("## Carte des fichiers") + 5)
    open(DOC, "w", encoding="utf-8").write(doc[:start] + "\n".join(out).rstrip() + "\n" + doc[end:])
    print(f"{len(fl)} fichiers, {len(groups)} dossiers")


if __name__ == "__main__":
    if sys.argv[1:] == ["--test"]:
        assert header("bar/Clock.qml", "import QtQuick\n// Clock — horloge de la barre\n") == "horloge de la barre"
        assert header("x.py", "#!/usr/bin/env python3\n# Photos des périphériques\n") == "Photos des périphériques"
        print("ok")
    else:
        main()
