#!/usr/bin/env bash
# Alacritty dynamic theme switcher for Linux / macOS / WSL

WINDOW_ONLY=0
QUERY=""

show_help() {
    echo "Usage: theme [OPTIONS] [THEME_NAME]"
    echo ""
    echo "Options:"
    echo "  -w, --window, -l, --local  Apply theme to current window only (via OSC sequences)"
    echo "  -h, --help                 Show this help message"
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        -w|--window|-l|--local)
            WINDOW_ONLY=1
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
THEMES_DIR="$ALACRITTY_DIR/themes"
TARGET_FILE="$ALACRITTY_DIR/theme.toml"

# Fallback to repo directory if not deployed
if [ ! -d "$THEMES_DIR" ]; then
    REPO_THEMES="$SCRIPT_DIR/../.config/alacritty/themes"
    if [ -d "$REPO_THEMES" ]; then
        THEMES_DIR="$REPO_THEMES"
        mkdir -p "$ALACRITTY_DIR" 2>/dev/null
    fi
fi

if [ ! -d "$THEMES_DIR" ]; then
    echo "[ERROR] Alacritty themes directory not found at $THEMES_DIR" >&2
    exit 1
fi

SELECTED_THEME=""

if [ -n "$QUERY" ]; then
    if [ -f "$THEMES_DIR/$QUERY.toml" ]; then
        SELECTED_THEME="$QUERY"
    elif [ -f "$THEMES_DIR/$QUERY" ]; then
        SELECTED_THEME="$(basename "$QUERY" .toml)"
    else
        MATCH=$(find "$THEMES_DIR" -maxdepth 1 -iname "*$QUERY*.toml" -print -quit)
        if [ -n "$MATCH" ]; then
            SELECTED_THEME="$(basename "$MATCH" .toml)"
        fi
    fi

    if [ -z "$SELECTED_THEME" ]; then
        echo "[ERROR] Theme '$QUERY' not found in $THEMES_DIR" >&2
        echo "Available themes:"
        find "$THEMES_DIR" -maxdepth 1 -name "*.toml" -exec basename {} .toml \; | sort | sed 's/^/  - /'
        exit 1
    fi
else
    if command -v fzf >/dev/null 2>&1; then
        SELECTED_THEME=$(find "$THEMES_DIR" -maxdepth 1 -name "*.toml" -exec basename {} .toml \; | sort | \
            fzf --prompt="Select Alacritty Theme > " \
                --preview="cat '$THEMES_DIR/{}.toml' 2>/dev/null" \
                --layout=reverse --height=40% --border)
    else
        echo "Available Alacritty Themes:"
        themes=($(find "$THEMES_DIR" -maxdepth 1 -name "*.toml" -exec basename {} .toml \; | sort))
        for i in "${!themes[@]}"; do
            printf "  %d. %s\n" "$((i+1))" "${themes[$i]}"
        done
        read -rp "Select theme number or name: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#themes[@]}" ]; then
            SELECTED_THEME="${themes[$((choice-1))]}"
        else
            SELECTED_THEME="$choice"
        fi
    fi
fi

if [ -z "$SELECTED_THEME" ]; then
    echo "No theme selected."
    exit 0
fi

SRC_FILE="$THEMES_DIR/$SELECTED_THEME.toml"
if [ ! -f "$SRC_FILE" ]; then
    echo "[ERROR] Theme file '$SRC_FILE' does not exist." >&2
    exit 1
fi

apply_osc() {
    local theme_file="$1"
    local section=""
    local esc=$'\033'

    while IFS='=' read -r raw_key raw_val || [ -n "$raw_key" ]; do
        # Strip comments
        raw_key="${raw_key%%#*}"
        raw_val="${raw_val%%#*}"
        local key="$(echo "$raw_key" | tr -d '[:space:]')"
        local val="$(echo "$raw_val" | tr -d '[:space:]' | tr -d '"' | tr -d "'")"

        if [[ "$key" =~ ^\[.*\]$ ]]; then
            section="$key"
            continue
        fi

        [ -z "$val" ] && continue

        case "$section" in
            "[colors.primary]")
                [ "$key" = "background" ] && printf "%s]11;%s%s\\" "$esc" "$val" "$esc"
                [ "$key" = "foreground" ] && printf "%s]10;%s%s\\" "$esc" "$val" "$esc"
                ;;
            "[colors.cursor]")
                [ "$key" = "cursor" ]     && printf "%s]12;%s%s\\" "$esc" "$val" "$esc"
                ;;
            "[colors.normal]")
                case "$key" in
                    black)   printf "%s]4;0;%s%s\\" "$esc" "$val" "$esc" ;;
                    red)     printf "%s]4;1;%s%s\\" "$esc" "$val" "$esc" ;;
                    green)   printf "%s]4;2;%s%s\\" "$esc" "$val" "$esc" ;;
                    yellow)  printf "%s]4;3;%s%s\\" "$esc" "$val" "$esc" ;;
                    blue)    printf "%s]4;4;%s%s\\" "$esc" "$val" "$esc" ;;
                    magenta) printf "%s]4;5;%s%s\\" "$esc" "$val" "$esc" ;;
                    cyan)    printf "%s]4;6;%s%s\\" "$esc" "$val" "$esc" ;;
                    white)   printf "%s]4;7;%s%s\\" "$esc" "$val" "$esc" ;;
                esac
                ;;
            "[colors.bright]")
                case "$key" in
                    black)   printf "%s]4;8;%s%s\\" "$esc" "$val" "$esc" ;;
                    red)     printf "%s]4;9;%s%s\\" "$esc" "$val" "$esc" ;;
                    green)   printf "%s]4;10;%s%s\\" "$esc" "$val" "$esc" ;;
                    yellow)  printf "%s]4;11;%s%s\\" "$esc" "$val" "$esc" ;;
                    blue)    printf "%s]4;12;%s%s\\" "$esc" "$val" "$esc" ;;
                    magenta) printf "%s]4;13;%s%s\\" "$esc" "$val" "$esc" ;;
                    cyan)    printf "%s]4;14;%s%s\\" "$esc" "$val" "$esc" ;;
                    white)   printf "%s]4;15;%s%s\\" "$esc" "$val" "$esc" ;;
                esac
                ;;
        esac
    done < "$theme_file"
}

if [ "$WINDOW_ONLY" -eq 1 ]; then
    apply_osc "$SRC_FILE"
    echo "[Alacritty] Switched current window theme to: $SELECTED_THEME"
    exit 0
fi

mkdir -p "$ALACRITTY_DIR"
cp -f "$SRC_FILE" "$TARGET_FILE"
echo "[Alacritty] Switched theme to: $SELECTED_THEME"

# Also update repo target if running from repo
if [ -d "$SCRIPT_DIR/../.config/alacritty" ]; then
    cp -f "$SRC_FILE" "$SCRIPT_DIR/../.config/alacritty/theme.toml" 2>/dev/null || true
fi
