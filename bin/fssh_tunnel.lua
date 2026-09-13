#!/usr/bin/env luajit
--[[
  fssh_tunnel.lua - High-Performance Interactive SSH Port Forward & Tunnel Manager
  Powered by LuaJIT & FFI. Sub-millisecond pre-flight socket port verification.

  Features:
    1. Host discovery from OpenSSH config, known_hosts, /etc/hosts, and Windows PuTTY sessions (Win32 Registry FFI).
    2. Local Forward (-L), Remote Forward (-R), and Dynamic SOCKS5 Proxy (-D).
    3. Pre-flight port availability verification via C socket FFI (< 0.1 ms) before launching SSH.
    4. Auto-detects port collisions and suggests the next free port.
    5. Built-in service presets (Jupyter, TensorBoard, PostgreSQL, MySQL, Redis, Code-Server, VNC).
    6. Background tunnel tracking with persistent registry (~/.ssh/.fssh_tunnels.json).
    7. Stale tunnel detection & cleanup (checks PID liveness via FFI without subshell overhead).
    8. Interactive FZF tunnel manager to inspect and terminate active tunnels.

  Usage:
    fssh_tunnel.lua [OPTIONS] [HOST]

  Options:
    -L <local_port:remote_host:remote_port>   Local forward
    -R <remote_port:local_host:local_port>   Remote forward
    -D <local_port>                          Dynamic SOCKS5 proxy
    -p, --preset <name>                      Use service preset (jupyter, tensorboard, pg, etc.)
    -b, --background                         Run tunnel in background (-f -N) [default for new tunnels]
    -F, --foreground                         Run tunnel in foreground (keep terminal attached)
    -l, --list                               List currently active background tunnels
    --json                                   Output active tunnels as JSON
    -k, --kill <PID|all>                     Kill active background tunnel(s)
    -m, --manage                             Interactive FZF tunnel manager
    --check-port <port>                      Check if a local TCP port is free
    --hosts                                  List discovered SSH hosts
    -d, --dry-run                            Print SSH command without executing
    -h, --help                               Show this help message
]]

local ffi = require("ffi")

local OS = ffi.os
local IS_LINUX = (OS == "Linux")
local IS_WINDOWS = (OS == "Windows")
local IS_OSX = (OS == "OSX")

--------------------------------------------------------------------------------
-- FFI Declarations
--------------------------------------------------------------------------------
if IS_WINDOWS then
    ffi.cdef[[
        typedef void* HANDLE;
        typedef void* HKEY;
        typedef unsigned long DWORD;
        typedef long LONG;
        typedef unsigned char BYTE;
        typedef int BOOL;
        typedef unsigned int UINT_PTR;
        typedef UINT_PTR SOCKET;

        LONG RegOpenKeyExA(HKEY hKey, const char* lpSubKey, DWORD ulOptions, DWORD samDesired, HKEY* phkResult);
        LONG RegEnumKeyExA(HKEY hKey, DWORD dwIndex, char* lpName, DWORD* lpcchName, DWORD* lpReserved, char* lpClass, DWORD* lpcchClass, void* lpftLastWriteTime);
        LONG RegQueryValueExA(HKEY hKey, const char* lpValueName, DWORD* lpReserved, DWORD* lpType, BYTE* lpData, DWORD* lpcbData);
        LONG RegCloseKey(HKEY hKey);

        HANDLE OpenProcess(DWORD dwDesiredAccess, BOOL bInheritHandle, DWORD dwProcessId);
        BOOL GetExitCodeProcess(HANDLE hProcess, DWORD* lpExitCode);
        BOOL TerminateProcess(HANDLE hProcess, unsigned int uExitCode);
        BOOL CloseHandle(HANDLE hObject);

        HANDLE GetStdHandle(DWORD nStdHandle);
        BOOL GetConsoleMode(HANDLE hConsoleHandle, DWORD* lpMode);
        BOOL SetConsoleMode(HANDLE hConsoleHandle, DWORD dwMode);

        typedef struct {
            unsigned short wVersion;
            unsigned short wHighVersion;
            char szDescription[257];
            char szSystemStatus[129];
            unsigned short iMaxSockets;
            unsigned short iMaxUdpDg;
            char *lpVendorInfo;
        } WSADATA;

        int WSAStartup(unsigned short wVersionRequired, WSADATA *lpWSAData);
        int WSACleanup(void);
        SOCKET socket(int af, int type, int protocol);
        int closesocket(SOCKET s);
        int bind(SOCKET s, const struct sockaddr *name, int namelen);
        int setsockopt(SOCKET s, int level, int optname, const char *optval, int optlen);
        unsigned short htons(unsigned short hostshort);
    ]]
else
    ffi.cdef[[
        int kill(int pid, int sig);
        int isatty(int fd);

        int socket(int domain, int type, int protocol);
        int close(int fd);
        int bind(int sockfd, const void *addr, unsigned int addrlen);
        int setsockopt(int sockfd, int level, int optname, const void *optval, unsigned int optlen);
        unsigned short htons(unsigned short hostshort);
        int inet_pton(int af, const char *src, void *dst);
    ]]
end

--------------------------------------------------------------------------------
-- ANSI Colors
--------------------------------------------------------------------------------
local C = {
    reset  = "\27[0m",
    bold   = "\27[1m",
    dim    = "\27[2m",
    red    = "\27[31m",
    green  = "\27[32m",
    yellow = "\27[33m",
    blue   = "\27[34m",
    magenta= "\27[35m",
    cyan   = "\27[36m",
    white  = "\27[37m",
    bg_blue= "\27[44m",
}

