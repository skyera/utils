@echo off
rem dogit.bat - Launch dogit.lua via LuaJIT on Windows
setlocal
set "SCRIPT_DIR=%~dp0"
luajit "%SCRIPT_DIR%dogit.lua" %*
