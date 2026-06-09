#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║   Réinstallation automatique de la config Hyprland (Arch)     ║
# ║   Usage :  git clone <repo> && cd <repo> && ./install.sh      ║
# ╚══════════════════════════════════════════════════════════════╝
#  Étapes : 1.Vérifs  2.yay  3.Paquets officiels  4.Paquets AUR  5.Dotfiles
#           6.Shell  7.Plugins hyprpm  8.Thème SDDM  9.Services

set -uo pipefail

# --- Emplacement du dépôt cloné (peu importe d'où on lance) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || { echo "Impossible d'accéder à $SCRIPT_DIR"; exit 1; }

SDDM_THEME_DIR="simple-sddm-2"          # dossier du thème dans le dépôt
SDDM_THEME_NAME="simple-sddm-2"         # nom installé dans /usr/share/sddm/themes
FAILED_PKGS=()
STEP=0; STEPS_TOTAL=9
LOG="$HOME/hypr-install.log"
DEPLOY_MODE=overwrite   # overwrite | skip | ask  (défini à l'étape dotfiles)

# ─────────────────────────────  UI  ──────────────────────────────
if [[ -t 1 ]]; then
  B='\033[1m'; D='\033[2m'; R='\033[0m'
  RED='\033[1;31m'; GRN='\033[1;32m'; YEL='\033[1;33m'
  BLU='\033[1;34m'; MAG='\033[1;35m'; CYN='\033[1;36m'
else
  B=''; D=''; R=''; RED=''; GRN=''; YEL=''; BLU=''; MAG=''; CYN=''
fi

line(){ printf "${D}────────────────────────────────────────────────────────────${R}\n"; }

banner(){
  printf "${MAG}"
  cat <<'EOF'
   ╦ ╦╦ ╦╔═╗╦═╗╦  ╔═╗╔╗╔╔╦╗   ┬─┐┌─┐┌─┐┌┬┐┌─┐┬─┐┌─┐
   ╠═╣╚╦╝╠═╝╠╦╝║  ╠═╣║║║ ║║   ├┬┘├┤ └─┐ │ │ │├┬┘├┤
   ╩ ╩ ╩ ╩  ╩╚═╩═╝╩ ╩╝╚╝═╩╝   ┴└─└─┘└─┘ ┴ └─┘┴└─└─┘
EOF
  printf "${R}${D}        réinstallation automatique • Arch Linux${R}\n\n"
}

section(){                       # $1 = titre
  STEP=$((STEP+1))
  printf "\n${BLU}╭─[ ${B}%d/%d${R}${BLU} ]─ ${B}%s${R}\n" "$STEP" "$STEPS_TOTAL" "$1"
  printf "${BLU}╰────────────────────────────────────────────────────────${R}\n"
}

ok(){   printf "  ${GRN}✔${R} %s\n" "$*"; }
warn(){ printf "  ${YEL}⚠${R} %s\n" "$*"; }
err(){  printf "  ${RED}✘${R} %s\n" "$*"; }
note(){ printf "  ${D}%s${R}\n" "$*"; }
ask(){  # $1 = question  ->  retourne 0 si oui (défaut Non)
  local r; printf "${YEL}❯${R} %s ${D}[o/N]${R} " "$1"
  read -r r; [[ "$r" =~ ^[oOyY]$ ]]
}

# ───────────────────────  1. Vérifications  ──────────────────────
step_checks(){
  section "Vérifications préalables"
  if ! command -v pacman >/dev/null; then
    err "pacman introuvable — script prévu pour Arch Linux. Abandon."; exit 1
  fi
  ok "Arch Linux détecté"
  if [[ $EUID -eq 0 ]]; then
    err "Ne lance PAS ce script en root (sudo sera demandé au besoin)."; exit 1
  fi
  ok "Utilisateur non-root"
  printf "  ${D}Authentification sudo…${R}\n"
  if ! sudo -v; then err "sudo requis."; exit 1; fi
  ok "sudo OK"
  ( while true; do sudo -n true; sleep 50; done ) 2>/dev/null & SUDO_KEEPALIVE=$!
  trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null' EXIT
  if ping -c1 -W2 archlinux.org >/dev/null 2>&1; then
    ok "Connexion réseau OK"
  else
    warn "Pas de réponse réseau — l'installation des paquets risque d'échouer."
    ask "Continuer quand même ?" || exit 1
  fi
}

