#!/bin/bash
# Game Launcher toggle (daemon mode)
# The launcher now runs as a persistent (hidden) Quickshell daemon and we just
# toggle its visibility over IPC — no cold start / no cover re-decode per open.

CONFIG="game-launcher"          # ~/.config/quickshell/game-launcher/shell.qml

if pgrep -f "quickshell -c $CONFIG" > /dev/null 2>&1; then
    # Daemon already running → instant visibility toggle
    qs -c "$CONFIG" ipc call launcher toggle
else
    # First press of the session → start the daemon (hidden), then show it
    quickshell -c "$CONFIG" > /dev/null 2>&1 &
    for _ in $(seq 1 100); do          # wait up to ~5s for the IPC handler
        if qs -c "$CONFIG" ipc call launcher show > /dev/null 2>&1; then
            break
        fi
        sleep 0.05
    done
fi
