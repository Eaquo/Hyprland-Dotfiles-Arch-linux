# Quick-Bar — architecture

Carte du projet : où est quoi, qui dépend de quoi, et comment ajouter quelque chose.
La table des fichiers en fin de document est générée à partir du code.

## Vue d'ensemble

```
Quick-Bar/
├── shell.qml      point d'entrée : instancie la barre, les panneaux, le wallpaper
├── core/          état global et thème (singletons) : Appearance, ShellState, Popups,
│   └── functions/   GameMode, GameBreak, WallpaperState… + ColorUtils, IconUtils
├── services/      ce qui tourne en fond, sans interface : Cava, Discord, Mixer (audio),
│   └── system/      notifications, enregistrement d'écran… + mesures CPU/GPU/RAM/disques
├── components/    briques d'interface réutilisables : ColorPicker, CachedArt, PopupShape,
│                    GradientBorder, StatCard, TabSwitcher, TimeInput
├── bar/           la barre du haut et ses widgets (horloge, workspaces, audio, tray…)
├── panels/        les fenêtres : Dashboard, TouchPanel, SpotifyPanel, popups, PowerMenu
├── pages/         le contenu des onglets, un dossier par page (home/, game/, mixer/…)
├── wallpaper/     Wallpaper.qml + shaders/ (matrix, aurora, underwater, fireworks — portés des shaders du terminal kitty)
├── scripts/       scripts appelés par le QML : audio/ discord/ game/ hypr/ media/ rgb/ wallust/
├── assets/        icônes
├── user_data/     tes réglages et données (JSON) — jamais versionné
└── docs/          ce document
```

**Règle de rangement** : un fichier va dans `services/` s'il n'affiche rien, dans
`components/` s'il est réutilisé par plusieurs écrans, dans `pages/<nom>/` s'il est le
contenu d'un onglet, dans `panels/` s'il est une fenêtre.

## Imports

Tous les fichiers s'importent par **module**, jamais par chemin relatif :

```qml
import qs.core            // Appearance, ShellState, Popups, GameMode…
import qs.core.functions  // ColorUtils, IconUtils
import qs.services        // Mixer, CavaService, DiscordService…
import qs.services.system // CpuService, GpuService…
import qs.components      // ColorPicker, CachedArt…
import qs.pages.home      // (un module par dossier)
```

`qs` = la racine du projet (Quickshell génère les modules à partir des dossiers ; un
fichier `pragma Singleton` devient automatiquement un singleton). Déplacer un fichier
ne casse donc que les imports du module qu'il quitte.

Les pages chargées à la demande le sont par chemin : `Loader { source: "../pages/x/X.qml" }`.

## Flux principaux

**Couleurs (wallust)** — `wallust run <image>` écrit `~/.cache/wal/wal.json` →
`core/Appearance.qml` le surveille et expose `Appearance.colors.*` (accent = color11) →
tout se recolore. L'onglet Wallust applique une palette modifiée via
`scripts/wallust/wallust_override.sh` (`wallust cs`, puis `~/.config/hypr/scripts/Refresh.sh`).

