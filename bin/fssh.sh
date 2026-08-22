#!/usr/bin/env bash
# fssh.sh - Shell wrapper for fssh (Git Bash / WSL / Linux / macOS)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PY_BIN=""
for candidate in python python3 py; do
    if command -v "$candidate" >/dev/null 2>&1; then
        if "$candidate" -c "import sys; sys.exit(0)" >/dev/null 2>&1; then
            PY_BIN="$candidate"
            break
        fi
    fi
done

if [ -z "$PY_BIN" ]; then
    for candidate in /c/app/miniforge3/python.exe /c/Python3*/python.exe /c/Program\ Files/Python3*/python.exe; do
        if [ -x "$candidate" ] || [ -f "$candidate" ]; then
            PY_BIN="$candidate"
            break
        fi
    done
fi

if [ -n "$PY_BIN" ]; then
    exec "$PY_BIN" "$SCRIPT_DIR/fssh.py" "$@"
else
    echo "[ERROR] Working Python 3 interpreter not found to run fssh." >&2
    exit 1
fi
