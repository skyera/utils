#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if command -v luajit >/dev/null 2>&1; then
    exec luajit "${SCRIPT_DIR}/fscp_tui.lua" "$@"
fi
echo "[ERROR] luajit is required to run fscp_tui.lua." >&2
exit 1
