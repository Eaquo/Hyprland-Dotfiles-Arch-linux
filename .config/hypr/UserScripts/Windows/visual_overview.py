#!/usr/bin/env python3
"""
Visual Overview Mode - Nouveau système avec bordures et grille
Reproduction fidèle de la disposition tiled mais réduite avec éléments visuels
"""

import json
import subprocess
import math
from pathlib import Path
from hyprland_manager import HyprlandManager


class VisualOverview:
    """Gestionnaire du mode overview visuel avec bordures et grille"""
    
    def __init__(self):
        self.hypr = HyprlandManager()
        
        # Configuration overview - inspirée d'hyprfloat
        self.overview_area_ratio = 0.8  # 80% de l'écran (plus généreux)
        self.window_scale = 0.25        # Facteur d'échelle des fenêtres (25%)
        self.min_window_size = (240, 160)  # Taille minimum lisible
        self.max_window_size = (400, 300)  # Taille maximum
        
        # Grid layout - comme hyprfloat
        self.grid_padding = 40          # Padding global
        self.window_gap = 25            # Gap entre fenêtres
        self.preserve_aspect = True     # Préserver ratio d'aspect
        
        # Visual elements
        self.show_window_titles = True  # Afficher titres
        self.highlight_focused = True   # Surligner fenêtre active
        
        # State management
        self.state_file = Path.home() / ".local" / "share" / "hyprland" / "visual_overview_state.json"
        self.is_overview_active = False
        self.state_file.parent.mkdir(exist_ok=True)
    
    def get_monitor_size(self):
        """Récupère la taille du moniteur principal"""
        result = subprocess.run(['hyprctl', 'monitors', '-j'], capture_output=True, text=True)
        monitors = json.loads(result.stdout)
        
        for monitor in monitors:
            if monitor.get('focused', False):
                return monitor['width'], monitor['height']
        
        # Fallback au premier moniteur
        return monitors[0]['width'], monitors[0]['height']
    
    def analyze_tiled_layout(self, windows):
        """Analyse la disposition tiled actuelle pour la reproduire"""
        if not windows:
            return []
        
        print(f"🔍 Analyse de {len(windows)} fenêtres:")
        for i, window in enumerate(windows):
            print(f"  {i+1}. {window.title[:30]} - {window.x},{window.y} ({window.width}x{window.height})")
        
        # Trier par position pour détecter les colonnes
        sorted_windows = sorted(windows, key=lambda w: (w.x, w.y))
        
        # Détecter les colonnes (tolerance de 50px pour position X similaire)
        columns = []
        tolerance = 50
        
        for window in sorted_windows:
            # Trouver la colonne existante ou créer une nouvelle
            placed = False
            for column in columns:
                if abs(window.x - column[0].x) <= tolerance:
                    column.append(window)
                    placed = True
                    break
            
            if not placed:
                columns.append([window])
        
        # Trier chaque colonne par position Y
        for column in columns:
            column.sort(key=lambda w: w.y)
        
        print(f"📊 {len(columns)} colonne(s) détectée(s):")
        for i, col in enumerate(columns):
            print(f"  Colonne {i+1}: {len(col)} fenêtre(s)")
        
        return columns
    
    def calculate_smart_grid(self, windows):
        """Calcule une grille intelligente inspirée d'hyprfloat"""
        screen_width, screen_height = self.get_monitor_size()
        
        # Zone d'overview avec padding
        overview_width = screen_width * self.overview_area_ratio
        overview_height = screen_height * self.overview_area_ratio
        
        start_x = (screen_width - overview_width) // 2
        start_y = (screen_height - overview_height) // 2
        
        # Calculer les dimensions optimales des fenêtres
        num_windows = len(windows)
        
        # Calculer grille optimale (inspiré hyprfloat)
        cols = math.ceil(math.sqrt(num_windows))
        rows = math.ceil(num_windows / cols)
        
        # Dimensions disponibles pour les fenêtres
        available_width = overview_width - (2 * self.grid_padding) - ((cols - 1) * self.window_gap)
        available_height = overview_height - (2 * self.grid_padding) - ((rows - 1) * self.window_gap)
        
        # Calculer taille optimale des fenêtres
        optimal_width = available_width // cols
        optimal_height = available_height // rows
        
        # Appliquer contraintes min/max
        window_width = max(self.min_window_size[0], min(optimal_width, self.max_window_size[0]))
        window_height = max(self.min_window_size[1], min(optimal_height, self.max_window_size[1]))
        
        # Préserver ratio d'aspect si demandé
        if self.preserve_aspect:
            # Utiliser le ratio 16:10 comme référence
            target_ratio = 16 / 10
            current_ratio = window_width / window_height
            
            if current_ratio > target_ratio:
                window_width = int(window_height * target_ratio)
            else:
                window_height = int(window_width / target_ratio)
        
        # Recalculer le centrage avec les vraies dimensions
        total_grid_width = cols * window_width + (cols - 1) * self.window_gap
        total_grid_height = rows * window_height + (rows - 1) * self.window_gap
        
        grid_start_x = start_x + (overview_width - total_grid_width) // 2
        grid_start_y = start_y + (overview_height - total_grid_height) // 2
        
        print(f"⚙️  Grille intelligente: {cols}x{rows} ({num_windows} fenêtres)")
        print(f"⚙️  Zone: {overview_width}x{overview_height} à ({start_x}, {start_y})")
        print(f"⚙️  Fenêtres: {window_width}x{window_height}, gap: {self.window_gap}px")
        print(f"⚙️  Grille: {total_grid_width}x{total_grid_height} à ({grid_start_x}, {grid_start_y})")
        
        # Générer les positions
        positions = []
        for i in range(num_windows):
            col = i % cols
            row = i // cols
            
            x = grid_start_x + col * (window_width + self.window_gap)
            y = grid_start_y + row * (window_height + self.window_gap)
            
            positions.append((x, y, window_width, window_height))
            print(f"    Position {i+1}: ({x}, {y}) {window_width}x{window_height}")
        
        return positions
    
    def create_window_borders(self, positions):
        """Crée des bordures visuelles autour des positions des fenêtres"""
        # TODO: Implémenter avec eww ou avec des fenêtres Hyprland overlay
        print("🎨 Création des bordures visuelles...")
        
        # Afficher les positions avec dimensions
        for i, position in enumerate(positions):
            x, y, width, height = position
            print(f"  Bordure {i+1}: {x},{y} -> {x + width},{y + height} ({width}x{height})")
    
    def create_background_grid(self):
        """Crée le background avec grille transparente"""
        # TODO: Implémenter avec eww ou overlay
        print("🎭 Création du background avec grille...")
        
        screen_width, screen_height = self.get_monitor_size()
        overview_width = screen_width * self.overview_area_ratio
        overview_height = screen_height * self.overview_area_ratio
        
        start_x = (screen_width - overview_width) // 2
        start_y = (screen_height - overview_height) // 2
        
        print(f"  Background: {overview_width}x{overview_height} à ({start_x}, {start_y})")
    
    def save_window_states(self, windows):
        """Sauvegarde l'état actuel des fenêtres"""
        states = {}
        for window in windows:
            states[window.address] = {
                'x': window.x, 'y': window.y,
                'width': window.width, 'height': window.height,
                'floating': window.floating, 'workspace': window.workspace
            }
        
        with open(self.state_file, 'w') as f:
            json.dump(states, f, indent=2)
    
    def enter_visual_overview(self, workspace_id=None):
        """Entre en mode overview visuel"""
        if workspace_id is None:
            workspace_id = self.hypr.get_active_workspace()
        
        print(f"🚀 === DÉBUT OVERVIEW VISUEL WORKSPACE {workspace_id} ===")
        
        # Actualiser les données
        self.hypr.refresh_data()
        
        # Récupérer toutes les fenêtres du workspace
        windows = [w for w in self.hypr.get_windows_by_workspace(workspace_id) 
                  if w.workspace > 0]  # Exclure workspaces spéciaux
        
        if not windows:
            print("📭 Aucune fenêtre trouvée")
            return
        
        # Option 1: Grille intelligente (comme hyprfloat)
        smart_positions = self.calculate_smart_grid(windows)
        
        # Option 2: Préserver disposition tiled
        window_columns = self.analyze_tiled_layout(windows)
        
        # Pour l'instant, utiliser la grille intelligente
        positions = smart_positions
        
        # Créer les éléments visuels
        self.create_background_grid()
        self.create_window_borders(positions)
        
        # Sauvegarder l'état
        self.save_window_states(windows)
        
        # Appliquer les nouvelles positions (grille intelligente)
        print("🎬 Application des transformations:")
        for i, (window, position) in enumerate(zip(windows, positions)):
            x, y, width, height = position
            print(f"  {i+1}. {window.title[:25]} -> {x},{y} ({width}x{height})")
            
            # Passer en floating si nécessaire
            if not window.floating:
                self.hypr.toggle_floating(window.address)
            
            # Redimensionner et positionner
            self.hypr.resize_window(window.address, width, height)
            self.hypr.move_window(window.address, x, y)
        
        print("✨ Overview visuel activé !")
        print("🏁 === FIN OVERVIEW VISUEL ===")


def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Visual Overview Mode pour Hyprland')
    parser.add_argument('--toggle', action='store_true', help='Basculer le mode overview')
    parser.add_argument('--workspace', type=int, help='Workspace spécifique')
    
    args = parser.parse_args()
    
    overview = VisualOverview()
    
    if args.toggle:
        # Pour l'instant, juste entrer en mode overview
        # TODO: implémenter la détection et la sortie
        overview.enter_visual_overview(args.workspace)
    else:
        print("Usage: --toggle pour basculer le mode overview")


if __name__ == "__main__":
    main()