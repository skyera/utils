@echo off
setlocal enabledelayedexpansion

:: Determine Alacritty configuration directory
set "ALACRITTY_DIR=%APPDATA%\alacritty"
set "THEMES_DIR=%ALACRITTY_DIR%\themes"
set "TARGET_FILE=%ALACRITTY_DIR%\theme.toml"

:: Fallback to repository directory if APPDATA themes not yet deployed
if not exist "%THEMES_DIR%" (
    set "REPO_THEMES=%~dp0..\.config\alacritty\themes"
    if exist "!REPO_THEMES!" (
        set "THEMES_DIR=!REPO_THEMES!"
        if not exist "%ALACRITTY_DIR%" mkdir "%ALACRITTY_DIR%" 2>nul
    )
)

if not exist "%THEMES_DIR%" (
    echo [ERROR] Alacritty themes directory not found.
    echo Expected at: "%ALACRITTY_DIR%\themes" or "%~dp0..\.config\alacritty\themes"
    exit /b 1
)

set "QUERY=%~1"
set "SELECTED_THEME="

:: If theme name is provided as argument, check directly
if not "%QUERY%"=="" (
    if exist "%THEMES_DIR%\%QUERY%.toml" (
        set "SELECTED_THEME=%QUERY%"
    ) else if exist "%THEMES_DIR%\%QUERY%" (
        set "SELECTED_THEME=%~n1"
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
set "REPO_TARGET=%~dp0..\.config\alacritty\theme.toml"
if exist "%~dp0..\.config\alacritty" (
    copy /Y "%SRC_FILE%" "%REPO_TARGET%" >nul 2>&1
)

endlocal
