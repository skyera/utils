#!/usr/bin/env python3
"""
putty_colors.py - Easily manage, preview, export, and apply PuTTY color schemes for Windows.

Supports 650+ color themes from:
- Preset Themes (Dracula, Nord, One Dark, Tokyo Night, Catppuccin, Gruvbox, Solarized, Monokai Pro, etc.)
- AlexAkulov/putty-color-themes (.reg files)
- mbadolato/iTerm2-Color-Schemes (putty .reg files)

Features fzf live preview integration, Windows Registry direct winreg modification,
and .reg registry patch file generation.
"""

import sys
import os
import re
import argparse
import subprocess
import shutil
from typing import Dict, List, Tuple, Optional

# Preset color themes (22 RGB entries for PuTTY Colour0..Colour21)
PRESET_THEMES: Dict[str, Dict[str, any]] = {
    "dracula": {
        "name": "Dracula",
        "author": "Zeno Rocha",
        "colors": [
            "248,248,242", "255,255,255", "40,42,54", "68,71,90",
            "40,42,54", "248,248,242", "0,0,0", "98,114,164",
            "255,85,85", "255,110,110", "80,250,123", "105,255,148",
            "241,250,140", "255,255,165", "189,147,249", "214,172,255",
            "255,121,198", "255,146,223", "139,233,253", "164,255,255",
            "191,191,191", "255,255,255"
        ]
    },
    "nord": {
        "name": "Nord",
        "author": "Arctic Ice Studio",
        "colors": [
            "216,222,233", "235,238,245", "46,52,64", "59,66,82",
            "46,52,64", "216,222,233", "59,66,82", "76,86,106",
            "191,97,106", "191,97,106", "163,190,140", "163,190,140",
            "235,203,139", "235,203,139", "129,161,193", "136,192,208",
            "180,142,173", "180,142,173", "136,192,208", "143,188,187",
            "229,233,240", "236,239,244"
        ]
    },
    "onedark": {
        "name": "One Dark",
        "author": "Atom",
        "colors": [
            "171,178,191", "220,223,228", "40,44,52", "62,68,81",
            "40,44,52", "82,139,255", "40,44,52", "92,99,112",
            "224,108,117", "224,108,117", "152,195,121", "152,195,121",
            "229,192,123", "229,192,123", "97,175,239", "97,175,239",
            "198,120,221", "198,120,221", "86,182,194", "86,182,194",
            "171,178,191", "255,255,255"
        ]
    },
    "gruvbox-dark": {
        "name": "Gruvbox Dark",
        "author": "morhetz",
        "colors": [
            "235,219,178", "251,241,199", "40,40,40", "60,56,54",
            "40,40,40", "235,219,178", "40,40,40", "146,131,116",
            "204,36,29", "251,73,52", "152,151,26", "184,187,38",
            "215,153,33", "250,189,47", "69,133,136", "131,165,152",
            "177,98,134", "211,134,155", "104,157,106", "142,192,124",
            "168,153,132", "235,219,178"
        ]
    },
    "tokyonight": {
        "name": "Tokyo Night",
        "author": "folke",
        "colors": [
            "192,202,245", "205,214,244", "26,27,38", "36,40,59",
            "26,27,38", "192,202,245", "21,22,30", "65,72,104",
            "247,118,142", "247,118,142", "158,206,106", "158,206,106",
            "224,175,104", "224,175,104", "122,162,247", "122,162,247",
            "187,154,247", "187,154,247", "125,207,255", "125,207,255",
            "169,177,214", "192,202,245"
        ]
    },
    "catppuccin-mocha": {
        "name": "Catppuccin Mocha",
        "author": "Catppuccin Org",
        "colors": [
            "205,214,244", "245,224,220", "30,30,46", "49,50,68",
            "30,30,46", "245,224,220", "69,71,90", "88,91,112",
            "243,139,168", "243,139,168", "166,227,161", "166,227,161",
            "249,226,175", "249,226,175", "137,180,250", "137,180,250",
            "245,194,231", "245,194,231", "148,226,213", "148,226,213",
            "186,194,222", "166,173,200"
        ]
    },
    "solarized-dark": {
        "name": "Solarized Dark",
        "author": "Ethan Schoonover",
        "colors": [
            "131,148,150", "147,161,161", "0,43,54", "7,54,66",
            "0,43,54", "131,148,150", "7,54,66", "0,43,54",
            "220,50,47", "203,75,22", "133,153,0", "88,110,117",
            "181,137,0", "101,123,131", "38,139,210", "131,148,150",
            "211,54,130", "108,113,196", "42,161,152", "147,161,161",
            "238,232,213", "253,246,227"
        ]
    },
    "monokai": {
        "name": "Monokai Pro",
        "author": "Wimer Hazenberg",
        "colors": [
            "252,252,250", "255,255,255", "45,42,46", "64,61,65",
            "45,42,46", "252,252,250", "45,42,46", "114,110,115",
            "255,97,136", "255,97,136", "169,220,118", "169,220,118",
            "255,216,102", "255,216,102", "252,152,103", "252,152,103",
            "171,157,242", "171,157,242", "120,220,232", "120,220,232",
            "252,252,250", "255,255,255"
        ]
    },
    "solarized-light": {
        "name": "Solarized Light",
        "author": "Ethan Schoonover",
        "colors": [
            "101,123,131", "7,54,66", "253,246,227", "238,232,213",
            "253,246,227", "101,123,131", "7,54,66", "0,43,54",
            "220,50,47", "203,75,22", "133,153,0", "88,110,117",
            "181,137,0", "101,123,131", "38,139,210", "131,148,150",
            "211,54,130", "108,113,196", "42,161,152", "147,161,161",
            "238,232,213", "253,246,227"
        ]
    },
    "gruvbox-light": {
        "name": "Gruvbox Light",
        "author": "morhetz",
        "colors": [
            "60,56,54", "40,40,40", "251,241,199", "235,219,178",
            "251,241,199", "60,56,54", "251,241,199", "146,131,116",
            "204,36,29", "157,0,6", "152,151,26", "121,116,14",
            "215,153,33", "181,118,20", "69,133,136", "7,102,102",
            "177,98,134", "143,63,113", "104,157,106", "66,123,88",
            "124,111,100", "60,56,54"
        ]
    }
}

