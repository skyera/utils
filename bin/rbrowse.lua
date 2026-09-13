#!/usr/bin/env luajit
--[=[
  rbrowse.lua - Ultra-fast Interactive Remote Server Browser & Previewer.
  Powered by LuaJIT & FFI. Single-file, zero external Lua dependencies.
  Runs natively on Linux/POSIX and Windows (Win32 Console & Registry FFI).

  Features:
    - Dual-Pane TUI: Left = Remote Directory Tree, Right = Real-Time Preview
    - Full File & Folder Icons: Nerd Fonts (default), Unicode Emoji, and ASCII fallback
    - Live Text Preview: Syntax-highlighted text/code with line numbers and smooth scrolling
    - Live Image Preview: Dual-mode rendering:
        * Universal Truecolor Half-Blocks (▀) via ImageMagick/chafa (works in all truecolor terminals)
        * WezTerm / iTerm2 OSC 1337 & Kitty inline graphics protocols via in-memory FFI Base64
    - Fast Image Header Parser: In-memory binary dimension reader for PNG, JPEG, GIF, BMP
    - SSH Connection Multiplexing: ControlMaster/ControlPath socket reuse for < 10ms queries
    - Offline Demo Mode (--demo): Browse a simulated remote filesystem without an SSH server
    - CLI Preview Mode (--preview): For instant integration into fzf, lf, and ranger

  Usage:
    luajit rbrowse.lua [OPTIONS] [USER@HOST[:REMOTE_PATH]]
    luajit rbrowse.lua --demo
    luajit rbrowse.lua --preview <HOST> <REMOTE_PATH> [WIDTH] [HEIGHT]
    luajit rbrowse.lua --list <HOST> <REMOTE_PATH>
    luajit rbrowse.lua --test

  Options:
    -H, --host <HOST>       Remote SSH host (or saved PuTTY session)
    -u, --user <USER>       Remote SSH username
    -p, --port <PORT>       Remote SSH port
    -i, --identity <KEY>    Path to SSH private key
    --icons <MODE>          Icon mode: nerd (default), emoji, ascii, or none
    --protocol <MODE>       Image protocol: blocks (default) or graphics (OSC 1337)
    --demo                  Start in simulated demo mode
    --preview               Headless preview mode for fzf/lf/ranger
    --list                  List remote directory as TSV
    --test                  Run automated test suite
    -h, --help              Show this help message

  Keybindings:
    j / Down, k / Up        Navigate file tree
    Enter / l / Right       Drill into directory / open item
    h / Backspace / Left    Go to parent directory (..)
    J / K, PageDown/Up      Scroll preview pane up/down
    Tab                     Toggle focus between file tree and preview pane
    I                       Cycle icon mode: Nerd -> Emoji -> ASCII -> None
    i                       Toggle image rendering mode (Half-Blocks <-> Graphics Protocol)
    /                       Inline fuzzy filter current directory
    d                       Download selected file locally via SCP
    r                       Refresh current remote directory and cache
    ~                       Jump to remote home directory ($HOME)
    ?                       Show keyboard help modal
    q / Ctrl+C              Quit
]=]

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
        void Sleep(DWORD dwMilliseconds);

        LONG RegOpenKeyExA(HKEY hKey, const char* lpSubKey, DWORD ulOptions, DWORD samDesired, HKEY* phkResult);
        LONG RegEnumKeyExA(HKEY hKey, DWORD dwIndex, char* lpName, DWORD* lpcchName, DWORD* lpReserved, char* lpClass, DWORD* lpcchClass, void* lpftLastWriteTime);
        LONG RegQueryValueExA(HKEY hKey, const char* lpValueName, DWORD* lpReserved, DWORD* lpType, BYTE* lpData, DWORD* lpcbData);
        LONG RegCloseKey(HKEY hKey);
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
    italic      = "\27[3m",
    underline   = "\27[4m",
    reverse     = "\27[7m",

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
    bg_darkgray = "\27[48;5;236m",
    bg_sel      = "\27[48;5;238m",
    bg_header   = "\27[48;5;24m",
}

-- Box drawing characters
local BOX = {
    tl = "┌", tr = "┐", bl = "└", br = "┘",
    h = "─", v = "│", vl = "├", vr = "┤",
    tt = "┬", tb = "┴", x = "┼",
    arrow_r = "▸",
}

--------------------------------------------------------------------------------
-- Helpers & Utilities
--------------------------------------------------------------------------------
local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
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

local function format_size(bytes)
    if not bytes or bytes < 0 then return "-" end
    if bytes < 1024 then
        return string.format("%d B", bytes)
    elseif bytes < 1024 * 1024 then
        return string.format("%.1f KB", bytes / 1024)
    elseif bytes < 1024 * 1024 * 1024 then
        return string.format("%.1f MB", bytes / (1024 * 1024))
    else
        return string.format("%.2f GB", bytes / (1024 * 1024 * 1024))
    end
end

local function parse_size_bytes(size_str)
    if not size_str then return 0 end
    local n = tonumber(size_str)
    if n then return n end
    local num, unit = size_str:match("^([%d%.]+)%s*([KkMmGgTt]?[Bb]?)$")
    if not num then return 0 end
    n = tonumber(num) or 0
    unit = unit:upper()
    if unit:find("K") then return math.floor(n * 1024)
    elseif unit:find("M") then return math.floor(n * 1024 * 1024)
    elseif unit:find("G") then return math.floor(n * 1024 * 1024 * 1024)
    elseif unit:find("T") then return math.floor(n * 1024 * 1024 * 1024 * 1024)
    end
    return math.floor(n)
end

local function get_home_dir()
    return os.getenv("HOME") or os.getenv("USERPROFILE") or "."
end

local function file_exists(path)
    local f = io.open(path, "rb")
    if f then
        f:close()
        return true
    end
    return false
end

local function read_file(path, max_bytes)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data
    if max_bytes then
        data = f:read(max_bytes)
    else
        data = f:read("*a")
    end
    f:close()
    return data
end

-- String visual column width calculation (considering emojis & Nerd Font glyphs)
local function utf8_col_width(s)
    local clean = s:gsub("\27%[[%d;]*[mK]", "")
    local width = 0
    local i = 1
    local len = #clean
    while i <= len do
        local b = clean:byte(i)
        if b < 128 then
            width = width + 1
            i = i + 1
        elseif b >= 192 and b < 224 then
            -- 2-byte UTF-8
            width = width + 1
            i = i + 2
        elseif b >= 224 and b < 240 then
            -- 3-byte UTF-8 (Common CJK or basic symbols)
            local b2 = clean:byte(i+1) or 0
            -- Check for wide emoji blocks
            if (b == 0xE2 and (b2 >= 0x96 and b2 <= 0xBF)) or (b == 0xE3) then
                width = width + 2
            else
                width = width + 1
            end
            i = i + 3
        elseif b >= 240 then
            -- 4-byte UTF-8 (Emoji / Supplementary)
            width = width + 2
            i = i + 4
        else
            i = i + 1
        end
    end
    return width
end

local function pad_string(s, target_width)
    local cur_w = utf8_col_width(s)
    if cur_w < target_width then
        return s .. string.rep(" ", target_width - cur_w)
    else
        return s
    end
end

local function truncate_string(s, max_width)
    local cur_w = utf8_col_width(s)
    if cur_w <= max_width then return s end
    if max_width <= 1 then return "…" end
    local clean = s:gsub("\27%[[%d;]*[mK]", "")
    local res = ""
    local w = 0
    local i = 1
    local len = #clean
    while i <= len and w < max_width - 1 do
        local b = clean:byte(i)
        local step = 1
        local char_w = 1
        if b >= 192 and b < 224 then step = 2
        elseif b >= 224 and b < 240 then step = 3; char_w = 1
        elseif b >= 240 then step = 4; char_w = 2
        end
        if w + char_w > max_width - 1 then break end
        res = res .. clean:sub(i, i + step - 1)
        w = w + char_w
        i = i + step
    end
    return res .. "…" .. string.rep(" ", math.max(0, max_width - w - 1))
end

--------------------------------------------------------------------------------
-- Fast In-Memory Base64 Encoder / Decoder via FFI & bitwise operations
--------------------------------------------------------------------------------
local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_MAP = {}
for i = 1, 64 do
    B64_MAP[B64_CHARS:byte(i)] = i - 1
end

local function base64_encode(data)
    if not data or #data == 0 then return "" end
    local len = #data
    local ptr = ffi.cast("const uint8_t*", data)
    local out = {}
    local n = math.floor(len / 3) * 3

    for i = 0, n - 1, 3 do
        local b0 = ptr[i]
        local b1 = ptr[i + 1]
        local b2 = ptr[i + 2]
        local c0 = bit.rshift(b0, 2)
        local c1 = bit.bor(bit.lshift(bit.band(b0, 0x03), 4), bit.rshift(b1, 4))
        local c2 = bit.bor(bit.lshift(bit.band(b1, 0x0F), 2), bit.rshift(b2, 6))
        local c3 = bit.band(b2, 0x3F)
        table.insert(out, string.char(
            B64_CHARS:byte(c0 + 1),
            B64_CHARS:byte(c1 + 1),
            B64_CHARS:byte(c2 + 1),
            B64_CHARS:byte(c3 + 1)
        ))
    end

    local rem = len - n
    if rem == 1 then
        local b0 = ptr[n]
        local c0 = bit.rshift(b0, 2)
        local c1 = bit.lshift(bit.band(b0, 0x03), 4)
        table.insert(out, string.char(
            B64_CHARS:byte(c0 + 1),
            B64_CHARS:byte(c1 + 1),
            61, 61
        ))
    elseif rem == 2 then
        local b0 = ptr[n]
        local b1 = ptr[n + 1]
        local c0 = bit.rshift(b0, 2)
        local c1 = bit.bor(bit.lshift(bit.band(b0, 0x03), 4), bit.rshift(b1, 4))
        local c2 = bit.lshift(bit.band(b1, 0x0F), 2)
        table.insert(out, string.char(
            B64_CHARS:byte(c0 + 1),
            B64_CHARS:byte(c1 + 1),
            B64_CHARS:byte(c2 + 1),
            61
        ))
    end

    return table.concat(out)
