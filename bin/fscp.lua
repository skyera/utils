#!/usr/bin/env luajit
--[[
  fscp.lua - Ultra-fast Interactive Fuzzy Remote File Transfer (SCP & Rsync).
  Powered by LuaJIT & FFI. Sub-millisecond FZF preview response.
  Fully cross-platform: Windows (Win32 FFI / Registry) & Linux/POSIX.

  Features:
    - Interactive fuzzy host selector (SSH config, known_hosts, PuTTY sessions, /etc/hosts)
    - Interactive fuzzy local file picker (multi-select with TAB)
    - Supports Push (Local -> Remote) and Pull (Remote -> Local)
    - Transparent SCP and Rsync support (use --rsync or invoke as frsync)
    - Sub-millisecond FZF host preview (< 1 ms)
    - Supports custom ports, identity files, and user overrides
    - Windows PuTTY session integration via pscp.exe

  Usage:
    fscp.lua [OPTIONS] [LOCAL_FILES...]

  Options:
    -r, --rsync                 Use rsync instead of scp (-avzP)
    -P, --pull                  Pull mode (download from remote to current directory)
    -t, --to <REMOTE_PATH>      Destination directory on remote host (default: ~/)
    -H, --host <HOST>           Pre-select remote host (skip interactive host picker)
    -u, --user <USER>           Override SSH remote user
    -p, --port <PORT>           Override SSH port
    -i, --identity <KEY>        Specify SSH private key file
    -d, --dry-run               Print command without executing
    -l, --list-hosts            List aggregated hosts in TSV format
    --preview-only <HOST>       Print host preview card (used by fzf)
    -h, --help                  Show this help message
]]

local ffi = require("ffi")

local OS = ffi.os
local IS_LINUX = (OS == "Linux")
local IS_WINDOWS = (OS == "Windows")

--------------------------------------------------------------------------------
-- FFI Declarations
--------------------------------------------------------------------------------
if not IS_WINDOWS then
    ffi.cdef[[
        int execvp(const char *file, char *const argv[]);
        int isatty(int fd);
    ]]