_THEME_CACHE: Optional[Dict[str, Dict[str, any]]] = None


def parse_reg_file(filepath: str) -> Optional[Dict[str, any]]:
    """Parses a PuTTY .reg file and returns theme dict with 22 RGB color strings."""
    if not os.path.exists(filepath):
        return None

    try:
        content = ""
        for enc in ["utf-8", "utf-16", "utf-16-le", "latin-1"]:
            try:
                with open(filepath, "r", encoding=enc) as f:
                    content = f.read()
                if "Colour" in content:
                    break
            except Exception:
                continue

        colors = {}
        for line in content.splitlines():
            line = line.strip()
            m = re.match(r'^"Colour(\d+)"="([^"]+)"', line)
            if m:
                colors[int(m.group(1))] = m.group(2).strip()

        if len(colors) >= 22:
            color_list = [colors[i] for i in range(22)]
            basename = os.path.splitext(os.path.basename(filepath))[0]
            clean_name = re.sub(r'^\d+\.\s*', '', basename).strip()
            
            parent_dir = os.path.basename(os.path.dirname(filepath))
            if parent_dir == "putty":
                author = "iTerm2 Schemes"
            elif parent_dir == "AlexAkulov":
                author = "AlexAkulov Schemes"
            else:
                author = parent_dir or "Custom .reg"

            return {
                "name": clean_name,
                "author": author,
                "colors": color_list,
                "path": filepath
            }
    except Exception:
        pass
    return None


