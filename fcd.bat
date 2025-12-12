@echo off
for /f "usebackq delims=" %%i in (`dir /ad /b /s ^| fzf`) do (
    cd /d "%%i"
    exit /b
)