else
    ffi.cdef[[
        typedef void* HANDLE;
        typedef void* HKEY;
        typedef unsigned long DWORD;
        typedef long LONG;
        typedef unsigned char BYTE;

        LONG RegOpenKeyExA(HKEY hKey, const char* lpSubKey, DWORD ulOptions, DWORD samDesired, HKEY* phkResult);
        LONG RegEnumKeyExA(HKEY hKey, DWORD dwIndex, char* lpName, DWORD* lpcchName, DWORD* lpReserved, char* lpClass, DWORD* lpcchClass, void* lpftLastWriteTime);
        LONG RegQueryValueExA(HKEY hKey, const char* lpValueName, DWORD* lpReserved, DWORD* lpType, BYTE* lpData, DWORD* lpcbData);
        LONG RegCloseKey(HKEY hKey);

        typedef int BOOL;
        HANDLE GetStdHandle(DWORD nStdHandle);
        BOOL GetConsoleMode(HANDLE hConsoleHandle, DWORD* lpMode);
        BOOL SetConsoleMode(HANDLE hConsoleHandle, DWORD dwMode);
        BOOL SetConsoleOutputCP(unsigned int wCodePageID);
        BOOL SetConsoleCP(unsigned int wCodePageID);
    ]]

    pcall(function()
        local bit = require("bit")
        ffi.C.SetConsoleOutputCP(65001)
        ffi.C.SetConsoleCP(65001)
        local hOut = ffi.C.GetStdHandle(ffi.cast("DWORD", -11))
        if hOut ~= nil and hOut ~= ffi.cast("HANDLE", -1) then
            local mode = ffi.new("DWORD[1]")
            if ffi.C.GetConsoleMode(hOut, mode) ~= 0 then
                ffi.C.SetConsoleMode(hOut, bit.bor(mode[0], 0x0004))
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- ANSI Colors
--------------------------------------------------------------------------------
local C = {
    reset   = "\27[0m",
    bold    = "\27[1m",
    dim     = "\27[2m",
    cyan    = "\27[36m",
    green   = "\27[32m",
    yellow  = "\27[33m",
    blue    = "\27[34m",
    magenta = "\27[35m",
    red     = "\27[31m",
    white   = "\27[37m",
    gray    = "\27[90m",
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function get_home_dir()
    return os.getenv("HOME") or os.getenv("USERPROFILE") or "."
end

local function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

local function trim(s)
    if not s then return "" end
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function url_decode(str)
    return (str:gsub("%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end))
end

local function shell_escape(s)
    if not s:find("[^%w_%-%.%/:]") then
        return s
    end
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

--------------------------------------------------------------------------------
-- Host Aggregation (SSH Config, known_hosts, PuTTY Registry, /etc/hosts)
--------------------------------------------------------------------------------
local function get_ssh_config_paths()
    local paths = {}
    local seen = {}
    local home = get_home_dir()

    local p1 = home .. "/.ssh/config"
    if file_exists(p1) and not seen[p1] then
        table.insert(paths, p1)
        seen[p1] = true
    end

    local userprofile = os.getenv("USERPROFILE")
    if userprofile then
        local p2 = userprofile:gsub("\\", "/") .. "/.ssh/config"
        if file_exists(p2) and not seen[p2] then
            table.insert(paths, p2)
            seen[p2] = true
        end
    end
    return paths
end

local function parse_ssh_config(filepath, visited)
    visited = visited or {}
    local hosts = {}
    if visited[filepath] or not file_exists(filepath) then
        return hosts
    end
    visited[filepath] = true

    local f = io.open(filepath, "r")
    if not f then return hosts end

    local current_aliases = {}
    local current_params = {}

    local function flush_block()
        if #current_aliases == 0 then return end
        local explicit_host = current_params.hostname or ""
        for _, alias in ipairs(current_aliases) do
            local entry = {
                name = alias,
                hostname = (explicit_host ~= "") and explicit_host or alias,
                user = current_params.user or "",
                port = current_params.port or "22",
                key = current_params.key or "",
                proxy = current_params.proxy or "",
                source = "ssh-config",
                source_file = filepath,
            }
            table.insert(hosts, entry)
        end
        current_aliases = {}
        current_params = {}
    end

    for line in f:lines() do
        local line_str = trim(line)
        if line_str ~= "" and not line_str:match("^#") then
            local k, v = line_str:match("^([%w_]+)%s*=?%s*(.*)$")
            if k and v then
                local key = k:lower()
                local val = trim(v):gsub('^["\']', ''):gsub('["\']$', '')

                if key == "include" then
                    flush_block()
                    for pattern in val:gmatch("%S+") do
                        local expanded = pattern:gsub("^~", get_home_dir())
                        if not expanded:match("^/") and not expanded:match("^%a:") then
                            local dir = filepath:match("^(.*)[/\\]") or (get_home_dir() .. "/.ssh")
                            expanded = dir .. "/" .. expanded
                        end
                        local p_pipe = io.popen(string.format("ls -1d %s 2>/dev/null", expanded))
                        if p_pipe then
                            for inc_file in p_pipe:lines() do
                                if file_exists(inc_file) then
                                    local sub_hosts = parse_ssh_config(inc_file, visited)
                                    for _, sh in ipairs(sub_hosts) do
                                        table.insert(hosts, sh)
                                    end
                                end
                            end
                            p_pipe:close()
                        end
                    end
                elseif key == "host" then
                    flush_block()
                    local valid_aliases = {}
                    for alias in val:gmatch("%S+") do
                        if not alias:find("[*?]") then
                            table.insert(valid_aliases, alias)
                        end
                    end
                    current_aliases = valid_aliases
                elseif #current_aliases > 0 then
                    if key == "hostname" then
                        current_params.hostname = val
                    elseif key == "user" then
                        current_params.user = val
                    elseif key == "port" then
                        current_params.port = val
                    elseif key == "identityfile" then
                        current_params.key = val:gsub("^~", get_home_dir())
                    elseif key == "proxyjump" then
                        current_params.proxy = val
                    end
                end
            end
        end
    end
    flush_block()
    f:close()
    return hosts
end

local function parse_known_hosts(filepath)
    local hosts = {}
    if not file_exists(filepath) then return hosts end
    local f = io.open(filepath, "r")
    if not f then return hosts end

    for line in f:lines() do
        local line_str = trim(line)
        if line_str ~= "" and not line_str:match("^#") and not line_str:match("^|1|") then
            local host_part = line_str:match("^(%S+)")
            if host_part then
                for single_host in host_part:gmatch("[^,]+") do
                    local host, port = single_host:match("^%[(.-)%]:(%d+)$")
                    if not host then
                        host = single_host
                        port = "22"
                    end
                    if host ~= "" and not host:find("[*?]") then
                        table.insert(hosts, {
                            name = host,
                            hostname = host,
                            user = "",
                            port = port,
                            key = "",
                            source = "known_hosts",
                            source_file = filepath,
                        })
                    end
                end
            end
        end
    end
    f:close()
    return hosts
end

local function parse_putty_sessions_win32()
    local hosts = {}
    if not IS_WINDOWS then return hosts end

    local HKEY_CURRENT_USER = ffi.cast("HKEY", 0x80000001)
    local KEY_READ = 0x20019
    local phk = ffi.new("HKEY[1]")
    local subkey = "Software\\SimonTatham\\PuTTY\\Sessions"

    if ffi.C.RegOpenKeyExA(HKEY_CURRENT_USER, subkey, 0, KEY_READ, phk) ~= 0 then
        return hosts
    end
    local hSessions = phk[0]

    local index = 0
    local name_buf = ffi.new("char[256]")
    local name_len = ffi.new("DWORD[1]", 256)

    while ffi.C.RegEnumKeyExA(hSessions, index, name_buf, name_len, nil, nil, nil, nil) == 0 do
        local session_encoded = ffi.string(name_buf, name_len[0])
        local session_name = url_decode(session_encoded)

        if session_name ~= "Default Settings" then
            local phkSub = ffi.new("HKEY[1]")
            if ffi.C.RegOpenKeyExA(hSessions, session_encoded, 0, KEY_READ, phkSub) == 0 then
                local hSub = phkSub[0]
                local data_buf = ffi.new("char[256]")
                local data_len = ffi.new("DWORD[1]", 256)
                local dword_val = ffi.new("DWORD[1]")
                local dword_len = ffi.new("DWORD[1]", ffi.sizeof("DWORD"))

                local hostname = ""
                data_len[0] = 256
                if ffi.C.RegQueryValueExA(hSub, "HostName", nil, nil, ffi.cast("BYTE*", data_buf), data_len) == 0 then
                    hostname = trim(ffi.string(data_buf))
                end

                local user = ""
                data_len[0] = 256
                if ffi.C.RegQueryValueExA(hSub, "UserName", nil, nil, ffi.cast("BYTE*", data_buf), data_len) == 0 then
                    user = trim(ffi.string(data_buf))
                end

                local port = "22"
                if ffi.C.RegQueryValueExA(hSub, "PortNumber", nil, nil, ffi.cast("BYTE*", dword_val), dword_len) == 0 then
                    port = tostring(dword_val[0])
                end

                local key_file = ""
                data_len[0] = 256
                if ffi.C.RegQueryValueExA(hSub, "PublicKeyFile", nil, nil, ffi.cast("BYTE*", data_buf), data_len) == 0 then
                    key_file = trim(ffi.string(data_buf))
                end

                ffi.C.RegCloseKey(hSub)

                if hostname ~= "" then
                    table.insert(hosts, {
                        name = session_name,
                        hostname = hostname,
                        user = user,
                        port = port,
                        key = key_file,
                        source = "putty",
                        source_file = "Registry: HKCU\\Software\\SimonTatham\\PuTTY\\Sessions",
                    })
                end
            end
        end
        index = index + 1
        name_len[0] = 256
    end
    ffi.C.RegCloseKey(hSessions)
    return hosts
end

local function parse_hosts_file()
    local hosts = {}
    local path = IS_WINDOWS and "C:\\Windows\\System32\\drivers\\etc\\hosts" or "/etc/hosts"
    if not file_exists(path) then return hosts end
    local f = io.open(path, "r")
    if not f then return hosts end

    for line in f:lines() do
        local line_str = trim(line)
        if line_str ~= "" and not line_str:match("^#") then
            local ip, names = line_str:match("^(%S+)%s+(.+)$")
            if ip and not ip:match("^fe80") and not ip:match("^::1") and ip ~= "127.0.0.1" and ip ~= "localhost" then
                for n in names:gmatch("%S+") do
                    if not n:match("^#") and n ~= "localhost" then
                        table.insert(hosts, {
                            name = n,
                            hostname = ip,
                            user = "",
                            port = "22",
                            key = "",
                            source = "hosts-file",
                            source_file = path,
                        })
                    end
                end
            end
        end
    end
    f:close()
    return hosts
end

local function collect_all_hosts()
    local all_hosts = {}
    local seen = {}

    local function add_host(h)
        local key = (h.name .. "|" .. h.hostname .. "|" .. h.port):lower()
        if not seen[key] then
            seen[key] = true
            table.insert(all_hosts, h)
        end
    end

    for _, path in ipairs(get_ssh_config_paths()) do
        for _, h in ipairs(parse_ssh_config(path)) do
            add_host(h)
        end
    end

    for _, h in ipairs(parse_putty_sessions_win32()) do
        add_host(h)
    end

    local home = get_home_dir()
    for _, h in ipairs(parse_known_hosts(home .. "/.ssh/known_hosts")) do
        add_host(h)
    end

    for _, h in ipairs(parse_hosts_file()) do
        add_host(h)
    end

    return all_hosts
end

--------------------------------------------------------------------------------
-- Preview Formatter (< 1 ms response)
--------------------------------------------------------------------------------
local function format_preview(h)
    local lines = {}
    table.insert(lines, string.format("%s%s=== Target Remote Host: %s ===%s", C.bold, C.cyan, h.name, C.reset))
    table.insert(lines, "")
    table.insert(lines, string.format("  %sHostname / IP :%s %s", C.yellow, C.reset, h.hostname))
    table.insert(lines, string.format("  %sRemote User   :%s %s", C.yellow, C.reset, (h.user ~= "" and h.user or string.format("%s(default)%s", C.dim, C.reset))))
    table.insert(lines, string.format("  %sPort          :%s %s", C.yellow, C.reset, h.port or "22"))
    if h.key and h.key ~= "" then
        table.insert(lines, string.format("  %sIdentity Key  :%s %s", C.yellow, C.reset, h.key))
    end
    table.insert(lines, string.format("  %sSource        :%s %s%s%s", C.yellow, C.reset, C.magenta, h.source, C.reset))
    if h.source_file and h.source_file ~= "" then
        table.insert(lines, string.format("  %sConfig File   :%s %s%s%s", C.dim, C.reset, C.dim, h.source_file, C.reset))
    end
    table.insert(lines, "")
    table.insert(lines, string.format("%s%sAvailable Actions:%s", C.bold, C.white, C.reset))
    table.insert(lines, string.format("  %s• Push Files  :%s Upload selected local files to %s:~/", C.green, C.reset, h.name))
    table.insert(lines, string.format("  %s• Pull Files  :%s Run with %s--pull%s to download files from %s", C.green, C.reset, C.yellow, C.reset, h.name))
    table.insert(lines, string.format("  %s• Rsync Mode  :%s Fast delta transfer with progress bar (-r)", C.green, C.reset))
    return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- Interactive FZF Host Selector
--------------------------------------------------------------------------------
local function run_fzf_host_picker(hosts)
    local script_path = arg[0] or "fscp.lua"

    local fzf_cmd = string.format(
        'luajit %q --list-hosts | fzf --prompt="[fscp] Remote Host > " --delimiter="\t" --with-nth=1,2,3,4 ' ..
        '--layout=reverse --height=50%% --border --preview="luajit %q --preview-only {1}" --preview-window=right:50%%:wrap ' ..
        '--header="⚡ LuaJIT FFI | ENTER: Select Host | ESC: Cancel"',
        script_path, script_path
    )

    local pipe = io.popen(fzf_cmd, "r")
    if not pipe then
        io.stderr:write("Error: fzf is not installed or failed to launch.\n")
        return nil
    end

    local output = pipe:read("*line")
    pipe:close()

    if output and output ~= "" then
        local key = output:match("^[^\t]+")
        for _, h in ipairs(hosts) do
            if h.name == key then
                return h
            end
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Interactive FZF Local File Picker (Multi-select)
--------------------------------------------------------------------------------
local function run_fzf_file_picker()
    local preview_cmd
    if IS_WINDOWS then
        preview_cmd = "if exist {} ( dir /b /a {} 2>nul || type {} 2>nul )"
    else
        preview_cmd = "if [ -d {} ]; then ls -la --color=always {}; else head -n 40 {} 2>/dev/null || file {}; fi"
    end

    local list_cmd
    if IS_WINDOWS then
        list_cmd = "dir /b /a-d 2>nul"
    else
        list_cmd = "find . -maxdepth 3 -not -path '*/.*' 2>/dev/null | sed 's|^\\./||'"
    end

    local fzf_cmd = string.format(
        '%s | fzf -m --prompt="[fscp] Select File(s) to Send > " ' ..
        '--layout=reverse --height=55%% --border --preview=%q --preview-window=right:50%%:wrap ' ..
        '--header="TAB: Multi-select | ENTER: Confirm | ESC: Cancel"',
        list_cmd, preview_cmd
    )

    local pipe = io.popen(fzf_cmd, "r")
    if not pipe then return {} end

    local selected = {}
    for line in pipe:lines() do
        local l = trim(line)
        if l ~= "" then
            table.insert(selected, l)
        end
    end
    pipe:close()
    return selected
end

--------------------------------------------------------------------------------
-- Interactive FZF Remote File Browser (Pull Mode)
--------------------------------------------------------------------------------
local function run_fzf_remote_file_picker(host, override_user, override_port, override_key)
    local name = host.name
    local hostname = host.hostname
    local config_user = host.user or ""
    local user = (override_user ~= "") and override_user or config_user
    local port = (override_port ~= "") and override_port or (host.port or "22")
    local key = (override_key ~= "") and override_key or (host.key or "")
    local source = host.source or ""

    local target_host = (source == "ssh-config") and name or hostname
    local host_str = (user ~= "" and user ~= config_user) and string.format("%s@%s", user, target_host) or target_host
    if source ~= "ssh-config" and user ~= "" and not host_str:find("@") then
        host_str = string.format("%s@%s", user, target_host)
    end

    local ssh_cmd_parts = { "ssh", "-o", "ConnectTimeout=4", "-o", "BatchMode=yes" }
    if port ~= "22" and port ~= "" then
        table.insert(ssh_cmd_parts, "-p")
        table.insert(ssh_cmd_parts, port)
    end
    if key ~= "" then
        table.insert(ssh_cmd_parts, "-i")
        table.insert(ssh_cmd_parts, shell_escape(key))
    end
    table.insert(ssh_cmd_parts, host_str)
    local ssh_base = table.concat(ssh_cmd_parts, " ")

    local current_remote_dir = "."

    while true do
        local dir_display = (current_remote_dir == ".") and "~/" or (current_remote_dir .. "/")
        local remote_cmd = string.format("%s 'ls -1ap %s 2>/dev/null'", ssh_base, shell_escape(current_remote_dir))

        -- Check connection and list
        local pipe = io.popen(remote_cmd, "r")
        local lines = {}
        if pipe then
            for l in pipe:lines() do
                local item = trim(l)
                if item ~= "" and item ~= "./" then
                    table.insert(lines, item)
                end
            end
            pipe:close()
        end

        if #lines == 0 then
            -- Remote connection failed or empty / inaccessible directory
            return nil
        end

        -- Build candidate list with an option to download current directory
        local candidates = { string.format("⚡ [PULL CURRENT FOLDER: %s]", dir_display) }
        for _, it in ipairs(lines) do
            table.insert(candidates, it)
        end

        local input_data = table.concat(candidates, "\n")
        local fzf_prompt = string.format("[fpull] %s:%s > ", name, dir_display)
        local fzf_cmd = string.format(
            'fzf --prompt=%q --layout=reverse --height=60%% --border ' ..
            '--header="ENTER: Navigate / Select | ESC: Manual Path"',
            fzf_prompt
        )

        local fzf_pipe
        if IS_WINDOWS then
            local tmp_path = os.getenv("TEMP") or "."
            local tmp_file = tmp_path .. "\\fscp_remote_list.tmp"
            local f = io.open(tmp_file, "w")
            if f then
                f:write(input_data)
                f:close()
                fzf_pipe = io.popen(string.format('type "%s" | %s', tmp_file, fzf_cmd), "r")
            end
        else
            fzf_pipe = io.popen(string.format('printf %%s %s | %s', shell_escape(input_data), fzf_cmd), "r")
        end

        if not fzf_pipe then return nil end

        local selection = fzf_pipe:read("*line")
        fzf_pipe:close()

        if not selection or trim(selection) == "" then
            return nil
        end
        selection = trim(selection)

        if selection:find("^⚡ %[PULL CURRENT FOLDER:") then
            return (current_remote_dir == ".") and "~/" or current_remote_dir
        elseif selection == "../" then
            if current_remote_dir == "." or current_remote_dir == "" then
                current_remote_dir = ".."
            elseif current_remote_dir == ".." then
                current_remote_dir = "../.."
            else
                current_remote_dir = current_remote_dir:match("^(.*)/[^/]+$") or "."
            end
        elseif selection:sub(-1) == "/" then
            -- Directory selected: navigate into it
            local sub_dir = selection:sub(1, -2)
            if current_remote_dir == "." then
                current_remote_dir = sub_dir
            else
                current_remote_dir = current_remote_dir .. "/" .. sub_dir
            end
        else
            -- File selected: return full path
            if current_remote_dir == "." then
                return selection
            else
                return current_remote_dir .. "/" .. selection
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Transfer Execution Engine
--------------------------------------------------------------------------------
local function execute_transfer(host, local_files, remote_path, pull_mode, use_rsync, override_user, override_port, override_key, dry_run)
    local name = host.name
    local hostname = host.hostname
    local config_user = host.user or ""
    local user = (override_user ~= "") and override_user or config_user
    local port = (override_port ~= "") and override_port or (host.port or "22")
    local key = (override_key ~= "") and override_key or (host.key or "")
    local source = host.source or ""

    remote_path = (remote_path ~= "") and remote_path or "~/"

    -- PuTTY Windows PSCP mode
    if IS_WINDOWS and (source == "putty" and not use_rsync) then
        local pscp_bin = "pscp.exe"
        local p_cmd = { pscp_bin, "-load", name, "-r" }
        if user ~= "" and user ~= config_user then
            table.insert(p_cmd, "-l")
            table.insert(p_cmd, user)
        end
        if port ~= "22" and port ~= "" then
            table.insert(p_cmd, "-P")
            table.insert(p_cmd, port)
        end
        if key ~= "" then
            table.insert(p_cmd, "-i")
            table.insert(p_cmd, key)
        end

        if pull_mode then
            local remote_spec = string.format("%s:%s", name, remote_path)
            table.insert(p_cmd, remote_spec)
            table.insert(p_cmd, ".")
        else
            for _, f in ipairs(local_files) do
                table.insert(p_cmd, f)
            end
            table.insert(p_cmd, string.format("%s:%s", name, remote_path))
        end

        if dry_run then
            print("Dry run: " .. table.concat(p_cmd, " "))
            return
        end
        print(string.format("[fscp] Launching PSCP with PuTTY session '%s'...", name))
        os.execute(table.concat(p_cmd, " "))
        return
    end

    -- Construct Remote Host String
    local target_host = (source == "ssh-config") and name or hostname
    local host_str = (user ~= "" and user ~= config_user) and string.format("%s@%s", user, target_host) or target_host
    if source ~= "ssh-config" and user ~= "" and not host_str:find("@") then
        host_str = string.format("%s@%s", user, target_host)
    end

    local cmd = {}

    if use_rsync then
        cmd = { "rsync", "-avzP" }
        local ssh_opts = {}
        if port ~= "22" and port ~= "" then
            table.insert(ssh_opts, "-p " .. port)
        end
        if key ~= "" then
            table.insert(ssh_opts, "-i " .. shell_escape(key))
        end
        if #ssh_opts > 0 then
            table.insert(cmd, "-e")
            table.insert(cmd, string.format("ssh %s", table.concat(ssh_opts, " ")))
        end

        if pull_mode then
            table.insert(cmd, string.format("%s:%s", host_str, remote_path))
            table.insert(cmd, "./")
        else
            for _, f in ipairs(local_files) do
                table.insert(cmd, f)
            end
            table.insert(cmd, string.format("%s:%s", host_str, remote_path))
        end
    else
        -- Standard SCP
        cmd = { "scp", "-r" }
        if port ~= "22" and port ~= "" then
            table.insert(cmd, "-P")
            table.insert(cmd, port)
        end
        if key ~= "" then
            table.insert(cmd, "-i")
            table.insert(cmd, key)
        end

        if pull_mode then
            table.insert(cmd, string.format("%s:%s", host_str, remote_path))
            table.insert(cmd, ".")
        else
            for _, f in ipairs(local_files) do
                table.insert(cmd, f)
            end
            table.insert(cmd, string.format("%s:%s", host_str, remote_path))
        end
    end

    if dry_run then
        print("Dry run: " .. table.concat(cmd, " "))
        return
    end

    print(string.format("%s[fscp] ⚡ Executing: %s%s", C.cyan, table.concat(cmd, " "), C.reset))

    if not IS_WINDOWS then
        local c_args = ffi.new("const char*[?]", #cmd + 1)
        for i, a in ipairs(cmd) do
            c_args[i - 1] = a
        end
        c_args[#cmd] = nil
        ffi.C.execvp(cmd[1], ffi.cast("char* const*", c_args))
    else
        os.execute(table.concat(cmd, " "))
    end
end

--------------------------------------------------------------------------------
-- Main Entry Point
--------------------------------------------------------------------------------
local function main(args)
    -- Check if invoked as frsync or fpull
    local is_rsync = (arg[0] and arg[0]:match("rsync")) and true or false
    local is_fpull = (arg[0] and arg[0]:match("pull")) and true or false

    local pull_mode = is_fpull
    local remote_path = ""
    local target_host_name = nil
    local override_user = ""
    local override_port = ""
    local override_key = ""
    local dry_run = false
    local local_files = {}

    local all_hosts = collect_all_hosts()

    local i = 1
    while i <= #args do
        local a = args[i]
        if a == "-h" or a == "--help" then
            print([[fscp.lua - Interactive Fuzzy Remote File Transfer (LuaJIT FFI)
Usage:
  fscp.lua [OPTIONS] [LOCAL_FILES...]
  fpull    [OPTIONS]

Options:
  -r, --rsync                 Use rsync instead of scp (-avzP)
  -P, --pull                  Pull mode (download remote path to local directory)
  -t, --to <REMOTE_PATH>      Remote path (destination for push, source for pull)
  -H, --host <HOST>           Specify remote host directly (skip FZF host picker)
  -u, --user <USER>           Override remote SSH username
  -p, --port <PORT>           Override remote SSH port
  -i, --identity <KEY>        Specify SSH private key file
  -d, --dry-run               Print transfer command without running
  -l, --list-hosts            Output host list in TSV format
  --preview-only <HOST>       Output host preview card (for FZF)
  -h, --help                  Show this help message

Examples:
  fscp                                # Interactive file picker -> host picker -> push
  fscp build/app.bin                  # Push file -> interactive host picker
  fpull                               # Interactive host picker -> remote file browser -> pull
  fpull -H dev-server -t /tmp/log     # Download /tmp/log directly from dev-server
  frsync -r src/ --to /opt/app/       # Rsync directory to remote
]])
            return
        elseif a == "-l" or a == "--list-hosts" then
            for _, h in ipairs(all_hosts) do
                local dest = (h.user ~= "") and (h.user .. "@" .. h.hostname) or h.hostname
                print(string.format("%s\t%s\t%s\t%s", h.name, dest, h.port, h.source))
            end
            return
        elseif a == "--preview-only" and i + 1 <= #args then
            local target = args[i + 1]:lower():gsub('^["\']', ''):gsub('["\']$', '')
            for _, h in ipairs(all_hosts) do
                if h.name:lower() == target or h.hostname:lower() == target then
                    print(format_preview(h))
                    return
                end
            end
            print("Host: " .. target)
            return
        elseif a == "-r" or a == "--rsync" then
            is_rsync = true
        elseif a == "-P" or a == "--pull" then
            pull_mode = true
        elseif (a == "-t" or a == "--to") and i + 1 <= #args then
            i = i + 1
            remote_path = args[i]
        elseif (a == "-H" or a == "--host") and i + 1 <= #args then
            i = i + 1
            target_host_name = args[i]
        elseif (a == "-u" or a == "--user") and i + 1 <= #args then
            i = i + 1
            override_user = args[i]
        elseif (a == "-p" or a == "--port") and i + 1 <= #args then
            i = i + 1
            override_port = args[i]
        elseif (a == "-i" or a == "--identity") and i + 1 <= #args then
            i = i + 1
            override_key = args[i]
        elseif a == "-d" or a == "--dry-run" then
            dry_run = true
        elseif not a:match("^-") then
            table.insert(local_files, a)
        end
        i = i + 1
    end

    -- 1. Resolve Remote Host
    local selected_host = nil
    if target_host_name then
        local q = target_host_name:lower()
        for _, h in ipairs(all_hosts) do
            if h.name:lower() == q or h.hostname:lower() == q then
                selected_host = h
                break
            end
        end
        if not selected_host then
            io.stderr:write(string.format("[ERROR] Host '%s' not found in configurations.\n", target_host_name))
            os.exit(1)
        end
    else
        if #all_hosts == 0 then
            io.stderr:write("[ERROR] No SSH hosts found in ~/.ssh/config, ~/.ssh/known_hosts, or PuTTY sessions.\n")
            os.exit(1)
        end
        selected_host = run_fzf_host_picker(all_hosts)
    end

    if not selected_host then
        return
    end

    -- 2. Resolve Files
    if pull_mode then
        if remote_path == "" then
            if not dry_run and (IS_WINDOWS or ffi.C.isatty(0) ~= 0) then
                local picked = run_fzf_remote_file_picker(selected_host, override_user, override_port, override_key)
                if picked and picked ~= "" then
                    remote_path = picked
                end
            end

            if remote_path == "" then
                if dry_run or (not IS_WINDOWS and ffi.C.isatty(0) == 0) then
                    remote_path = "~/"
                else
                    io.write(string.format("[fpull] Enter remote file/directory path to pull from %s: ", selected_host.name))
                    io.flush()
                    local line = io.read("*line")
                    if not line or trim(line) == "" then
                        print("No remote path specified. Aborted.")
                        return
                    end
                    remote_path = trim(line)
                end
            end
        end
    else
        -- Push mode: if no files provided on CLI, open interactive file picker
        if #local_files == 0 then
            local_files = run_fzf_file_picker()
            if #local_files == 0 then
                print("No files selected. Aborted.")
                return
            end
        end

        if remote_path == "" then
            local default_dest = "~/"
            if dry_run or (not IS_WINDOWS and ffi.C.isatty(0) == 0) then
                remote_path = default_dest
            else
                io.write(string.format("[fscp] Enter remote destination directory on %s [%s]: ", selected_host.name, default_dest))
                io.flush()
                local line = io.read("*line")
                if line and trim(line) ~= "" then
                    remote_path = trim(line)
                else
                    remote_path = default_dest
                end
            end
        end
    end

    -- 3. Execute Transfer
    execute_transfer(selected_host, local_files, remote_path, pull_mode, is_rsync, override_user, override_port, override_key, dry_run)
end

main({...})