def load_all_themes() -> Dict[str, Dict[str, any]]:
    """Loads built-in presets and scans all .reg files from themes directory."""
    global _THEME_CACHE
    if _THEME_CACHE is not None:
        return _THEME_CACHE

    themes = {}
    
    # 1. Load Built-in Presets
    for k, v in PRESET_THEMES.items():
        themes[k.lower()] = v

    # 2. Search Directories for .reg theme files
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_dir = os.path.abspath(os.path.join(script_dir, ".."))
    
    search_dirs = [
        os.path.join(repo_dir, ".config", "putty", "themes"),
        os.path.expanduser("~/.config/putty/themes"),
        os.path.expandvars(r"%APPDATA%\putty\themes")
    ]

    for s_dir in search_dirs:
        if os.path.exists(s_dir):
            for root, _, files in os.walk(s_dir):
                for f in files:
                    if f.endswith(".reg"):
                        full_path = os.path.join(root, f)
                        theme_data = parse_reg_file(full_path)
                        if theme_data:
                            key_name = theme_data["name"].lower()
                            key_name = re.sub(r'[^a-z0-9]+', '-', key_name).strip('-')
                            if key_name not in themes:
                                themes[key_name] = theme_data

    _THEME_CACHE = themes
    return _THEME_CACHE


def sanitize_session_name(session: str) -> str:
    """Escapes session name for PuTTY Registry / configuration keys."""
    escaped = ""
    for ch in session:
        if ch == ' ':
            escaped += '%20'
        elif ch == '/':
            escaped += '%2F'
        elif ch == '\\':
            escaped += '%5C'
        elif ch == ':':
            escaped += '%3A'
        elif ch == '%':
            escaped += '%25'
        elif ch == '~':
            escaped += '%7E'
        else:
            escaped += ch
    return escaped


def generate_reg_content(session: str, color_list: List[str]) -> str:
    """Generates a Windows Registry .reg file content for PuTTY."""
    reg_session = sanitize_session_name(session)
    lines = [
        "Windows Registry Editor Version 5.00",
        "",
        f"[HKEY_CURRENT_USER\\Software\\SimonTatham\\PuTTY\\Sessions\\{reg_session}]"
    ]
    for idx, rgb in enumerate(color_list):
        lines.append(f'"Colour{idx}"="{rgb}"')
    lines.append("")
    return "\n".join(lines)


def render_preview(theme_key: str, raw: bool = False):
    """Renders a visual terminal preview of a color scheme."""
    themes = load_all_themes()
    theme = themes.get(theme_key.lower())
    if not theme:
        if not raw:
            print(f"Error: Unknown theme '{theme_key}'.")
        return

    colors = theme["colors"]

    def bg_rgb(rgb_str):
        r, g, b = [int(x) for x in rgb_str.split(",")]
        return f"\033[48;2;{r};{g};{b}m"

    def fg_rgb(rgb_str):
        r, g, b = [int(x) for x in rgb_str.split(",")]
        return f"\033[38;2;{r};{g};{b}m"

    def reset():
        return "\033[0m"

    fg = colors[0]
    bg = colors[2]

    if not raw:
        print(f"\n--- Color Scheme Preview: \033[1m{theme['name']}\033[0m (from {theme['author']}) ---")
    else:
        print(f"\033[1mTheme: {theme['name']}\033[0m ({theme['author']})")

    print(f"\nBackground / Foreground demo:")
    print(f"{bg_rgb(bg)}{fg_rgb(fg)}  Sample Text: The quick brown fox jumps over the lazy dog  {reset()}")
    
    print("\nANSI 16-Color Palette:")
    normal_indices = [6, 8, 10, 12, 14, 16, 18, 20]
    bright_indices = [7, 9, 11, 13, 15, 17, 19, 21]

    sys.stdout.write("Normal: ")
    for idx in normal_indices:
        rgb = colors[idx]
        sys.stdout.write(f"{bg_rgb(rgb)}   {reset()} ")
    print()

    sys.stdout.write("Bright: ")
    for idx in bright_indices:
        rgb = colors[idx]
        sys.stdout.write(f"{bg_rgb(rgb)}   {reset()} ")
    print("\n")


