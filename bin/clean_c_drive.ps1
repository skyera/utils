#Requires -RunAsAdministrator

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "Checking Administrator Rights..." -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[WARNING] Script is not running as Administrator." -ForegroundColor Yellow
    Write-Host "Please right-click and select 'Run with PowerShell as Administrator'." -ForegroundColor Yellow
    Pause
    Exit
}
Write-Host "[OK] Running with Administrator privileges.`n" -ForegroundColor Green

$targetFolders = @(
    @{ Name = "User Temp"; Path = "$env:LOCALAPPDATA\Temp" },
    @{ Name = "System Temp"; Path = "$env:SystemRoot\Temp" },
    @{ Name = "Windows Update Cache"; Path = "$env:SystemRoot\SoftwareDistribution\Download" },
    @{ Name = "Windows WER Logs"; Path = "$env:LOCALAPPDATA\Microsoft\Windows\WER" }
)

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "SCANNING TARGET FOLDERS BEFORE CLEANUP..." -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$totalBytes = 0

foreach ($folder in $targetFolders) {
    if (Test-Path -Path $folder.Path) {
        $files = Get-ChildItem -Path $folder.Path -Recurse -File -ErrorAction SilentlyContinue
        $bytes = ($files | Measure-Object -Property Length -Sum).Sum
        if (-not $bytes) { $bytes = 0 }
        $totalBytes += $bytes
        $mb = [math]::Round($bytes / 1MB, 2)
        Write-Host ("[FOLDER] {0}: {1} ({2} MB)" -f $folder.Name, $folder.Path, $mb) -ForegroundColor White
    } else {
        Write-Host ("[FOLDER] {0}: {1} (Folder Not Found)" -f $folder.Name, $folder.Path) -ForegroundColor DarkGray
    }
}

# Scan Recycle Bin
if (Test-Path -Path "C:\`$Recycle.Bin") {
    $rbFiles = Get-ChildItem -Path "C:\`$Recycle.Bin" -Recurse -File -Force -ErrorAction SilentlyContinue
    $rbBytes = ($rbFiles | Measure-Object -Property Length -Sum).Sum
    if (-not $rbBytes) { $rbBytes = 0 }
    $totalBytes += $rbBytes
    $rbMb = [math]::Round($rbBytes / 1MB, 2)
    Write-Host ("[FOLDER] Recycle Bin: C:\`$Recycle.Bin ({0} MB)" -f $rbMb) -ForegroundColor White
}

$savedMb = [math]::Round($totalBytes / 1MB, 2)
$savedGb = [math]::Round($totalBytes / 1GB, 2)

Write-Host "--------------------------------------------------------" -ForegroundColor Cyan
Write-Host ("Total potential space to free: {0} MB ({1} GB)" -f $savedMb, $savedGb) -ForegroundColor Yellow
Write-Host "========================================================`n" -ForegroundColor Cyan

Read-Host "Press ENTER to start cleaning these folders, or CTRL+C to cancel"

Write-Host "`n1. Cleaning User Temp..." -ForegroundColor Green
Remove-Item -Path "$env:LOCALAPPDATA\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "2. Cleaning System Temp..." -ForegroundColor Green
Remove-Item -Path "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "3. Cleaning Windows Update Cache..." -ForegroundColor Green
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
Stop-Service -Name bits -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:SystemRoot\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
Start-Service -Name bits -ErrorAction SilentlyContinue
Start-Service -Name wuauserv -ErrorAction SilentlyContinue

Write-Host "4. Cleaning Windows WER Logs..." -ForegroundColor Green
Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\WER\*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "5. Emptying Recycle Bin..." -ForegroundColor Green
Clear-RecycleBin -Force -ErrorAction SilentlyContinue

Write-Host "6. Running Windows Disk Cleanup..." -ForegroundColor Green
Start-Process cleanmgr.exe -ArgumentList "/autoclean" -Wait -NoNewWindow -ErrorAction SilentlyContinue

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host ("CLEANUP FINISHED! Successfully freed ~{0} MB ({1} GB)." -f $savedMb, $savedGb) -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Cyan
Pause
