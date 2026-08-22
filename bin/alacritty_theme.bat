@echo off
setlocal enabledelayedexpansion

:: Capture script and repository directory early before shift affects %0
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "REPO_DIR=%%~fI"
set "ALACRITTY_DIR=%APPDATA%\alacritty"
set "THEMES_DIR=%ALACRITTY_DIR%\themes"
set "TARGET_FILE=%ALACRITTY_DIR%\theme.toml"
set "REPO_THEMES=!REPO_DIR!\.config\alacritty\themes"
set "REPO_TARGET=!REPO_DIR!\.config\alacritty\theme.toml"

:: Parse command-line flags (-w / --window / -l / --local / -h / --help)
set "WINDOW_ONLY=0"
set "QUERY="

:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="-w" (set "WINDOW_ONLY=1" & shift & goto :parse_args)
if /i "%~1"=="--window" (set "WINDOW_ONLY=1" & shift & goto :parse_args)
if /i "%~1"=="-l" (set "WINDOW_ONLY=1" & shift & goto :parse_args)
if /i "%~1"=="--local" (set "WINDOW_ONLY=1" & shift & goto :parse_args)
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="/?" goto :show_help
if not defined QUERY set "QUERY=%~1"
shift
goto :parse_args
:args_done

:: Fallback to repository directory if APPDATA themes not yet deployed
if not exist "%THEMES_DIR%" (
    if exist "!REPO_THEMES!" (
        set "THEMES_DIR=!REPO_THEMES!"
        if not exist "%ALACRITTY_DIR%" mkdir "%ALACRITTY_DIR%" 2>nul
    )
)

if not exist "%THEMES_DIR%" (
    echo [ERROR] Alacritty themes directory not found.
    echo Expected at: "%ALACRITTY_DIR%\themes" or "!REPO_THEMES!"
    exit /b 1
)

set "SELECTED_THEME="

:: If theme name is provided as argument, check directly
if not "%QUERY%"=="" (
    if exist "%THEMES_DIR%\%QUERY%.toml" (
        set "SELECTED_THEME=%QUERY%"
    ) else if exist "%THEMES_DIR%\%QUERY%" (
        for %%A in ("%QUERY%") do set "SELECTED_THEME=%%~nA"
    ) else (
        :: Case-insensitive / partial prefix search
        for %%F in ("%THEMES_DIR%\*%QUERY%*.toml") do (
            if not defined SELECTED_THEME set "SELECTED_THEME=%%~nF"
        )
    )
    if not defined SELECTED_THEME (
        echo [ERROR] Theme "%QUERY%" not found in "%THEMES_DIR%".
        echo Available themes:
        for /f "delims=" %%F in ('dir /b /a-d "%THEMES_DIR%\*.toml" 2^>nul') do echo   - %%~nF
        exit /b 1
    )
) else (
    :: Interactive selection via fzf or fallback prompt
    where fzf >nul 2>&1
    if !errorlevel! equ 0 (
        set "TMP_THEMES=%TEMP%\alacritty_themes_%RANDOM%.txt"
        set "TMP_OUT=%TEMP%\alacritty_theme_%RANDOM%.txt"
        (for /f "delims=" %%F in ('dir /b /a-d "%THEMES_DIR%\*.toml" 2^>nul') do @echo %%~nF) > "!TMP_THEMES!"
        type "!TMP_THEMES!" | fzf --prompt="Select Alacritty Theme > " --preview="type \"%THEMES_DIR%\{}.toml\"" --layout=reverse --height=40%% --border > "!TMP_OUT!"
        if exist "!TMP_THEMES!" del "!TMP_THEMES!" 2>nul
        if exist "!TMP_OUT!" (
            for /f "usebackq delims=" %%I in ("!TMP_OUT!") do (
                set "SELECTED_THEME=%%~nI"
                if "!SELECTED_THEME!"=="" set "SELECTED_THEME=%%I"
            )
            del "!TMP_OUT!" 2>nul
        )
    ) else (
        echo Available Alacritty Themes:
        set /a count=0
        for /f "delims=" %%F in ('dir /b /a-d "%THEMES_DIR%\*.toml" 2^>nul') do (
            set /a count+=1
            echo   !count!. %%~nF
            set "theme_!count!=%%~nF"
        )
        set /p "CHOICE=Select theme number or name: "
        if defined CHOICE (
            if defined theme_!CHOICE! (
                set "SELECTED_THEME=!theme_%CHOICE%!"
            ) else (
                set "SELECTED_THEME=!CHOICE!"
            )
        )
    )
)

if "%SELECTED_THEME%"=="" (
    echo No theme selected.
    exit /b 0
)

