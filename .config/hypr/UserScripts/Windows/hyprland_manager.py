#!/usr/bin/env python3
"""
Hyprland Window Manager
Un réorganiseur de fenêtres pour Hyprland
"""

import json
import subprocess
from typing import List, Optional
from dataclasses import dataclass


@dataclass
class Window:
    """Représente une fenêtre Hyprland"""
    address: str
    title: str
    class_name: str
    workspace: int
    x: int
    y: int
    width: int
    height: int
    floating: bool
    monitor: int
    pid: int


@dataclass
class Workspace:
    """Représente un workspace Hyprland"""
    id: int
    name: str
    monitor: int
    windows: int
    has_fullscreen: bool


class HyprlandManager:
    """Gestionnaire principal pour interagir avec Hyprland"""
    
    def __init__(self):
        self.windows: List[Window] = []
        self.workspaces: List[Workspace] = []
        self.refresh_data()
    
    def run_hyprctl(self, command: str) -> str:
        """Exécute une commande hyprctl et retourne le résultat"""
        try:
            result = subprocess.run(
                ['hyprctl', *command.split()],
                capture_output=True,
                text=True,
                check=True
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            print(f"Erreur hyprctl: {e}")
            return ""
    
    def refresh_data(self):
        """Met à jour les données des fenêtres et workspaces"""
        self.windows = self._get_windows()
        self.workspaces = self._get_workspaces()
    
    def _get_windows(self) -> List[Window]:
        """Récupère la liste des fenêtres"""
        output = self.run_hyprctl('clients -j')
        if not output:
            return []
        
        windows = []
        try:
            clients_data = json.loads(output)
            for client in clients_data:
                window = Window(
                    address=client.get('address', ''),
                    title=client.get('title', ''),
                    class_name=client.get('class', ''),
                    workspace=client.get('workspace', {}).get('id', 0),
                    x=client.get('at', [0, 0])[0],
                    y=client.get('at', [0, 0])[1],
                    width=client.get('size', [0, 0])[0],
                    height=client.get('size', [0, 0])[1],
                    floating=client.get('floating', False),
                    monitor=client.get('monitor', 0),
                    pid=client.get('pid', 0)
                )
                windows.append(window)
        except json.JSONDecodeError:
            print("Erreur lors du parsing des données des fenêtres")
        
        return windows
    
    def _get_workspaces(self) -> List[Workspace]:
        """Récupère la liste des workspaces"""
        output = self.run_hyprctl('workspaces -j')
        if not output:
            return []
        
        workspaces = []
        try:
            workspaces_data = json.loads(output)
            for ws in workspaces_data:
                workspace = Workspace(
                    id=ws.get('id', 0),
                    name=ws.get('name', ''),
                    monitor=ws.get('monitorID', 0),
                    windows=ws.get('windows', 0),
                    has_fullscreen=ws.get('hasfullscreen', False)
                )
                workspaces.append(workspace)
        except json.JSONDecodeError:
            print("Erreur lors du parsing des données des workspaces")
        
        return workspaces
    
    def move_window_to_workspace(self, window_address: str, workspace_id: int):
        """Déplace une fenêtre vers un workspace spécifique"""
        self.run_hyprctl(f'dispatch movetoworkspace {workspace_id},address:{window_address}')
    
    def resize_window(self, window_address: str, width: int, height: int):
        """Redimensionne une fenêtre"""
        self.run_hyprctl(f'dispatch resizewindowpixel exact {width} {height},address:{window_address}')
    
    def move_window(self, window_address: str, x: int, y: int):
        """Déplace une fenêtre à une position spécifique"""
        self.run_hyprctl(f'dispatch movewindowpixel exact {x} {y},address:{window_address}')
    
    def focus_window(self, window_address: str):
        """Met le focus sur une fenêtre"""
        self.run_hyprctl(f'dispatch focuswindow address:{window_address}')
    
    def toggle_floating(self, window_address: str):
        """Bascule le mode floating d'une fenêtre"""
        self.run_hyprctl(f'dispatch togglefloating address:{window_address}')
    
    def get_windows_by_workspace(self, workspace_id: int) -> List[Window]:
        """Retourne les fenêtres d'un workspace spécifique"""
        return [w for w in self.windows if w.workspace == workspace_id]
    
    def get_active_workspace(self) -> Optional[int]:
        """Retourne l'ID du workspace actif"""
        output = self.run_hyprctl('activeworkspace -j')
        if output:
            try:
                data = json.loads(output)
                return data.get('id', None)
            except json.JSONDecodeError:
                pass
        return None
    
    def list_windows_formatted(self) -> str:
        """Retourne une liste formatée des fenêtres"""
        result = []
        for i, window in enumerate(self.windows):
            floating_str = "🔵" if window.floating else "🟦"
            result.append(
                f"{i+1:2d}. {floating_str} [{window.workspace:2d}] {window.class_name:15s} - {window.title[:50]}"
            )
        return "\n".join(result)
    
    def list_workspaces_formatted(self) -> str:
        """Retourne une liste formatée des workspaces"""
        result = []
        for ws in self.workspaces:
            if ws.id > 0:  # Ignore les workspaces spéciaux
                result.append(f"Workspace {ws.id:2d}: {ws.windows} fenêtre(s)")
        return "\n".join(result)