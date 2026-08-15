@echo off
setlocal enabledelayedexpansion

set "BASE_DIR=."
set "QUERY="
set "ARG1=%~1"

:: Check if first argument is an explicit directory path (starts with ., \, /, has :, or contains \ or /)
if not "%ARG1%"=="" (
    set "IS_PATH=0"
    if exist "%ARG1%\*" (
        if "%ARG1:~0,1%"=="." set "IS_PATH=1"
        if "%ARG1:~0,1%"=="\" set "IS_PATH=1"
        if "%ARG1:~0,1%"=="/" set "IS_PATH=1"
        if not "%ARG1:~1,1%"=="" if "%ARG1:~1,1%"==":" set "IS_PATH=1"
        echo %ARG1% | findstr /R "[\\/]" >nul 2>&1
        if !errorlevel!==0 set "IS_PATH=1"
    )
    if "!IS_PATH!"=="1" (
        set "BASE_DIR=%ARG1%"
        shift
        set "QUERY=%~1"
        :collect_query
        shift
        if not "%~1"=="" (
            set "QUERY=!QUERY! %~1"
            goto :collect_query
        )
    ) else (
        :: First argument is a name/search term, treat all arguments as fzf search query
        set "QUERY=%*"
    )
)

:: Determine directory previewer (prefer eza if installed)
set "PREVIEW_CMD=cmd /c dir /b \"{}\" 2>nul"
where eza >nul 2>nul
if %errorlevel%==0 set "PREVIEW_CMD=eza --tree --level=2 --icons=always --color=always \"{}\" 2>nul"

set "TMP_OUT=%TEMP%\fcd_res_%RANDOM%.txt"

:: Check if fd is available for fast directory scanning
where fd >nul 2>nul
if %errorlevel%==0 (
    if not "!QUERY!"=="" (
        fd --type d --hidden --exclude .git -a . "!BASE_DIR!" 2>nul | fzf --prompt="Fuzzy CD> " --preview "%PREVIEW_CMD%" --query "!QUERY!" > "%TMP_OUT%"
    ) else (
        fd --type d --hidden --exclude .git -a . "!BASE_DIR!" 2>nul | fzf --prompt="Fuzzy CD> " --preview "%PREVIEW_CMD%" > "%TMP_OUT%"
    )
) else (
    if not "!QUERY!"=="" (
        (cd /d "!BASE_DIR!" 2>nul && dir /ad /b /s 2>nul) | fzf --prompt="Fuzzy CD> " --preview "%PREVIEW_CMD%" --query "!QUERY!" > "%TMP_OUT%"
    ) else (
        (cd /d "!BASE_DIR!" 2>nul && dir /ad /b /s 2>nul) | fzf --prompt="Fuzzy CD> " --preview "%PREVIEW_CMD%" > "%TMP_OUT%"
    )
)

if not exist "%TMP_OUT%" goto :end

set "TARGET_DIR="
for /f "usebackq delims=" %%i in ("%TMP_OUT%") do (
    if not defined TARGET_DIR set "TARGET_DIR=%%i"
)
del "%TMP_OUT%" 2>nul

if "!TARGET_DIR!"=="" goto :end

:: Normalize forward slashes to backslashes
set "TARGET_DIR=!TARGET_DIR:/=\!"

:: Remove trailing backslash if present (unless it is a drive root like C:\)
if "!TARGET_DIR:~-1!"=="\" (
    if not "!TARGET_DIR:~-2!"==":\" (
        set "TARGET_DIR=!TARGET_DIR:~0,-1!"
    )
)

for /f "delims=" %%D in ("!TARGET_DIR!") do (
    endlocal
    cd /d "%%~fD"
    exit /b 0
)

:end
endlocal
