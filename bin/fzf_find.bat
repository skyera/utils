@echo off
setlocal enabledelayedexpansion

:: Call fd and fzf
set "tmpfile=%TEMP%\lf_fzf_%RANDOM%.txt"
fd . --type f --type d | fzf --preview "bat --color=always --style=numbers {}" > "%tmpfile%"

:: Read result
set /p selected_file=<"%tmpfile%"

:: Replace backslashes with forward slashes (lf prefers Unix-style paths)
set "selected_file=!selected_file:\=/!"

:: If selected, send to lf
if not "!selected_file!"=="" (
    lf -remote "send %id% select '!selected_file!'"
)

del "%tmpfile%"
endlocal