def fzf_theme_picker() -> Optional[str]:
    """Launches fzf with live ANSI truecolor preview window to select from all 650+ themes."""
    themes = load_all_themes()
    if not themes:
        print("Error: No themes found.")
        return None

    fzf_bin = "fzf"
    if sys.platform == "win32":
        if not shutil.which("fzf") and shutil.which("fzf.exe"):
            fzf_bin = "fzf.exe"

    if not shutil.which(fzf_bin):
        print("Note: 'fzf' is not in PATH. Falling back to standard menu.")
        return None

    lines = []
    for key, data in sorted(themes.items(), key=lambda x: x[1]["name"].lower()):
        lines.append(f"{key:<32}\t{data['name']} ({data['author']})")

    python_bin = sys.executable
    script_path = os.path.abspath(__file__)
    
    preview_cmd = f'"{python_bin}" "{script_path}" preview --raw {{1}}'

    try:
        fzf_proc = subprocess.Popen(
            [
                fzf_bin,
                "--prompt=PuTTY Theme > ",
                "--header=Arrow Up/Down to preview, Enter to select theme",
                f"--preview={preview_cmd}",
                "--preview-window=right:55%:wrap",
                "--delimiter=\t",
                "--with-nth=2",
                "--height=85%",
                "--reverse",
                "--tiebreak=begin,length"
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            text=True
        )

        stdout, _ = fzf_proc.communicate(input="\n".join(lines))
        if fzf_proc.returncode == 0 and stdout.strip():
            selected_line = stdout.strip()
            selected_key = selected_line.split("\t")[0].strip()
            return selected_key
    except Exception as e:
        print(f"Error launching fzf: {e}")

    return None


def apply_theme_to_windows_registry(session: str, color_list: List[str]):
    """Applies color scheme directly to Windows Registry if running on Windows."""
    try:
        import winreg
    except ImportError:
        print("Warning: 'winreg' module is only available on native Windows Python.")
        return False

    reg_session = sanitize_session_name(session)
    key_path = f"Software\\SimonTatham\\PuTTY\\Sessions\\{reg_session}"

    try:
        key = winreg.CreateKey(winreg.HKEY_CURRENT_USER, key_path)
        for idx, rgb in enumerate(color_list):
            winreg.SetValueEx(key, f"Colour{idx}", 0, winreg.REG_SZ, rgb)
        winreg.CloseKey(key)
        print(f"Successfully applied color scheme to Windows Registry: HKCU\\{key_path}")
        return True
    except Exception as e:
        print(f"Error modifying Windows Registry: {e}")
        return False


def apply_theme_to_linux_putty(session: str, color_list: List[str]):
    """Applies color scheme to Linux/Unix ~/.putty/sessions/ file."""
    putty_dir = os.path.expanduser("~/.putty/sessions")
    os.makedirs(putty_dir, exist_ok=True)

    sanitized = sanitize_session_name(session)
    session_file = os.path.join(putty_dir, sanitized)

    existing_lines = []
    if os.path.exists(session_file):
        with open(session_file, "r", encoding="utf-8", errors="ignore") as f:
            existing_lines = f.readlines()

    new_lines = [line for line in existing_lines if not re.match(r"^Colour\d+=", line.strip())]
    for idx, rgb in enumerate(color_list):
        new_lines.append(f"Colour{idx}={rgb}\n")

    with open(session_file, "w", encoding="utf-8") as f:
        f.writelines(new_lines)

    print(f"Successfully saved color scheme to Linux PuTTY session file: {session_file}")
    return True


def get_all_putty_sessions() -> List[str]:
    """Retrieves list of all saved PuTTY session names from Windows Registry or Linux."""
    sessions = []
    if sys.platform == "win32":
        try:
            import winreg
            import urllib.parse
            key_path = r"Software\SimonTatham\PuTTY\Sessions"
            key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, key_path)
            idx = 0
            while True:
                try:
                    sub_key = winreg.EnumKey(key, idx)
                    sessions.append(urllib.parse.unquote(sub_key))
                    idx += 1
                except OSError:
                    break
            winreg.CloseKey(key)
        except Exception:
            pass
    else:
        putty_dir = os.path.expanduser("~/.putty/sessions")
        if os.path.exists(putty_dir):
            import urllib.parse
            for item in os.listdir(putty_dir):
                if os.path.isfile(os.path.join(putty_dir, item)):
                    sessions.append(urllib.parse.unquote(item))
    return sessions


