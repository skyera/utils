@echo off
where luajit >nul 2>nul
if %errorlevel% equ 0 if exist "%~dp0ftheme.lua" (
    luajit "%~dp0ftheme.lua" %*
    exit /b %errorlevel%
)
call "%~dp0alacritty_theme.bat" %*
