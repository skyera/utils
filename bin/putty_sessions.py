#!/usr/bin/env python3
"""
putty_sessions.py - Retrieve and export saved PuTTY sessions to text, CSV, JSON, or SSH config.

Supports:
- Windows (Registry: HKCU\\Software\\SimonTatham\\PuTTY\\Sessions)
- WSL (via Windows reg.exe)
- Linux / macOS (~/.putty/sessions)

Usage:
  putty_sessions.py [options] [filter_pattern]
"""

import sys
import os
import re
import csv
import json
import argparse
import datetime
import urllib.parse
import subprocess
import shutil
from typing import List, Dict, Any, Optional


def is_wsl() -> bool:
    """Check if running inside Windows Subsystem for Linux (WSL)."""
    if sys.platform != "linux":
        return False
    try:
        with open("/proc/version", "r") as f:
            return "microsoft" in f.read().lower()
    except Exception:
        return False


def get_sessions_winreg() -> List[Dict[str, Any]]:
    """Retrieve PuTTY sessions directly via Windows Registry (winreg)."""
    sessions = []
    try:
        import winreg
        root_path = r"Software\SimonTatham\PuTTY\Sessions"
        root_key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, root_path)
        idx = 0
        while True:
            try:
                sub_name = winreg.EnumKey(root_key, idx)
                session_name = urllib.parse.unquote(sub_name)
                sub_key = winreg.OpenKey(root_key, sub_name)

                def get_val(key, name: str, default: str = "") -> str:
                    try:
                        v, _ = winreg.QueryValueEx(key, name)
                        return str(v)
                    except OSError:
                        return default

                sessions.append({
                    "name": session_name,
                    "host": get_val(sub_key, "HostName", ""),
                    "port": get_val(sub_key, "PortNumber", "22"),
                    "user": get_val(sub_key, "UserName", ""),
                    "protocol": get_val(sub_key, "Protocol", "ssh"),
                    "key_file": get_val(sub_key, "PublicKeyFile", ""),
                    "cert_file": get_val(sub_key, "CertificateFile", ""),
                    "agent_fwd": get_val(sub_key, "AgentFwd", "0"),
                    "auth_gssapi": get_val(sub_key, "AuthGSSAPI", "0"),
                })
                winreg.CloseKey(sub_key)
                idx += 1
            except OSError:
                break
        winreg.CloseKey(root_key)
    except Exception:
        pass
    return sessions


def get_sessions_reg_exe() -> List[Dict[str, Any]]:
    """Retrieve PuTTY sessions from Windows registry when running inside WSL."""
    sessions = []
    reg_cmd = shutil.which("reg.exe") or "/mnt/c/Windows/System32/reg.exe"
    if not os.path.exists(reg_cmd) and not shutil.which("reg.exe"):
        return sessions

    try:
        res = subprocess.run(
            [reg_cmd, "query", r"HKCU\Software\SimonTatham\PuTTY\Sessions"],
            capture_output=True, text=True, check=False
        )
        for line in res.stdout.splitlines():
            line = line.strip()
            if r"PuTTY\Sessions\\" in line:
                raw_session = line.split(r"PuTTY\Sessions\\")[-1].strip()
                if not raw_session:
                    continue
                session_name = urllib.parse.unquote(raw_session)
                info: Dict[str, str] = {
                    "name": session_name,
                    "host": "",
                    "port": "22",
                    "user": "",
                    "protocol": "ssh",
                    "key_file": "",
                    "cert_file": "",
                    "agent_fwd": "0",
                    "auth_gssapi": "0",
                }
                detail_res = subprocess.run(
                    [reg_cmd, "query", line],
                    capture_output=True, text=True, check=False
                )
                for dline in detail_res.stdout.splitlines():
                    parts = dline.strip().split()
                    if len(parts) >= 3:
                        val_name, _, val = parts[0], parts[1], " ".join(parts[2:])
                        v_lower = val_name.lower()
                        if v_lower == "hostname":
                            info["host"] = val
                        elif v_lower == "portnumber":
                            info["port"] = str(int(val, 16) if val.startswith("0x") else val)
                        elif v_lower == "username":
                            info["user"] = val
                        elif v_lower == "protocol":
                            info["protocol"] = val
                        elif v_lower == "publickeyfile":
                            info["key_file"] = val
                        elif v_lower == "certificatefile":
                            info["cert_file"] = val
                        elif v_lower == "agentfwd":
                            info["agent_fwd"] = str(int(val, 16) if val.startswith("0x") else val)
                        elif v_lower == "authgssapi":
                            info["auth_gssapi"] = str(int(val, 16) if val.startswith("0x") else val)
                sessions.append(info)
    except Exception:
        pass
    return sessions


