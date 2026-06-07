#!/usr/bin/env python3
"""
OpenRGB Controller avec modes multiples
Contrôleur RGB avec différents modes d'animation
"""

from openrgb import OpenRGBClient
from openrgb.utils import RGBColor, DeviceType
import time, json, os, threading, random, sys, math
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import socket

SCRIPT_PATH = os.path.expanduser('~/.config/quickshell/rgb-launcher/modules/script')

class ZoneDevice:
    """Wrapper pour traiter une zone de carte mère comme un device indépendant"""
    def __init__(self, device, zone_index):
        self.device = device
        self.zone_index = zone_index
        self.zone = device.zones[zone_index]
        self.name = f"{device.name} / {self.zone.name}"
        self.leds = self.zone.leds
        self.modes = device.modes

    def set_color(self, color):
        self.device.zones[self.zone_index].set_color(color)

    def set_colors(self, colors):
        self.device.zones[self.zone_index].set_colors(colors)

    def set_mode(self, mode):
        self.device.set_mode(mode)

class FanSyncGroup:
    """Synchronise tous les fans sur un clock partagé avec décalage de phase"""
    def __init__(self, node_channel, mobo_fan, leds_per_fan=8):
        self.node_channel = node_channel  # ZoneDevice Channel 1
        self.mobo_fan = mobo_fan
        self.leds_per_fan = leds_per_fan
        self.node_fan_count = len(node_channel.leds) // leds_per_fan  # 3
        self.total_fans = self.node_fan_count + 1  # 4
        # Phases réparties : [0.0, 0.25, 0.50, 0.75]
        self.phases = [i / self.total_fans for i in range(self.total_fans)]

    def render(self, color_func, apply_brightness):
        """
        color_func(led_index, phase, t) -> RGBColor
        Même t pour tous les fans = sync parfaite
        """
        t = time.time()

        # Node Pro — 3 fans en un seul appel set_colors (24 LEDs)
        node_colors = []
        for fan_i in range(self.node_fan_count):
            phase = self.phases[fan_i]
            for led_i in range(self.leds_per_fan):
                node_colors.append(apply_brightness(color_func(led_i, phase, t)))
        self.node_channel.set_colors(node_colors)

        # RS120 — même t, phase décalée
        phase = self.phases[self.total_fans - 1]
        mobo_colors = [
            apply_brightness(color_func(led_i, phase, t))
            for led_i in range(self.leds_per_fan)
        ]
        self.mobo_fan.set_colors(mobo_colors)

def wait_for_openrgb(host="127.0.0.1", port=6742, timeout=30, interval=0.5):
    """Attend qu'OpenRGB soit prêt en vérifiant la disponibilité du port SDK."""
    print(f"⏳ Attente d'OpenRGB sur {host}:{port}...")
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            with socket.create_connection((host, port), timeout=1):
                print("✅ OpenRGB est prêt !")
                return True
        except (ConnectionRefusedError, OSError):
            time.sleep(interval)
    print(f"❌ OpenRGB non disponible après {timeout}s, on continue quand même...")
    return False

