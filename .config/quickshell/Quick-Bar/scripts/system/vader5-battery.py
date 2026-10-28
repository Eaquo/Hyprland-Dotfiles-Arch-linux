#!/usr/bin/env python3
# Batterie de la manette Flydigi Vader 5 Pro (dongle 37d7:2401 ou filaire), lue sur son interface HID
# constructeur : commande « infos appareil » 5a a5 01 02 03, réponse 5a a5 01 … ; octet 11 = état (4 bits
# hauts : 0 sur batterie, 1 en charge, 2 pleine) + niveau (4 bits bas, 0..5 × 20 %).
# Décodage repris de TJLawInOrbit/tux-invader (vader5/protocol.py). Une requête par appel.
# Sortie : « <pourcent> <état> <connexion> » (ex. « 100 0 2 »), rien si la manette est absente.
import glob, os, select, sys, time


def node():
    for h in sorted(glob.glob("/sys/class/hidraw/hidraw*")):
        try:
            u = open(h + "/device/uevent").read()
        except OSError:
            continue
        if "000037D7:00002401" in u.upper() and "input1" in u:
            return "/dev/" + os.path.basename(h)


def query(path, timeout=1.0):
    fd = os.open(path, os.O_RDWR | os.O_NONBLOCK)
    try:
        os.write(fd, bytes([0x5A, 0xA5, 0x01, 0x02, 0x03]) + bytes(27))
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            if select.select([fd], [], [], 0.1)[0]:
                try:
                    d = os.read(fd, 64)
                except BlockingIOError:
                    continue
                if len(d) > 1 and d[0] != 0x5A and d[1] == 0x5A:   # numéro de rapport en tête
                    d = d[1:]
                if len(d) >= 17 and d[:3] == b"\x5a\xa5\x01":
                    return d
    finally:
        os.close(fd)


def decode(d):
    status, level = d[11] >> 4, d[11] & 0x0F
    percent = 100 if status == 2 else min(level * 20, 100)
    return percent, status, d[6]


if __name__ == "__main__":
    if sys.argv[1:] == ["--test"]:
        # réponse réelle relevée le 2026-10-24 : sans fil, sur batterie, niveau 5
        r = bytes.fromhex("5aa5010100820200000000054501007153046735170000000000001026" "1f0036")
        assert decode(r) == (100, 0, 2), decode(r)
        assert decode(bytes(11) + b"\x13" + bytes(20)) == (60, 1, 0)
        print("ok")
        sys.exit()
    n = node()
    d = n and query(n)
    if d:
        print(*decode(d))
