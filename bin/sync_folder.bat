@echo off
setlocal

if "%~1"=="" goto help
if "%~1"=="/?" goto help
if "%~1"=="-h" goto help
if "%~1"=="--help" goto help
if "%~1"=="-help" goto help

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync_folder.ps1" %*
exit /b %ERRORLEVEL%

:help
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0sync_folder.ps1' -Help"
exit /b 0
