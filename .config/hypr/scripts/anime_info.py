#!/usr/bin/env python3

import requests
import re
from datetime import datetime
import subprocess
import sys
import tempfile
import os


def parse_js_calls(js_content):
    """Parse les appels JavaScript pour extraire les informations d'anime uniquement"""
    
    releases = []
    postponed = []
    
    # Regex pour capturer UNIQUEMENT les appels cartePlanningAnime
    anime_pattern = r'cartePlanningAnime\("([^"]+)",\s*"([^"]+)",\s*"([^"]+)",\s*"([^"]+)",\s*"([^"]*)",\s*"([^"]+)"\);'
    
    # Trouver tous les appels d'anime (ignorer les scans)
    anime_matches = re.findall(anime_pattern, js_content)
    
    for match in anime_matches:
        name, url, image, time, problem, lang = match
        
        # Vérifier si reporté
        is_postponed = problem.strip() == "Reporté"
        
        anime_info = {
            "title": name,
            "time": time,
            "type": lang,
            "postponed": is_postponed,
            "category": "Anime"
        }
        
        if is_postponed:
            postponed.append(anime_info)
        else:
            releases.append(anime_info)
    
    return releases, postponed


def get_anime_releases(filter_vostfr_only=False):
    """Récupère les sorties d'anime du jour depuis anime-sama.fr"""

    url = "https://anime-sama.fr/planning/"

    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        
        # Extraire le contenu JavaScript
        js_content = response.text
        
        # Parser les appels JavaScript
        releases, postponed = parse_js_calls(js_content)
        
        # Filtrer si nécessaire
        if filter_vostfr_only:
            releases = [r for r in releases if r["type"] == "VOSTFR"]
            postponed = [p for p in postponed if p["type"] == "VOSTFR"]
        
        print(f"Debug: {len(releases)} sorties trouvées, {len(postponed)} reports")
        
        # Afficher le détail de ce qui a été trouvé
        for release in releases:
            print(f"Debug: {release['title']} à {release['time']} ({release['type']}) [{release['category']}]")
        
        for item in postponed:
            print(f"Debug: {item['title']} ({item['type']}) [{item['category']}] - REPORTÉ")

        return releases, postponed

    except requests.exceptions.RequestException as e:
        print(f"Erreur lors de la récupération de la page: {e}")
        return [], []
    except Exception as e:
        print(f"Erreur lors de l'analyse: {e}")
        import traceback
        traceback.print_exc()
        return [], []


def format_releases(releases, postponed, filter_vostfr=False):
    """Formate les sorties pour l'affichage"""

    current_time = datetime.now()
    filter_text = " (VOSTFR uniquement)" if filter_vostfr else ""
    message = f"Planning Anime - {current_time.strftime('%d/%m/%Y')}{filter_text}\n"
    message += "=" * 40 + "\n\n"

    if releases:
        # Trier par heure
        def parse_time(time_str):
            if time_str == "?":
                return 9999  # Mettre à la fin
            try:
                if "h" in time_str:
                    parts = time_str.split("h")
                    hour = int(parts[0])
                    minute = int(parts[1]) if parts[1] else 0
                    return hour * 60 + minute
                return 9999
            except:
                return 9999

        releases.sort(key=lambda x: parse_time(x["time"]))

        message += "Sorties Anime du jour:\n"
        for release in releases:
            message += f"• {release['time']} - {release['title']}\n"
        
    else:
        message += "Aucune sortie anime prévue aujourd'hui\n"

    if postponed:
        message += "\nReports:\n"
        for item in postponed:
            emoji = "VF" if item["type"] == "VF" else "VOSTFR"
            message += f"• {item['title']} ({emoji}) - Reporté\n"

    return message


def show_in_kitty_terminal(message):
    """Affiche le message dans un terminal Kitty flottant"""
    try:
        # Créer un script temporaire avec le message
        with tempfile.NamedTemporaryFile(mode='w', suffix='.sh', delete=False) as f:
            script_content = f'''#!/bin/bash
clear
cat << 'EOL'
{message}

Appuyez sur Entrée pour fermer...
EOL
read
rm "$0"
'''
            f.write(script_content)
            script_path = f.name
        
        os.chmod(script_path, 0o755)
        
        # Lancer Kitty avec le script
        subprocess.Popen([
            'kitty',
            '--class=anime-planning',
            '--title=Planning Anime',
            'bash',
            script_path
        ])
        
        return True
        
    except Exception as e:
        print(f"Impossible de lancer Kitty: {e}")
        return False


def send_notification(message):
    """Affiche le message dans un terminal Kitty ou notification de fallback"""
    
    # Essayer d'abord Kitty
    if show_in_kitty_terminal(message):
        return True
    
    # Fallback vers les notifications système
    try:
        subprocess.run([
            "notify-send", "Planning Anime", message, "-t", "15000", "-i", "video-x-generic"
        ], check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        try:
            subprocess.run([
                "osascript", "-e", 
                f'display notification "{message}" with title "Planning Anime"'
            ], check=True)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False


def main():
    """Fonction principale"""
    # Vérifier les arguments de ligne de commande
    filter_vostfr = "--vostfr" in sys.argv or "-v" in sys.argv

    if filter_vostfr:
        print("Récupération du planning (VOSTFR uniquement)...")
    else:
        print("Récupération du planning (tous)...")

    releases, postponed = get_anime_releases(filter_vostfr_only=filter_vostfr)

    message = format_releases(releases, postponed, filter_vostfr)

    # Afficher dans le terminal
    print("\n" + message)

    # Essayer d'envoyer une notification
    if not send_notification(message):
        print("Impossible d'envoyer la notification système.")

    # Sauvegarder dans un fichier log
    try:
        filter_text = "VOSTFR seulement" if filter_vostfr else "tous"
        with open("anime_releases.log", "a", encoding="utf-8") as f:
            f.write(
                f"{datetime.now()}: {len(releases)} sorties ({filter_text}), {len(postponed)} reports\n"
            )
    except Exception as e:
        print(f"Impossible de sauvegarder le log: {e}")


if __name__ == "__main__":
    main()