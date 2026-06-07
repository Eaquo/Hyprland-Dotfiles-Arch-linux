#!/usr/bin/env python3
"""
Inject wallust colors into Windsurf settings.json as colorCustomizations.
Vesper handles syntax; wallust handles UI & terminal.
"""

import json, re, sys
from pathlib import Path

COLORS_FILE  = Path.home() / ".cache/wal/colors.json"
SETTINGS_FILE = Path.home() / ".config/Windsurf/User/settings.json"

def strip_jsonc(text: str) -> str:
    """Remove // line comments from JSONC without breaking strings."""
    result = []
    in_string = False
    i = 0
    while i < len(text):
        c = text[i]
        if c == '"' and (i == 0 or text[i-1] != '\\'):
            in_string = not in_string
            result.append(c)
        elif not in_string and c == '/' and i+1 < len(text) and text[i+1] == '/':
            while i < len(text) and text[i] != '\n':
                i += 1
            continue
        else:
            result.append(c)
        i += 1
    return ''.join(result)

def alpha(color: str, a: str) -> str:
    return color.rstrip() + a

def build_color_customizations(c: dict) -> dict:
    bg   = c["special"]["background"]
    fg   = c["special"]["foreground"]
    col  = c["colors"]

    # Wallust role mapping
    bg_dark   = bg
    bg_mid    = alpha(col["color1"], "cc")   # sidebar/panel bg
    accent    = col["color11"]               # bright accent (pink/red)
    teal      = col["color13"]               # secondary accent
    blue      = col["color10"]               # focus / info
    muted     = col["color8"]                # inactive text
    selection = alpha(col["color2"], "55")   # selection bg
    border    = alpha(col["color2"], "44")   # subtle borders

    return {
        # ── Éditeur — wallust colore les accents, Vesper garde son fond noir ─
        # editor.background intentionnellement absent → Vesper #101010
        "editor.selectionBackground":            selection,
        "editor.selectionHighlightBackground":   alpha(col["color2"], "33"),
        "editor.wordHighlightBackground":        alpha(col["color5"], "33"),
        "editor.wordHighlightStrongBackground":  alpha(accent, "44"),
        "editor.findMatchBackground":            alpha(accent, "40"),
        "editor.findMatchHighlightBackground":   alpha(accent, "25"),
        "editor.lineHighlightBackground":        alpha(fg, "07"),
        "editorLineNumber.foreground":           alpha(muted, "80"),
        "editorLineNumber.activeForeground":     teal,
        "editorCursor.foreground":               accent,
        "editorIndentGuide.background1":         border,
        "editorIndentGuide.activeBackground1":   alpha(col["color5"], "88"),
        "editorBracketMatch.background":         alpha(teal, "25"),
        "editorBracketMatch.border":             alpha(teal, "88"),

        # ── Activity bar ─────────────────────────────────────────────────
        "activityBar.background":                bg_dark,
        "activityBar.foreground":                teal,
        "activityBar.inactiveForeground":        alpha(muted, "80"),
        "activityBar.activeBorder":              accent,
        "activityBarBadge.background":           accent,
        "activityBarBadge.foreground":           bg_dark,

        # ── Sidebar ───────────────────────────────────────────────────────
        "sideBar.background":                    bg_dark,
        "sideBar.border":                        border,
        "sideBarSectionHeader.border":           border,

        # ── Listes ───────────────────────────────────────────────────────
        "list.activeSelectionBackground":        alpha(col["color2"], "55"),
        "list.activeSelectionForeground":        fg,
        "list.inactiveSelectionBackground":      alpha(col["color1"], "88"),
        "list.hoverBackground":                  alpha(col["color2"], "30"),
        "list.highlightForeground":              accent,
        "list.focusBackground":                  alpha(col["color2"], "44"),

        # ── Tabs — accent wallust, fond Vesper ────────────────────────────
        "tab.activeBorderTop":                   accent,
        "tab.border":                            "#00000000",
        "editorGroupHeader.tabsBorder":          border,

        # ── Status bar ────────────────────────────────────────────────────
        "statusBar.border":                      border,
        "statusBarItem.hoverBackground":         alpha(teal, "22"),
        "statusBarItem.remoteBackground":        alpha(col["color2"], "bb"),
        "statusBarItem.remoteForeground":        fg,

        # ── Panel (terminal) ─────────────────────────────────────────────
        "panel.background":                      bg_dark,
        "panel.border":                          border,
        "panelTitle.activeForeground":           fg,
        "panelTitle.activeBorder":               accent,
        "panelTitle.inactiveForeground":         alpha(muted, "99"),

        # ── Title bar ─────────────────────────────────────────────────────
        "titleBar.activeBackground":             bg_dark,
        "titleBar.activeForeground":             fg,
        "titleBar.border":                       border,

        # ── Focus & inputs ────────────────────────────────────────────────
        "focusBorder":                           alpha(blue, "88"),
        "input.background":                      alpha(col["color1"], "cc"),
        "input.border":                          border,
        "input.foreground":                      fg,
        "input.placeholderForeground":           alpha(muted, "88"),
        "inputOption.activeBackground":          alpha(col["color2"], "66"),
        "inputOption.activeBorder":              accent,

        # ── Widgets (autocomplete, peek…) ─────────────────────────────────
        "editorWidget.background":               alpha(col["color1"], "ee"),
        "editorWidget.border":                   border,
        "editorSuggestWidget.selectedBackground": alpha(col["color2"], "66"),
        "editorSuggestWidget.highlightForeground": accent,
        "peekView.border":                       teal,
        "peekViewEditor.background":             bg_dark,
        "peekViewResult.background":             bg_dark,
        "peekViewTitle.background":              bg_dark,

        # ── Scrollbar ─────────────────────────────────────────────────────
        "scrollbarSlider.background":            alpha(col["color2"], "44"),
        "scrollbarSlider.hoverBackground":       alpha(col["color2"], "66"),
        "scrollbarSlider.activeBackground":      alpha(teal, "77"),

        # ── Badges & boutons ─────────────────────────────────────────────
        "badge.background":                      accent,
        "badge.foreground":                      bg_dark,
        "button.background":                     alpha(col["color2"], "cc"),
        "button.foreground":                     fg,
        "button.hoverBackground":                col["color2"],

        # ── Git decorations ───────────────────────────────────────────────
        "gitDecoration.addedResourceForeground":     col["color5"],
        "gitDecoration.modifiedResourceForeground":  blue,
        "gitDecoration.deletedResourceForeground":   accent,
        "gitDecoration.untrackedResourceForeground": teal,
        "gitDecoration.ignoredResourceForeground":   alpha(muted, "66"),

        # ── Terminal ANSI — palette wallust ──────────────────────────────
        "terminal.background":                   bg_dark,
        "terminal.foreground":                   fg,
        "terminalCursor.foreground":             accent,
        "terminal.ansiBlack":    col["color0"],
        "terminal.ansiRed":      col["color1"],
        "terminal.ansiGreen":    col["color2"],
        "terminal.ansiYellow":   col["color3"],
        "terminal.ansiBlue":     col["color4"],
        "terminal.ansiMagenta":  col["color5"],
        "terminal.ansiCyan":     col["color6"],
        "terminal.ansiWhite":    col["color7"],
        "terminal.ansiBrightBlack":    col["color8"],
        "terminal.ansiBrightRed":      col["color9"],
        "terminal.ansiBrightGreen":    col["color10"],
        "terminal.ansiBrightYellow":   col["color11"],
        "terminal.ansiBrightBlue":     col["color12"],
        "terminal.ansiBrightMagenta":  col["color13"],
        "terminal.ansiBrightCyan":     col["color14"],
        "terminal.ansiBrightWhite":    col["color15"],

        # ── Breadcrumbs ───────────────────────────────────────────────────
        "breadcrumb.foreground":               alpha(muted, "aa"),
        "breadcrumb.activeSelectionForeground": teal,
        "breadcrumb.focusForeground":           teal,

        # ── Quick input ──────────────────────────────────────────────────
        "quickInput.background":               alpha(col["color1"], "f0"),
        "quickInputList.focusBackground":      alpha(col["color2"], "66"),
        "quickInputHighlight.background":      alpha(accent, "44"),
    }

