@echo off
setlocal enabledelayedexpansion

:: Get the directory where the script is located (Capture early because shift affects %0)
set "REPO_DIR=%~dp0"
set "REPO_DIR=%REPO_DIR:~0,-1%"

:: Destination for binaries
set "BIN_DIR=C:\app\bin"

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

:: 1. Deploy binaries to %BIN_DIR%
echo [1/2] Deploying binaries...
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"
xcopy /Y /S /E "%REPO_DIR%\bin\*" "%BIN_DIR%\"

:: 2. Deploy application configurations
echo [2/2] Deploying configurations...

:: Helper to deploy a file (creates directory and copies)
call :deploy_file "%REPO_DIR%\.config\lf\lfrc_windows" "%APPDATA%\lf\lfrc"
call :deploy_file "%REPO_DIR%\.config\lf\icons"        "%APPDATA%\lf\icons"
call :deploy_file "%REPO_DIR%\.config\lf\colors"       "%APPDATA%\lf\colors"
call :deploy_file "%REPO_DIR%\.config\fd\ignore"      "%APPDATA%\fd\ignore"
call :deploy_file "%REPO_DIR%\.ripgreprc"             "%USERPROFILE%\.ripgreprc"
call :deploy_file "%REPO_DIR%\.gitconfig"             "%USERPROFILE%\.gitconfig"
call :deploy_file "%REPO_DIR%\.config\git\ignore"     "%USERPROFILE%\.config\git\ignore"
call :deploy_file "%REPO_DIR%\myvimrc"                "%USERPROFILE%\_vimrc"
call :deploy_file "%REPO_DIR%\.vifm\vifmrc"           "%APPDATA%\vifm\vifmrc"
call :deploy_file "%REPO_DIR%\.gdbinit"               "%USERPROFILE%\.gdbinit"

:: Git Bash / Mintty configuration
set "GIT_BASH_FOUND=0"
where git >nul 2>nul
if %ERRORLEVEL% equ 0 set "GIT_BASH_FOUND=1"
if exist "%ProgramFiles%\Git" set "GIT_BASH_FOUND=1"
if exist "%ProgramFiles(x86)%\Git" set "GIT_BASH_FOUND=1"
if exist "%LocalAppData%\Programs\Git" set "GIT_BASH_FOUND=1"

if "%GIT_BASH_FOUND%"=="1" (
    call :deploy_file "%REPO_DIR%\.minttyrc" "%USERPROFILE%\.minttyrc"
)

:: Ranger configuration
call :deploy_file "%REPO_DIR%\.config\ranger\rc.conf"      "%APPDATA%\ranger\rc.conf"
call :deploy_file "%REPO_DIR%\.config\ranger\commands.py"  "%APPDATA%\ranger\commands.py"
call :deploy_file "%REPO_DIR%\.config\ranger\scope.sh"     "%APPDATA%\ranger\scope.sh"
if exist "%REPO_DIR%\.config\ranger\colorschemes" (
    if not exist "%APPDATA%\ranger\colorschemes" mkdir "%APPDATA%\ranger\colorschemes"
    xcopy /Y /S /E "%REPO_DIR%\.config\ranger\colorschemes\*" "%APPDATA%\ranger\colorschemes\"
)

:: Yazi configuration
call :deploy_file "%REPO_DIR%\.config\yazi\theme.toml"  "%APPDATA%\yazi\config\theme.toml"
call :deploy_file "%REPO_DIR%\.config\yazi\keymap.toml" "%APPDATA%\yazi\config\keymap.toml"
call :deploy_file "%REPO_DIR%\.config\yazi\yazi.toml"   "%APPDATA%\yazi\config\yazi.toml"

:: PuTTY theme collection deployment
if exist "%REPO_DIR%\.config\putty\themes" (
    if not exist "%APPDATA%\putty\themes" mkdir "%APPDATA%\putty\themes"
    xcopy /Y /S /E "%REPO_DIR%\.config\putty\themes\*" "%APPDATA%\putty\themes\"
)

:: MPV configuration and plugins (uosc, mpv-cut, thumbfast, autoload, quality-menu)
call :deploy_file "%REPO_DIR%\.config\mpv\mpv.conf" "%APPDATA%\mpv\mpv.conf"
set "MPV_DIR=%APPDATA%\mpv"
set "UOSC_REPO=%MPV_DIR%\uosc"
set "MPV_CUT_DIR=%MPV_DIR%\scripts\mpv-cut"
set "THUMBFAST_REPO=%MPV_DIR%\thumbfast"
set "QUALITY_MENU_REPO=%MPV_DIR%\quality-menu"
set "SPONSORBLOCK_REPO=%MPV_DIR%\sponsorblock"


if not exist "%MPV_DIR%\scripts" mkdir "%MPV_DIR%\scripts"
if not exist "%MPV_DIR%\fonts" mkdir "%MPV_DIR%\fonts"
if not exist "%MPV_DIR%\script-opts" mkdir "%MPV_DIR%\script-opts"

