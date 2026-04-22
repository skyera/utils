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
echo [2/2] Deploying application configurations...
set "LF_CONFIG_DIR=%LOCALAPPDATA%\lf"
if not exist "%LF_CONFIG_DIR%" mkdir "%LF_CONFIG_DIR%"
set "FD_CONFIG_DIR=%APPDATA%\fd"
if not exist "%FD_CONFIG_DIR%" mkdir "%FD_CONFIG_DIR%"

:: Copy configs
copy /Y "%REPO_DIR%\.config\lf\lfrc_windows" "%LF_CONFIG_DIR%\lfrc"
if exist "%REPO_DIR%\.config\lf\icons" copy /Y "%REPO_DIR%\.config\lf\icons" "%LF_CONFIG_DIR%\icons"
copy /Y "%REPO_DIR%\.config\fd\ignore" "%FD_CONFIG_DIR%\ignore"
copy /Y "%REPO_DIR%\.ripgreprc" "%USERPROFILE%\.ripgreprc"

:: Set Ripgrep Environment Variable
echo Setting RIPGREP_CONFIG_PATH...
setx RIPGREP_CONFIG_PATH "%USERPROFILE%\.ripgreprc"

echo.
echo Deployment complete!
echo Note: Ensure C:\app\bin is in your System PATH to use the tools globally.
pause
