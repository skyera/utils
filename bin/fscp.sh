#!/usr/bin/env bash
# fscp.sh - Fast interactive file transfer wrapper using LuaJIT & FFI
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if command -v luajit >/dev/null 2>&1 && [ -f "$SCRIPT_DIR/fscp.lua" ]; then
    exec luajit "$SCRIPT_DIR/fscp.lua" "$@"
else
    echo "[ERROR] 'luajit' is required to run fscp.lua." >&2
    exit 1
fi