:: Strip any leading/trailing whitespace
for /f "tokens=* delims= " %%A in ("!SELECTED_THEME!") do set "SELECTED_THEME=%%A"
:trim_loop
if "!SELECTED_THEME:~-1!"==" " (
    set "SELECTED_THEME=!SELECTED_THEME:~0,-1!"
    goto trim_loop
)

set "SRC_FILE=%THEMES_DIR%\%SELECTED_THEME%.toml"
if not exist "%SRC_FILE%" (
    echo [ERROR] Theme file "%SRC_FILE%" does not exist.
    exit /b 1
)

if "%WINDOW_ONLY%"=="1" (
    call :apply_osc "%SRC_FILE%"
    echo [Alacritty] Switched current window theme to: %SELECTED_THEME%
    exit /b 0
)

:: Copy to APPDATA
if not exist "%ALACRITTY_DIR%" mkdir "%ALACRITTY_DIR%" 2>nul
copy /Y "%SRC_FILE%" "%TARGET_FILE%" >nul 2>&1
if !errorlevel! equ 0 (
    echo [Alacritty] Switched theme to: %SELECTED_THEME%
) else (
    echo [ERROR] Failed to write theme to "%TARGET_FILE%".
    exit /b 1
)

:: Also update repository theme.toml if inside repo
if exist "!REPO_DIR!\.config\alacritty\." (
    copy /Y "%SRC_FILE%" "!REPO_TARGET!" >nul 2>&1
)

endlocal
exit /b 0

:apply_osc
for /f %%a in ('echo prompt $E^| cmd') do set "ESC=%%a"
set "SECTION="
for /f "usebackq tokens=1* delims==" %%A in ("%~1") do (
    set "KEY_RAW=%%A"
    set "VAL_RAW=%%B"
    set "KEY=!KEY_RAW: =!"
    set "VAL=!VAL_RAW: =!"
    set "VAL=!VAL:"=!"
    set "VAL=!VAL:'=!"
    if "!KEY:~0,1!"=="[" (
        set "SECTION=!KEY!"
    ) else if not "!VAL!"=="" (
        if "!SECTION!"=="[colors.primary]" (
            if /i "!KEY!"=="background" <nul set /p "=!ESC!]11;!VAL!!ESC!\"
            if /i "!KEY!"=="foreground" <nul set /p "=!ESC!]10;!VAL!!ESC!\"
        ) else if "!SECTION!"=="[colors.cursor]" (
            if /i "!KEY!"=="cursor"     <nul set /p "=!ESC!]12;!VAL!!ESC!\"
        ) else if "!SECTION!"=="[colors.normal]" (
            if /i "!KEY!"=="black"   <nul set /p "=!ESC!]4;0;!VAL!!ESC!\"
            if /i "!KEY!"=="red"     <nul set /p "=!ESC!]4;1;!VAL!!ESC!\"
            if /i "!KEY!"=="green"   <nul set /p "=!ESC!]4;2;!VAL!!ESC!\"
            if /i "!KEY!"=="yellow"  <nul set /p "=!ESC!]4;3;!VAL!!ESC!\"
            if /i "!KEY!"=="blue"    <nul set /p "=!ESC!]4;4;!VAL!!ESC!\"
            if /i "!KEY!"=="magenta" <nul set /p "=!ESC!]4;5;!VAL!!ESC!\"
            if /i "!KEY!"=="cyan"    <nul set /p "=!ESC!]4;6;!VAL!!ESC!\"
            if /i "!KEY!"=="white"   <nul set /p "=!ESC!]4;7;!VAL!!ESC!\"
        ) else if "!SECTION!"=="[colors.bright]" (
            if /i "!KEY!"=="black"   <nul set /p "=!ESC!]4;8;!VAL!!ESC!\"
            if /i "!KEY!"=="red"     <nul set /p "=!ESC!]4;9;!VAL!!ESC!\"
            if /i "!KEY!"=="green"   <nul set /p "=!ESC!]4;10;!VAL!!ESC!\"
            if /i "!KEY!"=="yellow"  <nul set /p "=!ESC!]4;11;!VAL!!ESC!\"
            if /i "!KEY!"=="blue"    <nul set /p "=!ESC!]4;12;!VAL!!ESC!\"
            if /i "!KEY!"=="magenta" <nul set /p "=!ESC!]4;13;!VAL!!ESC!\"
            if /i "!KEY!"=="cyan"    <nul set /p "=!ESC!]4;14;!VAL!!ESC!\"
            if /i "!KEY!"=="white"   <nul set /p "=!ESC!]4;15;!VAL!!ESC!\"
        )
    )
)
exit /b 0

:show_help
echo Usage: theme [OPTIONS] [THEME_NAME]
echo.
echo Options:
echo   -w, --window, -l, --local  Apply theme to current window only (via OSC sequences)
echo   -h, --help                 Show this help message
exit /b 0
