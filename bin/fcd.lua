#!/usr/bin/env luajit
--[[
  fcd.lua - Ultra-fast Interactive Fuzzy Directory Jumper & Tree Previewer
  Powered by LuaJIT & FFI. Works on Windows (Win32 FindFirstFileW) & Linux/POSIX (/proc/opendir).

  Features:
    - Recursively scans directory trees at C-speed without requiring 'fd' or 'eza'
    - Built-in instant sub-millisecond directory tree previewer for FZF (< 1 ms)
    - Automatically ignores heavy directories (.git, node_modules, .cache, target, build)
    - Returns the selected path on stdout for easy integration into bash/zsh/cmd/PowerShell

  Usage:
    fcd.lua [OPTIONS] [BASE_DIR] [QUERY]

  Options:
    -a, --all               Include hidden directories (e.g. .config, .git)
    -d, --max-depth <NUM>   Maximum directory search depth (default: 6)
    -l, --list              Output directory list (for pipelines)
    -p, --preview <DIR>     Render rich directory content card (for fzf live preview)
    -h, --help              Show this help message

  Shell Integration Examples:
    Bash / Zsh:
      fcd() { local d; d="$(luajit path/to/fcd.lua "$@")" && [ -n "$d" ] && cd "$d"; }

    Windows CMD (fcd.bat):
      for /f "delims=" %%i in ('luajit "%~dp0fcd.lua" %*') do cd /d "%%i"

    PowerShell (fcd.ps1):
      $d = & luajit $PSScriptRoot/fcd.lua @args; if ($d) { Set-Location $d }
]]

local ffi = require("ffi")

local OS = ffi.os
local IS_WINDOWS = (OS == "Windows")

-- ANSI Color Codes
local C = {
    reset   = "\27[0m",
    bold    = "\27[1m",
    dim     = "\27[2m",
    cyan    = "\27[36m",
    green   = "\27[32m",
    yellow  = "\27[33m",
    blue    = "\27[34m",
    magenta = "\27[35m",
    white   = "\27[37m",
    gray    = "\27[90m",
    b_cyan  = "\27[1;36m",
    b_yellow= "\27[1;33m",
    b_white = "\27[1;37m",
    b_green = "\27[1;32m",
}

--------------------------------------------------------------------------------
-- FFI Declarations
--------------------------------------------------------------------------------
if IS_WINDOWS then
    ffi.cdef[[
        typedef void* HANDLE;
        typedef unsigned long DWORD;
        typedef int BOOL;
        typedef const wchar_t* LPCWSTR;
        typedef wchar_t* LPWSTR;

        typedef struct {
            DWORD dwLowDateTime;
            DWORD dwHighDateTime;
        } FILETIME;

        typedef struct {
            DWORD dwFileAttributes;
            FILETIME ftCreationTime;
            FILETIME ftLastAccessTime;
            FILETIME ftLastWriteTime;
            DWORD nFileSizeHigh;
            DWORD nFileSizeLow;
            DWORD dwReserved0;
            DWORD dwReserved1;
            wchar_t cFileName[260];
            wchar_t cAlternateFileName[14];
        } WIN32_FIND_DATAW;

        HANDLE FindFirstFileW(LPCWSTR lpFileName, WIN32_FIND_DATAW* lpFindFileData);
        BOOL FindNextFileW(HANDLE hFindFile, WIN32_FIND_DATAW* lpFindFileData);
        BOOL FindClose(HANDLE hFindFile);

        int MultiByteToWideChar(unsigned int CodePage, DWORD dwFlags, const char* lpMultiByteStr, int cbMultiByte, wchar_t* lpWideCharStr, int cchWideChar);
        int WideCharToMultiByte(unsigned int CodePage, DWORD dwFlags, LPCWSTR lpWideCharStr, int cchWideChar, char* lpMultiByteStr, int cbMultiByte, const char* lpDefaultChar, BOOL* lpUsedDefaultChar);
    ]]
else
    ffi.cdef[[
        typedef struct DIR DIR;
        struct dirent {
            unsigned long  d_ino;
            long           d_off;
            unsigned short d_reclen;
            unsigned char  d_type;
            char           d_name[256];
        };
        DIR *opendir(const char *name);
        struct dirent *readdir(DIR *dirp);
        int closedir(DIR *dirp);
    ]]
end

