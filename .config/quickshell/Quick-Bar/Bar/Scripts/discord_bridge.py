#!/usr/bin/env python3
"""Pont Discord ↔ Quickshell (sans discord.py — aiohttp + websockets).

Orienté SERVEUR : l'id configuré est celui du serveur (guild). Le bridge liste
les salons texte, écoute tous les messages du serveur (threads compris) et les
tague avec leur salon ; le picker de l'onglet Discord choisit lequel afficher.

Modes :
  • écoute (défaut) : émet la liste des salons puis, en continu, chaque message
    reçu — un JSON par ligne sur stdout (lu par DiscordService via SplitParser).
  • --history <channel_id>  : imprime l'historique récent d'un salon, puis quitte.
  • --send "texte" <channel_id> : poste un message (ou exécute une commande
    locale si le texte commence par « / »), puis quitte.

Token : $DISCORD_BOT_TOKEN ou ~/.config/quickshell/Quick-Bar/.discord_token
(gitignoré). Prérequis : intent Message Content + bot dans le serveur avec
View Channel / Send Messages / Read Message History.
"""

import asyncio
import json
import os
import sys

import aiohttp
import websockets

API = "https://discord.com/api/v10"
GUILD_ID = "1517138021105799169"
GATEWAY_URL = "wss://gateway.discord.gg/?v=10&encoding=json"

# Endpoint download de bot.js (LXC 107).
BOT_API = "http://192.168.1.188:8787"

# Secret partagé avec DL_API_SECRET de bot.js. Lu depuis $DISCORD_DL_SECRET ou le
# fichier ~/.config/quickshell/Quick-Bar/.dl_secret (gitignoré) — jamais en dur
# pour ne pas fuiter sur un repo public.
DL_SECRET = os.environ.get("DISCORD_DL_SECRET", "").strip()
if not DL_SECRET:
    try:
        with open(os.path.expanduser(
                "~/.config/quickshell/Quick-Bar/.dl_secret")) as _f:
            DL_SECRET = _f.read().strip()
    except OSError:
        DL_SECRET = ""

# GUILDS(1<<0) | GUILD_MESSAGES(1<<9) | MESSAGE_CONTENT(1<<15)
INTENTS = (1 << 0) | (1 << 9) | (1 << 15)

TEXT_TYPES = (0, 5)             # text, announcement
THREAD_TYPES = (10, 11, 12)     # announcement / public / private thread

TOKEN_FILE = os.path.expanduser(
    "~/.config/quickshell/Quick-Bar/.discord_token")


# ── Commandes locales « de mon bot » ─────────────────────────────────────────
# Le texte commençant par « / » n'est pas envoyé tel quel : le bot exécute la
# commande et poste son résultat. Ajoute les tiennes ici.
def _cmd_help(args):
    return "Commandes dispo : " + ", ".join(sorted(LOCAL_COMMANDS))


def _cmd_ping(args):
    return "pong 🏓"


LOCAL_COMMANDS = {
    "/help": _cmd_help,
    "/ping": _cmd_ping,
}