where git >nul 2>nul
if %ERRORLEVEL% equ 0 (
    :: 1. uosc plugin
    if not exist "%UOSC_REPO%" (
        echo Cloning uosc for mpv...
        git clone --depth 1 https://github.com/tomasklaen/uosc.git "%UOSC_REPO%"
    )
    if exist "%UOSC_REPO%" (
        echo Deploying uosc components for mpv...
        if exist "%UOSC_REPO%\src\uosc" (
            if not exist "%MPV_DIR%\scripts\uosc" mkdir "%MPV_DIR%\scripts\uosc"
            xcopy /Y /S /E "%UOSC_REPO%\src\uosc\*" "%MPV_DIR%\scripts\uosc\" >nul
        )
        if exist "%UOSC_REPO%\src\fonts" (
            xcopy /Y /S /E "%UOSC_REPO%\src\fonts\*" "%MPV_DIR%\fonts\" >nul
        )
        if exist "%UOSC_REPO%\src\uosc.conf" (
            if not exist "%MPV_DIR%\script-opts\uosc.conf" (
                copy /Y "%UOSC_REPO%\src\uosc.conf" "%MPV_DIR%\script-opts\uosc.conf" >nul
            )
        )
    )

    :: 2. mpv-cut plugin
    if not exist "%MPV_CUT_DIR%" (
        echo Cloning mpv-cut for mpv...
        git clone -b release --single-branch --depth 1 https://github.com/familyfriendlymikey/mpv-cut.git "%MPV_CUT_DIR%" 2>nul || git clone --depth 1 https://github.com/familyfriendlymikey/mpv-cut.git "%MPV_CUT_DIR%"
    )

    :: 3. thumbfast plugin
    if not exist "%THUMBFAST_REPO%" (
        echo Cloning thumbfast for mpv...
        git clone --depth 1 https://github.com/po5/thumbfast.git "%THUMBFAST_REPO%"
    )
    if exist "%THUMBFAST_REPO%" (
        echo Deploying thumbfast for mpv...
        if exist "%THUMBFAST_REPO%\thumbfast.lua" (
            copy /Y "%THUMBFAST_REPO%\thumbfast.lua" "%MPV_DIR%\scripts\thumbfast.lua" >nul
        )
        if exist "%THUMBFAST_REPO%\thumbfast.conf" (
            if not exist "%MPV_DIR%\script-opts\thumbfast.conf" (
                copy /Y "%THUMBFAST_REPO%\thumbfast.conf" "%MPV_DIR%\script-opts\thumbfast.conf" >nul
            )
        )
    )

    :: 4. quality-menu plugin
    if not exist "%QUALITY_MENU_REPO%" (
        echo Cloning quality-menu for mpv...
        git clone --depth 1 https://github.com/christoph-heinrich/mpv-quality-menu.git "%QUALITY_MENU_REPO%"
    )
    if exist "%QUALITY_MENU_REPO%" (
        echo Deploying quality-menu for mpv...
        if exist "%QUALITY_MENU_REPO%\quality-menu.lua" (
            copy /Y "%QUALITY_MENU_REPO%\quality-menu.lua" "%MPV_DIR%\scripts\quality-menu.lua" >nul
        )
        if exist "%QUALITY_MENU_REPO%\quality-menu.conf" (
            if not exist "%MPV_DIR%\script-opts\quality-menu.conf" (
                copy /Y "%QUALITY_MENU_REPO%\quality-menu.conf" "%MPV_DIR%\script-opts\quality-menu.conf" >nul
            )
        )
    )

    :: 5. sponsorblock plugin
    if not exist "%SPONSORBLOCK_REPO%" (

        echo Cloning sponsorblock for mpv...
        git clone --depth 1 https://github.com/po5/mpv_sponsorblock.git "%SPONSORBLOCK_REPO%"
    )
    if exist "%SPONSORBLOCK_REPO%" (
        echo Deploying sponsorblock for mpv...
        if exist "%SPONSORBLOCK_REPO%\sponsorblock.lua" (
            copy /Y "%SPONSORBLOCK_REPO%\sponsorblock.lua" "%MPV_DIR%\scripts\sponsorblock.lua" >nul
        )
        if exist "%SPONSORBLOCK_REPO%\sponsorblock_shared" (
            if not exist "%MPV_DIR%\scripts\sponsorblock_shared" mkdir "%MPV_DIR%\scripts\sponsorblock_shared"
            xcopy /Y /S /E "%SPONSORBLOCK_REPO%\sponsorblock_shared\*" "%MPV_DIR%\scripts\sponsorblock_shared\" >nul
        )
    )
)

:: 6. autoload script

if not exist "%MPV_DIR%\scripts\autoload.lua" (
    echo Downloading autoload.lua for mpv...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri https://raw.githubusercontent.com/mpv-player/mpv/master/TOOLS/lua/autoload.lua -OutFile '%MPV_DIR%\scripts\autoload.lua'"
)