**État persistant** — `core/ShellState.qml` ↔ `user_data/shell_state.json` (barre sur un
écran, TouchPanel allumé, ordre des onglets) ; `core/WallpaperState.qml` ↔
`user_data/wallpaper_fx.json` (effet du wallpaper). Aucune sauvegarde n'a lieu avant la
première lecture du fichier (sinon les valeurs par défaut écrasent l'état au démarrage).

**Panneaux et popups** — `core/Popups.qml` contient un booléen par popup
(`dashboardOpen`, `spotifyOpen`…). Chaque fenêtre de `panels/` s'affiche selon le sien.
Ouverture depuis Hyprland par IPC :
`qs -p ~/.config/quickshell/Quick-Bar/shell.qml ipc call <cible> toggle`
(cibles : `dashboard-home`, `spotify`, `gamebreak`).

**TouchPanel (Xeneon)** — `panels/TouchPanel.qml` contient **le catalogue des onglets**
(`allTabs`) : une ligne par onglet (clé, icône, libellé, page, zoom, `keep`, `def`).
L'ordre et l'activation choisis avec le bouton ⚙ sont dans `ShellState.touchTabs`.

**Mode jeu** — une fenêtre au tag Hyprland `games` (règles de
`~/.config/hypr/configs lua/WindowRulesGaming.lua`) → `core/GameMode.qml` passe `active` :
preset EQ FPS, LED à la couleur du jeu, page Game affichée. Visuels du jeu :
`scripts/game/game_art.sh` (cache Steam). Temps de jeu : `scripts/game/game_sessions.py`
→ `user_data/game_sessions.json`. État d'avant-jeu gardé dans `/tmp/quickbar-gamemode-*`.

**Audio** — `services/Mixer.qml` est le seul accès à PipeWire (sorties, flux par
application, volumes). Les pages Mixer, Game, Eq et le panneau Spotify passent par lui.
L'égaliseur passe par EasyEffects (`scripts/audio/eq_control.py`).

**RGB** — `scripts/rgb/rgb_watch.sh ensure|restart` lance le démon
`script/OpenRGB_Controller_Watch.py`, qui applique le mode écrit dans
`script/conf/sequence.txt`. Le QML ne fait qu'écrire ce fichier.

**Wallpaper et effets** — `wallpaper/Wallpaper.qml` affiche l'image à travers
`shaders/<thème>.frag.qsb`. Entrées communes à tous les shaders : `intensity`, `time`,
`resolution`, `accent`, `source`.

### Divers récents
- **Veille du Xeneon** : `panels/TouchPanel.qml` (`idle`, `idleTimer`, `wake()`), délai `ShellState.touchIdleMinutes` (0 = jamais) ; grande horloge + titre en cours.
- **Rotation du wallpaper** : `WallpaperState.autoChange` / `autoMinutes` / `randomWall()` ; en pause en mode vidéo et en jeu.
- **En jeu** : les effets du wallpaper sont suspendus (`Wallpaper.qml`, `fxAllowed`).
- **Rôles des couleurs wallust** : color11 = accent, color12 = survol, color13 = focus/urgent, color8 = atténué, color0 = surface. Notes par couleur dans `pages/wallust/WallustTab.qml` (`roles`).

## Liens avec l'extérieur

| Qui | Pointe vers | Pour |
|---|---|---|
| `hypr/configs lua/Startup_Apps.lua` | `shell.qml`, `scripts/rgb/rgb_watch.sh ensure` | lancer la barre et le démon RGB |
| `hypr/configs lua/Keybinds_app.lua`, `XeneonEdge.lua` | `shell.qml ipc call …` | raccourcis (Spotify, pause tactile) |
| `hypr/configs lua/WindowRules.lua` | calque `quickshell:spotify` | pas d'animation Hyprland sur ce panneau |
| `hypr/scripts/Refresh.sh` | `scripts/rgb/rgb_watch.sh restart`, `scripts/rgb/script` | recharger après un changement de couleurs |
| `hypr/scripts/GameScripts/*` | `shell.qml` | relancer la barre autour des jeux |
| Quick-Bar | `~/.config/hypr/scripts/set-wallpaper.sh`, `set-video-wallpaper.sh`, `list-wallpapers.sh`, `Refresh.sh` | onglet Wall, onglet Wallust |
| Quick-Bar (`pages/games/GameTab.qml`) | `~/.config/quickshell/game-launcher/modules/service/backend.py` | liste et jaquettes des jeux |
| Quick-Bar | `~/.cache/wal/wal.json`, `~/.curr_wall_static.jpg`, `~/.config/rofi/.current_wallpaper` | couleurs et wallpaper courant |

Les dossiers voisins `overview/`, `rgb-launcher/`, `hyprquickpaper/` ne sont pas
utilisés par Quick-Bar (réserve d'idées). Seul `game-launcher/` l'est.

Secrets (jamais versionnés) : `.discord_token`, `.dl_secret`, `user_data/`.

## Recettes

### Ajouter un onglet au TouchPanel
1. Créer `pages/<nom>/<Nom>Tab.qml` (un `Item` qui remplit son parent).
2. Ajouter **une ligne** au catalogue `all` de `core/TouchTabs.qml` :
   `{ key: "<nom>", icon: "<glyphe>", label: "<Nom>", src: "../pages/<nom>/<Nom>Tab.qml" }`
   Options : `scale: 1.15` (zoom), `keep: true` (reste chargée), `def: false` (désactivé par défaut).
   Activation et ordre : bouton ⚙ du panneau (carrousel) ou Réglages › Panneau tactile.

Pour l'avoir aussi dans le Dashboard (popup) : l'ajouter à `allTabs` et à la liste de pages de
`panels/Dashboard.qml`, et au catalogue de `pages/settings/DashboardPage.qml`.

### Ajouter une page de Réglages
`pages/settings/<Nom>Page.qml`, puis dans `panels/SettingsPanel.qml` : une ligne au catalogue `tabs`
(groupe, glyphe, mots-clés de recherche, `src`), un `Component { id: <nom>C; <Nom>Page {} }` et l'entrée
`<src>: <nom>C` dans `pages`.

### Ajouter un périphérique (photo)
Ligne dans `assets/devices/devices.json` (fiche produit Shopify + n° de photo, `"fond": "tout"` pour un arceau),
ou Réglages › Périphériques, ou un PNG `assets/devices/<slug du modèle>.png`. Script :
`scripts/system/device-photos.py` (`images` / `set` / `file` / `rm`). Service : `services/Batteries.qml`
(UPower + Vader en HID, notifications de connexion/déconnexion, `ShellState.devicesSeen`).

### Ajouter un effet de wallpaper (shader)
1. Écrire `wallpaper/shaders/<nom>.frag` avec le même bloc `uniform buf` que les autres
   (`intensity`, `time`, `resolution`, `accent`) et `sampler2D source`. Quand
   `intensity < 0.001`, rendre l'image telle quelle.
2. Compiler : `wallpaper/shaders/build.sh` (produit `<nom>.frag.qsb`).
3. Ajouter `"<nom>"` à `themes` dans `core/WallpaperState.qml`.

### Ajouter une vérification au bilan de santé
Dans `scripts/health/check.sh` : une fonction `check_<id>` (qui appelle `row id "Libellé" 0|1 "détail"`),
éventuellement `fix_<id>` (la ligne devient alors réparable au toucher), puis ajouter `<id>` à `CHECKS`.
Rien à toucher côté QML : `services/Health.qml` lit le JSON, `pages/health/HealthTab.qml` l'affiche.

### Régler les tailles (config.toml)
`config.toml` à la racine, relu à chaud par `core/Config.qml` : `[touchpanel] scale` (zoom global des
pages), `[touchpanel.pages] <clé d'onglet>` (zoom par page), `[fonts]` (police et tailles du thème).
Dans le code : `Config.get("fonts.body", 16)`, `Config.pageScale("wall", 1.0)`.

### Ajouter un widget à la barre
Créer `bar/<Nom>.qml` puis l'instancier dans une des trois pastilles de `bar/Bar.qml`.
Les widgets `Bluetooth`, `Eq`, `MediaPlayer`, `Network` existent mais sont désactivés.

### Ajouter un panneau qui sort d'un bord
Copier `panels/SpotifyPanel.qml` : un booléen dans `core/Popups.qml` (à ajouter à
`anyOpen` et `closeAll()`), un `IpcHandler`, `PopupShape` (`attachedEdge`), l'instancier
dans `shell.qml`, puis un `hl.bind` dans Hyprland. Penser à la règle
`hl.layer_rule({ match = { namespace = "…" }, no_anim = true })` si le panneau a sa
propre animation.

### Redémarrer Quick-Bar proprement
```bash
qs kill -p ~/.config/quickshell/Quick-Bar/shell.qml
setsid -f ~/.config/quickshell/Quick-Bar/scripts/launch.sh >/dev/null 2>&1   # lanceur unique (environnement)
qs log -p ~/.config/quickshell/Quick-Bar/shell.qml | grep -E "ERROR|caused"
```
Nécessaire quand un **singleton** a changé (le rechargement à chaud ne le recrée pas) ou après un
échec de chargement (la surveillance des fichiers s'arrête). Vérifier ensuite qu'il n'y a qu'une
instance : `pgrep -af "quickshell -p"`.

## Pièges connus

- **Singletons** : un singleton n'est créé qu'à sa première lecture (un service de fond doit être
  référencé dans `shell.qml`, voir `Batteries`) et n'est pas recréé par le rechargement à chaud.
- **Molette** : une `MouseArea` garde les événements de molette ; `onWheel: (w) => w.accepted = false`
  pour qu'un `ListView`/`Flickable` parent les reçoive. Un `ListView` ignore le `y` de ses délégués.

- **HTTPS depuis Qt** : charger une image `https://` dans un `Image` peut faire planter
  Quickshell (OpenSSL). Passer par `components/CachedArt.qml` (téléchargement `curl`).
- **Hyprland en config Lua** : les actions passent par `hyprctl eval "hl.dispatch(hl.dsp.…)"`,
  toutes dans un seul `eval`. Un workspace inexistant est créé sur l'écran qui a le focus.
- **`pkill -f`** tue aussi un shell dont la ligne de commande contient le motif.
- **Shaders du wallpaper** : portés depuis `/usr/lib/kitty/kitty/shaders/custom/*.slang` (Slang → GLSL 440). Pas de `uint` (qsb génère des variantes GLSL qui n'en ont pas) ; `mul(M, v)` de Slang = `v * M` en GLSL. Les thèmes retirés sont dans `~/Sdd_Windsurf/Sauvegarde/backups/shaders-retires/`.

## Fichiers à découper

Les plus gros fichiers, à scinder en sous-composants quand on y retouche :

- `pages/grid/GridDash.qml` — 1261 lignes
- `pages/home/QuickSettings.qml` — 1100 lignes
- `pages/kanban/KanbanBoard.qml` — 1087 lignes
- `pages/eq/EqDash.qml` — 962 lignes
- `pages/files/FileBrowser.qml` — 909 lignes
- `pages/home/ClockCard.qml` — 780 lignes
- `pages/config/KeybindsPage.qml` — 565 lignes
- `panels/TouchPanel.qml` — 538 lignes

## Carte des fichiers

Générée par `scripts/dev/gen-map.py` (rôle = commentaire d'en-tête du fichier). « Utilisé par » liste
les fichiers qui instancient ou appellent le type, ou qui lancent le script.

### `racine`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `shell.qml` (160 l.) | @ pragma UseQApplication | *(point d'entrée)* |

### `bar/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `AppLauncher.qml` (26 l.) | même lanceur que Super seul (menus/scripts/apps.sh, IPC menu run apps) ; recliquer le referme | Bar |
| `Audio.qml` (99 l.) | Rangée en barre horizontale, colonne en barre verticale ([bar] position) | Bar |
| `Bar.qml` (174 l.) | Écran principal = le plus grand (l'ultrawide, pas le tactile) | BarModules, Minimized, shell |
| `BarSeparator.qml` (10 l.) |  / Bar | Bar |
| `Bluetooth.qml` (65 l.) | Rangée en barre horizontale, colonne en barre verticale ([bar] position) | Bar, QuickSettings |
| `Cava.qml` (188 l.) | Jaquette ronde visible dès qu'un lecteur est actif | Bar |
| `Clock.qml` (45 l.) | barre verticale : heures et minutes l'une sous l'autre | Bar |
| `Eq.qml` (58 l.) | Animation fluide | Bar |
| `LayoutDisplayer.qml` (288 l.) | ─── LayoutDisplayer ──────────────────────────────────────────────────────── | Bar |
| `LocalSend.qml` (105 l.) | Pulse dot when active | Bar |
| `MediaPlayer.qml` (176 l.) | ── Data ───────────────────────────────────────────────────────────── | Bar |
| `Minimized.qml` (77 l.) | Fenêtres réduites (services/Minimize.qml, remplace niflveil) : caché s'il n'y en a pas ; sinon logo dock | Bar, Minimize |
| `Network.qml` (79 l.) | Rangée en barre horizontale, colonne en barre verticale ([bar] position) | Bar, QuickSettings |
| `Notifications.qml` (51 l.) | Rangée en barre horizontale, colonne en barre verticale ([bar] position) | Bar |
| `PowerButtons.qml` (54 l.) | Rangée en barre horizontale, colonne en barre verticale ([bar] position) | Bar |
| `Proxmox.qml` (47 l.) | Mises à jour du serveur Proxmox (hôte + LXC) : scan silencieux de menus/scripts/proxmox.sh toutes | Bar |
| `SysStats.qml` (569 l.) | CPU · RAM · températures (CPU, GPU, NVMe) · disque dans la barre | Bar, SysData |
| `SysTray.qml` (184 l.) | Rangée en barre horizontale, colonne en barre verticale ([bar] position) | Bar |
| `Updates.qml` (43 l.) | Rangée en barre horizontale, colonne en barre verticale ([bar] position) | Bar, GridDash, Updates, shell |
| `Workspaces.qml` (107 l.) | Rangée en barre horizontale, colonne en barre verticale ([bar] position) | Bar |

### `components/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `CachedArt.qml` (28 l.) | rend une image distante affichable sans requête HTTPS de Qt | DevicesPage, PlayerCard, SpotifyPanel |
| `ColorPicker.qml` (205 l.) | sélecteur de couleur tactile (HSV) en surimpression | WallpaperTab, WallustTab |
| `GradientBorder.qml` (78 l.) | Contour arrondi tracé avec un dégradé 45° des couleurs wallust qui défile | Bar, GameModeTab, Menu, NotifCard, SessionPanel … (+2) |
| `MorphCard.qml` (61 l.) | carte qui s'ouvre comme les cartes de survol de la barre : | DashBattery, StatsBoard, StreamDeck |
| `NotifCard.qml` (167 l.) | une notification, même aspect que les menus Quick-Bar (verre, arrondi relié à la barre, | NotifCenter, NotifToasts |
| `PopupShape.qml` (207 l.) | Draws a popup background that "melts" into whichever edge(s) it's attached to | Dashboard, NotifCenter, SpotifyPanel |
| `StatCard.qml` (98 l.) | Reusable card background. Wrap any stats panel in this for | CalendarCard, ClockCard, EqDash, ProfileCard, QuickSettings |
| `TabSwitcher.qml` (244 l.) | Unified tab switcher — horizontal or vertical | ClockCard, Dashboard, ShellConfig |
| `TimeInput.qml` (152 l.) | reusable HH:MM input | ClockCard |

### `components/stats/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `CpuCard.qml` (51 l.) | carte CPU : charge, courbe, cœurs, processus (survol de la barre, pages System) | GridDash, StatsBoard, SysStats |
| `CpuTempCard.qml` (32 l.) | carte température CPU : Tctl, CCD (survol de la barre, pages System) | GridDash, StatsBoard, SysStats |
| `DiskCard.qml` (41 l.) | carte disques : place, débit, à récupérer (survol de la barre, pages System) | GridDash, StatsBoard, SysStats |
| `GpuCard.qml` (32 l.) | carte GPU : températures, charge, VRAM, puissance, ventilateur (survol de la barre, pages System) | GridDash, StatsBoard, SysStats |
| `NetCard.qml` (24 l.) | carte réseau : débit descendant / montant de l'interface par défaut, courbe | GridDash, StatsBoard |
| `NvmeCard.qml` (31 l.) | carte SSD NVMe : températures, débit (survol de la barre, pages System) | GridDash, StatsBoard, SysStats |
| `RamCard.qml` (44 l.) | carte mémoire : utilisée/cache/libre, courbe, plus gros (survol de la barre, pages System) | GridDash, StatsBoard, SysStats |
| `StatCaption.qml` (14 l.) | élément des cartes de stats (barre et pages System) | CpuCard, DiskCard, GpuCard, RamCard |
| `StatHeader.qml` (19 l.) | élément des cartes de stats (barre et pages System) | CpuCard, CpuTempCard, DiskCard, GpuCard, NetCard … (+2) |
| `StatHint.qml` (13 l.) | élément des cartes de stats (barre et pages System) | CpuCard, CpuTempCard, DiskCard, GpuCard, NetCard … (+2) |
| `StatMeter.qml` (32 l.) | élément des cartes de stats (barre et pages System) | CpuCard, CpuTempCard, DiskCard, GpuCard, NetCard … (+2) |
| `StatSpark.qml` (34 l.) | élément des cartes de stats (barre et pages System) | CpuCard, CpuTempCard, DiskCard, GameModeTab, GpuCard … (+3) |

### `core/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `AppDeck.qml` (64 l. · singleton) | tuiles de l'onglet Apps (pages/apps/StreamDeck.qml), éditées dans Réglages › Apps | AppsPage, StreamDeck |
| `Appearance.qml` (344 l. · singleton) | ── Source des couleurs (Réglages › Couleurs, [theme] dans config.toml) ── | AltTab, AnimPage, AppDeck, AppLauncher, Apps … (+126) |
| `BarModules.qml` (49 l. · singleton) | catalogue des modules de la barre et disposition ([bar.layout] dans config.toml) | Bar, BarPage |
| `ClockState.qml` (32 l. · singleton) | état des modules horloge (timer / chrono / alarmes) | ClockCard |
| `Config.qml` (122 l. · singleton) | réglages généraux lus dans config.toml (à la racine du projet) | AltTab, AnimPage, AppDeck, Appearance, AppsPage … (+63) |
| `GameBreak.qml` (131 l. · singleton) | « pause tactile » pendant un jeu | GameBreakBar, GameModeTab, GamePage, HealthTab, MixerTab … (+6) |
| `GameMode.qml` (197 l. · singleton) | bascule automatique quand un jeu tourne | GameModeTab, GamePage, TouchPanel, Wallpaper, WallpaperState |
| `Popups.qml` (96 l. · singleton) | ── État d'ouverture par popup ───────────────────────────────────────── | AltTab, AppsPage, AudioPage, BarPage, Cava … (+30) |
| `ShellState.qml` (108 l. · singleton) | État global du shell | AppsPage, Bar, Batteries, DevicesPage, GameBreak … (+18) |
| `TouchTabs.qml` (50 l. · singleton) | catalogue des onglets du panneau tactile (TouchPanel.qml) et de leur état | AppsPage, TerminalTab, TouchPage, TouchPanel |
| `WallpaperState.qml` (197 l. · singleton) | État + config des effets wallpaper (glitch, screen shader) | Appearance, GridDash, LockScreen, Menu, Overview … (+13) |

### `core/functions/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `ColorUtils.qml` (36 l. · singleton) | Fonctions couleur : mix, transparence, applyAlpha | AltTab, AnimPage, Apps, AppsPage, Bar … (+70) |
| `IconUtils.qml` (119 l. · singleton) | Populated at startup from the GTK icon theme directory | Minimized, SysTray, ThemePage |

### `menus/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `lib.sh` (50 l.) | fonctions disponibles dans les scripts de menus (menus/scripts/*.sh). Voir README.md | run.sh |
| `run.sh` (51 l.) | run.sh <script> [args…] — lance le menu menus/scripts/<script>.sh (appelé par `qbmenu run`) | Menu.qml, Proxmox.qml, QuickSettings.qml, Updates.qml, menus.sh … (+3) |

### `menus/scripts/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `apps.sh` (6 l.) | Lanceur d'applications (remplace rofi -show drun) — SUPER+D | AppLauncher.qml |
| `bluetooth.sh` (66 l.) | Bluetooth : allumer, connecter, appairer, oublier — CTRL+B (ou clic molette sur la tuile Bluetooth) | — |
| `calc.sh` (9 l.) | Calculatrice (qalculate) : résultat en direct, entrée copie le résultat | — |
| `clipboard.sh` (15 l.) | Presse-papiers (cliphist) : recopier, supprimer une entrée, tout vider — SUPER+ALT+V | — |
| `command.sh` (9 l.) | Lancer une commande (comme rofi -show run) ; maj+entrée la lance dans un terminal | — |
| `cours.sh` (138 l.) | Carte du cours de programmation (~/Samsung_Game/Cours code) : modules, exercices, Claude prof — ALT+C | — |
| `emoji.sh` (10 l.) | Emojis : chercher en anglais (smile, heart, cat…), entrée copie — SUPER+ALT+E | — |
| `files.sh` (29 l.) | Chercher un fichier dans le dossier personnel (aperçu à droite), entrée l'ouvre | — |
| `game-scripts.sh` (43 l.) | Scripts de jeux (gamescope, MangoHud…) : ouvrir, créer, modifier le modèle — SUPER+MAJ+G | — |
| `keyhints.py` (370 l.) | — | keyhints.sh |
| `keyhints.sh` (25 l.) | Aide-mémoire des raccourcis, construit automatiquement depuis la config Hyprland — SUPER+H | keyhints.py |
| `menus.sh` (16 l.) | Tous les menus Quick-Bar (ce dossier) : en choisir un pour le lancer | — |
| `proxmox.sh` (133 l.) | Mises à jour Proxmox : l'hôte et chaque LXC (apt), le changelog Debian à droite ; entrée = un paquet, un conteneur ou tout | Proxmox.qml |
| `quickedit.sh` (39 l.) | Éditer une config : d'abord Lua, conf de base ou Quick-Bar, puis le fichier (aperçu à droite) — SUPER+MAJ+E | — |
| `search.sh` (10 l.) | Recherche web dans le navigateur par défaut — SUPER+MAJ+Z | — |
| `themes.sh` (19 l.) | Palettes wallust prêtes à l'emploi : aperçu des couleurs, entrée applique à tout le système | — |
| `updates.sh` (142 l.) | Mises à jour du système : la liste des paquets (dépôts et AUR) avec leur changelog à droite ; entrée = mettre à jour ce paquet ou tout | Updates.qml |
| `windows.sh` (17 l.) | Fenêtres ouvertes : aller sur l'une d'elles (comme rofi -show window) | — |

### `menus/templates/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `Apps.qml` (55 l.) | lanceur d'applications (les .desktop installés), comme rofi -show drun : | AppDeck |
| `Confirm.qml` (45 l.) | une question (MESSAGE / TITLE) et des boutons (les items ; Oui / Non par défaut) | — |
| `Emoji.qml` (31 l.) | grille dense : le premier mot de chaque ligne est affiché en grand, le reste sert à chercher | — |
| `Files.qml` (65 l.) | liste de fichiers avec aperçu à droite (image ou début du texte) | — |
| `Grid.qml` (132 l.) | tuiles : image (icon = chemin ou nom d'icône, recadrée) ou glyphe, libellé dessous | CalendarCard, CalendarWindow, GridDash, KanbanBoard, QuickSettings … (+1) |
| `Info.qml` (79 l.) | affichage seul (aide-mémoire, raccourcis…) : « touche<TAB>description<TAB>détail », | — |
| `Input.qml` (11 l.) | une saisie libre (recherche web, calcul…). Entrée renvoie le texte tapé ; | — |
| `List.qml` (128 l.) | une ligne par choix. Tabulations = colonnes (largeur selon la plus longue) | — |
| `Scan.qml` (203 l.) | une tâche longue avec barre de progression (mises à jour…). Le 1er item porte `cmd` : | — |
| `Theme.qml` (52 l.) | cartes de thème : aperçu (icon = image) et/ou bande de couleurs (métadonnée colors="#a,#b,…") | Appearance |

### `pages/apps/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `StreamDeck.qml` (181 l.) | onglet Apps : lanceurs en sections, une carte par section (même ouverture | AppDeck, Dashboard, TouchTabs |

### `pages/battery/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `DashBattery.qml` (125 l.) | page Devices du dashboard : une carte par périphérique de services/Batteries.qml | Dashboard, TouchTabs |

### `pages/config/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `KeybindsPage.qml` (565 l.) | ── Capture state ───────────────────────────────────────────────────────── | KeysPage, ShellConfig |
| `ShellConfig.qml` (84 l.) | ── Left: tab column (30%) ──────────────────────────────────────────── | — |

### `pages/discord/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `DiscordChat.qml` (527 l.) | vue de l'onglet Discord (TouchPanel + Dashboard) | Dashboard, TouchTabs |

### `pages/eq/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `EqDash.qml` (962 l.) | page Equalizer du dashboard, en 3 blocs : | Dashboard, TouchPanel, TouchTabs |

### `pages/files/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `FileBrowser.qml` (909 l.) | onglet "Files" du dashboard, dans l'esprit de yazi | Dashboard, TouchTabs |

### `pages/game/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `GameModeTab.qml` (824 l.) | page « Game » du TouchPanel, façon HUD : fond = bannière du jeu floutée | TouchTabs |

### `pages/games/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `GameTab.qml` (301 l.) | grille de jeux tactile, basée sur le backend du game-launcher | Dashboard, TouchTabs |

### `pages/grid/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `GridDash.qml` (1403 l.) | page « Grid » : tableau de widgets déplaçables/redimensionnables | TouchTabs |

### `pages/health/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `HealthTab.qml` (164 l.) | bilan de santé (TouchPanel), 4 colonnes × 5 lignes. Toucher une ligne ouvre ce | TouchTabs |

### `pages/home/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `CalendarCard.qml` (174 l.) | Calendar card — month grid with prev/next navigation | DashHome, GridDash, TouchHome |
| `ClockCard.qml` (780 l.) | Clock / Timer / Alarm / Stopwatch | DashHome, TouchHome |
| `DashHome.qml` (116 l.) | Dashboard Home tab — layout only | Dashboard |
| `PlayerCard.qml` (535 l.) | ── Source allowlist ────────────────────────────────────────────────────── | CavaService, DashHome, GridDash, TouchHome |
| `ProfileCard.qml` (145 l.) | Profile card — circular avatar, username, window manager, uptime | DashHome, GridDash, TouchHome |
| `QuickSettings.qml` (1139 l.) | Right column — brightness slider + scrollable quick-settings grid | DashHome, GridDash, ShellState, TouchHome |
| `TouchHome.qml` (93 l.) | variante tactile (ultra-large) de la page Home du Dashboard | TouchTabs |

### `pages/kanban/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `KanbanBoard.qml` (1087 l.) | three columns, JSON at $HOME/.config/quickshell/Quick-Bar/user_data/tasks.json | Dashboard, TouchTabs |

### `pages/mixer/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `MixerTab.qml` (219 l.) | mixeur tactile (TouchPanel) : une tranche verticale par app qui | TouchTabs |

### `pages/rgb/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `RgbTab.qml` (357 l.) | onglet RGB (OpenRGB), consolidé depuis l'ancien rgb-launcher | TouchTabs |

### `pages/settings/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `AnimPage.qml` (248 l.) | Réglages › Apparence › Animations : vitesse globale ([theme] anim_speed) | SettingsPanel |
| `AppsPage.qml` (235 l.) | Réglages › Panneaux › Apps : sections et applis de l'onglet Apps | SettingsPanel |
| `AudioPage.qml` (112 l.) | Réglages › Multimédia › Audio et EQ : sortie/entrée par défaut (pactl) | SettingsPanel |
| `BarPage.qml` (438 l.) | Réglages › Barre › Modules : disposition ([bar.layout]) par glisser-déposer, | SettingsPanel |
| `CapturePage.qml` (57 l.) | Réglages › Multimédia › Capture d'écran ([capture] dans config.toml ; | SettingsPanel |
| `ColorsPage.qml` (129 l.) | Réglages › Apparence › Couleurs : source de la palette ([theme]) | SettingsPanel |
| `DashboardPage.qml` (52 l.) | Réglages › Panneaux › Dashboard ([dashboard] width · height · tabs) | SettingsPanel |
| `DataPage.qml` (81 l.) | Réglages › Avancé › Données : sauvegarde / restauration de config.toml + user_data, | SettingsPanel |
| `DepsPage.qml` (147 l.) | Réglages › Système › Dépendances | SettingsPanel |
| `DevicesPage.qml` (191 l.) | Réglages › Panneaux › Périphériques : notifications de connexion, et photo de chaque | SettingsPanel |
| `FontsPage.qml` (109 l.) | Réglages › Apparence › Police ([fonts] dans config.toml) | SettingsPanel |
| `GamePage.qml` (102 l.) | Réglages › Jeu › Mode jeu ([game] dans config.toml, lu par core/GameMode.qml) | SettingsPanel |
| `GeneralPage.qml` (162 l.) | Réglages › Général : profil, applications, écrans ([general]) | SettingsPanel |
| `HealthPage.qml` (298 l.) | Réglages › Système › Santé ([health] proxmox · skip · [[health.custom]] ; scripts/health/check.sh) | SettingsPanel |
| `KeysPage.qml` (23 l.) | Réglages › Avancé › Raccourcis : la page Keybinds existante (pages/config/KeybindsPage.qml) | SettingsPanel |
| `NotifPage.qml` (69 l.) | Réglages › Panneaux › Notifications : swaync (~/.config/swaync/config.json, | SettingsPanel |
| `PageHeader.qml` (15 l.) | titre de page + sous-titre (souvent : où c'est rangé dans config.toml) | AnimPage, AppsPage, AudioPage, BarPage, CapturePage … (+19) |
| `PlannedPage.qml` (27 l.) | page de réglages pas encore construite : ce qu'elle contiendra | SettingsPanel |
| `RefreshPage.qml` (64 l.) | Réglages › Barre › Rafraîchissement : intervalles de mise à jour ([refresh], en secondes) | SettingsPanel |
| `SessionPage.qml` (70 l.) | Réglages › Panneaux › Écran de session ([session] style, lu par panels/SessionPanel.qml) | SettingsPanel |
| `SetButton.qml` (24 l.) | bouton des pages de réglages (primary = plein, active = sélectionné) | AnimPage, AppsPage, AudioPage, BarPage, CapturePage … (+13) |
| `SetCard.qml` (55 l.) | section d'une page de réglages : titre en petites capitales + lignes | AnimPage, AppsPage, AudioPage, BarPage, CapturePage … (+18) |
| `SetInput.qml` (33 l.) | champ texte ; `committed(text)` quand on valide (Entrée) ou quitte le champ | AppsPage, CapturePage, ColorsPage, DevicesPage, FontsPage … (+4) |
| `SetOrderList.qml` (66 l.) | liste d'éléments à réordonner (flèches) et activer (interrupteur) | BarPage, DashboardPage, TouchPage |
| `SetRow.qml` (41 l.) | une ligne de réglage : titre + description à gauche, commande à droite | AnimPage, AppsPage, AudioPage, BarPage, CapturePage … (+16) |
| `SetSeg.qml` (31 l.) | choix exclusif : options = [[valeur, libellé], …], current = valeur active | AnimPage, BarPage, CapturePage, ColorsPage, FontsPage … (+6) |
| `SetSlider.qml` (52 l.) | curseur avec valeur affichée ; `moved(v)` à chaque déplacement (valeur arrondie au pas) | AppsPage, BarPage, CapturePage, DashboardPage, FontsPage … (+8) |
| `SetSwitch.qml` (22 l.) | interrupteur à ressort (même style que le reste de Quick-Bar) | AppsPage, BarPage, CapturePage, ColorsPage, DevicesPage … (+7) |
| `SpotifyPage.qml` (33 l.) | Réglages › Panneaux › Spotify et média ([spotify] width · height) | SettingsPanel |
| `StatsPage.qml` (37 l.) | Réglages › Système › Stats et seuils : affichage des stats de la barre et | SettingsPanel |
| `ThemePage.qml` (296 l.) | Réglages › Apparence › Thème : préréglages, accent, bordures animées, arrondis ([theme], [bar]) | SettingsPanel |
| `TouchPage.qml` (84 l.) | Réglages › Panneaux › Panneau tactile : onglets (ShellState.touchTabs), | SettingsPanel |
| `WallPage.qml` (101 l.) | Réglages › Multimédia › Fond d'écran : dossiers ([wallpaper]) et effets | SettingsPanel |

### `pages/spaces/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `WorkspacesTab.qml` (375 l.) | overview des workspaces 1..10 pour le TouchPanel (Xeneon), | TouchTabs |

### `pages/stats/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `DashStats.qml` (7 l.) | page System du dashboard : les cartes de la barre, 3 colonnes défilantes (StatsBoard) | Dashboard |
| `StatsBoard.qml` (103 l.) | page System (dashboard et tactile) : les cartes de survol de la barre | DashStats, TouchStats |
| `TouchStats.qml` (7 l.) | page System du panneau tactile : les cartes de la barre, 4 colonnes (StatsBoard) | TouchTabs |

### `pages/terminal/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `TerminalTab.qml` (161 l.) | onglet Terminal du TouchPanel : un vrai terminal (qmltermwidget, le moteur de Konsole) avec | TouchTabs |

### `pages/wall/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `WallpaperTab.qml` (806 l.) | galerie de wallpapers à gauche, panneau des effets à droite | Dashboard, TouchTabs |

### `pages/wallust/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `WallustTab.qml` (623 l.) | édition manuelle de la palette wallust (TouchPanel) | TouchTabs |

### `panels/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `AltTab.qml` (292 l.) | changer de fenêtre (ALT+Tab · ALT+MAJ+Tab · relâcher Alt = y aller) | shell |
| `CalendarWindow.qml` (333 l.) | ── State ───────────────────────────────────────────────── | shell |
| `Dashboard.qml` (265 l.) | PanelWindow required for TextInput keyboard focus on Wayland | DashboardPage, TabSwitcher, TouchHome, WallustTab, shell |
| `EqPopup.qml` (419 l.) | ── State ───────────────────────────────────────────────── | shell |
| `GameBreakBar.qml` (137 l.) | pastille flottante affichée sur le Xeneon pendant une pause jeu | GameBreak, shell |
| `LockScreen.qml` (278 l.) | verrouillage de session Quick-Bar (ext-session-lock : si Quick-Bar plante, la session | shell |
| `MediaPlayerPopup.qml` (393 l.) | Hotspot zone du bouton EQ dans la barre → switch vers EQ popup | shell |
| `Menu.qml` (704 l.) | le cadre des menus Quick-Bar (remplace rofi). Voir menus/README.md | List, shell |
| `NotifCenter.qml` (389 l.) | l'historique des notifications (SUPER+MAJ+N, clic sur le module de la barre), dans | NotifCard, NotificationService, shell |
| `NotifToasts.qml` (102 l.) | les notifications qui apparaissent (NotificationService.toasts), dans un coin | NotifCard, NotificationService, shell |
| `Overview.qml` (591 l.) | vue d'ensemble des espaces de l'écran principal (SUPER+A, `qs ipc call overview toggle`) | shell |
| `PowerMenu.qml` (130 l.) | Power menu — vertical list of power action buttons | — |
| `SessionCyber.qml` (439 l.) | style « cyber » du SessionPanel ([session] style = "cyber"), plein écran : un netrunner | SessionPanel |
| `SessionJarvis.qml` (399 l.) | style « jarvis » du SessionPanel ([session] style = "jarvis"), plein écran | SessionPanel |
| `SessionMatrix.qml` (316 l.) | style « matrix » du SessionPanel ([session] style = "matrix"), plein écran | SessionPanel |
| `SessionMinimal.qml` (241 l.) | style « minimal » du SessionPanel ([session] style = "minimal"), plein écran | SessionPanel |
| `SessionPanel.qml` (363 l.) | verrouiller, veille, déconnexion, redémarrer, éteindre, BIOS | PowerButtons, SessionPage, shell |
| `SettingsPanel.qml` (380 l.) | fenêtre Réglages, au centre de l'écran principal | shell |
| `SpotifyPanel.qml` (510 l.) | panneau Spotify qui sort du bord DROIT de l'écran principal, | shell |
| `SysTrayPopup.qml` (340 l.) | Uniquement sur l'écran où le clic a eu lieu (sinon le menu s'ouvre partout) | shell |
| `TouchPanel.qml` (743 l.) | panneau plein écran sur le tactile Corsair Xeneon Edge | AnimPage, GameBreak, ShellState, TouchTabs, shell |
| `WallpaperCinema.qml` (340 l.) | sélecteur « Cinéma » (ALT+W, `qs ipc call wallcinema toggle`) | shell |
| `WallpaperPicker.qml` (406 l.) | sélecteur de fond d'écran au clavier (SUPER+W, ALT+W = vidéos), | shell |

### `scripts/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `launch.sh` (12 l.) | Lance Quick-Bar avec son environnement. Point d'entrée unique : démarrage Hyprland (Startup_Apps.lua), | SysStats.qml, TerminalTab.qml |

### `scripts/apps/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `amethyst-theme.py` (84 l.) | Thème « Quick-Bar » pour Amethyst Mod Manager, calculé depuis la palette active (wallust ou matugen, | Appearance.qml |
| `desktop_apps.py` (46 l.) | — | AppsPage.qml |

### `scripts/audio/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `eq_control.py` (95 l.) | — | AudioPage.qml, EqDash.qml, EqPopup.qml, GameMode.qml, GamePage.qml |

### `scripts/config/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `config_set.py` (50 l.) | — | Config.qml |
| `swaync_set.py` (38 l.) | — | NotifPage.qml |

### `scripts/dev/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `gen-map.py` (89 l. · singleton) | Régénère la section « Carte des fichiers » de docs/ARCHITECTURE.md depuis le code : rôle (commentaire | — |

### `scripts/discord/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `discord_bridge.py` (375 l.) | Endpoint download de bot.js (LXC 107) | DiscordService.qml |

### `scripts/game/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `game_art.sh` (88 l.) | Visuels d'un jeu Steam pour la page Game (GameMode.qml) | GameMode.qml |
| `game_sessions.py` (62 l.) | — | GameMode.qml |
| `mangohud_tail.sh` (8 l.) | FPS et temps de trame de la dernière ligne du journal MangoHud en cours | GameModeTab.qml |

### `scripts/health/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `check.sh` (180 l.) | Bilan de santé de Quick-Bar : vérifie ce dont le shell dépend | Health.qml, HealthPage.qml, HealthTab.qml |
| `suggest.py` (262 l.) | — | HealthPage.qml |

### `scripts/media/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `music_info.sh` (115 l.) | ── Choisir le lecteur pertinent ────────────────────────────────────────────── | Cava.qml, MediaPlayer.qml, MediaPlayerPopup.qml |

### `scripts/rgb/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `backend.py` (140 l.) | — | GamePage.qml, GameTab.qml, GridDash.qml, RgbTab.qml, check.sh … (+1) |
| `launch_rgb_mode.sh` (12 l.) | Applique un mode RGB (OpenRGB) de façon détachée. Chemin auto (dossier du script) | RgbTab.qml |
| `rgb_watch.sh` (27 l.) | Démon RGB (OpenRGB_Controller_Watch.py) — un seul point d'entrée | check.sh |

### `scripts/rgb/script/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `OpenRGB_Controller.py` (1446 l.) | La zone peut refuser un resize (ex: D_LED Gigabyte figé à 1 LED) | OpenRGB_Controller_Watch.py, launch_rgb_mode.sh, rgb_watch.sh |
| `OpenRGB_Controller_Watch.py` (117 l.) | — | rgb_watch.sh |
| `OpenWal.py` (413 l.) | Configuration multi-ports | launch_rgb_mode.sh, rgb_watch.sh |
| `set_fixed_color.py` (98 l.) | — | — |

### `scripts/system/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `deps.py` (214 l.) | — | DepsPage.qml |
| `device-photos.py` (111 l.) | Photos des périphériques pour la page Devices du dashboard. Pour chaque modèle de assets/devices/devices.json | Batteries.qml, DevicesPage.qml |
| `fonts.py` (25 l.) | — | FontsPage.qml |
| `icon_themes.py` (133 l.) | Icônes de l'aperçu : dossier, maison, terminal, navigateur, réglages, musique, image, Steam | ThemePage.qml |
| `sysstats.py` (261 l.) | Intervalles (s) : argv[1] au repos, argv[2] pendant le survol — [refresh] stats dans config.toml | SysData.qml, SysStats.qml |
| `vader5-battery.py` (57 l.) | Batterie de la manette Flydigi Vader 5 Pro (dongle 37d7:2401 ou filaire), lue sur son interface HID | Batteries.qml |

### `scripts/wallust/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `wallust_override.sh` (58 l.) | Surcharge manuelle des couleurs de la palette (onglet Wallust/Matugen du TouchPanel) | WallustTab.qml |

### `services/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `Batteries.qml` (151 l. · singleton) | appareils sur batterie vus par UPower (souris Logitech via hidpp, casques Bluetooth…), | DashBattery, DevicesPage, GameModeTab, GridDash, NotifCard … (+2) |
| `CavaService.qml` (56 l. · singleton) | Single cava process shared by CenterContent and PlayerCard | EqDash, GridDash, PlayerCard |
| `DiscordService.qml` (128 l. · singleton) | pont vers le serveur Discord via scripts/discord/discord_bridge.py | DiscordChat |
| `Health.qml` (116 l. · singleton) | bilan de santé de ce dont Quick-Bar dépend (OpenRGB, EasyEffects, | HealthPage, HealthTab, TouchPanel |
| `KeybindService.qml` (406 l. · singleton) | Raccourcis propres à Quick-Bar : générés dans Quick-Bar/hypr/, chargés par une ligne de | KeybindsPage, Minimize |
| `Minimize.qml` (48 l. · singleton) | remplace niflveil : la fenêtre active part dans l'espace caché special:minimized, | Minimized, shell |
| `Mixer.qml` (74 l. · singleton) | accès unique à l'audio PipeWire pour toutes les pages (Mixer, Game, | Audio, EqDash, GameModeTab, MixerTab, SpotifyPanel |
| `NotificationService.qml` (79 l. · singleton) | le démon de notifications de Quick-Bar (remplace swaync) | GridDash, NotifCard, NotifCenter, NotifToasts, Notifications … (+1) |
| `ScreenRecService.qml` (441 l. · singleton) | owns all screen recording state | CapturePage, GameModeTab, QuickSettings |
| `SysData.qml` (106 l. · singleton) | stats système partagées : un seul démon (scripts/system/sysstats.py) pour la | Batteries, CpuCard, CpuTempCard, DiskCard, GameModeTab … (+9) |
| `Updates.qml` (48 l. · singleton) | paquets à mettre à jour, partagés par la barre (bar/Updates.qml), la grille du tactile | Bar, GridDash, Updates, shell |
| `WallpaperService.qml` (133 l. · singleton) | ============================================================ | — |

### `services/system/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `CpuFreqService.qml` (141 l.) | Tracks auto-cpufreq daemon status, the kernel governor, and current freq | — |
| `CpuService.qml` (69 l.) | Reads /proc/stat every second via cat and computes CPU usage % | GridDash |
| `DiskService.qml` (80 l.) | Runs df every 15s and exposes real block devices as a list model | GridDash |
| `FanControl.qml` (44 l.) | Controls fans via nbfc-linux | — |
| `GpuService.qml` (87 l.) | AMD GPU (amdgpu) via sysfs | GridDash |
| `MemService.qml` (62 l.) | Reads /proc/meminfo every 2s via cat (FileView can't read virtual fs) | GridDash |
| `NetService.qml` (109 l.) | Detects active interface via ip route, then | GridDash |
| `ThermalService.qml` (99 l.) | Lit `sensors` toutes les 2s : temp CPU (AMD k10temp Tctl/Tdie, ou Intel Package) | GridDash |

### `wallpaper/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `Wallpaper.qml` (142 l.) | fond Quickshell (layer background) affichant l'image fixe courante | WallpaperState, shell |

### `wallpaper/shaders/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `build.sh` (16 l.) | Compile les shaders GLSL (.frag) en .qsb pour Qt6/Quickshell | — |

## Réglages (SUPER+F1, tuile Config)

- `panels/SettingsPanel.qml` : fenêtre, barre latérale (catalogue `tabs`), recherche ; pages dans `pages/settings/` chargées par `sourceComponent` (jamais `Loader.source` relatif).
- Composants : `SetCard`, `SetRow`, `SetSwitch`, `SetSlider`, `SetSeg`, `SetInput`, `SetButton`, `SetOrderList`, `PageHeader`.
- Écriture : `Config.set("section.cle", valeur)` → `scripts/config/config_set.py` (tomlkit, commentaires gardés, `null` = valeur par défaut).
- Helpers : `Config.term(titre, argv)` (terminal choisi), `Config.isTouch(screen)`, `Config.ms(clé, s)` ([refresh]), `Appearance.dur(ms)` (vitesse d'animation), `Appearance.paletteName` (Wallust/Matugen).
- Catalogues : `core/BarModules.qml` ([bar.layout]), `core/TouchTabs.qml` (onglets tactiles).
- Stats : `services/SysData.qml` (démon `sysstats.py` unique, `SysData.want(id, on)` pour le mode détail) ; cartes dans `components/stats/` (barre au survol + `pages/stats/StatsBoard.qml` pour les pages System).
- Icônes : `IconUtils.reload()` relit le thème GTK ; `scripts/system/icon_themes.py list|apply <id>`. Style de la zone de notification : `[theme] tray_icons`.
- Santé : vérifications perso `[[health.custom]]` {name, type, target, fix?}, passées à `check.sh` en JSON (QB_HEALTH_CUSTOM).
