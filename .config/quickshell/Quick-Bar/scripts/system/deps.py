#!/usr/bin/env python3
"""Dépendances de Quick-Bar — Réglages › Système › Dépendances.

Imprime un JSON : {"distro": {...}, "deps": [{group, required, name, kind, package, manual, use, ok}],
                   "install": "<commande pour ce qui manque>", "manual": [{name, how}]}

La distribution est détectée par /etc/os-release (ID puis ID_LIKE) et ramenée à une
famille : arch · debian · fedora · suse · void · nix. Chaque dépendance donne son paquet
par famille ; une famille absente = même nom que sous Arch ; None = pas dans les dépôts
de cette famille → installation à la main (`how`).

Ajouter une dépendance = une ligne dans DEPS :
  (nom, paquets, à quoi ça sert dans Quick-Bar)
  paquets = "nom-commun"  ou  {"arch": …, "debian": …, "fedora": …, "how": "à la main"}
  nom « py:module » = module Python, « font:Nerd Font » = police (fc-list), « qml:Module » = module QML de Qt 6.
"""
import importlib.util
import json
import os
import shutil
import subprocess

GH = "https://github.com/"
DEPS = [
    ("Essentiels", True, [
        ("quickshell", {"arch": "quickshell", "fedora": None, "debian": None, "suse": None, "void": None, "nix": "quickshell",
                        "how": "quickshell.org → paquets / compilation"}, "tout Quick-Bar"),
        ("hyprctl", {"arch": "hyprland", "debian": "hyprland", "fedora": "hyprland", "suse": "hyprland", "void": None, "nix": "hyprland",
                     "how": "hyprland.org → Installation"}, "espaces, fenêtres, raccourcis"),
        ("python3", {"arch": "python", "debian": "python3", "fedora": "python3", "suse": "python3", "void": "python3", "nix": "python3"},
         "démons de stats, Discord, santé, réglages"),
        ("jq", "jq", "scripts de santé et de fond d'écran"),
        ("fc-list", "fontconfig", "liste des polices (Réglages)"),
        ("py:tomlkit", {"arch": "python-tomlkit", "debian": "python3-tomlkit", "fedora": "python3-tomlkit", "suse": "python3-tomlkit",
                        "void": "python3-tomlkit", "nix": "python3Packages.tomlkit"}, "écriture de config.toml (Réglages)"),
    ]),
    ("Couleurs", True, [
        ("wallust", {"arch": "wallust", "debian": None, "fedora": None, "suse": None, "void": None, "nix": "wallust",
                     "how": "cargo install wallust"}, "palette Wallust (par défaut)"),
        ("matugen", {"arch": "matugen", "debian": None, "fedora": None, "suse": None, "void": None, "nix": "matugen",
                     "how": "cargo install matugen"}, "palette Matugen (Material You), si choisie"),
    ]),
    ("Fond d'écran", True, [
        ("awww", {"arch": "awww", "debian": None, "fedora": None, "suse": None, "void": None, "nix": None,
                  "how": "codeberg.org/LGFae/awww → compilation (cargo)"}, "wallpaper image"),
        ("gslapper", {"arch": "gslapper", "debian": None, "fedora": None, "suse": None, "void": None, "nix": None,
                      "how": GH + "Nomadcxx/gSlapper → compilation"}, "wallpaper vidéo"),
        ("magick", {"arch": "imagemagick", "fedora": "ImageMagick", "suse": "ImageMagick", "void": "ImageMagick"},
         "vignettes, image fixe des vidéos"),
        ("ffmpegthumbnailer", "ffmpegthumbnailer", "vignettes des vidéos"),
    ]),
    ("Audio et média", True, [
        ("wpctl", "wireplumber", "volume, mixeur"),
        ("pactl", {"arch": "libpulse", "debian": "pulseaudio-utils", "fedora": "pulseaudio-utils", "suse": "pulseaudio-utils",
                   "void": "pulseaudio-utils", "nix": "pulseaudio"}, "sorties audio"),
        ("playerctl", "playerctl", "contrôles média"),
        ("cava", "cava", "visualiseur de la barre"),
        ("easyeffects", "easyeffects", "égaliseur (presets EQ)"),
        ("pavucontrol", "pavucontrol", "clic droit Audio"),
    ]),
    ("Polices", True, [
        ("font:Nerd Font", {"arch": "ttf-cascadia-code-nerd", "debian": None, "fedora": None, "suse": None, "void": None,
                            "nix": "nerd-fonts.caskaydia-cove", "how": "nerdfonts.com → télécharger, copier dans ~/.local/share/fonts"},
         "icônes de toute la barre"),
    ]),
    ("Système et stats", False, [
        ("sensors", {"arch": "lm_sensors", "debian": "lm-sensors", "fedora": "lm_sensors", "suse": "sensors", "void": "lm_sensors",
                     "nix": "lm_sensors"}, "bilan de santé"),
        ("powerprofilesctl", "power-profiles-daemon", "profil d'énergie (carte CPU)"),
        ("smartctl", "smartmontools", "santé SMART des NVMe"),
        ("checkupdates", {"arch": "pacman-contrib", "debian": None, "fedora": None, "suse": None, "void": None, "nix": None,
                          "how": "spécifique à Arch (le module Mises à jour reste vide ailleurs)"}, "module Mises à jour"),
        ("paccache", {"arch": "pacman-contrib", "debian": None, "fedora": None, "suse": None, "void": None, "nix": None,
                      "how": "spécifique à Arch"}, "nettoyer le cache pacman"),
        ("btop", "btop", "clic sur CPU / RAM"),
        ("ncdu", "ncdu", "clic sur Disque"),
        ("amdgpu_top", {"arch": "amdgpu_top", "debian": None, "fedora": None, "suse": None, "void": None, "nix": "amdgpu_top",
                        "how": "cargo install amdgpu_top"}, "clic sur Temp GPU"),
        ("nvtop", "nvtop", "menu GPU"),
        ("lact", {"arch": "lact", "debian": None, "fedora": None, "suse": None, "void": None, "nix": "lact",
                  "how": GH + "ilya-zlobintsev/LACT → paquets .deb / .rpm"}, "réglages GPU, undervolt"),
    ]),
    ("Réseau et appareils", False, [
        ("nmcli", {"arch": "networkmanager", "debian": "network-manager", "fedora": "NetworkManager", "suse": "NetworkManager",
                   "void": "NetworkManager", "nix": "networkmanager"}, "Wi-Fi, hotspot, VPN"),
        ("bluetoothctl", {"arch": "bluez-utils", "debian": "bluez", "fedora": "bluez", "suse": "bluez", "void": "bluez", "nix": "bluez"},
         "Bluetooth"),
        ("blueman-manager", "blueman", "clic droit Bluetooth"),
        ("localsend", {"arch": "localsend-bin", "debian": None, "fedora": None, "suse": None, "void": None, "nix": "localsend",
                       "how": "flatpak install flathub org.localsend.localsend_app"}, "module LocalSend"),
        ("ddcutil", "ddcutil", "luminosité des écrans"),
    ]),
    ("Bureau", False, [
        ("swaync-client", {"arch": "swaync", "debian": "sway-notification-center", "fedora": "SwayNotificationCenter",
                           "suse": "SwayNotificationCenter", "void": "SwayNotificationCenter", "nix": "swaynotificationcenter"},
         "notifications, Ne pas déranger"),
        ("kitty", "kitty", "terminaux ouverts par la barre"),
        ("wl-copy", "wl-clipboard", "copier depuis les menus"),
        ("notify-send", {"arch": "libnotify", "debian": "libnotify-bin", "nix": "libnotify"}, "notifications de Quick-Bar"),
        ("xdg-open", "xdg-utils", "ouvrir des fichiers"),
        ("gio", {"arch": "glib2", "debian": "libglib2.0-bin", "fedora": "glib2", "suse": "glib2-tools", "void": "glib", "nix": "glib"},
         "corbeille"),
        ("wlogout", "wlogout", "menu d'alimentation"),
        ("hyprlock", "hyprlock", "verrouillage"),
        ("hyprsunset", "hyprsunset", "filtre de lumière bleue"),
        ("pypr", {"arch": "pyprland", "debian": None, "fedora": None, "suse": None, "void": None, "nix": "pyprland",
                  "how": "pipx install pyprland"}, "fenêtre Spotify (scratchpad)"),
        ("grim", "grim", "captures d'écran"),
        ("slurp", "slurp", "capture d'une zone"),
        ("wf-recorder", "wf-recorder", "enregistrement d'écran"),
        ("wvkbd-mobintl", "wvkbd", "clavier tactile (Discord, Terminal)"),
        ("qml:QMLTermWidget", {"arch": "qmltermwidget", "debian": None, "fedora": None, "suse": None, "void": None, "nix": None,
                               "how": GH + "Swordfish90/qmltermwidget → compiler pour Qt 6"}, "onglet Terminal du panneau tactile"),
    ]),
    ("RGB", False, [
        ("openrgb", {"arch": "openrgb", "debian": "openrgb", "fedora": "openrgb", "suse": "OpenRGB", "void": None, "nix": "openrgb",
                     "how": "openrgb.org → téléchargements"}, "LED, modes RGB"),
        ("py:openrgb", {"arch": "python-openrgb-git", "debian": None, "fedora": None, "suse": None, "void": None, "nix": None,
                        "how": "pip install openrgb-python"}, "contrôleur RGB"),
        ("py:watchdog", {"arch": "python-watchdog", "debian": "python3-watchdog", "fedora": "python3-watchdog",
                         "suse": "python3-watchdog", "void": "python3-watchdog", "nix": "python3Packages.watchdog"}, "surveillance RGB"),
    ]),
    ("Discord", False, [
        ("py:aiohttp", {"arch": "python-aiohttp", "debian": "python3-aiohttp", "fedora": "python3-aiohttp", "suse": "python3-aiohttp",
                        "void": "python3-aiohttp", "nix": "python3Packages.aiohttp"}, "pont Discord"),
        ("py:websockets", {"arch": "python-websockets", "debian": "python3-websockets", "fedora": "python3-websockets",
                           "suse": "python3-websockets", "void": "python3-websockets", "nix": "python3Packages.websockets"}, "pont Discord"),
    ]),
]

