@echo off
where eza >nul 2>nul
if %errorlevel% equ 0 (
    eza -lh -s newest --icons=always %*
) else (
    where ls >nul 2>nul
    if %errorlevel% equ 0 (
        ls -lhrt %*
    ) else (
        dir /o:d %*
    )
)
