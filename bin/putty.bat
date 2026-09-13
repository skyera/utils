@echo off
where luajit >nul 2>nul
if %errorlevel% equ 0 (
    luajit "%~dp0putty.lua" %*
    exit /b %errorlevel%
)
echo [ERROR] luajit is not installed or not in PATH to run putty.lua.
exit /b 1
