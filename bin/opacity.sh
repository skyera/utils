#!/usr/bin/env bash
# Alacritty dynamic opacity switcher for Linux, macOS, WSL, and Windows (Git Bash / MSYS2 / Cygwin)

WINDOW_ONLY=0
SHOW_CURRENT=0
ACTION=""
ARG1=""
ARG2=""
DEFAULT_OPACITY="0.93"

show_help() {
    echo "Usage: opacity [OPTIONS] [VALUE | COMMAND]"
    echo ""
    echo "Dynamically change Alacritty window opacity (transparency)."
    echo ""
    echo "Commands / Values:"
    echo "  (no args)                  Interactive preset selection via fzf"
    echo "  <0.0 - 1.0>                Set exact opacity (e.g., 1.0, 0.85)"
    echo "  <0 - 100[%]>               Set opacity by percentage (e.g., 85, 85%, 100%)"
    echo "  toggle, -t, --toggle       Toggle between opaque (1.0) and default ($DEFAULT_OPACITY)"
    echo "  +, up, inc [STEP]          Increase opacity (default step: 0.05, max: 1.0)"
    echo "  -, down, dec [STEP]        Decrease opacity (default step: 0.05, min: 0.1)"
    echo "  reset, default             Reset opacity to default ($DEFAULT_OPACITY)"
    echo ""
    echo "Options:"
    echo "  -c, --current              Display current opacity value"
    echo "  -w, --window               Apply to current window only (via IPC on Unix, or new window)"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  opacity                    Interactive selection via fzf"
    echo "  opacity 1.0                Make window fully opaque"
    echo "  opacity 85%                Set opacity to 0.85"
    echo "  opacity toggle             Toggle between 1.0 and 0.93"
    echo "  opacity +                  Increase opacity by 0.05"
    echo "  opacity - 0.1              Decrease opacity by 0.10"
    echo "  opacity reset              Restore default 0.93 opacity"
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        -c|--current)
            SHOW_CURRENT=1
            shift
            ;;
        -w|--window|-l|--local)
            WINDOW_ONLY=1
            shift
            ;;
        -t|--toggle)
            ACTION="toggle"
            shift
            ;;
        *)
            if [ -z "$ARG1" ]; then
                ARG1="$1"
            elif [ -z "$ARG2" ]; then
                ARG2="$1"
            fi
            shift
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Detect environment
IS_WINDOWS=0
case "$(uname -s)" in
    CYGWIN*|MINGW*|MSYS*) IS_WINDOWS=1 ;;
    *)
        if [ -n "$APPDATA" ] || [ -n "$WINDIR" ] || [ -n "$USERPROFILE" ]; then
            IS_WINDOWS=1
        fi
        ;;
esac

if [ "$IS_WINDOWS" -eq 1 ] && [ -n "$APPDATA" ]; then
    if command -v cygpath >/dev/null 2>&1; then
        ALACRITTY_DIR="$(cygpath -u "$APPDATA")/alacritty"
    else
        ALACRITTY_DIR="${APPDATA//\\//}/alacritty"
    fi
else
    ALACRITTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/alacritty"
fi

TARGET_FILE="$ALACRITTY_DIR/alacritty.toml"
USER_CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/alacritty/alacritty.toml"
REPO_TARGET="$REPO_DIR/.config/alacritty/alacritty.toml"

# Fallback to repo config if target does not exist yet
if [ ! -f "$TARGET_FILE" ] && [ -f "$REPO_TARGET" ]; then
    mkdir -p "$ALACRITTY_DIR" 2>/dev/null
    cp -f "$REPO_TARGET" "$TARGET_FILE" 2>/dev/null
fi

if [ ! -f "$TARGET_FILE" ]; then
    echo "[ERROR] Alacritty config file not found at $TARGET_FILE" >&2
    exit 1
fi

# Read current opacity
CURRENT_OPACITY=$(awk -F'=' '/^[[:space:]]*opacity[[:space:]]*=/ {
    val = $2
    sub(/#.*/, "", val)
    gsub(/[[:space:]]/, "", val)
    print val
    exit
}' "$TARGET_FILE")

if [ -z "$CURRENT_OPACITY" ]; then
    CURRENT_OPACITY="$DEFAULT_OPACITY"
fi

if [ "$SHOW_CURRENT" -eq 1 ]; then
    echo "[Alacritty] Current opacity: $CURRENT_OPACITY"
    exit 0
fi

# Determine action from ARG1 if not already set
if [ -z "$ACTION" ] && [ -n "$ARG1" ]; then
    case "$(echo "$ARG1" | tr '[:upper:]' '[:lower:]')" in
        toggle)       ACTION="toggle" ;;
        reset|default) ACTION="reset" ;;
        +|up|inc)     ACTION="inc" ;;
        -|down|dec)   ACTION="dec" ;;
        *)            ACTION="set" ;;
    esac
fi

