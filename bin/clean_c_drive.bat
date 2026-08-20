@echo off
setlocal enabledelayedexpansion

:: ==========================================
:: Safe C: Drive Cleanup Script with Pre-Clean Preview
:: ==========================================

echo ========================================================
echo Checking Administrator Rights...
echo ========================================================
openfiles >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] Script is not running as Administrator.
    echo System temp folders and update caches require Admin rights.
    echo Right-click this script and select "Run as administrator".
    echo.
    pause
    exit /b
)
echo [OK] Running with Administrator privileges.
echo.

set "TOTAL_BYTES=0"

echo ========================================================
echo SCANNING TARGET FOLDERS BEFORE CLEANUP...
echo ========================================================

call :ScanFolder "User Temp" "%LOCALAPPDATA%\Temp"
call :ScanFolder "System Temp" "%SystemRoot%\Temp"
call :ScanFolder "Windows Update Cache" "%SystemRoot%\SoftwareDistribution\Download"
call :ScanFolder "Windows WER Logs" "%LOCALAPPDATA%\Microsoft\Windows\WER"
call :ScanRecycleBin

echo --------------------------------------------------------
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "[math]::Round(!TOTAL_BYTES! / 1MB, 2)"') do set "SAVED_MB=%%a"
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "[math]::Round(!TOTAL_BYTES! / 1GB, 2)"') do set "SAVED_GB=%%a"

echo Total potential space to free: !SAVED_MB! MB (!SAVED_GB! GB)
echo ========================================================
echo.
echo Press ANY KEY to start cleaning these folders, or CTRL+C to cancel...
pause >nul
echo.

echo ========================================================
echo 1. Cleaning User Temp Directory...
echo ========================================================
del /f /s /q "%LOCALAPPDATA%\Temp\*.*" >nul 2>&1
for /d %%x in ("%LOCALAPPDATA%\Temp\*") do rd /s /q "%%x" >nul 2>&1
echo [DONE] User temp cleaned.

echo ========================================================
echo 2. Cleaning System Temp Directory...
echo ========================================================
del /f /s /q "%SystemRoot%\Temp\*.*" >nul 2>&1
for /d %%x in ("%SystemRoot%\Temp\*") do rd /s /q "%%x" >nul 2>&1
echo [DONE] System temp cleaned.

echo ========================================================
echo 3. Cleaning Windows Update Cache...
echo ========================================================
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
del /f /s /q "%SystemRoot%\SoftwareDistribution\Download\*.*" >nul 2>&1
for /d %%x in ("%SystemRoot%\SoftwareDistribution\Download\*") do rd /s /q "%%x" >nul 2>&1
net start bits >nul 2>&1
net start wuauserv >nul 2>&1
echo [DONE] Update cache cleaned.

echo ========================================================
echo 4. Cleaning Windows WER Logs...
echo ========================================================
del /f /s /q "%LOCALAPPDATA%\Microsoft\Windows\WER\*.*" >nul 2>&1
for /d %%x in ("%LOCALAPPDATA%\Microsoft\Windows\WER\*") do rd /s /q "%%x" >nul 2>&1
echo [DONE] WER logs cleaned.

echo ========================================================
echo 5. Emptying Recycle Bin...
echo ========================================================
powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >nul 2>&1
echo [DONE] Recycle Bin emptied.

echo ========================================================
echo 6. Launching Windows Native Disk Cleanup...
echo ========================================================
cleanmgr /autoclean >nul 2>&1
echo [DONE] Disk cleanup complete.

echo.
echo ========================================================
echo CLEANUP FINISHED! Successfully freed ~!SAVED_MB! MB (!SAVED_GB! GB).
echo ========================================================
pause
goto :eof

:: Function to scan and display folder size
:ScanFolder
for /f "tokens=1,2 delims=|" %%a in ('powershell -NoProfile -Command "$p='%~2'; if (Test-Path -Path $p) { $b=(Get-ChildItem -Path $p -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum; if(-not $b){$b=0}; $m=[math]::Round($b/1MB, 2); Write-Output \"$b|$m\" } else { Write-Output \"NOT_FOUND|0\" }"') do (
    if "%%a"=="NOT_FOUND" (
        echo [FOLDER] %~1: %~2 (Folder Not Found)
    ) else (
        set /a TOTAL_BYTES+=%%a 2>nul
        echo [FOLDER] %~1: %~2 (%%b MB)
    )
)
goto :eof

:: Function to scan Recycle Bin size
:ScanRecycleBin
for /f "tokens=1,2 delims=|" %%a in ('powershell -NoProfile -Command "if (Test-Path -Path 'C:\$Recycle.Bin') { $b=(Get-ChildItem 'C:\$Recycle.Bin' -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum; if(-not $b){$b=0}; $m=[math]::Round($b/1MB, 2); Write-Output \"$b|$m\" } else { Write-Output \"0|0\" }"') do (
    set /a TOTAL_BYTES+=%%a 2>nul
    echo [FOLDER] Recycle Bin: C:\$Recycle.Bin (%%b MB)
)
goto :eof
