#!/usr/bin/env python3
"""
add_nonsteam_games.py — Ajoute des jeux non-Steam dans shortcuts.vdf
et télécharge automatiquement les artworks (grid/hero/logo/icon) via SteamGridDB.

USAGE :
    export STEAMGRIDDB_API_KEY="ta_cle_api"
    python3 add_nonsteam_games.py --config games.json

    # Pour prévisualiser sans rien écrire :
    python3 add_nonsteam_games.py --config games.json --dry-run

IMPORTANT :
    - Ferme Steam avant de lancer ce script (sinon Steam écrase shortcuts.vdf
      en quittant et annule tes changements).
    - Relance Steam après pour voir les jeux + artworks apparaître.
"""

import argparse
import json
import os
import struct
import sys
import zlib
from pathlib import Path

import requests
import vdf

STEAMGRIDDB_BASE = "https://www.steamgriddb.com/api/v2"

# Racines possibles où chercher userdata/ selon l'install (native / flatpak)
STEAM_ROOTS = [
    "~/.steam/steam",
    "~/.local/share/Steam",
    "~/.var/app/com.valvesoftware.Steam/.local/share/Steam",
]


# --------------------------------------------------------------------------
# Détection de l'installation Steam / profil utilisateur
# --------------------------------------------------------------------------
def find_userdata_dir(user_id_override=None, steam_root_override=None):
    roots = [steam_root_override] if steam_root_override else STEAM_ROOTS
    for root in roots:
        userdata = Path(root).expanduser() / "userdata"
        if not userdata.is_dir():
            continue
        profiles = [p for p in userdata.iterdir() if p.is_dir() and p.name.isdigit()]
        if user_id_override:
            match = userdata / str(user_id_override)
            if match.is_dir():
                return match / "config"
            continue
        # Le profil "0" est un placeholder Steam (anonyme), pas un vrai compte.
        # S'il y a un seul VRAI profil à côté, on le prend automatiquement.
        real_profiles = [p for p in profiles if p.name != "0"]
        if len(real_profiles) == 1:
            return real_profiles[0] / "config"
        if len(profiles) == 1:
            return profiles[0] / "config"
        if len(real_profiles) > 1:
            print("Plusieurs profils Steam trouvés, précise avec --user-id :")
            for p in real_profiles:
                print(f"  - {p.name}")
            sys.exit(1)
    print("Impossible de trouver le dossier userdata de Steam. "
          "Utilise --steam-root pour préciser le chemin d'installation.")
    sys.exit(1)


# --------------------------------------------------------------------------
# Calcul de l'appid Steam (algo "legacy" utilisé par les jeux non-Steam)
# --------------------------------------------------------------------------
def compute_ids(exe, name):
    """
    Calcule les IDs Steam pour un raccourci non-Steam.
    IMPORTANT : Steam calcule le CRC32 sur '"<exe>"' + AppName — c'est-à-dire le
    chemin de l'exe ENTRE GUILLEMETS (tel qu'il est réellement stocké dans
    shortcuts.vdf), concaténé au nom du jeu SANS guillemets.
    Oublier ces guillemets donne un ID différent de celui que Steam recalcule
    pour chercher les images dans grid/ → le jeu apparaît mais sans artwork.
    """
    key = f'"{exe}"{name}'
    crc = zlib.crc32(key.encode("utf-8")) & 0xFFFFFFFF
    unsigned = crc | 0x80000000
    signed = unsigned - 0x100000000
    return signed, unsigned


def grid_appid(unsigned_legacy_id):
    """
    ID utilisé pour les NOMS DE FICHIERS d'artwork dans grid/.
    Constaté empiriquement sur ce client Steam : c'est l'appid NON SIGNÉ tel quel
    (pas le décalage 64 bits << 32 | 0x02000000 documenté dans les anciens guides,
    qui ne correspond plus au client Steam actuel).
    """
    return unsigned_legacy_id


# --------------------------------------------------------------------------
# shortcuts.vdf : lecture / écriture
# --------------------------------------------------------------------------
def load_shortcuts(path):
    if not path.exists():
        return {"shortcuts": {}}
    with open(path, "rb") as f:
        return vdf.binary_load(f)


def save_shortcuts(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "wb") as f:
        vdf.binary_dump(data, f)


def build_entry(index, game, unsigned_appid):
    signed_appid = unsigned_appid - 0x100000000 if unsigned_appid >= 0x80000000 else unsigned_appid
    tags = {str(i): t for i, t in enumerate(game.get("tags", []))}
    return {
        "appid": signed_appid,
        "AppName": game["name"],
        "Exe": f'"{game["exe"]}"',
        "StartDir": f'"{game.get("start_dir", str(Path(game["exe"]).parent))}"',
        "icon": game.get("icon", ""),
        "ShortcutPath": "",
        "LaunchOptions": game.get("launch_options", ""),
        "IsHidden": 0,
        "AllowDesktopConfig": 1,
        "AllowOverlay": 1,
        "OpenVR": 0,
        "Devkit": 0,
        "DevkitGameID": "",
        "DevkitOverrideAppID": 0,
        "LastPlayTime": 0,
        "FlatpakAppID": "",
        "tags": tags,
    }


