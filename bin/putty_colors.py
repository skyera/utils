#!/usr/bin/env python3
"""
putty_colors.py - Easily manage, preview, export, and apply PuTTY color schemes.

Supports Windows Registry (.reg generation or direct winreg modification)
and Linux/Unix PuTTY session files (~/.putty/sessions/).
"""

import sys
import os
import re
import argparse
from typing import Dict, List, Tuple, Optional

# Preset color themes (22 RGB entries for PuTTY Colour0..Colour21)
# Format: List of 22 "R,G,B" strings
PRESET_THEMES: Dict[str, Dict[str, any]] = {
    "dracula": {
        "name": "Dracula",
        "author": "Zeno Rocha",
        "colors": [
            "248,248,242",  # 0: FG
            "255,255,255",  # 1: Bold FG
            "40,42,54",     # 2: BG
            "68,71,90",     # 3: Bold BG
            "40,42,54",     # 4: Cursor Text
            "248,248,242",  # 5: Cursor Color
            "0,0,0",        # 6: Black
            "98,114,164",   # 7: Bright Black
            "255,85,85",    # 8: Red
            "255,110,110",  # 9: Bright Red
            "80,250,123",   # 10: Green
            "105,255,148",  # 11: Bright Green
            "241,250,140",  # 12: Yellow
            "255,255,165",  # 13: Bright Yellow
            "189,147,249",  # 14: Blue
            "214,172,255",  # 15: Bright Blue
            "255,121,198",  # 16: Magenta
            "255,146,223",  # 17: Bright Magenta
            "139,233,253",  # 18: Cyan
            "164,255,255",  # 19: Bright Cyan
            "191,191,191",  # 20: White
            "255,255,255",  # 21: Bright White
        ]
    },
    "nord": {
        "name": "Nord",
        "author": "Arctic Ice Studio",
        "colors": [
            "216,222,233",  # 0
            "235,238,245",  # 1
            "46,52,64",     # 2
            "59,66,82",     # 3
            "46,52,64",     # 4
            "216,222,233",  # 5
            "59,66,82",     # 6
            "76,86,106",    # 7
            "191,97,106",   # 8
            "191,97,106",   # 9
            "163,190,140",  # 10
            "163,190,140",  # 11
            "235,203,139",  # 12
            "235,203,139",  # 13
            "129,161,193",  # 14
            "136,192,208",  # 15
            "180,142,173",  # 16
            "180,142,173",  # 17
            "136,192,208",  # 18
            "143,188,187",  # 19
            "229,233,240",  # 20
            "236,239,244",  # 21
        ]
    },
    "onedark": {
        "name": "One Dark",
        "author": "Atom",
        "colors": [
            "171,178,191",  # 0
            "220,223,228",  # 1
            "40,44,52",     # 2
            "62,68,81",     # 3
            "40,44,52",     # 4
            "82,139,255",   # 5
            "40,44,52",     # 6
            "92,99,112",    # 7
            "224,108,117",  # 8
            "224,108,117",  # 9
            "152,195,121",  # 10
            "152,195,121",  # 11
            "229,192,123",  # 12
            "229,192,123",  # 13
            "97,175,239",   # 14
            "97,175,239",   # 15
            "198,120,221",  # 16
            "198,120,221",  # 17
            "86,182,194",   # 18
            "86,182,194",   # 19
            "171,178,191",  # 20
            "255,255,255",  # 21
        ]
    },
    "gruvbox-dark": {
        "name": "Gruvbox Dark",
        "author": "morhetz",
        "colors": [
            "235,219,178",  # 0
            "251,241,199",  # 1
            "40,40,40",     # 2
            "60,56,54",     # 3
            "40,40,40",     # 4
            "235,219,178",  # 5
            "40,40,40",     # 6
            "146,131,116",  # 7
            "204,36,29",    # 8
            "251,73,52",    # 9
            "152,151,26",   # 10
            "184,187,38",   # 11
            "215,153,33",   # 12
            "250,189,47",   # 13
            "69,133,136",   # 14
            "131,165,152",  # 15
            "177,98,134",   # 16
            "211,134,155",  # 17
            "104,157,106",  # 18
            "142,192,124",  # 19
            "168,153,132",  # 20
            "235,219,178",  # 21
        ]
    },
    "tokyonight": {
        "name": "Tokyo Night",
        "author": "folke",
        "colors": [
            "192,202,245",  # 0
            "205,214,244",  # 1
            "26,27,38",     # 2
            "36,40,59",     # 3
            "26,27,38",     # 4
            "192,202,245",  # 5
            "21,22,30",     # 6
            "65,72,104",    # 7
            "247,118,142",  # 8
            "247,118,142",  # 9
            "158,206,106",  # 10
            "158,206,106",  # 11
            "224,175,104",  # 12
            "224,175,104",  # 13
            "122,162,247",  # 14
            "122,162,247",  # 15
            "187,154,247",  # 16
            "187,154,247",  # 17
            "125,207,255",  # 18
            "125,207,255",  # 19
            "169,177,214",  # 20
            "192,202,245",  # 21
        ]
    },
    "catppuccin-mocha": {
        "name": "Catppuccin Mocha",
        "author": "Catppuccin Org",
        "colors": [
            "205,214,244",  # 0
            "245,224,220",  # 1
            "30,30,46",     # 2
            "49,50,68",     # 3
            "30,30,46",     # 4
            "245,224,220",  # 5
            "69,71,90",     # 6
            "88,91,112",    # 7
            "243,139,168",  # 8
            "243,139,168",  # 9
            "166,227,161",  # 10
            "166,227,161",  # 11
            "249,226,175",  # 12
            "249,226,175",  # 13
            "137,180,250",  # 14
            "137,180,250",  # 15
            "245,194,231",  # 16
            "245,194,231",  # 17
            "148,226,213",  # 18
            "148,226,213",  # 19
            "186,194,222",  # 20
            "166,173,200",  # 21
        ]
    },
    "solarized-dark": {
        "name": "Solarized Dark",
        "author": "Ethan Schoonover",
        "colors": [
            "131,148,150",  # 0
            "147,161,161",  # 1
            "0,43,54",      # 2
            "7,54,66",      # 3
            "0,43,54",      # 4
            "131,148,150",  # 5
            "7,54,66",      # 6
            "0,43,54",      # 7
            "220,50,47",    # 8
            "203,75,22",    # 9
            "133,153,0",    # 10
            "88,110,117",   # 11
            "181,137,0",    # 12
            "101,123,131",  # 13
            "38,139,210",   # 14
            "131,148,150",  # 15
            "211,54,130",   # 16
            "108,113,196",  # 17
            "42,161,152",   # 18
            "147,161,161",  # 19
            "238,232,213",  # 20
            "253,246,227",  # 21
        ]
    },
    "monokai": {
        "name": "Monokai Pro",
        "author": "Wimer Hazenberg",
        "colors": [
            "252,252,250",  # 0
            "255,255,255",  # 1
            "45,42,46",     # 2
            "64,61,65",     # 3
            "45,42,46",     # 4
            "252,252,250",  # 5
            "45,42,46",     # 6
            "114,110,115",  # 7
            "255,97,136",   # 8
            "255,97,136",   # 9
            "169,220,118",  # 10
            "169,220,118",  # 11
            "255,216,102",  # 12
            "255,216,102",  # 13
            "252,152,103",  # 14
            "252,152,103",  # 15
            "171,157,242",  # 16
            "171,157,242",  # 17
            "120,220,232",  # 18
            "120,220,232",  # 19
            "252,252,250",  # 20
            "255,255,255",  # 21
        ]
    },
    "solarized-light": {
        "name": "Solarized Light",
        "author": "Ethan Schoonover",
        "colors": [
            "101,123,131",  # 0
            "7,54,66",      # 1
            "253,246,227",  # 2
            "238,232,213",  # 3
            "253,246,227",  # 4
            "101,123,131",  # 5
            "7,54,66",      # 6
            "0,43,54",      # 7
            "220,50,47",    # 8
            "203,75,22",    # 9
            "133,153,0",    # 10
            "88,110,117",   # 11
            "181,137,0",    # 12
            "101,123,131",  # 13
            "38,139,210",   # 14
            "131,148,150",  # 15
            "211,54,130",   # 16
            "108,113,196",  # 17
            "42,161,152",   # 18
            "147,161,161",  # 19
            "238,232,213",  # 20
            "253,246,227",  # 21
        ]
    },
    "gruvbox-light": {
        "name": "Gruvbox Light",
        "author": "morhetz",
        "colors": [
            "60,56,54",     # 0
            "40,40,40",     # 1
            "251,241,199",  # 2
            "235,219,178",  # 3
            "251,241,199",  # 4
            "60,56,54",     # 5
            "251,241,199",  # 6
            "146,131,116",  # 7
            "204,36,29",    # 8
            "157,0,6",      # 9
            "152,151,26",   # 10
            "121,116,14",   # 11
            "215,153,33",   # 12
            "181,118,20",   # 13
            "69,133,136",   # 14
            "7,102,102",    # 15
            "177,98,134",   # 16
            "143,63,113",   # 17
            "104,157,106",  # 18
            "66,123,88",    # 19
            "124,111,100",  # 20
            "60,56,54",     # 21
        ]
    }
}


