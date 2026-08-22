#!/usr/bin/env python3
"""
fssh.py - Interactive Fuzzy SSH / Linux Server Selector and Connector.

Aggregates servers from:
  1. OpenSSH config (~/.ssh/config, %USERPROFILE%/.ssh/config)
  2. OpenSSH known_hosts (~/.ssh/known_hosts)
  3. PuTTY saved sessions (Windows Registry: HKCU\\Software\\SimonTatham\\PuTTY\\Sessions)
  4. Local hosts files (/etc/hosts, %SystemRoot%\\System32\\drivers\\etc\\hosts)

Usage:
  fssh [OPTIONS] [QUERY] [-- SSH_EXTRA_ARGS...]

Options:
  -p, --preview-only <HOST>   Print detailed preview card for host (used by fzf preview)
  -l, --list                  List aggregated hosts in TSV format (for fzf input)
  -d, --dry-run               Print the ssh command without executing
  -u, --user <USER>           Override SSH user
  --putty                     Connect using PuTTY instead of OpenSSH (Windows only)
  -h, --help                  Show this help message

Examples:
  fssh                        Interactive selection via fzf
  fssh pi5                    Quick-filter or connect to host matching "pi5"
  fssh -u root ser8           Connect to ser8 with user root
  fssh ser8 "df -h && uptime" Connect and execute remote command
  fssh -d myserver            Print connection command without executing
"""

import sys
import os
import re
import shutil
import subprocess
import urllib.parse
import getpass
from typing import List, Dict, Any, Optional


def get_home_dir() -> str:
    return os.path.expanduser("~")


def get_ssh_config_paths() -> List[str]:
    paths = []
    home = get_home_dir()
    p1 = os.path.join(home, ".ssh", "config")
    if os.path.isfile(p1) and p1 not in paths:
        paths.append(p1)

    userprofile = os.environ.get("USERPROFILE")
    if userprofile:
        p2 = os.path.join(userprofile, ".ssh", "config")
        if os.path.isfile(p2) and p2 not in paths:
            paths.append(p2)
    return paths


def parse_ssh_config(filepath: str) -> List[Dict[str, Any]]:
    """Parse OpenSSH configuration file and extract Host blocks."""
    hosts = []
    if not os.path.isfile(filepath):
        return hosts

    current_host: Optional[Dict[str, Any]] = None

    try:
        with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line_str = line.strip()
                if not line_str or line_str.startswith("#"):
                    continue

                parts = line_str.split(None, 1)
                if not parts:
                    continue

                key = parts[0].lower()
                val = parts[1] if len(parts) > 1 else ""

                if key == "host":
                    # Can have multiple host aliases on one line
                    host_aliases = [h for h in val.split() if not any(c in h for c in "*?")]
                    for alias in host_aliases:
                        if alias:
                            if current_host:
                                hosts.append(current_host)
                            current_host = {
                                "name": alias,
                                "hostname": alias,
                                "user": "",
                                "port": "22",
                                "key": "",
                                "proxy": "",
                                "source": "ssh-config",
                                "source_file": filepath,
                                "raw_config": []
                            }
                elif current_host:
                    current_host["raw_config"].append(line_str)
                    if key == "hostname":
                        current_host["hostname"] = val
                    elif key == "user":
                        current_host["user"] = val
                    elif key == "port":
                        current_host["port"] = val
                    elif key in ("identityfile", "identity_file"):
                        current_host["key"] = val
                    elif key in ("proxyjump", "proxycommand"):
                        current_host["proxy"] = val

            if current_host:
                hosts.append(current_host)
    except Exception:
        pass

    return hosts


def parse_known_hosts(filepath: str) -> List[Dict[str, Any]]:
    """Parse OpenSSH known_hosts file."""
    hosts = []
    if not os.path.isfile(filepath):
        return hosts

    try:
        with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line_str = line.strip()
                if not line_str or line_str.startswith("#") or line_str.startswith("|1|"):
                    # Skip empty, comments, and hashed hosts
                    continue

                first_token = line_str.split()[0]
                # Can be comma-separated list of hostnames / IP addresses
                for entry in first_token.split(","):
                    # Remove [host]:port notation
                    port = "22"
                    m = re.match(r"^\[(.+)\]:(\d+)$", entry)
                    if m:
                        host_name = m.group(1)
                        port = m.group(2)
                    else:
                        host_name = entry

                    if host_name and not host_name.startswith("@"):
                        hosts.append({
                            "name": host_name,
                            "hostname": host_name,
                            "user": "",
                            "port": port,
                            "key": "",
                            "proxy": "",
                            "source": "known-hosts",
                            "source_file": filepath,
                            "raw_config": []
                        })
    except Exception:
        pass

    return hosts


