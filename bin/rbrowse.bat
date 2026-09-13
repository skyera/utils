@echo off
rem rbrowse.bat - Launch rbrowse.lua via LuaJIT on Windows
setlocal
set "SCRIPT_DIR=%~dp0"
luajit "%SCRIPT_DIR%rbrowse.lua" %*