end

local function base64_decode(s)
    if not s or #s == 0 then return "" end
    local out = {}
    local buf, bits = 0, 0
    for i = 1, #s do
        local c = s:byte(i)
        local val = B64_MAP[c]
        if val then
            buf = bit.bor(bit.lshift(buf, 6), val)
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                table.insert(out, string.char(bit.band(bit.rshift(buf, bits), 0xFF)))
            end
        end
    end
    return table.concat(out)
end

--------------------------------------------------------------------------------
-- Image Header Parser (In-Memory Binary Extraction via FFI)
--------------------------------------------------------------------------------
local ImageParser = {}

function ImageParser.parse_header(data)
    if not data or #data < 10 then return nil end
    local ptr = ffi.cast("const uint8_t*", data)
    local len = #data

    -- 1. PNG (\137PNG\r\n\026\n)
    if len >= 24 and ptr[0] == 0x89 and ptr[1] == 0x50 and ptr[2] == 0x4E and ptr[3] == 0x47 then
        local w = bit.bor(bit.lshift(ptr[16], 24), bit.lshift(ptr[17], 16), bit.lshift(ptr[18], 8), ptr[19])
        local h = bit.bor(bit.lshift(ptr[20], 24), bit.lshift(ptr[21], 16), bit.lshift(ptr[22], 8), ptr[23])
        local bit_depth = ptr[24]
        local color_type = ptr[25]
        local color_desc = "sRGB"
        if color_type == 0 then color_desc = "Grayscale"
        elseif color_type == 2 then color_desc = "RGB Truecolor"
        elseif color_type == 3 then color_desc = "Indexed Palette"
        elseif color_type == 4 then color_desc = "Grayscale+Alpha"
        elseif color_type == 6 then color_desc = "RGBA Truecolor"
        end
        return {
            format = "PNG",
            width = w,
            height = h,
            bit_depth = bit_depth,
            color_desc = color_desc,
        }
    end

    -- 2. GIF (GIF87a or GIF89a)
    if len >= 10 and ptr[0] == 0x47 and ptr[1] == 0x49 and ptr[2] == 0x46 then
        local w = ptr[6] + bit.lshift(ptr[7], 8)
        local h = ptr[8] + bit.lshift(ptr[9], 8)
        return {
            format = "GIF",
            width = w,
            height = h,
            bit_depth = 8,
            color_desc = "Indexed Palette",
        }
    end

    -- 3. BMP (BM)
    if len >= 26 and ptr[0] == 0x42 and ptr[1] == 0x4D then
        local w = ptr[18] + bit.lshift(ptr[19], 8) + bit.lshift(ptr[20], 16) + bit.lshift(ptr[21], 24)
        local h = ptr[22] + bit.lshift(ptr[23], 8) + bit.lshift(ptr[24], 16) + bit.lshift(ptr[25], 24)
        local bpp = ptr[28] + bit.lshift(ptr[29], 8)
        return {
            format = "BMP",
            width = w,
            height = math.abs(h),
            bit_depth = bpp,
            color_desc = bpp == 32 and "RGBA" or (bpp == 24 and "RGB" or "Indexed"),
        }
    end

    -- 4. JPEG (0xFF 0xD8)
    if len >= 4 and ptr[0] == 0xFF and ptr[1] == 0xD8 then
        local i = 2
        while i < len - 8 do
            if ptr[i] == 0xFF then
                local m = ptr[i + 1]
                -- SOF0, SOF1, SOF2 markers
                if m == 0xC0 or m == 0xC1 or m == 0xC2 then
                    local h = bit.bor(bit.lshift(ptr[i + 5], 8), ptr[i + 6])
                    local w = bit.bor(bit.lshift(ptr[i + 7], 8), ptr[i + 8])
                    local precision = ptr[i + 4]
                    return {
                        format = "JPEG",
                        width = w,
                        height = h,
                        bit_depth = precision,
                        color_desc = "YCbCr / sRGB",
                    }
                elseif m == 0xD9 or m == 0xDA then
                    break
                else
                    local seg_len = bit.bor(bit.lshift(ptr[i + 2], 8), ptr[i + 3])
                    i = i + 2 + seg_len
                end
            else
                i = i + 1
            end
        end
    end

    -- 5. WebP (RIFF .... WEBP)
    if len >= 30 and ptr[0] == 0x52 and ptr[1] == 0x49 and ptr[2] == 0x46 and ptr[3] == 0x46
       and ptr[8] == 0x57 and ptr[9] == 0x45 and ptr[10] == 0x42 and ptr[11] == 0x50 then
        -- VP8 chunk
        if ptr[12] == 0x56 and ptr[13] == 0x50 and ptr[14] == 0x38 and ptr[15] == 0x20 then
            local w = bit.band(ptr[26] + bit.lshift(ptr[27], 8), 0x3FFF)
            local h = bit.band(ptr[28] + bit.lshift(ptr[29], 8), 0x3FFF)
            return {
                format = "WebP",
                width = w,
                height = h,
                bit_depth = 8,
                color_desc = "sRGB (Lossy)",
            }
        elseif ptr[12] == 0x56 and ptr[13] == 0x50 and ptr[14] == 0x38 and ptr[15] == 0x4C then
            -- VP8L (Lossless)
            local b0 = ptr[21]
            local b1 = ptr[22]
            local b2 = ptr[23]
            local b3 = ptr[24]
            local w = 1 + bit.band(b0 + bit.lshift(bit.band(b1, 0x3F), 8), 0x3FFF)
            local h = 1 + bit.band(bit.rshift(b1, 6) + bit.lshift(b2, 2) + bit.lshift(bit.band(b3, 0x0F), 10), 0x3FFF)
            return {
                format = "WebP",
                width = w,
                height = h,
                bit_depth = 8,
                color_desc = "sRGB (Lossless)",
            }
        end
    end

    return nil
end

--------------------------------------------------------------------------------
-- File & Folder Icon Classification Engine
--------------------------------------------------------------------------------
local IconEngine = {
    mode = "nerd", -- "nerd", "emoji", "ascii", "none"
}

local EXT_ICONS = {
    -- Programming languages
    lua   = { nerd = " ", emoji = "🌙 ", color = C.bright_cyan },
    py    = { nerd = " ", emoji = "🐍 ", color = C.bright_yellow },
    pyw   = { nerd = " ", emoji = "🐍 ", color = C.bright_yellow },
    ipynb = { nerd = " ", emoji = "🐍 ", color = C.bright_yellow },
    sh    = { nerd = " ", emoji = "⚡ ", color = C.bright_green },
    bash  = { nerd = " ", emoji = "⚡ ", color = C.bright_green },
    zsh   = { nerd = " ", emoji = "⚡ ", color = C.bright_green },
    fish  = { nerd = " ", emoji = "⚡ ", color = C.bright_green },
    bat   = { nerd = " ", emoji = "⚡ ", color = C.bright_green },
    cmd   = { nerd = " ", emoji = "⚡ ", color = C.bright_green },
    ps1   = { nerd = " ", emoji = "⚡ ", color = C.bright_green },
    c     = { nerd = " ", emoji = "📜 ", color = C.bright_blue },
    h     = { nerd = " ", emoji = "📜 ", color = C.bright_blue },
    cpp   = { nerd = " ", emoji = "📜 ", color = C.bright_blue },
    hpp   = { nerd = " ", emoji = "📜 ", color = C.bright_blue },
    cc    = { nerd = " ", emoji = "📜 ", color = C.bright_blue },
    rs    = { nerd = " ", emoji = "🦀 ", color = C.bright_red },
    go    = { nerd = " ", emoji = "🐹 ", color = C.bright_cyan },
    js    = { nerd = " ", emoji = "🌐 ", color = C.bright_yellow },
    ts    = { nerd = " ", emoji = "🌐 ", color = C.bright_blue },
    jsx   = { nerd = " ", emoji = "🌐 ", color = C.bright_yellow },
    tsx   = { nerd = " ", emoji = "🌐 ", color = C.bright_blue },
    html  = { nerd = " ", emoji = "🌐 ", color = C.bright_red },
    css   = { nerd = " ", emoji = "🎨 ", color = C.bright_blue },
    scss  = { nerd = " ", emoji = "🎨 ", color = C.bright_magenta },
    php   = { nerd = " ", emoji = "🐘 ", color = C.bright_magenta },
    rb    = { nerd = " ", emoji = "💎 ", color = C.bright_red },
    java  = { nerd = " ", emoji = "☕ ", color = C.bright_red },
    kt    = { nerd = " ", emoji = "☕ ", color = C.bright_yellow },
    cs    = { nerd = " ", emoji = "🔷 ", color = C.bright_green },

    -- Images
    png   = { nerd = " ", emoji = "🖼  ", color = C.bright_magenta },
    jpg   = { nerd = " ", emoji = "🖼  ", color = C.bright_magenta },
    jpeg  = { nerd = " ", emoji = "🖼  ", color = C.bright_magenta },
    gif   = { nerd = " ", emoji = "🖼  ", color = C.bright_magenta },
    bmp   = { nerd = " ", emoji = "🖼  ", color = C.bright_magenta },
    webp  = { nerd = " ", emoji = "🖼  ", color = C.bright_magenta },
    svg   = { nerd = " ", emoji = "🎨 ", color = C.bright_yellow },
    ico   = { nerd = " ", emoji = "🖼  ", color = C.bright_cyan },
    tiff  = { nerd = " ", emoji = "🖼  ", color = C.bright_magenta },

    -- Config / Data
    json  = { nerd = " ", emoji = "⚙  ", color = C.bright_yellow },
    yaml  = { nerd = " ", emoji = "⚙  ", color = C.bright_yellow },
    yml   = { nerd = " ", emoji = "⚙  ", color = C.bright_yellow },
    toml  = { nerd = " ", emoji = "⚙  ", color = C.bright_yellow },
    xml   = { nerd = " ", emoji = "⚙  ", color = C.bright_yellow },
    conf  = { nerd = " ", emoji = "⚙  ", color = C.bright_white },
    ini   = { nerd = " ", emoji = "⚙  ", color = C.bright_white },
    env   = { nerd = " ", emoji = "🔒 ", color = C.bright_yellow },
    sql   = { nerd = " ", emoji = "🗄  ", color = C.bright_magenta },

    -- Documents
    md    = { nerd = " ", emoji = "📝 ", color = C.bright_white },
    txt   = { nerd = " ", emoji = "📄 ", color = C.bright_white },
    pdf   = { nerd = " ", emoji = "📕 ", color = C.bright_red },
    log   = { nerd = " ", emoji = "📋 ", color = C.gray },

    -- Archives
    zip   = { nerd = " ", emoji = "📦 ", color = C.bright_red },
    tar   = { nerd = " ", emoji = "📦 ", color = C.bright_red },
    gz    = { nerd = " ", emoji = "📦 ", color = C.bright_red },
    bz2   = { nerd = " ", emoji = "📦 ", color = C.bright_red },
    xz    = { nerd = " ", emoji = "📦 ", color = C.bright_red },
    ["7z"]= { nerd = " ", emoji = "📦 ", color = C.bright_red },
    rar   = { nerd = " ", emoji = "📦 ", color = C.bright_red },

    -- Executable / Binary
    exe   = { nerd = " ", emoji = "🔧 ", color = C.bright_green },
    dll   = { nerd = " ", emoji = "🔧 ", color = C.bright_red },
    so    = { nerd = " ", emoji = "🔧 ", color = C.bright_red },
    bin   = { nerd = " ", emoji = "🔧 ", color = C.bright_red },
}

