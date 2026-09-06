<#
.SYNOPSIS
    Folder Backup & Sync Utility for Windows using Robocopy.
.DESCRIPTION
    Synchronizes or mirrors a source folder to a destination folder using Windows built-in Robocopy.
.PARAMETER Source
    Source folder to copy from.
.PARAMETER Destination
    Target folder to backup/sync to.
.PARAMETER Mirror
    Mirror mode: deletes files in destination that are not in source.
.PARAMETER DryRun
    Preview mode: shows what would happen without modifying files.
.PARAMETER Help
    Show help message.
#>

param(
    [Parameter(Position = 0)]
    [string]$Source,

    [Parameter(Position = 1)]
    [string]$Destination,

    [Alias("m")]
    [switch]$Mirror,

    [Alias("n")]
    [switch]$DryRun,

    [Alias("h", "?")]
    [switch]$Help
)

function Show-Help {
    Write-Host "`nFolder Backup & Sync Utility (Windows)" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "`nUsage:" -ForegroundColor Yellow
    Write-Host "  sync_folder <Source> <Destination> [-Mirror] [-DryRun]`n" -ForegroundColor White

    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  <Source>          Source folder to copy from" -ForegroundColor White
    Write-Host "  <Destination>     Target folder to backup/sync to" -ForegroundColor White
    Write-Host "  -Mirror, -m       Mirror mode: deletes files in destination that are not in source" -ForegroundColor White
    Write-Host "  -DryRun, -n       Preview mode: shows what would happen without modifying files" -ForegroundColor White
    Write-Host "  -Help, -h, -?     Show this help message`n" -ForegroundColor White

    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  sync_folder D:\docs E:\backup\docs              # Safe incremental backup" -ForegroundColor Cyan
    Write-Host "  sync_folder D:\docs E:\backup\docs -Mirror      # True mirror clone" -ForegroundColor Cyan
    Write-Host "  sync_folder D:\docs E:\backup\docs -n           # Dry-run preview" -ForegroundColor Cyan
    Write-Host "  sync_folder -h                                  # Show help`n" -ForegroundColor Cyan
}

# Display help if requested
if ($Help) {
    Show-Help
    exit 0
}

# Validate required arguments
if ([string]::IsNullOrWhiteSpace($Source) -or [string]::IsNullOrWhiteSpace($Destination)) {
    Write-Host "[ERROR] Missing Source or Destination folder." -ForegroundColor Red
    Show-Help
    exit 1
}

# Trim trailing slashes to prevent Robocopy quote-escaping issues
$Source = $Source.TrimEnd('\', '/')
$Destination = $Destination.TrimEnd('\', '/')

# Validate source directory exists
if (-not (Test-Path -Path $Source -PathType Container)) {
    Write-Host "[ERROR] Source folder does not exist: $Source" -ForegroundColor Red
    exit 1
}

# Ensure destination directory exists
if (-not (Test-Path -Path $Destination)) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
}

# Base robocopy arguments:
# /E: subfolders (including empty) | /Z: restartable | /R:2: 2 retries | /W:3: 3s wait | /MT:8: 8 threads
$roboArgs = @($Source, $Destination, "/E", "/Z", "/R:2", "/W:3", "/MT:8")

if ($Mirror) {
    Write-Host "[MODE] Mirror Sync (deleting extra files in destination)" -ForegroundColor Yellow
    $roboArgs += "/PURGE"
} else {
    Write-Host "[MODE] Safe Incremental Backup (no deletions)" -ForegroundColor Cyan
}

if ($DryRun) {
    Write-Host "[INFO] Dry Run / Preview Only (no files will be changed)" -ForegroundColor Magenta
    $roboArgs += "/L"
}

Write-Host "Source:      $Source"
Write-Host "Destination: $Destination`n"

robocopy @roboArgs

# Robocopy exit codes: 0-7 indicate success/info, >=8 indicate errors
if ($LASTEXITCODE -lt 8) {
    Write-Host "`n[SUCCESS] Sync completed successfully." -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n[ERROR] Robocopy reported errors (Exit code: $LASTEXITCODE)." -ForegroundColor Red
    exit $LASTEXITCODE
}