def emit(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def load_token():
    tok = os.environ.get("DISCORD_BOT_TOKEN", "").strip()
    if tok:
        return tok
    try:
        with open(TOKEN_FILE, "r") as f:
            return f.read().strip()
    except OSError:
        return ""


def avatar_url(author):
    aid, av = author.get("id", ""), author.get("avatar")
    return (f"https://cdn.discordapp.com/avatars/{aid}/{av}.png?size=64"
            if aid and av else "")


def _color_hex(c):
    return ("#%06x" % (c & 0xFFFFFF)) if c else ""


def pack_embeds(embeds):
    out = []
    for e in embeds or []:
        out.append({
            "title":       e.get("title", ""),
            "url":         e.get("url", ""),
            "description": e.get("description", ""),
            "color":       _color_hex(e.get("color")),
            "author":      (e.get("author") or {}).get("name", ""),
            "footer":      (e.get("footer") or {}).get("text", ""),
            "thumb":       (e.get("thumbnail") or {}).get("url", ""),
            "image":       (e.get("image") or {}).get("url", ""),
            "fields": [{"name": f.get("name", ""), "value": f.get("value", ""),
                        "inline": bool(f.get("inline"))}
                       for f in e.get("fields", [])],
        })
    return out


def pack_buttons(components):
    out = []
    for row in components or []:
        for c in row.get("components", []):
            if c.get("type") == 2:                     # bouton
                emoji = (c.get("emoji") or {}).get("name", "")
                out.append({
                    "label":     c.get("label", "") or emoji or "•",
                    "style":     c.get("style", 2),    # 5 = lien
                    "url":       c.get("url", ""),
                    "custom_id": c.get("custom_id", ""),
                })
    return out


def pack_message(m, self_id, parent_id="", thread_name="", hist=False):
    author = m.get("author", {})
    return {
        "t": "msg",
        "id": m.get("id", ""),
        "channel_id": m.get("channel_id", ""),
        "parent_id": parent_id,          # salon parent si thread, sinon ""
        "thread": thread_name,
        "author": author.get("global_name") or author.get("username", "?"),
        "author_id": author.get("id", ""),
        "avatar": avatar_url(author),
        "content": m.get("content", ""),
        "embeds": pack_embeds(m.get("embeds")),
        "buttons": pack_buttons(m.get("components")),
        "ts": m.get("timestamp", ""),
        "self": author.get("id", "") == self_id,
        "hist": hist,
    }


async def _get(session, headers, path):
    async with session.get(f"{API}{path}", headers=headers) as r:
        return await r.json() if r.status == 200 else None


# ── Modes one-shot ───────────────────────────────────────────────────────────
async def send_message(text, target):
    token = load_token()
    if not token:
        emit({"t": "error", "msg": "no-token"})
        return 1
    if not target:
        emit({"t": "error", "msg": "no-target"})
        return 1

    # Commande locale ?
    if text.startswith("/"):
        parts = text.split(None, 1)
        fn = LOCAL_COMMANDS.get(parts[0].lower())
        if fn is None:
            text = f"❔ commande inconnue : {parts[0]}"
        else:
            text = fn(parts[1] if len(parts) > 1 else "")
            if not text:
                return 0

    headers = {"Authorization": f"Bot {token}",
               "Content-Type": "application/json"}
    async with aiohttp.ClientSession() as s:
        async with s.post(f"{API}/channels/{target}/messages",
                          headers=headers, json={"content": text}) as r:
            if r.status in (200, 201):
                return 0
            emit({"t": "error", "msg": f"send-failed:{r.status}"})
            return 1


async def trigger_download(custom_id):
    """POST le customId du bouton à l'endpoint /dl de bot.js (auto best version)."""
    try:
        async with aiohttp.ClientSession() as s:
            async with s.post(f"{BOT_API}/dl",
                              headers={"X-Token": DL_SECRET,
                                       "Content-Type": "application/json"},
                              json={"customId": custom_id},
                              timeout=aiohttp.ClientTimeout(total=40)) as r:
                try:
                    body = await r.json()
                except Exception:
                    body = {}
                ok = bool(body.get("ok"))
                emit({"t": "dl", "ok": ok,
                      "msg": body.get("message") or body.get("error", "")
                      or ("ok" if ok else "échec")})
                return 0 if ok else 1
    except Exception as e:
        emit({"t": "dl", "ok": False, "msg": f"api:{type(e).__name__}"})
        return 1


async def history(channel_id, limit=40):
    token = load_token()
    if not token:
        emit({"t": "error", "msg": "no-token"})
        return 1
    headers = {"Authorization": f"Bot {token}"}
    async with aiohttp.ClientSession() as s:
        msgs = await _get(s, headers,
                          f"/channels/{channel_id}/messages?limit={limit}")
    if msgs is None:
        emit({"t": "error", "msg": "history-failed"})
        return 1
    for m in reversed(msgs):
        emit(pack_message(m, "", hist=True))
    emit({"t": "history-end", "channel": channel_id})
    return 0


# ── Mode écoute (Gateway) ────────────────────────────────────────────────────
async def emit_channels(session, headers):
    chans = await _get(session, headers, f"/guilds/{GUILD_ID}/channels")
    if not chans:
        emit({"t": "error", "msg": "channels-failed"})
        return
    out = [{"id": c["id"], "name": c.get("name", ""),
            "pos": c.get("position", 0)}
           for c in chans if c.get("type") in TEXT_TYPES]
    out.sort(key=lambda c: c["pos"])
    emit({"t": "channels", "list": out})


async def discover_threads(session, headers, state):
    active = await _get(session, headers, f"/guilds/{GUILD_ID}/threads/active")
    for th in (active or {}).get("threads", []):
        state["threads"][th["id"]] = (th.get("name", ""),
                                      th.get("parent_id", ""))


async def resolve_thread(session, headers, state, cid):
    if cid in state["not_thread"]:
        return None
    ch = await _get(session, headers, f"/channels/{cid}")
    if ch and ch.get("type") in THREAD_TYPES:
        info = (ch.get("name", ""), ch.get("parent_id", ""))
        state["threads"][cid] = info
        return info
    state["not_thread"].add(cid)
    return None


async def heartbeat(ws, interval, state):
    while True:
        await asyncio.sleep(interval / 1000)
        try:
            await ws.send(json.dumps({"op": 1, "d": state.get("seq")}))
        except Exception:
            return


async def handle_dispatch(session, headers, state, d_all):
    t = d_all.get("t")
    d = d_all.get("d", {})

    if t == "READY":
        state["self_id"] = d.get("user", {}).get("id", "")
        if not state.get("init"):
            await emit_channels(session, headers)
            await discover_threads(session, headers, state)
            state["init"] = True
        emit({"t": "ready", "user": d.get("user", {}).get("username", "")})

    elif t in ("THREAD_CREATE", "THREAD_UPDATE"):
        state["threads"][d["id"]] = (d.get("name", ""), d.get("parent_id", ""))
        if t == "THREAD_CREATE":
            emit({"t": "thread", "id": d["id"], "name": d.get("name", ""),
                  "parent": d.get("parent_id", "")})
    elif t == "THREAD_DELETE":
        state["threads"].pop(d.get("id", ""), None)
    elif t == "THREAD_LIST_SYNC":
        for th in d.get("threads", []):
            state["threads"][th["id"]] = (th.get("name", ""),
                                          th.get("parent_id", ""))

    elif t == "MESSAGE_CREATE":
        cid = d.get("channel_id", "")
        if cid in state["threads"]:
            name, parent = state["threads"][cid]
            emit(pack_message(d, state["self_id"], parent, name))
        else:
            info = await resolve_thread(session, headers, state, cid)
            if info:
                emit(pack_message(d, state["self_id"], info[1], info[0]))
            else:
                emit(pack_message(d, state["self_id"]))


async def gateway_once(session, headers, state):
    async with websockets.connect(GATEWAY_URL, max_size=None) as ws:
        hello = json.loads(await ws.recv())
        hb = asyncio.create_task(
            heartbeat(ws, hello["d"]["heartbeat_interval"], state))
        await ws.send(json.dumps({
            "op": 2,
            "d": {"token": state["token"], "intents": INTENTS,
                  "properties": {"os": "linux", "browser": "quickshell",
                                 "device": "quickshell"}},
        }))
        try:
            async for raw in ws:
                data = json.loads(raw)
                if data.get("s") is not None:
                    state["seq"] = data["s"]
                op = data.get("op")
                if op == 1:
                    await ws.send(json.dumps({"op": 1, "d": state.get("seq")}))
                elif op in (7, 9):
                    return
                elif op == 0:
                    await handle_dispatch(session, headers, state, data)
        finally:
            hb.cancel()


async def listen():
    token = load_token()
    if not token:
        emit({"t": "error", "msg": "no-token"})
        return
    headers = {"Authorization": f"Bot {token}"}
    state = {"token": token, "seq": None, "self_id": "", "init": False,
             "threads": {}, "not_thread": set()}
    backoff = 2
    async with aiohttp.ClientSession() as session:
        while True:
            try:
                await gateway_once(session, headers, state)
                backoff = 2
            except Exception as e:
                emit({"t": "error", "msg": f"gateway:{type(e).__name__}"})
            await asyncio.sleep(backoff)
            backoff = min(backoff * 2, 60)


def main():
    a = sys.argv
    if len(a) >= 3 and a[1] == "--send":
        target = a[3] if len(a) >= 4 else ""
        return asyncio.run(send_message(a[2], target)) or 0 if a[2].strip() else 0
    if len(a) >= 3 and a[1] == "--history":
        return asyncio.run(history(a[2])) or 0
    if len(a) >= 3 and a[1] == "--dl":
        return asyncio.run(trigger_download(a[2])) or 0
    try:
        asyncio.run(listen())
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
