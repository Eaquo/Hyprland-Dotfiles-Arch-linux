# Menus Quick-Bar

Des menus à la place de rofi, dans le style de Quick-Bar (animation, contour, couleur, arrondi :
tout suit les Réglages). Un menu = **un fichier `.sh`** dans `menus/scripts/` : quelques variables
en tête, une fonction qui liste les choix, une fonction qui agit sur le choix.

```
menus/
├── qbmenu          la commande (même usage que `rofi -dmenu`)
├── run.sh          lance un script de menus/scripts/
├── lib.sh          les fonctions utilisables dans les scripts
├── scripts/        les menus (un fichier = un menu)
└── templates/      les mises en page (un fichier QML = un template)
```

## Lancer un menu

```bash
~/.config/quickshell/Quick-Bar/menus/qbmenu run bluetooth      # lance menus/scripts/bluetooth.sh
~/.config/quickshell/Quick-Bar/menus/qbmenu list               # liste les menus et leur description
qs -p ~/.config/quickshell/Quick-Bar/shell.qml ipc call menu run bluetooth   # pareil, depuis un raccourci
```

Relancer le même menu le referme. Pour un raccourci clavier, ajoute une entrée dans
`services/KeybindService.qml` (`target: "menu", fn: "run <nom>"`) : il est écrit dans `hypr/quickbar.lua`.

## Écrire un menu

`menus/scripts/exemple.sh` :

```bash
# Ma première ligne de commentaire = la description affichée par « qbmenu list »
TEMPLATE=list              # la mise en page (voir plus bas)
PROMPT="Exemple"           # titre dans la pastille de recherche
ICON="󰍜"                   # glyphe Nerd Font de la pastille
PLACEHOLDER="Chercher…"    # texte gris dans la recherche
MESSAGE="une phrase d'aide sous le bandeau"

items() {                  # une ligne par choix
    section "Applications"
    item "Firefox" id=firefox icon=firefox sub="navigateur"
    item "Terminal" id=kitty glyph="" sub="kitty"
}

on_select() {              # $1 = l'id du choix (ou son texte s'il n'a pas d'id)
    launch "$1"
}
```

### Les variables

| Variable | Rôle | Défaut |
|---|---|---|
| `TEMPLATE` | `list` · `grid` · `apps` · `emoji` · `files` · `input` · `confirm` · `info` · `theme` · `scan` | `list` |
| `POSITION` | `center` · `top` · `bottom` · `left` · `right` · `top-left` · `top-right` · `bottom-left` · `bottom-right` | `center` |
| `WIDTH` / `HEIGHT` | largeur de la boîte, hauteur maximale du contenu (px) | selon le template |
| `COLUMNS` | colonnes (`list`, `grid`, `theme`, `apps`) | selon le template |
| `ROW_HEIGHT` | hauteur d'une ligne (`list`) | 58 |
| `PROMPT` · `ICON` · `PLACEHOLDER` · `TITLE` | l'en-tête | — |
| `MESSAGE` | la pastille d'aide sous le bandeau | — |
| `SELECTED` | ligne choisie à l'ouverture | 0 |
| `NO_CUSTOM=1` | interdit de valider un texte tapé qui n'est pas dans la liste | 0 |
| `PASSWORD=1` | saisie masquée | 0 |
| `KEEP_OPEN=1` | le menu se rouvre après chaque action (le script peut le remettre à 0) | 0 |
| `KEYS=(…)` | touches perso : `KEYS=("Control-Delete" "Alt-Delete")` → `on_key_1`, `on_key_2` | — |
| `TABS=(…)` | onglets vers d'autres menus : `"glyphe\|libellé\|script"` | — |

### Les fonctions du script

| Fonction | Quand |
|---|---|
| `items` | liste les choix (avec `item` et `section`) |
| `on_select "$choix"` | Entrée ou clic |
| `on_key_N "$choix"` | la Nᵉ touche de `KEYS` |
| `on_cancel` | Échap ou clic à côté |
| `live "$saisie"` | (facultatif) relancée à chaque frappe ; sa sortie devient la liste (calculatrice, recherche de fichiers…) |
| `run.sh <menu> --call <fonction>` | appelle une fonction du script depuis l'extérieur (la commande `cmd=` d'un scan) |

### Les choix : `item` et `section`

```bash
item "Texte affiché" id=valeur icon=nom-ou-chemin glyph="󰊴" sub="à droite" path=/un/fichier colors="#ff0000,#00ff00"
section "Titre de section"     # une ligne non sélectionnable
```

- `id` : ce que reçoit `on_select` (sinon le texte).
- `icon` : un nom d'icône du thème (`firefox`, `steam`) ou le chemin d'une image (`/…/jaquette.png`).
- `glyph` : un glyphe Nerd Font, si pas d'icône.
- `sub` : un texte secondaire à droite (`list`) ou sous le nom.
- Tabulations dans le texte : des **colonnes** (`list`, `info`).
- `path` : le fichier à prévisualiser (`files`) · `colors` : la bande de couleurs (`theme`).

### Les actions (`lib.sh`)

