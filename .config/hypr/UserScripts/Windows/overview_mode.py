#!/usr/bin/env python3
"""
Mode Overview pour Hyprland - Style 󱇚
Passe toutes les fenêtres du workspace en float, les réduit et les centre
"""

import json
import datetime
import math
from pathlib import Path
from hyprland_manager import HyprlandManager


class OverviewMode:
    """Gestionnaire du mode overview"""
    
    def __init__(self):
        self.hypr = HyprlandManager()
        self.state_file = Path.home() / ".cache" / "hypr_overview_state.json"
        self.log_file = Path.home() / ".cache" / "hypr_overview.log"
        self.state_file.parent.mkdir(exist_ok=True)
        
        # Taille des fenêtres en mode overview (plus petites)
        self.overview_size = (300, 200)
        # Padding entre les fenêtres
        self.padding = 20
        # Taille d'une fenêtre avec padding
        self.cell_width = self.overview_size[0] + self.padding
        self.cell_height = self.overview_size[1] + self.padding
    
    def log(self, message):
        """Affichage sélectif pour overview hyprfloat"""
        if any(keyword in message for keyword in ["===", "📋", "⚙️", "🎯", "🎬", "💾", "✨", "🏁"]):
            print(message)
    
    def save_window_states(self, windows):
        """Sauvegarde l'état actuel des fenêtres"""
        states = {}
        for window in windows:
            states[window.address] = {
                'x': window.x,
                'y': window.y,
                'width': window.width,
                'height': window.height,
                'floating': window.floating,
                'workspace': window.workspace
            }
        
        with open(self.state_file, 'w') as f:
            json.dump(states, f, indent=2)
    
    def load_window_states(self):
        """Charge l'état sauvegardé des fenêtres"""
        if not self.state_file.exists():
            return {}
        
        try:
            with open(self.state_file, 'r') as f:
                return json.load(f)
        except (json.JSONDecodeError, FileNotFoundError):
            return {}
    
    def get_monitor_size(self):
        """Récupère la taille de l'écran principal"""
        output = self.hypr.run_hyprctl('monitors -j')
        if output:
            try:
                monitors = json.loads(output)
                if monitors:
                    monitor = monitors[0]  # Premier écran
                    return monitor.get('width', 1920), monitor.get('height', 1080)
            except json.JSONDecodeError:
                pass
        return 1920, 1080  # Valeur par défaut
    
    def analyze_current_layout(self, windows):
        """Analyse la disposition actuelle des fenêtres pour recréer la grille"""
        if not windows:
            return []
        
        self.log(f"🔍 Analyse de {len(windows)} fenêtres:")
        
        # Afficher les positions actuelles
        for i, window in enumerate(windows):
            self.log(f"  Fenêtre {i+1}: {window.title[:30]} - Position: ({window.x}, {window.y}) - Taille: {window.width}x{window.height}")
        
        # Trier les fenêtres par position (gauche à droite, puis haut en bas)
        sorted_windows = sorted(windows, key=lambda w: (w.x, w.y))
        
        # Détecter les colonnes en groupant par position X similaire
        columns = []
        current_col = []
        tolerance = 50  # Tolérance pour considérer que 2 fenêtres sont dans la même colonne
        
        self.log(f"📊 Détection des colonnes (tolérance: {tolerance}px):")
        
        for window in sorted_windows:
            if not current_col:
                current_col.append(window)
                self.log(f"  Nouvelle colonne 1 commencée avec: {window.title[:20]} (x={window.x})")
            else:
                # Vérifier si cette fenêtre est dans la même colonne
                if abs(window.x - current_col[0].x) <= tolerance:
                    current_col.append(window)
                    self.log(f"  Ajouté à colonne {len(columns)+1}: {window.title[:20]} (x={window.x}, diff={abs(window.x - current_col[0].x)}px)")
                else:
                    # Nouvelle colonne
                    columns.append(sorted(current_col, key=lambda w: w.y))
                    self.log(f"  Colonne {len(columns)} terminée avec {len(current_col)} fenêtre(s)")
                    current_col = [window]
                    self.log(f"  Nouvelle colonne {len(columns)+1} commencée avec: {window.title[:20]} (x={window.x})")
        
        if current_col:
            columns.append(sorted(current_col, key=lambda w: w.y))
            self.log(f"  Dernière colonne {len(columns)} terminée avec {len(current_col)} fenêtre(s)")
        
        self.log(f"📋 Résultat: {len(columns)} colonne(s) détectée(s)")
        for i, col in enumerate(columns):
            self.log(f"  Colonne {i+1}: {len(col)} fenêtre(s)")
        
        return columns
    
    def calculate_overview_grid(self, window_columns):
        """Calcule la grille d'overview basée sur la disposition actuelle"""
        screen_width, screen_height = self.get_monitor_size()
        
        num_cols = len(window_columns)
        total_windows = sum(len(col) for col in window_columns)
        
        self.log(f"⚙️  Calcul de la grille overview:")
        self.log(f"  Écran: {screen_width}x{screen_height}")
        self.log(f"  Colonnes: {num_cols}, Total fenêtres: {total_windows}")
        
        # Tailles adaptatives selon le nombre de fenêtres
        if total_windows <= 3:
            window_width = 480
            window_height = 300
            gap = 40  # Espacement pour éviter que les fenêtres se touchent
        elif total_windows <= 6:
            window_width = 400
            window_height = 250
            gap = 35
        elif total_windows <= 9:
            window_width = 340
            window_height = 215
            gap = 30
        else:
            window_width = 280
            window_height = 180
            gap = 25
        
        self.log(f"  Taille fenêtres: {window_width}x{window_height}, Gap: {gap}px")
        
        # Marges pour créer un rectangle d'overview plus visible
        margin_x = 150
        margin_y = 100
        
        # Calculer l'espace disponible
        available_width = screen_width - (2 * margin_x)
        available_height = screen_height - (2 * margin_y)
        
        self.log(f"  Marges: {margin_x}x{margin_y}, Espace dispo: {available_width}x{available_height}")
        
        # Calculer l'espacement horizontal entre colonnes
        if num_cols > 1:
            total_cols_width = num_cols * window_width
            horizontal_gap = min(gap, (available_width - total_cols_width) // (num_cols - 1))
            horizontal_gap = max(horizontal_gap, 20)  # Minimum 20px entre colonnes
        else:
            horizontal_gap = 0
        
        # Calculer la largeur totale de la grille
        total_grid_width = (num_cols * window_width) + ((num_cols - 1) * horizontal_gap)
        start_x = (screen_width - total_grid_width) // 2
        
        self.log(f"  Gap horizontal: {horizontal_gap}px, Grille totale: {total_grid_width}px, Start X: {start_x}")
        
        positions = []
        
        for col_idx, column in enumerate(window_columns):
            num_windows_in_col = len(column)
            
            # Calculer l'espacement vertical dans cette colonne
            if num_windows_in_col > 1:
                total_col_height = num_windows_in_col * window_height
                vertical_gap = min(gap, (available_height - total_col_height) // (num_windows_in_col - 1))
                vertical_gap = max(vertical_gap, 15)  # Minimum 15px entre fenêtres
            else:
                vertical_gap = 0
            
            # Hauteur totale de cette colonne
            col_height = (num_windows_in_col * window_height) + ((num_windows_in_col - 1) * vertical_gap)
            
            # Centrer verticalement cette colonne
            col_start_y = (screen_height - col_height) // 2
            
            # Position X de cette colonne
            col_x = start_x + col_idx * (window_width + horizontal_gap)
            
            self.log(f"  Colonne {col_idx+1}: {num_windows_in_col} fenêtres, X={col_x}, Y_start={col_start_y}, gap_vertical={vertical_gap}px")
            
            # Ajouter les positions pour chaque fenêtre de cette colonne
            for row_idx in range(num_windows_in_col):
                y = col_start_y + row_idx * (window_height + vertical_gap)
                positions.append((col_x, y))
                self.log(f"    Position {len(positions)}: ({col_x}, {y})")
        
        # Mettre à jour la taille des fenêtres pour cette session
        self.overview_size = (window_width, window_height)
        
        self.log(f"📐 Grille calculée: {len(positions)} positions générées")
        
        return positions
    
    def calculate_proportional_layout(self, windows):
        """Calcule une disposition proportionnelle miniaturisée de la disposition actuelle"""
        screen_width, screen_height = self.get_monitor_size()
        
        if not windows:
            return []
        
        # Trouver les bornes de la disposition actuelle
        min_x = min(w.x for w in windows)
        max_x = max(w.x + w.width for w in windows)
        min_y = min(w.y for w in windows)
        max_y = max(w.y + w.height for w in windows)
        
        # Dimensions de la disposition actuelle
        layout_width = max_x - min_x
        layout_height = max_y - min_y
        
        # Taille des fenêtres dans l'overview (équilibré)
        window_width = 450  # Taille intermédiaire
        window_height = 300  # Taille intermédiaire
        
        # Dimensions cibles pour l'overview (80% de l'écran)
        target_width = screen_width * 0.8
        target_height = screen_height * 0.8
        
        # Calculer le facteur de réduction pour que tout rentre
        # Prendre en compte la taille des fenêtres + marge pour éviter les chevauchements
        margin = 50  # Marge supplémentaire entre les fenêtres
        effective_target_width = target_width - window_width - margin
        effective_target_height = target_height - window_height - margin
        
        scale_x = effective_target_width / layout_width if layout_width > 0 else 1
        scale_y = effective_target_height / layout_height if layout_height > 0 else 1
        scale = min(scale_x, scale_y, 0.35)  # Augmenté à 35% pour plus d'espace entre fenêtres
        
        # Mettre à jour la taille pour cette session
        self.overview_size = (window_width, window_height)
        
        # Calculer le centre de l'écran
        center_x = screen_width // 2
        center_y = screen_height // 2
        
        # Calculer les nouvelles positions avec espacement garanti
        positions = []
        
        # Si trop de fenêtres, utiliser une grille simple
        if len(windows) > 6:
            # Mode grille pour beaucoup de fenêtres
            cols = 3
            for i, w in enumerate(windows):
                col = i % cols
                row = i // cols
                new_x = center_x - 450 + col * 300  # Espacement fixe de 300px
                new_y = center_y - 200 + row * 200  # Espacement fixe de 200px
                positions.append((new_x, new_y))
                self.log(f"    Position {i+1}: ({new_x}, {new_y}) [grille]")
        else:
            # Mode proportionnel avec espacement minimum garanti
            for w in windows:
                # Position relative dans la disposition originale
                rel_x = (w.x - min_x) * scale
                rel_y = (w.y - min_y) * scale
                
                # Position absolue centrée à l'écran
                new_x = int(center_x - (layout_width * scale) // 2 + rel_x)
                new_y = int(center_y - (layout_height * scale) // 2 + rel_y)
                
                positions.append((new_x, new_y))
                self.log(f"    Position {len(positions)}: ({new_x}, {new_y}) [scale={scale:.2f}]")
        
        return positions
    
    def calculate_reduced_box_grid(self, window_columns):
        """Calcule une grille dans une boîte réduite centrée, preservant la disposition tiled"""
        screen_width, screen_height = self.get_monitor_size()
        
        # Dimensions de la boîte réduite (60% de l'écran)
        box_width = screen_width * 0.6
        box_height = screen_height * 0.6
        
        # Centre de l'écran
        center_x = screen_width // 2
        center_y = screen_height // 2
        
        # Coins de la boîte réduite
        box_start_x = center_x - box_width // 2
        box_start_y = center_y - box_height // 2
        
        # Calculer les dimensions des fenêtres dans la boîte
        num_cols = len(window_columns)
        total_windows = sum(len(col) for col in window_columns)
        
        # Taille des fenêtres adaptée à la boîte
        window_width = 350
        window_height = 220
        gap = 20
        
        # Calculer les positions comme dans calculate_overview_grid mais dans la boîte
        positions = []
        
        # Espacement horizontal entre colonnes
        if num_cols > 1:
            horizontal_gap = max(gap, (box_width - num_cols * window_width) // (num_cols - 1))
        else:
            horizontal_gap = 0
        
        # Position X de départ pour centrer toutes les colonnes dans la boîte
        total_grid_width = num_cols * window_width + (num_cols - 1) * horizontal_gap
        start_x = box_start_x + (box_width - total_grid_width) // 2
        
        self.log(f"⚙️  Boîte réduite: {box_width}x{box_height} à ({box_start_x}, {box_start_y})")
        self.log(f"⚙️  Grille: {num_cols} colonnes, fenêtres {window_width}x{window_height}")
        
        for col_idx, column in enumerate(window_columns):
            num_windows_in_col = len(column)
            
            # Espacement vertical dans cette colonne
            if num_windows_in_col > 1:
                vertical_gap = max(gap, (box_height - num_windows_in_col * window_height) // (num_windows_in_col - 1))
            else:
                vertical_gap = 0
            
            # Hauteur totale de cette colonne
            col_height = num_windows_in_col * window_height + (num_windows_in_col - 1) * vertical_gap
            
            # Position Y de départ pour centrer cette colonne verticalement dans la boîte
            col_start_y = box_start_y + (box_height - col_height) // 2
            
            # Position X de cette colonne
            col_x = start_x + col_idx * (window_width + horizontal_gap)
            
            self.log(f"  Colonne {col_idx+1}: {num_windows_in_col} fenêtres, X={col_x}, Y_start={col_start_y}")
            
            # Ajouter les positions pour chaque fenêtre de cette colonne
            for row_idx in range(num_windows_in_col):
                y = col_start_y + row_idx * (window_height + vertical_gap)
                positions.append((col_x, y))
                self.log(f"    Position {len(positions)}: ({col_x}, {y})")
        
        # Mettre à jour la taille des fenêtres pour cette session
        self.overview_size = (window_width, window_height)
        
        self.log(f"📐 Boîte réduite calculée: {len(positions)} positions générées")
        
        return positions
    
    def calculate_hyprfloat_grid(self, windows):
        """Calcule une grille intelligente comme hyprfloat"""
        screen_width, screen_height = self.get_monitor_size()
        
        # Zone d'overview (80% de l'écran)
        overview_ratio = 0.8
        overview_width = screen_width * overview_ratio
        overview_height = screen_height * overview_ratio
        
        start_x = (screen_width - overview_width) // 2
        start_y = (screen_height - overview_height) // 2
        
        # Calculer grille optimale
        num_windows = len(windows)
        cols = int(math.ceil(math.sqrt(num_windows)))
        rows = int(math.ceil(num_windows / cols))
        
        # Dimensions des fenêtres avec contraintes
        gap = 30
        padding = 50
        
        available_width = overview_width - (2 * padding) - ((cols - 1) * gap)
        available_height = overview_height - (2 * padding) - ((rows - 1) * gap)
        
        window_width = min(400, available_width // cols)
        window_height = min(280, available_height // rows)
        
        # Préserver ratio d'aspect 16:10
        target_ratio = 16 / 10
        if window_width / window_height > target_ratio:
            window_width = int(window_height * target_ratio)
        else:
            window_height = int(window_width / target_ratio)
        
        # Centrer la grille
        total_grid_width = cols * window_width + (cols - 1) * gap
        total_grid_height = rows * window_height + (rows - 1) * gap
        
        grid_start_x = start_x + (overview_width - total_grid_width) // 2
        grid_start_y = start_y + (overview_height - total_grid_height) // 2
        
        # Mettre à jour la taille pour cette session
        self.overview_size = (window_width, window_height)
        
        self.log(f"⚙️  Grille hyprfloat: {cols}x{rows}, fenêtres {window_width}x{window_height}")
        self.log(f"⚙️  Zone: {overview_width}x{overview_height} à ({start_x}, {start_y})")
        
        # Générer les positions
        positions = []
        for i in range(num_windows):
            col = i % cols
            row = i // cols
            
            x = grid_start_x + col * (window_width + gap)
            y = grid_start_y + row * (window_height + gap)
            
            positions.append((x, y))
            self.log(f"    Position {i+1}: ({x}, {y})")
        
        return positions
    
    def enter_overview(self, workspace_id=None):
        """Entre en mode overview"""
        if workspace_id is None:
            workspace_id = self.hypr.get_active_workspace()
        
        if workspace_id is None:
            print("❌ Impossible de déterminer le workspace actif")
            return
        
        screen_width, screen_height = self.get_monitor_size()
        self.log(f"🚀 === DÉBUT MODE OVERVIEW WORKSPACE {workspace_id} ===")
        self.log(f"🔍 Mode overview {workspace_id} ({screen_width}x{screen_height})")
        
        # Actualiser les données
        self.hypr.refresh_data()
        
        # Récupérer TOUTES les fenêtres du workspace actuel
        windows = [w for w in self.hypr.get_windows_by_workspace(workspace_id) 
                  if w.workspace > 0]  # Exclure seulement les workspaces spéciaux
        
        if not windows:
            self.log("📭 Aucune fenêtre trouvée")
            return
        
        # Vérifier s'il y a des fenêtres floating (disposition mixte)
        # Approche simple : parser ligne par ligne
        import subprocess
        result = subprocess.run(['hyprctl', 'clients'], capture_output=True, text=True)
        
        floating_count_actual = 0
        lines = result.stdout.split('\n')
        current_workspace = None
        
        for i, line in enumerate(lines):
            line = line.strip()
            # Détecter le workspace
            if line.startswith('workspace:'):
                if f'workspace: {workspace_id} (' in line:
                    current_workspace = workspace_id
                else:
                    current_workspace = None
            # Détecter floating dans ce workspace
            elif line == 'floating: 1' and current_workspace == workspace_id:
                floating_count_actual += 1
        
        has_floating = floating_count_actual > 0
        self.log(f"🔍 Debug: {floating_count_actual}/{len(windows)} fenêtres floating détectées (workspace {workspace_id})")
        
        # Mode hyprfloat overview : grille intelligente centrée
        self.log(f"📋 {len(windows)} fenêtre(s) - Mode overview hyprfloat")
        
        # Calculer grille optimale (comme hyprfloat)
        positions = self.calculate_hyprfloat_grid(windows)
        
        # Créer un mapping direct fenêtres → positions
        window_position_map = list(zip(windows, positions))
        
        self.log("🎯 Mapping fenêtres → positions (hyprfloat):")
        for i, (window, (x, y)) in enumerate(window_position_map):
            self.log(f"  {window.title[:25]} → Position {i+1}: ({x}, {y})")
        
        # Sauvegarder l'état actuel
        self.save_window_states(windows)
        self.log("💾 États des fenêtres sauvegardés")
        
        # Passer chaque fenêtre en mode overview en conservant l'ordre des colonnes
        self.log("🎬 Application des transformations:")
        for i, (window, (x, y)) in enumerate(window_position_map):
            self.log(f"  Transformation {i+1}/{len(window_position_map)}: {window.title[:20]}")
            self.log(f"    Avant: {window.width}x{window.height} à ({window.x}, {window.y}) floating={window.floating}")
            
            # Passer en floating
            if not window.floating:
                self.hypr.toggle_floating(window.address)
                self.log(f"    → Passé en floating")
            
            # Redimensionner et positionner avec espacement
            self.hypr.resize_window(window.address, self.overview_size[0], self.overview_size[1])
            self.hypr.move_window(window.address, x, y)
            self.log(f"    → Nouveau: {self.overview_size[0]}x{self.overview_size[1]} à ({x}, {y})")
        
        self.log("✨ Mode overview activé ! SUPER+TAB pour revenir")
        self.log("🏁 === FIN ACTIVATION OVERVIEW ===\n")
    
    def exit_overview(self):
        """Sort du mode overview et restaure l'état original"""
        self.log("🔙 === DÉBUT RESTAURATION OVERVIEW ===")
        self.log("🔙 Restauration depuis le mode overview")
        
        states = self.load_window_states()
        if not states:
            self.log("❌ Aucun état sauvegardé trouvé")
            return
        
        self.log(f"📂 {len(states)} état(s) chargé(s) depuis la sauvegarde")
        
        # Actualiser les données
        self.hypr.refresh_data()
        
        restored_count = 0
        self.log("🔄 Restauration des fenêtres:")
        
        for window in self.hypr.windows:
            if window.address in states:
                original_state = states[window.address]
                
                self.log(f"  Restauration: {window.title[:25]}")
                self.log(f"    Actuel: {window.width}x{window.height} à ({window.x}, {window.y}) floating={window.floating}")
                self.log(f"    Target: {original_state['width']}x{original_state['height']} à ({original_state['x']}, {original_state['y']}) floating={original_state['floating']}")
                
                # Restaurer la taille et position originales
                self.hypr.move_window(window.address, original_state['x'], original_state['y'])
                self.hypr.resize_window(window.address, original_state['width'], original_state['height'])
                
                # Restaurer le mode floating/tiling
                if window.floating != original_state['floating']:
                    self.hypr.toggle_floating(window.address)
                    self.log(f"    → Mode basculé vers floating={original_state['floating']}")
                
                restored_count += 1
        
        # Supprimer le fichier d'état
        if self.state_file.exists():
            self.state_file.unlink()
            self.log("🗑️  Fichier d'état supprimé")
        
        self.log(f"✅ {restored_count} fenêtre(s) restaurée(s)")
        self.log("🏁 === FIN RESTAURATION ===\n")
    
    def is_in_overview(self):
        """Vérifie si on est actuellement en mode overview"""
        return self.state_file.exists()
    
    def toggle_overview(self, workspace_id=None):
        """Bascule entre le mode overview et normal"""
        if self.is_in_overview():
            self.exit_overview()
        else:
            self.enter_overview(workspace_id)
    
    def move_window_in_overview(self, window_address, new_x, new_y):
        """Déplace une fenêtre en mode overview (met à jour la sauvegarde)"""
        if not self.is_in_overview():
            print("❌ Pas en mode overview")
            return
        
        # Déplacer la fenêtre
        self.hypr.move_window(window_address, new_x, new_y)
        
        # Mettre à jour l'état sauvegardé pour que la nouvelle position soit conservée
        states = self.load_window_states()
        if window_address in states:
            # La position sauvegardée reste l'originale, on ne change que visuellement
            pass
    
    def apply_new_layout(self):
        """Applique la nouvelle disposition et sort du mode overview"""
        print("🎯 Application de la nouvelle disposition")
        
        if not self.is_in_overview():
            print("❌ Pas en mode overview")
            return
        
        # Actualiser les données pour voir les positions actuelles
        self.hypr.refresh_data()
        
        # Pour chaque fenêtre, garder sa position actuelle mais repasser en tiling
        for window in self.hypr.windows:
            if window.floating and window.workspace > 0:  # Fenêtres en overview
                # Garder la position actuelle mais repasser en tiling si nécessaire
                # Note: en mode tiling, Hyprland ignore les positions manuelles
                if window.floating:
                    self.hypr.toggle_floating(window.address)
        
        # Supprimer le fichier d'état
        if self.state_file.exists():
            self.state_file.unlink()
        
        print("✅ Nouvelle disposition appliquée en mode tiling")


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="Mode Overview Hyprland")
    parser.add_argument('--toggle', action='store_true', help='Basculer le mode overview')
    parser.add_argument('--enter', action='store_true', help='Entrer en mode overview')
    parser.add_argument('--exit', action='store_true', help='Sortir du mode overview')
    parser.add_argument('--apply', action='store_true', help='Appliquer la nouvelle disposition')
    parser.add_argument('--workspace', type=int, help='Workspace à utiliser (défaut: actuel)')
    
    args = parser.parse_args()
    
    overview = OverviewMode()
    
    if args.toggle:
        overview.toggle_overview(args.workspace)
    elif args.enter:
        overview.enter_overview(args.workspace)
    elif args.exit:
        overview.exit_overview()
    elif args.apply:
        overview.apply_new_layout()
    else:
        # Par défaut, toggle
        overview.toggle_overview(args.workspace)


if __name__ == "__main__":
    main()