def apply_live_osc_colors(theme_key: str):
    """Sends ANSI OSC sequences to immediately change active terminal colors on the fly."""
    themes = load_all_themes()
    theme = themes.get(theme_key.lower())
    if not theme:
        print(f"Error: Unknown theme '{theme_key}'.")
        return
    colors = theme["colors"]
    fg_rgb = [int(x) for x in colors[0].split(',')]
    bg_rgb = [int(x) for x in colors[2].split(',')]
    
    sys.stdout.write(f"\033]10;rgb:{fg_rgb[0]:02x}/{fg_rgb[1]:02x}/{fg_rgb[2]:02x}\007")
    sys.stdout.write(f"\033]11;rgb:{bg_rgb[0]:02x}/{bg_rgb[1]:02x}/{bg_rgb[2]:02x}\007")
    
    ansi_map = [6, 8, 10, 12, 14, 16, 18, 20, 7, 9, 11, 13, 15, 17, 19, 21]
    for ansi_idx, color_idx in enumerate(ansi_map):
        r, g, b = [int(x) for x in colors[color_idx].split(',')]
        sys.stdout.write(f"\033]4;{ansi_idx};rgb:{r:02x}/{g:02x}/{b:02x}\007")
    sys.stdout.flush()
    print(f"Instantly changed active terminal window colors to '{theme['name']}'.")


def select_session_interactively(title: str = "Select PuTTY Session") -> Optional[str]:
    """Displays a numbered selection list of all existing saved PuTTY sessions."""
    existing = get_all_putty_sessions()
    
    session_options = ["Default Settings"]
    for s in existing:
        if s != "Default Settings":
            session_options.append(s)

    print(f"\n{title}:")
    for idx, name in enumerate(session_options, 1):
        print(f" [{idx:2d}] {name}")
    print(" [ M] Type custom session name manually")
    print(" [ 0] Cancel")
    print("\nSelect session number: ", end="")

    try:
        choice = input().strip()
        if not choice or choice == "0":
            return None
        if choice.upper() == "M":
            manual = input("Enter PuTTY Session Name manually: ").strip()
            return manual if manual else "Default Settings"
        
        idx = int(choice) - 1
        if 0 <= idx < len(session_options):
            return session_options[idx]
        else:
            print("Invalid session selection.")
            return None
    except ValueError:
        print("Invalid input.")
        return None


def prompt_theme_actions(selected_key: str):
    """Prompts user for actions (apply, export, saved sessions) on a selected theme."""
    themes = load_all_themes()
    theme_data = themes.get(selected_key)
    if not theme_data:
        return
    theme_colors = theme_data["colors"]
    
    print(f"\nActions for '{theme_data['name']}':")
    print(" [1] Apply to PuTTY 'Default Settings'")
    print(" [2] Select & apply to an existing saved PuTTY session")
    print(" [3] Apply to ALL saved PuTTY sessions")
    print(" [4] Export as Windows Registry (.reg) file")
    print(" [0] Exit / Cancel")
    print("\nChoice: ", end="")

    try:
        opt = input().strip().upper()
        if opt == "0" or not opt:
            return

        if opt == "1":
            session = "Default Settings"
            if sys.platform == "win32":
                apply_theme_to_windows_registry(session, theme_colors)
            else:
                apply_theme_to_linux_putty(session, theme_colors)
                reg_file = f"{selected_key}_default.reg"
                with open(reg_file, "w", encoding="utf-8") as f:
                    f.write(generate_reg_content(session, theme_colors))
                print(f"Also generated Windows Registry file: {reg_file}")

        elif opt == "2":
            session = select_session_interactively("Select Saved PuTTY Session to Apply Theme")
            if not session:
                return
            if sys.platform == "win32":
                apply_theme_to_windows_registry(session, theme_colors)
            else:
                apply_theme_to_linux_putty(session, theme_colors)

        elif opt == "3":
            sessions = get_all_putty_sessions()
            if "Default Settings" not in sessions:
                sessions.append("Default Settings")
            print(f"Applying '{theme_data['name']}' theme to ALL {len(sessions)} saved PuTTY sessions...")
            for s_item in sessions:
                if sys.platform == "win32":
                    apply_theme_to_windows_registry(s_item, theme_colors)
                else:
                    apply_theme_to_linux_putty(s_item, theme_colors)
            print("Done! Applied to all saved sessions.")

        elif opt == "4":
            session = select_session_interactively("Select Session for .reg Export")
            if not session:
                session = "Default Settings"
            out_name = f"{selected_key}_{sanitize_session_name(session)}.reg"
            out_file = input(f"Output file path [{out_name}]: ").strip() or out_name
            with open(out_file, "w", encoding="utf-8") as f:
                f.write(generate_reg_content(session, theme_colors))
            print(f"Exported .reg file to: {os.path.abspath(out_file)}")
            print("On Windows, double-click this .reg file to import the theme into PuTTY.")

    except Exception as e:
        print(f"Operation failed: {e}")


