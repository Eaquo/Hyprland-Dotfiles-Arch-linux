#!/bin/bash
exec python3 - << 'EOF'
import subprocess, json, os, sys, hashlib, urllib.request

def cmd(c):
    try: return subprocess.check_output(c, shell=True, stderr=subprocess.DEVNULL).decode().strip()
    except: return ""

status = cmd("playerctl status") or "Stopped"
if status == "Stopped":
    print(json.dumps({"status":"Stopped","title":"","artist":"","percent":0,"artPath":""}))
    sys.exit()

title   = cmd("playerctl metadata title")
artist  = cmd("playerctl metadata artist")
length  = cmd("playerctl metadata mpris:length") or "0"
pos     = cmd("playerctl position") or "0"
art_url = cmd("playerctl metadata mpris:artUrl")

try:
    percent = float(pos) / (int(length) / 1_000_000)
    percent = max(0.0, min(1.0, percent))
except:
    percent = 0

art_path = ""
if art_url.startswith("file://"):
    art_path = art_url[7:]
elif art_url.startswith("http"):
    h     = hashlib.md5(art_url.encode()).hexdigest()[:10]
    cache = f"/tmp/qs-art-{h}.jpg"
    if not os.path.exists(cache):
        try: urllib.request.urlretrieve(art_url, cache)
        except: pass
    if os.path.exists(cache):
        art_path = cache

print(json.dumps({"title":title,"artist":artist,"status":status,"percent":percent,"artPath":art_path}))
EOF
