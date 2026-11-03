#!/usr/bin/env python3
# wall-mana.py — prépare l'effet Mana d'un fond d'écran (wallpaper/shaders/mana.frag) :
# détoure le personnage avec isnet-anime (modèle de rembg, ~/.local/share/quickbar/models/isnet-anime.onnx),
# puis écrit dans user_data/mana/ :
#   <nom>.png   R = masque du personnage · G = proximité extérieure du contour (1 au bord → 0 à ~12 % de
#               la hauteur) · B = proximité intérieure (1 au bord → 0 vers le cœur), pour l'aura et le liseré
#   <nom>.json  {"colors": ["#rrggbb", …]} les couleurs dominantes du personnage (les plus vives d'abord)
# Mis en cache : rien n'est recalculé si le fichier existe et est plus récent que l'image.
#   wall-mana.py <image>        → affiche le JSON {"field": …, "colors": […]}
#   wall-mana.py <image> --force → recalcule même si le cache est à jour
#   wall-mana.py --test         → auto-test (couleurs et champ sur une image synthétique, sans le modèle)
import json
import os
import sys

import cv2
import numpy as np

MODEL = os.path.expanduser("~/.local/share/quickbar/models/isnet-anime.onnx")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "user_data", "mana")
W = 1280                                   # largeur du champ (le shader l'étire, inutile d'aller plus haut)


def segment(img):
    """Masque 0..1 du personnage (isnet-anime, prétraitement identique à rembg)."""
    import onnxruntime as ort
    sess = ort.InferenceSession(MODEL, providers=["CPUExecutionProvider"])
    rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    x = cv2.resize(rgb, (1024, 1024), interpolation=cv2.INTER_LANCZOS4).astype(np.float32)
    x /= max(float(x.max()), 1e-6)
    x = (x - np.array([0.485, 0.456, 0.406], np.float32)) / np.array([1.0, 1.0, 1.0], np.float32)
    x = x.transpose(2, 0, 1)[None]
    pred = sess.run(None, {sess.get_inputs()[0].name: x})[0][0, 0]
    pred = (pred - pred.min()) / max(float(pred.max() - pred.min()), 1e-6)
    return cv2.resize(pred, (img.shape[1], img.shape[0]), interpolation=cv2.INTER_LINEAR)


