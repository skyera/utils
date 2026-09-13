@echo off
where luajit >nul 2>nul
if %errorlevel% equ 0 if exist "%~dp0putty.lua" (
    luajit "%~dp0putty.lua" colors %*
    exit /b %errorlevel%
)
python "%~dp0putty_colors.py" %*
