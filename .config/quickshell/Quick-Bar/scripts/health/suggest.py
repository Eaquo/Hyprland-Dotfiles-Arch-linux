#!/usr/bin/env python3
"""Suggestions pour « Ajouter une vérification » (Réglages › Santé), une liste par type.

Sortie JSON : {type: [{name, target, detail, fix, icon?}, …]} pour
process · service · url · host · port · mount · file · command.
Tout est lu localement (hyprctl, /proc, systemctl, ip, ss, findmnt) ; rien n'est modifié.
"""
import json
import os
import re
import shutil
import subprocess

HOME = os.path.expanduser("~")
NOISE = ("kworker", "(sd-", "python", "systemd", "dbus", "at-spi", "xdg-", "gvfs", "dconf", "ksecretd", "kded", "start-hyprland",
         "Xwayland", "polkit", "gpg-agent", "ssh-agent", "appimagelaunch", "sh", "bash", "zsh", "fish", "sleep", "cat", "timeout",
         "qs", "quickshell", "hyprctl", "socat", "pkexec", "sudo", "login", "agetty", "uwsm", "obex", "evolution")
GENERIC = {"electron", "java", "node", "mono", "dotnet", "bwrap", "AppRun", "steam-runtime"}


def sh(cmd, timeout=4):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def cmdline(pid):
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            parts = [p.decode(errors="replace") for p in f.read().split(b"\0") if p]
        return parts
    except OSError:
        return []


def relaunch(parts):
    """Commande de relance d'un processus : son exécutable (sans les arguments internes)."""
    if not parts:
        return ""
    exe = parts[0]
    base = os.path.basename(exe)
    return "setsid -f " + (base if shutil.which(base) else exe) + " >/dev/null 2>&1"


def processes():
    out, seen = [], set()
    # 1. applications ouvertes (fenêtres Hyprland)
    try:
        clients = json.loads(sh(["hyprctl", "clients", "-j"]) or "[]")
    except ValueError:
        clients = []
    for c in clients:
        pid = c.get("pid", 0)
        parts = cmdline(pid)
        comm = ""
        try:
            comm = open(f"/proc/{pid}/comm").read().strip()
        except OSError:
            pass
        cls = (c.get("class") or comm).split(".")[-1]
        # électron, python, java… : le nom du processus ne dit rien → on cherche l'appli dans la ligne de commande
        generic = comm in GENERIC or comm.startswith(("python", "wine"))
        target = cls.lower() if generic else comm
        if not comm or target in seen:
            continue
        seen.add(target); seen.add(comm)
        fix = ("setsid -f " + cls.lower() + " >/dev/null 2>&1" if shutil.which(cls.lower()) else "") if generic else relaunch(parts)
        out.append({"name": c.get("class") or comm, "target": target, "detail": "fenêtre ouverte · " + (c.get("title") or "")[:60],
                    "fix": fix, "group": "Applications ouvertes"})
    # 2. autres programmes de l'utilisateur (sans les démons de session)
    others = []
    uid = os.getuid()
    for d in os.listdir("/proc"):
        if not d.isdigit():
            continue
        try:
            if os.stat(f"/proc/{d}").st_uid != uid:
                continue
            comm = open(f"/proc/{d}/comm").read().strip()
        except OSError:
            continue
        parts = cmdline(d)
        name = os.path.basename(parts[0]).split(" ")[0] if parts else comm      # comm est tronqué à 15 caractères
        if name in seen or comm in seen or comm in GENERIC or name.startswith(NOISE) or comm.startswith(NOISE):
            continue
        seen.add(name); seen.add(comm)
        others.append({"name": name, "target": name, "detail": " ".join(parts)[:80], "fix": relaunch(parts),
                       "group": "Programmes en cours"})
    return out + sorted(others, key=lambda x: x["name"].lower())