local function setup_console()
    if IS_WINDOWS then
        local hOut = ffi.C.GetStdHandle(-11) -- STD_OUTPUT_HANDLE
        if hOut ~= nil and hOut ~= ffi.cast("HANDLE", -1) then
            local mode = ffi.new("DWORD[1]")
            if ffi.C.GetConsoleMode(hOut, mode) ~= 0 then
                local ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
                ffi.C.SetConsoleMode(hOut, bit.bor(mode[0], ENABLE_VIRTUAL_TERMINAL_PROCESSING))
            end
        end
    end
end
setup_console()

--------------------------------------------------------------------------------
-- Sockets & Port Checking via FFI
--------------------------------------------------------------------------------
local AF_INET = 2
local SOCK_STREAM = 1
local SOL_SOCKET = IS_WINDOWS and 0xffff or 1
local SO_REUSEADDR = IS_WINDOWS and 0x0004 or 2

local wsa_initialized = false
local function init_wsa()
    if IS_WINDOWS and not wsa_initialized then
        local wsadata = ffi.new("WSADATA")
        if ffi.C.WSAStartup(0x0202, wsadata) == 0 then
            wsa_initialized = true
        end
    end
end

-- Checks if a local TCP port is available on 127.0.0.1
local function is_port_free(port)
    port = tonumber(port)
    if not port or port < 1 or port > 65535 then return false, "Invalid port" end

    if IS_WINDOWS then
        init_wsa()
        local s = ffi.C.socket(AF_INET, SOCK_STREAM, 0)
        if s == ffi.cast("SOCKET", -1) or s == ffi.cast("SOCKET", 0xFFFFFFFF) then
            return false, "Failed to create socket"
        end

        local optval = ffi.new("int[1]", 1)
        ffi.C.setsockopt(s, SOL_SOCKET, SO_REUSEADDR, ffi.cast("const char*", optval), ffi.sizeof("int"))

        -- struct sockaddr_in (16 bytes)
        local raw_addr = ffi.new("uint8_t[16]")
        local p_sin_family = ffi.cast("uint16_t*", raw_addr)
        local p_sin_port   = ffi.cast("uint16_t*", raw_addr + 2)
        local p_sin_addr   = ffi.cast("uint32_t*", raw_addr + 4)

        p_sin_family[0] = AF_INET
        p_sin_port[0]   = ffi.C.htons(port)
        p_sin_addr[0]   = 0x0100007F -- 127.0.0.1 in network byte order

        local res = ffi.C.bind(s, ffi.cast("const struct sockaddr*", raw_addr), 16)
        ffi.C.closesocket(s)
        return (res == 0)
    else
        local s = ffi.C.socket(AF_INET, SOCK_STREAM, 0)
        if s < 0 then return false, "Failed to create socket" end

        local optval = ffi.new("int[1]", 1)
        ffi.C.setsockopt(s, SOL_SOCKET, SO_REUSEADDR, optval, ffi.sizeof("int"))

        local raw_addr = ffi.new("uint8_t[16]")
        local p_sin_family = ffi.cast("uint16_t*", raw_addr)
        local p_sin_port   = ffi.cast("uint16_t*", raw_addr + 2)
        local p_sin_addr   = ffi.cast("uint32_t*", raw_addr + 4)

        p_sin_family[0] = AF_INET
        p_sin_port[0]   = ffi.C.htons(port)
        p_sin_addr[0]   = 0x0100007F -- 127.0.0.1 in network byte order

        local res = ffi.C.bind(s, ffi.cast("const void*", raw_addr), 16)
        ffi.C.close(s)
        return (res == 0)
    end
end

-- Find next available port starting from base_port
local function find_next_free_port(base_port)
    base_port = tonumber(base_port) or 8080
    for p = base_port, base_port + 100 do
        if is_port_free(p) then return p end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Process Liveness & Termination via FFI
--------------------------------------------------------------------------------
local function is_process_alive(pid)
    pid = tonumber(pid)
    if not pid or pid <= 0 then return false end

    if IS_WINDOWS then
        local PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
        local SYNCHRONIZE = 0x00100000
        local h = ffi.C.OpenProcess(bit.bor(PROCESS_QUERY_LIMITED_INFORMATION, SYNCHRONIZE), 0, pid)
        if h == nil or h == ffi.cast("HANDLE", 0) then return false end

        local code = ffi.new("DWORD[1]")
        local alive = false
        if ffi.C.GetExitCodeProcess(h, code) ~= 0 then
            alive = (code[0] == 259) -- STILL_ACTIVE = 259
        end
        ffi.C.CloseHandle(h)
        return alive
    else
        -- Signal 0 tests if process exists and can receive signals
        return (ffi.C.kill(pid, 0) == 0)
    end
end

local function kill_process(pid)
    pid = tonumber(pid)
    if not pid or pid <= 0 then return false end

    if IS_WINDOWS then
        local PROCESS_TERMINATE = 0x0001
        local h = ffi.C.OpenProcess(PROCESS_TERMINATE, 0, pid)
        if h == nil or h == ffi.cast("HANDLE", 0) then return false end
        local res = ffi.C.TerminateProcess(h, 1)
        ffi.C.CloseHandle(h)
        return (res ~= 0)
    else
        return (ffi.C.kill(pid, 15) == 0) or (ffi.C.kill(pid, 9) == 0)
    end
end

