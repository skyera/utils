@echo off
rem dotag.bat - Launch dotag.lua via LuaJIT on Windows
setlocal
set "SCRIPT_DIR=%~dp0"
luajit "%SCRIPT_DIR%dotag.lua" %*