class OpenRGBController:
    def __init__(self):
        self.WALLUST_PATH = os.path.expanduser(f'{SCRIPT_PATH}/wal_rgb.json')
        self.PORT_FILE = os.path.expanduser(f'{SCRIPT_PATH}/current_port.txt')
        self.STATUS_FILE = os.path.expanduser(f'{SCRIPT_PATH}/sequence.txt')
        self.BRIGHTNESS_FILE = os.path.expanduser(f'{SCRIPT_PATH}/brightness.txt')
        self.DEFAULT_PORT = 6742
        
        # État du contrôleur
        self.current_mode = "off"
        self.running = False
        self.animation_thread = None
        
        # Connexion OpenRGB
        self.setup_openrgb()
        
        # Chargement des couleurs
        self.load_colors()
        
        # Variables pour optimisation
        self.last_colors = {}
        self.last_modes = {}
        self.PREFERRED_MODES = ["Direct", "Static"]
    
    def get_openrgb_port(self):
        """Récupère le port OpenRGB depuis le fichier de config"""
        try:
            if os.path.exists(self.PORT_FILE):
                with open(self.PORT_FILE, 'r') as f:
                    port = int(f.read().strip())
                    print(f"🔌 Port OpenRGB: {port}")
                    return port
            else:
                print(f"📄 Port par défaut: {self.DEFAULT_PORT}")
                return self.DEFAULT_PORT
        except (FileNotFoundError, ValueError) as e:
            print(f"⚠️ Erreur lecture port: {e}")
            return self.DEFAULT_PORT
    
    def force_zone_sizes(self):
        try:
            # Node Pro — Channel 1 : forcer 24 LEDs
            if len(self.node_pro.zones[0].leds) != 24:
                print(f"⚠️ Node Channel 1: {len(self.node_pro.zones[0].leds)} LEDs détectées, resize → 24")
                self.node_pro.zones[0].resize(24)
                time.sleep(0.5)
                # Reconnexion pour rafraîchir
                self.client = OpenRGBClient()
                self.devices = self.client.devices
                self.node_pro = next(d for d in self.devices if "Corsair Lighting Node Pro" in d.name)
                self.mobo_device = next(d for d in self.devices if d.type == DeviceType.MOTHERBOARD)
                time.sleep(0.5)
            else:
                print(f"✅ Node Channel 1: 24 LEDs OK")

            # Mobo D_LED — forcer 8 LEDs
            if len(self.mobo_device.zones[1].leds) != 8:
                print(f"⚠️ D_LED: {len(self.mobo_device.zones[1].leds)} LEDs détectées, resize → 8")
                self.mobo_device.zones[1].resize(8)
                time.sleep(0.5)
                self.client = OpenRGBClient()
                self.devices = self.client.devices
                self.node_pro = next(d for d in self.devices if "Corsair Lighting Node Pro" in d.name)
                self.mobo_device = next(d for d in self.devices if d.type == DeviceType.MOTHERBOARD)
                time.sleep(0.5)
            else:
                print(f"✅ D_LED: 8 LEDs OK")

            # Recharge les références après resize
            self.node_channel1 = ZoneDevice(self.node_pro, 0)
            self.mobo_fan = ZoneDevice(self.mobo_device, 1)
            self.mobo_leds = ZoneDevice(self.mobo_device, 2)
            self.fan_sync = FanSyncGroup(self.node_channel1, self.mobo_fan, leds_per_fan=8)

            print(f"✅ Zones après resize:")
            print(f"   Node Channel 1 : {len(self.node_channel1.leds)} LEDs")
            print(f"   D_LED (RS120)  : {len(self.mobo_fan.leds)} LEDs")
            print(f"🌀 FanSyncGroup   : {len(self.fan_sync.phases)} fans synchronisés")
            for i, phase in enumerate(self.fan_sync.phases):
                print(f"   Fan #{i+1} → phase {phase:.2f}")

        except Exception as e:
            print(f"❌ Erreur force_zone_sizes: {e}")
            sys.exit(1)

    def setup_openrgb(self):
        """Établit la connexion OpenRGB"""
        openrgb_port = self.get_openrgb_port()
        try:
            if openrgb_port != self.DEFAULT_PORT:
                self.client = OpenRGBClient(port=openrgb_port)
            else:
                self.client = OpenRGBClient()
            print(f"✅ Connexion OpenRGB sur port {openrgb_port}")
        except Exception as e:
            print(f"❌ Erreur connexion sur port {openrgb_port}: {e}")
            try:
                self.client = OpenRGBClient()
                print("✅ Connexion sur port par défaut")
            except Exception as e2:
                print(f"💥 Erreur critique: {e2}")
                sys.exit(1)

        # Identification des périphériques
        self.devices = self.client.devices
        print("🔍 Périphériques disponibles:")
        for i, device in enumerate(self.devices):
            print(f"   {i}: {device.name} (Type: {device.type})")

        try:
            self.ram_devices = [d for d in self.devices if "Corsair Vengeance Pro RGB" in d.name]
            self.node_pro = next(d for d in self.devices if "Corsair Lighting Node Pro" in d.name)
            self.mobo_device = next(d for d in self.devices if d.type == DeviceType.MOTHERBOARD)

            # Zones carte mère
            self.mobo_fan  = ZoneDevice(self.mobo_device, 1)  # D_LED — RS120 — 8 LEDs
            self.mobo_leds = ZoneDevice(self.mobo_device, 2)  # LEDs intégrées — 4 LEDs
            self.mobo = self.mobo_device                      # compat set_static global
            print(f"💡 RS120 (D_LED)  : {len(self.mobo_fan.leds)} LEDs")
            print(f"💡 Mobo LEDs      : {len(self.mobo_leds.leds)} LEDs")

            # Node Pro — Channel 1 : 2× ML140 + 1× AF120 = 24 LEDs
            self.node_channel1 = ZoneDevice(self.node_pro, 0)
            print(f"💡 Node Channel 1 : {len(self.node_channel1.leds)} LEDs "
                f"({len(self.node_channel1.leds) // 8} fans × 8 LEDs)")

            self.force_zone_sizes()
            print("✅ Zones forcées")

            # Groupe de sync : ML140×2 + AF120 + RS120 = 4 fans
            self.fan_sync = FanSyncGroup(self.node_channel1, self.mobo_fan, leds_per_fan=8)
            print(f"🌀 FanSyncGroup   : {self.fan_sync.total_fans} fans synchronisés")
            for i, phase in enumerate(self.fan_sync.phases):
                print(f"   Fan #{i+1} → phase {phase:.2f}")

            # Détection GPU
            self.gpu = None
            gpu_candidates = [d for d in self.devices if d.type == DeviceType.GPU]
            if gpu_candidates:
                self.gpu = gpu_candidates[0]
                print(f"🎮 GPU détectée par type: {self.gpu.name}")
            if not self.gpu:
                gpu_keywords = ["NVIDIA", "AMD", "Radeon", "GeForce", "RTX", "GTX", "RX"]
                for device in self.devices:
                    if any(k.lower() in device.name.lower() for k in gpu_keywords):
                        self.gpu = device
                        print(f"🎮 GPU détectée par nom: {self.gpu.name}")
                        break

            print(f"🎮 Périphériques détectés:")
            print(f"   - RAM       : {len(self.ram_devices)} modules")
            print(f"   - Node Pro  : {self.node_pro.name}")
            print(f"   - Carte mère: {self.mobo.name}")
            if self.gpu:
                print(f"   - GPU       : {self.gpu.name}")
                print(f"     Modes    : {[m.name for m in self.gpu.modes]}")
                print(f"     LEDs     : {len(self.gpu.leds)}")
            else:
                print("   - GPU: Non détectée")

        except StopIteration:
            print("❌ Périphérique manquant")
            for i, device in enumerate(self.devices):
                print(f"   {i}: {device.name} (Type: {device.type})")
            sys.exit(1)
    
    def get_all_devices(self):
        devices = self.ram_devices + [self.node_pro, self.mobo_fan, self.mobo_leds]
        if self.gpu:
            devices.append(self.gpu)
        return devices
    
    def hex_to_rgbcolor(self, hex_code):
        """Convertit hex en RGBColor"""
        hex_code = hex_code.lstrip('#')
        r = int(hex_code[0:2], 16)
        g = int(hex_code[2:4], 16)
        b = int(hex_code[4:6], 16)
        return RGBColor(r, g, b)
    
    def load_colors(self):
        """Charge les couleurs depuis wallust"""
        try:
            with open(self.WALLUST_PATH) as f:
                wal = json.load(f)
            colors = [self.hex_to_rgbcolor(wal['colors'][f'color{i}']) for i in range(16)]
            
            # Attribution des couleurs nommées
            self.colorA = colors[0]   # Couleur principale
            self.colorB = colors[2]   # Accent 1
            self.colorC = colors[7]   # Accent 2
            self.colorD = colors[12]  # Accent 3
            self.colorE = colors[4]   # Accent 4
            self.colorF = colors[15]  # Couleur claire
            self.colorG = colors[13]  # Couleur moyenne
            self.colorH = colors[1]   # Couleur sombre
            self.colorI = colors[5]   # Accent 5a
            self.colorJ = colors[14]   # Accent 5b
            self.colorM = colors[8]
            
            print("🎨 Couleurs chargées depuis wallust")
        except Exception as e:
            print(f"⚠️ Erreur chargement couleurs: {e}")
            # Couleurs par défaut
            self.colorA = RGBColor(255, 0, 0)
            self.colorB = RGBColor(0, 255, 0)
            self.colorC = RGBColor(0, 0, 255)
            self.colorD = RGBColor(255, 255, 0)
            self.colorE = RGBColor(255, 0, 255)
            self.colorF = RGBColor(255, 255, 255)
            self.colorG = RGBColor(128, 128, 128)
            self.colorH = RGBColor(64, 64, 64)
            self.colorI = RGBColor(0, 255, 255)
            self.colorJ = RGBColor(255, 165, 0)
    
    def get_brightness(self):
        """Récupère la luminosité actuelle (0.0 à 1.0)"""
        try:
            if os.path.exists(self.BRIGHTNESS_FILE):
                with open(self.BRIGHTNESS_FILE, 'r') as f:
                    brightness = int(f.read().strip())
                    return max(0, min(100, brightness)) / 100.0
        except:
            pass
        return 1.0

    def set_best_mode(self, device):
        """Active le meilleur mode disponible"""
        for mode_name in self.PREFERRED_MODES:
            for mode in device.modes:
                if mode.name.lower() == mode_name.lower():
                    try:
                        if self.last_modes.get(device) != mode.name:
                            device.set_mode(mode)
                            self.last_modes[device] = mode.name
                        return
                    except Exception as e:
                        print(f"⚠️ Mode '{mode_name}' échoué sur {device.name}: {e}")
    
    def smart_set_color(self, device, color):
        """Optimise les changements de couleur"""
        adjusted_color = self.apply_brightness(color)
        if self.last_colors.get(device) != adjusted_color:
            device.set_color(adjusted_color)
            self.last_colors[device] = adjusted_color
    
    def set_static(self, device, color):
        """Applique une couleur statique"""
        self.set_best_mode(device)
        self.smart_set_color(device, color)
    
    def interpolate_color(self, color1, color2, factor):
        """Interpolation entre deux couleurs"""
        r = int(color1.red + (color2.red - color1.red) * factor)
        g = int(color1.green + (color2.green - color1.green) * factor)
        b = int(color1.blue + (color2.blue - color1.blue) * factor)
        return RGBColor(r, g, b)
    
    def smooth_transition(self, device, start_color, end_color, duration=1.0, steps=20):
        """Transition douce entre couleurs"""
        self.set_best_mode(device)
        step_time = duration / steps
        
        for step in range(steps + 1):
            if not self.running:
                break
            factor = step / steps
            current_color = self.interpolate_color(start_color, end_color, factor)
            adjusted_color = self.apply_brightness(current_color)
            device.set_color(adjusted_color)
            time.sleep(step_time)
    
    def base_with_active_led(self, device, base_color, active_color, duration=50, speed=0.5, leds_per_fan=8):
        """Animation LED aléatoire par ventilateur"""
        self.set_best_mode(device)
        led_count = len(device.leds)
        start_time = time.time()
        
        fan_count = max(1, led_count // leds_per_fan)
        
        while time.time() - start_time < duration and self.running:
            colors = [base_color] * led_count
            
            for fan_index in range(fan_count):
                fan_start = fan_index * leds_per_fan
                fan_end = min(fan_start + leds_per_fan, led_count)
                
                if fan_end > fan_start:
                    active_led_index = random.randint(fan_start, fan_end - 1)
                    colors[active_led_index] = active_color
            
            adjusted_colors = [self.apply_brightness(c) for c in colors]
            device.set_colors(adjusted_colors)
            time.sleep(speed)
    
    def fans_base_with_active(self, base_color, active_color, duration=20, speed=0.5):
        """Animation LED aléatoire synchronisée sur tous les fans"""
        self.fan_sync.node_channel.device.set_mode(
            next(m for m in self.fan_sync.node_channel.device.modes if m.name == "Direct")
        )
        start_time = time.time()

        while time.time() - start_time < duration and self.running:
            # Un active_led aléatoire par fan, calculé au même instant
            active_leds = [random.randint(0, self.fan_sync.leds_per_fan - 1)
                        for _ in range(self.fan_sync.total_fans)]

            def color_func(led_i, phase, t):
                # Quel fan ? On le retrouve depuis la phase
                fan_i = self.fan_sync.phases.index(phase)
                return active_color if led_i == active_leds[fan_i] else base_color

            self.fan_sync.render(color_func, self.apply_brightness)
            time.sleep(speed)

    def fans_wave(self, color_a, color_b, speed=2.0):
        """Vague de couleur synchronisée avec décalage de phase entre fans"""
        def color_func(led_i, phase, t):
            # Phase globale + décalage du fan + position LED
            angle = (t * speed + phase + led_i / self.fan_sync.leds_per_fan) * 2 * math.pi
            factor = (math.sin(angle) + 1) / 2
            return self.interpolate_color(color_a, color_b, factor)

        self.fan_sync.render(color_func, self.apply_brightness)

    def fans_spin(self, colors_list, speed=1.5):
        """Rotation simulée — la LED brillante tourne sur chaque fan"""
        def color_func(led_i, phase, t):
            # Position de la LED "active" qui tourne
            active_pos = (t * speed * self.fan_sync.leds_per_fan + phase * self.fan_sync.leds_per_fan) \
                        % self.fan_sync.leds_per_fan
            distance = min(
                abs(led_i - active_pos),
                self.fan_sync.leds_per_fan - abs(led_i - active_pos)
            )
            if distance < 1:
                return colors_list[0]  # LED principale
            elif distance < 2:
                return self.interpolate_color(colors_list[0], colors_list[1], distance)
            else:
                return colors_list[-1]  # fond

        self.fan_sync.render(color_func, self.apply_brightness)

    def mode_off(self):
        """Mode éteint - toutes les lumières noires"""
        print("🌑 Mode OFF")
        black = RGBColor(0, 0, 0)
        for device in self.get_all_devices():
            self.set_static(device, black)
    
    def mode_sequence_1(self):
        """Séquence 1 - Animation originale avec transitions fluides"""
        print("🌈 Séquence 1")

        while self.running and self.current_mode == "sequence_1":

            # Phase 1
            print("🌈 Phase 1")
            self.set_static(self.mobo_leds, self.colorG)
            if self.gpu:
                self.smooth_transition(self.gpu,
                    self.last_colors.get(self.gpu, RGBColor(0,0,0)), self.colorI, 1.0)

            start = time.time()
            while time.time() - start < 20 and self.running and self.current_mode == "sequence_1":
                self.fans_base_with_active(self.colorA, self.colorJ)
                time.sleep(0.5)

            if not self.running or self.current_mode != "sequence_1":
                break

            # Phase 2
            print("🌈 Phase 2")
            self.set_static(self.mobo_leds, self.colorD)
            if self.gpu:
                self.set_static(self.gpu, self.colorH)

            start = time.time()
            while time.time() - start < 20 and self.running and self.current_mode == "sequence_1":
                self.fans_base_with_active(self.colorG, self.colorB)
                time.sleep(0.5)

            if not self.running or self.current_mode != "sequence_1":
                break

            # Phase 3
            print("🌈 Phase 3")
            self.set_static(self.mobo_leds, self.colorE)
            if self.gpu:
                self.set_static(self.gpu, self.colorE)

            start = time.time()
            while time.time() - start < 20 and self.running and self.current_mode == "sequence_1":
                self.fans_base_with_active(self.colorC, self.colorI)
                time.sleep(0.5)

            if not self.running or self.current_mode != "sequence_1":
                break

            # Phase 4
            print("🌈 Phase 4")
            self.set_static(self.mobo_leds, self.colorF)
            if self.gpu:
                self.set_static(self.gpu, self.colorB)

            start = time.time()
            while time.time() - start < 20 and self.running and self.current_mode == "sequence_1":
                self.fans_base_with_active(self.colorD, self.colorI)
                time.sleep(0.5)
    
    def mode_sequence_2(self):
        """Séquence 2 - Vagues de couleur"""
        print("🌊 Séquence 2")
        colors_cycle = [self.colorA, self.colorB, self.colorC, self.colorD, self.colorE]
        
        while self.running and self.current_mode == "sequence_2":
            for color in colors_cycle:
                if not self.running or self.current_mode != "sequence_2":
                    break
                    
                # Transition douce sur tous les périphériques (y compris GPU)
                threads = []
                all_devices = self.get_all_devices()
                for device in all_devices:
                    thread = threading.Thread(target=self.smooth_transition, 
                                            args=(device, self.last_colors.get(device, RGBColor(0,0,0)), color, 2.0))
                    threads.append(thread)
                    thread.start()
                
                for thread in threads:
                    thread.join()
                
                time.sleep(3)
    
    def mode_sequence_3(self):
        """Séquence 3 - Respiration synchronisée"""
        print("💨 Séquence 3")
        
        while self.running and self.current_mode == "sequence_3":
            # Respiration montante
            for i in range(0, 256, 5):
                if not self.running or self.current_mode != "sequence_3":
                    break
                intensity = i / 255.0
                
                breath_color = RGBColor(
                    int((self.colorA.red + self.colorD.red) / 2 * intensity),
                    int((self.colorB.green + self.colorE.green) / 2 * intensity),
                    int((self.colorC.blue + self.colorF.blue) / 2 * intensity)
                )
                
                for device in self.get_all_devices():
                    self.set_static(device, breath_color)
                time.sleep(0.02)
            
            # Respiration descendante
            for i in range(255, 0, -5):
                if not self.running or self.current_mode != "sequence_3":
                    break
                intensity = i / 255.0
                
                breath_color = RGBColor(
                    int((self.colorA.red + self.colorD.red) / 2 * intensity),
                    int((self.colorB.green + self.colorE.green) / 2 * intensity),
                    int((self.colorC.blue + self.colorF.blue) / 2 * intensity)
                )
                
                for device in self.get_all_devices():
                    self.set_static(device, breath_color)
                time.sleep(0.02)
    
    def mode_sequence_4(self):
        """Séquence 4 - Cyberpunk Matrix avec effets néon et balayages"""
        print("🌆 Séquence 4 - Cyberpunk Mode")

        neon_primary  = self.colorJ
        neon_secondary = self.colorB
        matrix_green  = self.colorI
        danger_red    = self.colorH
        shadow_color  = self.colorA
        highlight     = self.colorF

        while self.running and self.current_mode == "sequence_4":

            # ── Phase 1: Data Stream ──────────────────────────────────────────
            print("🌆 Phase 1: Data Stream")
            self.set_static(self.mobo_leds, shadow_color)
            if self.gpu:
                self.set_static(self.gpu, self.interpolate_color(shadow_color, neon_primary, 0.3))

            # RAM en data stream classique (pas des fans)
            for ram in self.ram_devices:
                self.set_best_mode(ram)

            for wave_cycle in range(3):
                if not self.running or self.current_mode != "sequence_4":
                    break

                # RAM — balayage indépendant
                for ram in self.ram_devices:
                    led_count = len(ram.leds)
                    for position in range(led_count + 8):
                        if not self.running or self.current_mode != "sequence_4":
                            break
                        colors = [shadow_color] * led_count
                        for i in range(max(0, position-6), min(led_count, position-2)):
                            colors[i] = self.interpolate_color(shadow_color, matrix_green, 0.3)
                        for i in range(max(0, position-2), min(led_count, position)):
                            colors[i] = matrix_green
                        if 0 <= position < led_count:
                            colors[position] = neon_primary
                        ram.set_colors(colors)
                        time.sleep(0.06)

                # Fans — data stream synchronisé via fan_sync
                # Chaque fan a sa propre tête de lecture décalée par phase
                stream_duration = 2.0
                stream_start = time.time()
                while time.time() - stream_start < stream_duration:
                    if not self.running or self.current_mode != "sequence_4":
                        break

                    def data_stream(led_i, phase, t):
                        # Position de la tête décalée par fan
                        speed = 6.0  # LEDs par seconde
                        head = (t * speed + phase * self.fan_sync.leds_per_fan) \
                            % (self.fan_sync.leds_per_fan + 8)
                        distance = head - led_i
                        if 0 <= distance < 1:
                            return neon_primary
                        elif 1 <= distance < 3:
                            return matrix_green
                        elif 3 <= distance < 7:
                            return self.interpolate_color(shadow_color, matrix_green, 0.3)
                        else:
                            return shadow_color

                    self.fan_sync.render(data_stream, self.apply_brightness)
                    time.sleep(0.05)

            if not self.running or self.current_mode != "sequence_4":
                break

            # ── Phase 2: Neon Glitch ──────────────────────────────────────────
            print("🌆 Phase 2: Neon Glitch")
            glitch_colors = [danger_red, neon_primary, matrix_green, highlight]

            for glitch_round in range(8):
                if not self.running or self.current_mode != "sequence_4":
                    break

                # RAM — glitch per-LED
                for ram in self.ram_devices:
                    self.set_best_mode(ram)
                    colors = [random.choice(glitch_colors) if random.random() < 0.4
                            else shadow_color for _ in range(len(ram.leds))]
                    ram.set_colors([self.apply_brightness(c) for c in colors])

                # Fans — glitch synchronisé, chaque LED tire au sort
                # mais toutes calculées au même instant
                glitch_snapshot = [random.random() < 0.4 for _ in
                                range(self.fan_sync.total_fans * self.fan_sync.leds_per_fan)]

                def neon_glitch(led_i, phase, t):
                    fan_i = round(phase * self.fan_sync.total_fans)
                    idx = fan_i * self.fan_sync.leds_per_fan + led_i
                    if idx < len(glitch_snapshot) and glitch_snapshot[idx]:
                        return random.choice(glitch_colors)
                    return shadow_color

                self.fan_sync.render(neon_glitch, self.apply_brightness)

                # Mobo LEDs et GPU
                if random.random() < 0.6:
                    self.set_static(self.mobo_leds, random.choice(glitch_colors))
                if self.gpu and random.random() < 0.6:
                    self.set_static(self.gpu, random.choice(glitch_colors))

                time.sleep(0.1)

                # Reset tout
                for ram in self.ram_devices:
                    ram.set_colors([self.apply_brightness(shadow_color)] * len(ram.leds))

                def reset_fans(led_i, phase, t):
                    return shadow_color
                self.fan_sync.render(reset_fans, self.apply_brightness)
                self.set_static(self.mobo_leds, shadow_color)

                time.sleep(0.05)

            if not self.running or self.current_mode != "sequence_4":
                break

            # ── Phase 3: Cyberpunk Pulse ──────────────────────────────────────
            print("🌆 Phase 3: Cyberpunk Pulse")
            for pulse_cycle in range(2):
                if not self.running or self.current_mode != "sequence_4":
                    break

                # Montée
                for intensity in range(0, 256, 12):
                    if not self.running or self.current_mode != "sequence_4":
                        break

                    factor = intensity / 255.0
                    pulse_color = self.interpolate_color(shadow_color, neon_primary, factor)

                    self.set_static(self.mobo_leds,
                        self.interpolate_color(shadow_color, neon_secondary, factor))
                    if self.gpu:
                        self.set_static(self.gpu,
                            self.interpolate_color(shadow_color, highlight, factor))

                    for ram in self.ram_devices:
                        self.set_static(ram, pulse_color)

                    # Pulse fans — légère variation de phase entre fans pour un effet vague
                    def pulse_wave(led_i, phase, t):
                        phase_offset = math.sin(phase * 2 * math.pi) * 0.08
                        adjusted = max(0.0, min(1.0, factor + phase_offset))
                        return self.interpolate_color(shadow_color, neon_primary, adjusted)

                    self.fan_sync.render(pulse_wave, self.apply_brightness)
                    time.sleep(0.03)

                time.sleep(0.2)

                # Descente
                for intensity in range(255, 0, -15):
                    if not self.running or self.current_mode != "sequence_4":
                        break

                    factor = intensity / 255.0
                    pulse_color = self.interpolate_color(shadow_color, neon_primary, factor)

                    for ram in self.ram_devices:
                        self.set_static(ram, pulse_color)
                    self.set_static(self.mobo_leds, pulse_color)
                    if self.gpu:
                        self.set_static(self.gpu, pulse_color)

                    def pulse_down(led_i, phase, t):
                        return self.interpolate_color(shadow_color, neon_primary, factor)

                    self.fan_sync.render(pulse_down, self.apply_brightness)
                    time.sleep(0.02)

            time.sleep(0.5)
    
    def mode_sequence_5(self):
        """Séquence 5 - Matrix Digital Rain avec effets de code défilant"""
        print("💚 Séquence 5 - Matrix Mode")
        
        matrix_main = self.colorE
        matrix_bright = self.colorF
        matrix_medium = self.colorG
        matrix_dim = self.colorH
        matrix_accent = self.colorI
        glitch_color = self.colorA
        background = RGBColor(0, 0, 0)
        
        cycle_count = 0
        
        while self.running and self.current_mode == "sequence_5":
            cycle_count += 1
            
            # Phase 1: System Boot — tout le monde s'allume progressivement
            print("💚 Phase 1: System Boot")
            boot_colors = [background, matrix_dim, matrix_medium, matrix_main, matrix_bright]
            for boot_color in boot_colors:
                if not self.running or self.current_mode != "sequence_5":
                    break
                # LEDs intégrées et GPU en statique
                self.set_static(self.mobo_leds, boot_color)
                if self.gpu:
                    self.set_static(self.gpu, boot_color)
                # Fan, RAM, Node Pro per-LED uniforme pour le boot
                for device in self.ram_devices + [self.node_pro, self.mobo_fan]:
                    self.set_best_mode(device)
                    device.set_colors([self.apply_brightness(boot_color)] * len(device.leds))
                time.sleep(0.3)
            
            if not self.running or self.current_mode != "sequence_5":
                break
            
            # Phase 2: Digital Rain
            print("💚 Phase 2: Digital Rain")
            for rain_cycle in range(25):
                if not self.running or self.current_mode != "sequence_5":
                    break
                
                # Pulsation mobo LEDs et GPU
                pulse_intensity = (math.sin(rain_cycle * 0.2) + 1) / 2
                mobo_pulse = self.interpolate_color(matrix_dim, matrix_medium, pulse_intensity)
                self.set_static(self.mobo_leds, mobo_pulse)
                if self.gpu:
                    gpu_pulse = self.interpolate_color(matrix_accent, matrix_main, pulse_intensity)
                    self.set_static(self.gpu, gpu_pulse)
                
                # Colonnes de code sur RAM, Node Pro ET fan ARGB
                for device in self.ram_devices + [self.node_pro, self.mobo_fan]:
                    self.set_best_mode(device)
                    led_count = len(device.leds)
                    colors = [background] * led_count
                    
                    # Fan a moins de LEDs donc moins de colonnes
                    columns_count = random.randint(1, 2) if device == self.mobo_fan else random.randint(2, 4)
                    
                    for _ in range(columns_count):
                        column_start = random.randint(0, led_count - 1)
                        column_length = random.randint(2, min(4, led_count))
                        
                        for i in range(column_length):
                            led_pos = (column_start + i) % led_count
                            if i == 0:
                                colors[led_pos] = matrix_bright
                            elif i == 1:
                                colors[led_pos] = matrix_main
                            elif i == 2:
                                colors[led_pos] = matrix_medium
                            else:
                                colors[led_pos] = matrix_dim
                    
                    device.set_colors([self.apply_brightness(c) for c in colors])
                
                time.sleep(0.12)
            
            time.sleep(1)

    def mode_sequence_6(self):
        """Séquence 6 - Aurora Borealis avec vagues ondulantes"""
        print("🌌 Séquence 6 - Aurora Borealis")

        aurora_green  = self.colorI
        aurora_cyan   = self.colorM
        aurora_purple = self.colorE
        aurora_blue   = self.colorC
        aurora_teal   = RGBColor(0, 180, 180)
        dark_bg       = self.colorJ

        while self.running and self.current_mode == "sequence_6":

            # ── Phase 1: Northern Lights Rise ────────────────────────────────
            print("🌌 Phase 1: Northern Lights Rise")
            for intensity in range(0, 256, 8):
                if not self.running or self.current_mode != "sequence_6":
                    break

                # mobo_leds teal, GPU bleu
                mobo_factor = (math.sin(intensity / 30.0) + 1) / 2
                self.set_static(self.mobo_leds,
                    self.interpolate_color(dark_bg, aurora_teal, mobo_factor))
                if self.gpu:
                    gpu_factor = (math.sin(intensity / 25.0 + 1) + 1) / 2
                    self.set_static(self.gpu,
                        self.interpolate_color(dark_bg, aurora_blue, gpu_factor))

                # RAM — vague per-LED indépendante
                for ram in self.ram_devices:
                    self.set_best_mode(ram)
                    colors = []
                    for led_i in range(len(ram.leds)):
                        f = (math.sin((intensity + led_i * 15) / 40.0) + 1) / 2
                        colors.append(self.interpolate_color(dark_bg, aurora_green, f))
                    ram.set_colors([self.apply_brightness(c) for c in colors])

                # Fans — vague synchronisée, chaque fan décalé par phase
                def aurora_rise(led_i, phase, t):
                    # Décalage spatial : phase déplace la vague entre fans
                    offset = phase * self.fan_sync.leds_per_fan * 15
                    f = (math.sin((intensity + led_i * 15 + offset) / 40.0) + 1) / 2
                    return self.interpolate_color(dark_bg, aurora_green, f)

                self.fan_sync.render(aurora_rise, self.apply_brightness)
                time.sleep(0.04)

            if not self.running or self.current_mode != "sequence_6":
                break

            # ── Phase 2: Color Dance ──────────────────────────────────────────
            print("🌌 Phase 2: Color Dance")
            for wave_cycle in range(30):
                if not self.running or self.current_mode != "sequence_6":
                    break

                phase1 = (math.sin(wave_cycle * 0.3) + 1) / 2
                phase2 = (math.sin(wave_cycle * 0.3 + math.pi / 2) + 1) / 2
                phase3 = (math.sin(wave_cycle * 0.3 + math.pi) + 1) / 2

                # mobo_leds cyan-vert, GPU bleu-violet
                self.set_static(self.mobo_leds,
                    self.interpolate_color(aurora_cyan, aurora_green, phase1))
                if self.gpu:
                    self.set_static(self.gpu,
                        self.interpolate_color(aurora_blue, aurora_purple, phase2))

                # RAM — gradient ondulant per-LED
                for i, ram in enumerate(self.ram_devices):
                    self.set_best_mode(ram)
                    colors = []
                    for led_i in range(len(ram.leds)):
                        lp = (phase3 + i * 0.2 + led_i * 0.1) % 1.0
                        colors.append(self.interpolate_color(aurora_green, aurora_purple, lp))
                    ram.set_colors([self.apply_brightness(c) for c in colors])

                # Fans — ondulation continue, chaque fan a sa propre phase
                # qui se propage LED par LED → effet ruban d'aurore qui traverse les 4 fans
                def color_dance(led_i, phase, t):
                    # phase du fan + position LED = position dans le ruban d'aurore
                    lp = (phase3 + phase + led_i / self.fan_sync.leds_per_fan * 0.8) % 1.0
                    return self.interpolate_color(aurora_green, aurora_purple, lp)

                self.fan_sync.render(color_dance, self.apply_brightness)
                time.sleep(0.08)

            if not self.running or self.current_mode != "sequence_6":
                break

            # ── Phase 3: Aurora Curtain ───────────────────────────────────────
            print("🌌 Phase 3: Aurora Curtain")

            # RAM — rideau classique per-device
            for ram in self.ram_devices:
                self.set_best_mode(ram)
                led_count = len(ram.leds)
                for sweep in range(2):
                    if not self.running or self.current_mode != "sequence_6":
                        break
                    for position in range(led_count + 10):
                        if not self.running or self.current_mode != "sequence_6":
                            break
                        colors = [dark_bg] * led_count
                        for led_i in range(led_count):
                            dist = abs(led_i - position)
                            if dist < 5:
                                f = 1.0 - (dist / 5.0)
                                colors[led_i] = self.interpolate_color(
                                    dark_bg,
                                    aurora_green if position % 2 == 0 else aurora_purple, f)
                        ram.set_colors([self.apply_brightness(c) for c in colors])
                        time.sleep(0.06)

            # Fans — rideau synchronisé : la "lumière" traverse les 4 fans en cascade
            # position globale de 0 à (total_fans * leds_per_fan) + marge
            total_leds = self.fan_sync.total_fans * self.fan_sync.leds_per_fan
            curtain_window = 4

            for sweep in range(2):
                if not self.running or self.current_mode != "sequence_6":
                    break

                sweep_color = aurora_green if sweep % 2 == 0 else aurora_purple

                for global_pos in range(total_leds + curtain_window * 2):
                    if not self.running or self.current_mode != "sequence_6":
                        break

                    def aurora_curtain(led_i, phase, t,
                                    gp=global_pos, sc=sweep_color):
                        # Position absolue de cette LED dans le ruban de fans
                        fan_i = round(phase * self.fan_sync.total_fans)
                        abs_pos = fan_i * self.fan_sync.leds_per_fan + led_i
                        dist = abs(abs_pos - gp)
                        if dist < curtain_window:
                            f = 1.0 - (dist / curtain_window)
                            return self.interpolate_color(dark_bg, sc, f)
                        return dark_bg

                    self.fan_sync.render(aurora_curtain, self.apply_brightness)
                    time.sleep(0.05)

            time.sleep(0.5)

    def mode_sequence_7(self):

        storm_dark      = self.colorA
        lightning_white = self.colorF
        lightning_blue  = self.colorJ
        cloud_gray      = self.colorD
        thunder_purple  = self.colorE

        while self.running and self.current_mode == "sequence_7":

            # ── Phase 1: Storm Clouds ─────────────────────────────────────────
            print("⚡ Phase 1: Storm Clouds")
            for cloud_cycle in range(15):
                if not self.running or self.current_mode != "sequence_7":
                    break

                cloud_intensity = (math.sin(cloud_cycle * 0.4) + 1) / 2

                self.set_static(self.mobo_leds,
                    self.interpolate_color(storm_dark, cloud_gray, cloud_intensity * 0.5))
                if self.gpu:
                    self.set_static(self.gpu,
                        self.interpolate_color(storm_dark, thunder_purple, cloud_intensity * 0.3))

                # RAM — ambiance sombre statique
                for ram in self.ram_devices:
                    self.set_static(ram, storm_dark)

                # Fans — nuages qui roulent lentement, chaque fan légèrement déphasé
                def rolling_clouds(led_i, phase, t):
                    # Ondulation lente décalée par fan et par LED
                    angle = (t * 0.5 + phase * 2 + led_i / self.fan_sync.leds_per_fan) * math.pi
                    f = (math.sin(angle) + 1) / 2 * 0.4  # max 40% de cloud_gray
                    return self.interpolate_color(storm_dark, cloud_gray, f)

                self.fan_sync.render(rolling_clouds, self.apply_brightness)
                time.sleep(0.15)

            if not self.running or self.current_mode != "sequence_7":
                break

            # ── Phase 2: Lightning Strikes ────────────────────────────────────
            print("⚡ Phase 2: Lightning Strikes")
            for _ in range(random.randint(3, 6)):
                if not self.running or self.current_mode != "sequence_7":
                    break

                # Choix aléatoire : éclair sur un fan ou sur la RAM
                strike_on_fans = random.random() > 0.4

                if strike_on_fans:
                    # Éclair sur un fan aléatoire — les autres restent sombres
                    strike_fan = random.randint(0, self.fan_sync.total_fans - 1)

                    def fan_strike_flash(led_i, phase, t, sf=strike_fan):
                        fan_i = round(phase * self.fan_sync.total_fans)
                        if fan_i == sf:
                            # Flash : toutes les LEDs du fan touché
                            return lightning_white
                        return storm_dark

                    self.fan_sync.render(fan_strike_flash, self.apply_brightness)
                    if self.gpu and random.random() > 0.5:
                        self.set_static(self.gpu, lightning_blue)
                    time.sleep(0.05)

                    def fan_strike_fade(led_i, phase, t, sf=strike_fan):
                        fan_i = round(phase * self.fan_sync.total_fans)
                        if fan_i == sf:
                            return lightning_blue
                        return storm_dark

                    self.fan_sync.render(fan_strike_fade, self.apply_brightness)
                    time.sleep(0.08)

                    def fans_dark(led_i, phase, t):
                        return storm_dark

                    self.fan_sync.render(fans_dark, self.apply_brightness)

                else:
                    # Éclair sur la RAM
                    strike_ram = random.choice(self.ram_devices)
                    self.set_static(strike_ram, lightning_white)
                    if self.gpu and random.random() > 0.5:
                        self.set_static(self.gpu, lightning_blue)
                    time.sleep(0.05)
                    self.set_static(strike_ram, lightning_blue)
                    time.sleep(0.08)
                    self.set_static(strike_ram, storm_dark)

                if self.gpu:
                    self.set_static(self.gpu, thunder_purple)

                time.sleep(random.uniform(0.3, 1.5))

            if not self.running or self.current_mode != "sequence_7":
                break

            # ── Phase 3: Fork Lightning ───────────────────────────────────────
            # L'éclair traverse les 4 fans comme un seul bandeau de 32 LEDs
            print("⚡ Phase 3: Fork Lightning")
            for fork_strike in range(2):
                if not self.running or self.current_mode != "sequence_7":
                    break

                total_leds = self.fan_sync.total_fans * self.fan_sync.leds_per_fan

                # RAM — éclair classique per-device
                for ram in self.ram_devices:
                    self.set_best_mode(ram)
                    led_count = len(ram.leds)
                    for position in range(0, led_count, 2):
                        if not self.running or self.current_mode != "sequence_7":
                            break
                        colors = [storm_dark] * led_count
                        if position < led_count:
                            colors[position] = lightning_white
                        if position + 1 < led_count:
                            colors[position + 1] = lightning_blue
                        if position - 1 >= 0:
                            colors[position - 1] = cloud_gray
                        ram.set_colors(colors)
                        time.sleep(0.02)
                    self.set_static(ram, storm_dark)

                # Fans — éclair qui traverse les 4 fans en cascade
                for position in range(0, total_leds + 4, 2):
                    if not self.running or self.current_mode != "sequence_7":
                        break

                    def fork_lightning(led_i, phase, t, pos=position):
                        # Position absolue de cette LED dans le bandeau
                        fan_i = round(phase * self.fan_sync.total_fans)
                        abs_pos = fan_i * self.fan_sync.leds_per_fan + led_i
                        if abs_pos == pos:
                            return lightning_white
                        elif abs_pos == pos + 1:
                            return lightning_blue
                        elif abs_pos == pos - 1:
                            return cloud_gray
                        return storm_dark

                    self.fan_sync.render(fork_lightning, self.apply_brightness)
                    time.sleep(0.02)

                # Flash final mobo + GPU
                if self.gpu:
                    self.set_static(self.gpu, lightning_white)
                self.set_static(self.mobo_leds, lightning_blue)
                time.sleep(0.1)
                if self.gpu:
                    self.set_static(self.gpu, storm_dark)
                self.set_static(self.mobo_leds, storm_dark)

                # Retour au calme sur les fans
                def fans_reset(led_i, phase, t):
                    return storm_dark
                self.fan_sync.render(fans_reset, self.apply_brightness)

                time.sleep(random.uniform(1.0, 2.0))

            time.sleep(1)

    def mode_sequence_8(self):
        """Séquence 8 - Neon City avec néons urbains cyberpunk"""
        print("🌃 Séquence 8 - Neon City")

        # Palette néon urbain
        neon_pink = RGBColor(255, 20, 147)
        neon_cyan = RGBColor(0, 255, 255)
        neon_orange = RGBColor(255, 140, 0)
        neon_purple = self.colorE
        neon_lime = RGBColor(50, 255, 50)
        city_dark = RGBColor(15, 10, 25)
        billboard_white = RGBColor(255, 255, 200)

        while self.running and self.current_mode == "sequence_8":
            # Phase 1: Néons qui s'allument un par un
            print("🌃 Phase 1: City Awakens")
            neon_sequence = [
                (self.mobo, neon_cyan),
                (self.gpu if self.gpu else self.mobo, neon_pink),
            ]

            for device in self.ram_devices:
                neon_sequence.append((device, random.choice([neon_orange, neon_lime, neon_purple])))
            neon_sequence.append((self.node_pro, neon_cyan))

            for device, color in neon_sequence:
                if not self.running or self.current_mode != "sequence_8":
                    break
                self.smooth_transition(device, city_dark, color, 0.3, 10)
                time.sleep(0.2)

            if not self.running or self.current_mode != "sequence_8":
                break

            time.sleep(1)

            # Phase 2: Publicités clignotantes (billboard flicker)
            print("🌃 Phase 2: Neon Billboards")
            for flicker_cycle in range(20):
                if not self.running or self.current_mode != "sequence_8":
                    break

                # Néons qui clignotent de façon désynchronisée
                for device in [self.mobo] + self.ram_devices + [self.node_pro]:
                    if random.random() > 0.7:
                        flash_color = random.choice([billboard_white, neon_pink, neon_cyan])
                        self.set_static(device, flash_color)
                    else:
                        steady_color = random.choice([neon_orange, neon_purple, neon_lime])
                        self.set_static(device, steady_color)

                if self.gpu:
                    gpu_pulse = (math.sin(flicker_cycle * 0.5) + 1) / 2
                    self.set_static(self.gpu, self.interpolate_color(neon_purple, neon_pink, gpu_pulse))

                time.sleep(0.15)

            if not self.running or self.current_mode != "sequence_8":
                break

            # Phase 3: Balayage urbain (city sweep)
            print("🌃 Phase 3: Street Lights")
            for sweep_round in range(2):
                if not self.running or self.current_mode != "sequence_8":
                    break

                sweep_colors = [neon_cyan, neon_pink, neon_orange, neon_lime]

                for sweep_color in sweep_colors:
                    if not self.running or self.current_mode != "sequence_8":
                        break

                    # Balayage à travers tous les composants
                    all_devices = [self.mobo] + self.ram_devices + [self.node_pro]
                    if self.gpu:
                        all_devices.append(self.gpu)

                    for device in all_devices:
                        if not self.running or self.current_mode != "sequence_8":
                            break

                        self.smooth_transition(device, self.last_colors.get(device, city_dark), sweep_color, 0.4, 15)
                        time.sleep(0.1)

                    time.sleep(0.3)

            # Phase 4: Extinction progressive
            print("🌃 Phase 4: City Sleeps")
            for device in self.get_all_devices():
                if not self.running or self.current_mode != "sequence_8":
                    break
                self.smooth_transition(device, self.last_colors.get(device, neon_pink), city_dark, 0.5, 15)
                time.sleep(0.1)

            time.sleep(1)

    def mode_fixed_color(self, color_name):
        """Mode couleur fixe"""
        print(f"🎨 Couleur fixe: {color_name}")
        
        color_palette = {
            "rouge": RGBColor(255, 0, 0),
            "vert": RGBColor(0, 255, 0),
            "bleu": RGBColor(0, 114, 255),
            "cyan": RGBColor(0, 255, 255),
            "magenta": RGBColor(255, 70, 255),
            "violet": RGBColor(128, 0, 128),
            "jaune": RGBColor(255, 255, 0),
            "blanc": RGBColor(255, 255, 255),
            "orange": RGBColor(255, 165, 0),
            "rose": RGBColor(255, 192, 203),
            "lime": RGBColor(50, 205, 50),
            "azure": RGBColor(0, 127, 255),
        }
        
        if color_name not in color_palette:
            print(f"❌ Couleur inconnue: {color_name}")
            return
        
        fixed_color = color_palette[color_name]
        
        # Appliquer à tous les périphériques y compris GPU
        for device in self.get_all_devices():
            self.set_static(device, fixed_color)
        
        gpu_status = " (y compris GPU)" if self.gpu else ""
        print(f"✅ Couleur {color_name} appliquée à tous les périphériques{gpu_status}")
    
    def start_mode(self, mode):
        """Démarre un mode spécifique"""
        self.stop_current_mode()
        self.current_mode = mode
        self.running = True
        
        try:
            os.makedirs(os.path.dirname(self.STATUS_FILE), exist_ok=True)
            with open(self.STATUS_FILE, 'w') as f:
                f.write(mode)
        except Exception as e:
            print(f"⚠️ Impossible de sauvegarder le statut: {e}")
        
        if mode == "off":
            self.mode_off()
        elif mode == "sequence_1":
            self.animation_thread = threading.Thread(target=self.mode_sequence_1)
            self.animation_thread.daemon = True
            self.animation_thread.start()
        elif mode == "sequence_2":
            self.animation_thread = threading.Thread(target=self.mode_sequence_2)
            self.animation_thread.daemon = True
            self.animation_thread.start()
        elif mode == "sequence_3":
            self.animation_thread = threading.Thread(target=self.mode_sequence_3)
            self.animation_thread.daemon = True
            self.animation_thread.start()
        elif mode == "sequence_4":
            self.animation_thread = threading.Thread(target=self.mode_sequence_4)
            self.animation_thread.daemon = True
            self.animation_thread.start()
        elif mode == "sequence_5":
            self.animation_thread = threading.Thread(target=self.mode_sequence_5)
            self.animation_thread.daemon = True
            self.animation_thread.start()
        elif mode == "sequence_6":
            self.animation_thread = threading.Thread(target=self.mode_sequence_6)
            self.animation_thread.daemon = True
            self.animation_thread.start()
        elif mode == "sequence_7":
            self.animation_thread = threading.Thread(target=self.mode_sequence_7)
            self.animation_thread.daemon = True
            self.animation_thread.start()
        elif mode == "sequence_8":
            self.animation_thread = threading.Thread(target=self.mode_sequence_8)
            self.animation_thread.daemon = True
            self.animation_thread.start()
        elif mode.startswith("fixed_"):
            color_name = mode.replace("fixed_", "")
            self.mode_fixed_color(color_name)
    
    def stop_current_mode(self):
        """Arrête le mode actuel"""
        self.running = False
        if self.animation_thread and self.animation_thread.is_alive():
            self.animation_thread.join(timeout=2)
    
    def cleanup(self):
        """Nettoyage avant fermeture"""
        self.stop_current_mode()
        self.mode_off()

    def apply_brightness(self, color):
        """Applique la luminosité actuelle à une couleur"""
        brightness = self.get_brightness()
        return RGBColor(
            int(color.red * brightness),
            int(color.green * brightness),
            int(color.blue * brightness)
        )

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 ./modules/script/OpenRGB_Controller.py <mode>")
        print("Modes: off, sequence_1, sequence_2, sequence_3, sequence_4, sequence_5, sequence_6, sequence_7, sequence_8, fixed_<couleur>")
        print("Couleurs fixes: rouge, vert, bleu, cyan, magenta, jaune, blanc, orange, violet, rose, lime, azure")
        sys.exit(1)

    mode = sys.argv[1]
    valid_modes = ["off", "sequence_1", "sequence_2", "sequence_3", "sequence_4", "sequence_5", "sequence_6", "sequence_7", "sequence_8"]
    valid_colors = ["rouge", "vert", "bleu", "cyan", "magenta", "jaune", "blanc", "orange", "violet", "rose", "lime", "azure"]
    
    wait_for_openrgb(timeout=30)
    
    controller = OpenRGBController()
    
    try:
        controller.start_mode(mode)
        
        if mode != "off":
            # Maintenir le programme en vie pour les animations
            while controller.running:
                time.sleep(1)
        else:
            print("✅ Mode OFF appliqué")
            
    except KeyboardInterrupt:
        print("\n🛑 Arrêt demandé")
    except Exception as e:
        print(f"💥 Erreur: {e}")
    finally:
        controller.cleanup()
        print("🏁 Programme terminé")
# Classe pour surveiller les changements
class SequenceFileHandler(FileSystemEventHandler):
    """Gestionnaire pour surveiller les changements du fichier sequence.txt"""
    def __init__(self, controller):
        self.controller = controller
        self.last_mode = None

    def on_modified(self, event):
        if event.src_path.endswith('./modules/script/sequence.txt'):
            try:
                with open(event.src_path, 'r') as f:
                    new_mode = f.read().strip()

                if new_mode and new_mode != self.last_mode:
                    print(f"📝 Nouveau mode détecté: {new_mode}")
                    self.last_mode = new_mode
                    self.controller.start_mode(new_mode)
            except Exception as e:
                print(f"⚠️ Erreur lecture sequence.txt: {e}")
