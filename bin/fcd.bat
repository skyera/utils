@echo off

:: Determine directory previewer (prefer eza if installed)
set "PREVIEW_CMD=cmd /c dir /b \"{}\" 2>nul"
where eza >nul 2>nul
if %errorlevel%==0 set "PREVIEW_CMD=eza --tree --level=2 --icons=always --color=always {} 2>nul"

:: Check if fd is available for fast directory scanning
where fd >nul 2>nul
if %errorlevel%==0 (
    for /f "usebackq delims=" %%i in (`fd --type d --hidden --exclude .git 2^>nul ^| fzf --preview "%PREVIEW_CMD%"`) do (
        cd /d "%%i"
        exit /b
    )
) else (
    for /f "usebackq delims=" %%i in (`dir /ad /b /s 2^>nul ^| fzf --preview "%PREVIEW_CMD%"`) do (
        cd /d "%%i"
        exit /b
    )
)