# --------------------------------------------------------------------------
# SteamGridDB : recherche + téléchargement des artworks
# --------------------------------------------------------------------------
class SteamGridDB:
    def __init__(self, api_key):
        self.headers = {"Authorization": f"Bearer {api_key}"}

    def search(self, name):
        r = requests.get(f"{STEAMGRIDDB_BASE}/search/autocomplete/{requests.utils.quote(name)}",
                          headers=self.headers, timeout=15)
        r.raise_for_status()
        results = r.json().get("data", [])
        return results[0]["id"] if results else None

    def _first_image_url(self, endpoint, game_id, params=None):
        query = {"mimes": "image/png,image/jpeg"}
        query.update(params or {})
        r = requests.get(f"{STEAMGRIDDB_BASE}/{endpoint}/game/{game_id}",
                          headers=self.headers, params=query, timeout=15)
        if r.status_code != 200:
            return None
        data = r.json().get("data", [])
        return data[0]["url"] if data else None

    def get_grid_portrait(self, gid):
        return self._first_image_url("grids", gid, {"dimensions": "600x900"})

    def get_grid_landscape(self, gid):
        return self._first_image_url("grids", gid, {"dimensions": "460x215"})

    def get_hero(self, gid):
        return self._first_image_url("heroes", gid)

    def get_logo(self, gid):
        return self._first_image_url("logos", gid)

    def get_icon(self, gid):
        return self._first_image_url("icons", gid, {"mimes": "image/png,image/vnd.microsoft.icon"})


def download(url, dest):
    r = requests.get(url, timeout=30)
    r.raise_for_status()
    dest.write_bytes(r.content)


def ext_from_url(url, default="png"):
    suffix = Path(url.split("?")[0]).suffix.lstrip(".")
    return suffix if suffix else default


def fetch_artwork(sgdb, name, unsigned_appid, grid_dir, dry_run):
    gid = sgdb.search(name)
    if gid is None:
        print(f"    ! Rien trouvé sur SteamGridDB pour « {name} »")
        return None

    gappid = grid_appid(unsigned_appid)
    urls = {
        "portrait": sgdb.get_grid_portrait(gid),   # grille verticale (bibliothèque)
        "landscape": sgdb.get_grid_landscape(gid), # capsule horizontale
        "hero": sgdb.get_hero(gid),                # bannière en haut de la page jeu
        "logo": sgdb.get_logo(gid),                # logo transparent
        "icon": sgdb.get_icon(gid),                # icône
    }
    filename_patterns = {
        "portrait": "{id}p.{ext}",
        "landscape": "{id}.{ext}",
        "hero": "{id}_hero.{ext}",
        "logo": "{id}_logo.{ext}",
        "icon": "{id}icon.{ext}",
    }

    icon_local_path = None
    for kind, url in urls.items():
        if not url:
            continue
        filename = filename_patterns[kind].format(id=gappid, ext=ext_from_url(url))
        dest = grid_dir / filename
        if dry_run:
            print(f"    [dry-run] {filename} <- {url}")
            if kind == "icon":
                icon_local_path = str(dest)
            continue
        try:
            download(url, dest)
            print(f"    + {filename}")
            if kind == "icon":
                icon_local_path = str(dest)
        except requests.RequestException as e:
            print(f"    ! Échec téléchargement {filename} : {e}")

    return icon_local_path


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config", default="games.json", help="Fichier JSON listant les jeux à ajouter")
    ap.add_argument("--user-id", help="ID numérique du profil Steam (si plusieurs comptes)")
    ap.add_argument("--steam-root", help="Chemin d'installation Steam (auto-détecté sinon)")
    ap.add_argument("--api-key", default=os.environ.get("STEAMGRIDDB_API_KEY"),
                     help="Clé API SteamGridDB (ou variable d'env STEAMGRIDDB_API_KEY)")
    ap.add_argument("--dry-run", action="store_true", help="Simule sans rien écrire")
    args = ap.parse_args()

    if not args.api_key:
        print("Aucune clé API SteamGridDB fournie (--api-key ou export STEAMGRIDDB_API_KEY=...).")
        sys.exit(1)

    config_path = Path(args.config)
    if not config_path.exists():
        print(f"Fichier de config introuvable : {config_path}")
        sys.exit(1)
    games = json.loads(config_path.read_text())

    config_dir = find_userdata_dir(args.user_id, args.steam_root)
    shortcuts_path = config_dir / "shortcuts.vdf"
    grid_dir = config_dir / "grid"

    print(f"Fichier shortcuts : {shortcuts_path}")
    data = load_shortcuts(shortcuts_path)
    existing = data.setdefault("shortcuts", {})
    existing_names = {v["AppName"] for v in existing.values()}

    sgdb = SteamGridDB(args.api_key)
    next_index = max([int(k) for k in existing.keys()], default=-1) + 1

    for game in games:
        name = game["name"]
        if name in existing_names:
            print(f"- {name} déjà présent, ignoré (supprime-le manuellement pour le réajouter)")
            continue

        unsigned_appid = zlib.crc32((f'"{game["exe"]}"' + name).encode("utf-8")) | 0x80000000
        signed_appid = unsigned_appid - 0x100000000

        print(f"+ {name}  (appid {signed_appid})")
        icon_path = fetch_artwork(sgdb, name, unsigned_appid, grid_dir, args.dry_run)
        if icon_path:
            game["icon"] = icon_path

        entry = build_entry(next_index, game, unsigned_appid)
        if not args.dry_run:
            existing[str(next_index)] = entry
        next_index += 1

    if args.dry_run:
        print("\n[dry-run] Rien n'a été écrit sur disque.")
    else:
        grid_dir.mkdir(parents=True, exist_ok=True)
        save_shortcuts(shortcuts_path, data)
        print(f"\n{shortcuts_path} mis à jour. Relance Steam pour voir les jeux.")


if __name__ == "__main__":
    main()
