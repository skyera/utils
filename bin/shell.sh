#!/usr/bin/env bash
# Alacritty dynamic shell switcher for Windows (Git Bash / MSYS2 / Cygwin), Linux, macOS, WSL

NEW_WINDOW=0
SHOW_CURRENT=0
EXEC_SHELL=0
QUERY=""

show_help() {
    echo "Usage: shell [OPTIONS] [SHELL_NAME]"
    echo ""
    echo "Switch Alacritty's default shell dynamically or launch a new window."
    echo ""
    echo "Options:"
    echo "  -e, --exec, -i, -r         Launch/enter the selected shell in current console"
    echo "  -w, --window, -n, --new    Open a new Alacritty window with the selected shell"
    echo "  -c, --current              Display currently configured shell"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Available shell names (when installed):"
    echo "  cmd, powershell, pwsh, git-bash, bash, wsl, cygwin, nu (Windows)"
    echo "  bash, zsh, fish, sh (Linux / macOS)"
    echo ""
    echo "Examples:"
    echo "  shell                      Interactive selection via fzf"
    echo "  shell -e                   Interactive selection and launch in current console"
    echo "  shell powershell           Set default shell to Windows PowerShell"
    echo "  shell -e git-bash          Enter Git Bash immediately"
    echo "  shell -w wsl               Open new WSL window immediately"
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        -e|--exec|-i|--interactive|-r|--run)
            EXEC_SHELL=1
            shift
            ;;
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

if [ "$IS_WINDOWS" -eq 1 ]; then
    if [ -n "$APPDATA" ]; then
        if command -v cygpath >/dev/null 2>&1; then
            ALACRITTY_DIR="$(cygpath -u "$APPDATA")/alacritty"
        else
            ALACRITTY_DIR="${APPDATA//\\//}/alacritty"
        fi
    else
        ALACRITTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/alacritty"
    fi
else
    ALACRITTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/alacritty"
fi

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
# Format per item: key|toml_prog|toml_args|exec_prog|exec_args|label
AVAILABLE_SHELLS=()

add_shell() {
    local key="$1"
    local toml_prog="$2"
    local toml_args="$3"
    local exec_prog="$4"
    local exec_args="$5"
    local label="$6"
    AVAILABLE_SHELLS+=("$key|$toml_prog|$toml_args|$exec_prog|$exec_args|$label")
}

