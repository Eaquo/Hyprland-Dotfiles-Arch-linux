#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║   Réinstallation automatique de la config Hyprland (Arch)     ║
# ║   Usage :  git clone <repo> && cd <repo> && ./install.sh      ║
# ╚══════════════════════════════════════════════════════════════╝
#  Étapes : 1.Vérifs  2.yay  3.Paquets officiels  4.Paquets AUR
#           5.Dotfiles  6.Shell par défaut  7.Thème SDDM  8.Services

set -uo pipefail

# --- Emplacement du dépôt cloné (peu importe d'où on lance) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || { echo "Impossible d'accéder à $SCRIPT_DIR"; exit 1; }

SDDM_THEME_DIR="simple-sddm-2"          # dossier du thème dans le dépôt
SDDM_THEME_NAME="simple-sddm-2"         # nom installé dans /usr/share/sddm/themes
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$HOME/.config-backup-$TS"
FAILED_PKGS=()
STEP=0; STEPS_TOTAL=8
LOG="$HOME/hypr-install.log"

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
  local src="$1" dst="$2"
  [[ -e "$src" ]] || return
  if [[ -e "$dst" ]]; then
    mkdir -p "$BACKUP_DIR/$(dirname "${dst#"$HOME"/}")"
    cp -a "$dst" "$BACKUP_DIR/${dst#"$HOME"/}" 2>/dev/null
  fi
  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
  ok "${dst/#$HOME/\~}"
}

step_dotfiles(){
  section "Déploiement des dotfiles"
  note "Backup de l'existant → ${BACKUP_DIR/#$HOME/\~}"
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
  [[ -d Pictures ]] && { mkdir -p "$HOME/Pictures"; for it in Pictures/*; do deploy_one "$it" "$HOME/Pictures/$(basename "$it")"; done; }
  [[ -d .zen ]]     && deploy_one ".zen"     "$HOME/.zen"
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

# ──────────────────────  7. Thème SDDM  ──────────────────────────
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
}

# ────────────────────────  8. Services  ──────────────────────────
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
  ok "Dotfiles déployés  ${D}(backup: ${BACKUP_DIR/#$HOME/\~})${R}"
  ok "Thème SDDM : $SDDM_THEME_NAME"
  if ((${#FAILED_PKGS[@]})); then
    printf "\n"; warn "Paquets NON installés (${#FAILED_PKGS[@]}) — à vérifier manuellement :"
    printf "     ${RED}•${R} %s\n" "${FAILED_PKGS[@]}"
    note "Détail des erreurs : ${LOG/#$HOME/\~}"
    note "Cherches-y le nom du paquet pour voir la cause exacte."
  fi
  printf "\n${CYN}❯${R} Redémarre, ou lance :  ${B}sudo systemctl start sddm${R}\n\n"
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

  if ask "Installer le thème SDDM ?"; then step_sddm; else
    STEP=$((STEP+1)); warn "Thème SDDM ignoré"; fi

  if ask "Activer les services (NetworkManager, bluetooth, sddm) ?"; then step_services; else
    STEP=$((STEP+1)); warn "Services ignorés"; fi

  summary
}

main "$@"