# ──────────────────────────  2. yay  ─────────────────────────────
step_yay(){
  section "AUR helper (yay)"
  if command -v yay >/dev/null; then ok "yay déjà présent"; return; fi
  warn "yay absent → compilation"
  sudo pacman -S --needed --noconfirm git base-devel || { err "base-devel/git échec"; exit 1; }
  local tmp; tmp="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay.git "$tmp/yay" || { err "clone yay échec"; exit 1; }
  ( cd "$tmp/yay" && makepkg -si --noconfirm ) || { err "build yay échec"; exit 1; }
  rm -rf "$tmp"
  command -v yay >/dev/null && ok "yay installé" || { err "yay introuvable après build"; exit 1; }
}

# lit une liste (ignore # et lignes vides) -> stdout
read_list(){ grep -vE '^\s*#|^\s*$' "$1" 2>/dev/null | sed 's/#.*//' | awk '{$1=$1};1'; }

# installe paquet par paquet (tolérant aux échecs) via yay, avec compteur
install_pkgs(){
  local file="$1" label="$2"
  [[ -f "$file" ]] || { warn "$file absent, étape ignorée"; return; }
  local pkgs; mapfile -t pkgs < <(read_list "$file")
  local total=${#pkgs[@]}
  ((total==0)) && { warn "aucun paquet listé dans $file"; return; }
  note "$label — $total paquets ($file)"
  local i=0
  for p in "${pkgs[@]}"; do
    [[ -z "$p" ]] && continue
    i=$((i+1))
    printf "  ${CYN}[%2d/%2d]${R} %-28s" "$i" "$total" "$p"
    printf '\n========== %s ==========\n' "$p" >>"$LOG"
    if yay -S --needed --noconfirm "$p" >>"$LOG" 2>&1; then
      printf "${GRN}✔${R}\n"
    else
      printf "${RED}✘${R}\n"
      FAILED_PKGS+=("$p")
    fi
  done
}

# ───────────────────────  5. Dotfiles  ───────────────────────────
deploy_one(){   # $1 = source (dans dépôt)   $2 = destination
  local src="$1" dst="$2" short
  [[ -e "$src" ]] || return
  short="${dst/#$HOME/\~}"
  if [[ -e "$dst" || -L "$dst" ]]; then
    case "$DEPLOY_MODE" in
      skip) note "gardé (existe déjà) : $short"; return ;;
      ask)
        printf "  ${YEL}?${R} %s existe déjà — écraser ? ${D}(l'ancien → ${short##*/}_backup)${R} ${D}[o/N]${R} " "$short"
        local r; read -r r
        [[ "$r" =~ ^[oOyY]$ ]] || { note "gardé : $short"; return; }
        ;;
    esac
    # l'ancien est conservé à côté, renommé <nom>_backup
    rm -rf "${dst}_backup"
    mv "$dst" "${dst}_backup"
    note "ancien conservé → ${short}_backup"
  fi
  mkdir -p "$(dirname "$dst")"
  cp -aT "$src" "$dst"     # -T : dst EST la cible, jamais "copier dedans"
  ok "$short"
}