def sanitize_session_name(session: str) -> str:
    """Escapes session name for PuTTY Registry / configuration keys."""
    # PuTTY escapes session names in registry: space -> %20, / -> %2F, \ -> %5C, : -> %3A, % -> %25, ~ -> %7E
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


def hex_to_rgb(hex_str: str) -> Tuple[int, int, int]:
    """Converts hex string (#RRGGBB or RRGGBB) to RGB tuple."""
    clean_hex = hex_str.strip().lstrip("#")
    if len(clean_hex) == 3:
        clean_hex = "".join([c * 2 for c in clean_hex])
    if len(clean_hex) != 6:
        raise ValueError(f"Invalid hex color: {hex_str}")
    return (int(clean_hex[0:2], 16), int(clean_hex[2:4], 16), int(clean_hex[4:6], 16))


def rgb_to_ansi_escapes(rgb_str: str) -> Tuple[str, Tuple[int, int, int]]:
    """Parses 'R,G,B' string into RGB tuple."""
    parts = [int(x.strip()) for x in rgb_str.split(",")]
    return (rgb_str, (parts[0], parts[1], parts[2]))


def render_preview(theme_key: str):
    """Renders a visual terminal preview of a color scheme."""
    theme = PRESET_THEMES.get(theme_key.lower())
    if not theme:
        print(f"Error: Unknown theme '{theme_key}'.")
        return

    colors = theme["colors"]
    print(f"\n--- Color Scheme Preview: \031[1m{theme['name']}\033[0m (by {theme['author']}) ---")

    # Helper for truecolor ANSI
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

    print(f"\nBackground / Foreground demo:")
    print(f"{bg_rgb(bg)}{fg_rgb(fg)}  Sample Text: The quick brown fox jumps over the lazy dog  {reset()}")
    
    print("\nANSI 16-Color Palette:")
    labels = ["Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White"]
    
    # Normal colors (Colour6..13 vs Colour14..21 in PuTTY map:
    # PuTTY map: 6=Black, 8=Red, 10=Green, 12=Yellow, 14=Blue, 16=Magenta, 18=Cyan, 20=White
    normal_indices = [6, 8, 10, 12, 14, 16, 18, 20]
    bright_indices = [7, 9, 11, 13, 15, 17, 19, 21]

    # Print normal palette
    sys.stdout.write("Normal: ")
    for idx in normal_indices:
        rgb = colors[idx]
        sys.stdout.write(f"{bg_rgb(rgb)}   {reset()} ")
    print()

    # Print bright palette
    sys.stdout.write("Bright: ")
    for idx in bright_indices:
        rgb = colors[idx]
        sys.stdout.write(f"{bg_rgb(rgb)}   {reset()} ")
    print("\n")