--------------------------------------------------------------------------------
-- Helper Utilities
--------------------------------------------------------------------------------
local function to_wide(str)
    if not IS_WINDOWS then return str end
    local len = ffi.C.MultiByteToWideChar(65001, 0, str, #str, nil, 0)
    local buf = ffi.new("wchar_t[?]", len + 1)
    ffi.C.MultiByteToWideChar(65001, 0, str, #str, buf, len)
    buf[len] = 0
    return buf
end

local function from_wide(wstr)
    if not IS_WINDOWS then return wstr end
    local len = ffi.C.WideCharToMultiByte(65001, 0, wstr, -1, nil, 0, nil, nil)
    local buf = ffi.new("char[?]", len)
    ffi.C.WideCharToMultiByte(65001, 0, wstr, -1, buf, len, nil, nil)
    return ffi.string(buf, len - 1)
end

local function format_size(bytes)
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

-- Default directories to ignore
local IGNORE_DIRS = {
    [".git"] = true,
    ["node_modules"] = true,
    ["__pycache__"] = true,
    [".pytest_cache"] = true,
    [".mypy_cache"] = true,
    [".cache"] = true,
    ["target"] = true,
    ["dist"] = true,
    ["build"] = true,
    [".idea"] = true,
    [".vscode"] = true,
    ["$recycle.bin"] = true,
    ["system volume information"] = true,
}

--------------------------------------------------------------------------------
-- Directory Scanner (Windows Win32 FFI & Linux POSIX FFI)
--------------------------------------------------------------------------------
local FILE_ATTRIBUTE_DIRECTORY = 0x10

local function scan_dirs_win32(base_dir, max_depth, include_all)
    local results = {}
    local sep = "\\"
    base_dir = base_dir:gsub("[/\\]+$", "")

    local function recurse(current_path, current_depth)
        if current_depth > max_depth then return end
        local pattern = current_path .. "\\*"
        local find_data = ffi.new("WIN32_FIND_DATAW")
        local hFind = ffi.C.FindFirstFileW(to_wide(pattern), find_data)
        if hFind == nil or hFind == ffi.cast("HANDLE", -1) then return end

        repeat
            local name = from_wide(find_data.cFileName)
            if name ~= "." and name ~= ".." then
                local is_dir = (bit.band(find_data.dwFileAttributes, FILE_ATTRIBUTE_DIRECTORY) ~= 0)
                if is_dir then
                    local lower = name:lower()
                    local skip = false
                    if not include_all then
                        if IGNORE_DIRS[lower] or (name:sub(1, 1) == "." and lower ~= ".config") then
                            skip = true
                        end
                    end
                    if not skip then
                        local child_path = current_path .. sep .. name
                        table.insert(results, child_path)
                        recurse(child_path, current_depth + 1)
                    end
                end
            end
        until ffi.C.FindNextFileW(hFind, find_data) == 0

        ffi.C.FindClose(hFind)
    end

    recurse(base_dir, 1)
    return results
end

local function scan_dirs_posix(base_dir, max_depth, include_all)
    local results = {}
    base_dir = base_dir:gsub("/+$", "")

    local function recurse(current_path, current_depth)
        if current_depth > max_depth then return end
        local d = ffi.C.opendir(current_path)
        if d == nil then return end

        while true do
            local ent = ffi.C.readdir(d)
            if ent == nil then break end
            local name = ffi.string(ent.d_name)
            if name ~= "." and name ~= ".." then
                -- ent.d_type == 4 is DT_DIR, skip symlinks (DT_LNK == 10)
                if ent.d_type == 4 then
                    local lower = name:lower()
                    local skip = false
                    if not include_all then
                        if IGNORE_DIRS[lower] or (name:sub(1, 1) == "." and lower ~= ".config") then
                            skip = true
                        end
                    end
                    if not skip then
                        local child_path = current_path .. "/" .. name
                        table.insert(results, child_path)
                        recurse(child_path, current_depth + 1)
                    end
                end
            end
        end
        ffi.C.closedir(d)
    end

    recurse(base_dir, 1)
    return results
end

local scan_dirs = IS_WINDOWS and scan_dirs_win32 or scan_dirs_posix

--------------------------------------------------------------------------------
-- Fast Directory Content Inspector (Sub-millisecond for FZF Preview)
--------------------------------------------------------------------------------
local function get_dir_contents_win32(dir_path)
    local dirs = {}
    local files = {}
    local total_size = 0

    local pattern = dir_path:gsub("[/\\]+$", "") .. "\\*"
    local find_data = ffi.new("WIN32_FIND_DATAW")
    local hFind = ffi.C.FindFirstFileW(to_wide(pattern), find_data)
    if hFind ~= nil and hFind ~= ffi.cast("HANDLE", -1) then
        repeat
            local name = from_wide(find_data.cFileName)
            if name ~= "." and name ~= ".." then
                local is_dir = (bit.band(find_data.dwFileAttributes, FILE_ATTRIBUTE_DIRECTORY) ~= 0)
                if is_dir then
                    table.insert(dirs, name)
                else
                    local sz = (tonumber(find_data.nFileSizeHigh) * 4294967296) + tonumber(find_data.nFileSizeLow)
                    total_size = total_size + sz
                    table.insert(files, { name = name, size = sz })
                end
            end
        until ffi.C.FindNextFileW(hFind, find_data) == 0
        ffi.C.FindClose(hFind)
    end

    table.sort(dirs)
    table.sort(files, function(a, b) return a.name < b.name end)
    return dirs, files, total_size
end

local function get_dir_contents_posix(dir_path)
    local dirs = {}
    local files = {}
    local total_size = 0

    local d = ffi.C.opendir(dir_path)
    if d ~= nil then
        while true do
            local ent = ffi.C.readdir(d)
            if ent == nil then break end
            local name = ffi.string(ent.d_name)
            if name ~= "." and name ~= ".." then
                if ent.d_type == 4 then
                    table.insert(dirs, name)
                else
                    local f = io.open(dir_path .. "/" .. name, "rb")
                    local sz = 0
                    if f then
                        sz = f:seek("end") or 0
                        f:close()
                    end
                    total_size = total_size + sz
                    table.insert(files, { name = name, size = sz })
                end
            end
        end
        ffi.C.closedir(d)
    end

    table.sort(dirs)
    table.sort(files, function(a, b) return a.name < b.name end)
    return dirs, files, total_size
end

local get_dir_contents = IS_WINDOWS and get_dir_contents_win32 or get_dir_contents_posix

--------------------------------------------------------------------------------
-- Render Preview Card (for FZF live preview)
--------------------------------------------------------------------------------
local function render_preview(dir_path)
    local dirs, files, total_size = get_dir_contents(dir_path)
    local border = string.rep("─", 54)

    io.write(string.format("%s┌%s┐%s\n", C.b_cyan, border, C.reset))
    io.write(string.format("%s│ %s%-52s%s │%s\n", C.b_cyan, C.b_yellow, "DIRECTORY PREVIEW [⚡ LuaJIT FFI]", C.b_cyan, C.reset))
    io.write(string.format("%s├%s┤%s\n", C.b_cyan, border, C.reset))

    -- Truncate path if too long
    local d_disp = #dir_path > 48 and ("..." .. dir_path:sub(-45)) or dir_path
    io.write(string.format("%s│%s Path : %s%-45s%s %s│%s\n", C.b_cyan, C.bold, C.b_white, d_disp, C.reset, C.b_cyan, C.reset))
    io.write(string.format("%s│%s Items: %s%-45s%s %s│%s\n", C.b_cyan, C.bold, C.green,
        string.format("%d folder(s), %d file(s) [%s]", #dirs, #files, format_size(total_size)),
        C.reset, C.b_cyan, C.reset))
    io.write(string.format("%s├%s┤%s\n", C.b_cyan, border, C.reset))

    local max_items = 24
    local count = 0

    -- 1. List Subdirectories first
    for _, dname in ipairs(dirs) do
        if count >= max_items then break end
        io.write(string.format("%s│%s   📁 %s%-46s%s %s│%s\n", C.b_cyan, C.reset, C.b_cyan, dname:sub(1, 46) .. "/", C.reset, C.b_cyan, C.reset))
        count = count + 1
    end

    -- 2. List Files
    for _, f in ipairs(files) do
        if count >= max_items then break end
        local sz_str = format_size(f.size)
        local max_name_len = 44 - #sz_str
        local name_disp = f.name:sub(1, max_name_len)
        local pad = string.rep(" ", math.max(0, max_name_len - #name_disp))
        io.write(string.format("%s│%s   📄 %s%s%s %s%s%s %s│%s\n",
            C.b_cyan, C.reset,
            C.white, name_disp, pad,
            C.gray, sz_str, C.reset,
            C.b_cyan, C.reset))
        count = count + 1
    end

    if #dirs + #files > max_items then
        local rem = (#dirs + #files) - max_items
        io.write(string.format("%s│%s   %s... and %d more items%s%s %s│%s\n",
            C.b_cyan, C.reset, C.gray, rem, string.rep(" ", math.max(0, 43 - #tostring(rem) - 20)), C.reset, C.b_cyan, C.reset))
    elseif #dirs == 0 and #files == 0 then
        io.write(string.format("%s│%s   %s(Directory is empty)%s%s %s│%s\n",
            C.b_cyan, C.reset, C.gray, string.rep(" ", 29), C.reset, C.b_cyan, C.reset))
    end

    io.write(string.format("%s└%s┘%s\n", C.b_cyan, border, C.reset))
end

--------------------------------------------------------------------------------
-- Interactive FZF Mode
--------------------------------------------------------------------------------
local function interactive_fzf(base_dir, max_depth, include_all, query)
    local script_path = debug.getinfo(1, "S").source:sub(2)
    if not script_path:match("^/") and not script_path:match("^%a:[/\\]") then
        local pwd = io.popen(IS_WINDOWS and "cd" or "pwd 2>/dev/null || pwd"):read("*line") or "."
        script_path = pwd .. "/" .. script_path
    end

    local preview_cmd = string.format("luajit %q --preview {}", script_path)
    local list_cmd    = string.format("luajit %q --list -d %d %s %q",
        script_path, max_depth, include_all and "-a" or "", base_dir)

    local query_flag = (query and query ~= "") and string.format("--query=%q ", query) or ""

    local fzf_cmd = string.format(
        '%s | fzf %s--prompt="[LuaJIT] Jump Dir > " ' ..
        '--layout=reverse --height=60%% --border --preview=%q --preview-window=right:50%%:wrap ' ..
        '--header="⚡ LuaJIT FFI | ENTER: Select Directory | ESC: Cancel"',
        list_cmd, query_flag, preview_cmd
    )

    local pipe = io.popen(fzf_cmd, "r")
    if not pipe then
        io.stderr:write("Error: fzf is not installed or failed to launch.\n")
        return
    end

    local selected = pipe:read("*line")
    pipe:close()

    if selected and selected ~= "" then
        -- Print selected directory to standard output
        io.write(selected .. "\n")
    end
end

--------------------------------------------------------------------------------
-- CLI Argument Parsing & Entry Point
--------------------------------------------------------------------------------
local function main(args)
    local base_dir = "."
    local max_depth = 6
    local include_all = false
    local query = nil
    local list_only = false

    local i = 1
    while i <= #args do
        local a = args[i]
        if a == "-h" or a == "--help" then
            print([[fcd.lua - Fast Interactive Directory Jumper (LuaJIT FFI)
Usage:
  fcd.lua [OPTIONS] [BASE_DIR] [QUERY]

Options:
  -a, --all               Include hidden directories
  -d, --max-depth <NUM>   Max recursion depth (default: 6)
  -l, --list              Print discovered directories to stdout
  -p, --preview <DIR>     Render directory contents card (for fzf)
  -h, --help              Show this help message
]])
            return
        elseif a == "-p" or a == "--preview" then
            local target_dir = args[i + 1] or "."
            render_preview(target_dir)
            return
        elseif a == "-l" or a == "--list" then
            list_only = true
        elseif a == "-a" or a == "--all" then
            include_all = true
        elseif (a == "-d" or a == "--max-depth") and i + 1 <= #args then
            i = i + 1
            max_depth = tonumber(args[i]) or 6
        elseif not a:match("^-") then
            -- Check if argument is an existing directory
            local is_exist = false
            if IS_WINDOWS then
                is_exist = (os.execute(string.format('if exist "%s\\*" exit 0 else exit 1', a)) == 0)
            else
                local d = ffi.C.opendir(a)
                if d ~= nil then ffi.C.closedir(d) is_exist = true end
            end

            if is_exist and base_dir == "." then
                base_dir = a
            else
                query = query and (query .. " " .. a) or a
            end
        end
        i = i + 1
    end

    if list_only then
        local dirs = scan_dirs(base_dir, max_depth, include_all)
        table.sort(dirs)
        for _, d in ipairs(dirs) do
            print(d)
        end
        return
    end

    interactive_fzf(base_dir, max_depth, include_all, query)
end

main({...})
