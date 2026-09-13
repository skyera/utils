@echo off
where luajit >nul 2>nul
if %errorlevel% equ 0 if exist "%~dp0fscp_tui.lua" (
    luajit "%~dp0fscp_tui.lua" %*
    exit /b %errorlevel%
)
echo [ERROR] luajit is required to run fscp_tui.lua. 1>&2
exit /b 1