def luminosity(hex_color: str) -> float:
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return 0.299 * r + 0.587 * g + 0.114 * b

def build_token_customizations(c: dict) -> dict:
    col = c["colors"]

    # Trie toutes les couleurs par luminosité, garde celles lisibles (lum > 80)
    all_colors = [(k, v, luminosity(v)) for k, v in col.items()]
    visible = sorted(
        [(k, v, l) for k, v, l in all_colors if l > 80],
        key=lambda x: x[2]
    )
    # visible[0] = plus sombre lisible … visible[-1] = plus clair

    def pick(idx: int) -> str:
        """Prend une couleur dans visible par index relatif, sécurisé."""
        if not visible:
            return c["special"]["foreground"]
        return visible[min(idx, len(visible) - 1)][1]

    comment   = pick(0)   # plus sombre lisible  → commentaires
    operator  = pick(1)   # légèrement + clair   → opérateurs
    param     = pick(2)   # milieu bas           → paramètres
    type_     = pick(3)   # milieu               → types/classes
    tag       = pick(3)   # idem                 → tags QML/HTML
    property_ = pick(4)   # milieu haut          → propriétés
    func      = pick(5)   # clair                → fonctions
    string_   = pick(-2)  # avant-dernier        → strings
    variable  = pick(-2)  # idem                 → variables
    number    = pick(-3)  # 3e depuis la fin     → nombres
    keyword   = pick(-1)  # plus clair/vif       → mots-clés (bold)

    return {
        "textMateRules": [
            # ── Commentaires ──────────────────────────────────────────────
            {"scope": ["comment", "punctuation.definition.comment"],
             "settings": {"foreground": comment, "fontStyle": "italic"}},

            # ── Strings ───────────────────────────────────────────────────
            {"scope": ["string", "string.quoted", "string.template",
                       "string.interpolated"],
             "settings": {"foreground": string_}},

            # ── Mots-clés ─────────────────────────────────────────────────
            {"scope": ["keyword", "keyword.control", "keyword.operator.new",
                       "storage.type", "storage.modifier"],
             "settings": {"foreground": keyword, "fontStyle": "bold"}},

            # ── Fonctions & méthodes ──────────────────────────────────────
            {"scope": ["entity.name.function", "support.function",
                       "meta.function-call entity.name.function"],
             "settings": {"foreground": func}},

            # ── Types, classes, interfaces ────────────────────────────────
            {"scope": ["entity.name.type", "entity.name.class",
                       "support.class", "entity.other.inherited-class"],
             "settings": {"foreground": type_, "fontStyle": "italic"}},

            # ── Nombres & constantes ──────────────────────────────────────
            {"scope": ["constant.numeric", "constant.language",
                       "constant.character"],
             "settings": {"foreground": number}},

            # ── Variables ─────────────────────────────────────────────────
            {"scope": ["variable", "variable.other.readwrite"],
             "settings": {"foreground": variable}},

            # ── Paramètres ────────────────────────────────────────────────
            {"scope": ["variable.parameter", "meta.parameter"],
             "settings": {"foreground": param, "fontStyle": "italic"}},

            # ── Propriétés / attributs ────────────────────────────────────
            {"scope": ["variable.other.property", "support.type.property-name",
                       "entity.other.attribute-name"],
             "settings": {"foreground": property_}},

            # ── Opérateurs & ponctuation ──────────────────────────────────
            {"scope": ["keyword.operator", "punctuation.accessor",
                       "punctuation.separator"],
             "settings": {"foreground": operator}},

            # ── Tags HTML / QML ───────────────────────────────────────────
            {"scope": ["entity.name.tag", "support.class.component"],
             "settings": {"foreground": tag, "fontStyle": "bold"}},

            # ── Imports / modules ─────────────────────────────────────────
            {"scope": ["entity.name.module", "keyword.control.import",
                       "keyword.control.from"],
             "settings": {"foreground": keyword}},

            # ── Decorateurs / annotations ─────────────────────────────────
            {"scope": ["meta.decorator", "punctuation.decorator",
                       "entity.name.function.decorator"],
             "settings": {"foreground": type_, "fontStyle": "italic"}},
        ]
    }