def list_themes():
    """Lists all available preset color schemes."""
    print("Available PuTTY Color Schemes:\n")
    print(f"{'KEY':<20} {'NAME':<20} {'AUTHOR':<25}")
    print("-" * 65)
    for key, data in PRESET_THEMES.items():
        print(f"{key:<20} {data['name']:<20} {data['author']:<25}")
    print("\nUse 'putty_colors preview <key>' to preview a scheme.")
    print("Use 'putty_colors export <key> [-s SESSION] [-o FILE.reg]' to export a .reg registry file.")
    print("Use 'putty_colors apply <key> [-s SESSION]' to apply directly.")


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

    # Filter out existing Colour entries
    new_lines = [line for line in existing_lines if not re.match(r"^Colour\d+=", line.strip())]

    # Append new Colour entries
    for idx, rgb in enumerate(color_list):
        new_lines.append(f"Colour{idx}={rgb}\n")

    with open(session_file, "w", encoding="utf-8") as f:
        f.writelines(new_lines)

    print(f"Successfully saved color scheme to Linux PuTTY session file: {session_file}")
    return True


def interactive_menu():
    """Interactive CLI menu to select, preview, export, or apply theme."""
    theme_keys = list(PRESET_THEMES.keys())
    
    while True:
        print("\n========================================")
        print("   PuTTY Color Scheme Manager Utility   ")
        print("========================================\n")

        print("Available Color Schemes:")
        for idx, k in enumerate(theme_keys, 1):
            name = PRESET_THEMES[k]["name"]
            author = PRESET_THEMES[k]["author"]
            print(f" [{idx:2d}] {k:<18} - {name} (by {author})")

        print("\nSelect a theme number to preview & manage (or 0 to exit): ", end="")
        try:
            choice = input().strip()
            if not choice or choice == "0":
                print("Exiting.")
                return
            idx = int(choice) - 1
            if idx < 0 or idx >= len(theme_keys):
                print("Invalid selection.")
                continue
            selected_key = theme_keys[idx]
        except Exception:
            print("Invalid input.")
            continue

        render_preview(selected_key)

        print(f"Actions for '{PRESET_THEMES[selected_key]['name']}':")
        print(" [1] Apply to PuTTY 'Default Settings'")
        print(" [2] Select from existing saved PuTTY sessions")
        print(" [3] Apply to ALL saved PuTTY sessions")
        print(" [4] Apply to custom PuTTY session (type manually)")
        print(" [5] Export as Windows Registry (.reg) file")
        print(" [P] Preview another theme / Back to list")
        print(" [0] Exit")
        print("\nChoice: ", end="")

        try:
            opt = input().strip().upper()
            if opt == "P":
                continue
            if opt == "0":
                print("Exiting.")
                return

            theme_colors = PRESET_THEMES[selected_key]["colors"]
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
                sessions = get_all_putty_sessions()
                if not sessions:
                    print("No existing saved PuTTY sessions found.")
                    session = input("Enter PuTTY Session Name manually [Default Settings]: ").strip() or "Default Settings"
                    target_sessions = [session]
                else:
                    print("\nExisting Saved PuTTY Sessions:")
                    for s_idx, s_name in enumerate(sessions, 1):
                        print(f" [{s_idx:2d}] {s_name}")
                    print(" [ A] Apply to ALL existing sessions")
                    print(" [ 0] Cancel")
                    print("\nSelect session number: ", end="")
                    s_choice = input().strip()
                    if s_choice.upper() == "A":
                        target_sessions = sessions
                    elif s_choice == "0" or not s_choice:
                        continue
                    else:
                        try:
                            s_i = int(s_choice) - 1
                            if 0 <= s_i < len(sessions):
                                target_sessions = [sessions[s_i]]
                            else:
                                print("Invalid session selection.")
                                continue
                        except ValueError:
                            print("Invalid input.")
                            continue

                for s_item in target_sessions:
                    if sys.platform == "win32":
                        apply_theme_to_windows_registry(s_item, theme_colors)
                    else:
                        apply_theme_to_linux_putty(s_item, theme_colors)
                print(f"Applied '{PRESET_THEMES[selected_key]['name']}' theme to {len(target_sessions)} session(s).")

            elif opt == "3":
                sessions = get_all_putty_sessions()
                if "Default Settings" not in sessions:
                    sessions.append("Default Settings")
                print(f"Applying '{PRESET_THEMES[selected_key]['name']}' theme to ALL {len(sessions)} saved PuTTY sessions...")
                for s_item in sessions:
                    if sys.platform == "win32":
                        apply_theme_to_windows_registry(s_item, theme_colors)
                    else:
                        apply_theme_to_linux_putty(s_item, theme_colors)
                print("Done! Applied to all saved sessions.")

            elif opt == "4":
                session = input("Enter PuTTY Session Name: ").strip()
                if not session:
                    session = "Default Settings"
                if sys.platform == "win32":
                    apply_theme_to_windows_registry(session, theme_colors)
                else:
                    apply_theme_to_linux_putty(session, theme_colors)
                    reg_file = f"{selected_key}_{sanitize_session_name(session)}.reg"
                    with open(reg_file, "w", encoding="utf-8") as f:
                        f.write(generate_reg_content(session, theme_colors))
                    print(f"Also generated Windows Registry file: {reg_file}")

            elif opt == "5":
                session = input("Enter Session Name [Default Settings]: ").strip() or "Default Settings"
                out_name = f"{selected_key}.reg"
                out_file = input(f"Output file path [{out_name}]: ").strip() or out_name
                with open(out_file, "w", encoding="utf-8") as f:
                    f.write(generate_reg_content(session, theme_colors))
                print(f"Exported .reg file to: {os.path.abspath(out_file)}")
                print("On Windows, double-click this .reg file to import the theme into PuTTY.")

            print("\nPress Enter to return to main menu...", end="")
            input()

        except Exception as e:
            print(f"Operation failed: {e}")


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
    theme = PRESET_THEMES.get(theme_key.lower())
    if not theme:
        print(f"Error: Unknown theme '{theme_key}'.")
        return
    colors = theme["colors"]
    fg_rgb = [int(x) for x in colors[0].split(',')]
    bg_rgb = [int(x) for x in colors[2].split(',')]
    
    # OSC 10 (Foreground) & OSC 11 (Background)
    sys.stdout.write(f"\033]10;rgb:{fg_rgb[0]:02x}/{fg_rgb[1]:02x}/{fg_rgb[2]:02x}\007")
    sys.stdout.write(f"\033]11;rgb:{bg_rgb[0]:02x}/{bg_rgb[1]:02x}/{bg_rgb[2]:02x}\007")
    
    # 16 ANSI colors
    ansi_map = [6, 8, 10, 12, 14, 16, 18, 20, 7, 9, 11, 13, 15, 17, 19, 21]
    for ansi_idx, color_idx in enumerate(ansi_map):
        r, g, b = [int(x) for x in colors[color_idx].split(',')]
        sys.stdout.write(f"\033]4;{ansi_idx};rgb:{r:02x}/{g:02x}/{b:02x}\007")
    sys.stdout.flush()
    print(f"Instantly changed active terminal window colors to '{theme['name']}'.")


