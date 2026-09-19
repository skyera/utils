#!/bin/sh
# dotag.sh - Launch dotag.lua via LuaJIT
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec luajit "$SCRIPT_DIR/dotag.lua" "$@"
