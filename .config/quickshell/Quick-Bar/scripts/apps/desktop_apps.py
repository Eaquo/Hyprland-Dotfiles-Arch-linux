#!/usr/bin/env python3
"""Applications installées (fichiers .desktop), pour Réglages › Apps.

Sortie JSON triée : [{id, name, exec, icon, comment}] — sans les entrées cachées
(NoDisplay/Hidden) ; Exec nettoyé de ses codes %f %U…
"""
import configparser
import glob
import json
import os
import re

HOME = os.path.expanduser("~")
DIRS = [HOME + "/.local/share/applications", HOME + "/.local/share/flatpak/exports/share/applications",
        "/var/lib/flatpak/exports/share/applications", "/usr/local/share/applications", "/usr/share/applications"]
LANG = os.environ.get("LANG", "fr").split("_")[0] or "fr"


def main():
    seen, out = set(), []
    for d in DIRS:
        for f in sorted(glob.glob(d + "/**/*.desktop", recursive=True)):
            did = os.path.relpath(f, d).replace("/", "-")
            if did in seen:
                continue                      # le premier dossier gagne (comme XDG)
            seen.add(did)
            cp = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                cp.read(f, encoding="utf-8")
                e = cp["Desktop Entry"]
            except (KeyError, configparser.Error, UnicodeDecodeError):
                continue
            if e.get("Type", "Application") != "Application" or e.get("NoDisplay", "").lower() == "true" \
                    or e.get("Hidden", "").lower() == "true" or not e.get("Exec"):
                continue
            ex = re.sub(r"\s*%[fFuUdDnNickvm]", "", e.get("Exec")).strip()
            out.append({"id": did, "name": e.get(f"Name[{LANG}]") or e.get("Name", did),
                        "exec": ex, "icon": e.get("Icon", ""), "terminal": e.get("Terminal", "").lower() == "true",
                        "comment": e.get(f"Comment[{LANG}]") or e.get("Comment", "") or e.get("GenericName", "")})
    out.sort(key=lambda a: a["name"].lower())
    print(json.dumps(out, ensure_ascii=False))


if __name__ == "__main__":
    main()
