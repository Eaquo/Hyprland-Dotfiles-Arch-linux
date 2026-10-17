#!/usr/bin/env python3
"""Modifie ~/.config/swaync/config.json puis recharge swaync.

Usage : swaync_set.py '<json>'   — {"timeout": 8, "positionX": "right", ...}
        swaync_set.py get        — affiche les réglages actuels (JSON)
Écriture atomique ; les autres clés (widgets…) ne sont pas touchées.
"""
import json
import os
import subprocess
import sys
import tempfile

PATH = os.path.expanduser("~/.config/swaync/config.json")


def main():
    try:
        with open(PATH, encoding="utf-8") as f:
            cfg = json.load(f)
    except (OSError, ValueError):
        cfg = {}
    if sys.argv[1] == "get":
        print(json.dumps(cfg))
        return
    cfg.update(json.loads(sys.argv[1]))
    os.makedirs(os.path.dirname(PATH), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(PATH), prefix=".config.", suffix=".json")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, PATH)
    subprocess.run(["swaync-client", "-R"], capture_output=True)


if __name__ == "__main__":
    main()
