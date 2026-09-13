#!/usr/bin/env luajit
--[[
  fkill.lua - Ultra-fast Interactive Process Killer powered by LuaJIT & FFI.
  Supports both Linux (/proc) and Windows (Win32 Toolhelp32 & Kernel32 APIs).

  Usage:
    fkill                     Interactive multi-process selector with live preview (via fzf)
    fkill <PID>               Kill process by numeric PID
    fkill <NAME>              Kill all processes matching NAME (case-insensitive)
    fkill -9 <PID|NAME>       Force kill (SIGKILL on Linux)
    fkill --list              Print process list table (for fzf or pipeline)
    fkill --preview <PID>     Print rich process details card (for fzf live preview)
]]

local ffi = require("ffi")

local OS = ffi.os
local IS_LINUX = (OS == "Linux")
local IS_WINDOWS = (OS == "Windows")

-- ANSI Colors for preview
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
    b_cyan = "\27[1;36m",
    b_yellow="\27[1;33m",
    b_red  = "\27[1;31m",
}

--------------------------------------------------------------------------------
-- FFI Declarations
--------------------------------------------------------------------------------
if IS_LINUX then
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
        int kill(int pid, int sig);
        int readlink(const char *pathname, char *buf, size_t bufsiz);
        char *strerror(int errnum);
    ]]