def glow_mask(img):
    """Repli pour les personnages néon sur fond sombre (le modèle n'y voit rien) : ce qui s'éclaire sur le noir,
    intérieur bouché, petites taches retirées."""
    h, w = img.shape[:2]
    v = cv2.GaussianBlur(img.max(axis=2), (0, 0), 2)
    t, _ = cv2.threshold(v, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    m = (v > max(t, 40)).astype(np.uint8)
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (int(0.035 * h) | 1,) * 2)
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, k)
    inv = (1 - m).copy()
    inv[-1, :] = 0                                             # bas de l'écran = bord fermé (buste coupé par le cadre)
    ff = np.zeros((h + 2, w + 2), np.uint8)
    for seed in ((0, 0), (w - 1, 0), (w // 2, 0)):
        if inv[seed[1], seed[0]]:
            cv2.floodFill(inv, ff, seed, 2)
    m = np.where(inv == 2, 0, 1).astype(np.uint8)              # trous intérieurs bouchés
    n, lab, st, _ = cv2.connectedComponentsWithStats(m)
    keep = np.zeros(n, bool)
    keep[1:] = st[1:, cv2.CC_STAT_AREA] > 0.004 * h * w
    # ponytail: un dessin au trait aux contours ouverts reste en traits (l'aura suit alors les traits)
    return cv2.GaussianBlur(keep[lab].astype(np.float32), (0, 0), 1.5)


def character(img):
    """Masque du personnage : isnet-anime, sinon le repli « lumière » si le modèle ne trouve rien de crédible."""
    m = segment(img)
    cover = (m > 0.5).mean()
    if 0.02 < cover < 0.85:
        return m, "modele"
    return glow_mask(img), "lumiere"


def field(mask):
    """Image RVB : masque, proximité extérieure et intérieure du contour."""
    h = mask.shape[0]
    hard = (mask > 0.5).astype(np.uint8)
    reach = 0.12 * h
    dout = cv2.distanceTransform(1 - hard, cv2.DIST_L2, 5)
    din = cv2.distanceTransform(hard, cv2.DIST_L2, 5)
    g = np.clip(1.0 - dout / reach, 0, 1) * (1 - hard)
    b = np.clip(1.0 - din / (0.04 * h), 0, 1) * hard
    return (np.dstack([b, g, mask]) * 255).astype(np.uint8)        # OpenCV écrit en BGR → R = masque


def colors(img, mask, n=3):
    """Couleurs dominantes du personnage, les plus vives d'abord (k-moyennes sur ses pixels assez saturés)."""
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    sel = (mask > 0.6) & (hsv[..., 1] > 70) & (hsv[..., 2] > 60)
    px = img[sel].astype(np.float32)
    if len(px) < 50:                                           # personnage gris / noir : on prend tout le masque
        px = img[mask > 0.6].astype(np.float32)
    if len(px) < 3:
        return []
    px = px[np.random.default_rng(0).choice(len(px), min(len(px), 20000), replace=False)]
    k = min(n + 2, len(px))
    _, lab, cen = cv2.kmeans(px, k, None, (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 0.5), 3,
                             cv2.KMEANS_PP_CENTERS)
    counts = np.bincount(lab.ravel(), minlength=k)
    out = []
    for i in range(k):
        b, g, r = cen[i]
        s = cv2.cvtColor(np.uint8([[[b, g, r]]]), cv2.COLOR_BGR2HSV)[0, 0, 1] / 255.0
        v = max(b, g, r) / 255.0
        out.append((counts[i] / len(px) * (0.15 + s) * (0.1 + v) ** 2, "#%02x%02x%02x" % (int(r), int(g), int(b))))
    return [c for _, c in sorted(out, reverse=True)[:n]]


def prepare(path, force=False):
    os.makedirs(OUT, exist_ok=True)
    name = os.path.splitext(os.path.basename(path))[0]
    fpng, fjson = os.path.join(OUT, name + ".png"), os.path.join(OUT, name + ".json")
    if not force and os.path.exists(fjson) and os.path.getmtime(fjson) >= os.path.getmtime(path):
        with open(fjson) as f:
            return json.load(f)
    img = cv2.imread(path, cv2.IMREAD_COLOR)
    if img is None:
        raise SystemExit("image illisible : " + path)
    img = cv2.resize(img, (W, round(img.shape[0] * W / img.shape[1])), interpolation=cv2.INTER_AREA)
    mask, how = character(img)
    cv2.imwrite(fpng, field(mask))
    res = {"field": os.path.abspath(fpng), "colors": colors(img, mask), "mask": how,
           "cover": round(float((mask > 0.5).mean()), 3)}
    with open(fjson, "w") as f:
        json.dump(res, f)
    return res


def test():
    img = np.zeros((400, 600, 3), np.uint8)
    img[:] = (40, 40, 40)
    cv2.circle(img, (300, 220), 100, (40, 40, 230), -1)        # personnage rouge (BGR)
    cv2.circle(img, (300, 220), 40, (230, 120, 30), -1)        # avec du bleu au milieu
    mask = np.zeros((400, 600), np.float32)
    cv2.circle(mask, (300, 220), 100, 1.0, -1)
    c = colors(img, mask)
    assert c and c[0] == "#e62828", c                          # le rouge domine
    assert "#1e78e6" in c, c
    f = field(mask)
    assert f[220, 300, 2] == 255 and f[220, 300, 1] == 0       # R = masque, pas d'aura dedans
    assert f[220, 405, 1] > 200 and f[220, 590, 1] < f[220, 405, 1]   # aura forte au bord, qui décroît
    assert f[220, 201, 0] > 200 and f[220, 300, 0] == 0        # liseré intérieur au bord seulement
    g = np.zeros((300, 400, 3), np.uint8)                      # anneau néon sur noir → disque plein
    cv2.circle(g, (200, 150), 80, (255, 80, 200), 6)
    gm = glow_mask(g)
    assert gm[150, 200] > 0.9 and gm[10, 10] < 0.1, (gm[150, 200], gm[10, 10])
    print("ok")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit(__doc__ or "wall-mana.py <image> | --test")
    if sys.argv[1] == "--test":
        test()
    else:
        print(json.dumps(prepare(sys.argv[1], "--force" in sys.argv)))
