#!/usr/bin/env python3
import sys, json, os, subprocess

HOME       = os.path.expanduser("~")
PRESET_DIR = f"{HOME}/.local/share/easyeffects/output"
EQ_NAME    = "quickbar_eq"
EQ_FILE    = f"{PRESET_DIR}/{EQ_NAME}.json"
FREQS      = [32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384]

def last_preset():
    rc = f"{HOME}/.config/easyeffects/db/easyeffectsrc"
    try:
        for line in open(rc):
            if "lastLoadedOutputPreset=" in line:
                return line.split("=", 1)[1].strip()
    except: pass
    return "HP"

def read_gains(name):
    path = f"{PRESET_DIR}/{name}.json"
    if not os.path.exists(path):
        return [0.0] * 10
    with open(path) as f:
        d = json.load(f)
    eq = d["output"]["equalizer#0"]["left"]
    return [round(eq.get(f"band{i}", {}).get("gain", 0.0), 1) for i in range(10)]

def write_and_load(gains, base="HP"):
    base_path = f"{PRESET_DIR}/{base}.json"
    with open(base_path) as f:
        d = json.load(f)
    eq = d["output"]["equalizer#0"]
    for side in ("left", "right"):
        for i, g in enumerate(gains):
            if f"band{i}" in eq[side]:
                eq[side][f"band{i}"]["gain"] = g
    with open(EQ_FILE, "w") as f:
        json.dump(d, f, indent=2)
    subprocess.run(["easyeffects", "-l", EQ_NAME], capture_output=True)

cmd = sys.argv[1] if len(sys.argv) > 1 else "get"

if cmd == "get":
    p = last_preset()
    g = read_gains(p)
    print(json.dumps({"gains": g, "preset": p}))

elif cmd == "set_gains":
    gains = [float(x) for x in sys.argv[2:12]]
    write_and_load(gains)
    print(json.dumps({"ok": True}))

elif cmd == "load_preset":
    name = sys.argv[2]
    if name == "Flat":
        write_and_load([0.0] * 10)
        print(json.dumps({"gains": [0.0]*10, "preset": "Flat"}))
    else:
        subprocess.run(["easyeffects", "-l", name], capture_output=True)
        print(json.dumps({"gains": read_gains(name), "preset": name}))

elif cmd == "save_preset":
    # save_preset <name> g0 g1 ... g9  → écrit <name>.json (structure basée sur HP)
    name  = sys.argv[2].strip().replace("/", "").replace("..", "")
    gains = [float(x) for x in sys.argv[3:13]]
    if name == "" or name in ("quickbar_eq",):
        print(json.dumps({"ok": False, "error": "nom invalide"}))
    else:
        base_path = f"{PRESET_DIR}/HP.json"
        with open(base_path) as f:
            d = json.load(f)
        eq = d["output"]["equalizer#0"]
        for side in ("left", "right"):
            for i, g in enumerate(gains):
                if f"band{i}" in eq[side]:
                    eq[side][f"band{i}"]["gain"]  = g
                    eq[side][f"band{i}"]["mute"]  = False
        with open(f"{PRESET_DIR}/{name}.json", "w") as f:
            json.dump(d, f, indent=2)
        print(json.dumps({"ok": True, "preset": name}))

elif cmd == "delete_preset":
    name = sys.argv[2].strip().replace("/", "").replace("..", "")
    protected = {"HP", "quickbar_eq"}
    path = f"{PRESET_DIR}/{name}.json"
    if name in protected or not os.path.exists(path):
        print(json.dumps({"ok": False, "error": "protégé ou introuvable"}))
    else:
        os.remove(path)
        print(json.dumps({"ok": True}))

elif cmd == "list":
    files = [f[:-5] for f in os.listdir(PRESET_DIR) if f.endswith(".json")]
    print(json.dumps({"presets": sorted(files)}))
