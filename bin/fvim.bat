@echo off
setlocal enabledelayedexpansion

:: Determine editor (prefer %EDITOR%, then %VISUAL%, then nvim, then vim)
set "TARGET_EDITOR=%EDITOR%"
if "%TARGET_EDITOR%"=="" set "TARGET_EDITOR=%VISUAL%"
if "%TARGET_EDITOR%"=="" (
    where nvim >nul 2>nul
    if !errorlevel! equ 0 (
        set "TARGET_EDITOR=nvim"
    ) else (
        set "TARGET_EDITOR=vim"
    )
)

:: Run fzf to select a file and open with editor
for /f "usebackq delims=" %%i in (`fzf %*`) do (
    "%TARGET_EDITOR%" "%%i"
    exit /b
)

endlocal