def list_themes():
    """Lists all available preset & custom .reg color schemes and allows interactive selection."""
    themes = load_all_themes()
    theme_keys = sorted(themes.keys(), key=lambda k: themes[k]["name"].lower())

    print(f"Available PuTTY Color Schemes ({len(themes)} Themes):\n")
    print(f" {'#':<4} {'KEY':<30} {'NAME':<25} {'SOURCE':<20}")
    print("-" * 82)
    for idx, key in enumerate(theme_keys, 1):
        data = themes[key]
        print(f" [{idx:3d}] {key:<30} {data['name']:<25} {data['author']:<20}")

    if sys.stdin.isatty():
        print("\nSelect theme number to preview & manage (or 0/Enter to exit): ", end="")
        try:
            choice = input().strip()
            if not choice or choice == "0":
                return
            idx = int(choice) - 1
            if 0 <= idx < len(theme_keys):
                selected_key = theme_keys[idx]
                render_preview(selected_key)
                prompt_theme_actions(selected_key)
            else:
                print("Invalid selection.")
        except Exception:
            pass


def interactive_menu():
    """Interactive CLI menu to select, preview, export, or apply theme."""
    # Check if fzf is available for instant fuzzy search
    if sys.platform == "win32":
        has_fzf = shutil.which("fzf") or shutil.which("fzf.exe")
    else:
        has_fzf = shutil.which("fzf")

    if sys.stdin.isatty() and has_fzf:
        selected_key = fzf_theme_picker()
        if selected_key:
            render_preview(selected_key)
            prompt_theme_actions(selected_key)
            return

    # Fallback to standard CLI menu
    list_themes()


def select_theme_interactively() -> Optional[str]:
    """Selects a theme interactively via fzf (if available) or numbered list."""
    if sys.stdin.isatty():
        if sys.platform == "win32":
            has_fzf = shutil.which("fzf") or shutil.which("fzf.exe")
        else:
            has_fzf = shutil.which("fzf")

        if has_fzf:
            key = fzf_theme_picker()
            if key:
                return key

    themes = load_all_themes()
    theme_keys = sorted(themes.keys(), key=lambda k: themes[k]["name"].lower())

    print(f"Available PuTTY Color Schemes ({len(themes)} Themes):\n")
    print(f" {'#':<4} {'KEY':<30} {'NAME':<25} {'SOURCE':<20}")
    print("-" * 82)
    for idx, key in enumerate(theme_keys, 1):
        data = themes[key]
        print(f" [{idx:3d}] {key:<30} {data['name']:<25} {data['author']:<20}")

    print("\nSelect theme number (or 0/Enter to cancel): ", end="")
    try:
        choice = input().strip()
        if not choice or choice == "0":
            return None
        idx = int(choice) - 1
        if 0 <= idx < len(theme_keys):
            return theme_keys[idx]
        else:
            print("Invalid selection.")
            return None
    except Exception:
        print("Invalid input.")
        return None