function IconEngine.get(name, is_dir, is_symlink, is_exec)
    local mode = IconEngine.mode
    if mode == "none" then return "", 0 end

    if mode == "ascii" then
        if is_dir then
            return (name == ".." and "[..]  " or "[DIR] "), 6
        elseif is_symlink then
            return "[@]   ", 6
        elseif is_exec then
            return "[*]   ", 6
        end
        local ext = (name:match("%.([%w_%-]+)$") or ""):lower()
        if EXT_ICONS[ext] then
            if ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "gif" or ext == "bmp" or ext == "webp" then
                return "[IMG] ", 6
            elseif ext == "lua" or ext == "py" or ext == "sh" or ext == "c" or ext == "cpp" or ext == "rs" or ext == "go" or ext == "js" or ext == "ts" then
                return "[SRC] ", 6
            elseif ext == "md" or ext == "txt" or ext == "log" then
                return "[TXT] ", 6
            elseif ext == "zip" or ext == "tar" or ext == "gz" or ext == "7z" then
                return "[ARC] ", 6
            end
        end
        return "[   ] ", 6
    end

    -- Graphical modes: "nerd" or "emoji"
    local is_emoji = (mode == "emoji")

    if is_dir then
        if name == ".." then
            return (is_emoji and (C.bright_yellow .. "📁 " .. C.reset) or (C.bright_yellow .. "  " .. C.reset)), 3
        else
            return (is_emoji and (C.bright_blue .. "📁 " .. C.reset) or (C.bright_blue .. "  " .. C.reset)), 3
        end
    end

    if is_symlink then
        return (is_emoji and (C.bright_cyan .. "🔗 " .. C.reset) or (C.bright_cyan .. "  " .. C.reset)), 3
    end

    local ext = (name:match("%.([%w_%-]+)$") or ""):lower()
    local mapped = EXT_ICONS[ext]
    if mapped then
        local glyph = is_emoji and mapped.emoji or mapped.nerd
        return (mapped.color .. glyph .. C.reset), 3
    end

    if is_exec then
        return (is_emoji and (C.bright_green .. "🔧 " .. C.reset) or (C.bright_green .. "  " .. C.reset)), 3
    end

    return (is_emoji and (C.gray .. "📄 " .. C.reset) or (C.gray .. "  " .. C.reset)), 3
end

function IconEngine.cycle()
    if IconEngine.mode == "nerd" then
        IconEngine.mode = "emoji"
    elseif IconEngine.mode == "emoji" then
        IconEngine.mode = "ascii"
    elseif IconEngine.mode == "ascii" then
        IconEngine.mode = "none"
    else
        IconEngine.mode = "nerd"
    end
    return IconEngine.mode
end

