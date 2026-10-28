# Quick-Bar — repères pour Claude

Shell Quickshell (QML) de Florian pour **Hyprland 0.56 en config Lua** (Arch/CachyOS). Répondre en **français**.
Carte complète : `docs/ARCHITECTURE.md` (flux, recettes, pièges, carte des fichiers). Après avoir ajouté ou
déplacé des fichiers : `python3 -I scripts/dev/gen-map.py` (régénère la carte).

## Machine
- Écrans : **DP-1** 3440×1440 (principal) · **DP-2** Xeneon Edge 2560×720 **tactile** (TouchPanel), sous DP-1.
- Hyprland : `~/.config/hypr/hyprland.lua` + `~/.config/hypr/configs lua/*.lua` (Keybinds, WindowRules, Startup_Apps,
  Monitors, XeneonEdge…). `hypr/quickbar.lua` est **généré** par Réglages › Raccourcis (ne pas l'éditer à la main).
  Plugin hy3 compilé à la main (`rebuild-hy3.sh`), jamais `sudo hyprpm`.
- Onglet Terminal du TouchPanel : qmltermwidget (paquet Arch) + fish avec `QB_CLEAN=1` (pas de fastfetch) ;
  bascule auto quand un éditeur passe au premier plan (`[touchpanel] follow_editors`, `editor_apps`).
  Le rechargement à chaud recrée la session du terminal (elle est perdue) et **peut faire planter** Quickshell
  (relance auto) : après une modif de `TerminalTab.qml`, redémarrer via `launch.sh` plutôt qu'attendre le rechargement.
- Services externes : OpenRGB = **un seul** serveur, `systemctl --user openrgb.service` (port 6742) ;
  UPower (batteries) ; `udevadm monitor` (branchements HID) ; wallust/matugen → `Appearance`.

## Lancer, recharger, vérifier
- Un fichier QML enregistré recharge à chaud. **Un singleton (`pragma Singleton`) modifié n'est pas recréé** par le
  rechargement, et une config cassée arrête la surveillance des fichiers → redémarrer :
  `qs kill -p shell.qml; setsid -f ~/.config/quickshell/Quick-Bar/scripts/launch.sh >/dev/null 2>&1`
  **Toujours via `scripts/launch.sh`** (lanceur unique : MALLOC_MMAP_THRESHOLD_ + QML_IMPORT_PATH des couleurs du
  terminal) — aussi utilisé par Startup_Apps.lua, les GameScripts et « Relancer Quick-Bar ».
- Journal : `qs log -p shell.qml | grep -E "ERROR|caused|WARN"` (ignorer desktopentry / textinput / IpcHandler en double).
- Capture d'un écran pour vérifier un rendu : `grim -o DP-2 fichier.png` (puis réduire avec `magick … -resize`).
- Piloter : `qs ipc -p shell.qml call <cible> <fonction> [arg]` — cibles ci-dessous.

| Cible | Fonctions | Cible | Fonctions |
|---|---|---|---|
| `dashboard-home` | toggle, open(page) | `settings` | toggle, open(page) |
| `touch` | page(p) | `menu` | open(path), close, current, run(name) |
| `overview` | toggle, open | `alttab` | next, prev, commit, cancel |
| `notifications` | toggle, clear, dnd | `updates` | upgrade, refresh, menu |
| `wallpicker` | toggle, videos, random | `wallcinema` | toggle, videos |
| `minimize` | minimize, restoreLast, restoreAll | `session` | toggle, open |
| `gamebreak` | toggle, start, stop, extend | `lock` | lock, tryUnlock(pw) |
| `spotify` | toggle | `screenrec-on`, `focus-toggle` | toggle |

## Règles de code (apprises à la dure)
- Couleurs **toujours** via `Appearance.colors.*` (accent = color11), jamais en dur ; libellés de palette via
  `Appearance.paletteName` (jamais « wallust » en dur). Durées via `Appearance.dur(ms)`.
- Imports par module (`qs.core`, `qs.services`, `qs.components`, `qs.pages.settings`…), jamais de chemin relatif ;
  Réglages : `sourceComponent`, pas `Loader.source` relatif.
- **Jamais d'`https://` dans un `Image`** (crash OpenSSL de Quickshell) → `components/CachedArt.qml`.
- Un singleton n'existe qu'une fois **lu** : un service qui doit tourner en fond est référencé dans `shell.qml`.
- `MouseArea` garde la molette → `onWheel: (w) => w.accepted = false` pour la laisser à un parent qui défile.
  `ListView` ignore le `y` de ses délégués → `anchors.verticalCenter`.
- Composant inline modifié à chaud → « X is not a type » : redémarrer.
- Hyprland : `hyprctl eval "hl.dispatch(hl.dsp.…)"`, un seul eval par lot ; glyphe Hyprland `` (U+F359).
- Réglages persistants : `Config.set("section.cle", v)` (`null` = défaut) → `config.toml` ; état d'UI :
  `core/ShellState.qml` → `user_data/shell_state.json`.
- **Pas de sondage** (`Timer` répétitif qui lance un `Process`) pour un état qui a des événements : modules natifs
  Quickshell 0.3 (`Services.Pipewire` via `Mixer`, `Services.Mpris`, `Bluetooth`, `Services.UPower`, `Hyprland.rawEvent`
  filtré + anti-rafale), sinon un flux (`nmcli monitor`, `rfkill event`, `udevadm monitor`) + un secours lent (≥ 30 s).
  Audit du 2026-10-28 : 0 processus lancé par Quick-Bar en 20 s au repos (contre ~300/min avant).
- Logique non triviale = un petit auto-test (`--test` dans les scripts Python, comme `device-photos.py`).

## Florian
- « Écris-moi le process » = il veut souvent coder lui-même : montrer, ne pas éditer.
- Confirmer avant tout ce qui est irréversible ou public. Ne pas tester à l'écran pendant qu'il joue.
- `user_data/`, `.discord_token`, `.dl_secret`, photos `assets/devices/*.png` : jamais versionnés.
- Push des dotfiles : dépôt `Eaquo/Hyprland-Dotfiles-Arch-linux` via `~/Sdd_Windsurf/Sauvegarde/v2`
  (`./sync.sh` puis `./sync.sh --go`, scan de secrets), commits `feat(quickbar): …` **sans attribution Claude**.
- Le git de `~/.config/quickshell` est celui du game-launcher : ne rien y pousser.