--------------------------------------------------------------------------------
-- Presets
--------------------------------------------------------------------------------
local PRESETS = {
    jupyter = {
        name = "Jupyter Lab / Notebook",
        mode = "L",
        local_port = 8888,
        remote_host = "127.0.0.1",
        remote_port = 8888,
        desc = "Web browser at http://localhost:8888",
    },
    tensorboard = {
        name = "TensorBoard",
        mode = "L",
        local_port = 6006,
        remote_host = "127.0.0.1",
        remote_port = 6006,
        desc = "Web browser at http://localhost:6006",
    },
    postgres = {
        name = "PostgreSQL Database",
        mode = "L",
        local_port = 5432,
        remote_host = "127.0.0.1",
        remote_port = 5432,
        desc = "psql -h localhost -p 5432",
    },
    mysql = {
        name = "MySQL / MariaDB",
        mode = "L",
        local_port = 3306,
        remote_host = "127.0.0.1",
        remote_port = 3306,
        desc = "mysql -h 127.0.0.1 -P 3306",
    },
    redis = {
        name = "Redis Cache",
        mode = "L",
        local_port = 6379,
        remote_host = "127.0.0.1",
        remote_port = 6379,
        desc = "redis-cli -p 6379",
    },
    codeserver = {
        name = "code-server (VS Code in Browser)",
        mode = "L",
        local_port = 8080,
        remote_host = "127.0.0.1",
        remote_port = 8080,
        desc = "Web browser at http://localhost:8080",
    },
    vnc = {
        name = "VNC Remote Desktop",
        mode = "L",
        local_port = 5901,
        remote_host = "127.0.0.1",
        remote_port = 5901,
        desc = "VNC client connecting to localhost:5901",
    },
    socks = {
        name = "Dynamic SOCKS5 Proxy",
        mode = "D",
        local_port = 1080,
        desc = "Configure browser/proxy to socks5://127.0.0.1:1080",
    },
}

--------------------------------------------------------------------------------
-- Host Discovery (SSH Config, PuTTY Registry, Hosts)
--------------------------------------------------------------------------------
local function get_home()
    return os.getenv("HOME") or os.getenv("USERPROFILE") or "/root"
end

local function parse_ssh_config(path)
    local hosts = {}
    local f = io.open(path, "r")
    if not f then return hosts end

    local current = nil
    for line in f:lines() do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" and not trimmed:match("^#") then
            local key, val = trimmed:match("^(%S+)%s+(.*)$")
            if key then
                key = key:lower()
                if key == "host" then
                    for h in val:gmatch("%S+") do
                        if not h:match("[%*%?]") then
                            current = { name = h, source = "ssh_config", hostname = h }
                            table.insert(hosts, current)
                        else
                            current = nil
                        end
                    end
                elseif current then
                    if key == "hostname" then
                        current.hostname = val
                    elseif key == "user" then
                        current.user = val
                    elseif key == "port" then
                        current.port = tonumber(val)
                    end
                end
            end
        end
    end
    f:close()
    return hosts
end

local function parse_known_hosts(path)
    local hosts = {}
    local f = io.open(path, "r")
    if not f then return hosts end

    for line in f:lines() do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" and not trimmed:match("^#") and not trimmed:match("^|1|") then
            local entry = trimmed:match("^(%S+)")
            if entry then
                for h in entry:gmatch("[^,]+") do
                    local clean = h:match("^%[(.-)%]:%d+$") or h
                    if clean ~= "" and not clean:match("^%d+%.%d+%.%d+%.%d+$") then
                        table.insert(hosts, { name = clean, hostname = clean, source = "known_hosts" })
                    end
                end
            end
        end
    end
    f:close()
    return hosts
end

local function parse_putty_sessions()
    local hosts = {}
    if not IS_WINDOWS then return hosts end

    local HKEY_CURRENT_USER = ffi.cast("HKEY", 0x80000001)
    local KEY_READ = 0x20019
    local phkResult = ffi.new("HKEY[1]")
    local subkey = "Software\\SimonTatham\\PuTTY\\Sessions"

    if ffi.C.RegOpenKeyExA(HKEY_CURRENT_USER, subkey, 0, KEY_READ, phkResult) == 0 then
        local hKey = phkResult[0]
        local dwIndex = 0
        local nameBuf = ffi.new("char[260]")
        local nameLen = ffi.new("DWORD[1]")

        while true do
            nameLen[0] = 260
            local res = ffi.C.RegEnumKeyExA(hKey, dwIndex, nameBuf, nameLen, nil, nil, nil, nil)
            if res ~= 0 then break end

            local session_raw = ffi.string(nameBuf, nameLen[0])
            local session_name = session_raw:gsub("%%20", " ")
            if session_name ~= "Default%20Settings" and session_name ~= "Default Settings" then
                -- Query HostName from inside this session key
                local sessionHKey = ffi.new("HKEY[1]")
                local sessionSubkey = subkey .. "\\" .. session_raw
                local host_name = session_name
                local user_name = nil

                if ffi.C.RegOpenKeyExA(HKEY_CURRENT_USER, sessionSubkey, 0, KEY_READ, sessionHKey) == 0 then
                    local dataBuf = ffi.new("BYTE[260]")
                    local dataLen = ffi.new("DWORD[1]")
                    dataLen[0] = 260
                    if ffi.C.RegQueryValueExA(sessionHKey[0], "HostName", nil, nil, dataBuf, dataLen) == 0 and dataLen[0] > 1 then
                        local hval = ffi.string(dataBuf, dataLen[0] - 1)
                        if hval ~= "" then host_name = hval end
                    end
                    dataLen[0] = 260
                    if ffi.C.RegQueryValueExA(sessionHKey[0], "UserName", nil, nil, dataBuf, dataLen) == 0 and dataLen[0] > 1 then
                        local uval = ffi.string(dataBuf, dataLen[0] - 1)
                        if uval ~= "" then user_name = uval end
                    end
                    ffi.C.RegCloseKey(sessionHKey[0])
                end

                table.insert(hosts, {
                    name = session_name,
                    hostname = host_name,
                    user = user_name,
                    source = "putty",
                })
            end
            dwIndex = dwIndex + 1
        end
        ffi.C.RegCloseKey(hKey)
    end
    return hosts
