@echo off
setlocal enabledelayedexpansion

:: Get the directory where the script is located
set "REPO_DIR=%~dp0"
set "REPO_DIR=%REPO_DIR:~0,-1%"

echo Deploying for Windows...

:: 1. Deploy binaries to C:\app\bin
echo [1/2] Deploying binaries...
if not exist "C:\app\bin" mkdir "C:\app\bin"
xcopy /Y /S /E "%REPO_DIR%\bin\*" "C:\app\bin\"

:: 2. Deploy application configurations
echo [2/2] Deploying configurations...

:: Helper to deploy a file (creates directory and copies)
call :deploy_file "%REPO_DIR%\.config\lf\lfrc_windows" "%LOCALAPPDATA%\lf\lfrc"
call :deploy_file "%REPO_DIR%\.config\lf\icons"        "%LOCALAPPDATA%\lf\icons"
call :deploy_file "%REPO_DIR%\.config\fd\ignore"      "%APPDATA%\fd\ignore"
call :deploy_file "%REPO_DIR%\.ripgreprc"             "%USERPROFILE%\.ripgreprc"
call :deploy_file "%REPO_DIR%\myvimrc"                "%USERPROFILE%\_vimrc"

:: Neovim configuration selection
echo.
echo Select Neovim configuration style:
echo 1) Lua (Modern, faster, separate config) [Default]
echo 2) Vimscript (Legacy, uses myvimrc/init.vim)
set /p NVIM_CHOICE="Enter choice [1-2] (default 1): "
if "!NVIM_CHOICE!"=="" set "NVIM_CHOICE=1"

if "%NVIM_CHOICE%"=="1" (
    :: Deploy Neovim Lua configuration
    if exist "%REPO_DIR%\.config\nvim" (
        if not exist "%LOCALAPPDATA%\nvim" mkdir "%LOCALAPPDATA%\nvim"
        if exist "%LOCALAPPDATA%\nvim\init.vim" del /Q "%LOCALAPPDATA%\nvim\init.vim"
        xcopy /Y /S /E "%REPO_DIR%\.config\nvim\*" "%LOCALAPPDATA%\nvim\"
        echo Deployed Neovim configuration to %LOCALAPPDATA%\nvim
    )
) else if "%NVIM_CHOICE%"=="2" (
    echo Deploying Neovim Vimscript configuration...
    :: Remove Lua config directory if it exists to avoid conflicts
    if exist "%LOCALAPPDATA%\nvim\lua" rd /S /Q "%LOCALAPPDATA%\nvim\lua"
    if exist "%LOCALAPPDATA%\nvim\init.lua" del /Q "%LOCALAPPDATA%\nvim\init.lua"
    call :deploy_file "%REPO_DIR%\myvimrc" "%LOCALAPPDATA%\nvim\init.vim"
) else (
    echo Invalid choice. Skipping Neovim configuration.
)

:: Set Environment Variables
echo Setting Environment Variables...
setx RIPGREP_CONFIG_PATH "%USERPROFILE%\.ripgreprc"
setx FZF_DEFAULT_COMMAND "fd --follow --hidden --exclude .git --ignore-file \"%APPDATA%\fd\ignore\""
setx FZF_DEFAULT_OPTS "--preview \"bat --color=always {}\""

echo.
echo Deployment complete!
echo Note: Environment variables will take effect in NEW terminal windows.
echo Note: Ensure C:\app\bin is in your System PATH.
pause
goto :eof

:deploy_file
set "src=%~1"
set "dest=%~2"
if exist "%src%" (
    for %%I in ("%dest%") do set "dest_dir=%%~dpI"
    if not exist "!dest_dir!" mkdir "!dest_dir!"
    copy /Y "%src%" "%dest%"
    echo Deployed %dest%
)
goto :eof
