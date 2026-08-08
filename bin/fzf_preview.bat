@echo off
if exist "%~1\" (
    eza --tree --level=2 --icons=always --color=always "%~1"
) else (
    bat --color=always "%~1"
)