FAMILIES = {"arch": "arch", "manjaro": "arch", "endeavouros": "arch", "cachyos": "arch", "garuda": "arch", "artix": "arch",
            "debian": "debian", "ubuntu": "debian", "linuxmint": "debian", "pop": "debian", "elementary": "debian", "zorin": "debian",
            "fedora": "fedora", "rhel": "fedora", "centos": "fedora", "nobara": "fedora", "ultramarine": "fedora",
            "opensuse": "suse", "opensuse-tumbleweed": "suse", "opensuse-leap": "suse", "suse": "suse",
            "void": "void", "nixos": "nix"}
NAMES = {"arch": "Arch", "debian": "Debian / Ubuntu", "fedora": "Fedora", "suse": "openSUSE", "void": "Void", "nix": "NixOS"}


def distro():
    info = {}
    try:
        with open("/etc/os-release", encoding="utf-8") as f:
            for line in f:
                if "=" in line:
                    k, v = line.rstrip("\n").split("=", 1)
                    info[k] = v.strip('"')
    except OSError:
        pass
    family = None
    for ident in [info.get("ID", "")] + info.get("ID_LIKE", "").split():
        if ident in FAMILIES:
            family = FAMILIES[ident]
            break
    return {"id": info.get("ID", "?"), "name": info.get("PRETTY_NAME", info.get("NAME", "Linux")),
            "family": family or "arch", "known": family is not None}


