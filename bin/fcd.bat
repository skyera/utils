@echo off
setlocal enabledelayedexpansion

set "BASE_DIR=."
set "QUERY="

if not "%~1"=="" (
    if exist "%~1\*" (
        set "BASE_DIR=%~1"
        for /f "tokens=1* delims= " %%A in ("%*") do (
            set "QUERY=%%B"
        )
    ) else (
        set "QUERY=%*"
    )
)

set "PREVIEW_CMD=cmd /c dir /b \"{}\" 2>nul"
where eza >nul 2>&1 && set "PREVIEW_CMD=eza --tree --level=2 --icons=always --color=always \"{}\" 2>nul"

set "TMP_OUT=%TEMP%\fcd_res_%RANDOM%.txt"

set "FZF_OPTS=--prompt="Fuzzy CD> " --preview="%PREVIEW_CMD%""
if not "!QUERY!"=="" set "FZF_OPTS=!FZF_OPTS! --query="!QUERY!""

where fd >nul 2>&1
if !errorlevel!==0 (
    fd --type d --hidden --exclude .git -a . "!BASE_DIR!" 2>nul | fzf !FZF_OPTS! > "%TMP_OUT%"
) else (
    (cd /d "!BASE_DIR!" 2>nul && dir /ad /b /s 2>nul) | fzf !FZF_OPTS! > "%TMP_OUT%"
)

if not exist "%TMP_OUT%" goto end

set "TARGET_DIR="
for /f "usebackq delims=" %%i in ("%TMP_OUT%") do (
    if not defined TARGET_DIR set "TARGET_DIR=%%i"
)
del "%TMP_OUT%" 2>nul

if "!TARGET_DIR!"=="" goto end

endlocal & cd /d "%TARGET_DIR%"

:end
if exist "%TMP_OUT%" del "%TMP_OUT%" 2>nul
endlocal
