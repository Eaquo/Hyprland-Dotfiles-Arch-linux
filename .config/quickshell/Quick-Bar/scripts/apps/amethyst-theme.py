#!/usr/bin/env python3
# Thème « Quick-Bar » pour Amethyst Mod Manager, calculé depuis la palette active (wallust ou matugen,
# même format JSON : special.background/foreground + colors.color0..15). Lancé par core/Appearance.qml
# à chaque rechargement de la palette. Écrit ~/.config/AmethystModManager/themes/quickbar.json.
# Usage : amethyst-theme.py <palette.json> [nom de la source] [clé d'accent, color11 par défaut]
import importlib.util, json, os, sys

APP = "/usr/lib/python3.14/site-packages/amethyst-mod-manager/themes/dark.py"
OUT = os.path.expanduser("~/.config/AmethystModManager/themes/quickbar.json")


def rgb(h): h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
def hexa(c): return "#%02x%02x%02x" % tuple(max(0, min(255, round(v))) for v in c)
def mix(a, b, t): return hexa(tuple(x + (y - x) * t for x, y in zip(rgb(a), rgb(b))))
def lum(h):
    def ch(v): v /= 255; return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = rgb(h); return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)
def contrast(a, b): x, y = sorted((lum(a), lum(b)), reverse=True); return (x + 0.05) / (y + 0.05)
def on(bg): return "#0a0a0a" if contrast(bg, "#0a0a0a") >= contrast(bg, "#ffffff") else "#ffffff"
def legible(c, bg, ratio=3.0):
    """éclaircit (fond sombre) ou fonce (fond clair) c jusqu'au contraste voulu sur bg"""
    target = "#ffffff" if lum(bg) < 0.4 else "#000000"
    for i in range(21):
        x = mix(c, target, i / 20)
        if contrast(x, bg) >= ratio: return x
    return target


def main():
    src = json.load(open(sys.argv[1]))
    name = sys.argv[2] if len(sys.argv) > 2 else "Wallust"
    key = sys.argv[3] if len(sys.argv) > 3 else "color11"
    cols, sp = src["colors"], src.get("special", {})
    bg, fg = sp.get("background", cols["color0"]), sp.get("foreground", cols["color15"])
    acc = legible(cols.get(key, cols["color11"]), bg, 3.0)        # accent lisible sur le fond
    acc2 = legible(mix(acc, fg, 0.25), bg, 4.5)                   # accent clair (liens, flèches)

    spec = importlib.util.spec_from_file_location("dark", APP)
    dark = importlib.util.module_from_spec(spec); spec.loader.exec_module(dark)
    pal = dict(dark.PALETTE)                                      # toutes les clés, valeurs de secours

    neutral = {
        "BG_DEEP": bg, "BG_LIST": mix(bg, fg, .03), "BG_PANEL": mix(bg, fg, .04), "BG_ROW": mix(bg, fg, .05),
        "BG_HEADER": mix(bg, fg, .06), "BG_ROW_ALT": mix(bg, fg, .075), "BG_ENTRY": mix(bg, fg, .02),
        "BG_CARD": mix(bg, fg, .09), "BG_CARD_ALT": mix(bg, fg, .07), "BG_OVERLAY_DEEP": bg, "BG_OVERLAY_ERR": mix(bg, acc, .12),
        "BG_ROW_HOVER": mix(bg, acc, .22), "BG_HOVER_ROW": mix(bg, acc, .22), "BG_HOVER": mix(bg, acc, .35),
        "BG_SELECT": mix(bg, acc, .55), "BG_SELECT_BAR": mix(bg, acc, .3), "BG_SEP": mix(bg, acc, .3),
        "BG_BTN_SAVE": mix(bg, acc, .55), "BG_DARK_BLUE": mix(bg, acc, .1),
        "ACCENT": acc, "ACCENT_HOV": mix(acc, fg, .2), "TEXT_ON_ACCENT": on(acc),
        "TEXT_MAIN": fg, "TEXT_WHITE": mix(fg, "#ffffff", .3), "TEXT_SEP": mix(fg, bg, .15),
        "TEXT_MUTED": mix(fg, bg, .3), "TEXT_DIM": mix(fg, bg, .45), "TEXT_FAINT": mix(fg, bg, .5),
        "TEXT_CARD": mix(fg, bg, .1), "TEXT_CARD_MED": fg, "TEXT_CARD_DIM": mix(fg, bg, .5),
        "BORDER": mix(bg, fg, .14), "BORDER_DIM": mix(bg, fg, .19), "BORDER_FAINT": mix(bg, fg, .24),
        "SCROLL_BG": mix(bg, fg, .14), "SCROLL_TROUGH": bg, "SCROLL_ACTIVE": acc, "CHECK_FILL": acc,
        "DROPDOWN_ARROW": acc2, "LINK_BLUE": acc2, "HIGHLIGHT_DRAG": acc2, "TONE_BLUE": acc2, "TONE_BLUE_SOFT": acc2,
        "BTN_GREY": mix(bg, fg, .15), "BTN_GREY_HOV": mix(bg, fg, .22), "BTN_GREY_ALT": mix(bg, fg, .12), "BTN_GREY_ALT_HOV": mix(bg, fg, .2),
        "BTN_NEUTRAL": mix(bg, acc, .5), "BTN_NEUTRAL_HOV": mix(bg, acc, .68),
        "BTN_INFO": mix(bg, acc, .45), "BTN_INFO_HOV": mix(bg, acc, .62), "BTN_INFO_DEEP": mix(bg, acc, .35), "BTN_INFO_DEEP_HOV": mix(bg, acc, .5),
        "BTN_PURPLE": acc, "BTN_PURPLE_HOV": mix(acc, fg, .2),
        "ROOT_SEP_BG": mix(bg, acc, .18), "ROOT_SEP_FG": acc2, "TAG_BUNDLED_BG": mix(bg, acc, .2), "TAG_BUNDLED_FG": acc2,
    }
    for k, v in pal.items():
        if k in neutral: pal[k] = neutral[k]
        elif isinstance(v, str) and v.startswith("#") and len(v) == 7:
            # couleurs d'état (vert OK, rouge danger, orange avertissement, conflits…) : sens gardé,
            # fonds sombres rapprochés du fond de la palette, textes rendus lisibles
            pal[k] = mix(v, bg, .25) if lum(v) < 0.08 else legible(v, bg, 3.0)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    tmp = OUT + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump({"NAME": f"Quick-Bar ({name})", "CTK_APPEARANCE": "dark" if lum(bg) < 0.4 else "light", "PALETTE": pal},
                  f, indent=2, ensure_ascii=False)
    os.replace(tmp, OUT)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--test":
        assert contrast("#000000", "#ffffff") > 20 and on("#ffffff") == "#0a0a0a" and on("#000000") == "#ffffff"
        assert contrast(legible("#202020", "#101010", 3.0), "#101010") >= 3.0
        print("ok")
    else:
        main()
