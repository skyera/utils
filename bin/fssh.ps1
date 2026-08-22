# fssh.ps1 - PowerShell wrapper for fssh
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$pyScript = Join-Path $scriptDir "fssh.py"
& python $pyScript @args