if [ "$IS_WINDOWS" -eq 1 ]; then
    # 1. CMD
    add_shell "cmd" "cmd.exe" "" "cmd.exe" "" "Command Prompt"

    # 2. PowerShell
    if command -v powershell.exe >/dev/null 2>&1 || command -v powershell >/dev/null 2>&1; then
        add_shell "powershell" "powershell.exe" '"-NoLogo"' "powershell.exe" "-NoLogo" "Windows PowerShell (5.1)"
    fi

    # 3. PowerShell 7+ (pwsh)
    if command -v pwsh.exe >/dev/null 2>&1 || command -v pwsh >/dev/null 2>&1; then
        add_shell "pwsh" "pwsh.exe" '"-NoLogo"' "pwsh.exe" "-NoLogo" "PowerShell 7+ (pwsh)"
    elif [ -f "/c/Program Files/PowerShell/7/pwsh.exe" ]; then
        add_shell "pwsh" "C:\\Program Files\\PowerShell\\7\\pwsh.exe" '"-NoLogo"' "/c/Program Files/PowerShell/7/pwsh.exe" "-NoLogo" "PowerShell 7+ (pwsh)"
    fi

    # 4. Git Bash
    GIT_BASH_WIN=""
    GIT_BASH_EXEC=""
    if [ -f "/c/Program Files/Git/bin/bash.exe" ]; then
        GIT_BASH_WIN="C:\\Program Files\\Git\\bin\\bash.exe"
        GIT_BASH_EXEC="/c/Program Files/Git/bin/bash.exe"
    elif [ -f "/c/Program Files (x86)/Git/bin/bash.exe" ]; then
        GIT_BASH_WIN="C:\\Program Files (x86)\\Git\\bin\\bash.exe"
        GIT_BASH_EXEC="/c/Program Files (x86)/Git/bin/bash.exe"
    elif command -v bash >/dev/null 2>&1; then
        GIT_BASH_EXEC="$(command -v bash)"
        if command -v cygpath >/dev/null 2>&1; then
            GIT_BASH_WIN="$(cygpath -w "$GIT_BASH_EXEC" | sed 's/\\/\\\\/g')"
        else
            GIT_BASH_WIN="$GIT_BASH_EXEC"
        fi
    fi
    if [ -n "$GIT_BASH_WIN" ]; then
        add_shell "git-bash" "$GIT_BASH_WIN" '"--login", "-i"' "$GIT_BASH_EXEC" "--login -i" "Git Bash"
        add_shell "bash" "$GIT_BASH_WIN" '"--login", "-i"' "$GIT_BASH_EXEC" "--login -i" "Git Bash (alias)"
    fi

    # 5. WSL
    if command -v wsl.exe >/dev/null 2>&1 || command -v wsl >/dev/null 2>&1; then
        add_shell "wsl" "wsl.exe" '"~"' "wsl.exe" "~" "Windows Subsystem for Linux (WSL)"
    fi

    # 6. Cygwin
    if [ -f "/c/cygwin64/bin/bash.exe" ]; then
        add_shell "cygwin" "C:\\cygwin64\\bin\\bash.exe" '"--login", "-i"' "/c/cygwin64/bin/bash.exe" "--login -i" "Cygwin Bash (64-bit)"
    elif [ -f "/c/cygwin/bin/bash.exe" ]; then
        add_shell "cygwin" "C:\\cygwin\\bin\\bash.exe" '"--login", "-i"' "/c/cygwin/bin/bash.exe" "--login -i" "Cygwin Bash (32-bit)"
    fi

    # 7. Nushell
    if command -v nu.exe >/dev/null 2>&1 || command -v nu >/dev/null 2>&1; then
        add_shell "nu" "nu.exe" "" "nu.exe" "" "Nushell"
    fi