def get_sessions_linux() -> List[Dict[str, Any]]:
    """Retrieve PuTTY sessions from ~/.putty/sessions on Unix systems."""
    sessions = []
    putty_dir = os.path.expanduser("~/.putty/sessions")
    if os.path.exists(putty_dir):
        for item in sorted(os.listdir(putty_dir)):
            full_path = os.path.join(putty_dir, item)
            if os.path.isfile(full_path):
                session_name = urllib.parse.unquote(item)
                info: Dict[str, str] = {
                    "name": session_name,
                    "host": "",
                    "port": "22",
                    "user": "",
                    "protocol": "ssh",
                    "key_file": "",
                    "cert_file": "",
                    "agent_fwd": "0",
                    "auth_gssapi": "0",
                }
                try:
                    with open(full_path, "r", encoding="utf-8", errors="ignore") as f:
                        for line in f:
                            if line.startswith("HostName="):
                                info["host"] = line.split("=", 1)[1].strip()
                            elif line.startswith("PortNumber="):
                                info["port"] = line.split("=", 1)[1].strip()
                            elif line.startswith("UserName="):
                                info["user"] = line.split("=", 1)[1].strip()
                            elif line.startswith("Protocol="):
                                info["protocol"] = line.split("=", 1)[1].strip()
                            elif line.startswith("PublicKeyFile="):
                                info["key_file"] = line.split("=", 1)[1].strip()
                            elif line.startswith("CertificateFile="):
                                info["cert_file"] = line.split("=", 1)[1].strip()
                            elif line.startswith("AgentFwd="):
                                info["agent_fwd"] = line.split("=", 1)[1].strip()
                            elif line.startswith("AuthGSSAPI="):
                                info["auth_gssapi"] = line.split("=", 1)[1].strip()
                except Exception:
                    pass
                sessions.append(info)
    return sessions


def fetch_all_sessions() -> List[Dict[str, Any]]:
    """Fetch all saved PuTTY sessions depending on platform."""
    if sys.platform == "win32":
        return get_sessions_winreg()
    if is_wsl():
        wsl_sessions = get_sessions_reg_exe()
        if wsl_sessions:
            return wsl_sessions
    return get_sessions_linux()


def format_table(sessions: List[Dict[str, Any]]) -> str:
    """Format session records into an aligned, human-readable text table."""
    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    header_fmt = "{:<26} {:<26} {:<6} {:<14} {:<8} {:<10} {:<32}"
    divider = "-" * 128
    lines = [
        f"# Saved PuTTY Sessions (Exported: {now_str})",
        f"# Total: {len(sessions)} session(s)",
        "",
        header_fmt.format("SESSION NAME", "HOST / IP", "PORT", "USER", "PROTOCOL", "AGENT_FWD", "KEY / AUTH FILE"),
        divider,
    ]
    for s in sessions:
        name = s.get("name", "")
        host = s.get("host", "") or "-"
        port = str(s.get("port", "22"))
        user = s.get("user", "") or "-"
        proto = (s.get("protocol", "ssh") or "ssh").upper()
        agent_fwd = "Yes" if str(s.get("agent_fwd", "0")) in ("1", "true") else "No"
        
        # Display key/cert summary
        key_file = s.get("key_file", "") or ""
        cert_file = s.get("cert_file", "") or ""
        auth_parts = []
        if key_file:
            auth_parts.append(os.path.basename(key_file) if len(key_file) > 30 else key_file)
        if cert_file:
            auth_parts.append(f"cert:{os.path.basename(cert_file)}")
        auth_display = "; ".join(auth_parts) if auth_parts else "-"

        lines.append(header_fmt.format(name[:25], host[:25], port[:5], user[:13], proto[:7], agent_fwd, auth_display))
    lines.append(divider)
    return "\n".join(lines) + "\n"


def format_names_only(sessions: List[Dict[str, Any]]) -> str:
    """Format session names only (one per line)."""
    return "\n".join(s.get("name", "") for s in sessions) + "\n"


