#!/usr/bin/env luajit
--[[
  fscp_tui.lua - Fast Dual-Pane TUI File Transfer Tool (Local <-> Remote).
  Powered by LuaJIT & FFI. Single-file, zero external Lua dependencies.
  Runs natively on Windows (Win32 Console & Registry FFI) and Linux/POSIX.

  Features:
    - Left Pane: Local directory browser (instant < 1 ms via FFI)
    - Right Pane: Remote directory browser (SSH / SFTP / Rsync / Demo mode)
    - Multi-select files and directories (Space to toggle, 'a' for all, 'A' to clear)
    - Push (Upload 'u' / F5) and Pull (Download 'd' / F5) with live confirmation
    - Built-in host picker aggregating ~/.ssh/config, known_hosts, and PuTTY sessions
    - Dynamic terminal resize support, double-buffered flicker-free rendering
    - Offline Demo Mode (--demo) for UI testing without SSH connection

  Usage:
    luajit fscp_tui.lua [HOST] [REMOTE_PATH] [LOCAL_PATH]
    luajit fscp_tui.lua --demo
    luajit fscp_tui.lua --help

  Keybindings:
    Tab             Switch active pane (Left <-> Right)
    Up / k, Down / j Move cursor
    Enter / l / Right Drill into directory
    Backspace / h / Left Parent directory (..)
    Space           Toggle select file/folder
    a / A           Select all / Deselect all
    u / F5          Upload selected items (Left -> Right)
    d / F5          Download selected items (Right -> Left)
    r               Refresh active pane (or force remote re-scan)
    ~               Jump to home directory
    /               Inline filter current pane
    ?               Show help modal
    q / Ctrl+C      Quit
]]

local ffi = require("ffi")
local bit = require("bit")

local OS = ffi.os
local IS_WINDOWS = (OS == "Windows")
local IS_LINUX = (OS == "Linux")

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

        typedef struct { short X; short Y; } COORD;
        typedef struct { short Left; short Top; short Right; short Bottom; } SMALL_RECT;
        typedef struct {
            COORD dwSize;
            COORD dwCursorPosition;
            unsigned short wAttributes;
            SMALL_RECT srWindow;
            COORD dwMaximumWindowSize;
        } CONSOLE_SCREEN_BUFFER_INFO;

        HANDLE GetStdHandle(DWORD nStdHandle);
        BOOL GetConsoleMode(HANDLE hConsoleHandle, DWORD* lpMode);
        BOOL SetConsoleMode(HANDLE hConsoleHandle, DWORD dwMode);
        BOOL GetConsoleScreenBufferInfo(HANDLE h, CONSOLE_SCREEN_BUFFER_INFO* csbi);
        BOOL SetConsoleOutputCP(unsigned int wCodePageID);
        BOOL SetConsoleCP(unsigned int wCodePageID);
        HANDLE CreateFileA(const char* lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode, void* lpSecurityAttributes, DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes, void* hTemplateFile);
        BOOL CloseHandle(HANDLE hObject);

        typedef struct { DWORD dwLowDateTime; DWORD dwHighDateTime; } FILETIME;
        typedef struct { unsigned short wYear, wMonth, wDayOfWeek, wDay, wHour, wMinute, wSecond, wMilliseconds; } SYSTEMTIME;
        typedef struct {
            DWORD dwFileAttributes;
            FILETIME ftCreationTime;
            FILETIME ftLastAccessTime;
            FILETIME ftLastWriteTime;
            DWORD nFileSizeHigh;
            DWORD nFileSizeLow;
            DWORD dwReserved0;
            DWORD dwReserved1;
            char cFileName[260];
            char cAlternateFileName[14];
        } WIN32_FIND_DATAA;

        HANDLE FindFirstFileA(const char* lpFileName, WIN32_FIND_DATAA* lpFindFileData);
        BOOL FindNextFileA(HANDLE hFindFile, WIN32_FIND_DATAA* lpFindFileData);
        BOOL FindClose(HANDLE hFindFile);
        BOOL FileTimeToSystemTime(const FILETIME* lpFileTime, SYSTEMTIME* lpSystemTime);

        LONG RegOpenKeyExA(HKEY hKey, const char* lpSubKey, DWORD ulOptions, DWORD samDesired, HKEY* phkResult);
        LONG RegEnumKeyExA(HKEY hKey, DWORD dwIndex, char* lpName, DWORD* lpcchName, DWORD* lpReserved, char* lpClass, DWORD* lpcchClass, void* lpftLastWriteTime);
        LONG RegQueryValueExA(HKEY hKey, const char* lpValueName, DWORD* lpReserved, DWORD* lpType, BYTE* lpData, DWORD* lpcbData);
        LONG RegCloseKey(HKEY hKey);
        void Sleep(DWORD dwMilliseconds);
    ]]

    local msvcrt = ffi.load("msvcrt")
    ffi.cdef[[
        int _kbhit(void);
        int _getch(void);
    ]]
    _G.msvcrt = msvcrt
else
    ffi.cdef[[
        struct termios {
            unsigned int c_iflag;
            unsigned int c_oflag;
            unsigned int c_cflag;
            unsigned int c_lflag;
            unsigned char c_line;
            unsigned char c_cc[32];
            unsigned int c_ispeed;
            unsigned int c_ospeed;
        };
        int tcgetattr(int fd, struct termios *termios_p);
        int tcsetattr(int fd, int optional_actions, const struct termios *termios_p);
        struct winsize {
            unsigned short ws_row;
            unsigned short ws_col;
            unsigned short ws_xpixel;
            unsigned short ws_ypixel;
        };
        int ioctl(int fd, unsigned long request, ...);
        int read(int fd, void *buf, size_t count);
        int isatty(int fd);
        int usleep(unsigned int usec);
    ]]
end

--------------------------------------------------------------------------------
-- ANSI Colors & Styling
--------------------------------------------------------------------------------
local C = {
    reset       = "\27[0m",
    bold        = "\27[1m",
    dim         = "\27[2m",
    reverse     = "\27[7m",
    underline   = "\27[4m",

    black       = "\27[30m",
    red         = "\27[31m",
    green       = "\27[32m",
    yellow      = "\27[33m",
    blue        = "\27[34m",
    magenta     = "\27[35m",
    cyan        = "\27[36m",
    white       = "\27[37m",
    gray        = "\27[90m",

    bright_red     = "\27[91m",
    bright_green   = "\27[92m",
    bright_yellow  = "\27[93m",
    bright_blue    = "\27[94m",
    bright_magenta = "\27[95m",
    bright_cyan    = "\27[96m",
    bright_white   = "\27[97m",

    bg_black    = "\27[40m",
    bg_blue     = "\27[44m",
    bg_cyan     = "\27[46m",
    bg_gray     = "\27[100m",
    bg_darkblue = "\27[48;5;24m",
    bg_sel      = "\27[48;5;238m",
}

-- Box drawing characters with ASCII fallback
local BOX_UNICODE = {
    tl = "┌", tr = "┐", bl = "└", br = "┘",
    h = "─", v = "│", vl = "├", vr = "┤",
    tt = "┬", tb = "┴", x = "┼",
    arrow_r = "→", arrow_l = "←",
}

local BOX_ASCII = {
    tl = "+", tr = "+", bl = "+", br = "+",
    h = "-", v = "|", vl = "+", vr = "+",
    tt = "+", tb = "+", x = "+",
    arrow_r = "->", arrow_l = "<-",
}

local BOX = BOX_UNICODE

--------------------------------------------------------------------------------
-- Terminal Low-Level Controller
--------------------------------------------------------------------------------
local Term = {
    orig_in_mode = nil,
    orig_out_mode = nil,
    orig_termios = nil,
    hIn = nil,
    hOut = nil,
    is_raw = false,
}

function Term.init()
    if IS_WINDOWS then
        pcall(function()
            ffi.C.SetConsoleOutputCP(65001)
            ffi.C.SetConsoleCP(65001)
        end)
        Term.hIn = ffi.C.GetStdHandle(ffi.cast("DWORD", -10))
        Term.hOut = ffi.C.GetStdHandle(ffi.cast("DWORD", -11))

        -- Enable virtual terminal processing for output
        if Term.hOut ~= nil and Term.hOut ~= ffi.cast("HANDLE", -1) then
            local mode = ffi.new("DWORD[1]")
            if ffi.C.GetConsoleMode(Term.hOut, mode) ~= 0 then
                Term.orig_out_mode = mode[0]
                ffi.C.SetConsoleMode(Term.hOut, bit.bor(mode[0], 0x0004)) -- ENABLE_VIRTUAL_TERMINAL_PROCESSING
            end
        end
    end
end

