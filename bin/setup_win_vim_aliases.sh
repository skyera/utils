#!/usr/bin/env bash

echo "========================================================"
echo "         CONFIGURING WINDOWS VIM ALIASES ONLY           "
echo "========================================================"

WINDOWS_VIM=""

# 1. First Method: Check if a Windows vim.exe is in the System PATH (ignoring Git Bash built-in)
if command -v vim.exe >/dev/null 2>&1; then
    PATH_VIM=$(which vim.exe)
    if [[ "$PATH_VIM" != /usr/bin/* && "$PATH_VIM" != /bin/* ]]; then
        WINDOWS_VIM="$PATH_VIM"
    fi
fi

# 2. Second Method (Primary Auto-Find): Query Windows Registry App Paths (HKLM then HKCU)
if [ -z "$WINDOWS_VIM" ]; then
    for hive in "HKLM" "HKCU"; do
        REG_VAL=$(reg.exe query "${hive}\Software\Microsoft\Windows\CurrentVersion\App Paths\vim.exe" /ve 2>/dev/null)
        if [ $? -eq 0 ]; then
            # Extract the raw Windows path to vim.exe
            RAW_PATH=$(echo "$REG_VAL" | grep -o '[A-Za-z]:\\.*\.exe')
            if [ -n "$RAW_PATH" ]; then
                # Convert Windows path (C:\...) to POSIX path (/c/...)
                POSIX_PATH=$(cygpath -u "$RAW_PATH")
                if [ -f "$POSIX_PATH" ]; then
                    WINDOWS_VIM="$POSIX_PATH"
                    break
                fi
            fi
        fi
    done
fi

# 3. Third Method: Scan standard installation directories (sorted to get newest version)
if [ -z "$WINDOWS_VIM" ]; then
    for path in $(ls -d "/c/Program Files/Vim"/vim*/vim.exe "/c/Program Files (x86)/Vim"/vim*/vim.exe "/c/tools/vim"/vim*/vim.exe 2>/dev/null | sort -r); do
        if [ -f "$path" ]; then
            WINDOWS_VIM="$path"
            break
        fi
    done
fi

# 4. Fourth Method: Fallback to manual user input
if [ -z "$WINDOWS_VIM" ]; then
    echo "Error: Could not automatically locate vim.exe in standard paths or Registry."
    read -rp "Please enter the absolute path to your Windows vim.exe: " USER_PATH
    if [ -f "$USER_PATH" ]; then
        WINDOWS_VIM="$USER_PATH"
    else
        echo "Error: File does not exist at $USER_PATH."
        exit 1
    fi
fi

echo "Found Windows Vim at: $WINDOWS_VIM"

# 5. Define active shell config file (~/.bashrc)
CONFIG_FILE="$HOME/.bashrc"

echo "Updating Git Bash aliases inside $CONFIG_FILE..."

# Clean up existing vim aliases to prevent duplicates
sed -i '/alias vim=/d' "$CONFIG_FILE" 2>/dev/null
sed -i '/alias vi=/d' "$CONFIG_FILE" 2>/dev/null
sed -i '/alias vimdiff=/d' "$CONFIG_FILE" 2>/dev/null

# Append the new aliases using winpty for full terminal interactivity
echo "alias vim='winpty \"$WINDOWS_VIM\"'" >> "$CONFIG_FILE"
echo "alias vi='winpty \"$WINDOWS_VIM\"'" >> "$CONFIG_FILE"
echo "alias vimdiff='winpty \"$WINDOWS_VIM\" -d'" >> "$CONFIG_FILE"

echo "--------------------------------------------------------"
echo "Success! Aliases configured in $CONFIG_FILE."
echo "Please restart Git Bash or run: source $CONFIG_FILE"
echo "--------------------------------------------------------"