def main():
    if not COLORS_FILE.exists():
        print(f"[windsurf-theme] {COLORS_FILE} not found.", file=sys.stderr)
        sys.exit(0)

    colors = json.loads(COLORS_FILE.read_text())

    raw = SETTINGS_FILE.read_text()
    cleaned = strip_jsonc(raw)
    settings = json.loads(cleaned)

    tokens = build_token_customizations(colors)
    col    = colors["colors"]

    # Semantic tokens (Python/Pyright override TextMate — les deux sont nécessaires)
    def lum_pick(idx):
        all_c = sorted(
            [(v, luminosity(v)) for v in col.values() if luminosity(v) > 80],
            key=lambda x: x[1]
        )
        if not all_c: return colors["special"]["foreground"]
        return all_c[min(idx, len(all_c)-1)][0]

    sep = col["color13"]  # couleur des séparateurs

    settings["workbench.colorTheme"] = "Vesper"
    settings["workbench.colorCustomizations"] = {
        "sideBar.border":      sep,
        "editorGroup.border":  sep,
        "tab.border":          sep,
        "activityBar.border":  sep,
        "editorWidget.border": sep,
        "input.border":        sep,
    }
    settings["editor.tokenColorCustomizations"] = tokens
    settings["editor.semanticTokenColorCustomizations"] = {
        "enabled": True,
        "rules": {
            "comment":            {"foreground": lum_pick(0),  "fontStyle": "italic"},
            "keyword":            {"foreground": lum_pick(-1), "fontStyle": "bold"},
            "string":             {"foreground": lum_pick(-2)},
            "number":             {"foreground": lum_pick(-3)},
            "function":           {"foreground": lum_pick(5)},
            "method":             {"foreground": lum_pick(5)},
            "class":              {"foreground": lum_pick(3),  "fontStyle": "italic"},
            "type":               {"foreground": lum_pick(3),  "fontStyle": "italic"},
            "variable":           {"foreground": lum_pick(-2)},
            "variable.readonly":  {"foreground": lum_pick(4)},
            "parameter":          {"foreground": lum_pick(2),  "fontStyle": "italic"},
            "property":           {"foreground": lum_pick(4)},
            "decorator":          {"foreground": lum_pick(3),  "fontStyle": "italic"},
            "namespace":          {"foreground": lum_pick(3)},
            "operator":           {"foreground": lum_pick(1)},
        }
    }

    SETTINGS_FILE.write_text(
        json.dumps(settings, indent=4, ensure_ascii=False)
    )
    print("[windsurf-theme] token colors updated from wallust palette.")

if __name__ == "__main__":
    main()
