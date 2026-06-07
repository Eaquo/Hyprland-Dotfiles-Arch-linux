#!/usr/bin/env python3
import os, sys, json, glob, time

def find_vader_hidraw():
    for h in glob.glob("/sys/class/hidraw/hidraw*"):
        try:
            content = open(h + "/device/uevent").read()
            if "37D7" in content and "2401" in content and "input1" in content:
                return f"/dev/{os.path.basename(h)}"
        except:
            pass
    return None

def get_battery(path):
    try:
        fd = os.open(path, os.O_RDWR | os.O_NONBLOCK)
        for cmd in [
            bytes([0x5a, 0xa5, 0x01, 0x02, 0x03] + [0]*27),
            bytes([0x5a, 0xa5, 0xa1, 0x02, 0xa3] + [0]*27),
            bytes([0x5a, 0xa5, 0x02, 0x02, 0x04] + [0]*27),
            bytes([0x5a, 0xa5, 0x04, 0x02, 0x06] + [0]*27),
        ]:
            os.write(fd, cmd)
            time.sleep(0.05)
            try: os.read(fd, 32)
            except: pass
        time.sleep(0.2)
        battery = None
        for _ in range(10):
            try:
                data = os.read(fd, 32)
                if len(data) >= 6 and data[0] == 0x5a and data[1] == 0xa5:
                    for i in range(3, min(len(data), 10)):
                        if 1 <= data[i] <= 100:
                            battery = data[i]
                            break
                if battery is not None:
                    break
            except: 
                break
        os.close(fd)
        return battery
    except:
        return None

dev = find_vader_hidraw()
if not dev:
    print(json.dumps({
        "text":    "",
        "tooltip": "Vader 5 Pro non connectée",
        "class":   "disconnected"
    }))
    sys.exit(0)

batt = get_battery(dev)
if batt is not None:
    perc = round(batt / 5) * 5
    print(json.dumps({
        "text":       f"🎮 |",
        "tooltip":    f"🎮 Vader 5 Pro\nBatterie : {batt}%",
        "class":      f"perc{perc}",
        "percentage": batt
    }))
else:
    print(json.dumps({
        "text":    "",
        "tooltip": "Vader 5 Pro connectée (batterie inconnue)",
        "class":   "connected"
    }))
