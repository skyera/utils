#!/usr/bin/env bash
# Launcher for fssh_tunnel.lua (SSH Port Forward & Tunnel Manager)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if command -v luajit >/dev/null 2>&1; then
    exec luajit "${SCRIPT_DIR}/fssh_tunnel.lua" "$@"
else
    echo "[ERROR] luajit is required to run fssh_tunnel.lua." >&2
    exit 1
fi
