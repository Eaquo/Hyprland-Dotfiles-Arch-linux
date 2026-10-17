#!/usr/bin/env python3
"""Polices installées pour Réglages › Apparence › Police.

Imprime un JSON trié : [{family, mono, nerd}] — une entrée par famille (fc-list),
mono = police à chasse fixe (fontconfig spacing=100), nerd = Nerd Font (icônes).
"""
import json
import subprocess


def families(pattern):
    out = subprocess.run(["fc-list", pattern, "family"], capture_output=True, text=True, timeout=15).stdout
    return {line.split(",")[0].strip() for line in out.splitlines() if line.strip() and not line.startswith(".")}


def main():
    every = families(":")
    mono = families(":spacing=100")
    print(json.dumps([{"family": f, "mono": f in mono, "nerd": "nerd font" in f.lower() or f.endswith(" NF")}
                      for f in sorted(every, key=str.lower)], ensure_ascii=False))


if __name__ == "__main__":
    main()