def show_current_putty_color_info(session: str = "Default Settings"):
    """Reads session colors from Windows Registry or Linux PuTTY files and identifies active color scheme."""
    colors = {}
    
    if sys.platform == "win32":
        try:
            import winreg
            reg_session = sanitize_session_name(session)
            key_path = f"Software\\SimonTatham\\PuTTY\\Sessions\\{reg_session}"
            key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, key_path)
            for idx in range(22):
                try:
                    val, _ = winreg.QueryValueEx(key, f"Colour{idx}")
                    colors[idx] = val
                except OSError:
                    pass
            winreg.CloseKey(key)
        except Exception:
            pass
    else:
        putty_dir = os.path.expanduser("~/.putty/sessions")
        sanitized = sanitize_session_name(session)
        session_file = os.path.join(putty_dir, sanitized)
        if os.path.exists(session_file):
            try:
                with open(session_file, "r", encoding="utf-8", errors="ignore") as f:
                    for line in f:
                        line = line.strip()
                        m = re.match(r'^Colour(\d+)=(.*)$', line)
                        if m:
                            colors[int(m.group(1))] = m.group(2).strip()
            except Exception:
                pass

    if len(colors) < 22:
        print(f"Could not read complete color scheme for PuTTY session '{session}'.")
        return

    color_list = [colors[i] for i in range(22)]
    
    themes = load_all_themes()
    matched_theme = None
    for k, t_data in themes.items():
        if t_data["colors"] == color_list:
            matched_theme = t_data
            break

    print(f"\n--- PuTTY Session Configuration Info: \033[1m{session}\033[0m ---")
    if matched_theme:
        print(f"Detected Color Scheme : \033[32;1m{matched_theme['name']}\033[0m (from {matched_theme['author']})")
    else:
        print(f"Detected Color Scheme : Custom Palette")

    def bg_rgb(rgb_str):
        r, g, b = [int(x) for x in rgb_str.split(",")]
        return f"\033[48;2;{r};{g};{b}m"

    def fg_rgb(rgb_str):
        r, g, b = [int(x) for x in rgb_str.split(",")]
        return f"\033[38;2;{r};{g};{b}m"

    def reset():
        return "\033[0m"

    fg = color_list[0]
    bg = color_list[2]

    print(f"Default Foreground    : {fg}")
    print(f"Default Background    : {bg}")
    print(f"\nBackground / Foreground demo:")
    print(f"{bg_rgb(bg)}{fg_rgb(fg)}  Sample Text: The quick brown fox jumps over the lazy dog  {reset()}")
    
    print("\nANSI 16-Color Palette:")
    normal_indices = [6, 8, 10, 12, 14, 16, 18, 20]
    bright_indices = [7, 9, 11, 13, 15, 17, 19, 21]

    sys.stdout.write("Normal: ")
    for idx in normal_indices:
        rgb = color_list[idx]
        sys.stdout.write(f"{bg_rgb(rgb)}   {reset()} ")
    print()

    sys.stdout.write("Bright: ")
    for idx in bright_indices:
        rgb = color_list[idx]
        sys.stdout.write(f"{bg_rgb(rgb)}   {reset()} ")
    print("\n")