def parse_putty_sessions() -> List[Dict[str, Any]]:
    """Retrieve saved PuTTY sessions from Windows Registry."""
    sessions = []
    if sys.platform != "win32":
        # Check if WSL running and reg.exe available
        if sys.platform == "linux" and os.path.exists("/proc/version"):
            try:
                with open("/proc/version", "r") as f:
                    if "microsoft" in f.read().lower() and shutil.which("reg.exe"):
                        res = subprocess.run(
                            ["reg.exe", "query", r"HKCU\Software\SimonTatham\PuTTY\Sessions"],
                            capture_output=True, text=True, check=False
                        )
                        for line in res.stdout.splitlines():
                            line = line.strip()
                            if "PuTTY\\Sessions\\" in line:
                                s_raw = line.split("PuTTY\\Sessions\\")[-1]
                                s_name = urllib.parse.unquote(s_raw)
                                sessions.append({
                                    "name": s_name,
                                    "hostname": s_name,
                                    "user": "",
                                    "port": "22",
                                    "key": "",
                                    "proxy": "",
                                    "source": "putty",
                                    "source_file": "Registry: PuTTY Sessions",
                                    "raw_config": []
                                })
            except Exception:
                pass
        return sessions

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

                host_val = get_val(sub_key, "HostName")
                user_val = get_val(sub_key, "UserName")
                port_val = get_val(sub_key, "PortNumber", "22")
                key_val = get_val(sub_key, "PublicKeyFile")

                if session_name != "Default Settings":
                    sessions.append({
                        "name": session_name,
                        "hostname": host_val if host_val else session_name,
                        "user": user_val,
                        "port": port_val,
                        "key": key_val,
                        "proxy": "",
                        "source": "putty",
                        "source_file": "Registry: PuTTY Sessions",
                        "raw_config": []
                    })
                idx += 1
            except OSError:
                break
    except Exception:
        pass

    return sessions


def parse_etc_hosts() -> List[Dict[str, Any]]:
    """Parse local hosts file."""
    hosts = []
    files_to_check = ["/etc/hosts"]
    win_dir = os.environ.get("SystemRoot", r"C:\Windows")
    files_to_check.append(os.path.join(win_dir, "System32", "drivers", "etc", "hosts"))

    ignore_patterns = {"localhost", "broadcasthost", "ip6-localhost", "ip6-loopback", "local"}

    for path in files_to_check:
        if os.path.isfile(path):
            try:
                with open(path, "r", encoding="utf-8", errors="ignore") as f:
                    for line in f:
                        line_str = line.strip()
                        if not line_str or line_str.startswith("#"):
                            continue
                        parts = line_str.split()
                        if len(parts) >= 2:
                            ip = parts[0]
                            if ip in ("127.0.0.1", "::1", "255.255.255.255", "fe00::0", "ff00::0", "ff02::1", "ff02::2"):
                                continue
                            for hostname in parts[1:]:
                                if hostname.lower() not in ignore_patterns:
                                    hosts.append({
                                        "name": hostname,
                                        "hostname": ip,
                                        "user": "",
                                        "port": "22",
                                        "key": "",
                                        "proxy": "",
                                        "source": "etc-hosts",
                                        "source_file": path,
                                        "raw_config": []
                                    })
            except Exception:
                pass

    return hosts


def collect_all_hosts() -> List[Dict[str, Any]]:
    """Aggregate, deduplicate, and sort all available SSH hosts."""
    all_hosts: List[Dict[str, Any]] = []
    seen = set()

    # 1. SSH Config (highest priority)
    for cfg in get_ssh_config_paths():
        for h in parse_ssh_config(cfg):
            key = h["name"].lower()
            if key not in seen:
                seen.add(key)
                all_hosts.append(h)

    # 2. PuTTY Sessions
    for h in parse_putty_sessions():
        key = h["name"].lower()
        if key not in seen:
            seen.add(key)
            all_hosts.append(h)

    # 3. Known Hosts
    known_paths = []
    home = get_home_dir()
    p1 = os.path.join(home, ".ssh", "known_hosts")
    if os.path.isfile(p1):
        known_paths.append(p1)
    userprofile = os.environ.get("USERPROFILE")
    if userprofile:
        p2 = os.path.join(userprofile, ".ssh", "known_hosts")
        if os.path.isfile(p2) and p2 not in known_paths:
            known_paths.append(p2)

    for kp in known_paths:
        for h in parse_known_hosts(kp):
            key = h["name"].lower()
            if key not in seen:
                seen.add(key)
                all_hosts.append(h)

    # 4. /etc/hosts
    for h in parse_etc_hosts():
        key = h["name"].lower()
        if key not in seen:
            seen.add(key)
            all_hosts.append(h)

    # Sort alphabetically by host name
    all_hosts.sort(key=lambda x: x["name"].lower())
    return all_hosts


