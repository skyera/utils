#!/usr/bin/env bash
# Alacritty dynamic shell switcher for Linux / macOS / WSL

NEW_WINDOW=0
SHOW_CURRENT=0
QUERY=""

show_help() {
    echo "Usage: shell [OPTIONS] [SHELL_NAME]"
    echo ""
    echo "Switch Alacritty's default shell dynamically or launch a new window."
    echo ""
    echo "Options:"
    echo "  -w, --window, -n, --new    Open a new Alacritty window with the selected shell"
    echo "  -c, --current              Display currently configured shell"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  shell                      Interactive selection via fzf"
    echo "  shell bash                 Set default shell to bash"
    echo "  shell zsh                  Set default shell to zsh"
    echo "  shell fish                 Set default shell to fish"
    echo "  shell -w zsh               Open new zsh window immediately"
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        -w|--window|-n|--new)
            NEW_WINDOW=1
            shift
            ;;
        -c|--current)
            SHOW_CURRENT=1
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            if [ -z "$QUERY" ]; then
                QUERY="$1"
            fi
            shift
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALACRITTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/alacritty"
TARGET_FILE="$ALACRITTY_DIR/shell.toml"
REPO_TARGET="$SCRIPT_DIR/../.config/alacritty/shell.toml"

if [ "$SHOW_CURRENT" -eq 1 ]; then
    if [ -f "$TARGET_FILE" ]; then
        echo "Current Alacritty shell config ($TARGET_FILE):"
        cat "$TARGET_FILE"
    else
        echo "[INFO] No shell.toml found at $TARGET_FILE. Using default shell."
    fi
    exit 0
fi

# Detect available shells
AVAILABLE_SHELLS=()
for sh_path in $(grep '^/' /etc/shells 2>/dev/null); do
    if [ -x "$sh_path" ]; then
        AVAILABLE_SHELLS+=("$(basename "$sh_path")|$sh_path")
    fi
done

# If /etc/shells was not found or empty, fallback to common shells
if [ ${#AVAILABLE_SHELLS[@]} -eq 0 ]; then
    for sh_name in bash zsh fish sh; do
        sh_path="$(command -v "$sh_name" 2>/dev/null)"
        if [ -n "$sh_path" ]; then
            AVAILABLE_SHELLS+=("$sh_name|$sh_path")
        fi
    done
fi

SELECTED_NAME=""
SELECTED_PATH=""

if [ -n "$QUERY" ]; then
    for item in "${AVAILABLE_SHELLS[@]}"; do
        name="${item%%|*}"
        path="${item##*|}"
        if [ "$QUERY" = "$name" ] || [ "$QUERY" = "$path" ]; then
            SELECTED_NAME="$name"
            SELECTED_PATH="$path"
            break
        fi
    done
    if [ -z "$SELECTED_NAME" ]; then
        echo "[ERROR] Shell '$QUERY' not found or not executable." >&2
        echo "Available shells:" >&2
        for item in "${AVAILABLE_SHELLS[@]}"; do
            echo "  - ${item%%|*} (${item##*|})" >&2
        done
        exit 1
    fi
else
    if command -v fzf >/dev/null 2>&1; then
        choice=$(printf '%s\n' "${AVAILABLE_SHELLS[@]}" | tr '|' '\t' | fzf --prompt="Select Alacritty Shell > " --with-nth=1 --layout=reverse --height=40% --border --preview="echo Shell Path: {2}")
        if [ -n "$choice" ]; then
            SELECTED_NAME=$(echo "$choice" | awk '{print $1}')
            SELECTED_PATH=$(echo "$choice" | awk '{print $2}')
        fi
    else
        echo "Available Alacritty Shells:"
        idx=1
        for item in "${AVAILABLE_SHELLS[@]}"; do
            echo "  $idx) ${item%%|*} (${item##*|})"
            ((idx++))
        done
        read -r -p "Select shell number or name: " input
        if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 1 ] && [ "$input" -le "${#AVAILABLE_SHELLS[@]}" ]; then
            selected_item="${AVAILABLE_SHELLS[$((input-1))]}"
            SELECTED_NAME="${selected_item%%|*}"
            SELECTED_PATH="${selected_item##*|}"
        elif [ -n "$input" ]; then
            for item in "${AVAILABLE_SHELLS[@]}"; do
                if [ "$input" = "${item%%|*}" ]; then
                    SELECTED_NAME="${item%%|*}"
                    SELECTED_PATH="${item##*|}"
                    break
                fi
            done
        fi
    fi
fi

if [ -z "$SELECTED_NAME" ]; then
    echo "No shell selected."
    exit 0
fi

# Write shell.toml
mkdir -p "$ALACRITTY_DIR" 2>/dev/null
cat <<EOF > "$TARGET_FILE"
[terminal.shell]
program = "$SELECTED_PATH"
EOF

if [ -d "$SCRIPT_DIR/../.config/alacritty" ]; then
    cp -f "$TARGET_FILE" "$REPO_TARGET" 2>/dev/null || true
fi

echo "[Alacritty] Default shell set to: $SELECTED_NAME ($SELECTED_PATH)"

if [ "$NEW_WINDOW" -eq 1 ]; then
    if command -v alacritty >/dev/null 2>&1; then
        alacritty msg create-window -e "$SELECTED_PATH" 2>/dev/null || alacritty -e "$SELECTED_PATH" &
        echo "[Alacritty] Opened new window with $SELECTED_NAME."
    fi
fi
