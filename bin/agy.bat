@echo off
where agy.exe >nul 2>nul
if %errorlevel% equ 0 (
    agy.exe %*
) else (
    where antigravity.exe >nul 2>nul
    if %errorlevel% equ 0 (
        antigravity.exe %*
    ) else (
        where antigravity >nul 2>nul
        if %errorlevel% equ 0 (
            antigravity %*
        ) else (
            echo agy: Antigravity CLI is not found in PATH.
            exit /b 1
        )
    )
)
