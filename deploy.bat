@echo off
setlocal enabledelayedexpansion

:: Get the directory where the script is located (Capture early because shift affects %0)
set "REPO_DIR=%~dp0"
set "REPO_DIR=%REPO_DIR:~0,-1%"

:: Default choice
set "NVIM_CHOICE=lua"

:: Parse arguments
:parse_args
if "%~1"=="" goto :end_parse
if /i "%~1"=="/h" goto :show_help
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="/help" goto :show_help
if /i "%~1"=="/v" set "NVIM_CHOICE=vim"
if /i "%~1"=="--vim" set "NVIM_CHOICE=vim"
if /i "%~1"=="/l" set "NVIM_CHOICE=lua"
if /i "%~1"=="--lua" set "NVIM_CHOICE=lua"
shift
goto :parse_args
:end_parse

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
if "%NVIM_CHOICE%"=="lua" (
    :: Deploy Neovim Lua configuration
    if exist "%REPO_DIR%\.config\nvim" (
        if not exist "%LOCALAPPDATA%\nvim" mkdir "%LOCALAPPDATA%\nvim"
        if exist "%LOCALAPPDATA%\nvim\init.vim" del /Q "%LOCALAPPDATA%\nvim\init.vim"
        xcopy /Y /S /E "%REPO_DIR%\.config\nvim\*" "%LOCALAPPDATA%\nvim\"
        echo Deployed Neovim configuration to %LOCALAPPDATA%\nvim
    )
) else (
    echo Deploying Neovim Vimscript configuration...
    :: Remove Lua config directory if it exists to avoid conflicts
    if exist "%LOCALAPPDATA%\nvim\lua" rd /S /Q "%LOCALAPPDATA%\nvim\lua"
    if exist "%LOCALAPPDATA%\nvim\init.lua" del /Q "%LOCALAPPDATA%\nvim\init.lua"
    call :deploy_file "%REPO_DIR%\myvimrc" "%LOCALAPPDATA%\nvim\init.vim"
)

:: Set Environment Variables
echo Setting Environment Variables...
setx RIPGREP_CONFIG_PATH "%USERPROFILE%\.ripgreprc"
setx FZF_DEFAULT_COMMAND "fd --follow --hidden --exclude .git --ignore-file \"%APPDATA%\fd\ignore\""
setx FZF_DEFAULT_OPTS "--preview \"bat --color=always {}\""

:: Add C:\app\bin to User PATH if not already present
echo Adding C:\app\bin to PATH...
powershell -Command "$p = [Environment]::GetEnvironmentVariable('PATH', 'User'); if ($p -notlike '*C:\app\bin*') { [Environment]::SetEnvironmentVariable('PATH', $p + ';C:\app\bin', 'User') }"

echo.
echo Deployment complete!
echo Note: Environment variables (including PATH) will take effect in NEW terminal windows.
goto :eof

:show_help
echo Usage: deploy.bat [OPTIONS]
echo.
echo Options:
echo   /h, --help      Show this help message
echo   /v, --vim       Use myvimrc as init.vim (Vimscript style)
echo   /l, --lua       Use .config/nvim as Neovim config (Lua style, default)
echo.
echo By default, Neovim Lua configuration is deployed.
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
