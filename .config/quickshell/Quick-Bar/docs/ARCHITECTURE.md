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
├── wallpaper/     Wallpaper.qml + shaders/ (effets : matrix, cyberpunk, rain…)
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
2. Ajouter **une ligne** au catalogue `allTabs` de `panels/TouchPanel.qml` :
   `{ key: "<nom>", icon: "<glyphe>", label: "<Nom>", src: "../pages/<nom>/<Nom>Tab.qml" }`
   Options : `scale: 1.15` (zoom), `keep: true` (reste chargée), `def: false` (désactivé par défaut).

Pour l'avoir aussi dans le Dashboard (popup) : l'ajouter au `TabSwitcher` et à la liste
de pages de `panels/Dashboard.qml`.

### Ajouter un effet de wallpaper (shader)
1. Écrire `wallpaper/shaders/<nom>.frag` avec le même bloc `uniform buf` que les autres
   (`intensity`, `time`, `resolution`, `accent`) et `sampler2D source`. Quand
   `intensity < 0.001`, rendre l'image telle quelle.
2. Compiler : `wallpaper/shaders/build.sh` (produit `<nom>.frag.qsb`).
3. Ajouter `"<nom>"` à `themes` dans `core/WallpaperState.qml`.

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
for p in $(quickshell list --all | awk '/Process ID/{print $3}'); do kill -9 $p; done
quickshell -p ~/.config/quickshell/Quick-Bar/shell.qml -d
quickshell log -p ~/.config/quickshell/Quick-Bar/shell.qml -n   # -n = instance la plus récente
```
`quickshell kill` peut planter à la fermeture puis se relancer tout seul → doublons.
Un fichier QML enregistré recharge la configuration à chaud.

## Pièges connus

- **HTTPS depuis Qt** : charger une image `https://` dans un `Image` peut faire planter
  Quickshell (OpenSSL). Passer par `components/CachedArt.qml` (téléchargement `curl`).
- **Hyprland en config Lua** : les actions passent par `hyprctl eval "hl.dispatch(hl.dsp.…)"`,
  toutes dans un seul `eval`. Un workspace inexistant est créé sur l'écran qui a le focus.
- **`pkill -f`** tue aussi un shell dont la ligne de commande contient le motif.
- **Mipmaps** : le shader `rain` floute avec `textureLod` → `mipmap: true` sur l'image du wallpaper.

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

Générée depuis le code. « Utilisé par » liste les fichiers qui instancient ou appellent le type.

### `racine`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `shell.qml` (79 l.) | Point d'entrée : instancie la barre, les panneaux et le wallpaper | *(point d'entrée)* |

### `core/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `Appearance.qml` (243 l. · singleton) | Thème : couleurs wallust (wal.json), polices, tailles, animations | AppLauncher, Audio, Bar, BarSeparator, Bluetooth … (+50) |
| `ClockState.qml` (32 l. · singleton) | État des modules horloge (timer / chrono / alarmes) | ClockCard |
| `GameBreak.qml` (131 l. · singleton) | « pause tactile » pendant un jeu | GameBreakBar, GameModeTab, MixerTab, TouchPanel, WallustTab … (+1) |
| `GameMode.qml` (182 l. · singleton) | Bascule automatique quand un jeu tourne | GameModeTab, TouchPanel |
| `Popups.qml` (80 l. · singleton) | Quel popup/panneau est ouvert (dashboard, spotify, audio…) + closeAll() | Cava, Clock, Dashboard, EqDash, KanbanBoard … (+5) |
| `ShellState.qml` (91 l. · singleton) | État global du shell | Bar, GameBreak, GameModeTab, KeybindService, LayoutDisplayer … (+4) |
| `WallpaperState.qml` (90 l. · singleton) | État + config des effets wallpaper (glitch, screen shader) | GridDash, TouchPanel, Wallpaper, WallpaperTab, WallustTab … (+1) |

### `core/functions/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `ColorUtils.qml` (36 l. · singleton) | Fonctions couleur : mix, transparence, applyAlpha | Bar, BarSeparator, Bluetooth, CalendarWindow, ColorPicker … (+23) |
| `IconUtils.qml` (60 l. · singleton) | Résolution des icônes d'applications dans le thème GTK | SysTray, shell |

