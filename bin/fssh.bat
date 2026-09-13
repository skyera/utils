@echo off
where luajit >nul 2>nul
if %errorlevel% equ 0 if exist "%~dp0fssh.lua" (
    luajit "%~dp0fssh.lua" %*
    exit /b %errorlevel%
)
python "%~dp0fssh.py" %*
