@echo off
setlocal
where luajit >nul 2>nul
if %ERRORLEVEL% equ 0 (
    luajit "%~dp0fssh_tunnel.lua" %*
    exit /b %ERRORLEVEL%
)

echo [ERROR] luajit is required to run fssh_tunnel.lua. 1>&2
exit /b 1
