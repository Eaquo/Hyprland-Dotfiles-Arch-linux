#!/usr/bin/env python3
# Photos des périphériques pour la page Devices du dashboard. Pour chaque modèle de assets/devices/devices.json
# sans photo, récupère l'image d'une fiche produit Shopify (API publique : <fiche>.json, sans clé), la détoure
# (fond uni rempli depuis les coins, ImageMagick si présent) et l'écrit dans assets/devices/<slug>.png.
# N'interroge le réseau que pour les photos manquantes ; affiche les fichiers créés (rien = rien de neuf).
# Commandes de Réglages › Périphériques :
#   images <fiche>                         URL des photos de la fiche, une par ligne
#   set <modèle> <fiche> <n°> [tout]       enregistre la fiche dans devices.json et (re)télécharge la photo
#   file <modèle> <image> [tout]           photo depuis un fichier local (détourée s'il a un fond uni)
#   rm <modèle>                            retire la photo et l'entrée de devices.json
import json, os, re, shutil, subprocess, sys, tempfile, urllib.request

DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "devices")
UA = {"User-Agent": "Mozilla/5.0 (Quick-Bar device photos)"}


def slug(s): return re.sub(r"^-+|-+$", "", re.sub(r"[^a-z0-9]+", "-", s.lower()))


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=20) as r: return r.read()


def images(page):
    page = page.split("?")[0].split("#")[0].rstrip("/")
    return [i["src"] for i in json.loads(get(page + ".json"))["product"]["images"]]


def image_url(page, index):
    imgs = images(page)
    return imgs[min(index, len(imgs) - 1)]


def cut_out(src, out, everywhere=False):
    """fond uni → transparent depuis les 4 coins (les blancs/noirs de l'objet restent), recadré, 1000 px max ;
    everywhere : retire aussi le fond enfermé (intérieur d'un arceau de casque), si l'objet n'a pas cette couleur"""
    if not shutil.which("magick"):
        subprocess.run(["cp", src, out], check=True); return
    w, h, a = subprocess.run(["magick", src, "-format", "%w %h %[fx:p{0,0}.a]", "info:"],
                             capture_output=True, text=True, check=True).stdout.split()
    w, h = int(w), int(h)
    if float(a) < 0.5:                           # déjà détourée (PNG transparent) : recadrage seul
        subprocess.run(["magick", src, "-trim", "+repage", "-resize", "1000x1000>", out], check=True); return
    method = "replace" if everywhere else "floodfill"
    fill = [a for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)) for a in ("-draw", f"color {x},{y} {method}")]
    subprocess.run(["magick", src, "-alpha", "set", "-fuzz", "4%", "-fill", "none", *fill, "-trim", "+repage",
                    "-channel", "A", "-morphology", "Erode", "Disk:1", "+channel", "-resize", "1000x1000>", out], check=True)


def load():
    try: return json.load(open(os.path.join(DIR, "devices.json"), encoding="utf-8"))
    except (OSError, ValueError): return {}


def save(d):
    tmp = os.path.join(DIR, "devices.json.tmp")
    with open(tmp, "w", encoding="utf-8") as f: json.dump(d, f, indent=2, ensure_ascii=False); f.write("\n")
    os.replace(tmp, os.path.join(DIR, "devices.json"))


def fetch(model, e, out):
    with tempfile.NamedTemporaryFile(suffix=".img") as t:
        t.write(get(image_url(e["url"], e.get("image", 0)))); t.flush()
        cut_out(t.name, out, e.get("fond") == "tout")


def command(args):
    cmd, model = args[0], args[1] if len(args) > 1 else ""
    out = os.path.join(DIR, slug(model) + ".png")
    if cmd == "images":
        print("\n".join(images(args[1])))
    elif cmd == "set":
        e = {"url": args[2], "image": int(args[3])}
        if args[4:] == ["tout"]: e["fond"] = "tout"
        d = load(); d[model] = e; save(d)
        if os.path.exists(out): os.remove(out)
        fetch(model, e, out); print(out)
    elif cmd == "file":
        os.makedirs(DIR, exist_ok=True)
        cut_out(args[2], out, args[3:] == ["tout"]); print(out)
    elif cmd == "rm":
        d = load()
        if d.pop(model, None) is not None: save(d)
        if os.path.exists(out): os.remove(out)
        print(out)
    else:
        sys.exit(f"commande inconnue : {cmd}")


def main():
    wanted = load()
    for model, e in wanted.items():
        if model.startswith("_"): continue
        out = os.path.join(DIR, slug(model) + ".png")
        if os.path.exists(out): continue
        try:
            fetch(model, e, out); print(out)
        except Exception as err:
            print(f"{model} : {err}", file=sys.stderr)


if __name__ == "__main__":
    if sys.argv[1:] == ["--test"]:
        assert slug("Logitech PRO X") == "logitech-pro-x" and slug(" Flydigi Vader 5 Pro ") == "flydigi-vader-5-pro"
        print("ok")
    elif sys.argv[1:]:
        try: command(sys.argv[1:])
        except Exception as err: sys.exit(f"{err}")
    else:
        main()