def services():
    out = []
    for scope, flag, fixp in (("utilisateur", ["--user"], "systemctl --user restart "), ("système", [], "pkexec systemctl restart ")):
        txt = sh(["systemctl", *flag, "list-units", "--type=service", "--all", "--no-legend", "--plain"])
        for line in txt.splitlines():
            f = line.split(None, 4)
            if len(f) < 4 or not f[0].endswith(".service") or f[1] != "loaded":
                continue
            unit = f[0][:-8]
            if "@" in unit and unit.endswith("@"):
                continue
            out.append({"name": unit, "target": unit, "detail": f"{scope} · {f[2]}/{f[3]} · " + (f[4] if len(f) > 4 else ""),
                        "fix": fixp + unit, "group": f"Services {scope} " + ("actifs" if f[2] == "active" else "inactifs"),
                        "active": f[2] == "active"})
    out.sort(key=lambda s: (not s["active"], s["group"], s["name"]))
    return out


def listening():
    """[(adresse, port, processus)] en écoute TCP."""
    res = []
    for line in sh(["ss", "-tlnpH"]).splitlines():
        f = line.split()
        if len(f) < 4:
            continue
        addr, _, port = f[3].rpartition(":")
        addr = addr.strip("[]")
        m = re.search(r'\(\("([^"]+)"', line)
        res.append((addr, port, m.group(1) if m else ""))
    return res


def ports():
    out, seen = [], set()
    for addr, port, proc in listening():
        host = "127.0.0.1" if addr in ("0.0.0.0", "*", "::", "127.0.0.1", "::1") else addr
        key = host + ":" + port
        if key in seen:
            continue
        seen.add(key)
        out.append({"name": (proc or "port") + " " + port, "target": key, "detail": f"en écoute sur {addr} · {proc or '?'}",
                    "fix": "", "group": "Ports ouverts sur ce PC"})
    return out


def neighbours():
    """[(ip, mac)] vus récemment sur le réseau local + passerelle."""
    res = []
    for line in sh(["ip", "neigh"]).splitlines():
        f = line.split()
        if "lladdr" in f and not f[0].startswith(("fe80", "169.254")) and ":" not in f[0]:
            res.append((f[0], f[f.index("lladdr") + 1]))
    return res


def hosts():
    out, seen = [], set()
    gw = ""
    m = re.search(r"default via (\S+)", sh(["ip", "route"]))
    if m:
        gw = m.group(1)
    names = {}
    for ip, mac in neighbours():
        names.setdefault(ip, mac)
    wol = shutil.which("wakeonlan") or shutil.which("wol")
    for ip, mac in names.items():
        seen.add(ip)
        fix = (os.path.basename(wol) + " " + mac) if wol and ip != gw else ""
        out.append({"name": "Box / routeur" if ip == gw else ip, "target": ip,
                    "detail": ("passerelle · " if ip == gw else "vu sur le réseau · ") + mac + (" · réveil Wake-on-LAN" if fix else ""),
                    "fix": fix, "group": "Réseau local"})
    # ~/.ssh/config et /etc/hosts
    try:
        for line in open(HOME + "/.ssh/config"):
            m = re.match(r"\s*Host\s+(.+)", line)
            if m:
                for h in m.group(1).split():
                    if "*" not in h and h not in seen:
                        seen.add(h)
                        out.append({"name": h, "target": h, "detail": "~/.ssh/config", "fix": "", "group": "Machines SSH"})
    except OSError:
        pass
    try:
        for line in open("/etc/hosts"):
            f = line.split("#")[0].split()
            if len(f) >= 2 and not f[0].startswith(("127.", "::", "ff", "fe")):
                for h in f[1:]:
                    if h not in seen:
                        seen.add(h)
                        out.append({"name": h, "target": h, "detail": "/etc/hosts · " + f[0], "fix": "", "group": "Machines connues"})
    except OSError:
        pass
    out.append({"name": "Internet (Cloudflare)", "target": "1.1.1.1", "detail": "accès à Internet", "fix": "", "group": "Internet"})
    return out


def urls():
    out = []
    for addr, port, proc in listening():
        if addr.startswith("127.0.0.5") or port in ("53", "631"):
            continue
        host = "localhost" if addr in ("0.0.0.0", "*", "::", "127.0.0.1", "::1") else addr
        out.append({"name": (proc or "service") + " (web local)", "target": f"http://{host}:{port}",
                    "detail": f"port {port} ouvert par {proc or '?'}", "fix": "", "group": "Services locaux"})
    for ip, _ in neighbours():
        out.append({"name": ip + " (interface web)", "target": f"http://{ip}", "detail": "machine du réseau", "fix": "", "group": "Réseau local"})
    for n, u in (("Google", "https://www.google.com"), ("GitHub", "https://github.com"), ("Steam", "https://store.steampowered.com")):
        out.append({"name": n, "target": u, "detail": "site public", "fix": "", "group": "Internet"})
    return out


