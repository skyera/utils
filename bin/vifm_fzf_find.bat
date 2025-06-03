@echo off
setlocal enabledelayedexpansion

:: Call fd and fzf
fd . --type f | fzf --preview "bat --color=always --style=numbers {}" > "%TEMP%\fzf_result.txt"

:: Read result
set /p selected_file=<"%TEMP%\fzf_result.txt"

:: If no file selected, exit
if "!selected_file!"=="" (
    exit /b
)

:: Replace forward slashes with backslashes for Windows compatibility
set "selected_file=!selected_file:/=\!"

:: Get the parent directory of the selected file
for %%F in ("!selected_file!") do set "parent_dir=%%~dpF"

:: Remove trailing backslash from parent_dir if present
if "!parent_dir:~-1!"=="\" set "parent_dir=!parent_dir:~0,-1!"

:: Send commands to vifm: change to directory and select file
if not "!selected_file!"=="" (
    vifm --remote -c "cd '!parent_dir!' | goto '!selected_file!'"
)

:: Clean up
del "%TEMP%\fzf_result.txt"
endlocal