def format_ssh_config(sessions: List[Dict[str, Any]]) -> str:
    """Format sessions into OpenSSH ~/.ssh/config format."""
    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    blocks = [f"# Generated from PuTTY Sessions on {now_str}\n"]
    for s in sessions:
        name = s.get("name", "").strip()
        host = s.get("host", "").strip()
        port = str(s.get("port", "22")).strip()
        user = s.get("user", "").strip()
        key_file = s.get("key_file", "").strip()
        cert_file = s.get("cert_file", "").strip()
        agent_fwd = str(s.get("agent_fwd", "0")).strip()
        auth_gssapi = str(s.get("auth_gssapi", "0")).strip()

        if not host:
            continue
        # Replace spaces in SSH config Host alias
        safe_alias = re.sub(r"\s+", "_", name)
        block = [f"Host {safe_alias}"]
        block.append(f"    HostName {host}")
        if port and port != "22":
            block.append(f"    Port {port}")
        if user:
            block.append(f"    User {user}")
        if key_file:
            block.append(f"    IdentityFile {key_file}")
        if cert_file:
            block.append(f"    CertificateFile {cert_file}")
        if agent_fwd in ("1", "true"):
            block.append("    ForwardAgent yes")
        if auth_gssapi in ("1", "true"):
            block.append("    GSSAPIAuthentication yes")
        blocks.append("\n".join(block))
    return "\n\n".join(blocks) + "\n"


def format_csv(sessions: List[Dict[str, Any]]) -> str:
    """Format sessions as CSV text."""
    import io
    output = io.StringIO()
    fieldnames = ["name", "host", "port", "user", "protocol", "key_file", "cert_file", "agent_fwd", "auth_gssapi"]
    writer = csv.DictWriter(output, fieldnames=fieldnames)
    writer.writeheader()
    for s in sessions:
        row = {k: s.get(k, "") for k in fieldnames}
        writer.writerow(row)
    return output.getvalue()


def format_json(sessions: List[Dict[str, Any]]) -> str:
    """Format sessions as indented JSON string."""
    return json.dumps(sessions, indent=2) + "\n"


def main():
    parser = argparse.ArgumentParser(
        description="Retrieve saved PuTTY sessions and save to a text file."
    )
    parser.add_argument(
        "filter",
        nargs="?",
        default="",
        help="Optional search/filter string for session names, hosts, users, or auth key files",
    )
    parser.add_argument(
        "-o", "--output",
        dest="output",
        default="putty_sessions.txt",
        help="Output file path (default: putty_sessions.txt)",
    )
    parser.add_argument(
        "-n", "--names-only",
        action="store_true",
        help="Export session names only (one per line)",
    )
    parser.add_argument(
        "--ssh-config",
        action="store_true",
        help="Export in OpenSSH ~/.ssh/config format",
    )
    parser.add_argument(
        "--csv",
        action="store_true",
        help="Export in CSV format",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Export in JSON format",
    )
    parser.add_argument(
        "--stdout",
        action="store_true",
        help="Print to stdout instead of (or in addition to) saving file",
    )
    parser.add_argument(
        "--no-file",
        action="store_true",
        help="Only display results to terminal without writing to file",
    )

    args = parser.parse_args()

    sessions = fetch_all_sessions()

    # Filter if pattern provided
    if args.filter:
        pat = args.filter.lower()
        sessions = [
            s for s in sessions
            if pat in s.get("name", "").lower()
            or pat in s.get("host", "").lower()
            or pat in s.get("user", "").lower()
            or pat in s.get("key_file", "").lower()
            or pat in s.get("cert_file", "").lower()
        ]

    # Render formatted content
    if args.names_only:
        content = format_names_only(sessions)
    elif args.ssh_config:
        content = format_ssh_config(sessions)
    elif args.csv:
        content = format_csv(sessions)
    elif args.json:
        content = format_json(sessions)
    else:
        content = format_table(sessions)

    # Output to stdout if requested or if --no-file
    if args.stdout or args.no_file:
        sys.stdout.write(content)

    # Save to file unless --no-file
    if not args.no_file:
        try:
            with open(args.output, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"Successfully exported {len(sessions)} PuTTY session(s) to: {args.output}")
        except Exception as e:
            print(f"Error writing to {args.output}: {e}", file=sys.stderr)
            sys.exit(1)


if __name__ == "__main__":
    main()
