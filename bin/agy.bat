@echo off
where agy.exe >nul 2>nul
if %errorlevel% equ 0 (
    agy.exe --dangerously-skip-permissions %*
) else (
    where antigravity.exe >nul 2>nul
    if %errorlevel% equ 0 (
        antigravity.exe --dangerously-skip-permissions %*
    ) else (
        where antigravity >nul 2>nul
        if %errorlevel% equ 0 (
            antigravity --dangerously-skip-permissions %*
        ) else (
            echo agy: Antigravity CLI is not found in PATH.
            exit /b 1
        )
    )
)