### `services/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `CavaService.qml` (56 l. · singleton) | Un seul processus cava partagé (32 barres, 30 fps) | EqDash, GridDash, PlayerCard |
| `DiscordService.qml` (128 l. · singleton) | Pont vers le serveur Discord via scripts/discord/discord_bridge.py | DiscordChat |
| `KeybindService.qml` (394 l. · singleton) | Lit et écrit les raccourcis Hyprland (page Keybinds) | KeybindsPage |
| `Mixer.qml` (72 l. · singleton) | Audio PipeWire partagé : sorties, flux par appli, volumes | EqDash, GameModeTab, KeybindService, MixerTab, SpotifyPanel |
| `NotificationService.qml` (59 l. · singleton) | Serveur de notifications (liste, DND) | GridDash |
| `ScreenRecService.qml` (438 l. · singleton) | Owns all screen recording state | GameModeTab, QuickSettings |
| `WallpaperService.qml` (133 l. · singleton) | Wallpaper list + apply pipeline | DashHome, QuickSettings |

### `services/system/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `CpuFreqService.qml` (141 l.) | Tracks auto-cpufreq daemon status, the kernel governor, and current freq | DashStats, TouchStats |
| `CpuService.qml` (69 l.) | Reads /proc/stat every second via cat and computes CPU usage % | DashStats, GameModeTab, GridDash, TouchStats |
| `DiskService.qml` (80 l.) | Runs df every 15s and exposes real block devices as a list model | DashStats, GridDash, TouchStats |
| `FanControl.qml` (44 l.) | Controls fans via nbfc-linux | DashStats, TouchStats |
| `GpuService.qml` (87 l.) | AMD GPU (amdgpu) via sysfs | DashStats, GameModeTab, GridDash, TouchStats |
| `MemService.qml` (62 l.) | Reads /proc/meminfo every 2s via cat (FileView can't read virtual fs) | DashStats, GameModeTab, GridDash, TouchStats |
| `NetService.qml` (109 l.) | Detects active interface via ip route, then | DashStats, GridDash, TouchStats |
| `ThermalService.qml` (99 l.) | Températures CPU/GPU et ventilateurs via `sensors` | DashStats, GameModeTab, GridDash, TouchStats |

### `components/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `CachedArt.qml` (28 l.) | Rend une image distante affichable sans requête HTTPS de Qt | PlayerCard, SpotifyPanel |
| `ColorPicker.qml` (205 l.) | Sélecteur de couleur tactile (HSV) en surimpression | WallpaperTab, WallustTab |
| `GradientBorder.qml` (78 l.) | Contour arrondi tracé avec un dégradé 45° des couleurs wallust qui défile | Bar, GameModeTab |
| `PopupShape.qml` (207 l.) | Draws a popup background that "melts" into whichever edge(s) it's attached to | Dashboard, SpotifyPanel |
| `StatCard.qml` (98 l.) | Reusable card background. Wrap any stats panel in this for | CalendarCard, ClockCard, EqDash, ProfileCard, QuickSettings |
| `TabSwitcher.qml` (244 l.) | Unified tab switcher — horizontal or vertical | ClockCard, Dashboard, ShellConfig |
| `TimeInput.qml` (151 l.) | Reusable HH:MM input | ClockCard |

### `bar/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `AppLauncher.qml` (26 l.) |  | Bar |
| `Audio.qml` (132 l.) |  | Bar |
| `Bar.qml` (221 l.) | La barre du haut (une par écran) : trois pastilles de widgets | shell |
| `BarSeparator.qml` (10 l.) |  | Bar |
| `Bluetooth.qml` (61 l.) |  | *(désactivé, gardé en réserve)* |
| `Cava.qml` (174 l.) | Jaquette ronde visible dès qu'un lecteur est actif | Bar |
| `Clock.qml` (39 l.) |  | Bar |
| `Eq.qml` (57 l.) | Animation fluide | *(désactivé, gardé en réserve)* |
| `LayoutDisplayer.qml` (286 l.) | Clic gauche  → cycle le layout suivant | Bar |
| `LocalSend.qml` (105 l.) | Pulse dot when active | Bar |
| `MediaPlayer.qml` (175 l.) | Play / Pause | *(désactivé, gardé en réserve)* |
| `Network.qml` (76 l.) |  | *(désactivé, gardé en réserve)* |
| `Notifications.qml` (64 l.) |  | Bar |
| `PowerButtons.qml` (50 l.) |  | Bar |
| `SysStats.qml` (240 l.) | Couleur dynamique exposée pour que le parent puisse la surcharger | Bar |
| `SysTray.qml` (164 l.) | Position absolue dans la fenêtre pour le tooltip reparenté | Bar |
| `Updates.qml` (83 l.) | Dépôts officiels (checkupdates) + AUR (paru -Qua), chaque ligne préfixée R/A | Bar |
| `Workspaces.qml` (111 l.) | Include all existing workspaces (1-10) | Bar |

### `panels/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `CalendarWindow.qml` (330 l.) | Cellules plus petites → moins large | shell |
| `Dashboard.qml` (260 l.) | Popup dashboard sous la barre (onglets, clavier) | KeybindService, shell |
| `EqPopup.qml` (415 l.) | Hotspot zone du widget MediaPlayer dans la barre → switch vers MP popup | shell |
| `GameBreakBar.qml` (183 l.) | Pastille flottante affichée sur le Xeneon pendant une pause jeu | shell |
| `MediaPlayerPopup.qml` (389 l.) | Hotspot zone du bouton EQ dans la barre → switch vers EQ popup | shell |
| `PowerMenu.qml` (130 l.) | Power menu — vertical list of power action buttons | KeybindService |
| `SpotifyPanel.qml` (367 l.) | Panneau Spotify qui sort du bord DROIT de l'écran principal | shell |
| `SysTrayPopup.qml` (335 l.) | Click outside → ferme (même pattern que EqPopup/CalendarWindow) | shell |
| `TouchPanel.qml` (538 l.) | Panneau plein écran du Xeneon : catalogue d'onglets + pages | shell |

### `wallpaper/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `Wallpaper.qml` (132 l.) | Affiche le wallpaper à travers le shader d'effet choisi | shell |

### `pages/apps/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `StreamDeck.qml` (189 l.) | Grille tactile de lanceurs, façon Elgato Stream Deck, en sections | Dashboard, TouchPanel |

### `pages/config/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `KeybindsPage.qml` (565 l.) | Keep KeybindService in sync so external handlers can observe it | ShellConfig |
| `ShellConfig.qml` (84 l.) |  | *(désactivé, gardé en réserve)* |

### `pages/discord/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `DiscordChat.qml` (527 l.) | Vue de l'onglet Discord (TouchPanel + Dashboard) | Dashboard, TouchPanel |

### `pages/eq/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `EqDash.qml` (962 l.) | Page Equalizer du dashboard, en 3 blocs : | Dashboard, TouchPanel |

### `pages/files/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `FileBrowser.qml` (909 l.) | Onglet "Files" du dashboard, dans l'esprit de yazi | Dashboard, TouchPanel |

### `pages/game/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `GameModeTab.qml` (437 l.) | Page « Game » du TouchPanel, style « verre minimal » | TouchPanel |

### `pages/games/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `GameTab.qml` (256 l.) | Grille de jeux tactile, basée sur le backend du game-launcher | Dashboard, TouchPanel |

### `pages/grid/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `GridDash.qml` (1261 l.) | Page « Grid » : tableau de widgets déplaçables/redimensionnables | TouchPanel |

### `pages/home/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `CalendarCard.qml` (174 l.) | Calendar card — month grid with prev/next navigation | DashHome, GridDash, TouchHome |
| `ClockCard.qml` (780 l.) | Clock / Timer / Alarm / Stopwatch | DashHome, TouchHome |
| `DashHome.qml` (115 l.) | Dashboard Home tab — layout only | Dashboard |
| `PlayerCard.qml` (535 l.) | Explicit count tracker — forces filteredPlayers to re-evaluate whenever | DashHome, GridDash, TouchHome |
| `ProfileCard.qml` (155 l.) | Profile card — circular avatar, username, window manager, uptime | DashHome, GridDash, TouchHome |
| `QuickSettings.qml` (1100 l.) | Right column — brightness slider + scrollable quick-settings grid | DashHome, GridDash, TouchHome |
| `TouchHome.qml` (92 l.) | Variante tactile (ultra-large) de la page Home du Dashboard | TouchPanel |

### `pages/kanban/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `KanbanBoard.qml` (1087 l.) | Three columns, JSON at $HOME/.config/quickshell/Quick-Bar/user_data/tasks.json | Dashboard, TouchPanel |

### `pages/mixer/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `MixerTab.qml` (219 l.) | Mixeur tactile (TouchPanel) : une tranche verticale par app qui | TouchPanel |

### `pages/rgb/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `RgbTab.qml` (357 l.) | Onglet RGB (OpenRGB), consolidé depuis l'ancien rgb-launcher | TouchPanel |

### `pages/spaces/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `WorkspacesTab.qml` (334 l.) | Overview des workspaces 1..10 pour le TouchPanel (Xeneon) | TouchPanel |

### `pages/stats/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `DashStats.qml` (355 l.) | Page System du popup Dashboard, refaite façon TouchStats : cartes | Dashboard |
| `TouchStats.qml` (364 l.) | Page System du TouchPanel, refaite : cartes glowy + jauges | TouchPanel |

### `pages/wall/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `WallpaperTab.qml` (461 l.) | Onglet dashboard : picker de wallpapers (vignettes) + contrôles | Dashboard, TouchPanel |

### `pages/wallust/`

| Fichier | Rôle | Utilisé par |
|---|---|---|
| `WallustTab.qml` (270 l.) | Édition manuelle de la palette wallust (TouchPanel) | TouchPanel |