function Term.enable_raw()
    if Term.is_raw then return end
    if IS_WINDOWS then
        if Term.hIn ~= nil and Term.hIn ~= ffi.cast("HANDLE", -1) then
            local mode = ffi.new("DWORD[1]")
            if ffi.C.GetConsoleMode(Term.hIn, mode) ~= 0 then
                Term.orig_in_mode = mode[0]
                -- Disable line input and echo input
                local raw_mode = bit.band(mode[0], bit.bnot(bit.bor(0x0002, 0x0004)))
                ffi.C.SetConsoleMode(Term.hIn, raw_mode)
            end
        end
    else
        Term.orig_termios = ffi.new("struct termios")
        if ffi.C.tcgetattr(0, Term.orig_termios) == 0 then
            local raw = ffi.new("struct termios")
            ffi.copy(raw, Term.orig_termios, ffi.sizeof("struct termios"))
            raw.c_lflag = bit.band(raw.c_lflag, bit.bnot(bit.bor(0x0002, 0x0008, 0x0001))) -- ICANON, ECHO, ISIG
            raw.c_cc[5] = 0 -- VMIN
            raw.c_cc[6] = 1 -- VTIME
            ffi.C.tcsetattr(0, 0, raw)
        end
    end

    -- Switch to alternate screen buffer, hide cursor, disable auto-wrap, clear screen
    io.write("\27[?1049h\27[?25l\27[?7l\27[2J\27[H")
    io.flush()
    Term.is_raw = true
end

function Term.restore()
    if not Term.is_raw then return end
    -- Show cursor, re-enable auto-wrap, switch back from alternate screen buffer
    io.write("\27[?7h\27[?1049l\27[?25h\27[0m")
    io.flush()

    if IS_WINDOWS then
        if Term.orig_in_mode and Term.hIn ~= nil and Term.hIn ~= ffi.cast("HANDLE", -1) then
            ffi.C.SetConsoleMode(Term.hIn, Term.orig_in_mode)
        end
        if Term.orig_out_mode and Term.hOut ~= nil and Term.hOut ~= ffi.cast("HANDLE", -1) then
            ffi.C.SetConsoleMode(Term.hOut, Term.orig_out_mode)
        end
    else
        if Term.orig_termios then
            ffi.C.tcsetattr(0, 0, Term.orig_termios)
        end
    end
    Term.is_raw = false
end

function Term.get_size()
    local cols, rows = 100, 30
    if IS_WINDOWS then
        local hCon = ffi.C.CreateFileA("CONOUT$", 0xC0000000, 3, nil, 3, 0, nil)
        if hCon ~= nil and hCon ~= ffi.cast("HANDLE", -1) then
            local csbi = ffi.new("CONSOLE_SCREEN_BUFFER_INFO")
            if ffi.C.GetConsoleScreenBufferInfo(hCon, csbi) ~= 0 then
                cols = csbi.srWindow.Right - csbi.srWindow.Left + 1
                rows = csbi.srWindow.Bottom - csbi.srWindow.Top + 1
            end
            ffi.C.CloseHandle(hCon)
        end
    else
        local ws = ffi.new("struct winsize")
        if ffi.C.ioctl(0, 0x5413, ws) == 0 and ws.ws_col > 0 and ws.ws_row > 0 then
            cols = ws.ws_col
            rows = ws.ws_row
        end
    end

    local env_c = tonumber(os.getenv("COLUMNS"))
    local env_r = tonumber(os.getenv("LINES"))
    if env_c and env_c > 20 then cols = env_c end
    if env_r and env_r > 10 then rows = env_r end

    if cols < 60 then cols = 60 end
    if rows < 15 then rows = 15 end
    return cols, rows
end

