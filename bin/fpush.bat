@echo off
where luajit >nul 2>nul
if %errorlevel% equ 0 if exist "%~dp0fscp.lua" (
    luajit "%~dp0fscp.lua" --push %*
    exit /b %errorlevel%
)
echo [ERROR] luajit is required to run fpush. 1>&2
exit /b 1
