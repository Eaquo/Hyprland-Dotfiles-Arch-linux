#!/usr/bin/env python3
"""Historique du temps de jeu (page Game du TouchPanel, GameMode.qml).

  game_sessions.py add <clé> <titre> <début_epoch> <fin_epoch>   → enregistre une session
  game_sessions.py stats <clé>   → {"today": s, "week": s, "total": s, "sessions": n} (secondes)

Clé = appid Steam ou classe de fenêtre. « week » = depuis lundi 00:00.
Fichier : Quick-Bar/user_data/game_sessions.json (liste de sessions).
"""
import json
import os
import sys
import time
from datetime import datetime, timedelta

PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "user_data", "game_sessions.json")


def load():
    try:
        with open(PATH) as f:
            return json.load(f)
    except (FileNotFoundError, ValueError):
        return []


def overlap(s, e, lo):
    """Secondes de [s, e] postérieures à lo."""
    return max(0, e - max(s, lo))


cmd = sys.argv[1] if len(sys.argv) > 1 else ""

if cmd == "add" and len(sys.argv) == 6:
    key, title, start, end = sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5])
    if end - start >= 60:                      # ignore les lancements de moins d'une minute
        data = load()
        data.append({"key": key, "title": title, "start": start, "end": end})
        os.makedirs(os.path.dirname(PATH), exist_ok=True)
        tmp = PATH + ".tmp"
        with open(tmp, "w") as f:
            json.dump(data, f, indent=1)
        os.replace(tmp, PATH)                  # écriture atomique : jamais de fichier à moitié écrit

elif cmd == "stats" and len(sys.argv) == 3:
    key = sys.argv[2]
    now = datetime.now()
    today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    week = today - timedelta(days=today.weekday())
    t0, w0 = today.timestamp(), week.timestamp()
    mine = [s for s in load() if s["key"] == key]
    print(json.dumps({
        "today": sum(overlap(s["start"], s["end"], t0) for s in mine),
        "week": sum(overlap(s["start"], s["end"], w0) for s in mine),
        "total": sum(s["end"] - s["start"] for s in mine),
        "sessions": len(mine),
    }))

else:
    print(__doc__, file=sys.stderr)
    sys.exit(1)