else
    # POSIX / Linux / macOS
    for sh_path in $(grep '^/' /etc/shells 2>/dev/null); do
        if [ -x "$sh_path" ]; then
            sh_name="$(basename "$sh_path")"
            add_shell "$sh_name" "$sh_path" "" "$sh_path" "" "$sh_name ($sh_path)"
        fi
    done

    if [ ${#AVAILABLE_SHELLS[@]} -eq 0 ]; then
        for sh_name in bash zsh fish sh; do
            sh_path="$(command -v "$sh_name" 2>/dev/null)"
            if [ -n "$sh_path" ]; then
                add_shell "$sh_name" "$sh_path" "" "$sh_path" "" "$sh_name ($sh_path)"
            fi
        done
    fi
fi

SELECTED_KEY=""
SELECTED_TOML_PROG=""
SELECTED_TOML_ARGS=""
SELECTED_EXEC_PROG=""
SELECTED_EXEC_ARGS=""
SELECTED_LABEL=""

match_shell() {
    local target="$1"
    local t_lower="$(echo "$target" | tr '[:upper:]' '[:lower:]')"
    for item in "${AVAILABLE_SHELLS[@]}"; do
        IFS='|' read -r k tp ta ep ea lbl <<< "$item"
        local k_lower="$(echo "$k" | tr '[:upper:]' '[:lower:]')"
        if [ "$t_lower" = "$k_lower" ]; then
            SELECTED_KEY="$k"
            SELECTED_TOML_PROG="$tp"
            SELECTED_TOML_ARGS="$ta"
            SELECTED_EXEC_PROG="$ep"
            SELECTED_EXEC_ARGS="$ea"
            SELECTED_LABEL="$lbl"
            return 0
        fi
    done
    # Partial prefix match
    for item in "${AVAILABLE_SHELLS[@]}"; do
        IFS='|' read -r k tp ta ep ea lbl <<< "$item"
        local k_lower="$(echo "$k" | tr '[:upper:]' '[:lower:]')"
        if [[ "$k_lower" == *"$t_lower"* ]]; then
            SELECTED_KEY="$k"
            SELECTED_TOML_PROG="$tp"
            SELECTED_TOML_ARGS="$ta"
            SELECTED_EXEC_PROG="$ep"
            SELECTED_EXEC_ARGS="$ea"
            SELECTED_LABEL="$lbl"
            return 0
        fi
    done
    return 1
}

if [ -n "$QUERY" ]; then
    if ! match_shell "$QUERY"; then
        echo "[ERROR] Shell '$QUERY' not found or not installed." >&2
        echo "Available shells:" >&2
        for item in "${AVAILABLE_SHELLS[@]}"; do
            IFS='|' read -r k tp ta ep ea lbl <<< "$item"
            echo "  - $k ($lbl)" >&2
        done
        exit 1
    fi
else
    if command -v fzf >/dev/null 2>&1; then
        choice=$(printf '%s\n' "${AVAILABLE_SHELLS[@]}" | awk -F'|' '{printf "%s\t%s\t%s\n", $1, $6, $2}' | \
            fzf --prompt="Select Alacritty Shell > " --with-nth=1,2 --delimiter="\t" --layout=reverse --height=40% --border --header="TAB: key / description" --no-preview)
        if [ -n "$choice" ]; then
            sel_key=$(echo "$choice" | awk -F'\t' '{print $1}')
            match_shell "$sel_key"
        fi
    else
        echo "Available Alacritty Shells:"
        idx=1
        for item in "${AVAILABLE_SHELLS[@]}"; do
            IFS='|' read -r k tp ta ep ea lbl <<< "$item"
            printf "  %d. %s - %s [%s]\n" "$idx" "$k" "$lbl" "$tp"
            ((idx++))
        done
        read -r -p "Select shell number or name: " input
        if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 1 ] && [ "$input" -le "${#AVAILABLE_SHELLS[@]}" ]; then
            IFS='|' read -r k tp ta ep ea lbl <<< "${AVAILABLE_SHELLS[$((input-1))]}"
            SELECTED_KEY="$k"
            SELECTED_TOML_PROG="$tp"
            SELECTED_TOML_ARGS="$ta"
            SELECTED_EXEC_PROG="$ep"
            SELECTED_EXEC_ARGS="$ea"
            SELECTED_LABEL="$lbl"
        elif [ -n "$input" ]; then
            match_shell "$input"
        fi
    fi
fi

if [ -z "$SELECTED_KEY" ]; then
    echo "No shell selected."
    exit 0
fi

# Write shell.toml
mkdir -p "$ALACRITTY_DIR" 2>/dev/null
TMP_CONFIG="$(mktemp "${TMPDIR:-/tmp}/alacritty_shell_XXXXXX.toml")"
{
    echo "[terminal.shell]"
    echo "program = \"$SELECTED_TOML_PROG\""
    if [ -n "$SELECTED_TOML_ARGS" ]; then
        echo "args = [$SELECTED_TOML_ARGS]"
    fi
} > "$TMP_CONFIG"

cp -f "$TMP_CONFIG" "$TARGET_FILE"
if [ -d "$SCRIPT_DIR/../.config/alacritty" ]; then
    cp -f "$TMP_CONFIG" "$REPO_TARGET" 2>/dev/null || true
fi
rm -f "$TMP_CONFIG" 2>/dev/null

echo "[Alacritty] Default shell set to: $SELECTED_KEY ($SELECTED_LABEL)"

if [ "$NEW_WINDOW" -eq 1 ]; then
    if command -v alacritty >/dev/null 2>&1; then
        if [ -n "$SELECTED_EXEC_ARGS" ]; then
            alacritty msg create-window -e "$SELECTED_TOML_PROG" $SELECTED_EXEC_ARGS 2>/dev/null || alacritty -e "$SELECTED_TOML_PROG" $SELECTED_EXEC_ARGS &
        else
            alacritty msg create-window -e "$SELECTED_TOML_PROG" 2>/dev/null || alacritty -e "$SELECTED_TOML_PROG" &
        fi
        echo "[Alacritty] Opened new window with $SELECTED_KEY."
    fi
fi

if [ "$EXEC_SHELL" -eq 1 ]; then
    if [ -n "$SELECTED_EXEC_ARGS" ]; then
        exec "$SELECTED_EXEC_PROG" $SELECTED_EXEC_ARGS
    else
        exec "$SELECTED_EXEC_PROG"
    fi
fi