| Fonction | Fait |
|---|---|
| `launch cmd…` | lance une application sur l'écran principal |
| `term cmd…` | ouvre kitty (`term -e htop`, `term --hold -e script`) |
| `edit fichier` | ouvre le fichier dans `$EDITOR` (nvim) dans kitty |
| `open url-ou-fichier` | avec le programme par défaut |
| `copy texte` | dans le presse-papiers |
| `notify "titre" "texte"` | une notification |
| `qb cible fonction` | pilote Quick-Bar (`qb wallpicker toggle`, `qb updates upgrade`) |
| `ask "titre" a b c` | petit sous-menu : imprime le choix |
| `confirm "question ?"` | Oui / Non : code 0 si Oui |
| `input "titre" "aide"` | saisie libre : imprime le texte |
| `$QBMENU` | la commande `qbmenu` elle-même, pour un sous-menu sur mesure |

## Les templates

| Template | Pour |
|---|---|
| `list` | une liste (colonnes, sections, icônes) |
| `grid` | des cartes à image (jaquettes, fonds) |
| `apps` | le lanceur d'applications (les `.desktop`, rien à fournir) |
| `emoji` | une grille dense : le 1er mot de chaque ligne en grand |
| `files` | une liste de fichiers avec aperçu à droite (molette ou Maj+↑↓ pour défiler) |
| `input` | une saisie libre (avec `live` : résultats sous la saisie) |
| `confirm` | une question et des boutons |
| `info` | un affichage (aide-mémoire) : 1re colonne en touches de clavier |
| `theme` | des cartes avec bande de couleurs ou aperçu |
| `scan` | une tâche longue avec barre de progression (style du thème) : le 1er item porte `cmd=`, dont la sortie pilote l'affichage (`STEP i n libellé`, `SUB k m`, `ITEM texte`, `DONE`) — voir `updates.sh` |

Ajouter un template : un fichier `menus/templates/MonTemplate.qml` (nom en majuscule) et
`TEMPLATE=montemplate`. Il reçoit `menu` (le cadre) et expose `prefW`, `contentH`, `cols`, `filter`,
`search`, `hints`. Le plus simple est de partir de `List.qml` ou `Grid.qml`
(`import "." as T` puis `T.List { … }`). Après une modification d'un template, relancer Quick-Bar
(les templates déjà chargés restent en cache).

## Utiliser `qbmenu` comme rofi

Pour un script existant, remplacer `rofi -dmenu` par `qbmenu` suffit : mêmes options principales
(`-p`, `-mesg`, `-i`, `-kb-custom-N`, `-no-custom`, `-selected-row`, `-password`, lignes
`texte\0icon\x1fnom`), même sortie, mêmes codes de retour (0 choisi, 1 annulé, 10+ touches perso).
Si Quick-Bar ne tourne pas, `qbmenu` relance rofi avec les mêmes options.

```bash
choix=$(printf 'un\ndeux\ntrois' | qbmenu -p "Choisir" --template list)
```

Options en plus : `--template`, `--position`, `--width`, `--height`, `--columns`, `--row-height`,
`--icon`, `--title`, `--placeholder`, `--live 'commande "$1"'`, `--tab 'glyphe|libellé|script'`.

## Apparence

Rien à régler dans les scripts : la boîte suit Quick-Bar.

- **Animation** : Réglages › Session › « Animation des menus » (`menu.style` : matrix, minimal, cyber,
  jarvis, card), la même famille que l'écran de session.
- **Contour animé** : suit l'interrupteur « Animations » ; sinon contour fixe.
- **Arrondi** : proportionnel à celui de la barre (100 % dans la barre = boîte et pastilles arrondies au maximum).
- **Couleurs** : la palette en cours (wallust ou thème choisi) ; la lueur prend la couleur dominante du fond d'écran du bandeau.
- **Fermer** : Échap, clic à côté de la boîte, ou relancer le même menu.

## Les menus fournis

| Menu | Rôle | Raccourci |
|---|---|---|
| `apps` | lanceur d'applications, onglets apps · fichiers · commande · fenêtres | Super seul |
| `game-scripts` | scripts de jeux (gamescope, MangoHud…) : ouvrir, créer, modifier le modèle | SUPER+MAJ+G |
| `quickedit` | éditer une config : Lua, conf de base ou Quick-Bar, puis le fichier (aperçu, ← retour) | SUPER+MAJ+E |
| `bluetooth` | allumer, connecter, appairer, oublier | CTRL+B · clic molette sur la tuile Bluetooth |
| `updates` | paquets à mettre à jour avec leur changelog à droite (notes de version GitHub, commits pour les `-git`, historique Arch/AUR) ; un paquet AUR seul ou tout | clic sur le module de la barre |
| `files` | chercher un fichier ; entrée l'ouvre avec le programme par défaut (`~/.config/mimeapps.list`) | onglet de `apps` |
| `command` | lancer une commande (Maj+Entrée : dans un terminal) | onglet de `apps` |
| `windows` | aller sur une fenêtre ouverte | onglet de `apps` |
| `clipboard` | historique du presse-papiers (cliphist) | — |
| `emoji` | emojis, entrée copie | — |
| `calc` | calculatrice (qalculate), résultat en direct | — |
| `search` | recherche web | — |
| `keyhints` | aide-mémoire des raccourcis | — |
| `themes` | palettes prêtes à l'emploi, aperçu des couleurs | — |
| `menus` | tous les menus de ce dossier | — |

Les raccourcis se changent dans Réglages › Raccourcis (ou `services/KeybindService.qml`) ; un menu
sans raccourci se lance avec `qbmenu run <nom>` ou depuis `menus`.
