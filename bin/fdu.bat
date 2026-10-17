@echo off
rem fdu.bat - Launch fdu.lua via LuaJIT on Windows
setlocal
where luajit >nul 2>nul
if %ERRORLEVEL% equ 0 (
    luajit "%~dp0fdu.lua" %*
    exit /b %ERRORLEVEL%
)
echo [ERROR] luajit is required to run fdu.lua. 1>&2
exit /b 1