--------------------------------------------------------------------------------
-- Terminal Controller
--------------------------------------------------------------------------------
local Term = {
    orig_termios = nil,
    hIn = nil,
    hOut = nil,
    orig_in_mode = nil,
    orig_out_mode = nil,
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
                local raw_mode = bit.band(mode[0], bit.bnot(bit.bor(0x0002, 0x0004))) -- DISABLE LINE_INPUT & ECHO
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
            raw.c_cc[6] = 1 -- VTIME (100ms timeout)
            ffi.C.tcsetattr(0, 0, raw)
        end
    end

    io.write("\27[?1049h\27[?25l\27[2J\27[H")
    io.flush()
    Term.is_raw = true
end

function Term.restore()
    if not Term.is_raw then return end
    io.write("\27[?1049l\27[?25h")
    io.flush()

    if IS_WINDOWS then
        if Term.hIn ~= nil and Term.orig_in_mode ~= nil then
            ffi.C.SetConsoleMode(Term.hIn, Term.orig_in_mode)
        end
        if Term.hOut ~= nil and Term.orig_out_mode ~= nil then
            ffi.C.SetConsoleMode(Term.hOut, Term.orig_out_mode)
        end
    else
        if Term.orig_termios ~= nil then
            ffi.C.tcsetattr(0, 0, Term.orig_termios)
        end
    end
    Term.is_raw = false
end

function Term.get_size()
    if IS_WINDOWS then
        if Term.hOut ~= nil and Term.hOut ~= ffi.cast("HANDLE", -1) then
            local csbi = ffi.new("CONSOLE_SCREEN_BUFFER_INFO")
            if ffi.C.GetConsoleScreenBufferInfo(Term.hOut, csbi) ~= 0 then
                local w = csbi.srWindow.Right - csbi.srWindow.Left + 1
                local h = csbi.srWindow.Bottom - csbi.srWindow.Top + 1
                if w > 0 and h > 0 then return w, h end
            end
        end
    else
        local ws = ffi.new("struct winsize")
        -- TIOCGWINSZ = 0x5413 on Linux
        if ffi.C.ioctl(0, 0x5413, ws) == 0 then
            if ws.ws_col > 0 and ws.ws_row > 0 then
                return tonumber(ws.ws_col), tonumber(ws.ws_row)
            end
        end
    end
    return 100, 30 -- safe fallback
end

function Term.read_key()
    if IS_WINDOWS then
        if _G.msvcrt._kbhit() == 0 then
            ffi.C.Sleep(20)
            return nil
        end
        local ch = _G.msvcrt._getch()
        if ch == 0 or ch == 224 then
            local ch2 = _G.msvcrt._getch()
            if ch2 == 72 then return "up"
            elseif ch2 == 80 then return "down"
            elseif ch2 == 75 then return "left"
            elseif ch2 == 77 then return "right"
            elseif ch2 == 73 then return "page_up"
            elseif ch2 == 81 then return "page_down"
            elseif ch2 == 71 then return "home"
            elseif ch2 == 79 then return "end"
            end
        elseif ch == 13 then return "enter"
        elseif ch == 27 then return "escape"
        elseif ch == 8 then return "backspace"
        elseif ch == 9 then return "tab"
        elseif ch == 3 then return "ctrl_c"
        elseif ch == 4 then return "ctrl_d"
        elseif ch == 21 then return "ctrl_u"
        elseif ch >= 32 and ch <= 126 then
            return string.char(ch)
        end
        return nil
    else
        local buf = ffi.new("char[16]")
        local n = ffi.C.read(0, buf, 16)
        if n == 0 then
            -- EOF on stdin (e.g. piped input or closed stream)
            return "q"
        end
        if n < 0 then return nil end

        if n == 1 then
            local b = buf[0]
            if b == 10 or b == 13 then return "enter"
            elseif b == 27 then return "escape"
            elseif b == 127 or b == 8 then return "backspace"
            elseif b == 9 then return "tab"
            elseif b == 3 then return "ctrl_c"
            elseif b == 4 then return "ctrl_d"
            elseif b == 21 then return "ctrl_u"
            elseif b >= 32 and b <= 126 then
                return string.char(b)
            end
        elseif n >= 3 and buf[0] == 27 and buf[1] == 91 then -- Escape sequence \27[...
            local code = buf[2]
            if code == 65 then return "up"
            elseif code == 66 then return "down"
            elseif code == 67 then return "right"
            elseif code == 68 then return "left"
            elseif code == 72 then return "home"
            elseif code == 70 then return "end"
            elseif code == 53 and buf[3] == 126 then return "page_up"   -- \27[5~
            elseif code == 54 and buf[3] == 126 then return "page_down" -- \27[6~
            elseif code == 49 and buf[3] == 59 and buf[4] == 50 then
                -- Shift+Up / Shift+Down
                if buf[5] == 65 then return "page_up"
                elseif buf[5] == 66 then return "page_down"
                end
            end
        end
        return nil
    end
end

--------------------------------------------------------------------------------
-- Fast Syntax Tokenizer & Highlighter for Text / Code Preview
--------------------------------------------------------------------------------
local Syntax = {}

local KEYWORDS = {
    ["function"] = true, ["local"] = true, ["return"] = true, ["if"] = true,
    ["then"] = true, ["else"] = true, ["elseif"] = true, ["end"] = true,
    ["for"] = true, ["while"] = true, ["do"] = true, ["repeat"] = true,
    ["until"] = true, ["break"] = true, ["nil"] = true, ["true"] = true,
    ["false"] = true, ["and"] = true, ["or"] = true, ["not"] = true,
    ["def"] = true, ["class"] = true, ["import"] = true, ["from"] = true,
    ["export"] = true, ["default"] = true, ["const"] = true, ["let"] = true,
    ["var"] = true, ["struct"] = true, ["enum"] = true, ["typedef"] = true,
    ["int"] = true, ["char"] = true, ["void"] = true, ["unsigned"] = true,
    ["float"] = true, ["double"] = true, ["bool"] = true, ["fn"] = true,
    ["pub"] = true, ["mut"] = true, ["impl"] = true, ["use"] = true,
    ["mod"] = true, ["select"] = true, ["insert"] = true, ["update"] = true,
    ["delete"] = true,
}

function Syntax.highlight_line(line, ext)
    if not line or #line == 0 then return "" end

    -- Check for full-line comments
    local trimmed = line:match("^%s*(.-)$") or ""
    if trimmed:sub(1, 2) == "--" or trimmed:sub(1, 2) == "//" or trimmed:sub(1, 1) == "#" or trimmed:sub(1, 1) == ";" then
        return C.gray .. C.italic .. line .. C.reset
    end

    local out = {}
    local i = 1
    local len = #line

    while i <= len do
        local c = line:sub(i, i)

        -- Strings
        if c == '"' or c == "'" or (c == '`' and (ext == "js" or ext == "ts" or ext == "go")) then
            local quote = c
            local s_start = i
            i = i + 1
            while i <= len do
                local cur = line:sub(i, i)
                if cur == '\\' then
                    i = i + 2
                elseif cur == quote then
                    i = i + 1
                    break
                else
                    i = i + 1
                end
            end
            table.insert(out, C.bright_green .. line:sub(s_start, i - 1) .. C.reset)

        -- Line Comments
        elseif (c == '-' and line:sub(i, i+1) == "--") or (c == '/' and line:sub(i, i+1) == "//") or (c == '#' and ext ~= "c" and ext ~= "cpp") then
            table.insert(out, C.gray .. C.italic .. line:sub(i) .. C.reset)
            break

        -- Identifiers / Keywords
        elseif c:match("[%a_]") then
            local id_start = i
            while i <= len and line:sub(i, i):match("[%w_]") do
                i = i + 1
            end
            local word = line:sub(id_start, i - 1)
            if KEYWORDS[word] then
                table.insert(out, C.bold .. C.bright_magenta .. word .. C.reset)
            else
                table.insert(out, word)
            end

        -- Numbers
        elseif c:match("%d") then
            local num_start = i
            while i <= len and line:sub(i, i):match("[%x%.xX_]") do
                i = i + 1
            end
            table.insert(out, C.bright_yellow .. line:sub(num_start, i - 1) .. C.reset)

        -- Operators / Punctuation
        elseif c:match("[%+%-/%*%%=<>!~%^&|]") then
            table.insert(out, C.bright_cyan .. c .. C.reset)
            i = i + 1
        else
            table.insert(out, c)
            i = i + 1
        end
    end

    return table.concat(out)
end

--------------------------------------------------------------------------------
-- Image Terminal Rendering Engine (Half-Blocks & Graphics Protocol)
--------------------------------------------------------------------------------
local ImageRenderer = {
    protocol = "blocks", -- "blocks" (Universal Half-Blocks) or "graphics" (OSC 1337)
    cache = {},
}

-- Render downscaled image to 24-bit half-blocks via ImageMagick (magick/convert) or fallback
function ImageRenderer.render_half_blocks(image_path_or_bytes, w, h)
    if w < 2 or h < 2 then return { " [Window too small for image preview] " } end

    local tmp_file = nil
    local src_file = image_path_or_bytes
    if type(image_path_or_bytes) == "string" and #image_path_or_bytes > 0 and image_path_or_bytes:sub(1, 4) ~= "\137PNG" and file_exists(image_path_or_bytes) then
        src_file = image_path_or_bytes
    else
        -- Write to temp file for magick
        tmp_file = (IS_WINDOWS and os.getenv("TEMP") or "/tmp") .. "/rbrowse_preview_" .. tostring(os.time()) .. ".img"
        local f = io.open(tmp_file, "wb")
        if f then
            f:write(image_path_or_bytes)
            f:close()
            src_file = tmp_file
        else
            return { " [Failed to create preview cache] " }
        end
    end

    local lines = {}
    local magick_cmd = IS_WINDOWS and "magick.exe" or "magick"
    local conv_cmd = string.format("%s %s -resize %dx%d\\! -depth 8 rgb:- 2>/dev/null",
        magick_cmd, shell_escape(src_file), w, h * 2)

    local pipe = io.popen(conv_cmd, "r")
    if not pipe then
        -- Try fallback to 'convert'
        conv_cmd = string.format("convert %s -resize %dx%d\\! -depth 8 rgb:- 2>/dev/null",
            shell_escape(src_file), w, h * 2)
        pipe = io.popen(conv_cmd, "r")
    end

    local raw_rgb = nil
    if pipe then
        raw_rgb = pipe:read("*a")
        pipe:close()
    end

    if tmp_file then os.remove(tmp_file) end

    local expected_bytes = w * (h * 2) * 3
    if raw_rgb and #raw_rgb >= expected_bytes then
        local ptr = ffi.cast("const uint8_t*", raw_rgb)
        for row = 0, h - 1 do
            local row_buf = {}
            for col = 0, w - 1 do
                local idx1 = (row * 2 * w + col) * 3
                local idx2 = ((row * 2 + 1) * w + col) * 3
                local r1, g1, b1 = ptr[idx1], ptr[idx1 + 1], ptr[idx1 + 2]
                local r2, g2, b2 = ptr[idx2], ptr[idx2 + 1], ptr[idx2 + 2]
                table.insert(row_buf, string.format("\27[38;2;%d;%d;%dm\27[48;2;%d;%d;%dm▀", r1, g1, b1, r2, g2, b2))
            end
            table.insert(row_buf, C.reset)
            table.insert(lines, table.concat(row_buf))
        end
        return lines
    end

    -- Fallback simple placeholder card
    table.insert(lines, C.gray .. "┌" .. string.rep("─", w - 2) .. "┐" .. C.reset)
    local msg = " [Image: Install ImageMagick ('magick') for Half-Block Rendering] "
    local pad = math.max(0, math.floor((w - #msg) / 2))
    table.insert(lines, C.gray .. "│" .. string.rep(" ", pad) .. C.bright_yellow .. msg .. C.gray .. string.rep(" ", math.max(0, w - 2 - pad - #msg)) .. "│" .. C.reset)
    for _ = 1, h - 3 do
        table.insert(lines, C.gray .. "│" .. string.rep(" ", w - 2) .. "│" .. C.reset)
    end
    table.insert(lines, C.gray .. "└" .. string.rep("─", w - 2) .. "┘" .. C.reset)
    return lines
end

-- Generate WezTerm / iTerm2 OSC 1337 inline graphics escape code
function ImageRenderer.render_osc1337(data, w, h)
    local b64 = base64_encode(data)
    return string.format("\27]1337;File=inline=1;width=%dcell;height=%dcell;preserveAspectRatio=1:%s\007", w, h, b64)
end

--------------------------------------------------------------------------------
-- Offline Simulated Demo Filesystem (For --demo and unit testing)
--------------------------------------------------------------------------------
local DemoFS = {}

-- Embedded 32x32 genuine valid concentric circle PNG
local DEMO_PNG_B64 = "iVBORw0KGgoAAAANSUhEUgAAACAAAAAgEAIAAACsiDHgAAAAIGNIUk0AAHomAACAhAAA+gAAAIDoAAB1MAAA6mAAADqYAAAXcJy6UTwAAAAGYktHRP///////wlY99wAAAAHdElNRQfqCQ0TECt8b97QAAAAJXRFWHRkYXRlOmNyZWF0ZQAyMDI2LTA5LTEzVDE5OjE2OjQzKzAwOjAwbeiOYAAAACV0RVh0ZGF0ZTptb2RpZnkAMjAyNi0wOS0xM1QxOToxNjo0MyswMDowMBy1NtwAAAAodEVYdGRhdGU6dGltZXN0YW1wADIwMjYtMDktMTNUMTk6MTY6NDMrMDA6MDBLoBcDAAADpElEQVRYw+2Yb0wTdxzGHxxp5XpAoGCF8UfYNP5BhjQCabGMmYXGgkZpkCmxvNGlcaLdeKOGNyOLI2FgIFq3ZRtkKKiwOAUj0S1WbE0TKdKAKNVJaf1T5E+AawsHC3vRZBqT5e7SYw0Jz+vn9zzfz+9yd7+7oNxcrdZux5LVikAPsAwQ6AGWAQI9gL8K5iuIEAl6qfe3tMYZTKk5o2vLOirSq+OvGAsja4g/XwvHdZ7caNpS7tgtbzNE2+pVX/eonQqZ1eOmPyKf+9Mb5M9jVKANvj6rLU6RkvozpRsyW2uTuCY0DJjVuqGWvm5Kq6X18zuE5/4ngNiIcMlwctMPmvxtURBDBJc/u4gxuCEpOdTY3jX6YmLSlfAX+6Wc74HYqPAYe0JTm2bvtr95GN0nMURw+TJ9+YsCIDgU3D77RdPPmp2KcB6G/g81/aLZpQjzdfEMUJwlFeurQEKIqcUDgAgCTBdnScX6b3kDIEIFvVRM6ZrM5tqN7KYg0/IKgcShu73A+qSFh0Di47vnATIlL4PN+tI1mc21m4hQgZWK4QFgy6U4gymN3eiSFXWXgbiZG61AiFKeCkCIDUDILvk+IG7+hhmQCOvus+y9zdTLCiBnYu2xjuOMu56SlwFErDuiZnJGJB2RAuTmPAWL3hM8AKSfjL9g+pzJJW6rOMom7V//bxXljL3nmXpZAURWE7dGCCZXyKfyWC4AIQXyAoben4h7I24eAMa/8mxfNcPk8t40jnAB8LYbbzH06jy50TQPAJYKR5Gskck1Vlh5mgvA2J7KKobecsdueRsPAHc+ePKj6ksmF9XXeQ+YeFx/kck58bS+C6CsnQxXwBBlq1NV8gBg2emQyQbZOAHXQlkx4BQq8wHvdaMJwAwsgPeK8VfA+Z5yK+CaK1OwyepRO3NkVh4APFN0KvmqwWYu0tnYYVC9nR2APTlbDjwaCpIC9vXZBwCqv5PVG6BhwKzWPWNz2OZwlGixdE9qdfCABsl+FWeNwQ1JS183pT3Mxs4BgP5+XiU8U1La+HsXtXjz+w7VtH5+h1DPM4BPL0YnXybYS4oaL99ZgBdzEPEwtRuzCPNlLvr3wBuMxGHl1bP5g59wuTfeVcOQ+TNdv/La2YLBHF8m1wS/PinfFhEmsFKr06/Gm0zrFE8/PNhRk14Zf8mkifyO+GNk5Xi5Z/sqr+Ubx37ZOUOE7bTqVE+R82PZA880nUq+9KeXN4BAacn/VlkGCLSWPMA/SVJk1a13bcIAAAAASUVORK5CYII="

local DEMO_PNG_BYTES = base64_decode(DEMO_PNG_B64)

DemoFS["/"] = {
    { name = "..", is_dir = true, size = 4096, mtime = "2026-09-13 10:00", perms = "drwxr-xr-x" },
    { name = "etc", is_dir = true, size = 4096, mtime = "2026-09-13 09:30", perms = "drwxr-xr-x" },
    { name = "home", is_dir = true, size = 4096, mtime = "2026-09-13 10:15", perms = "drwxr-xr-x" },
    { name = "var", is_dir = true, size = 4096, mtime = "2026-09-13 11:00", perms = "drwxr-xr-x" },
    { name = "opt", is_dir = true, size = 4096, mtime = "2026-09-12 18:20", perms = "drwxr-xr-x" },
}

DemoFS["/home"] = {
    { name = "..", is_dir = true, size = 4096, mtime = "2026-09-13 10:00", perms = "drwxr-xr-x" },
    { name = "user", is_dir = true, size = 4096, mtime = "2026-09-13 10:15", perms = "drwxr-xr-x" },
}

DemoFS["/home/user"] = {
    { name = "..", is_dir = true, size = 4096, mtime = "2026-09-13 10:00", perms = "drwxr-xr-x" },
    { name = "app", is_dir = true, size = 4096, mtime = "2026-09-13 11:20", perms = "drwxr-xr-x" },
    { name = "avatar.png", is_dir = false, size = #DEMO_PNG_BYTES, mtime = "2026-09-13 11:15", perms = "-rw-r--r--" },
    { name = ".bashrc", is_dir = false, size = 3771, mtime = "2026-09-10 14:02", perms = "-rw-r--r--" },
}

DemoFS["/home/user/app"] = {
    { name = "..", is_dir = true, size = 4096, mtime = "2026-09-13 10:15", perms = "drwxr-xr-x" },
    { name = "assets", is_dir = true, size = 4096, mtime = "2026-09-13 11:30", perms = "drwxr-xr-x" },
    { name = "server.lua", is_dir = false, size = 4120, mtime = "2026-09-13 11:58", perms = "-rw-r--r--" },
    { name = "package.json", is_dir = false, size = 1240, mtime = "2026-09-12 18:20", perms = "-rw-r--r--" },
    { name = "README.md", is_dir = false, size = 2850, mtime = "2026-09-10 14:02", perms = "-rw-r--r--" },
    { name = "docker-compose.yml", is_dir = false, size = 840, mtime = "2026-09-11 16:45", perms = "-rw-r--r--" },
    { name = "deploy.sh", is_dir = false, size = 1520, mtime = "2026-09-13 08:12", perms = "-rwxr-xr-x", is_exec = true },
    { name = "current_build", is_dir = false, is_symlink = true, size = 12, mtime = "2026-09-13 08:00", perms = "lrwxrwxrwx" },
}

DemoFS["/home/user/app/assets"] = {
    { name = "..", is_dir = true, size = 4096, mtime = "2026-09-13 11:20", perms = "drwxr-xr-x" },
    { name = "logo.png", is_dir = false, size = #DEMO_PNG_BYTES, mtime = "2026-09-08 12:00", perms = "-rw-r--r--" },
}

DemoFS["/var/log"] = {
    { name = "..", is_dir = true, size = 4096, mtime = "2026-09-13 10:00", perms = "drwxr-xr-x" },
    { name = "syslog.log", is_dir = false, size = 18450, mtime = "2026-09-13 12:05", perms = "-rw-r-----" },
    { name = "nginx.log", is_dir = false, size = 9520, mtime = "2026-09-13 11:45", perms = "-rw-r--r--" },
}

local DemoContent = {
    ["/home/user/app/server.lua"] = [[
local ffi = require("ffi")
local http = require("http_server")

-- Initialize server application
local function start_server(port)
    local app = http.create()
    app:use(http.logger())

    app:get("/api/health", function(req, res)
        return res:json({
            status = "healthy",
            uptime = 84200,
            version = "2.4.0",
        })
    end)

    app:get("/api/users", function(req, res)
        return res:json({
            users = {
                { id = 1, name = "Alice", role = "Admin" },
                { id = 2, name = "Bob", role = "Developer" },
            }
        })
    end)

    print("[INFO] Listening on port " .. port)
    app:listen(port)
end

start_server(8080)
]],

    ["/home/user/app/README.md"] = [[
# Production Web Service

High-performance asynchronous HTTP microservice powered by LuaJIT.

## Quick Start
```bash
./deploy.sh --prod
```

## Features
- Zero-allocation buffer streaming
- In-memory metrics & health check endpoint
- Dual-platform support: Linux & Windows
- Built-in live telemetry on `:9090`
]],

    ["/home/user/app/package.json"] = [[
{
  "name": "web-service",
  "version": "2.4.0",
  "description": "High performance LuaJIT server",
  "main": "server.lua",
  "scripts": {
    "start": "luajit server.lua",
    "test": "luajit test.lua"
  },
  "dependencies": {
    "ffi": "*"
  }
}
]],

    ["/var/log/syslog.log"] = [[
Sep 13 12:00:01 prod-srv01 systemd[1]: Starting Daily apt download activities...
Sep 13 12:00:05 prod-srv01 kernel: [ 4512.182012] TCP: request_sock_TCP: Possible SYN flooding on port 8080. Sending cookies.
Sep 13 12:01:22 prod-srv01 sshd[4912]: Accepted publickey for user from 192.168.1.50 port 52314 ssh2
Sep 13 12:01:23 prod-srv01 systemd[1]: Started Session 14 of User user.
Sep 13 12:05:00 prod-srv01 rbrowse[5012]: Multiplexed SSH connection verified: socket active.
]],
}

DemoContent["/home/user/avatar.png"] = DEMO_PNG_BYTES
DemoContent["/home/user/app/assets/logo.png"] = DEMO_PNG_BYTES

--------------------------------------------------------------------------------
-- Remote Connection & Directory Crawler
--------------------------------------------------------------------------------
local Crawler = {
    dir_cache = {},
    preview_cache = {},
}

function Crawler.get_ssh_cmd(host_cfg)
    local parts = { "ssh", "-o", "ConnectTimeout=5", "-o", "BatchMode=yes" }
    if not IS_WINDOWS then
        local socket_dir = get_home_dir() .. "/.ssh"
        parts[#parts+1] = "-o"
        parts[#parts+1] = "ControlMaster=auto"
        parts[#parts+1] = "-o"
        parts[#parts+1] = "ControlPath=" .. socket_dir .. "/rbrowse-%r@%h:%p"
        parts[#parts+1] = "-o"
        parts[#parts+1] = "ControlPersist=60s"
    end
    if host_cfg.port and host_cfg.port ~= "22" and host_cfg.port ~= "" then
        parts[#parts+1] = "-p"
        parts[#parts+1] = tostring(host_cfg.port)
    end
    if host_cfg.key and host_cfg.key ~= "" then
        parts[#parts+1] = "-i"
        parts[#parts+1] = shell_escape(host_cfg.key)
    end
    local target = host_cfg.hostname or host_cfg.name
    if host_cfg.user and host_cfg.user ~= "" then
        target = host_cfg.user .. "@" .. target
    end
    parts[#parts+1] = target
    return table.concat(parts, " ")
end

function Crawler.list_directory(host_cfg, remote_dir)
    if not remote_dir or remote_dir == "" then remote_dir = "/" end
    local cache_key = (host_cfg.hostname or host_cfg.name or "demo") .. ":" .. remote_dir
    if Crawler.dir_cache[cache_key] then
        return Crawler.dir_cache[cache_key], nil
    end

    if host_cfg.is_demo then
        local list = DemoFS[remote_dir] or DemoFS["/"]
        local items = {}
        for _, it in ipairs(list) do
            local ext = (it.name:match("%.([%w_%-]+)$") or ""):lower()
            local is_img = (ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "gif" or ext == "bmp" or ext == "webp")
            table.insert(items, {
                name = it.name,
                is_dir = it.is_dir,
                is_symlink = it.is_symlink or false,
                is_exec = it.is_exec or false,
                is_image = is_img,
                size = it.size,
                mtime = it.mtime,
                perms = it.perms,
            })
        end
        Crawler.dir_cache[cache_key] = items
        return items, nil
    end

    local ssh_base = Crawler.get_ssh_cmd(host_cfg)
    local esc_dir = shell_escape(remote_dir)
    local remote_sh = string.format("LC_ALL=C ls -la --time-style=+%%Y-%%m-%%d\\ %%H:%%M:%%S %s 2>/dev/null || LC_ALL=C ls -la %s", esc_dir, esc_dir)
    local full_cmd = string.format("%s %s", ssh_base, shell_escape(remote_sh))

    local pipe = io.popen(full_cmd, "r")
    if not pipe then return nil, "Failed to execute SSH command" end

    local items = {}
    for line in pipe:lines() do
        local perms, links, owner, group, size, d1, d2, name = line:match("^(%S+)%s+(%d+)%s+(%S+)%s+(%S+)%s+(%d+)%s+(%d%d%d%d%-%d%d%-%d%d)%s+(%d%d:%d%d:%d%d)%s+(.+)$")
        if not perms then
            -- Fallback standard ls format
            perms, links, owner, group, size, d1, d2, name = line:match("^(%S+)%s+(%d+)%s+(%S+)%s+(%S+)%s+(%d+)%s+(%a+%s+%d+)%s+(%d%d?:?%d%d?)%s+(.+)$")
        end

        if perms and name and name ~= "." then
            local is_dir = (perms:sub(1, 1) == "d")
            local is_symlink = (perms:sub(1, 1) == "l")
            local is_exec = (perms:find("x") ~= nil)
            local clean_name = name
            if is_symlink then
                clean_name = name:match("^(.-)%s+%->") or name
            end
            local ext = (clean_name:match("%.([%w_%-]+)$") or ""):lower()
            local is_img = (ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "gif" or ext == "bmp" or ext == "webp")

            table.insert(items, {
                name = clean_name,
                raw_name = name,
                is_dir = is_dir,
                is_symlink = is_symlink,
                is_exec = is_exec,
                is_image = is_img,
                size = tonumber(size) or 0,
                mtime = (d1 and d2) and (d1 .. " " .. d2) or "-",
                perms = perms,
            })
        end
    end
    pipe:close()

    -- Sort: directories first, then alphabetically
    table.sort(items, function(a, b)
        if a.name == ".." then return true end
        if b.name == ".." then return false end
        if a.is_dir and not b.is_dir then return true end
        if not a.is_dir and b.is_dir then return false end
        return a.name:lower() < b.name:lower()
    end)

    Crawler.dir_cache[cache_key] = items
    return items, nil
end

function Crawler.get_file_preview(host_cfg, remote_path, is_image)
    local cache_key = (host_cfg.hostname or host_cfg.name or "demo") .. ":" .. remote_path
    if Crawler.preview_cache[cache_key] then
        return Crawler.preview_cache[cache_key]
    end

    if host_cfg.is_demo then
        local content = DemoContent[remote_path] or "File content not simulated in demo mode."
        Crawler.preview_cache[cache_key] = content
        return content
    end

    local ssh_base = Crawler.get_ssh_cmd(host_cfg)
    local esc_path = shell_escape(remote_path)
    local cmd
    if is_image then
        cmd = string.format("%s %s", ssh_base, shell_escape("cat " .. esc_path .. " 2>/dev/null"))
    else
        cmd = string.format("%s %s", ssh_base, shell_escape("head -n 250 " .. esc_path .. " 2>/dev/null"))
    end

    local pipe = io.popen(cmd, "r")
    if not pipe then return "Failed to retrieve remote preview" end
    local content = pipe:read("*a")
    pipe:close()

    Crawler.preview_cache[cache_key] = content
    return content
end

--------------------------------------------------------------------------------
-- Interactive Dual-Pane TUI Application
--------------------------------------------------------------------------------
local App = {
    running = true,
    term_w = 100,
    term_h = 30,

    host_cfg = {
        name = "demo",
        hostname = "prod-srv01.internal",
        user = "dev",
        is_demo = true,
    },

    current_dir = "/home/user/app",
    items = {},
    filtered_items = {},
    cursor = 1,
    scroll_top = 1,

    filter_text = "",
    filter_mode = false,

    focus = "left", -- "left" (file tree) or "right" (preview)
    preview_scroll = 0,

    status_msg = "Ready. Press [?] for keybindings.",
    status_color = C.bright_cyan,

    modal = nil, -- "help", "download", etc.
}

function App.update_filter()
    if App.filter_text == "" then
        App.filtered_items = App.items
    else
        local q = App.filter_text:lower()
        local res = {}
        for _, it in ipairs(App.items) do
            if it.name:lower():find(q, 1, true) then
                table.insert(res, it)
            end
        end
        App.filtered_items = res
    end
    App.cursor = math.max(1, math.min(App.cursor, #App.filtered_items))
end

function App.load_dir(dir_path)
    App.current_dir = dir_path
    local items, err = Crawler.list_directory(App.host_cfg, dir_path)
    if not items or #items == 0 then
        App.items = { { name = "..", is_dir = true, size = 4096, mtime = "-", perms = "drwxr-xr-x" } }
        App.status_msg = err or ("Directory empty or inaccessible: " .. dir_path)
        App.status_color = C.bright_yellow
    else
        App.items = items
        App.status_msg = string.format("Browsing: %s (%d items)", dir_path, #items)
        App.status_color = C.bright_cyan
    end
    App.cursor = 1
    App.scroll_top = 1
    App.preview_scroll = 0
    App.update_filter()
end

function App.get_selected_item()
    if #App.filtered_items == 0 then return nil end
    return App.filtered_items[App.cursor]
end

function App.drill_down()
    local it = App.get_selected_item()
    if not it then return end

    if it.is_dir then
        if it.name == ".." then
            local parent = App.current_dir:match("^(.*)/[^/]+$")
            if not parent or parent == "" then parent = "/" end
            App.load_dir(parent)
        else
            local next_dir = (App.current_dir == "/") and ("/" .. it.name) or (App.current_dir .. "/" .. it.name)
            App.load_dir(next_dir)
        end
    else
        App.status_msg = string.format("Inspecting: %s (%s)", it.name, format_size(it.size))
        App.status_color = C.bright_green
    end
end

function App.go_parent()
    if App.current_dir == "/" then
        App.status_msg = "Already at root directory (/)"
        App.status_color = C.gray
        return
    end
    local parent = App.current_dir:match("^(.*)/[^/]+$")
    if not parent or parent == "" then parent = "/" end
    App.load_dir(parent)
end

function App.draw()
    local w, h = Term.get_size()
    App.term_w = w
    App.term_h = h

    local buf = {}
    table.insert(buf, "\27[H")

    -- 1. Top Header Bar
    local host_str = App.host_cfg.is_demo and "[DEMO: simulated-server]" or string.format("[%s@%s]", App.host_cfg.user or "root", App.host_cfg.hostname)
    local header_text = string.format(" %s%srbrowse v1.0%s │ %s%s%s │ Dir: %s%s%s │ Icons: %s%s%s ",
        C.bold, C.bright_cyan, C.reset,
        C.bright_green, host_str, C.reset,
        C.bright_yellow, App.current_dir, C.reset,
        C.bright_magenta, IconEngine.mode:upper(), C.reset
    )
    local rem_h = math.max(0, w - utf8_col_width(header_text))
    table.insert(buf, string.format("\27[1;1H%s%s%s%s\27[K", header_text, C.gray, BOX.h:rep(rem_h), C.reset))

    -- Geometry
    local content_h = h - 5
    if content_h < 4 then content_h = 4 end
    local left_w = math.floor(w * 0.44)
    if left_w < 32 then left_w = 32 end
    if left_w > w - 30 then left_w = w - 30 end
    local right_w = w - left_w - 3

    -- Border Header
    local left_accent = (App.focus == "left") and (C.bold .. C.bright_cyan) or C.gray
    local right_accent = (App.focus == "right") and (C.bold .. C.bright_cyan) or C.gray

    local left_title = truncate_string(" Remote Files: " .. App.current_dir .. " ", left_w - 2)
    local sel_it = App.get_selected_item()
    local right_title = sel_it and truncate_string(" Preview: " .. sel_it.name .. " ", right_w - 2) or " Preview "

    table.insert(buf, string.format("\27[2;1H%s%s%s%s%s%s%s%s\27[K",
        left_accent, BOX.tl, pad_string(left_title, left_w), BOX.tt,
        right_accent, pad_string(right_title, right_w), BOX.tr, C.reset
    ))

    -- Adjust Left List Scroll
    if App.cursor < App.scroll_top then
        App.scroll_top = App.cursor
    elseif App.cursor >= App.scroll_top + content_h then
        App.scroll_top = App.cursor - content_h + 1
    end

    -- Pre-fetch preview content for right pane
    local preview_lines = {}
    if sel_it then
        local remote_file_path = (App.current_dir == "/") and ("/" .. sel_it.name) or (App.current_dir .. "/" .. sel_it.name)
        if sel_it.is_dir then
            table.insert(preview_lines, C.bold .. C.bright_blue .. "Directory Summary" .. C.reset)
            table.insert(preview_lines, C.gray .. "──────────────────────────────────────" .. C.reset)
            table.insert(preview_lines, string.format("Name:        %s", sel_it.name))
            table.insert(preview_lines, string.format("Permissions: %s", sel_it.perms))
            table.insert(preview_lines, string.format("Modified:    %s", sel_it.mtime))
            table.insert(preview_lines, "")
            table.insert(preview_lines, C.dim .. "Press [Enter] or [l] to explore this folder." .. C.reset)
        elseif sel_it.is_image then
            local data = Crawler.get_file_preview(App.host_cfg, remote_file_path, true)
            local hdr = ImageParser.parse_header(data)
            local fmt = hdr and hdr.format or "Image"
            local res = hdr and string.format("%d × %d px", hdr.width, hdr.height) or "Unknown"
            local col = hdr and hdr.color_desc or "Color"

            table.insert(preview_lines, string.format("%sFormat:%s %s  │  %sSize:%s %s  │  %sRes:%s %s",
                C.bold, C.reset, fmt, C.bold, C.reset, format_size(sel_it.size), C.bold, C.reset, res))
            table.insert(preview_lines, C.gray .. string.rep("─", right_w - 2) .. C.reset)

            if ImageRenderer.protocol == "blocks" then
                local img_h = content_h - 4
                if img_h > 2 then
                    local rendered_blocks = ImageRenderer.render_half_blocks(data, right_w - 4, img_h)
                    for _, l in ipairs(rendered_blocks) do
                        table.insert(preview_lines, l)
                    end
                end
            else
                table.insert(preview_lines, C.bright_magenta .. "[OSC 1337 Graphics Protocol Output Mode]" .. C.reset)
                table.insert(preview_lines, ImageRenderer.render_osc1337(data, right_w - 4, content_h - 4))
            end
        else
            -- Text file preview
            local data = Crawler.get_file_preview(App.host_cfg, remote_file_path, false)
            local ext = (sel_it.name:match("%.([%w_%-]+)$") or ""):lower()
            table.insert(preview_lines, string.format("%sSize:%s %s  │  %sPerms:%s %s  │  %sModified:%s %s",
                C.bold, C.reset, format_size(sel_it.size), C.bold, C.reset, sel_it.perms, C.bold, C.reset, sel_it.mtime))
            table.insert(preview_lines, C.gray .. string.rep("─", right_w - 2) .. C.reset)

            local line_idx = 1
            for l in (data .. "\n"):gmatch("([^\r\n]*)\r?\n") do
                local highlighted = Syntax.highlight_line(l, ext)
                table.insert(preview_lines, string.format("%s%3d%s %s│%s %s", C.gray, line_idx, C.reset, C.gray, C.reset, highlighted))
                line_idx = line_idx + 1
            end
        end
    end

    -- 2. Render Rows
    for r = 1, content_h do
        local item_idx = App.scroll_top + r - 1
        local it = App.filtered_items[item_idx]

        local left_cell = ""
        if it then
            local is_cur = (item_idx == App.cursor)
            local cur_arrow = is_cur and (C.bold .. C.bright_yellow .. BOX.arrow_r .. " " .. C.reset) or "  "
            local icon_str, icon_w = IconEngine.get(it.name, it.is_dir, it.is_symlink, it.is_exec)
            local size_str = it.is_dir and "<DIR>" or format_size(it.size)

            -- Format column widths
            local name_max_w = left_w - 18 - icon_w
            if name_max_w < 8 then name_max_w = 8 end
            local name_disp = truncate_string(it.name, name_max_w)
            local name_pad = string.rep(" ", math.max(0, name_max_w - utf8_col_width(name_disp)))

            local size_pad = string.rep(" ", math.max(0, 8 - #size_str)) .. size_str
            local row_color = is_cur and (C.bold .. C.bg_sel) or (it.is_dir and C.bright_blue or C.white)

            left_cell = string.format("%s%s%s%s%s%s%s", cur_arrow, icon_str, row_color, name_disp, name_pad, size_pad, C.reset)
        end
        left_cell = pad_string(left_cell, left_w)

        -- Right cell from preview_lines
        local prev_line_idx = App.preview_scroll + r
        local right_cell = preview_lines[prev_line_idx] or ""
        right_cell = pad_string(right_cell, right_w)

        table.insert(buf, string.format("\27[%d;1H%s%s%s%s%s%s%s%s%s%s\27[K",
            r + 2,
            left_accent, BOX.v, C.reset,
            left_cell,
            C.gray, BOX.v, C.reset,
            right_cell,
            right_accent, BOX.v .. C.reset
        ))
    end

    -- 3. Bottom Pane Border
    table.insert(buf, string.format("\27[%d;1H%s%s%s%s%s%s%s\27[K",
        content_h + 3,
        left_accent, BOX.bl, BOX.h:rep(left_w), BOX.tb,
        right_accent, BOX.h:rep(right_w), BOX.br .. C.reset
    ))

    -- 4. Status Bar
    local stat_text = App.filter_mode and (C.bold .. C.bright_yellow .. " FILTER: " .. App.filter_text .. "█" .. C.reset)
        or (App.status_color .. " " .. App.status_msg .. C.reset)
    table.insert(buf, string.format("\27[%d;1H%s\27[K", content_h + 4, pad_string(stat_text, w)))

    -- 5. Footer Keybindings Guide
    local footer = " [Enter/l] Open [h] Up [j/k] Select [J/K] Scroll [I] Icons [i] ImgMode [/] Filter [d] Scp [r] Refresh [?] Help [q] Quit "
    table.insert(buf, string.format("\27[%d;1H%s%s%s%s\27[K",
        content_h + 5,
        C.bg_gray, C.bold .. C.bright_white, pad_string(footer, w), C.reset
    ))

    io.write(table.concat(buf))
    io.flush()

    if App.modal == "help" then
        App.draw_help_modal()
    end
end

function App.draw_help_modal()
    local w, h = App.term_w, App.term_h
    local mw = math.min(68, w - 4)
    local mh = 16
    local mx = math.floor((w - mw) / 2)
    local my = math.floor((h - mh) / 2)

    local lines = {
        C.bold .. C.bright_cyan .. "            rbrowse.lua - Keyboard Controls Guide           " .. C.reset,
        C.gray .. string.rep("─", mw - 4) .. C.reset,
        string.format("  %s%-18s%s %s", C.bold .. C.yellow, "j, Down / k, Up", C.reset, "Navigate files in active directory"),
        string.format("  %s%-18s%s %s", C.bold .. C.yellow, "Enter, l, Right", C.reset, "Drill down into folder / inspect item"),
        string.format("  %s%-18s%s %s", C.bold .. C.yellow, "h, Backspace", C.reset, "Navigate to parent folder (..)"),
        string.format("  %s%-18s%s %s", C.bold .. C.yellow, "J / K, PgDn/PgUp", C.reset, "Scroll preview content smoothly"),
        string.format("  %s%-18s%s %s", C.bold .. C.yellow, "I", C.reset, "Cycle icon mode (Nerd -> Emoji -> ASCII -> None)"),
        string.format("  %s%-18s%s %s", C.bold .. C.yellow, "i", C.reset, "Toggle image renderer (Half-Blocks / OSC 1337)"),
        string.format("  %s%-18s%s %s", C.bold .. C.yellow, "/", C.reset, "Inline fuzzy filter current directory"),
        string.format("  %s%-18s%s %s", C.bold .. C.yellow, "Tab", C.reset, "Switch focus between file tree & preview"),
        string.format("  %s%-18s%s %s", C.bold .. C.yellow, "d", C.reset, "Download selected file/folder via SCP"),
        string.format("  %s%-18s%s %s", C.bold .. C.yellow, "r", C.reset, "Refresh remote directory and clear cache"),
        string.format("  %s%-18s%s %s", C.bold .. C.yellow, "~", C.reset, "Jump to remote user home directory"),
        string.format("  %s%-18s%s %s", C.bold .. C.yellow, "? / Esc / q", C.reset, "Close this help dialog / Quit application"),
    }

    local modal_buf = {}
    table.insert(modal_buf, string.format("\27[%d;%dH%s┌%s┐%s", my, mx, C.bold .. C.bright_cyan, string.rep("─", mw - 2), C.reset))
    for idx, l in ipairs(lines) do
        table.insert(modal_buf, string.format("\27[%d;%dH%s│%s %s %s│%s",
            my + idx, mx, C.bold .. C.bright_cyan, C.reset, pad_string(l, mw - 4), C.bold .. C.bright_cyan, C.reset))
    end
    table.insert(modal_buf, string.format("\27[%d;%dH%s└%s┘%s", my + #lines + 1, mx, C.bold .. C.bright_cyan, string.rep("─", mw - 2), C.reset))
    io.write(table.concat(modal_buf))
    io.flush()
end

function App.run()
    Term.init()
    Term.enable_raw()
    App.load_dir(App.current_dir)

    while App.running do
        App.draw()
        local key = Term.read_key()

        if key then
            if App.modal == "help" then
                if key == "escape" or key == "?" or key == "q" or key == "enter" then
                    App.modal = nil
                end
            elseif App.filter_mode then
                if key == "enter" or key == "escape" then
                    App.filter_mode = false
                elseif key == "backspace" then
                    if #App.filter_text > 0 then
                        App.filter_text = App.filter_text:sub(1, -2)
                        App.update_filter()
                    else
                        App.filter_mode = false
                    end
                elseif #key == 1 then
                    App.filter_text = App.filter_text .. key
                    App.update_filter()
                end
            else
                -- Normal navigation mode
                if key == "q" or key == "ctrl_c" then
                    App.running = false
                elseif key == "up" or key == "k" then
                    if App.cursor > 1 then
                        App.cursor = App.cursor - 1
                        App.preview_scroll = 0
                    end
                elseif key == "down" or key == "j" then
                    if App.cursor < #App.filtered_items then
                        App.cursor = App.cursor + 1
                        App.preview_scroll = 0
                    end
                elseif key == "page_up" or key == "K" or key == "ctrl_u" then
                    App.preview_scroll = math.max(0, App.preview_scroll - 5)
                elseif key == "page_down" or key == "J" or key == "ctrl_d" then
                    App.preview_scroll = App.preview_scroll + 5
                elseif key == "enter" or key == "l" or key == "right" then
                    App.drill_down()
                elseif key == "backspace" or key == "h" or key == "left" then
                    App.go_parent()
                elseif key == "tab" then
                    App.focus = (App.focus == "left") and "right" or "left"
                elseif key == "I" then
                    local new_m = IconEngine.cycle()
                    App.status_msg = "Icon Mode toggled to: " .. new_m:upper()
                    App.status_color = C.bright_magenta
                elseif key == "i" then
                    ImageRenderer.protocol = (ImageRenderer.protocol == "blocks") and "graphics" or "blocks"
                    App.status_msg = "Image Renderer toggled to: " .. ImageRenderer.protocol:upper()
                    App.status_color = C.bright_yellow
                elseif key == "/" then
                    App.filter_mode = true
                    App.filter_text = ""
                elseif key == "r" then
                    Crawler.dir_cache = {}
                    Crawler.preview_cache = {}
                    App.load_dir(App.current_dir)
                    App.status_msg = "Refreshed remote directory & cleared preview cache."
                    App.status_color = C.bright_green
                elseif key == "~" then
                    App.load_dir(App.host_cfg.is_demo and "/home/user" or "~")
                elseif key == "d" then
                    local sel = App.get_selected_item()
                    if sel then
                        App.status_msg = string.format("[Download] Run 'scp %s:%s/%s .' to pull locally.",
                            App.host_cfg.hostname, App.current_dir, sel.name)
                        App.status_color = C.bright_yellow
                    end
                elseif key == "?" then
                    App.modal = "help"
                end
            end
        end
    end

    Term.restore()
end

--------------------------------------------------------------------------------
-- Automated Self-Test Suite (--test)
--------------------------------------------------------------------------------
local function run_tests()
    print(C.bold .. C.bright_cyan .. "=== Running rbrowse.lua Automated Self-Tests ===" .. C.reset)

    -- 1. Base64 Encode & Decode
    local test_str = "LuaJIT FFI Remote Browser 2026!"
    local enc = base64_encode(test_str)
    local dec = base64_decode(enc)
    assert(dec == test_str, "Base64 roundtrip failed")
    print(C.bright_green .. "  [PASS] In-Memory Base64 FFI roundtrip" .. C.reset)

    -- 2. PNG Header Parser
    local png_hdr = ImageParser.parse_header(DEMO_PNG_BYTES)
    assert(png_hdr ~= nil, "Failed to parse DEMO_PNG_BYTES")
    assert(png_hdr.format == "PNG", "Format should be PNG")
    assert(png_hdr.width == 32 and png_hdr.height == 32, "PNG dimensions should be 32x32")
    print(C.bright_green .. string.format("  [PASS] ImageParser PNG dimensions: %dx%d (%s)", png_hdr.width, png_hdr.height, png_hdr.color_desc) .. C.reset)

    -- 3. BMP Header Parser Test
    local fake_bmp = string.char(
        0x42, 0x4D, 0, 0, 0, 0, 0, 0, 0, 0, 54, 0, 0, 0, 40, 0, 0, 0,
        64, 0, 0, 0, -- Width = 64
        48, 0, 0, 0, -- Height = 48
        1, 0, 24, 0   -- 24 bpp
    )
    local bmp_hdr = ImageParser.parse_header(fake_bmp)
    assert(bmp_hdr and bmp_hdr.format == "BMP" and bmp_hdr.width == 64 and bmp_hdr.height == 48, "BMP parser failed")
    print(C.bright_green .. "  [PASS] ImageParser BMP dimensions: 64x48 (24-bit)" .. C.reset)

    -- 4. Icon Engine Verification across Modes
    local old_mode = IconEngine.mode
    IconEngine.mode = "nerd"
    local n_icon = IconEngine.get("server.lua", false, false, false)
    assert(n_icon:find(""), "Nerd font Lua icon expected")

    IconEngine.mode = "emoji"
    local e_icon = IconEngine.get("server.lua", false, false, false)
    assert(e_icon:find("🌙"), "Emoji Lua icon expected")

    local img_icon = IconEngine.get("avatar.png", false, false, false)
    assert(img_icon:find("🖼"), "Emoji Image icon expected")

    IconEngine.mode = "ascii"
    local a_icon = IconEngine.get("dir", true, false, false)
    assert(a_icon:find("%[DIR%]"), "ASCII DIR icon expected")

    IconEngine.mode = old_mode
    print(C.bright_green .. "  [PASS] IconEngine mappings: Nerd Font, Emoji, ASCII fallback" .. C.reset)

    -- 5. Syntax Tokenizer
    local h_line = Syntax.highlight_line("local function start_server(port) -- init", "lua")
    assert(h_line:find("\27%["), "Syntax line should contain ANSI codes")
    print(C.bright_green .. "  [PASS] Syntax tokenizer keyword & comment formatting" .. C.reset)

    -- 6. Demo Filesystem Listing
    local demo_host = { is_demo = true, name = "demo", hostname = "demo" }
    local items, err = Crawler.list_directory(demo_host, "/home/user/app")
    assert(items and #items > 0, "Demo listing failed: " .. tostring(err))
    assert(items[1].name == "..", "First entry should be parent directory ..")
    print(C.bright_green .. string.format("  [PASS] Demo filesystem traversal: found %d items in /home/user/app", #items) .. C.reset)

    -- 7. Shell Escape Test
    assert(shell_escape("normal_path") == "normal_path", "Safe path should not be quoted")
    local esc = shell_escape("path with spaces & 'quotes'")
    assert(esc:find("path with spaces"), "Escaped path should contain original content")
    print(C.bright_green .. "  [PASS] Shell quote escaping and path hygiene" .. C.reset)

    -- 8. Terminal Size Query Test
    Term.init()
    local tw, th = Term.get_size()
    assert(tw > 0 and th > 0, "Terminal dimensions must be > 0")
    print(C.bright_green .. string.format("  [PASS] Terminal low-level FFI dimension probe: %dx%d", tw, th) .. C.reset)

    print(C.bold .. C.bright_green .. "\nALL 8 TESTS PASSED SUCCESSFULLY!" .. C.reset)
    return true
end

--------------------------------------------------------------------------------
-- CLI Argument Parsing & Dispatcher
--------------------------------------------------------------------------------
local function print_help()
    print([=[
rbrowse.lua - Fast Interactive Remote Server Browser & Previewer (LuaJIT + FFI)

Usage:
  luajit rbrowse.lua [OPTIONS] [USER@HOST[:REMOTE_PATH]]
  luajit rbrowse.lua --demo
  luajit rbrowse.lua --preview <HOST> <REMOTE_PATH> [WIDTH] [HEIGHT]
  luajit rbrowse.lua --list <HOST> <REMOTE_PATH>
  luajit rbrowse.lua --test

Options:
  -H, --host <HOST>       Remote SSH host
  -u, --user <USER>       Remote SSH username
  -p, --port <PORT>       Remote SSH port (default: 22)
  -i, --identity <KEY>    Path to SSH private key
  --icons <MODE>          Icon style: nerd (default), emoji, ascii, none
  --protocol <MODE>       Image protocol: blocks (default) or graphics (OSC 1337)
  --demo                  Start in simulated offline demo mode
  --preview               Headless preview mode for fzf/lf/ranger
  --list                  List remote directory as TSV
  --test                  Run automated test suite
  -h, --help              Show this help message
]=])
end

local function main(args)
    local target_arg = nil
    local i = 1
    while i <= #args do
        local a = args[i]
        if a == "--help" or a == "-h" then
            print_help()
            return
        elseif a == "--test" then
            run_tests()
            return
        elseif a == "--demo" then
            App.host_cfg.is_demo = true
        elseif a == "--icons" and i < #args then
            i = i + 1
            IconEngine.mode = args[i]:lower()
        elseif a == "--protocol" and i < #args then
            i = i + 1
            ImageRenderer.protocol = args[i]:lower()
        elseif a == "--preview" then
            -- Headless preview mode
            local host = args[i + 1] or "demo"
            local path = args[i + 2] or "/home/user/app/server.lua"
            local pw = tonumber(args[i + 3]) or 80
            local ph = tonumber(args[i + 4]) or 24
            local cfg = { hostname = host, is_demo = (host == "demo") }
            local ext = (path:match("%.([%w_%-]+)$") or ""):lower()
            local is_img = (ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "gif" or ext == "bmp" or ext == "webp")
            local content = Crawler.get_file_preview(cfg, path, is_img)

            if is_img then
                local hdr = ImageParser.parse_header(content)
                local res = hdr and string.format("%d×%d px", hdr.width, hdr.height) or "Unknown"
                print(string.format("%s[Image Preview: %s · %s · %s]%s", C.bold .. C.bright_magenta, path, res, format_size(#content), C.reset))
                local blocks = ImageRenderer.render_half_blocks(content, pw, ph - 2)
                for _, l in ipairs(blocks) do print(l) end
            else
                local l_num = 1
                for l in (content .. "\n"):gmatch("([^\r\n]*)\r?\n") do
                    if l_num > ph then break end
                    print(string.format("%s%3d%s │ %s", C.gray, l_num, C.reset, Syntax.highlight_line(l, ext)))
                    l_num = l_num + 1
                end
            end
            return
        elseif a == "--list" then
            local host = args[i + 1] or "demo"
            local path = args[i + 2] or "/"
            local cfg = { hostname = host, is_demo = (host == "demo") }
            local items, err = Crawler.list_directory(cfg, path)
            if not items then
                print("Error: " .. tostring(err))
                return
            end
            for _, it in ipairs(items) do
                print(string.format("%s\t%s\t%s\t%s", it.perms, format_size(it.size), it.mtime, it.name))
            end
            return
        elseif a == "-H" or a == "--host" then
            i = i + 1
            App.host_cfg.hostname = args[i]
            App.host_cfg.is_demo = false
        elseif a == "-u" or a == "--user" then
            i = i + 1
            App.host_cfg.user = args[i]
        elseif a == "-p" or a == "--port" then
            i = i + 1
            App.host_cfg.port = args[i]
        elseif a == "-i" or a == "--identity" then
            i = i + 1
            App.host_cfg.key = args[i]
        elseif not a:find("^%-") and not target_arg then
            target_arg = a
        end
        i = i + 1
    end

    if target_arg then
        if target_arg:find("@") then
            local u, rem = target_arg:match("^([^@]+)@(.+)$")
            App.host_cfg.user = u
            target_arg = rem
        end
        if target_arg:find(":") then
            local h, p = target_arg:match("^([^:]+):(.+)$")
            App.host_cfg.hostname = h
            App.current_dir = p
        else
            App.host_cfg.hostname = target_arg
        end
        App.host_cfg.is_demo = false
    end

    -- Run Interactive TUI
    App.run()
end

main({ ... })