end

local function get_all_hosts()
    local seen = {}
    local result = {}
    local home = get_home()

    local files = {
        home .. "/.ssh/config",
        IS_WINDOWS and (os.getenv("USERPROFILE") .. "/.ssh/config") or nil,
        "/etc/ssh/ssh_config",
    }
    for _, path in ipairs(files) do
        for _, h in ipairs(parse_ssh_config(path)) do
            if not seen[h.name] then
                seen[h.name] = true
                table.insert(result, h)
            end
        end
    end

    for _, h in ipairs(parse_putty_sessions()) do
        if not seen[h.name] then
            seen[h.name] = true
            table.insert(result, h)
        end
    end

    local kh_files = {
        home .. "/.ssh/known_hosts",
        IS_WINDOWS and (os.getenv("USERPROFILE") .. "/.ssh/known_hosts") or nil,
    }
    for _, path in ipairs(kh_files) do
        for _, h in ipairs(parse_known_hosts(path)) do
            if not seen[h.name] then
                seen[h.name] = true
                table.insert(result, h)
            end
        end
    end

    return result
end

--------------------------------------------------------------------------------
-- Registry Store for Active Tunnels (~/.ssh/.fssh_tunnels.json)
--------------------------------------------------------------------------------
local function get_registry_path()
    local home = get_home()
    return home .. "/.ssh/.fssh_tunnels.json"
end

