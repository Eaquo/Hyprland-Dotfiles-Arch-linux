#!/usr/bin/env python3
# Clavier principal pour la page Devices : `hyprctl devices -j` (disposition active, Verr. Maj, Verr. Num) et
# son vrai nom (/proc/bus/input/devices : Hyprland ne donne qu'un nom en minuscules avec tirets).
# Sortie : liste JSON [{model, layout, caps, num, main}] des vrais claviers (le service écarte ceux qui sont des souris).
import json, re, subprocess, sys


def slug(s): return re.sub(r"^-+|-+$", "", re.sub(r"[^a-z0-9]+", "-", s.lower()))


def pretty(name):
    """« Ducky Ducky One 3 Mini RGB » (fabricant répété par le pilote) → « Ducky One 3 Mini RGB »"""
    w = name.split()
    return " ".join(w[1:]) if len(w) > 1 and w[0].lower() == w[1].lower() else name


def physical(proc_text):
    """noms (slug) des vrais claviers : USB ou Bluetooth, avec voyants (LED) — pas « Power Button », « PC Speaker »…"""
    out = {}
    for b in proc_text.strip().split("\n\n"):
        n, bus, led = re.search(r'N: Name="(.*)"', b), re.search(r"Bus=(\w+)", b), re.search(r"B: LED=(\w+)", b)
        if n and bus and bus.group(1) in ("0003", "0005") and led and led.group(1) != "0":
            out[slug(n.group(1))] = pretty(n.group(1))
    return out


def keyboards(kbs, proc_text):
    """un par appareil physique (Hyprland en liste une entrée par interface), le principal en premier"""
    phys, groups = physical(proc_text), {}
    for k in kbs:
        base = re.sub(r"-\d+$", "", k["name"])
        if base in phys: groups.setdefault(base, []).append(k)
    out = []
    for base, ks in groups.items():
        k = next((x for x in ks if x.get("main")), ks[0])
        out.append({"model": phys[base], "layout": k.get("active_keymap", ""), "caps": bool(k.get("capsLock")),
                    "num": bool(k.get("numLock")), "main": any(x.get("main") for x in ks)})
    return sorted(out, key=lambda x: not x["main"])


def main():
    try: kbs = json.loads(subprocess.run(["hyprctl", "devices", "-j"], capture_output=True, text=True, timeout=5).stdout)["keyboards"]
    except (OSError, ValueError, KeyError, subprocess.SubprocessError): return
    try: proc = open("/proc/bus/input/devices", encoding="utf-8", errors="replace").read()
    except OSError: proc = ""
    print(json.dumps(keyboards(kbs, proc), ensure_ascii=False))


if __name__ == "__main__":
    if sys.argv[1:] == ["--test"]:
        p = ('I: Bus=0019\nN: Name="Power Button"\nH: Handlers=kbd\n\n'
             'I: Bus=0003\nN: Name="Ducky Ducky One 3 Mini RGB"\nH: Handlers=kbd\nB: LED=7\n\n'
             'I: Bus=0003\nN: Name="Logitech PRO X"\nH: Handlers=kbd\nB: LED=1f\n')
        kb = [{"name": "power-button", "main": True}, {"name": "ducky-ducky-one-3-mini-rgb-2", "active_keymap": "French (AZERTY)", "numLock": True},
              {"name": "logitech-pro-x"}]
        r = keyboards(kb, p)
        assert [x["model"] for x in r] == ["Ducky One 3 Mini RGB", "Logitech PRO X"], r      # Power Button écarté
        assert r[0]["layout"] == "French (AZERTY)" and r[0]["num"]
        assert keyboards([{"name": "power-button", "main": True}], p) == []                  # clavier débranché
        print("ok")
    else:
        main()