elseif IS_WINDOWS then
    ffi.cdef[[
        typedef void* HANDLE;
        typedef unsigned long DWORD;
        typedef int BOOL;
        typedef unsigned short WORD;
        typedef uintptr_t ULONG_PTR;

        typedef struct {
            DWORD dwSize;
            DWORD cntUsage;
            DWORD th32ProcessID;
            ULONG_PTR th32DefaultHeapID;
            DWORD th32ModuleID;
            DWORD cntThreads;
            DWORD th32ParentProcessID;
            long pcPriClassBase;
            DWORD dwFlags;
            char szExeFile[260];
        } PROCESSENTRY32;

        HANDLE CreateToolhelp32Snapshot(DWORD dwFlags, DWORD th32ProcessID);
        BOOL Process32First(HANDLE hSnapshot, PROCESSENTRY32* lppe);
        BOOL Process32Next(HANDLE hSnapshot, PROCESSENTRY32* lppe);
        HANDLE OpenProcess(DWORD dwDesiredAccess, BOOL bInheritHandle, DWORD dwProcessId);
        BOOL TerminateProcess(HANDLE hProcess, unsigned int uExitCode);
        BOOL CloseHandle(HANDLE hObject);
        DWORD QueryFullProcessImageNameA(HANDLE hProcess, DWORD dwFlags, char* lpExeName, DWORD* lpdwSize);
        DWORD GetLastError(void);

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
-- Linux Backend
--------------------------------------------------------------------------------
local LinuxBackend = {}

function LinuxBackend.get_process_list()
    local procs = {}
    local dir = ffi.C.opendir("/proc")
    if dir == nil then return procs end

    while true do
        local ent = ffi.C.readdir(dir)
        if ent == nil then break end
        local d_name = ffi.string(ent.d_name)
        local pid = tonumber(d_name)
        if pid then
            local info = LinuxBackend.get_proc_summary(pid)
            if info then
                table.insert(procs, info)
            end
        end
    end
    ffi.C.closedir(dir)

    table.sort(procs, function(a, b) return (a.rss or 0) > (b.rss or 0) end)
    return procs
end

function LinuxBackend.get_proc_summary(pid)
    local status_file = io.open(string.format("/proc/%d/status", pid), "r")
    if not status_file then return nil end

    local name = "?"
    local user = "?"
    local rss_kb = 0
    local ppid = 0
    local state = "?"

    for line in status_file:lines() do
        local k, v = line:match("^(%w+):%s*(.*)$")
        if k == "Name" then
            name = v
        elseif k == "State" then
            state = v:match("^(%S+)") or v
        elseif k == "PPid" then
            ppid = tonumber(v) or 0
        elseif k == "VmRSS" then
            rss_kb = tonumber(v:match("(%d+)")) or 0
        elseif k == "Uid" then
            local uid = tonumber(v:match("(%d+)")) or 0
            user = (uid == 0) and "root" or tostring(uid)
        end
    end
    status_file:close()

    local cmd = ""
    local cmd_file = io.open(string.format("/proc/%d/cmdline", pid), "rb")
    if cmd_file then
        local raw = cmd_file:read("*all")
        cmd_file:close()
        if raw and #raw > 0 then
            cmd = raw:gsub("%z", " "):gsub("%s+$", "")
        end
    end
    if cmd == "" then
        cmd = "[" .. name .. "]"
    end

    local rss_mb = math.floor((rss_kb / 1024) * 10) / 10

    return {
        pid = pid,
        name = name,
        user = user,
        ppid = ppid,
        state = state,
        rss = rss_mb,
        cmd = cmd
    }
end

function LinuxBackend.get_proc_details(pid)
    local summary = LinuxBackend.get_proc_summary(pid)
    if not summary then return nil end

    -- Read exe link
    local buf = ffi.new("char[1024]")
    local len = ffi.C.readlink(string.format("/proc/%d/exe", pid), buf, 1023)
    local exe = (len > 0) and ffi.string(buf, len) or "N/A"

    -- Read cwd link
    len = ffi.C.readlink(string.format("/proc/%d/cwd", pid), buf, 1023)
    local cwd = (len > 0) and ffi.string(buf, len) or "N/A"

    -- Extended status
    local threads = 1
    local vms_kb = 0
    local status_file = io.open(string.format("/proc/%d/status", pid), "r")
    if status_file then
        for line in status_file:lines() do
            local k, v = line:match("^(%w+):%s*(.*)$")
            if k == "Threads" then
                threads = tonumber(v) or 1
            elseif k == "VmSize" then
                vms_kb = tonumber(v:match("(%d+)")) or 0
            end
        end
        status_file:close()
    end

    summary.exe = exe
    summary.cwd = cwd
    summary.threads = threads
    summary.vms = math.floor((vms_kb / 1024) * 10) / 10
    return summary
end

function LinuxBackend.kill_process(pid, sig)
    sig = sig or 15 -- SIGTERM
    local res = ffi.C.kill(pid, sig)
    if res == 0 then
        return true
    else
        local err = ffi.string(ffi.C.strerror(ffi.errno()))
        return false, err
    end
end

--------------------------------------------------------------------------------
-- Windows Backend
--------------------------------------------------------------------------------
local WindowsBackend = {}

local TH32CS_SNAPPROCESS = 0x00000002
local PROCESS_TERMINATE = 0x0001
local PROCESS_QUERY_LIMITED_INFORMATION = 0x1000

function WindowsBackend.get_process_list()
    local procs = {}
    local hSnap = ffi.C.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    if hSnap == nil or hSnap == ffi.cast("HANDLE", -1) then
        return procs
    end

    local pe = ffi.new("PROCESSENTRY32")
    pe.dwSize = ffi.sizeof("PROCESSENTRY32")

    if ffi.C.Process32First(hSnap, pe) ~= 0 then
        repeat
            local pid = tonumber(pe.th32ProcessID)
            if pid > 0 then
                local name = ffi.string(pe.szExeFile)
                table.insert(procs, {
                    pid = pid,
                    name = name,
                    user = "User",
                    ppid = tonumber(pe.th32ParentProcessID),
                    threads = tonumber(pe.cntThreads),
                    rss = 0,
                    cmd = name
                })
            end
        until ffi.C.Process32Next(hSnap, pe) == 0
    end
    ffi.C.CloseHandle(hSnap)
    return procs
end

function WindowsBackend.get_proc_details(pid)
    local procs = WindowsBackend.get_process_list()
    local target = nil
    for _, p in ipairs(procs) do
        if p.pid == pid then
            target = p
            break
        end
    end
    if not target then return nil end

    local hProc = ffi.C.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, pid)
    local exe_path = "Access Denied / Protected"
    if hProc ~= nil and hProc ~= ffi.cast("HANDLE", 0) then
        local buf = ffi.new("char[1024]")
        local sz = ffi.new("DWORD[1]", 1024)
        if ffi.C.QueryFullProcessImageNameA(hProc, 0, buf, sz) ~= 0 then
            exe_path = ffi.string(buf, sz[0])
        end
        ffi.C.CloseHandle(hProc)
    end
    target.exe = exe_path
    return target
end

function WindowsBackend.kill_process(pid, _)
    local hProc = ffi.C.OpenProcess(PROCESS_TERMINATE, 0, pid)
    if hProc == nil or hProc == ffi.cast("HANDLE", 0) then
        return false, "Failed to open process (Access Denied / PID not found)"
    end
    local ok = ffi.C.TerminateProcess(hProc, 1)
    ffi.C.CloseHandle(hProc)
    if ok ~= 0 then
        return true
    else
        return false, "TerminateProcess failed"
    end
end

--------------------------------------------------------------------------------
-- Active Backend Selector
--------------------------------------------------------------------------------
local Backend = IS_WINDOWS and WindowsBackend or LinuxBackend

--------------------------------------------------------------------------------
-- Action: Print Preview Card (for FZF live preview)
--------------------------------------------------------------------------------
local function render_preview(pid)
    local info = Backend.get_proc_details(pid)
    if not info then
        io.write(string.format("%s[Process %d not found or terminated]%s\n", C.red, pid, C.reset))
        return
    end

    local border = string.rep("─", 54)
    io.write(string.format("%s┌%s┐%s\n", C.b_cyan, border, C.reset))
    io.write(string.format("%s│ %s%-52s%s │%s\n", C.b_cyan, C.b_yellow, string.format("PROCESS PREVIEW: %s (PID: %d)", info.name, info.pid), C.b_cyan, C.reset))
    io.write(string.format("%s├%s┤%s\n", C.b_cyan, border, C.reset))

    local function field(label, val, color)
        color = color or C.white
        io.write(string.format("%s│%s %s%-14s%s: %s%-36s%s %s│%s\n",
            C.b_cyan, C.reset,
            C.bold, label, C.reset,
            color, tostring(val):sub(1, 36), C.reset,
            C.b_cyan, C.reset))
    end

    field("Process Name", info.name, C.green)
    field("PID", info.pid, C.b_yellow)
    field("Parent PID", info.ppid or "N/A", C.white)
    field("User", info.user or "N/A", C.magenta)
    if info.state then field("State", info.state, C.cyan) end
    if info.threads then field("Threads", info.threads, C.white) end
    if info.rss and info.rss > 0 then field("Resident Mem", string.format("%.1f MB", info.rss), C.b_yellow) end
    if info.vms and info.vms > 0 then field("Virtual Mem", string.format("%.1f MB", info.vms), C.dim) end
    if info.cwd then field("Working Dir", info.cwd, C.white) end
    field("Executable", info.exe or "N/A", C.blue)

    io.write(string.format("%s├%s┤%s\n", C.b_cyan, border, C.reset))
    io.write(string.format("%s│ %s%-52s%s │%s\n", C.b_cyan, C.b_yellow, "COMMAND LINE:", C.b_cyan, C.reset))

    local cmd = info.cmd or info.name
    local max_w = 52
    for i = 1, #cmd, max_w do
        local chunk = cmd:sub(i, i + max_w - 1)
        io.write(string.format("%s│%s %-52s %s│%s\n", C.b_cyan, C.reset, chunk, C.b_cyan, C.reset))
    end

    io.write(string.format("%s└%s┘%s\n", C.b_cyan, border, C.reset))
end

--------------------------------------------------------------------------------
-- Action: Print Process List Table
--------------------------------------------------------------------------------
local function print_list()
    local procs = Backend.get_process_list()
    io.write(string.format("%-8s %-10s %-10s %-25s %s\n", "PID", "USER", "MEM(MB)", "NAME", "COMMAND"))
    for _, p in ipairs(procs) do
        local mem_str = (p.rss and p.rss > 0) and string.format("%.1f", p.rss) or "-"
        local cmd_sample = (p.cmd or p.name):gsub("\n", " ")
        io.write(string.format("%-8d %-10s %-10s %-25s %s\n",
            p.pid,
            (p.user or "-"):sub(1, 10),
            mem_str,
            p.name:sub(1, 25),
            cmd_sample:sub(1, 80)
        ))
    end
end

--------------------------------------------------------------------------------
-- Action: Kill Process
--------------------------------------------------------------------------------
local function kill_pid(pid, sig)
    local ok, err = Backend.kill_process(pid, sig)
    if ok then
        io.write(string.format("%s✔ Successfully killed PID %d%s\n", C.green, pid, C.reset))
        return true
    else
        io.write(string.format("%s✘ Failed to kill PID %d: %s%s\n", C.red, pid, err or "error", C.reset))
        return false
    end
end

local function kill_by_name(name, sig)
    local procs = Backend.get_process_list()
    local target_name = name:lower()
    local matched = {}

    for _, p in ipairs(procs) do
        if p.name:lower():find(target_name, 1, true) then
            table.insert(matched, p)
        end
    end

    if #matched == 0 then
        io.write(string.format("%sNo running processes matched '%s'%s\n", C.yellow, name, C.reset))
        return
    end

    io.write(string.format("%sFound %d matching process(es) for '%s':%s\n", C.cyan, #matched, name, C.reset))
    for _, p in ipairs(matched) do
        kill_pid(p.pid, sig)
    end
end

--------------------------------------------------------------------------------
-- Action: Interactive FZF mode
--------------------------------------------------------------------------------
local function interactive_fzf()
    local script_path = debug.getinfo(1, "S").source:sub(2)
    -- Normalize absolute path
    if not script_path:match("^/") and not script_path:match("^%a:[/\\]") then
        local pwd = io.popen(IS_WINDOWS and "cd" or "pwd 2>/dev/null || pwd"):read("*line") or "."
        script_path = pwd .. "/" .. script_path
    end

    local preview_cmd = string.format("luajit %q --preview {1}", script_path)
    local list_cmd    = string.format("luajit %q --list", script_path)

    local fzf_cmd = string.format(
        '%s | fzf -m --header-lines=1 --prompt="[LuaJIT] Kill Process > " ' ..
        '--header="LuaJIT FFI | [Tab]: Multi-select | [Enter]: Kill | [Esc]: Cancel" ' ..
        '--preview=%q --preview-window=right:50%%:wrap',
        list_cmd, preview_cmd
    )

    local pipe = io.popen(fzf_cmd, "r")
    if not pipe then
        io.stderr:write("Error: Failed to execute fzf. Ensure fzf is installed and in PATH.\n")
        os.exit(1)
    end

    local output = pipe:read("*all")
    pipe:close()

    if not output or #output:gsub("%s+", "") == 0 then
        return
    end

    local pids_to_kill = {}
    for line in output:gmatch("[^\r\n]+") do
        local pid = tonumber(line:match("^%s*(%d+)"))
        if pid then
            local name = line:match("^%s*%d+%s+%S+%s+%S+%s+(%S+)") or "unknown"
            table.insert(pids_to_kill, { pid = pid, name = name })
        end
    end

    if #pids_to_kill > 0 then
        io.write(string.format("\n%sTerminating %d selected process(es):%s\n", C.b_yellow, #pids_to_kill, C.reset))
        for _, item in ipairs(pids_to_kill) do
            kill_pid(item.pid, 15)
        end
    end
end

--------------------------------------------------------------------------------
-- CLI Argument Parsing & Entry Point
--------------------------------------------------------------------------------
local function main(args)
    if #args == 0 then
        interactive_fzf()
        return
    end

    local sig = 15 -- SIGTERM
    local arg1 = args[1]

    if arg1 == "--preview" then
        local pid = tonumber(args[2])
        if pid then
            render_preview(pid)
        else
            io.stderr:write("Usage: fkill --preview <PID>\n")
        end
        return
    elseif arg1 == "--list" then
        print_list()
        return
    elseif arg1 == "-h" or arg1 == "--help" then
        io.write([[fkill.lua - Fast Process Killer (LuaJIT FFI)
Usage:
  fkill                     Interactive process selector with live preview (via fzf)
  fkill <PID>               Kill process by numeric PID
  fkill <NAME>              Kill all processes matching NAME (case-insensitive)
  fkill -9 <PID|NAME>       Force kill (SIGKILL)
  fkill --list              Print process list table
  fkill --preview <PID>     Print process details card (for fzf)
]])
        return
    elseif arg1 == "-9" or arg1 == "-f" or arg1 == "--force" then
        sig = 9 -- SIGKILL
        table.remove(args, 1)
        arg1 = args[1]
    end

    if not arg1 then
        interactive_fzf()
        return
    end

    local pid = tonumber(arg1)
    if pid then
        kill_pid(pid, sig)
    else
        kill_by_name(arg1, sig)
    end
end

main({...})