def mounts():
    out = []
    txt = sh(["findmnt", "-rno", "TARGET,SOURCE,FSTYPE"])
    for line in txt.splitlines():
        f = line.split()
        if len(f) < 3:
            continue
        tgt = f[0].replace("\\x20", " ")
        net = f[2] in ("nfs", "nfs4", "cifs", "smb3", "fuse.sshfs", "fuse.rclone")
        if not net and not (f[1].startswith("/dev/") and f[2] in ("ext4", "btrfs", "xfs", "ntfs3", "ntfs", "exfat", "vfat", "f2fs")):
            continue
        if tgt in ("/", "/boot", "/home") or tgt.startswith(("/var", "/root", "/srv", "/snap")):
            continue
        out.append({"name": os.path.basename(tgt.rstrip("/")) or tgt, "target": tgt, "detail": f"{f[1]} · {f[2]}" + (" · réseau" if net else ""),
                    "fix": "pkexec mount " + tgt, "group": "Partages réseau" if net else "Disques montés"})
    # entrées de /etc/fstab pas montées en ce moment
    mounted = {o["target"] for o in out}
    try:
        for line in open("/etc/fstab"):
            f = line.split("#")[0].split()
            if len(f) >= 3 and f[1].startswith("/") and f[1].rstrip("/") not in mounted and f[1] not in mounted and f[1] not in ("/", "/boot", "/home", "none") \
                    and f[2] not in ("swap", "tmpfs") and not f[1].startswith(("/var", "/root", "/srv")):
                out.append({"name": os.path.basename(f[1].rstrip("/")) or f[1], "target": f[1].rstrip("/") or f[1],
                            "detail": f"fstab · {f[0]} · pas monté en ce moment", "fix": "pkexec mount " + f[1], "group": "Dans /etc/fstab"})
    except OSError:
        pass
    return out


def commands():
    g = "Modèles"
    return [
        {"name": "Internet accessible", "target": "ping -c1 -W2 1.1.1.1", "detail": "ping de Cloudflare", "fix": "", "group": g},
        {"name": "DNS fonctionne", "target": "getent hosts archlinux.org", "detail": "résolution de nom", "fix": "", "group": g},
        {"name": "Disque système sous 90 %", "target": "[ $(df --output=pcent / | tail -1 | tr -dc 0-9) -lt 90 ]", "detail": "place sur /", "fix": "", "group": g},
        {"name": "Aucun service en échec", "target": "! systemctl --failed --no-legend | grep -q .", "detail": "systemctl --failed", "fix": "", "group": g},
        {"name": "Aucun service utilisateur en échec", "target": "! systemctl --user --failed --no-legend | grep -q .", "detail": "systemctl --user --failed", "fix": "", "group": g},
        {"name": "Docker répond", "target": "docker info >/dev/null", "detail": "démon Docker", "fix": "pkexec systemctl restart docker", "group": g},
        {"name": "VPN WireGuard actif", "target": "ip link show wg0", "detail": "interface wg0", "fix": "", "group": g},
        {"name": "Batterie de la souris > 20 %", "target": "[ $(cat /sys/class/power_supply/hidpp_battery_0/capacity 2>/dev/null || echo 100) -gt 20 ]",
         "detail": "Logitech (hidpp)", "fix": "", "group": g},
    ]


def files():
    g = "Exemples"
    out = [{"name": "Dossier Images", "target": "~/Pictures", "detail": "présence du dossier", "fix": "", "group": g},
           {"name": "Config Hyprland", "target": "~/.config/hypr/hyprland.lua", "detail": "fichier de config", "fix": "", "group": g}]
    return out


def main():
    print(json.dumps({"process": processes(), "service": services(), "url": urls(), "host": hosts(), "port": ports(),
                      "mount": mounts(), "file": files(), "command": commands()}))


if __name__ == "__main__":
    main()
