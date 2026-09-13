#!/bin/sh
# rbrowse.sh - Launch rbrowse.lua via LuaJIT
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec luajit "$SCRIPT_DIR/rbrowse.lua" "$@"
