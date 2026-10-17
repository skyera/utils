@echo off
rem fport.bat - Launch fport.lua via LuaJIT on Windows
setlocal
where luajit >nul 2>nul
if %ERRORLEVEL% equ 0 (
    luajit "%~dp0fport.lua" %*
    exit /b %ERRORLEVEL%
)
echo [ERROR] luajit is required to run fport.lua. 1>&2
exit /b 1