# Interactive selection if no action provided
if [ -z "$ACTION" ]; then
    PRESETS=(
        "1.00	(100% - Fully opaque)"
        "0.95	(95% - Slight transparency)"
        "0.93	(93% - Default)"
        "0.90	(90%)"
        "0.85	(85%)"
        "0.80	(80%)"
        "0.75	(75%)"
        "0.70	(70%)"
        "0.60	(60%)"
        "0.50	(50% - Half transparent)"
    )

    if command -v fzf >/dev/null 2>&1; then
        CHOICE=$(printf '%s\n' "${PRESETS[@]}" | \
            fzf --prompt="Select Alacritty Opacity (current: $CURRENT_OPACITY) > " \
                --layout=reverse --height=40% --border --no-preview)
        if [ -n "$CHOICE" ]; then
            ARG1=$(echo "$CHOICE" | awk '{print $1}')
        fi
    else
        echo "Available Alacritty Opacity Presets (current: $CURRENT_OPACITY):"
        for i in "${!PRESETS[@]}"; do
            printf "  %d. %s\n" "$((i+1))" "${PRESETS[$i]}"
        done
        read -r -p "Select preset number or enter opacity (0.0-1.0 / 10-100%): " input
        if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 1 ] && [ "$input" -le "${#PRESETS[@]}" ]; then
            ARG1=$(echo "${PRESETS[$((input-1))]}" | awk '{print $1}')
        else
            ARG1="$input"
        fi
    fi

    if [ -z "$ARG1" ]; then
        echo "No opacity selected."
        exit 0
    fi
    ACTION="set"
fi

STEP="${ARG2:-0.05}"

# Calculate new opacity using awk
CALC_RESULT=$(awk -v cur="$CURRENT_OPACITY" -v def="$DEFAULT_OPACITY" -v act="$ACTION" -v val="$ARG1" -v step_raw="$STEP" '
function parse_val(s, allow_pct,    is_pct, n) {
    is_pct = 0
    if (sub(/%$/, "", s)) {
        is_pct = 1
    }
    if (s !~ /^([0-9]+(\.[0-9]*)?|\.[0-9]+)$/) {
        return -1
    }
    n = s + 0.0
    if (is_pct) {
        if (n < 0 || n > 100) return -1
        return n / 100.0
    }
    if (allow_pct && n > 1.0 && n <= 100.0) {
        return n / 100.0
    }
    if (n < 0.0 || n > 1.0) return -1
    return n
}
BEGIN {
    cur_n = cur + 0.0
    def_n = def + 0.0
    if (act == "toggle") {
        res = (cur_n >= 0.999) ? def_n : 1.0
    } else if (act == "reset") {
        res = def_n
    } else if (act == "inc" || act == "dec") {
        st = parse_val(step_raw, 1)
        if (st <= 0) {
            print "ERROR:Invalid step value"
            exit 0
        }
        if (act == "inc") {
            res = cur_n + st
            if (res > 1.0) res = 1.0
        } else {
            res = cur_n - st
            if (res < 0.10) res = 0.10
        }
    } else if (act == "set") {
        res = parse_val(val, 1)
        if (res < 0) {
            print "ERROR:Invalid opacity value"
            exit 0
        }
    }
    fmt = sprintf("%.2f", res)
    if (fmt ~ /\.[0-9]0$/) {
        sub(/0$/, "", fmt)
    }
    print fmt
}')

if [[ "$CALC_RESULT" == ERROR:* ]]; then
    echo "[ERROR] ${CALC_RESULT#ERROR:}: '$ARG1'. Expected 0.0-1.0 or 0%-100%." >&2
    exit 1
fi

NEW_OPACITY="$CALC_RESULT"

if [ "$WINDOW_ONLY" -eq 1 ]; then
    if [ "$IS_WINDOWS" -eq 0 ] && command -v alacritty >/dev/null 2>&1; then
        if alacritty msg config "window.opacity=$NEW_OPACITY" 2>/dev/null; then
            echo "[Alacritty] Current window opacity set to: $NEW_OPACITY"
            exit 0
        fi
    fi
    if command -v alacritty >/dev/null 2>&1; then
        alacritty -o "window.opacity=$NEW_OPACITY" >/dev/null 2>&1 &
        echo "[Alacritty] Opened new window with opacity: $NEW_OPACITY"
        exit 0
    else
        echo "[ERROR] alacritty executable not found in PATH." >&2
        exit 1
    fi
fi

update_file() {
    local f="$1"
    [ ! -f "$f" ] && return 0
    local tmp
    tmp="$(mktemp "${TMPDIR:-/tmp}/alacritty_opacity_XXXXXX")"
    awk -v new_op="$NEW_OPACITY" '
    /^[[:space:]]*opacity[[:space:]]*=/ {
        sub(/=[[:space:]]*[0-9.]+/, "= " new_op)
    }
    { print }
    ' "$f" > "$tmp" && cp -f "$tmp" "$f"
    rm -f "$tmp" 2>/dev/null
}

update_file "$TARGET_FILE"
if [ "$USER_CONFIG_FILE" != "$TARGET_FILE" ] && [ -f "$USER_CONFIG_FILE" ]; then
    update_file "$USER_CONFIG_FILE"
fi
if [ "$REPO_TARGET" != "$TARGET_FILE" ] && [ -f "$REPO_TARGET" ]; then
    update_file "$REPO_TARGET"
fi

echo "[Alacritty] Opacity changed: $CURRENT_OPACITY -> $NEW_OPACITY"