def main():
    parser = argparse.ArgumentParser(description="PuTTY Color Scheme Utility - Easily preview, export, or apply color schemes.")
    subparsers = parser.add_subparsers(dest="command")

    # list
    subparsers.add_parser("list", help="List all available preset themes")

    # sessions
    subparsers.add_parser("sessions", help="List all saved PuTTY sessions in Windows Registry")

    # preview
    preview_parser = subparsers.add_parser("preview", help="Preview a color scheme in terminal")
    preview_parser.add_argument("theme", nargs="?", default=None, help="Theme key (e.g. dracula, nord, tokyonight)")

    # export
    export_parser = subparsers.add_parser("export", help="Export color scheme to Windows Registry .reg file")
    export_parser.add_argument("theme", help="Theme key")
    export_parser.add_argument("-s", "--session", default="Default Settings", help="PuTTY session name (default: Default Settings)")
    export_parser.add_argument("-o", "--output", help="Output .reg filename")

    # apply
    apply_parser = subparsers.add_parser("apply", help="Apply color scheme to PuTTY session")
    apply_parser.add_argument("theme", help="Theme key")
    apply_parser.add_argument("-s", "--session", default="Default Settings", help="PuTTY session name (default: Default Settings)")
    apply_parser.add_argument("-a", "--all", action="store_true", help="Apply theme to ALL saved PuTTY sessions")

    # live
    live_parser = subparsers.add_parser("live", help="Instantly change colors in active open PuTTY terminal window")
    live_parser.add_argument("theme", help="Theme key")

    # interactive
    subparsers.add_parser("interactive", help="Run interactive theme selector menu")

    args = parser.parse_args()

    if not args.command:
        interactive_menu()
        return

    if args.command == "list":
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
        if not theme_key:
            theme_keys = list(PRESET_THEMES.keys())
            print("Available Color Schemes to Preview:\n")
            for idx, k in enumerate(theme_keys, 1):
                name = PRESET_THEMES[k]["name"]
                author = PRESET_THEMES[k]["author"]
                print(f" [{idx:2d}] {k:<18} - {name} (by {author})")
            print("\nSelect theme number to preview (or 0 to cancel): ", end="")
            try:
                choice = input().strip()
                if not choice or choice == "0":
                    return
                idx = int(choice) - 1
                if 0 <= idx < len(theme_keys):
                    theme_key = theme_keys[idx]
                else:
                    print("Invalid selection.")
                    return
            except Exception:
                print("Invalid input.")
                return
        render_preview(theme_key)

    elif args.command == "live":
        apply_live_osc_colors(args.theme)

    elif args.command == "export":
        theme_key = args.theme.lower()
        if theme_key not in PRESET_THEMES:
            print(f"Error: Unknown theme '{args.theme}'. Use 'list' to view available themes.")
            sys.exit(1)
        colors = PRESET_THEMES[theme_key]["colors"]
        session = args.session
        out_file = args.output or f"{theme_key}.reg"
        content = generate_reg_content(session, colors)
        with open(out_file, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Exported '{PRESET_THEMES[theme_key]['name']}' theme for session '{session}' to {os.path.abspath(out_file)}")

    elif args.command == "apply":
        theme_key = args.theme.lower()
        if theme_key not in PRESET_THEMES:
            print(f"Error: Unknown theme '{args.theme}'. Use 'list' to view available themes.")
            sys.exit(1)
        colors = PRESET_THEMES[theme_key]["colors"]

        if getattr(args, "all", False):
            sessions = get_all_putty_sessions()
            if "Default Settings" not in sessions:
                sessions.append("Default Settings")
            print(f"Applying '{PRESET_THEMES[theme_key]['name']}' theme to {len(sessions)} saved PuTTY sessions...")
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

    elif args.command == "interactive":
        interactive_menu()


if __name__ == "__main__":
    main()