def format_preview(host_entry: Dict[str, Any]) -> str:
    """Render a structured preview card for fzf preview window."""
    name = host_entry.get("name", "")
    hostname = host_entry.get("hostname", "")
    user = host_entry.get("user", "")
    port = host_entry.get("port", "22")
    key = host_entry.get("key", "")
    proxy = host_entry.get("proxy", "")
    source = host_entry.get("source", "")
    source_file = host_entry.get("source_file", "")

    # Build target string
    if user:
        target_str = f"{user}@{hostname}"
    else:
        target_str = hostname

    cmd_parts = ["ssh"]
    if port and port != "22":
        cmd_parts.extend(["-p", port])
    if key:
        cmd_parts.extend(["-i", key])
    if proxy:
        cmd_parts.extend(["-J", proxy])
    if name != hostname:
        cmd_parts.append(name)
    else:
        cmd_parts.append(target_str)

    ssh_cmd = " ".join(cmd_parts)

    lines = [
        "==================================================",
        f"  SSH Server Info: {name}",
        "==================================================",
        f"  Host / Alias:    {name}",
        f"  HostName / IP:   {hostname}",
        f"  User:            {user if user else '(default / system user)'}",
        f"  Port:            {port}",
    ]
    if key:
        lines.append(f"  IdentityFile:    {key}")
    if proxy:
        lines.append(f"  ProxyJump:       {proxy}")
    lines.append(f"  Source:          [{source}] {source_file}")
    lines.append("--------------------------------------------------")
    lines.append(f"  Connect Command: {ssh_cmd}")
    lines.append("==================================================")

    raw = host_entry.get("raw_config", [])
    if raw:
        lines.append("\n  Config Block:")
        for r in raw:
            lines.append(f"    {r}")

    return "\n".join(lines)


def run_fzf_interactive(hosts: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    """Launch fzf with rich table layout and live preview."""
    fzf_bin = shutil.which("fzf") or shutil.which("fzf.exe")
    if not fzf_bin:
        # Fallback to numbered list
        print("Available SSH Hosts:")
        for idx, h in enumerate(hosts, 1):
            dest = f"{h['user']}@{h['hostname']}" if h.get("user") else h['hostname']
            print(f"  {idx:2d}. {h['name']:<25} {dest:<30} [port {h['port']}] [{h['source']}]")
        try:
            choice = input("Select host number or name: ").strip()
            if not choice:
                return None
            if choice.isdigit() and 1 <= int(choice) <= len(hosts):
                return hosts[int(choice) - 1]
            for h in hosts:
                if choice.lower() == h["name"].lower():
                    return h
        except (KeyboardInterrupt, EOFError):
            return None
        return None

    # Build input lines for fzf: Key \t User@Host \t Port \t Source
    tsv_lines = []
    host_map = {}
    for h in hosts:
        dest = f"{h['user']}@{h['hostname']}" if h.get("user") else h['hostname']
        line = f"{h['name']}\t{dest}\t{h['port']}\t{h['source']}"
        tsv_lines.append(line)
        host_map[h['name']] = h

    fzf_input = "\n".join(tsv_lines).encode("utf-8")

    # Command for fzf preview
    self_script = os.path.abspath(__file__)
    py_exec = sys.executable
    preview_cmd = f'"{py_exec}" "{self_script}" --preview-only {{1}}'

    cmd = [
        fzf_bin,
        "--prompt=Select SSH Host > ",
        "--delimiter=\t",
        "--with-nth=1,2,3,4",
        "--layout=reverse",
        "--height=50%",
        "--border",
        f"--preview={preview_cmd}",
        "--preview-window=right:55%:wrap",
        "--header=ENTER: Connect | ESC: Cancel"
    ]

    try:
        proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=None)
        stdout, _ = proc.communicate(input=fzf_input)
        if proc.returncode == 0 and stdout:
            selected_line = stdout.decode("utf-8", errors="ignore").strip()
            if selected_line:
                selected_key = selected_line.split("\t")[0]
                return host_map.get(selected_key)
    except Exception as e:
        print(f"Error running fzf: {e}", file=sys.stderr)

    return None


