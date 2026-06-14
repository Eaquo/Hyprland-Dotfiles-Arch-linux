#!/bin/bash
exec python3 - << 'EOF'
import subprocess, json, os, sys, hashlib, urllib.request, urllib.parse, base64

def cmd(c):
    try: return subprocess.check_output(c, shell=True, stderr=subprocess.DEVNULL).decode().strip()
    except: return ""

# ── Choisir le lecteur pertinent ──────────────────────────────────────────────
# Priorité : un lecteur "Playing" (vidéo ou musique), sinon "Paused", sinon le
# premier actif. Comme ça la pochette suit ce qui joue réellement, pas le lecteur
# par défaut de playerctl.
players = [p for p in cmd("playerctl -l").splitlines() if p.strip()]

def status_of(p):
    return cmd(f"playerctl -p '{p}' status") or "Stopped"

chosen, chosen_status = "", "Stopped"
for want in ("Playing", "Paused"):
    for p in players:
        if status_of(p) == want:
            chosen, chosen_status = p, want
            break
    if chosen:
        break
if not chosen:
    for p in players:
        s = status_of(p)
        if s != "Stopped":
            chosen, chosen_status = p, s
            break

if not chosen:
    print(json.dumps({"status": "Stopped", "title": "", "artist": "", "percent": 0, "artPath": ""}))
    sys.exit()

P = f"playerctl -p '{chosen}'"
status   = chosen_status
title    = cmd(f"{P} metadata title")
artist   = cmd(f"{P} metadata artist")
length   = cmd(f"{P} metadata mpris:length") or "0"
pos      = cmd(f"{P} position") or "0"
art_url  = cmd(f"{P} metadata mpris:artUrl")
page_url = cmd(f"{P} metadata xesam:url")

try:
    percent = float(pos) / (int(length) / 1_000_000)
    percent = max(0.0, min(1.0, percent))
except:
    percent = 0

# ── Résolution de la pochette ─────────────────────────────────────────────────
art_path  = ""
candidates = []

if art_url.startswith("data:"):
    # Pochette embarquée (ex. Jellyfin) → décoder le base64 vers un fichier.
    try:
        header, payload = art_url.split(",", 1)
        if "base64" in header:
            h = hashlib.md5(art_url.encode()).hexdigest()[:10]
            cache = f"/tmp/qs-art-{h}.jpg"
            if not (os.path.exists(cache) and os.path.getsize(cache) > 0):
                with open(cache, "wb") as f:
                    f.write(base64.b64decode(payload))
            if os.path.exists(cache) and os.path.getsize(cache) > 0:
                art_path = cache
    except:
        pass
elif art_url.startswith("file://"):
    candidates.append(art_url)
elif art_url.startswith("http"):
    candidates.append(art_url)

# Pas de pochette MPRIS (cas YouTube dans Firefox/Zen) → la déduire de l'URL de page.
if not art_path and not candidates and page_url:
    vid = ""
    try:
        u = urllib.parse.urlparse(page_url)
        host = u.netloc.lower()
        if "youtu.be" in host:
            vid = u.path.lstrip("/").split("/")[0]
        elif "youtube.com" in host:
            vid = (urllib.parse.parse_qs(u.query).get("v") or [""])[0]
    except:
        pass
    if vid:
        candidates.append(f"https://i.ytimg.com/vi/{vid}/maxresdefault.jpg")
        candidates.append(f"https://i.ytimg.com/vi/{vid}/hqdefault.jpg")

# Résoudre la première pochette http/file valable.
if not art_path:
    for cu in candidates:
        if cu.startswith("file://"):
            p = cu[7:]
            if os.path.exists(p):
                art_path = p
                break
            continue
        h = hashlib.md5(cu.encode()).hexdigest()[:10]
        cache = f"/tmp/qs-art-{h}.jpg"
        if not (os.path.exists(cache) and os.path.getsize(cache) > 0):
            try:
                req = urllib.request.Request(cu, headers={"User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(req, timeout=4) as r, open(cache, "wb") as f:
                    f.write(r.read())
            except:
                pass
        if os.path.exists(cache) and os.path.getsize(cache) > 0:
            art_path = cache
            break

print(json.dumps({"title": title, "artist": artist, "status": status, "percent": percent, "artPath": art_path}))
EOF