step_dotfiles(){
  section "Déploiement des dotfiles"
  printf "${YEL}❯${R} Si un fichier existe déjà : ${D}[o]=tout écraser / [g]=garder l'existant / [d]=demander à chaque${R} "
  local m; read -r m
  case "$m" in
    g|G) DEPLOY_MODE=skip ;     note "Mode : garder l'existant (ne déploie que ce qui manque)" ;;
    d|D) DEPLOY_MODE=ask  ;     note "Mode : demander pour chaque fichier" ;;
    *)   DEPLOY_MODE=overwrite ; note "Mode : tout écraser (l'ancien renommé <nom>_backup)" ;;
  esac
  if [[ -d .config ]]; then
    for item in .config/*; do
      deploy_one "$item" "$HOME/.config/$(basename "$item")"
    done
  fi
  if [[ -d home_dotfiles ]]; then
    shopt -s dotglob
    for f in home_dotfiles/*; do
      [[ -e "$f" ]] && deploy_one "$f" "$HOME/$(basename "$f")"
    done
    shopt -u dotglob
  fi
  [[ -d .themes ]]  && deploy_one ".themes"  "$HOME/.themes"
  [[ -d .zen ]]     && deploy_one ".zen"     "$HOME/.zen"
  # Windsurf : seulement les réglages (jamais extensions/, conservées sur la machine)
  if [[ -d .windsurf ]]; then
    mkdir -p "$HOME/.windsurf"
    for f in .windsurf/settings.json .windsurf/argv.json; do
      [[ -f "$f" ]] && deploy_one "$f" "$HOME/.windsurf/$(basename "$f")"
    done
  fi
  if [[ -d Pictures ]]; then
    if ask "Déployer les wallpapers (dossier Pictures) ?"; then
      mkdir -p "$HOME/Pictures"
      for it in Pictures/*; do deploy_one "$it" "$HOME/Pictures/$(basename "$it")"; done
    else
      note "Wallpapers ignorés"
    fi
  fi
  chmod +x "$HOME"/.config/hypr/scripts/*.sh     2>/dev/null
  chmod +x "$HOME"/.config/hypr/UserScripts/*.sh 2>/dev/null
  chmod +x "$HOME"/.config/hypr/*.sh             2>/dev/null
  ok "Scripts hypr rendus exécutables"
}

# ───────────────────  6. Shell par défaut  ──────────────────────
step_shell(){
  section "Shell par défaut"
  local current target choice
  current="$(getent passwd "$USER" | cut -d: -f7)"
  note "Shell actuel : $current"
  printf "${YEL}❯${R} Quel shell par défaut ?  ${D}[f]ish / [z]sh / [Entrée]=garder${R} "
  read -r choice
  case "$choice" in
    f|F) target=/usr/bin/fish ;;
    z|Z) target=/usr/bin/zsh ;;
    *)   warn "Shell inchangé"; return ;;
  esac
  if [[ ! -x "$target" ]]; then
    err "$target introuvable — le paquet est-il bien installé ?"; return
  fi
  # ajoute le shell à /etc/shells si absent (requis par chsh)
  grep -qx "$target" /etc/shells 2>/dev/null || echo "$target" | sudo tee -a /etc/shells >/dev/null
  if sudo chsh -s "$target" "$USER"; then
    ok "Shell par défaut → $target ${D}(effectif à la prochaine connexion)${R}"
  else
    err "chsh a échoué"
  fi
}

# ─────────────────  7. Plugins Hyprland (hyprpm)  ───────────────
step_hyprpm(){
  section "Plugins Hyprland (hyprpm)"
  if ! command -v hyprpm >/dev/null; then
    warn "hyprpm absent (hyprland installé ?) — étape ignorée"; return
  fi
  note "Idéalement à lancer DANS une session Hyprland."
  note "Sinon, si ça échoue, relance simplement cette commande après le 1er login :"
  note "  hyprpm update && hyprpm enable hy3 && hyprpm enable hyprbars && hyprpm reload"
  note "Compilation des headers (peut prendre plusieurs minutes)…"
  if ! hyprpm update >>"$LOG" 2>&1; then
    warn "hyprpm update a échoué — à relancer dans Hyprland (voir $LOG)"; return
  fi
  ok "headers à jour"
  # dépôts nécessaires aux plugins activés (hy3, hyprbars)
  local name url
  for entry in "hyprland-plugins=https://github.com/hyprwm/hyprland-plugins" \
               "hy3=https://github.com/outfoxxed/hy3"; do
    name="${entry%%=*}"; url="${entry#*=}"
    if hyprpm list 2>/dev/null | grep -q "Repository $name"; then
      ok "dépôt $name déjà présent"
    else
      printf "  ${CYN}…${R} ajout du dépôt %s\n" "$name"
      if hyprpm add "$url" >>"$LOG" 2>&1; then ok "dépôt $name ajouté"; else warn "dépôt $name : échec (voir $LOG)"; fi
    fi
  done
  # activation des plugins utilisés
  for plug in hy3 hyprbars; do
    if hyprpm enable "$plug" >>"$LOG" 2>&1; then ok "plugin $plug activé"; else warn "plugin $plug : échec activation"; fi
  done
  hyprpm reload -n >>"$LOG" 2>&1 || true
  ok "Plugins prêts (rechargés au login via Startup_Apps)"
}

# ──────────────────────  8. Thème SDDM  ──────────────────────────
step_sddm(){
  section "Thème SDDM"
  if [[ ! -d "$SDDM_THEME_DIR" ]]; then warn "$SDDM_THEME_DIR absent, étape ignorée"; return; fi
  sudo mkdir -p /usr/share/sddm/themes
  if [[ -d "/usr/share/sddm/themes/$SDDM_THEME_NAME" ]]; then
    sudo rm -rf "/usr/share/sddm/themes/$SDDM_THEME_NAME.bak"
    sudo mv "/usr/share/sddm/themes/$SDDM_THEME_NAME" "/usr/share/sddm/themes/$SDDM_THEME_NAME.bak"
    warn "Ancien thème sauvegardé en $SDDM_THEME_NAME.bak"
  fi
  sudo cp -a "$SDDM_THEME_DIR" "/usr/share/sddm/themes/$SDDM_THEME_NAME"
  ok "Thème copié → /usr/share/sddm/themes/$SDDM_THEME_NAME"
  sudo mkdir -p /etc/sddm.conf.d
  printf "[Theme]\nCurrent=%s\n" "$SDDM_THEME_NAME" | sudo tee /etc/sddm.conf.d/theme.conf.user >/dev/null
  ok "/etc/sddm.conf.d/theme.conf.user écrit (Current=$SDDM_THEME_NAME)"

  # Session Hyprland : le paquet n'installe pas toujours de .desktop (ou il est vide)
  local sess=/usr/share/wayland-sessions/hyprland.desktop
  if [[ ! -s "$sess" ]] && command -v Hyprland >/dev/null; then
    sudo mkdir -p /usr/share/wayland-sessions
    printf '[Desktop Entry]\nName=Hyprland\nComment=An intelligent dynamic tiling Wayland compositor\nExec=Hyprland\nType=Application\n' \
      | sudo tee "$sess" >/dev/null
    ok "Session Hyprland créée → $sess"
    # supprime la coquille uwsm vide si présente
    [[ -e /usr/share/wayland-sessions/hyprland-uwsm.desktop && ! -s /usr/share/wayland-sessions/hyprland-uwsm.desktop ]] \
      && sudo rm -f /usr/share/wayland-sessions/hyprland-uwsm.desktop
  else
    ok "Session Hyprland déjà présente"
  fi
}

# ────────────────────────  9. Services  ──────────────────────────
step_services(){
  section "Services système"
  for svc in NetworkManager bluetooth; do
    if sudo systemctl enable "$svc" >/dev/null 2>&1; then ok "$svc activé"; else warn "$svc non activé"; fi
  done
  if ask "Activer SDDM comme gestionnaire de connexion ?"; then
    if sudo systemctl enable sddm >/dev/null 2>&1; then ok "sddm activé"; else warn "sddm non activé"; fi
  fi
}

# ────────────────────────────  Récap  ────────────────────────────
summary(){
  printf "\n${GRN}╔══════════════════════════════════════════════════════════╗${R}\n"
  printf "${GRN}║${R}  ${B}Installation terminée${R}                                   ${GRN}║${R}\n"
  printf "${GRN}╚══════════════════════════════════════════════════════════╝${R}\n"
  ok "Dotfiles déployés  ${D}(anciens conservés en <nom>_backup)${R}"
  ok "Thème SDDM : $SDDM_THEME_NAME"
  if ((${#FAILED_PKGS[@]})); then
    printf "\n"; warn "Paquets NON installés (${#FAILED_PKGS[@]}) — à vérifier manuellement :"
    printf "     ${RED}•${R} %s\n" "${FAILED_PKGS[@]}"
    note "Détail des erreurs : ${LOG/#$HOME/\~}"
    note "Cherches-y le nom du paquet pour voir la cause exacte."
  fi
  printf "\n"
  if ask "Redémarrer maintenant ?"; then
    note "Redémarrage…"; sudo reboot
  else
    printf "${CYN}❯${R} Plus tard : ${B}reboot${R}  (ou ${B}sudo systemctl start sddm${R})\n\n"
  fi
}

# ─────────────────────────────  main  ────────────────────────────
main(){
  clear 2>/dev/null
  banner
  : > "$LOG"   # réinitialise le log d'installation
  step_checks

  if ask "Installer les paquets (officiels + AUR) ?"; then
    step_yay
    section "Paquets — dépôts officiels"
    install_pkgs pkglist-pacman.txt "Dépôts officiels"
    section "Paquets — AUR"
    install_pkgs pkglist-aur.txt "AUR"
  else
    warn "Installation des paquets ignorée"
  fi

  if ask "Déployer les dotfiles dans ton HOME ?"; then step_dotfiles; else
    STEP=$((STEP+1)); warn "Déploiement des dotfiles ignoré"; fi

  if ask "Définir le shell par défaut (fish / zsh) ?"; then step_shell; else
    STEP=$((STEP+1)); warn "Shell par défaut inchangé"; fi

  if ask "Installer/activer les plugins Hyprland (hyprpm : hy3, hyprbars) ?"; then step_hyprpm; else
    STEP=$((STEP+1)); warn "Plugins hyprpm ignorés"; fi

  if ask "Installer le thème SDDM ?"; then step_sddm; else
    STEP=$((STEP+1)); warn "Thème SDDM ignoré"; fi

  if ask "Activer les services (NetworkManager, bluetooth, sddm) ?"; then step_services; else
    STEP=$((STEP+1)); warn "Services ignorés"; fi

  summary
}

main "$@"
