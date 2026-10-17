#!/usr/bin/env python3
"""Démon des stats de la barre (bar/SysStats.qml).

Une ligne JSON sur stdout toutes les 2 s, lue directement dans /proc et /sys
(aucun sous-processus au repos). Sur stdin, la barre envoie « detail on » quand
une carte de survol s'ouvre : le démon passe alors à 1 s et ajoute les
processus les plus gourmands, la place récupérable et le profil d'énergie.
« detail off » le remet au repos.
"""
import glob
import json
import os
import select
import subprocess
import sys
import time

PAGE = os.sysconf("SC_PAGE_SIZE")
HZ = os.sysconf("SC_CLK_TCK")
NCPU = os.cpu_count() or 1
HOME = os.path.expanduser("~")
# Intervalles (s) : argv[1] au repos, argv[2] pendant le survol — [refresh] stats dans config.toml
SLOW = float(sys.argv[1]) if len(sys.argv) > 1 else 2.0
FAST = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0


def read(path, default=""):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


def cpu_times():
    """[(actif, total)] : ligne globale puis un tuple par cœur."""
    out = []
    for line in read("/proc/stat").splitlines():
        if not line.startswith("cpu"):
            break
        v = [int(x) for x in line.split()[1:9]]
        active = v[0] + v[1] + v[2] + v[5] + v[6] + v[7]
        out.append((active, active + v[3] + v[4]))
    return out


def meminfo():
    m = {}
    for line in read("/proc/meminfo").splitlines():
        k, _, rest = line.partition(":")
        m[k] = int(rest.split()[0]) * 1024
    cache = m.get("Cached", 0) + m.get("Buffers", 0) + m.get("SReclaimable", 0)
    return {
        "total": m.get("MemTotal", 0),
        "used": m.get("MemTotal", 0) - m.get("MemAvailable", 0),
        "cache": cache,
        "swapTotal": m.get("SwapTotal", 0),
        "swapUsed": m.get("SwapTotal", 0) - m.get("SwapFree", 0),
    }


def mounts():
    """Point de montage le plus court par périphérique /dev (sous-volumes btrfs dédoublonnés)."""
    best = {}
    for line in read("/proc/mounts").splitlines():
        dev, mnt = line.split()[:2]
        mnt = mnt.replace("\\040", " ")
        if not dev.startswith("/dev/") or mnt.startswith("/boot"):
            continue
        if dev not in best or len(mnt) < len(best[dev]):
            best[dev] = mnt
    return best


def disks(mnts):
    out = []
    for dev, mnt in mnts.items():
        try:
            s = os.statvfs(mnt)
        except OSError:
            continue
        size, avail = s.f_blocks * s.f_frsize, s.f_bavail * s.f_frsize
        used = size - s.f_bfree * s.f_frsize
        out.append({"dev": os.path.basename(dev), "mount": mnt, "size": size, "used": used,
                    "avail": avail, "pct": round(used / size * 100) if size else 0})
    out.sort(key=lambda d: (d["mount"] != "/", d["mount"]))
    return out


def io_bytes():
    """Octets lus / écrits cumulés sur les disques entiers (pas les partitions)."""
    rd = wr = 0
    for line in read("/proc/diskstats").splitlines():
        f = line.split()
        name = f[2]
        whole = (name.startswith("nvme") and "p" not in name[4:]) or \
                (name.startswith("sd") and name[2:].isalpha())
        if whole:
            rd += int(f[5]) * 512
            wr += int(f[9]) * 512
    return rd, wr


def net_bytes():
    """(interface de la route par défaut, octets reçus, octets envoyés)."""
    iface = ""
    for line in read("/proc/net/route").splitlines()[1:]:
        f = line.split()
        if len(f) > 1 and f[1] == "00000000":
            iface = f[0]
            break
    for line in read("/proc/net/dev").splitlines()[2:]:
        name, _, rest = line.partition(":")
        if name.strip() == iface:
            v = rest.split()
            return iface, int(v[0]), int(v[8])
    return iface, 0, 0


def hwmon(mnts):
    """Températures utiles par puce, d'après /sys/class/hwmon (labels du noyau)."""
    t = {"cpu": {}, "gpu": {}, "nvme": []}
    dev_mount = {os.path.basename(d): m for d, m in mnts.items()}
    for h in glob.glob("/sys/class/hwmon/hwmon*"):
        name = read(h + "/name")
        temps = {}
        for inp in glob.glob(h + "/temp*_input"):
            label = read(inp.replace("_input", "_label"), os.path.basename(inp)[:-6])
            try:
                temps[label] = int(read(inp, "0")) / 1000
            except ValueError:
                pass
        if name == "k10temp":
            t["cpu"] = {"tctl": temps.get("Tctl", 0),
                        "ccd": [v for k, v in sorted(temps.items()) if k.startswith("Tccd")]}
        elif name == "amdgpu":
            num = lambda f: int(read(f, "0") or 0)
            t["gpu"] = {"edge": temps.get("edge", 0), "junction": temps.get("junction", 0),
                        "mem": temps.get("mem", 0), "fan": num(h + "/fan1_input"),
                        "busy": num(h + "/device/gpu_busy_percent"),
                        "power": num(h + "/power1_average") / 1e6, "powerCap": num(h + "/power1_cap") / 1e6,
                        "vramUsed": num(h + "/device/mem_info_vram_used"), "vramTotal": num(h + "/device/mem_info_vram_total"),
                        "sclk": num(h + "/freq1_input") / 1e6, "mclk": num(h + "/freq2_input") / 1e6}
        elif name == "nvme":
            ctrl = os.path.basename(os.path.realpath(h + "/device"))      # nvme0
            blk = next((b for b in dev_mount if b.startswith(ctrl + "n")), "")
            part = next((dev_mount[b] for b in dev_mount if b.startswith(ctrl)), "")
            t["nvme"].append({"name": ctrl, "mount": dev_mount.get(blk, part),
                              "temp": temps.get("Composite", 0)})
    t["nvme"].sort(key=lambda n: (n["mount"] != "/", n["name"]))
    return t