def main():
    parser = argparse.ArgumentParser(
        description="PuTTY Color Scheme Utility - Easily preview, export, or apply color schemes.",
        epilog="Running 'putty_colors' without subcommands launches the interactive theme picker."
    )
    subparsers = parser.add_subparsers(dest="command")

    # info / current
    info_parser = subparsers.add_parser("info", help="Display color scheme info of a PuTTY session")
    info_parser.add_argument("-s", "--session", default="Default Settings", help="PuTTY session name (default: Default Settings)")

    # list
    subparsers.add_parser("list", help="List all available preset & .reg themes")

    # sessions
    subparsers.add_parser("sessions", help="List all saved PuTTY sessions in Windows Registry")

    # preview
    preview_parser = subparsers.add_parser("preview", help="Preview a color scheme in terminal")
    preview_parser.add_argument("theme", nargs="?", default=None, help="Theme key (optional, prompts to select if omitted)")
    preview_parser.add_argument("--raw", action="store_true", help="Output raw preview block (for fzf preview window)")

    # apply
    apply_parser = subparsers.add_parser("apply", help="Apply color scheme to PuTTY session")
    apply_parser.add_argument("theme", nargs="?", default=None, help="Theme key (optional, prompts to select if omitted)")
    apply_parser.add_argument("-s", "--session", default="Default Settings", help="PuTTY session name (default: Default Settings)")
    apply_parser.add_argument("-a", "--all", action="store_true", help="Apply theme to ALL saved PuTTY sessions")

    # live
    live_parser = subparsers.add_parser("live", help="Instantly change colors in active open PuTTY terminal window")
    live_parser.add_argument("theme", nargs="?", default=None, help="Theme key (optional, prompts to select if omitted)")

    # export
    export_parser = subparsers.add_parser("export", help="Export color scheme to Windows Registry .reg file")
    export_parser.add_argument("theme", nargs="?", default=None, help="Theme key (optional, prompts to select if omitted)")
    export_parser.add_argument("-s", "--session", default="Default Settings", help="PuTTY session name (default: Default Settings)")
    export_parser.add_argument("-o", "--output", help="Output .reg filename")

    args = parser.parse_args()

    if not args.command:
        interactive_menu()
        return

    themes = load_all_themes()

    if args.command == "info":
        show_current_putty_color_info(args.session)

    elif args.command == "list":
        list_themes()

    elif args.command == "sessions":
        sessions = get_all_putty_sessions()
        if not sessions:
            print("No saved PuTTY sessions found.")
        else:
            print("Saved PuTTY Sessions:")
            for s in sessions:
                print(f" - {s}")

    elif args.command == "preview":
        theme_key = args.theme
        raw_mode = getattr(args, "raw", False)
        if not theme_key:
            theme_key = select_theme_interactively()
            if not theme_key:
                return
        render_preview(theme_key, raw=raw_mode)

    elif args.command == "live":
        theme_key = args.theme
        if not theme_key:
            theme_key = select_theme_interactively()
            if not theme_key:
                return
        apply_live_osc_colors(theme_key)

    elif args.command == "export":
        theme_key = args.theme
        if not theme_key:
            theme_key = select_theme_interactively()
            if not theme_key:
                return
        theme_key = theme_key.lower()
        if theme_key not in themes:
            print(f"Error: Unknown theme '{theme_key}'. Use 'list' to view available themes.")
            sys.exit(1)
        colors = themes[theme_key]["colors"]
        session = args.session
        out_file = args.output or f"{theme_key}.reg"
        content = generate_reg_content(session, colors)
        with open(out_file, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Exported '{themes[theme_key]['name']}' theme for session '{session}' to {os.path.abspath(out_file)}")

    elif args.command == "apply":
        theme_key = args.theme
        if not theme_key:
            theme_key = select_theme_interactively()
            if not theme_key:
                return
        theme_key = theme_key.lower()
        if theme_key not in themes:
            print(f"Error: Unknown theme '{theme_key}'. Use 'list' to view available themes.")
            sys.exit(1)
        colors = themes[theme_key]["colors"]

        if getattr(args, "all", False):
            sessions = get_all_putty_sessions()
            if "Default Settings" not in sessions:
                sessions.append("Default Settings")
            print(f"Applying '{themes[theme_key]['name']}' theme to {len(sessions)} saved PuTTY sessions...")
            for s in sessions:
                if sys.platform == "win32":
                    apply_theme_to_windows_registry(s, colors)
                else:
                    apply_theme_to_linux_putty(s, colors)
            print("Done! Applied to all saved sessions.")
        else:
            session = args.session
            if sys.platform == "win32":
                apply_theme_to_windows_registry(session, colors)
            else:
                apply_theme_to_linux_putty(session, colors)
                out_file = f"{theme_key}_{sanitize_session_name(session)}.reg"
                with open(out_file, "w", encoding="utf-8") as f:
                    f.write(generate_reg_content(session, colors))
                print(f"Generated Windows Registry file: {os.path.abspath(out_file)}")


if __name__ == "__main__":
    main()
