@echo off
setlocal enabledelayedexpansion

set "BASE_DIR=%~1"
if "%BASE_DIR%"=="" set "BASE_DIR=."

:: Determine directory previewer (prefer eza if installed)
set "PREVIEW_CMD=cmd /c dir /b \"{}\" 2>nul"
where eza >nul 2>nul
if %errorlevel%==0 set "PREVIEW_CMD=eza --tree --level=2 --icons=always --color=always {} 2>nul"

set "TMP_OUT=%TEMP%\fcd_res_%RANDOM%.txt"

:: Check if fd is available for fast directory scanning
where fd >nul 2>nul
if %errorlevel%==0 (
    fd --type d --hidden --exclude .git -a . "%BASE_DIR%" 2>nul | fzf --prompt="Fuzzy CD> " --preview "%PREVIEW_CMD%" > "%TMP_OUT%"
) else (
    (cd /d "%BASE_DIR%" 2>nul && dir /ad /b /s 2>nul) | fzf --prompt="Fuzzy CD> " --preview "%PREVIEW_CMD%" > "%TMP_OUT%"
)

if not exist "%TMP_OUT%" goto :end

:: If user cancelled (ESC), file size is 0 bytes
for %%A in ("%TMP_OUT%") do if %%~zA equ 0 (
    del "%TMP_OUT%" 2>nul
    goto :end
)

set "TARGET_DIR="
set /p TARGET_DIR=<"%TMP_OUT%"
del "%TMP_OUT%" 2>nul

if not "!TARGET_DIR!"=="" (
    :: Normalize forward slashes to backslashes
    set "TARGET_DIR=!TARGET_DIR:/=\!"
    :: Remove trailing backslash if present
    if "!TARGET_DIR:~-1!"=="\" set "TARGET_DIR=!TARGET_DIR:~0,-1!"

    for %%D in ("!TARGET_DIR!") do (
        endlocal
        cd /d "%%~fD"
        exit /b 0
    )
)

:end
endlocal
