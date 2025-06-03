@echo off
setlocal enabledelayedexpansion

:: Call fd and fzf
fd . --type f | fzf --preview "bat --color=always --style=numbers {}" > "%TEMP%\fzf_result.txt"

:: Read result
set /p selected_file=<"%TEMP%\fzf_result.txt"

:: Replace backslashes with forward slashes (lf prefers Unix-style paths)
set "selected_file=!selected_file:\=/!"

:: If selected, send to lf
if not "!selected_file!"=="" (
    lf -remote "send %id% select '!selected_file!'"
)

del "%TEMP%\fzf_result.txt"
endlocal