def install_command(family, packages):
    if not packages:
        return ""
    pk = " ".join(sorted(set(packages)))
    if family == "arch":
        helper = next((h for h in ("paru", "yay") if shutil.which(h)), None)
        return f"{helper} -S --needed {pk}" if helper else f"sudo pacman -S --needed {pk}"
    return {"debian": f"sudo apt install {pk}", "fedora": f"sudo dnf install {pk}", "suse": f"sudo zypper install {pk}",
            "void": f"sudo xbps-install -S {pk}",
            "nix": "# NixOS : ajouter à environment.systemPackages : " + " ".join("pkgs." + p for p in sorted(set(packages)))}[family]


def present(name):
    if name.startswith("py:"):
        return importlib.util.find_spec(name[3:]) is not None
    if name.startswith("qml:"):
        try:
            qml = subprocess.run(["qtpaths6", "--query", "QT_INSTALL_QML"], capture_output=True, text=True, timeout=10).stdout.strip()
        except (OSError, subprocess.SubprocessError):
            qml = ""
        return any(os.path.isfile(os.path.join(d, name[4:], "qmldir")) for d in filter(None, [qml, "/usr/lib/qt6/qml"]))
    if name.startswith("font:"):
        try:
            out = subprocess.run(["fc-list", ":", "family"], capture_output=True, text=True, timeout=10).stdout
        except (OSError, subprocess.SubprocessError):
            return False
        return name[5:].lower() in out.lower()
    return shutil.which(name) is not None


def main():
    d = distro()
    fam = d["family"]
    deps, to_install, manual = [], [], []
    for group, required, items in DEPS:
        for name, pkgs, use in items:
            if isinstance(pkgs, str):
                pkg, how = pkgs, ""
            else:
                pkg = pkgs[fam] if fam in pkgs else pkgs.get("arch")   # absent = même nom que sous Arch
                how = pkgs.get("how", "")
            kind = ("python" if name.startswith("py:") else "font" if name.startswith("font:")
                    else "qml" if name.startswith("qml:") else "programme")
            ok = present(name)
            short = name.split(":", 1)[-1]
            deps.append({"group": group, "required": required, "name": short, "kind": kind,
                         "package": pkg or "", "manual": pkg is None, "how": how, "use": use, "ok": ok})
            if not ok:
                (manual.append({"name": short, "how": how or "voir la documentation du projet"}) if pkg is None
                 else to_install.append(pkg))
    print(json.dumps({"distro": {**d, "familyName": NAMES[fam]}, "deps": deps,
                      "install": install_command(fam, to_install), "manual": manual}, ensure_ascii=False))


if __name__ == "__main__":
    main()
