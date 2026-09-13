@echo off
where luajit >nul 2>nul
if %errorlevel% equ 0 if exist "%~dp0clean_c_drive.lua" (
    luajit "%~dp0clean_c_drive.lua" %*
    exit /b %errorlevel%
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0clean_c_drive.ps1" %*