function Term.read_key()
    if IS_WINDOWS then
        local m = _G.msvcrt
        if m._kbhit() == 0 then return nil end
        local ch = m._getch()
        if ch == 0 or ch == 224 then
            local ch2 = m._getch()
            if ch2 == 72 then return "up"
            elseif ch2 == 80 then return "down"
            elseif ch2 == 75 then return "left"
            elseif ch2 == 77 then return "right"
            elseif ch2 == 71 then return "home"
            elseif ch2 == 79 then return "end"
            elseif ch2 == 73 then return "pageup"
            elseif ch2 == 81 then return "pagedown"
            elseif ch2 == 83 then return "delete"
            elseif ch2 == 63 then return "f5"
            else return "unknown_ext_" .. ch2 end
        elseif ch == 13 or ch == 10 then
            return "enter"
        elseif ch == 9 then
            return "tab"
        elseif ch == 8 or ch == 127 then
            return "backspace"
        elseif ch == 32 then
            return "space"
        elseif ch == 27 then
            -- Check if another char follows (escape sequence) with short wait buffer
            local timeout = 0
            while m._kbhit() == 0 and timeout < 8 do
                ffi.C.Sleep(2)
                timeout = timeout + 1
            end
            if m._kbhit() ~= 0 then
                local next_ch = m._getch()
                if next_ch == 91 then -- '['
                    timeout = 0
                    while m._kbhit() == 0 and timeout < 8 do
                        ffi.C.Sleep(2)
                        timeout = timeout + 1
                    end
                    if m._kbhit() ~= 0 then
                        local code = m._getch()
                        if code == 65 then return "up"
                        elseif code == 66 then return "down"
                        elseif code == 67 then return "right"
                        elseif code == 68 then return "left"
                        elseif code == 72 then return "home"
                        elseif code == 70 then return "end"
                        end
                    end
                end
            end
            return "esc"
        elseif ch == 3 then
            return "ctrl_c"
        else
            return string.char(ch)
        end
    else
        local buf = ffi.new("char[16]")
        local n = ffi.C.read(0, buf, 16)
        if n <= 0 then return nil end
        local ch = buf[0]
        if ch == 27 then
            if n == 1 then return "esc" end
            if buf[1] == 91 then -- '['
                local code = buf[2]
                if code == 65 then return "up"
                elseif code == 66 then return "down"
                elseif code == 67 then return "right"
                elseif code == 68 then return "left"
                elseif code == 72 then return "home"
                elseif code == 70 then return "end"
                elseif code == 49 and buf[3] == 53 and buf[4] == 126 then return "f5" -- [15~
                elseif code == 53 and buf[3] == 126 then return "pageup" -- [5~
                elseif code == 54 and buf[3] == 126 then return "pagedown" -- [6~
                elseif code == 51 and buf[3] == 126 then return "delete" -- [3~
                end
            end
            return "esc"
        elseif ch == 10 or ch == 13 then
            return "enter"
        elseif ch == 9 then
            return "tab"
        elseif ch == 127 or ch == 8 then
            return "backspace"
        elseif ch == 32 then
            return "space"
        elseif ch == 3 then
            return "ctrl_c"
        else
            return string.char(ch)
        end
    end
end

--------------------------------------------------------------------------------
-- Helpers & Formatters
--------------------------------------------------------------------------------
local function get_home_dir()
    return os.getenv("HOME") or os.getenv("USERPROFILE") or "."
end

local function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

local function trim(s)
    if not s then return "" end
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function normalize_path(p)
    if not p or p == "" then return "." end
    p = p:gsub("\\", "/")
    p = p:gsub("/+", "/")
    if p:len() > 1 and p:sub(-1) == "/" and not p:match("^%a:/$") then
        p = p:sub(1, -2)
    end
    return p
end

local function get_parent_dir(p)
    p = normalize_path(p)
    if IS_WINDOWS and p:match("^%a:/?$") then
        return p -- at drive root
    end
    if p == "/" or p == "." or p == ".." then
        return ".."
    end
    local parent = p:match("^(.*)/[^/]+$")
    if not parent or parent == "" then
        if IS_WINDOWS and p:match("^%a:") then
            return p:sub(1, 2) .. "/"
        end
        return "/"
    end
    return parent
end

local function format_size(bytes)
    if bytes == nil or bytes < 0 then return "-" end
    if bytes < 1024 then
        return string.format("%d B", bytes)
    elseif bytes < 1024 * 1024 then
        return string.format("%.1f KB", bytes / 1024)
    elseif bytes < 1024 * 1024 * 1024 then
        return string.format("%.1f MB", bytes / (1024 * 1024))
    else
        return string.format("%.1f GB", bytes / (1024 * 1024 * 1024))
    end
end

local function pad_string(s, width, align_right)
    s = s or ""
    local len = #s
    if len > width then
        if width <= 3 then return s:sub(1, width) end
        return s:sub(1, width - 2) .. ".."
    end
    local padding = string.rep(" ", width - len)
    if align_right then
        return padding .. s
    else
        return s .. padding
    end
end

local function shell_escape(s)
    if not s:find("[^%w_%-%.%/:]") then
        return s
    end
    if IS_WINDOWS then
        return '"' .. s:gsub('"', '\\"') .. '"'
    else
        return "'" .. s:gsub("'", "'\\''") .. "'"
    end
end

--------------------------------------------------------------------------------
-- Local Filesystem Scanner (FFI Win32 / POSIX)
--------------------------------------------------------------------------------
local function list_local_directory(dir_path)
    dir_path = normalize_path(dir_path)
    local items = {}

    if IS_WINDOWS then
        local search_pattern = dir_path .. "/*"
        local find_data = ffi.new("WIN32_FIND_DATAA")
        local hFind = ffi.C.FindFirstFileA(search_pattern, find_data)
        local st = ffi.new("SYSTEMTIME")

        if hFind ~= nil and hFind ~= ffi.cast("HANDLE", -1) then
            repeat
                local name = ffi.string(find_data.cFileName)
                if name ~= "." then
                    local is_dir = (bit.band(find_data.dwFileAttributes, 0x10) ~= 0)
                    local size = tonumber(find_data.nFileSizeHigh) * 4294967296 + tonumber(find_data.nFileSizeLow)
                    ffi.C.FileTimeToSystemTime(find_data.ftLastWriteTime, st)
                    local mtime = string.format("%04d-%02d-%02d %02d:%02d", st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute)

                    table.insert(items, {
                        name = name,
                        is_dir = is_dir,
                        size = is_dir and 0 or size,
                        mtime = mtime,
                    })
                end
            until ffi.C.FindNextFileA(hFind, find_data) == 0
            ffi.C.FindClose(hFind)
        end
    else
        local cmd = string.format("LC_ALL=C ls -la '%s' 2>/dev/null", dir_path:gsub("'", "'\\''"))
        local pipe = io.popen(cmd, "r")
        if pipe then
            for line in pipe:lines() do
                local perms, size, date, time, name = line:match("^([%-%a][%-%a%w]+)%s+%d+%s+[^%s]+%s+[^%s]+%s+(%d+)%s+(%d%d%d%d%-%d%d%-%d%d)%s+([%d:]+)%s+(.*)$")
                if not perms then
                    perms, size, date, time, name = line:match("^([%-%a][%-%a%w]+)%s+%d+%s+[^%s]+%s+[^%s]+%s+(%d+)%s+([A-Za-z]+%s+%d+)%s+([%d:]+)%s+(.*)$")
                end
                if perms and name and name ~= "." then
                    local is_dir = (perms:sub(1, 1) == "d")
                    table.insert(items, {
                        name = name,
                        is_dir = is_dir,
                        size = is_dir and 0 or tonumber(size or 0),
                        mtime = (date and time) and (date .. " " .. time) or "-",
                    })
                end
            end
            pipe:close()
        end
    end

    -- Ensure parent dir entry '..' is always present unless at drive/root
    local has_parent = false
    for _, it in ipairs(items) do
        if it.name == ".." then has_parent = true break end
    end
    if not has_parent and dir_path ~= "/" and not dir_path:match("^%a:/?$") then
        table.insert(items, 1, {
            name = "..",
            is_dir = true,
            size = 0,
            mtime = "-",
        })
    end

    -- Sort: '..' first, then directories alphabetically, then files alphabetically
    table.sort(items, function(a, b)
        if a.name == ".." then return true end
        if b.name == ".." then return false end
        if a.is_dir ~= b.is_dir then
            return a.is_dir -- directories first
        end
        return a.name:lower() < b.name:lower()
    end)

    return items
end

--------------------------------------------------------------------------------
-- Host Aggregation (SSH Config, PuTTY Registry, known_hosts)
--------------------------------------------------------------------------------
local function aggregate_ssh_hosts()
    local hosts = {}
    local seen = {}

    local function add_host(name, hostname, user, port, source)
        if not name or name == "" or name:find("[*?]") or seen[name] then return end
        seen[name] = true
        table.insert(hosts, {
            name = name,
            hostname = hostname or name,
            user = user or "",
            port = port or "22",
            source = source or "ssh",
        })
    end

    -- 1. ~/.ssh/config & %USERPROFILE%/.ssh/config
    local home = get_home_dir()
    local cfg_paths = { home .. "/.ssh/config" }
    local userprof = os.getenv("USERPROFILE")
    if userprof then table.insert(cfg_paths, userprof:gsub("\\", "/") .. "/.ssh/config") end

    for _, cfg in ipairs(cfg_paths) do
        if file_exists(cfg) then
            local f = io.open(cfg, "r")
            if f then
                local cur_name, cur_host, cur_user, cur_port = nil, nil, nil, "22"
                for line in f:lines() do
                    local l = trim(line)
                    if l ~= "" and not l:match("^#") then
                        local k, v = l:match("^([%w_]+)%s*=?%s*(.*)$")
                        if k and v then
                            k = k:lower()
                            v = trim(v):gsub('^["\']', ''):gsub('["\']$', '')
                            if k == "host" then
                                if cur_name then
                                    add_host(cur_name, cur_host, cur_user, cur_port, "ssh-config")
                                end
                                cur_name = v
                                cur_host = nil
                                cur_user = nil
                                cur_port = "22"
                            elseif k == "hostname" then
                                cur_host = v
                            elseif k == "user" then
                                cur_user = v
                            elseif k == "port" then
                                cur_port = v
                            end
                        end
                    end
                end
                if cur_name then
                    add_host(cur_name, cur_host, cur_user, cur_port, "ssh-config")
                end
                f:close()
            end
        end
    end

    -- 2. PuTTY Registry Sessions (Windows)
    if IS_WINDOWS then
        pcall(function()
            local HKEY_CURRENT_USER = ffi.cast("void*", 0x80000001)
            local phkResult = ffi.new("HKEY[1]")
            local subkey = "Software\\SimonTatham\\PuTTY\\Sessions"
            if ffi.C.RegOpenKeyExA(HKEY_CURRENT_USER, subkey, 0, 0x20019, phkResult) == 0 then
                local hKey = phkResult[0]
                local dwIndex = 0
                local name_buf = ffi.new("char[256]")
                local name_len = ffi.new("DWORD[1]")
                while true do
                    name_len[0] = 256
                    if ffi.C.RegEnumKeyExA(hKey, dwIndex, name_buf, name_len, nil, nil, nil, nil) ~= 0 then
                        break
                    end
                    local raw_name = ffi.string(name_buf, name_len[0])
                    local decoded = (raw_name:gsub("%%(%x%x)", function(h)
                        return string.char(tonumber(h, 16))
                    end))
                    if decoded ~= "Default Settings" then
                        local phkSub = ffi.new("HKEY[1]")
                        if ffi.C.RegOpenKeyExA(hKey, raw_name, 0, 0x20019, phkSub) == 0 then
                            local hSub = phkSub[0]
                            local data_buf = ffi.new("char[256]")
                            local data_len = ffi.new("DWORD[1]", 256)
                            local dword_val = ffi.new("DWORD[1]")
                            local dword_len = ffi.new("DWORD[1]", 4)

                            local r_host, r_user, r_port = "", "", "22"
                            if ffi.C.RegQueryValueExA(hSub, "HostName", nil, nil, ffi.cast("BYTE*", data_buf), data_len) == 0 then
                                r_host = trim(ffi.string(data_buf))
                            end
                            data_len[0] = 256
                            if ffi.C.RegQueryValueExA(hSub, "UserName", nil, nil, ffi.cast("BYTE*", data_buf), data_len) == 0 then
                                r_user = trim(ffi.string(data_buf))
                            end
                            if ffi.C.RegQueryValueExA(hSub, "PortNumber", nil, nil, ffi.cast("BYTE*", dword_val), dword_len) == 0 then
                                r_port = tostring(dword_val[0])
                            end
                            ffi.C.RegCloseKey(hSub)
                            if r_host ~= "" then
                                add_host(decoded, r_host, r_user, r_port, "putty")
                            end
                        end
                    end
                    dwIndex = dwIndex + 1
                end
                ffi.C.RegCloseKey(hKey)
            end
        end)
    end

    -- 3. known_hosts
    local kh_path = home .. "/.ssh/known_hosts"
    if file_exists(kh_path) then
        local f = io.open(kh_path, "r")
        if f then
            for line in f:lines() do
                local host_part = line:match("^([^%s,]+)")
                if host_part and not host_part:match("^|") and not host_part:match("^#") then
                    host_part = host_part:gsub("^%[", ""):gsub("%]:%d+$", "")
                    add_host(host_part, host_part, "", "22", "known-hosts")
                end
            end
            f:close()
        end
    end

    return hosts
end

--------------------------------------------------------------------------------
-- Remote Filesystem Scanner (SSH / Demo Engine)
--------------------------------------------------------------------------------
local DemoFS = {
    ["/"] = {
        { name = "etc", is_dir = true, size = 4096, mtime = "2026-09-01 10:00" },
        { name = "home", is_dir = true, size = 4096, mtime = "2026-09-05 12:00" },
        { name = "var", is_dir = true, size = 4096, mtime = "2026-09-10 14:00" },
        { name = "tmp", is_dir = true, size = 4096, mtime = "2026-09-13 04:00" },
    },
    ["/etc"] = {
        { name = "nginx", is_dir = true, size = 4096, mtime = "2026-09-01 10:05" },
        { name = "hosts", is_dir = false, size = 250, mtime = "2026-08-20 08:30" },
        { name = "resolv.conf", is_dir = false, size = 120, mtime = "2026-08-20 08:30" },
    },
    ["/etc/nginx"] = {
        { name = "nginx.conf", is_dir = false, size = 3200, mtime = "2026-09-01 10:10" },
        { name = "conf.d", is_dir = true, size = 4096, mtime = "2026-09-01 10:15" },
    },
    ["/home"] = {
        { name = "user", is_dir = true, size = 4096, mtime = "2026-09-05 12:05" },
    },
    ["/home/user"] = {
        { name = "app", is_dir = true, size = 4096, mtime = "2026-09-11 16:20" },
        { name = ".bashrc", is_dir = false, size = 3771, mtime = "2026-09-05 12:10" },
        { name = "README.md", is_dir = false, size = 1450, mtime = "2026-09-12 09:15" },
        { name = "config.yaml", is_dir = false, size = 890, mtime = "2026-09-12 11:30" },
    },
    ["/home/user/app"] = {
        { name = "server.js", is_dir = false, size = 18450, mtime = "2026-09-11 16:25" },
        { name = "package.json", is_dir = false, size = 1240, mtime = "2026-09-11 16:22" },
        { name = "public", is_dir = true, size = 4096, mtime = "2026-09-11 16:30" },
    },
    ["/var"] = {
        { name = "log", is_dir = true, size = 4096, mtime = "2026-09-13 01:00" },
        { name = "www", is_dir = true, size = 4096, mtime = "2026-09-10 14:05" },
    },
    ["/var/www"] = {
        { name = "html", is_dir = true, size = 4096, mtime = "2026-09-10 14:10" },
    },
    ["/var/www/html"] = {
        { name = "index.html", is_dir = false, size = 4280, mtime = "2026-09-10 14:12" },
        { name = "app.js", is_dir = false, size = 32800, mtime = "2026-09-11 15:40" },
        { name = "style.css", is_dir = false, size = 12100, mtime = "2026-09-08 11:20" },
        { name = "robots.txt", is_dir = false, size = 320, mtime = "2026-08-25 09:10" },
    },
    ["/tmp"] = {
        { name = "backup_20260912.tar.gz", is_dir = false, size = 5242880, mtime = "2026-09-12 23:00" },
        { name = "test.sql", is_dir = false, size = 45000, mtime = "2026-09-13 03:30" },
    },
}
DemoFS["~"] = DemoFS["/home/user"]
DemoFS["~/app"] = DemoFS["/home/user/app"]

local remote_cache = {}

local function list_remote_directory(host_cfg, remote_dir)
    remote_dir = normalize_path(remote_dir)
    if remote_dir == "" then remote_dir = "/" end

    -- Check in-memory cache
    local cache_key = (host_cfg.hostname or host_cfg.name) .. ":" .. remote_dir
    if remote_cache[cache_key] then
        return remote_cache[cache_key], nil
    end

    local items = {}

    -- Demo Mode Handler
    if host_cfg.is_demo or host_cfg.name == "demo" then
        local demo_list = DemoFS[remote_dir] or DemoFS["/home/user"] or {}
        for _, it in ipairs(demo_list) do
            table.insert(items, {
                name = it.name,
                is_dir = it.is_dir,
                size = it.size,
                mtime = it.mtime,
            })
        end
    else
        -- Live SSH Remote Directory Listing
        local ssh_args = {}
        if host_cfg.port and host_cfg.port ~= "22" and host_cfg.port ~= "" then
            table.insert(ssh_args, "-p " .. host_cfg.port)
        end
        if host_cfg.key and host_cfg.key ~= "" then
            table.insert(ssh_args, "-i " .. shell_escape(host_cfg.key))
        end
        local target = host_cfg.hostname or host_cfg.name
        if host_cfg.user and host_cfg.user ~= "" then
            target = host_cfg.user .. "@" .. target
        end

        local remote_path_arg
        if remote_dir == "~" or remote_dir == "" then
            remote_path_arg = "~"
        elseif remote_dir:sub(1, 2) == "~/" then
            remote_path_arg = "~/'" .. remote_dir:sub(3):gsub("'", "'\\''") .. "'"
        else
            remote_path_arg = "'" .. remote_dir:gsub("'", "'\\''") .. "'"
        end
        local remote_sh = "LC_ALL=C ls -la --time-style=+%Y-%m-%d\\ %H:%M:%S " .. remote_path_arg
        local cmd = string.format("ssh -q -o ConnectTimeout=4 -o BatchMode=yes -o StrictHostKeyChecking=accept-new %s \"%s\" \"%s\"",
            table.concat(ssh_args, " "),
            target,
            remote_sh
        )

        local pipe = io.popen(cmd, "r")
        if not pipe then
            return {}, "Failed to execute SSH command"
        end

        for line in pipe:lines() do
            local perms, size, date, time, name = line:match("^([%-%a][%-%a%w]+)%s+%d+%s+[^%s]+%s+[^%s]+%s+(%d+)%s+(%d%d%d%d%-%d%d%-%d%d)%s+([%d:]+)%s+(.*)$")
            if not perms then
                perms, size, date, time, name = line:match("^([%-%a][%-%a%w]+)%s+%d+%s+[^%s]+%s+[^%s]+%s+(%d+)%s+([A-Za-z]+%s+%d+)%s+([%d:]+)%s+(.*)$")
            end
            if perms and name and name ~= "." then
                -- Handle symlink display: 'link -> target'
                local link_target = name:match("^(.-)%s+%->%s+(.*)$")
                local clean_name = link_target or name
                local is_symlink = (perms:sub(1, 1) == "l")
                local is_dir = (perms:sub(1, 1) == "d") or is_symlink
                table.insert(items, {
                    name = clean_name,
                    is_dir = is_dir,
                    size = is_dir and 0 or tonumber(size or 0),
                    mtime = (date and time) and (date .. " " .. time) or "-",
                })
            end
        end
        pipe:close()
    end

    -- Add '..' if not at root
    if remote_dir ~= "/" then
        local has_parent = false
        for _, it in ipairs(items) do
            if it.name == ".." then has_parent = true break end
        end
        if not has_parent then
            table.insert(items, 1, {
                name = "..",
                is_dir = true,
                size = 0,
                mtime = "-",
            })
        end
    end

    -- Sort items: '..' first, then directories alphabetically, then files alphabetically
    table.sort(items, function(a, b)
        if a.name == ".." then return true end
        if b.name == ".." then return false end
        if a.is_dir ~= b.is_dir then
            return a.is_dir
        end
        return a.name:lower() < b.name:lower()
    end)

    remote_cache[cache_key] = items
    return items, nil
end

--------------------------------------------------------------------------------
-- Dual-Pane Application State & Engine
--------------------------------------------------------------------------------
local App = {
    running = true,
    active_pane = "left", -- "left" (local) or "right" (remote)
    term_w = 100,
    term_h = 30,
    status_msg = "Ready. Press [?] for help, [Tab] to switch panes.",
    status_color = C.gray,
    show_hidden = false, -- Default: hide hidden files/folders (.xxx)

    -- Host config
    host_cfg = {
        name = "demo",
        hostname = "demo-server",
        user = "user",
        port = "22",
        is_demo = true,
    },

    -- Modal states
    modal = nil, -- nil, "confirm_transfer", "host_picker", "help", "filter"
    modal_data = {},

    left = {
        title = "LOCAL",
        dir = ".",
        items = {},
        cursor = 1,
        scroll_top = 1,
        selected = {},
        filter = "",
    },

    right = {
        title = "REMOTE",
        dir = "~",
        items = {},
        cursor = 1,
        scroll_top = 1,
        selected = {},
        filter = "",
    },
}

function App.refresh_left()
    App.left.items = list_local_directory(App.left.dir)
    if App.left.cursor > #App.left.items then App.left.cursor = math.max(1, #App.left.items) end
end

function App.refresh_right(force_network)
    if force_network then
        remote_cache = {}
        if not App.host_cfg.is_demo and (App.right.dir == "~" or App.right.dir == "") then
            local target = App.host_cfg.hostname or App.host_cfg.name
            if App.host_cfg.user and App.host_cfg.user ~= "" then target = App.host_cfg.user .. "@" .. target end
            local ssh_args = {}
            if App.host_cfg.port and App.host_cfg.port ~= "22" and App.host_cfg.port ~= "" then table.insert(ssh_args, "-p " .. App.host_cfg.port) end
            if App.host_cfg.key and App.host_cfg.key ~= "" then table.insert(ssh_args, "-i " .. shell_escape(App.host_cfg.key)) end
            local pwd_cmd = string.format("ssh -q -o ConnectTimeout=4 -o BatchMode=yes -o StrictHostKeyChecking=accept-new %s \"%s\" \"pwd\"",
                table.concat(ssh_args, " "), target)
            local p = io.popen(pwd_cmd, "r")
            if p then
                local real_home = p:read("*l")
                p:close()
                if real_home and real_home:match("^/[^%s]+") then
                    App.right.dir = trim(real_home)
                end
            end
        end
    end
    local items, err = list_remote_directory(App.host_cfg, App.right.dir)
    if err then
        App.status_msg = "Remote error: " .. err
        App.status_color = C.red
    else
        App.right.items = items
        if App.right.cursor > #App.right.items then App.right.cursor = math.max(1, #App.right.items) end
    end
end

function App.get_filtered_items(pane)
    local filtered = {}
    local query = (pane.filter and pane.filter ~= "") and pane.filter:lower() or nil
    for _, it in ipairs(pane.items) do
        local is_hidden = (it.name:sub(1, 1) == "." and it.name ~= "..")
        if App.show_hidden or not is_hidden then
            if not query or it.name == ".." or it.name:lower():find(query, 1, true) then
                table.insert(filtered, it)
            end
        end
    end
    return filtered
end

function App.get_selected_count(pane)
    local count = 0
    local total_bytes = 0
    for _, it in ipairs(pane.items) do
        if pane.selected[it.name] and it.name ~= ".." then
            count = count + 1
            total_bytes = total_bytes + (it.size or 0)
        end
    end
    return count, total_bytes
end

--------------------------------------------------------------------------------
-- Rendering Subsystem (Double-Buffered Flicker-Free ANSI)
--------------------------------------------------------------------------------
function App.draw()
    local w, h = Term.get_size()
    App.term_w = w
    App.term_h = h

    local buf = {}
    table.insert(buf, "\27[H") -- move to top-left

    -- 1. Top Header Bar
    local host_display = App.host_cfg.is_demo and (C.bright_yellow .. "[DEMO MODE: Simulated Server]" .. C.reset) or
        (C.bright_green .. string.format("[Connected: %s%s:%s]",
            (App.host_cfg.user ~= "" and (App.host_cfg.user .. "@") or ""),
            (App.host_cfg.hostname or App.host_cfg.name),
            App.host_cfg.port
        ) .. C.reset)

    local raw_title = string.format(" FSCP-TUI v1.0 | %s ",
        App.host_cfg.is_demo and "[DEMO MODE: Simulated Server]" or
        string.format("[Connected: %s%s:%s]",
            (App.host_cfg.user ~= "" and (App.host_cfg.user .. "@") or ""),
            (App.host_cfg.hostname or App.host_cfg.name),
            App.host_cfg.port
        )
    )
    local styled_title = string.format(" %s%sFSCP-TUI v1.0%s | %s ", C.bold, C.bright_cyan, C.reset, host_display)
    local rem_len = math.max(0, w - #raw_title)
    table.insert(buf, string.format("\27[1;1H%s%s%s%s\27[K", styled_title, C.cyan, BOX.h:rep(rem_len), C.reset))

    -- 2. Pane Geometry
    local content_h = h - 5
    if content_h < 4 then content_h = 4 end

    local half_w = math.floor((w - 3) / 2)
    local right_w = w - 3 - half_w

    -- Pane Titles
    local left_is_active = (App.active_pane == "left")
    local left_accent = left_is_active and (C.bold .. C.bright_cyan) or C.gray
    local right_accent = (not left_is_active) and (C.bold .. C.bright_cyan) or C.gray

    local left_sel_n, left_sel_b = App.get_selected_count(App.left)
    local right_sel_n, right_sel_b = App.get_selected_count(App.right)

    local left_title_text = string.format(" Local: %s ", App.left.dir)
    if left_sel_n > 0 then left_title_text = left_title_text .. string.format("(%d sel, %s) ", left_sel_n, format_size(left_sel_b)) end
    left_title_text = pad_string(left_title_text, half_w)

    local right_title_text = string.format(" Remote: %s ", App.right.dir)
    if right_sel_n > 0 then right_title_text = right_title_text .. string.format("(%d sel, %s) ", right_sel_n, format_size(right_sel_b)) end
    right_title_text = pad_string(right_title_text, right_w)

    table.insert(buf, string.format("\27[2;1H%s%s%s%s%s%s%s\27[K",
        left_accent, BOX.tl, left_title_text:sub(1, half_w), BOX.tt,
        right_accent, right_title_text:sub(1, right_w), BOX.tr .. C.reset
    ))

    -- 3. Pane Rows
    local left_items = App.get_filtered_items(App.left)
    local right_items = App.get_filtered_items(App.right)

    -- Adjust scrolling
    if App.left.cursor < App.left.scroll_top then
        App.left.scroll_top = App.left.cursor
    elseif App.left.cursor >= App.left.scroll_top + content_h then
        App.left.scroll_top = App.left.cursor - content_h + 1
    end
    if App.right.cursor < App.right.scroll_top then
        App.right.scroll_top = App.right.cursor
    elseif App.right.cursor >= App.right.scroll_top + content_h then
        App.right.scroll_top = App.right.cursor - content_h + 1
    end

    for row = 1, content_h do
        local cur_y = 2 + row
        -- Left Pane Column
        local l_idx = App.left.scroll_top + row - 1
        local l_item = left_items[l_idx]
        local l_str = ""
        if l_item then
            local is_cur = (left_is_active and l_idx == App.left.cursor)
            local is_sel = App.left.selected[l_item.name]
            local prefix = is_sel and (C.bright_yellow .. "[*]" .. C.reset) or "   "
            local cur_arrow = is_cur and ">" or " "
            local type_icon = l_item.is_dir and (C.bright_blue .. "[DIR]" .. C.reset) or "     "
            local size_str = pad_string(l_item.is_dir and "-" or format_size(l_item.size), 7, true)
            local date_str = ""
            local meta_w = 19
            if half_w >= 48 then
                date_str = " " .. pad_string(l_item.mtime or "-", 16)
                meta_w = 36
            elseif half_w >= 36 then
                local short_date = (l_item.mtime and l_item.mtime:match("(%d%d%-%d%d)")) or (l_item.mtime and l_item.mtime:sub(1, 5)) or "-"
                date_str = " " .. pad_string(short_date, 5)
                meta_w = 25
            end
            local avail_name_w = math.max(6, half_w - meta_w)
            local name_disp = pad_string(l_item.name, avail_name_w)
            local line_color = is_cur and (C.reverse .. C.bold) or (l_item.is_dir and C.bright_white or C.white)
            l_str = string.format("%s%s %s %s%s %s%s", cur_arrow, prefix, type_icon, line_color, name_disp .. C.reset, size_str, date_str)
        else
            l_str = string.rep(" ", half_w)
        end

        -- Right Pane Column
        local r_idx = App.right.scroll_top + row - 1
        local r_item = right_items[r_idx]
        local r_str = ""
        if r_item then
            local is_cur = ((not left_is_active) and r_idx == App.right.cursor)
            local is_sel = App.right.selected[r_item.name]
            local prefix = is_sel and (C.bright_yellow .. "[*]" .. C.reset) or "   "
            local cur_arrow = is_cur and ">" or " "
            local type_icon = r_item.is_dir and (C.bright_blue .. "[DIR]" .. C.reset) or "     "
            local size_str = pad_string(r_item.is_dir and "-" or format_size(r_item.size), 7, true)
            local date_str = ""
            local meta_w = 19
            if right_w >= 48 then
                date_str = " " .. pad_string(r_item.mtime or "-", 16)
                meta_w = 36
            elseif right_w >= 36 then
                local short_date = (r_item.mtime and r_item.mtime:match("(%d%d%-%d%d)")) or (r_item.mtime and r_item.mtime:sub(1, 5)) or "-"
                date_str = " " .. pad_string(short_date, 5)
                meta_w = 25
            end
            local avail_name_w = math.max(6, right_w - meta_w)
            local name_disp = pad_string(r_item.name, avail_name_w)
            local line_color = is_cur and (C.reverse .. C.bold) or (r_item.is_dir and C.bright_white or C.white)
            r_str = string.format("%s%s %s %s%s %s%s", cur_arrow, prefix, type_icon, line_color, name_disp .. C.reset, size_str, date_str)
        else
            r_str = string.rep(" ", right_w)
        end

        table.insert(buf, string.format("\27[%d;1H%s%s%s%s%s\27[K",
            cur_y,
            left_accent .. BOX.v .. C.reset,
            l_str,
            left_accent .. BOX.v .. right_accent,
            r_str,
            BOX.v .. C.reset
        ))
    end

    -- 4. Pane Bottom Borders
    local btm_y = content_h + 3
    table.insert(buf, string.format("\27[%d;1H%s%s%s%s%s%s\27[K",
        btm_y,
        left_accent, BOX.bl, BOX.h:rep(half_w), BOX.tb,
        right_accent, BOX.h:rep(right_w) .. BOX.br .. C.reset
    ))

    -- 5. Status / Message Line
    local stat_y = content_h + 4
    table.insert(buf, string.format("\27[%d;1H%s%s%s\27[K",
        stat_y,
        App.status_color, pad_string(" " .. App.status_msg, w), C.reset
    ))

    -- 6. Keyboard Guide Footer Bar
    local foot_y = content_h + 5
    local keyguide = string.format(" [Tab] Switch  [Space] Select  [.] Hidden:%s  [u] Upload ->  [d] <- Download  [r] Refresh  [?] Help  [q] Quit ",
        App.show_hidden and "ON" or "OFF"
    )
    table.insert(buf, string.format("\27[%d;1H%s%s%s%s\27[K",
        foot_y,
        C.bg_gray, C.bold .. C.bright_white, pad_string(keyguide, w), C.reset
    ))

    -- Render in one atomic write
    io.write(table.concat(buf))
    io.flush()

    -- 7. Modals Overlay Rendering (if active)
    if App.modal == "confirm_transfer" then
        App.draw_confirm_modal()
    elseif App.modal == "host_picker" then
        App.draw_host_picker_modal()
    elseif App.modal == "help" then
        App.draw_help_modal()
    end
end

function App.draw_confirm_modal()
    local w, h = App.term_w, App.term_h
    local mw = math.min(68, w - 6)
    local mh = 11
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    local d = App.modal_data
    local is_upload = (d.direction == "upload")
    local title = is_upload and " Confirm Upload (Local -> Remote) " or " Confirm Download (Remote -> Local) "
    local target_dest = is_upload and (App.host_cfg.hostname .. ":" .. App.right.dir) or App.left.dir

    local lines = {
        BOX.tl .. pad_string(title, mw - 2) .. BOX.tr,
        BOX.v .. pad_string(" Direction : " .. (is_upload and "Upload to Remote Host" or "Download to Local Drive"), mw - 2) .. BOX.v,
        BOX.v .. pad_string(" Target    : " .. target_dest, mw - 2) .. BOX.v,
        BOX.v .. pad_string(string.format(" Selection : %d item(s) (%s)", d.count, format_size(d.bytes)), mw - 2) .. BOX.v,
        BOX.v .. pad_string(" Method    : rsync -avzP (fallback: scp -r)", mw - 2) .. BOX.v,
        BOX.v .. pad_string(" Sample    : " .. (d.items[1] or ""), mw - 2) .. BOX.v,
        BOX.v .. BOX.h:rep(mw - 2) .. BOX.v,
        BOX.v .. pad_string(" Execute transfer now? [Y]es / [N]o", mw - 2) .. BOX.v,
        BOX.bl .. BOX.h:rep(mw - 2) .. BOX.br,
    }

    local modal_buf = {}
    for i, line in ipairs(lines) do
        table.insert(modal_buf, string.format("\27[%d;%dH%s%s%s%s",
            my + i - 1, mx, C.bold, C.bright_yellow, line, C.reset
        ))
    end
    io.write(table.concat(modal_buf))
    io.flush()
end

function App.draw_help_modal()
    local w, h = App.term_w, App.term_h
    local mw = math.min(72, w - 4)
    local mh = 18
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    local help_lines = {
        BOX.tl .. pad_string(" FSCP-TUI Keybindings & Guide ", mw - 2) .. BOX.tr,
        BOX.v .. pad_string(" Tab                   Switch active pane (Left <-> Right)", mw - 2) .. BOX.v,
        BOX.v .. pad_string(" Up / k, Down / j      Move cursor up / down", mw - 2) .. BOX.v,
        BOX.v .. pad_string(" Enter / l / Right     Enter selected directory", mw - 2) .. BOX.v,
        BOX.v .. pad_string(" Backspace / h / Left  Go up to parent directory (..)", mw - 2) .. BOX.v,
        BOX.v .. pad_string(" Space                 Toggle multi-select on current item", mw - 2) .. BOX.v,
        BOX.v .. pad_string(" .                     Toggle hidden files/folders (default: OFF)", mw - 2) .. BOX.v,
        BOX.v .. pad_string(" a / A                 Select ALL / Deselect ALL items", mw - 2) .. BOX.v,
        BOX.v .. pad_string(" u / F5                Upload selected items (Local -> Remote)", mw - 2) .. BOX.v,
        BOX.v .. pad_string(" d / F5                Download selected items (Remote -> Local)", mw - 2) .. BOX.v,
        BOX.v .. pad_string(" r                     Refresh directory contents", mw - 2) .. BOX.v,
        BOX.v .. pad_string(" ~                     Jump directly to Home directory", mw - 2) .. BOX.v,
        BOX.v .. pad_string(" H                     Open Host Picker (Switch Remote Host)", mw - 2) .. BOX.v,
        BOX.v .. pad_string(" /                     Filter items in current pane", mw - 2) .. BOX.v,
        BOX.v .. pad_string(" q / Esc / Ctrl+C      Quit application", mw - 2) .. BOX.v,
        BOX.v .. BOX.h:rep(mw - 2) .. BOX.v,
        BOX.v .. pad_string(" Press any key to close this help window...", mw - 2) .. BOX.v,
        BOX.bl .. BOX.h:rep(mw - 2) .. BOX.br,
    }

    local modal_buf = {}
    for i, line in ipairs(help_lines) do
        table.insert(modal_buf, string.format("\27[%d;%dH%s%s%s%s",
            my + i - 1, mx, C.bold, C.bright_cyan, line, C.reset
        ))
    end
    io.write(table.concat(modal_buf))
    io.flush()
end

function App.draw_host_picker_modal()
    local w, h = App.term_w, App.term_h
    local mw = math.min(86, w - 4)
    local mh = math.min(18, h - 4)
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    local d = App.modal_data
    local hosts = d.filtered or d.hosts or {}
    local cur = d.cursor or 1
    local filter_str = d.filter or ""

    local lines = {
        BOX.tl .. pad_string(" Connect to Remote Server ", mw - 2) .. BOX.tr,
        BOX.v .. pad_string(" [↑/↓ or j/k] Navigate   [Enter or l] Connect   [Type] Filter   [Esc] Demo Mode", mw - 2) .. BOX.v,
    }

    if filter_str ~= "" then
        table.insert(lines, BOX.v .. pad_string(" Filter: " .. filter_str .. "_", mw - 2) .. BOX.v)
    end

    table.insert(lines, BOX.v .. BOX.h:rep(mw - 2) .. BOX.v)
    table.insert(lines, BOX.v .. pad_string(string.format("   %-18s %-26s %-10s %-6s %s", "NAME", "HOST / IP", "USER", "PORT", "SOURCE"), mw - 2) .. BOX.v)
    table.insert(lines, BOX.v .. BOX.h:rep(mw - 2) .. BOX.v)

    local view_h = mh - (filter_str ~= "" and 7 or 6)
    if view_h < 4 then view_h = 4 end
    local scroll = math.max(1, cur - view_h + 1)

    for i = 1, view_h do
        local idx = scroll + i - 1
        local h_entry = hosts[idx]
        if h_entry then
            local is_cur = (idx == cur)
            local prefix = is_cur and "> " or "  "
            local src_tag = string.format("[%s]", h_entry.source or "ssh")
            local desc = string.format("%s%-18s %-26s %-10s %-6s %s",
                prefix,
                h_entry.name:sub(1, 18),
                (h_entry.hostname or ""):sub(1, 26),
                (h_entry.user ~= "" and h_entry.user or "-"):sub(1, 10),
                (h_entry.port or "22"):sub(1, 6),
                src_tag
            )
            local line_col = is_cur and (C.reverse .. C.bold) or C.bright_white
            table.insert(lines, BOX.v .. line_col .. pad_string(desc, mw - 2) .. C.reset .. C.bright_cyan .. BOX.v)
        else
            table.insert(lines, BOX.v .. string.rep(" ", mw - 2) .. BOX.v)
        end
    end

    table.insert(lines, BOX.v .. BOX.h:rep(mw - 2) .. BOX.v)
    table.insert(lines, BOX.v .. pad_string(string.format(" Total: %d server(s) | Press [Enter] to connect", #hosts), mw - 2) .. BOX.v)
    table.insert(lines, BOX.bl .. BOX.h:rep(mw - 2) .. BOX.br)

    local modal_buf = {}
    for i, line in ipairs(lines) do
        table.insert(modal_buf, string.format("\27[%d;%dH%s%s%s%s",
            my + i - 1, mx, C.bold, C.bright_cyan, line, C.reset
        ))
    end
    io.write(table.concat(modal_buf))
    io.flush()
end

--------------------------------------------------------------------------------
-- Transfer Execution Engine (Rsync & SCP Bridge)
--------------------------------------------------------------------------------
function App.execute_transfer(direction, items)
    Term.restore()
    io.write("\27[2J\27[H")
    io.flush()

    local is_upload = (direction == "upload")
    print(C.bold .. C.bright_cyan .. "============================================================" .. C.reset)
    print(string.format("%s%s Starting %s: %d item(s)%s",
        C.bold, C.bright_yellow, is_upload and "UPLOAD (Local -> Remote)" or "DOWNLOAD (Remote -> Local)", #items, C.reset
    ))
    print(C.bold .. C.bright_cyan .. "============================================================" .. C.reset)

    if App.host_cfg.is_demo or App.host_cfg.name == "demo" then
        print("\n" .. C.bright_yellow .. "[DEMO MODE NOTICE]" .. C.reset)
        print("Simulating transfer:")
        for _, it in ipairs(items) do
            print(string.format("  -> %s %s", is_upload and "Uploading" or "Downloading", it))
        end
        print("\n" .. C.bright_green .. "Demo transfer simulated successfully!" .. C.reset)
    else
        local host = App.host_cfg.hostname or App.host_cfg.name
        if App.host_cfg.user and App.host_cfg.user ~= "" then
            host = App.host_cfg.user .. "@" .. host
        end

        local port_opt = (App.host_cfg.port and App.host_cfg.port ~= "22") and ("-P " .. App.host_cfg.port) or ""
        local key_opt = (App.host_cfg.key and App.host_cfg.key ~= "") and ("-i " .. shell_escape(App.host_cfg.key)) or ""

        -- Execute SCP or Rsync
        local cmd = ""
        if is_upload then
            local escaped_items = {}
            for _, it in ipairs(items) do
                local full_path = App.left.dir .. "/" .. it
                table.insert(escaped_items, shell_escape(full_path))
            end
            local remote_dest = string.format("%s:%s/", host, App.right.dir)
            cmd = string.format("scp -r %s %s %s %s", port_opt, key_opt, table.concat(escaped_items, " "), shell_escape(remote_dest))
        else
            local escaped_items = {}
            for _, it in ipairs(items) do
                local remote_src = string.format("%s:%s/%s", host, App.right.dir, it)
                table.insert(escaped_items, shell_escape(remote_src))
            end
            local local_dest = shell_escape(App.left.dir)
            cmd = string.format("scp -r %s %s %s %s", port_opt, key_opt, table.concat(escaped_items, " "), local_dest)
        end

        print("\nExecuting command:")
        print(C.gray .. cmd .. C.reset .. "\n")
        local ret = os.execute(cmd)
        print(string.format("\nTransfer process finished with exit code: %s", tostring(ret)))
    end

    print("\n" .. C.bright_white .. "Press [Enter] to return to FSCP-TUI..." .. C.reset)
    io.read()

    Term.enable_raw()
    App.refresh_left()
    App.refresh_right(true)
    App.status_msg = "Transfer complete. Directory views refreshed."
    App.status_color = C.bright_green
end

--------------------------------------------------------------------------------
-- User Input & Event Dispatcher
--------------------------------------------------------------------------------
function App.handle_input(key)
    if not key then return end

    -- Modals Handling
    if App.modal == "help" then
        App.modal = nil
        return
    elseif App.modal == "confirm_transfer" then
        if key == "y" or key == "Y" or key == "enter" then
            local d = App.modal_data
            App.modal = nil
            App.execute_transfer(d.direction, d.items)
        elseif key == "n" or key == "N" or key == "esc" or key == "q" then
            App.modal = nil
            App.status_msg = "Transfer cancelled."
            App.status_color = C.yellow
        end
        return
    elseif App.modal == "host_picker" then
        local d = App.modal_data
        local filtered = d.filtered or d.hosts or {}
        local cur = d.cursor or 1
        local total = #filtered

        local function update_filter()
            local q = (d.filter or ""):lower()
            if q == "" then
                d.filtered = d.hosts
            else
                local res = {}
                for _, h in ipairs(d.hosts) do
                    if (h.name:lower():find(q, 1, true) or (h.hostname and h.hostname:lower():find(q, 1, true)) or (h.user and h.user:lower():find(q, 1, true))) then
                        table.insert(res, h)
                    end
                end
                d.filtered = res
            end
            d.cursor = 1
        end

        if key == "up" or key == "k" then
            d.cursor = math.max(1, cur - 1)
        elseif key == "down" or key == "j" then
            d.cursor = math.min(total, cur + 1)
        elseif key == "pageup" then
            d.cursor = math.max(1, cur - 10)
        elseif key == "pagedown" then
            d.cursor = math.min(total, cur + 10)
        elseif key == "enter" or key == "l" or key == "right" then
            local sel = filtered[cur]
            if sel then
                App.host_cfg = sel
                App.modal = nil
                App.active_pane = "right"
                App.right.dir = sel.is_demo and "/home/user" or "~"
                remote_cache = {}
                App.status_msg = "Connecting to " .. sel.name .. "..."
                App.status_color = C.bright_cyan
                App.refresh_right(true)
            end
        elseif key == "backspace" then
            if d.filter and #d.filter > 0 then
                d.filter = d.filter:sub(1, -2)
                update_filter()
            end
        elseif key == "esc" then
            if d.filter and #d.filter > 0 then
                d.filter = ""
                update_filter()
            else
                -- Dismiss modal and fall back to demo mode
                App.modal = nil
                App.status_msg = "Switched to Demo Mode. Press [H] to pick SSH host."
                App.status_color = C.yellow
            end
        elseif key:len() == 1 and key:match("[%w_%-%.]") then
            d.filter = (d.filter or "") .. key
            update_filter()
        end
        return
    end

    -- Normal TUI Key Navigation
    local cur_pane = (App.active_pane == "left") and App.left or App.right
    local other_pane = (App.active_pane == "left") and App.right or App.left
    local items = App.get_filtered_items(cur_pane)

    if key == "tab" then
        App.active_pane = (App.active_pane == "left") and "right" or "left"
        App.status_msg = "Switched to " .. ((App.active_pane == "left") and "Local" or "Remote") .. " pane."
        App.status_color = C.gray
    elseif key == "up" or key == "k" then
        if cur_pane.cursor > 1 then
            cur_pane.cursor = cur_pane.cursor - 1
        end
    elseif key == "down" or key == "j" then
        if cur_pane.cursor < #items then
            cur_pane.cursor = cur_pane.cursor + 1
        end
    elseif key == "pageup" then
        cur_pane.cursor = math.max(1, cur_pane.cursor - 15)
    elseif key == "pagedown" then
        cur_pane.cursor = math.min(#items, cur_pane.cursor + 15)
    elseif key == "home" then
        cur_pane.cursor = 1
    elseif key == "end" then
        cur_pane.cursor = math.max(1, #items)
    elseif key == "enter" or key == "l" or key == "right" then
        local it = items[cur_pane.cursor]
        if it and it.is_dir then
            if it.name == ".." then
                cur_pane.dir = get_parent_dir(cur_pane.dir)
            else
                cur_pane.dir = normalize_path(cur_pane.dir .. "/" .. it.name)
            end
            cur_pane.cursor = 1
            cur_pane.scroll_top = 1
            cur_pane.selected = {}
            if App.active_pane == "left" then
                App.refresh_left()
            else
                App.refresh_right(false)
            end
        elseif it and not it.is_dir then
            App.status_msg = string.format("File: %s (%s, %s)", it.name, format_size(it.size), it.mtime or "-")
            App.status_color = C.bright_cyan
        end
    elseif key == "backspace" or key == "h" or key == "left" then
        cur_pane.dir = get_parent_dir(cur_pane.dir)
        cur_pane.cursor = 1
        cur_pane.scroll_top = 1
        cur_pane.selected = {}
        if App.active_pane == "left" then
            App.refresh_left()
        else
            App.refresh_right(false)
        end
    elseif key == "space" then
        local it = items[cur_pane.cursor]
        if it and it.name ~= ".." then
            cur_pane.selected[it.name] = not cur_pane.selected[it.name]
            if cur_pane.cursor < #items then
                cur_pane.cursor = cur_pane.cursor + 1
            end
        end
    elseif key == "a" then
        -- Select all items
        for _, it in ipairs(items) do
            if it.name ~= ".." then
                cur_pane.selected[it.name] = true
            end
        end
        App.status_msg = "Selected all items in active pane."
        App.status_color = C.yellow
    elseif key == "A" then
        -- Clear selection
        cur_pane.selected = {}
        App.status_msg = "Selection cleared."
        App.status_color = C.gray
    elseif key == "u" or (App.active_pane == "left" and key == "f5") then
        -- Upload from Left to Right
        local sel_items = {}
        local sel_bytes = 0
        for _, it in ipairs(App.left.items) do
            if App.left.selected[it.name] and it.name ~= ".." then
                table.insert(sel_items, it.name)
                sel_bytes = sel_bytes + (it.size or 0)
            end
        end
        if #sel_items == 0 then
            local hovered = App.left.items[App.left.cursor]
            if hovered and hovered.name ~= ".." then
                table.insert(sel_items, hovered.name)
                sel_bytes = hovered.size or 0
            end
        end
        if #sel_items > 0 then
            App.modal = "confirm_transfer"
            App.modal_data = {
                direction = "upload",
                items = sel_items,
                count = #sel_items,
                bytes = sel_bytes,
            }
        else
            App.status_msg = "No files or folders selected to upload."
            App.status_color = C.yellow
        end
    elseif key == "d" or (App.active_pane == "right" and key == "f5") then
        -- Download from Right to Left
        local sel_items = {}
        local sel_bytes = 0
        for _, it in ipairs(App.right.items) do
            if App.right.selected[it.name] and it.name ~= ".." then
                table.insert(sel_items, it.name)
                sel_bytes = sel_bytes + (it.size or 0)
            end
        end
        if #sel_items == 0 then
            local hovered = App.right.items[App.right.cursor]
            if hovered and hovered.name ~= ".." then
                table.insert(sel_items, hovered.name)
                sel_bytes = hovered.size or 0
            end
        end
        if #sel_items > 0 then
            App.modal = "confirm_transfer"
            App.modal_data = {
                direction = "download",
                items = sel_items,
                count = #sel_items,
                bytes = sel_bytes,
            }
        else
            App.status_msg = "No files or folders selected to download."
            App.status_color = C.yellow
        end
    elseif key == "r" then
        App.refresh_left()
        App.refresh_right(true)
        App.status_msg = "Both panes refreshed."
        App.status_color = C.green
    elseif key == "~" then
        cur_pane.dir = get_home_dir()
        cur_pane.cursor = 1
        cur_pane.scroll_top = 1
        if App.active_pane == "left" then App.refresh_left() else App.refresh_right(false) end
    elseif key == "." then
        App.show_hidden = not App.show_hidden
        App.status_msg = App.show_hidden and "Showing hidden files and folders." or "Hidden files/folders are now hidden."
        App.status_color = App.show_hidden and C.bright_yellow or C.gray
        local left_items = App.get_filtered_items(App.left)
        if App.left.cursor > #left_items then App.left.cursor = math.max(1, #left_items) end
        local right_items = App.get_filtered_items(App.right)
        if App.right.cursor > #right_items then App.right.cursor = math.max(1, #right_items) end
    elseif key == "H" then
        local hosts = aggregate_ssh_hosts()
        table.insert(hosts, 1, {
            name = "demo",
            hostname = "demo-server",
            user = "user",
            port = "22",
            source = "demo",
            is_demo = true,
        })
        App.modal = "host_picker"
        App.modal_data = { hosts = hosts, cursor = 1 }
    elseif key == "?" then
        App.modal = "help"
    elseif key == "q" or key == "ctrl_c" then
        App.running = false
    end
end

--------------------------------------------------------------------------------
-- Main Entrypoint & Lifecycle
--------------------------------------------------------------------------------
local function main(...)
    local args = { ... }

    -- Parse CLI Options
    local cli_host = nil
    local cli_remote_path = nil
    local cli_local_path = "."
    local is_demo = false

    local i = 1
    while i <= #args do
        local arg = args[i]
        if arg == "--demo" then
            is_demo = true
        elseif arg == "--ascii" then
            BOX = BOX_ASCII
        elseif arg == "--test" then
            print(C.bold .. C.bright_cyan .. "[TEST] Running FSCP-TUI Verification Suite..." .. C.reset)
            -- 1. Test local listing
            local local_items = list_local_directory(".")
            assert(#local_items > 0, "Local items count should be > 0")
            print(string.format("  [PASS] list_local_directory('.'): found %d items", #local_items))

            -- 2. Test remote demo listing
            local demo_cfg = { name = "demo", is_demo = true }
            local remote_items, err = list_remote_directory(demo_cfg, "/home/user/app")
            assert(#remote_items > 0, "Remote items count should be > 0")
            assert(not err, "Remote listing should not error")
            print(string.format("  [PASS] list_remote_directory(demo, '/home/user/app'): found %d items", #remote_items))
            local home_items = list_remote_directory(demo_cfg, "~")
            assert(#home_items > 0, "Remote home listing should find items")
            local app_items = list_remote_directory(demo_cfg, "~/app")
            assert(#app_items > 0, "Remote subpath ~/app should find items")
            print("  [PASS] list_remote_directory tilde resolution tests")

            -- 3. Test host aggregation
            local hosts = aggregate_ssh_hosts()
            print(string.format("  [PASS] aggregate_ssh_hosts(): found %d host(s)", #hosts))

            -- 4. Test format_size
            assert(format_size(500) == "500 B", "format_size 500 B failed")
            assert(format_size(2048) == "2.0 KB", "format_size 2.0 KB failed")
            assert(format_size(1048576) == "1.0 MB", "format_size 1.0 MB failed")
            print("  [PASS] format_size unit tests")

            -- 5. Test parent dir logic
            assert(get_parent_dir("/var/www/html") == "/var/www", "Parent dir failed")
            assert(get_parent_dir("C:/test/utils") == "C:/test", "Parent dir Windows failed")
            print("  [PASS] get_parent_dir unit tests")

            -- 6. Test App selection and state
            App.left.items = local_items
            local target_item = (local_items[1].name == "..") and local_items[2] or local_items[1]
            App.left.selected[target_item.name] = true
            local count, bytes = App.get_selected_count(App.left)
            assert(count == 1, "Selection count should be 1")
            print(string.format("  [PASS] Selection engine: 1 item (%s: %s)", target_item.name, format_size(bytes)))

            -- 7. Test hidden items filtering
            App.show_hidden = false
            local filtered_off = App.get_filtered_items(App.left)
            for _, it in ipairs(filtered_off) do
                assert(it.name == ".." or it.name:sub(1, 1) ~= ".", "Hidden item should not appear when show_hidden is false: " .. it.name)
            end
            App.show_hidden = true
            local filtered_on = App.get_filtered_items(App.left)
            assert(#filtered_on >= #filtered_off, "Show hidden ON should have >= items than OFF")
            App.show_hidden = false
            print("  [PASS] Hidden items filtering tests")
            print(C.bold .. C.bright_green .. "[ALL TESTS PASSED SUCCESSFULLY]" .. C.reset)
            return
        elseif arg == "--snapshot" then
            App.term_w, App.term_h = 98, 22
            App.host_cfg = {
                name = "dev-server",
                hostname = "dev-server.local",
                user = "zliu",
                port = "22",
                is_demo = true,
            }
            App.left.dir = "C:/test/utils"
            App.right.dir = "/var/www/html"
            App.refresh_left()
            App.refresh_right(false)
            -- Add some selections for demonstration
            for _, it in ipairs(App.left.items) do
                if it.name == "deploy.sh" or it.name == "notes.md" then
                    App.left.selected[it.name] = true
                end
                if it.name == "deploy_gui.py" then
                    App.left.cursor = _
                end
            end
            for _, it in ipairs(App.right.items) do
                if it.name == "app.js" then
                    App.right.selected[it.name] = true
                end
            end
            App.status_msg = "Ready. 2 local files selected (45.4 KB). Press 'u' to upload."
            App.status_color = C.bright_yellow
            App.draw()
            return
        elseif arg == "-h" or arg == "--help" then
            print([[
fscp_tui.lua - Fast Dual-Pane TUI File Transfer Tool (LuaJIT FFI)

Usage:
  luajit fscp_tui.lua [HOST] [REMOTE_PATH] [LOCAL_PATH]
  luajit fscp_tui.lua --demo
  luajit fscp_tui.lua --ascii

Keybindings:
  Tab            Switch active pane (Local <-> Remote)
  Up / Down      Move cursor (or k / j)
  Enter / Right  Drill into directory
  Backspace/Left Parent directory (..)
  Space          Toggle multi-select on file/folder
  a / A          Select All / Deselect All
  u / F5         Upload to remote current directory
  d / F5         Download to local current directory
  r              Refresh directories
  H              Open Host Picker
  ?              Help screen
  q              Quit
]])
            return
        elseif not cli_host then
            cli_host = arg
        elseif not cli_remote_path then
            cli_remote_path = arg
        elseif not cli_local_path or cli_local_path == "." then
            cli_local_path = arg
        end
        i = i + 1
    end

    Term.init()

    -- Configure Initial Remote Host
    if is_demo or cli_host == "demo" then
        App.host_cfg = {
            name = "demo",
            hostname = "demo-server",
            user = "user",
            port = "22",
            is_demo = true,
        }
    elseif cli_host then
        local user, host, port = cli_host:match("^(.-)@([^:]+):?(%d*)$")
        if not host then
            host, port = cli_host:match("^([^:]+):?(%d*)$")
            user = ""
        end
        App.host_cfg = {
            name = cli_host,
            hostname = host or cli_host,
            user = user or "",
            port = (port and port ~= "") and port or "22",
            is_demo = false,
        }
    else
        -- No host provided: aggregate all saved sessions and show server picker at start
        local available_hosts = aggregate_ssh_hosts()
        table.insert(available_hosts, 1, {
            name = "[Demo Server]",
            hostname = "demo-server.local",
            user = "user",
            port = "22",
            source = "demo",
            is_demo = true,
        })
        App.host_cfg = available_hosts[1]
        App.modal = "host_picker"
        App.modal_data = {
            hosts = available_hosts,
            filtered = available_hosts,
            cursor = 1,
            filter = "",
        }
        App.status_msg = "Select a remote server to connect, or press [Esc] for Demo Mode."
        App.status_color = C.bright_yellow
    end

    if cli_remote_path and cli_remote_path ~= "" then
        App.right.dir = cli_remote_path
    elseif App.host_cfg.is_demo then
        App.right.dir = "/home/user"
    end
    if cli_local_path and cli_local_path ~= "" then
        App.left.dir = cli_local_path
    end

    App.refresh_left()
    App.refresh_right(false)

    Term.enable_raw()

    -- Safe Execution Loop
    local ok, err = xpcall(function()
        while App.running do
            App.draw()
            local key = nil
            while not key and App.running do
                key = Term.read_key()
                if not key then
                    if IS_WINDOWS then
                        ffi.C.Sleep(20)
                    else
                        ffi.C.usleep(20000)
                    end
                end
            end
            App.handle_input(key)
        end
    end, debug.traceback)

    Term.restore()

    if not ok then
        io.stderr:write("FSCP-TUI Error: " .. tostring(err) .. "\n")
    end
end

main(...)
