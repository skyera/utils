@echo off
set "NEW_PATH=C:\tools\cygwin\bin"

:: 1. Autodetect if default doesn't exist
if not exist "%NEW_PATH%\sort.exe" (
    if exist "C:\cygwin64\bin\sort.exe" (
        set "NEW_PATH=C:\cygwin64\bin"
    ) else if exist "C:\cygwin\bin\sort.exe" (
        set "NEW_PATH=C:\cygwin\bin"
    ) else (
        :: Dynamic search fallback
        for /f "delims=" %%i in ('where sort.exe 2^>nul ^| findstr /i /v "System32"') do (
            set "NEW_PATH=%%~dpi"
            goto :found
        )
    )
)

:found
:: Remove trailing backslash if present
if "%NEW_PATH:~-1%"=="\" set "NEW_PATH=%NEW_PATH:~0,-1%"

if exist "%NEW_PATH%\sort.exe" (
    :: Always prepend to ensure it takes precedence over System32
    set "PATH=%NEW_PATH%;%PATH%"
    echo [INFO] Prepending Cygwin to PATH: %NEW_PATH%
) else (
    echo [ERROR] Cygwin/GNU sort.exe not found!
)

:: Clean up local variable
set "NEW_PATH="
