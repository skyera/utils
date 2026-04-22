@echo off
setlocal enabledelayedexpansion

:: Get the directory where the script is located
set "REPO_DIR=%~dp0"
set "REPO_DIR=%REPO_DIR:~0,-1%"

echo Deploying for Windows...

:: 1. Deploy binaries to C:\app\bin
echo [1/2] Deploying binaries to C:\app\bin...
if not exist "C:\app\bin" mkdir "C:\app\bin"
xcopy /Y /S /E "%REPO_DIR%\bin\*" "C:\app\bin\"

:: 2. Deploy lf configuration
echo [2/2] Deploying lf configuration...
set "LF_CONFIG_DIR=%LOCALAPPDATA%\lf"
if not exist "%LF_CONFIG_DIR%" mkdir "%LF_CONFIG_DIR%"

:: Copy lfrc_windows to the target location as 'lfrc'
copy /Y "%REPO_DIR%\.config\lf\lfrc_windows" "%LF_CONFIG_DIR%\lfrc"

echo.
echo Deployment complete!
echo Note: Ensure C:\app\bin is in your System PATH to use the tools globally.
pause