def main():
    args = sys.argv[1:]
    all_hosts = collect_all_hosts()

    # 1. Preview Only mode (used by fzf)
    if len(args) >= 2 and args[0] in ("-p", "--preview-only"):
        target_name = args[1].lower()
        for h in all_hosts:
            if h["name"].lower() == target_name or h["hostname"].lower() == target_name:
                print(format_preview(h))
                return
        # If not found, print fallback
        print(f"Host: {args[1]}")
        return

    # 2. List mode (TSV output)
    if len(args) >= 1 and args[0] in ("-l", "--list"):
        for h in all_hosts:
            dest = f"{h['user']}@{h['hostname']}" if h.get("user") else h['hostname']
            print(f"{h['name']}\t{dest}\t{h['port']}\t{h['source']}")
        return

    # 3. Parse options
    dry_run = False
    use_putty = False
    override_user = ""
    query = ""
    extra_ssh_args = []

    idx = 0
    while idx < len(args):
        arg = args[idx]
        if arg in ("-h", "--help", "/?"):
            print(__doc__)
            return
        elif arg in ("-d", "--dry-run"):
            dry_run = True
        elif arg == "--putty":
            use_putty = True
        elif arg in ("-u", "--user") and idx + 1 < len(args):
            idx += 1
            override_user = args[idx]
        elif arg == "--":
            extra_ssh_args.extend(args[idx + 1:])
            break
        elif not query and not arg.startswith("-"):
            query = arg
        else:
            extra_ssh_args.append(arg)
        idx += 1

    selected_host: Optional[Dict[str, Any]] = None

    if query:
        # Match query directly or prefix match
        q_lower = query.lower()
        for h in all_hosts:
            if h["name"].lower() == q_lower:
                selected_host = h
                break
        if not selected_host:
            for h in all_hosts:
                if q_lower in h["name"].lower() or q_lower in h["hostname"].lower():
                    selected_host = h
                    break

        if not selected_host:
            print(f"[ERROR] No configured host matches '{query}'.", file=sys.stderr)
            print("Available hosts:", file=sys.stderr)
            for h in all_hosts[:15]:
                print(f"  - {h['name']}", file=sys.stderr)
            if len(all_hosts) > 15:
                print(f"  ... and {len(all_hosts) - 15} more", file=sys.stderr)
            sys.exit(1)
    else:
        # Interactive selection
        if not all_hosts:
            print("No SSH hosts found in ~/.ssh/config, ~/.ssh/known_hosts, or PuTTY sessions.")
            sys.exit(0)
        selected_host = run_fzf_interactive(all_hosts)

    if not selected_host:
        print("No host selected.")
        return

    # Build connection command
    name = selected_host["name"]
    hostname = selected_host["hostname"]
    config_user = selected_host.get("user", "")
    user = override_user or config_user
    port = selected_host.get("port", "22")
    key = selected_host.get("key", "")
    proxy = selected_host.get("proxy", "")
    source = selected_host.get("source", "")

    # If no user is configured and no CLI override provided, prompt interactively
    if not user and sys.stdin.isatty():
        try:
            default_user = getpass.getuser()
        except Exception:
            default_user = os.environ.get("USER") or os.environ.get("USERNAME") or ""

        try:
            prompt_str = (
                f"[fssh] No user configured for '{name}'. Enter remote user [{default_user}]: "
                if default_user
                else f"[fssh] No user configured for '{name}'. Enter remote user: "
            )
            entered_user = input(prompt_str).strip()
            user = entered_user if entered_user else default_user
        except (KeyboardInterrupt, EOFError):
            print("\n[fssh] Connection cancelled.")
            return

    # Handle PuTTY connection if requested
    if use_putty or (source == "putty" and sys.platform == "win32" and not shutil.which("ssh")):
        putty_bin = shutil.which("putty") or shutil.which("putty.exe") or r"C:\app\putty\putty.exe"
        if os.path.isfile(putty_bin) or shutil.which("putty"):
            putty_cmd = [putty_bin, "-load", name]
            if user and user != config_user:
                putty_cmd.extend(["-l", user])
            if dry_run:
                print("Dry run:", " ".join(putty_cmd))
                return
            print(f"[fssh] Launching PuTTY session: {name}...")
            subprocess.Popen(putty_cmd)
            return

    # Standard OpenSSH command
    ssh_bin = shutil.which("ssh") or shutil.which("ssh.exe") or "ssh"
    cmd = [ssh_bin]

    # Add port if not 22 and source is not an exact ssh_config alias that already specifies port
    if source != "ssh-config" and port and port != "22":
        cmd.extend(["-p", port])

    # Add identity file if not from ssh-config
    if source != "ssh-config" and key:
        cmd.extend(["-i", key])

    # Target
    if source == "ssh-config":
        if user and user != config_user:
            cmd.append(f"{user}@{name}")
        else:
            cmd.append(name)
    else:
        if user:
            cmd.append(f"{user}@{hostname}")
        else:
            cmd.append(hostname)

    # Append any extra user arguments
    if extra_ssh_args:
        cmd.extend(extra_ssh_args)

    if dry_run:
        print("Dry run:", " ".join(cmd))
        return

    print(f"[fssh] Connecting to {name} ({hostname})...")

    # Replace current process or run interactively
    if sys.platform == "win32":
        res = subprocess.run(cmd)
        sys.exit(res.returncode)
    else:
        os.execvp(cmd[0], cmd)


if __name__ == "__main__":
    main()
