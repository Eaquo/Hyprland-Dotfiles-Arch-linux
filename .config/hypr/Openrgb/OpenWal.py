from openrgb import OpenRGBClient
from openrgb.utils import RGBColor, DeviceType
import time, json, os, random, threading
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

WALLUST_PATH = '/home/florian/.config/hypr/Openrgb/wal_rgb.json'

# --- Utilitaires ---
def hex_to_rgbcolor(hex_code):
    hex_code = hex_code.lstrip('#')
    r = int(hex_code[0:2], 16)
    g = int(hex_code[2:4], 16)
    b = int(hex_code[4:6], 16)
    return RGBColor(r, g, b)

def load_colors():
    with open(WALLUST_PATH) as f:
        wal = json.load(f)
    return [hex_to_rgbcolor(wal['colors'][f'color{i}']) for i in range(16)]

# --- Détection changement WAL ---
class WalChangeHandler(FileSystemEventHandler):
    def __init__(self, on_change_callback):
        self.on_change_callback = on_change_callback

    def on_modified(self, event):
        if event.src_path == WALLUST_PATH:
            self.on_change_callback()

def reload_colors():
    global colors, colorA, colorB, colorC, colorD, colorE, colorF
    print("🔁 Reload WAL colors")
    colors = load_colors()
    colorA = colors[0]
    colorB = colors[2]
    colorC = colors[7]
    colorD = colors[12]
    colorE = colors[4]
    colorF = colors[15]
    colorG = colors[13]
    colorH = colors[1]
    colorI = colors[5]

# --- Connexion OpenRGB ---
client = OpenRGBClient()
devices = client.devices

ram_devices = [d for d in devices if d.name == "Corsair Vengeance Pro RGB"]
node_pro = next(d for d in devices if d.name == "Corsair Lighting Node Pro")
mobo = next(d for d in devices if d.type == DeviceType.MOTHERBOARD)

colors = load_colors()
colorA = colors[0]
colorB = colors[2]
colorC = colors[7]
colorD = colors[12]
colorE = colors[4]
colorF = colors[15]
colorG = colors[13]
colorH = colors[1]
colorI = colors[5]

last_colors = {}
last_modes = {}

def set_mode_safe(device, target_mode_name):
    for mode in device.modes:
        if mode.name.lower() == target_mode_name.lower():
            if last_modes.get(device) != mode.name:
                device.set_mode(mode)
                last_modes[device] = mode.name
            return
    print(f"⚠️ Mode '{target_mode_name}' non disponible pour {device.name}")

def smart_set_color(device, color):
    if last_colors.get(device) != color:
        device.set_color(color)
        last_colors[device] = color

def set_static(device, color):
    set_mode_safe(device, "Static")
    smart_set_color(device, color)

def pulse_color_loop(device, color1, color2, duration=10, steps=50, speed=0.05):
    set_mode_safe(device, "Direct")
    start_time = time.time()
    while time.time() - start_time < duration:
        for i in range(steps):
            ratio = i / steps
            blend = RGBColor(
                int(color1.red * (1 - ratio) + color2.red * ratio),
                int(color1.green * (1 - ratio) + color2.green * ratio),
                int(color1.blue * (1 - ratio) + color2.blue * ratio),
            )
            device.set_color(blend)
            time.sleep(speed)
        color1, color2 = color2, color1

def rain_loop_with_base(ram_devices, base_color, rain_color, duration=10, speed=0.1, trail_length=3):
    off = RGBColor(0, 0, 0)
    start_time = time.time()
    led_count = len(ram_devices[0].leds)
    active_drops = []

    while time.time() - start_time < duration:
        if random.random() < 0.3:
            for ram in ram_devices:
                active_drops.append({
                    "device": ram,
                    "position": 0,
                    "color": rain_color
                })

        for drop in active_drops[:]:
            device = drop["device"]
            pos = drop["position"]
            color = drop["color"]
            leds = [base_color] * led_count

            for i in range(trail_length):
                p = pos - i
                if 0 <= p < led_count:
                    fade = max(0.1, 1.0 - (i / trail_length))
                    faded_color = RGBColor(
                        int(color.red * fade),
                        int(color.green * fade),
                        int(color.blue * fade)
                    )
                    leds[p] = faded_color

            device.set_colors(leds)
            drop["position"] += 1

            if drop["position"] - trail_length > led_count:
                active_drops.remove(drop)

        time.sleep(speed)

# --- Watcher WAL ---
handler = WalChangeHandler(reload_colors)
observer = Observer()
observer.schedule(handler, path=os.path.dirname(WALLUST_PATH), recursive=False)
observer_thread = threading.Thread(target=observer.start)
observer_thread.daemon = True
observer_thread.start()

# --- Boucle principale ---
try:
    while True:
        print("🌈 Phase 1 - Rain + Pulse")

        rain_thread = threading.Thread(
            target=rain_loop_with_base,
            args=(ram_devices, colorA, colorI, 10)
        )
        rain_thread.start()

        pulse_color_loop(node_pro, colorH, colorB, duration=10)
        set_static(mobo, colorC)

        rain_thread.join()  # attendre que la pluie se termine avant de continuer

        print("🌈 Phase 2 - Rain + Pulse")
        rain_thread = threading.Thread(
            target=rain_loop_with_base,
            args=(ram_devices, colorB, colorC, 10)
        )
        rain_thread.start()

        pulse_color_loop(node_pro, colorB, colorG, duration=10)
        set_static(mobo, colorC)

        rain_thread.join()

        print("🌈 Phase 3 - Rain + Pulse")
        rain_thread = threading.Thread(
            target=rain_loop_with_base,
            args=(ram_devices, colorC, colorG, 10)
        )
        rain_thread.start()

        pulse_color_loop(node_pro, colorC, colorG, duration=10)
        set_static(mobo, colorG)

        rain_thread.join()

        print("🌈 Phase 4 - Rain + Pulse")
        rain_thread = threading.Thread(
            target=rain_loop_with_base,
            args=(ram_devices, colorD, colorI, 10)
        )
        rain_thread.start()

        pulse_color_loop(node_pro, colorD, colorI, duration=10)
        set_static(mobo, colorI)

        rain_thread.join()

except KeyboardInterrupt:
    print("🛑 Animation stoppée par l'utilisateur.")
    for device in ram_devices + [node_pro, mobo]:
        try:
            set_static(device, colorA)
        except:
            pass
