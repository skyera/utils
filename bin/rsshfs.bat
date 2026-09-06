@echo off
setlocal enabledelayedexpansion

set "SCRIPT_NAME=%~nx0"

if "%~1"=="" goto :show_help
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="/h" goto :show_help
if /i "%~1"=="/?" goto :show_help

:: Unmount mode
if /i "%~1"=="-u" goto :do_unmount
if /i "%~1"=="--unmount" goto :do_unmount
if /i "%~1"=="/u" goto :do_unmount

:: Mount mode
if "%~2"=="" (
    echo Error: Missing local drive letter. >&2
    echo Run '%SCRIPT_NAME% --help' for usage. >&2
    exit /b 1
)

set "REMOTE_HOST=%~1"
if "%~3"=="" (
    set "REMOTE_DIR="
    set "DRIVE=%~2"
) else (
    set "REMOTE_DIR=%~2"
    set "DRIVE=%~3"
)

:: Normalize drive letter (strip trailing backslash, slash, colon; keep first character followed by colon)
set "DRIVE=%DRIVE:\=%"
set "DRIVE=%DRIVE:/=%"
set "DRIVE=%DRIVE::=%"
set "DRIVE=%DRIVE:~0,1%:"

:: Check if drive is already in use
if exist "%DRIVE%\" (
    echo Notice: Drive '%DRIVE%' is already in use.
    exit /b 0
)

:: Construct UNC path for SSHFS-Win
if "%REMOTE_DIR%"=="" (
    set "UNC_PATH=\\sshfs\%REMOTE_HOST%"
    set "DISPLAY_DIR=remote HOME"
) else (
    :: Replace forward slashes with backslashes for UNC
    set "NORM_DIR=%REMOTE_DIR:/=\%"
    :: Strip leading backslash if present
    if "!NORM_DIR:~0,1!"=="\" set "NORM_DIR=!NORM_DIR:~1!"
    set "UNC_PATH=\\sshfs.r\%REMOTE_HOST%\!NORM_DIR!"
    set "DISPLAY_DIR=%REMOTE_DIR%"
)

echo Mounting %REMOTE_HOST% (!DISPLAY_DIR!) to %DRIVE%...
net use %DRIVE% "%UNC_PATH%" /persistent:no >nul 2>&1
if !errorlevel! equ 0 (
    echo Successfully mounted to %DRIVE%
) else (
    echo Error: Failed to mount to %DRIVE%.
    echo Please verify WinFsp and SSHFS-Win are installed:
    echo   winget install WinFsp.WinFsp
    echo   winget install SSHFS-Win.SSHFS-Win
    exit /b 1
)
exit /b 0

:do_unmount
if "%~2"=="" (
    echo Error: Missing drive letter to unmount. >&2
    echo Run '%SCRIPT_NAME% --help' for usage. >&2
    exit /b 1
)
set "U_DRIVE=%~2"
set "U_DRIVE=%U_DRIVE:\=%"
set "U_DRIVE=%U_DRIVE:/=%"
set "U_DRIVE=%U_DRIVE::=%"
set "U_DRIVE=%U_DRIVE:~0,1%:"

if not exist "%U_DRIVE%\" (
    echo Notice: '%U_DRIVE%' is not currently mounted.
    exit /b 0
)

echo Unmounting %U_DRIVE%...
net use %U_DRIVE% /delete /y >nul 2>&1
if !errorlevel! equ 0 (
    echo Successfully unmounted %U_DRIVE%.
) else (
    echo Error: Failed to unmount %U_DRIVE%. >&2
    exit /b 1
)
exit /b 0

:show_help
echo Usage:
echo   %SCRIPT_NAME% ^<user@host^> [^<remote_dir^>] ^<Drive:^>
echo   %SCRIPT_NAME% -u ^<Drive:^>
echo   %SCRIPT_NAME% -h ^| --help
echo.
echo Description:
echo   Mount a remote directory locally via SSHFS-Win, or unmount an existing mount.
echo   If ^<remote_dir^> is omitted, it defaults to the remote user's home directory.
echo.
echo Arguments:
echo   ^<user@host^>     Remote SSH target (e.g., user@server.com or SSH config host)
echo   ^<remote_dir^>    Optional path on remote host to mount (defaults to remote home)
echo   ^<Drive:^>        Local drive letter to mount into (e.g., Z: or Z)
echo.
echo Options:
echo   -u, --unmount   Unmount the specified local drive
echo   -h, --help      Display this help message and exit
echo.
echo Examples:
echo   # Mount remote home directory to Z:
echo   %SCRIPT_NAME% user@remote-box Z:
echo.
echo   # Mount specific remote directory to Y:
echo   %SCRIPT_NAME% user@remote-box /var/www Y:
echo.
echo   # Mount with custom port:
echo   %SCRIPT_NAME% user!2222@remote-box /var/www Y:
echo.
echo   # Unmount drive:
echo   %SCRIPT_NAME% -u Z:
exit /b 0
