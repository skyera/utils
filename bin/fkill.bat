@echo off
setlocal enabledelayedexpansion

:: 1. Verify tasklist and taskkill are available
where tasklist >nul 2>nul || (echo Error: tasklist is not available.& goto :end)
where taskkill >nul 2>nul || (echo Error: taskkill is not available.& goto :end)

:: 2. Direct mode: if argument passed, kill directly by PID or Image Name
if not "%~1"=="" (
    REM Check if first argument is numeric (PID)
    echo %~1| findstr /r "^[0-9][0-9]*$" >nul
    if !errorlevel! equ 0 (
        taskkill /F /PID %*
    ) else (
        set "TARGET=%~1"
        if /i not "!TARGET:~-4!"==".exe" set "TARGET=!TARGET!.exe"
        taskkill /F /IM "!TARGET!" %*
    )
    goto :end
)

:: 3. Verify fzf is installed for interactive mode
where fzf >nul 2>nul || (echo Error: fzf is not installed or not in PATH.& goto :end)

:: 4. Temporary file for fzf selection
set "TMP_OUT=%TEMP%\fkill_%RANDOM%.txt"

:: 5. Interactive process selector with detailed process preview
tasklist /fo table | fzf -m --header-lines=3 --header="[Tab]: Multi-select - [Enter]: Terminate - [Esc]: Cancel" --preview="tasklist /fi \"PID eq {2}\" /fo list 2>nul" --preview-window=right:50%%:wrap > "%TMP_OUT%"

if not exist "%TMP_OUT%" goto :end
for %%A in ("%TMP_OUT%") do if %%~zA equ 0 (
    del "%TMP_OUT%" 2>nul
    goto :end
)

:: 6. Terminate selected processes
for /f "usebackq tokens=1,2" %%A in ("%TMP_OUT%") do (
    set "P_NAME=%%A"
    set "P_PID=%%B"
    if not "!P_PID!"=="" (
        echo Terminating !P_NAME! (PID: !P_PID!)...
        taskkill /F /PID !P_PID!
    )
)

del "%TMP_OUT%" 2>nul

:end
endlocal