-- Minimal JSON serializer/deserializer without external dependencies
local function serialize_json(tbl)
    local parts = {}
    table.insert(parts, "[\n")
    for i, t in ipairs(tbl) do
        table.insert(parts, string.format(
            '  {"pid": %d, "host": %q, "mode": %q, "local_port": %d, "remote_host": %q, "remote_port": %d, "spec": %q, "started_at": %q, "desc": %q}%s\n',
            t.pid or 0,
            t.host or "",
            t.mode or "L",
            t.local_port or 0,
            t.remote_host or "127.0.0.1",
            t.remote_port or 0,
            t.spec or "",
            t.started_at or "",
            t.desc or "",
            (i < #tbl and "," or "")
        ))
    end
    table.insert(parts, "]")
    return table.concat(parts)
end

local function deserialize_json(content)
    local items = {}
    if not content or content == "" then return items end

    -- Pattern matching simple objects in JSON array
    for obj in content:gmatch("%{([^%}]+)%}") do
        local item = {}
        item.pid = tonumber(obj:match('"pid"%s*:%s*(%d+)'))
        item.host = obj:match('"host"%s*:%s*"([^"]+)"')
        item.mode = obj:match('"mode"%s*:%s*"([^"]+)"')
        item.local_port = tonumber(obj:match('"local_port"%s*:%s*(%d+)'))
        item.remote_host = obj:match('"remote_host"%s*:%s*"([^"]+)"')
        item.remote_port = tonumber(obj:match('"remote_port"%s*:%s*(%d+)'))
        item.spec = obj:match('"spec"%s*:%s*"([^"]+)"')
        item.started_at = obj:match('"started_at"%s*:%s*"([^"]+)"')
        item.desc = obj:match('"desc"%s*:%s*"([^"]*)"')

        if item.pid and item.host then
            table.insert(items, item)
        end
    end
    return items
end

local function load_active_tunnels(clean_stale)
    local path = get_registry_path()
    local f = io.open(path, "r")
    if not f then return {} end
    local content = f:read("*a")
    f:close()

    local raw = deserialize_json(content)
    local alive = {}
    local changed = false

    for _, item in ipairs(raw) do
        if is_process_alive(item.pid) then
            table.insert(alive, item)
        else
            changed = true
        end
    end

    if clean_stale and changed then
        local out = io.open(path, "w")
        if out then
            out:write(serialize_json(alive))
            out:close()
        end
    end

    return alive
end

local function save_tunnel_entry(entry)
    local list = load_active_tunnels(true)
    table.insert(list, entry)
    local path = get_registry_path()
    local out = io.open(path, "w")
    if out then
        out:write(serialize_json(list))
        out:close()
    end
end

local function remove_tunnel_entry(pid)
    local list = load_active_tunnels(false)
    local updated = {}
    for _, t in ipairs(list) do
        if t.pid ~= pid then table.insert(updated, t) end
    end
    local path = get_registry_path()
    local out = io.open(path, "w")
    if out then
        out:write(serialize_json(updated))
        out:close()
    end
end

--------------------------------------------------------------------------------
-- CLI Commands & Actions
--------------------------------------------------------------------------------
local function print_active_tunnels(as_json)
    local tunnels = load_active_tunnels(true)
    if as_json then
        print(serialize_json(tunnels))
        return
    end

    if #tunnels == 0 then
        print(string.format("%s[INFO]%s No active SSH tunnels registered in %s", C.yellow, C.reset, get_registry_path()))
        return
    end

    print(string.format("\n%s%sACTIVE SSH TUNNELS%s", C.bold, C.cyan, C.reset))
    print(string.format("%s+-------+--------------------+------+-------------------+-------------------+---------------------+%s", C.dim, C.reset))
    print(string.format("%s| %-5s | %-18s | %-4s | %-17s | %-17s | %-19s |%s",
        C.bold, "PID", "HOST", "MODE", "LOCAL ENDPOINT", "REMOTE TARGET", "STARTED AT", C.reset))
    print(string.format("%s+-------+--------------------+------+-------------------+-------------------+---------------------+%s", C.dim, C.reset))

    for _, t in ipairs(tunnels) do
        local loc_str = string.format("127.0.0.1:%d", t.local_port or 0)
        local rem_str = (t.mode == "D") and "SOCKS5 Proxy" or string.format("%s:%d", t.remote_host or "127.0.0.1", t.remote_port or 0)
        local mode_badge = string.format("-%s", t.mode)
        print(string.format("| %s%-5d%s | %-18.18s | %s%-4s%s | %-17.17s | %-17.17s | %-19.19s |",
            C.green, t.pid, C.reset,
            t.host,
            C.yellow, mode_badge, C.reset,
            loc_str,
            rem_str,
            t.started_at or "-"
        ))
    end
    print(string.format("%s+-------+--------------------+------+-------------------+-------------------+---------------------+%s", C.dim, C.reset))
    print(string.format("Total: %d active tunnel(s). Run %s'fssh_tunnel -k <PID>'%s to stop a tunnel.\n", #tunnels, C.bold, C.reset))
end

local function kill_tunnels(target)
    local tunnels = load_active_tunnels(true)
    if #tunnels == 0 then
        print("No active tunnels found to kill.")
        return
    end

    if target == "all" then
        local count = 0
        for _, t in ipairs(tunnels) do
            if kill_process(t.pid) then
                print(string.format("✔ Terminated tunnel [PID: %d, Host: %s, Port: %d]", t.pid, t.host, t.local_port or 0))
                count = count + 1
            else
                print(string.format("✖ Failed to terminate PID %d", t.pid))
            end
            remove_tunnel_entry(t.pid)
        end
        print(string.format("Done. %d tunnel(s) killed.", count))
    else
        local pid = tonumber(target)
        if not pid then
            print(string.format("%s[ERROR]%s Invalid PID: %s", C.red, C.reset, tostring(target)))
            return
        end

        local found = false
        for _, t in ipairs(tunnels) do
            if t.pid == pid then
                found = true
                if kill_process(pid) then
                    print(string.format("✔ Terminated tunnel [PID: %d, Host: %s, Port: %d]", pid, t.host, t.local_port or 0))
                else
                    print(string.format("✖ Process %d already gone or could not be terminated.", pid))
                end
                remove_tunnel_entry(pid)
                break
            end
        end
        if not found then
            -- Attempt kill anyway
            if kill_process(pid) then
                print(string.format("✔ Terminated process %d", pid))
            else
                print(string.format("%s[ERROR]%s Tunnel PID %d not found in active registry.", C.red, C.reset, pid))
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Interactive Tunnel Manager (FZF)
--------------------------------------------------------------------------------
local function run_interactive_manager()
    local tunnels = load_active_tunnels(true)
    if #tunnels == 0 then
        print(string.format("%s[INFO]%s No active SSH tunnels running.", C.yellow, C.reset))
        return
    end

    -- Write temporary TSV lines for FZF
    local lines = {}
    for _, t in ipairs(tunnels) do
        local loc = string.format("127.0.0.1:%d", t.local_port or 0)
        local rem = (t.mode == "D") and "SOCKS5 Proxy" or string.format("%s:%d", t.remote_host or "127.0.0.1", t.remote_port or 0)
        table.insert(lines, string.format("%d\t%s\t-%s\t%s\t%s\t%s",
            t.pid, t.host, t.mode, loc, rem, t.started_at or ""))
    end

    local tmp_path = os.tmpname()
    local f = io.open(tmp_path, "w")
    if not f then return end
    f:write(table.concat(lines, "\n") .. "\n")
    f:close()

    local fzf_cmd = string.format(
        "cat %q | fzf --delimiter='\\t' --with-nth=1,2,3,4,5,6 " ..
        "--header='[ACTIVE SSH TUNNELS] ENTER: Inspect | Ctrl-K / d: Kill Tunnel | ESC: Exit' " ..
        "--bind='ctrl-k:execute-silent(luajit %q -k {1})+reload(luajit %q --list --json >/dev/null && cat %q)' " ..
        "--prompt='Tunnel > '",
        tmp_path, arg[0], arg[0], tmp_path
    )

    local pipe = io.popen(fzf_cmd)
    local selected = pipe:read("*l")
    pipe:close()
    os.remove(tmp_path)

    if selected and selected ~= "" then
        local pid = tonumber(selected:match("^(%d+)"))
        if pid then
            print(string.format("\nActions for Tunnel PID %d:\n  [1] Kill tunnel\n  [2] Open browser endpoint\n  [3] Cancel", pid))
            io.write("Select option [1-3]: ")
            local opt = io.read("*l")
            if opt == "1" then
                kill_tunnels(pid)
            elseif opt == "2" then
                for _, t in ipairs(tunnels) do
                    if t.pid == pid and t.local_port then
                        local url = string.format("http://localhost:%d", t.local_port)
                        print(string.format("Opening %s ...", url))
                        if IS_WINDOWS then
                            os.execute(string.format("start %s", url))
                        elseif IS_OSX then
                            os.execute(string.format("open %s", url))
                        else
                            os.execute(string.format("xdg-open %s 2>/dev/null &", url))
                        end
                    end
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Tunnel Launcher Execution
--------------------------------------------------------------------------------
local function launch_tunnel(params)
    local host = params.host
    local mode = params.mode or "L"
    local local_port = tonumber(params.local_port)
    local remote_host = params.remote_host or "127.0.0.1"
    local remote_port = tonumber(params.remote_port)
    local background = (params.background ~= false)
    local dry_run = params.dry_run

    if not host or host == "" then
        print(string.format("%s[ERROR]%s Missing remote host.", C.red, C.reset))
        return false
    end

    -- Pre-flight port check
    if local_port then
        local free, err = is_port_free(local_port)
        if not free then
            local next_free = find_next_free_port(local_port + 1)
            print(string.format("%s[WARNING]%s Local port %d is already OCCUPIED on 127.0.0.1!", C.yellow, C.reset, local_port))
            if next_free then
                print(string.format("  Next available port found: %s%d%s", C.bold .. C.green, next_free, C.reset))
                if not params.auto_accept then
                    io.write(string.format("  Switch local port to %d? [Y/n]: ", next_free))
                    local ans = io.read("*l")
                    if ans == "" or ans:lower():match("^y") then
                        local_port = next_free
                    else
                        print(string.format("%s[ABORTED]%s Port %d cannot be bound.", C.red, C.reset, local_port))
                        return false
                    end
                else
                    local_port = next_free
                end
            else
                print(string.format("%s[ERROR]%s Could not find a free port.", C.red, C.reset))
                return false
            end
        else
            print(string.format("✔ %sPre-flight socket check:%s Local port %s%d%s is FREE on 127.0.0.1",
                C.dim, C.reset, C.green, local_port, C.reset))
        end
    end

    -- Formulate forward flag
    local fwd_flag = ""
    local spec = ""
    if mode == "L" then
        spec = string.format("%d:%s:%d", local_port, remote_host, remote_port)
        fwd_flag = string.format("-L %s", spec)
    elseif mode == "R" then
        spec = string.format("%d:%s:%d", remote_port, remote_host, local_port)
        fwd_flag = string.format("-R %s", spec)
    elseif mode == "D" then
        spec = tostring(local_port)
        fwd_flag = string.format("-D %d", local_port)
    end

    -- SSH Command Construction
    local ssh_bin = "ssh"
    local cmd_args = {}
    table.insert(cmd_args, ssh_bin)

    if background then
        table.insert(cmd_args, "-f") -- Go to background before execution
        table.insert(cmd_args, "-N") -- Do not execute a remote command
    end

    table.insert(cmd_args, "-o ExitOnForwardFailure=yes")
    table.insert(cmd_args, "-o ServerAliveInterval=60")
    table.insert(cmd_args, "-o ServerAliveCountMax=3")
    table.insert(cmd_args, fwd_flag)
    table.insert(cmd_args, host)

    local full_cmd = table.concat(cmd_args, " ")

    if dry_run then
        print(string.format("\n%s[DRY-RUN] SSH Command:%s", C.yellow, C.reset))
        print("  " .. full_cmd)
        return true
    end

    print(string.format("\n🚀 %sLaunching SSH Tunnel (%s) to %s%s%s...",
        C.bold, (mode == "D" and "SOCKS5" or ("-" .. mode)), C.cyan, host, C.reset))
    print(string.format("   Command: %s%s%s", C.dim, full_cmd, C.reset))

    local status = os.execute(full_cmd)
    local ok = (status == 0 or status == true)

    if ok then
        -- Find PID of launched tunnel if in background
        local pid = 0
        if background then
            -- Query PID
            if IS_WINDOWS then
                -- On Windows, find ssh.exe with matching port
                local p = io.popen(string.format('tasklist /fi "IMAGENAME eq ssh.exe" /fo csv /nh 2>nul'))
                if p then
                    for l in p:lines() do
                        local p_pid = l:match('"ssh%.exe","(%d+)"')
                        if p_pid then pid = tonumber(p_pid) end
                    end
                    p:close()
                end
            else
                local p = io.popen(string.format("pgrep -f %q 2>/dev/null", spec))
                if p then
                    local out = p:read("*l")
                    if out then pid = tonumber(out) end
                    p:close()
                end
            end

            local now_str = os.date("%Y-%m-%d %H:%M:%S")
            save_tunnel_entry({
                pid = pid,
                host = host,
                mode = mode,
                local_port = local_port,
                remote_host = remote_host,
                remote_port = remote_port,
                spec = spec,
                started_at = now_str,
                desc = params.desc or "",
            })

            print(string.format("\n%s✔ Tunnel established successfully!%s", C.green .. C.bold, C.reset))
            if pid and pid > 0 then
                print(string.format("  Process ID : %s%d%s", C.cyan, pid, C.reset))
            end
            if mode == "D" then
                print(string.format("  SOCKS5 Endpoint: %ssocks5://127.0.0.1:%d%s", C.yellow, local_port, C.reset))
            elseif mode == "L" then
                print(string.format("  Local Endpoint : %shttp://localhost:%d%s (Forwarded to %s:%d)",
                    C.yellow, local_port, C.reset, remote_host, remote_port))
            end
            print(string.format("  Run %s'fssh_tunnel -l'%s or %s'fssh_tunnel -m'%s to manage active tunnels.\n",
                C.bold, C.reset, C.bold, C.reset))
        else
            print(string.format("\n%s✔ Foreground tunnel session closed.%s\n", C.green, C.reset))
        end
        return true
    else
        print(string.format("\n%s✖ SSH tunnel command failed with exit code: %s%s", C.red, tostring(status), C.reset))
        return false
    end
end

--------------------------------------------------------------------------------
-- Interactive Wizard Mode
--------------------------------------------------------------------------------
local function run_interactive_wizard(default_host)
    print(string.format([[
%s%s================================================================
  fssh_tunnel - SSH Port Forward & Tunnel Manager (LuaJIT FFI)
================================================================%s]], C.cyan, C.bold, C.reset))

    local hosts = get_all_hosts()
    local host = default_host

    if not host then
        if #hosts == 0 then
            io.write("Enter remote SSH host/IP: ")
            host = io.read("*l")
        else
            -- Try FZF if available
            local host_entries = {}
            for _, h in ipairs(hosts) do
                table.insert(host_entries, string.format("%s\t(%s) [%s]", h.name, h.hostname or h.name, h.source))
            end

            local tmp_path = os.tmpname()
            local f = io.open(tmp_path, "w")
            if f then
                f:write(table.concat(host_entries, "\n") .. "\n")
                f:close()

                local fzf_cmd = string.format("cat %q | fzf --delimiter='\\t' --with-nth=1,2 --prompt='Select Host > '", tmp_path)
                local pipe = io.popen(fzf_cmd)
                local sel = pipe:read("*l")
                pipe:close()
                os.remove(tmp_path)

                if sel and sel ~= "" then
                    host = sel:match("^(%S+)")
                end
            end

            if not host then
                io.write("Enter remote SSH host/IP: ")
                host = io.read("*l")
            end
        end
    end

    if not host or host == "" then
        print("No host selected. Exiting.")
        return
    end

    print(string.format("Target Host: %s%s%s\n", C.green .. C.bold, host, C.reset))

    print("Select Forwarding Mode:")
    print("  [1] Local Forward (-L)  [Remote Service -> Localhost]")
    print("  [2] Remote Forward (-R) [Localhost -> Remote Port]")
    print("  [3] Dynamic SOCKS5 (-D) [SOCKS Proxy via Remote Host]")
    io.write("Choice [1-3, default 1]: ")
    local mode_choice = io.read("*l")
    local mode = "L"
    if mode_choice == "2" then mode = "R"
    elseif mode_choice == "3" then mode = "D" end

    local local_port = 8080
    local remote_host = "127.0.0.1"
    local remote_port = 8080
    local desc = ""

    if mode == "D" then
        io.write("Enter Local SOCKS5 Port [default 1080]: ")
        local p = io.read("*l")
        local_port = tonumber(p) or 1080
        desc = "SOCKS5 Proxy"
    else
        print("\nChoose Service Preset (or Custom):")
        local preset_keys = { "jupyter", "tensorboard", "postgres", "mysql", "redis", "codeserver", "vnc" }
        for i, k in ipairs(preset_keys) do
            local p = PRESETS[k]
            print(string.format("  [%d] %-14s (Port %d) - %s", i, p.name, p.local_port, p.desc))
        end
        print("  [0] Custom Port Configuration")
        io.write(string.format("Choice [0-%d, default 0]: ", #preset_keys))
        local p_choice = tonumber(io.read("*l"))

        if p_choice and p_choice >= 1 and p_choice <= #preset_keys then
            local p = PRESETS[preset_keys[p_choice]]
            local_port = p.local_port
            remote_host = p.remote_host
            remote_port = p.remote_port
            desc = p.name
        else
            io.write("Enter Local Port [default 8080]: ")
            local lp = io.read("*l")
            local_port = tonumber(lp) or 8080

            io.write("Enter Remote Target Host [default 127.0.0.1]: ")
            local rh = io.read("*l")
            if rh and rh ~= "" then remote_host = rh end

            io.write(string.format("Enter Remote Port [default %d]: ", local_port))
            local rp = io.read("*l")
            remote_port = tonumber(rp) or local_port
            desc = "Custom Forward"
        end
    end

    print("\nRun mode:")
    print("  [1] Background (Detached, persistent)")
    print("  [2] Foreground (Attached to this terminal)")
    io.write("Choice [1-2, default 1]: ")
    local run_choice = io.read("*l")
    local background = (run_choice ~= "2")

    launch_tunnel({
        host = host,
        mode = mode,
        local_port = local_port,
        remote_host = remote_host,
        remote_port = remote_port,
        background = background,
        desc = desc,
    })
end

--------------------------------------------------------------------------------
-- CLI Argument Parsing
--------------------------------------------------------------------------------
local function print_help()
    print([[
fssh_tunnel.lua - High-Performance Interactive SSH Port Forward & Tunnel Manager (LuaJIT FFI)

Usage:
  fssh_tunnel.lua [OPTIONS] [HOST]

Options:
  -L <local:host:remote>   Local forward (e.g. 8888:127.0.0.1:8888 or 8888:8888)
  -R <remote:host:local>   Remote forward (e.g. 9000:127.0.0.1:3000)
  -D <port>                Dynamic SOCKS5 proxy on local port (e.g. 1080)
  -p, --preset <name>      Quick preset (jupyter, tensorboard, postgres, mysql, redis, vnc)
  -b, --background         Run in background (default for tunnels)
  -F, --foreground         Run in foreground
  -l, --list               List currently active background tunnels
  --json                   Output active tunnels list as JSON
  -k, --kill <PID|all>     Kill active background tunnel(s)
  -m, --manage             Interactive FZF tunnel manager
  --check-port <port>      Check if a local TCP port is free
  --hosts                  List all discovered SSH hosts
  -d, --dry-run            Show SSH command without running
  -i, --interactive        Run guided setup wizard
  -h, --help               Show this help message

Presets:
  jupyter     Local 8888 -> Remote 127.0.0.1:8888
  tensorboard Local 6006 -> Remote 127.0.0.1:6006
  postgres    Local 5432 -> Remote 127.0.0.1:5432
  mysql       Local 3306 -> Remote 127.0.0.1:3306
  redis       Local 6379 -> Remote 127.0.0.1:6379
  codeserver  Local 8080 -> Remote 127.0.0.1:8080
  vnc         Local 5901 -> Remote 127.0.0.1:5901
  socks       Dynamic SOCKS5 proxy on port 1080

Examples:
  fssh_tunnel.lua -L 8888:localhost:8888 gpu-box
  fssh_tunnel.lua -p jupyter gpu-box
  fssh_tunnel.lua -D 1080 dev-server
  fssh_tunnel.lua -l
  fssh_tunnel.lua -k 12345
  fssh_tunnel.lua -m
]])
end

local function parse_forward_spec(spec)
    -- Formats:
    -- 1. local_port:remote_host:remote_port
    -- 2. local_port:remote_port (implies 127.0.0.1)
    local lp, rh, rp = spec:match("^(%d+):([^:]+):(%d+)$")
    if lp and rh and rp then
        return tonumber(lp), rh, tonumber(rp)
    end
    lp, rp = spec:match("^(%d+):(%d+)$")
    if lp and rp then
        return tonumber(lp), "127.0.0.1", tonumber(rp)
    end
    return nil, nil, nil
end

local function main()
    local args = arg or {}
    if #args == 0 then
        run_interactive_wizard()
        return
    end

    local params = {
        background = true,
        dry_run = false,
    }

    local i = 1
    while i <= #args do
        local a = args[i]
        if a == "-h" or a == "--help" then
            print_help()
            return
        elseif a == "-l" or a == "--list" then
            local as_json = false
            if args[i+1] == "--json" then as_json = true end
            print_active_tunnels(as_json)
            return
        elseif a == "--json" then
            print_active_tunnels(true)
            return
        elseif a == "-m" or a == "--manage" then
            run_interactive_manager()
            return
        elseif a == "-k" or a == "--kill" then
            i = i + 1
            local target = args[i] or "all"
            kill_tunnels(target)
            return
        elseif a == "--check-port" then
            i = i + 1
            local port = tonumber(args[i])
            if not port then
                print("Error: Port required")
                os.exit(1)
            end
            local free = is_port_free(port)
            if free then
                print(string.format("Port %d is FREE", port))
                os.exit(0)
            else
                print(string.format("Port %d is OCCUPIED", port))
                os.exit(1)
            end
        elseif a == "--hosts" then
            local hosts = get_all_hosts()
            for _, h in ipairs(hosts) do
                print(string.format("%-24s\t%-24s\t[%s]", h.name, h.hostname or h.name, h.source))
            end
            return
        elseif a == "-i" or a == "--interactive" then
            run_interactive_wizard(args[i+1])
            return
        elseif a == "-b" or a == "--background" then
            params.background = true
        elseif a == "-F" or a == "--foreground" then
            params.background = false
        elseif a == "-d" or a == "--dry-run" then
            params.dry_run = true
        elseif a == "-L" then
            i = i + 1
            params.mode = "L"
            local lp, rh, rp = parse_forward_spec(args[i] or "")
            if not lp then
                print(string.format("%s[ERROR]%s Invalid -L spec. Expected <local_port:remote_host:remote_port> or <local_port:remote_port>", C.red, C.reset))
                os.exit(1)
            end
            params.local_port = lp
            params.remote_host = rh
            params.remote_port = rp
        elseif a == "-R" then
            i = i + 1
            params.mode = "R"
            local lp, rh, rp = parse_forward_spec(args[i] or "")
            if not lp then
                print(string.format("%s[ERROR]%s Invalid -R spec.", C.red, C.reset))
                os.exit(1)
            end
            params.local_port = lp
            params.remote_host = rh
            params.remote_port = rp
        elseif a == "-D" then
            i = i + 1
            params.mode = "D"
            local p = tonumber(args[i])
            if not p then
                print(string.format("%s[ERROR]%s Invalid -D port.", C.red, C.reset))
                os.exit(1)
            end
            params.local_port = p
        elseif a == "-p" or a == "--preset" then
            i = i + 1
            local name = (args[i] or ""):lower()
            local p = PRESETS[name]
            if not p then
                print(string.format("%s[ERROR]%s Unknown preset '%s'. Available presets: jupyter, tensorboard, postgres, mysql, redis, codeserver, vnc, socks", C.red, C.reset, name))
                os.exit(1)
            end
            params.mode = p.mode
            params.local_port = p.local_port
            params.remote_host = p.remote_host
            params.remote_port = p.remote_port
            params.desc = p.name
        elseif not a:match("^%-") and not params.host then
            params.host = a
        end
        i = i + 1
    end

    if not params.host then
        run_interactive_wizard()
        return
    end

    if not params.mode then
        -- Default to local forward if port specified or launch wizard with host
        run_interactive_wizard(params.host)
        return
    end

    launch_tunnel(params)
end

main()