def procs():
    """{nom: (ticks cpu cumulés, octets RSS, pid du plus gros)} — agrégé par nom (firefox = n processus)."""
    agg = {}
    for d in os.listdir("/proc"):
        if not d.isdigit():
            continue
        try:
            with open(f"/proc/{d}/stat") as f:
                s = f.read()
            with open(f"/proc/{d}/statm") as f:
                rss = int(f.read().split()[1]) * PAGE
        except OSError:
            continue
        name = s[s.index("(") + 1:s.rindex(")")]
        rest = s[s.rindex(")") + 2:].split()
        ticks = int(rest[11]) + int(rest[12])
        a = agg.setdefault(name, [0, 0, int(d), 0])
        a[0] += ticks
        a[1] += rss
        if rss > a[3]:
            a[2], a[3] = int(d), rss
    return agg


def dir_size(path):
    total = 0
    for root, _, files in os.walk(path):
        for f in files:
            try:
                total += os.lstat(os.path.join(root, f)).st_size
            except OSError:
                pass
    return total


def main():
    detail = False
    prev_cpu, prev_io, prev_t = cpu_times(), io_bytes(), time.monotonic()
    prev_net = net_bytes()
    prev_procs = None
    reclaim, reclaim_at, profile, profile_at = {}, 0, "", 0
    while True:
        r, _, _ = select.select([sys.stdin], [], [], FAST if detail else SLOW)
        if r:
            cmd = sys.stdin.readline()
            if not cmd:
                return                       # Quick-Bar fermé
            detail = cmd.strip() == "detail on"
            if detail:
                prev_procs, reclaim_at, profile_at = None, 0, 0
            continue                         # échantillon au prochain tour

        now = time.monotonic()
        dt = max(0.1, now - prev_t)
        cur = cpu_times()
        pct = [round((a - pa) / (t - pt) * 100) if t > pt else 0
               for (a, t), (pa, pt) in zip(cur, prev_cpu)]
        rd, wr = io_bytes()
        mnts = mounts()
        freqs = [int(read(p, "0") or 0) for p in
                 glob.glob("/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq")]
        out = {
            "cpu": pct[0] if pct else 0,
            "cores": pct[1:],
            "freq": round(sum(freqs) / len(freqs) / 1e6, 1) if freqs else 0,
            "load": float(read("/proc/loadavg", "0").split()[0]),
            "mem": meminfo(),
            "temps": hwmon(mnts),
            "disks": disks(mnts),
            "io": {"rd": (rd - prev_io[0]) / dt, "wr": (wr - prev_io[1]) / dt},
        }
        nt = net_bytes()
        same = nt[0] == prev_net[0]
        out["net"] = {"iface": nt[0], "rx": max(0, nt[1] - prev_net[1]) / dt if same else 0,
                      "tx": max(0, nt[2] - prev_net[2]) / dt if same else 0}
        prev_cpu, prev_io, prev_t, prev_net = cur, (rd, wr), now, nt

        if detail:
            p = procs()
            if prev_procs is not None:
                cpu = sorted(((n, (v[0] - prev_procs.get(n, (v[0],))[0]) / HZ / dt / NCPU * 100, v[2])
                              for n, v in p.items()), key=lambda x: -x[1])[:3]
                out["topCpu"] = [{"name": n, "pct": round(c, 1), "pid": pid} for n, c, pid in cpu]
            mem = sorted(p.items(), key=lambda kv: -kv[1][1])[:3]
            out["topMem"] = [{"name": n, "bytes": v[1]} for n, v in mem]
            prev_procs = p
            if now - reclaim_at > 60:
                reclaim = {"trash": dir_size(HOME + "/.local/share/Trash/files"),
                           "pacman": dir_size("/var/cache/pacman/pkg")}
                reclaim_at = now
            if now - profile_at > 10:
                try:
                    profile = subprocess.run(["powerprofilesctl", "get"], capture_output=True,
                                             text=True, timeout=2).stdout.strip()
                except (OSError, subprocess.SubprocessError):
                    profile = ""
                profile_at = now
            out["reclaim"], out["profile"] = reclaim, profile

        print(json.dumps(out, separators=(",", ":")), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
