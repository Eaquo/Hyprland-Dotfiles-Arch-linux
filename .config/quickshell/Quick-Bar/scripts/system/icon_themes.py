#!/usr/bin/env python3
"""Thèmes d'icônes du système (Réglages › Apparence › Thème).

  icon_themes.py list           → JSON {"current": id, "themes": [{id, name, preview: [chemins]}]}
  icon_themes.py apply <id>     → GTK 3/4 (settings.ini), gsettings, qt5ct/qt6ct

Un thème = dossier avec index.theme et des Directories (les thèmes de curseurs seuls sont ignorés).
"""
import configparser
import json
import os
import re
import subprocess
import sys

HOME = os.path.expanduser("~")
BASES = [HOME + "/.local/share/icons", HOME + "/.icons", "/usr/share/icons", "/usr/local/share/icons"]
# Icônes de l'aperçu : dossier, maison, terminal, navigateur, réglages, musique, image, Steam
PREVIEW = [["folder", "inode-directory"], ["user-home", "folder-home"], ["utilities-terminal", "org.gnome.Terminal", "kitty"],
           ["firefox", "web-browser", "internet-web-browser"], ["preferences-system", "systemsettings", "gnome-settings"],
           ["audio-x-generic", "multimedia-audio-player"], ["image-x-generic", "folder-pictures"], ["steam"]]


def index(path):
    cp = configparser.ConfigParser(interpolation=None, strict=False)
    try:
        cp.read(path, encoding="utf-8")
        return cp["Icon Theme"]
    except (KeyError, configparser.Error, UnicodeDecodeError):
        return None


def themes():
    seen, out = set(), []
    for base in BASES:
        if not os.path.isdir(base):
            continue
        for d in sorted(os.listdir(base)):
            p = os.path.join(base, d)
            if d in seen or d in ("default", "hicolor", "locolor") or not os.path.isfile(p + "/index.theme"):
                continue
            it = index(p + "/index.theme")
            if it is None or not it.get("Directories", "").strip():
                continue                      # thème de curseurs
            seen.add(d)
            out.append({"id": d, "name": it.get("Name", d), "dir": p, "inherits": it.get("Inherits", "")})
    return out


def find_icon(theme_dir, names):
    """Premier fichier trouvé pour un des noms, en préférant les grandes tailles."""
    it = index(theme_dir + "/index.theme")
    dirs = [x.strip() for x in (it.get("Directories", "") if it else "").split(",") if x.strip()]
    def score(d):
        m = re.search(r"(\d+)", d)
        n = int(m.group(1)) if m else 0
        return (0 if "scalable" in d else 1, -min(n, 64) if n >= 32 else 100 - n)
    dirs.sort(key=score)
    for name in names:
        for d in dirs:
            for ext in (".svg", ".png"):
                f = os.path.join(theme_dir, d, name + ext)
                if os.path.isfile(f):
                    return f
    return ""


def current():
    for f in (HOME + "/.config/gtk-3.0/settings.ini", HOME + "/.config/gtk-4.0/settings.ini"):
        try:
            for line in open(f, encoding="utf-8"):
                if line.strip().startswith("gtk-icon-theme-name"):
                    return line.split("=", 1)[1].strip()
        except OSError:
            pass
    return ""


def set_ini(path, section, key, value):
    """Remplace (ou ajoute) key=value dans la section, sans toucher au reste du fichier."""
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError:
        lines = []
    out, in_sec, done, has_sec = [], False, False, False
    for line in lines:
        s = line.strip()
        if s.startswith("["):
            if in_sec and not done:
                out.append(f"{key}={value}"); done = True
            in_sec = s == f"[{section}]"; has_sec = has_sec or in_sec
        elif in_sec and re.match(rf"\s*{re.escape(key)}\s*=", line):
            line, done = f"{key}={value}", True
        out.append(line)
    if not done:
        if not has_sec:
            out += ["", f"[{section}]"] if out else [f"[{section}]"]
        out.append(f"{key}={value}")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")


def apply(tid):
    for v in ("gtk-3.0", "gtk-4.0"):
        set_ini(f"{HOME}/.config/{v}/settings.ini", "Settings", "gtk-icon-theme-name", tid)
    for qt in ("qt5ct", "qt6ct"):
        p = f"{HOME}/.config/{qt}/{qt}.conf"
        if os.path.isfile(p):
            set_ini(p, "Appearance", "icon_theme", tid)
    subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", tid], capture_output=True)


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "apply":
        apply(sys.argv[2])
        return
    ts = themes()
    hicolor = "/usr/share/icons/hicolor"
    for t in ts:
        chain = [t["dir"]] + [b + "/" + i.strip() for i in t["inherits"].split(",") if i.strip() for b in BASES if os.path.isdir(b + "/" + i.strip())] + [hicolor]
        prev = []
        for names in PREVIEW:
            f = next((x for x in (find_icon(c, names) for c in chain) if x), "")
            prev.append(f)
        t["preview"] = prev
        del t["dir"], t["inherits"]
    print(json.dumps({"current": current(), "themes": ts}))


if __name__ == "__main__":
    main()