:: 7. mpv-webm script
if not exist "%MPV_DIR%\scripts\webm.lua" (
    echo Downloading webm.lua for mpv...
    powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri https://github.com/ekisu/mpv-webm/releases/download/latest/webm.lua -OutFile '%MPV_DIR%\scripts\webm.lua'"
)





:: Neovim configuration selection
if "%NVIM_CHOICE%"=="lua" (
    :: Deploy Neovim Lua configuration
    if exist "%REPO_DIR%\.config\nvim" (
        if not exist "%LOCALAPPDATA%\nvim" mkdir "%LOCALAPPDATA%\nvim"
        if exist "%LOCALAPPDATA%\nvim\init.vim" del /Q "%LOCALAPPDATA%\nvim\init.vim"
        xcopy /Y /S /E "%REPO_DIR%\.config\nvim\*" "%LOCALAPPDATA%\nvim\"
        echo Deployed Neovim configuration to %LOCALAPPDATA%\nvim

        :: Install vim-plug for Neovim
        call :install_plug_nvim
    )
) else (
    echo Deploying Neovim Vimscript configuration...
    :: Remove Lua config directory if it exists to avoid conflicts
    if exist "%LOCALAPPDATA%\nvim\lua" rd /S /Q "%LOCALAPPDATA%\nvim\lua"
    if exist "%LOCALAPPDATA%\nvim\init.lua" del /Q "%LOCALAPPDATA%\nvim\init.lua"
    call :deploy_file "%REPO_DIR%\myvimrc" "%LOCALAPPDATA%\nvim\init.vim"
    
    :: Install vim-plug for Neovim (Vimscript mode)
    call :install_plug_nvim
)

:: Install vim-plug for standard Vim
echo Installing vim-plug for Vim...
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $p = \"$env:USERPROFILE\vimfiles\autoload\plug.vim\"; if (-not (Test-Path $p)) { iwr -useb https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim | ni $p -Force }"

:: Link .vim/autoload and .vim/plugged to vimfiles equivalents for Git Bash/MSYS2 Vim compatibility
echo Linking .vim directories for Git Bash/MSYS2 compatibility...
if not exist "%USERPROFILE%\.vim" mkdir "%USERPROFILE%\.vim"
if not exist "%USERPROFILE%\.vim\autoload" mklink /J "%USERPROFILE%\.vim\autoload" "%USERPROFILE%\vimfiles\autoload"
if not exist "%USERPROFILE%\.vim\plugged" mklink /J "%USERPROFILE%\.vim\plugged" "%USERPROFILE%\vimfiles\plugged"

:: Set Environment Variables
echo Setting Environment Variables...
setx RIPGREP_CONFIG_PATH "%USERPROFILE%\.ripgreprc"
setx FZF_DEFAULT_COMMAND "fd --follow --hidden --exclude .git --ignore-file \"%APPDATA%\fd\ignore\""
setx FZF_DEFAULT_OPTS "--preview \"bat --color=always {}\""

:: Set Yazi MIME detector path
set "YAZI_FILE_PATH="
if exist "%ProgramFiles%\Git\usr\bin\file.exe" set "YAZI_FILE_PATH=%ProgramFiles%\Git\usr\bin\file.exe"
if not defined YAZI_FILE_PATH if exist "%ProgramFiles(x86)%\Git\usr\bin\file.exe" set "YAZI_FILE_PATH=%ProgramFiles(x86)%\Git\usr\bin\file.exe"
if not defined YAZI_FILE_PATH if exist "%LocalAppData%\Programs\Git\usr\bin\file.exe" set "YAZI_FILE_PATH=%LocalAppData%\Programs\Git\usr\bin\file.exe"
if not defined YAZI_FILE_PATH if exist "C:\cygwin64\bin\file.exe" set "YAZI_FILE_PATH=C:\cygwin64\bin\file.exe"
if defined YAZI_FILE_PATH (
    echo Setting YAZI_FILE_ONE to !YAZI_FILE_PATH!...
    setx YAZI_FILE_ONE "!YAZI_FILE_PATH!"
)

:: Add %BIN_DIR% to User PATH if not already present
echo Adding %BIN_DIR% to PATH...
powershell -Command "$d = '%BIN_DIR%'; $p = [Environment]::GetEnvironmentVariable('PATH', 'User'); if ($p -notlike \"*$d*\") { [Environment]::SetEnvironmentVariable('PATH', $p + ';' + $d, 'User') }"

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

:install_plug_nvim
echo Installing vim-plug for Neovim...
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $p = \"$(@($env:XDG_DATA_HOME, $env:LOCALAPPDATA)[$null -eq $env:XDG_DATA_HOME])\nvim-data\site\autoload\plug.vim\"; if (-not (Test-Path $p)) { iwr -useb https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim | ni $p -Force }"
goto :eof
