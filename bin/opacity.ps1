<#
.SYNOPSIS
    Alacritty dynamic opacity switcher.
.DESCRIPTION
    Dynamically change Alacritty window opacity (transparency) on Windows.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ValueOrCommand,

    [Parameter(Position = 1)]
    [string]$Step = "0.05",

    [Alias("c")]
    [switch]$Current,

    [Alias("w")]
    [switch]$Window,

    [Alias("t")]
    [switch]$Toggle,

    [Alias("h")]
    [switch]$Help
)

$DefaultOpacity = 0.93
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Split-Path -Parent $ScriptDir
$AppDataAlacritty = Join-Path $env:APPDATA "alacritty\alacritty.toml"
$UserConfigAlacritty = Join-Path $env:USERPROFILE ".config\alacritty\alacritty.toml"
$RepoAlacritty = Join-Path $RepoDir ".config\alacritty\alacritty.toml"

$TargetFile = $AppDataAlacritty
if (-not (Test-Path -LiteralPath $TargetFile)) {
    if (Test-Path -LiteralPath $RepoAlacritty) {
        $parent = Split-Path -Parent $TargetFile
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Copy-Item -LiteralPath $RepoAlacritty -Destination $TargetFile -Force
    } elseif (Test-Path -LiteralPath $UserConfigAlacritty) {
        $TargetFile = $UserConfigAlacritty
    }
}

if (-not (Test-Path -LiteralPath $TargetFile)) {
    Write-Error "[ERROR] Alacritty config file not found at $TargetFile"
    exit 1
}

function Show-HelpMessage {
    @"
Usage: opacity [OPTIONS] [VALUE | COMMAND]

Dynamically change Alacritty window opacity (transparency).

Commands / Values:
  (no args)                  Interactive preset selection via fzf
  <0.0 - 1.0>                Set exact opacity (e.g., 1.0, 0.85)
  <0 - 100[%]>               Set opacity by percentage (e.g., 85, 85%, 100%)
  toggle, -t, --toggle       Toggle between opaque (1.0) and default ($DefaultOpacity)
  +, up, inc [STEP]          Increase opacity (default step: 0.05, max: 1.0)
  -, down, dec [STEP]        Decrease opacity (default step: 0.05, min: 0.1)
  reset, default             Reset opacity to default ($DefaultOpacity)

Options:
  -c, -Current               Display current opacity value
  -w, -Window                Open a new Alacritty window with the specified opacity
  -h, -Help                  Show this help message

Examples:
  opacity                    Interactive selection via fzf
  opacity 1.0                Make window fully opaque
  opacity 85%                Set opacity to 0.85
  opacity toggle             Toggle between 1.0 and 0.93
  opacity +                  Increase opacity by 0.05
  opacity - 0.1              Decrease opacity by 0.10
  opacity reset              Restore default $DefaultOpacity opacity
"@
}

if ($Help) {
    Show-HelpMessage
    exit 0
}

# Read current opacity
$content = Get-Content -LiteralPath $TargetFile -Raw -ErrorAction SilentlyContinue
$currentVal = $DefaultOpacity
if ($content -match '(?m)^\s*opacity\s*=\s*([0-9.]+)') {
    $currentVal = [double]::Parse($Matches[1], [System.Globalization.CultureInfo]::InvariantCulture)
}

if ($Current) {
    $formatted = $currentVal.ToString("0.00", [System.Globalization.CultureInfo]::InvariantCulture).TrimEnd('0').TrimEnd('.')
    if (-not $formatted.Contains('.')) { $formatted = "$formatted.0" }
    Write-Output "[Alacritty] Current opacity: $formatted"
    exit 0
}

function Parse-OpacityValue([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return $null }
    $s = $s.Trim()
    $isPct = $false
    if ($s.EndsWith('%')) {
        $isPct = $true
        $s = $s.TrimEnd('%').Trim()
    }
    $val = 0.0
    if (-not [double]::TryParse($s, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$val)) {
        return $null
    }
    if ($isPct) {
        if ($val -lt 0 -or $val -gt 100) { return $null }
        return $val / 100.0
    }
    if ($val -gt 1.0 -and $val -le 100.0) {
        return $val / 100.0
    }
    if ($val -lt 0.0 -or $val -gt 1.0) {
        return $null
    }
    return $val
}

$action = $null
if ($Toggle) {
    $action = "toggle"
} elseif (-not [string]::IsNullOrEmpty($ValueOrCommand)) {
    switch -Regex ($ValueOrCommand.ToLowerInvariant()) {
        '^toggle$' { $action = "toggle" }
        '^(reset|default)$' { $action = "reset" }
        '^(\+|up|inc)$' { $action = "inc" }
        '^(-|down|dec)$' { $action = "dec" }
        default { $action = "set" }
    }
}

# Interactive selection if no action specified
if (-not $action) {
    $presets = @(
        [PSCustomObject]@{ Value = 1.00; Label = "1.00`t(100% - Fully opaque)" }
        [PSCustomObject]@{ Value = 0.95; Label = "0.95`t(95% - Slight transparency)" }
        [PSCustomObject]@{ Value = 0.93; Label = "0.93`t(93% - Default)" }
        [PSCustomObject]@{ Value = 0.90; Label = "0.90`t(90%)" }
        [PSCustomObject]@{ Value = 0.85; Label = "0.85`t(85%)" }
        [PSCustomObject]@{ Value = 0.80; Label = "0.80`t(80%)" }
        [PSCustomObject]@{ Value = 0.75; Label = "0.75`t(75%)" }
        [PSCustomObject]@{ Value = 0.70; Label = "0.70`t(70%)" }
        [PSCustomObject]@{ Value = 0.60; Label = "0.60`t(60%)" }
        [PSCustomObject]@{ Value = 0.50; Label = "0.50`t(50% - Half transparent)" }
    )

    $hasFzf = Get-Command fzf -ErrorAction SilentlyContinue
    if ($hasFzf) {
        $fzfInput = ($presets | ForEach-Object { $_.Label }) -join "`n"
        $selected = $fzfInput | fzf --prompt="Select Alacritty Opacity (current: $currentVal) > " --layout=reverse --height=40% --border --no-preview
        if ($selected) {
            $ValueOrCommand = ($selected -split '\s+')[0]
            $action = "set"
        }
    } else {
        Write-Host "Available Alacritty Opacity Presets (current: $currentVal):"
        for ($i = 0; $i -lt $presets.Count; $i++) {
            Write-Host ("  {0}. {1}" -f ($i + 1), $presets[$i].Label)
        }
        $choice = Read-Host "Select preset number or enter opacity (0.0-1.0 / 10-100%)"
        if ($choice) {
            $idx = 0
            if ([int]::TryParse($choice, [ref]$idx) -and $idx -ge 1 -and $idx -le $presets.Count) {
                $ValueOrCommand = $presets[$idx - 1].Value.ToString("0.00", [System.Globalization.CultureInfo]::InvariantCulture)
            } else {
                $ValueOrCommand = $choice
            }
            $action = "set"
        }
    }

    if (-not $action) {
        Write-Host "No opacity selected."
        exit 0
    }
}

$newVal = 0.0
switch ($action) {
    "toggle" {
        $newVal = if ($currentVal -ge 0.999) { $DefaultOpacity } else { 1.0 }
    }
    "reset" {
        $newVal = $DefaultOpacity
    }
    "inc" {
        $st = Parse-OpacityValue $Step
        if ($null -eq $st -or $st -le 0) {
            Write-Error "[ERROR] Invalid step value: '$Step'"
            exit 1
        }
        $newVal = [Math]::Min(1.0, [Math]::Round($currentVal + $st, 4))
    }
    "dec" {
        $st = Parse-OpacityValue $Step
        if ($null -eq $st -or $st -le 0) {
            Write-Error "[ERROR] Invalid step value: '$Step'"
            exit 1
        }
        $newVal = [Math]::Max(0.10, [Math]::Round($currentVal - $st, 4))
    }
    "set" {
        $parsed = Parse-OpacityValue $ValueOrCommand
        if ($null -eq $parsed) {
            Write-Error "[ERROR] Invalid opacity value: '$ValueOrCommand'. Expected 0.0-1.0 or 0%-100%."
            exit 1
        }
        $newVal = $parsed
    }
}

$fmtNew = $newVal.ToString("0.00", [System.Globalization.CultureInfo]::InvariantCulture).TrimEnd('0').TrimEnd('.')
if (-not $fmtNew.Contains('.')) { $fmtNew = "$fmtNew.0" }

$fmtCur = $currentVal.ToString("0.00", [System.Globalization.CultureInfo]::InvariantCulture).TrimEnd('0').TrimEnd('.')
if (-not $fmtCur.Contains('.')) { $fmtCur = "$fmtCur.0" }

if ($Window) {
    $alacrittyExe = Get-Command alacritty.exe -ErrorAction SilentlyContinue
    if ($alacrittyExe) {
        Start-Process $alacrittyExe.Source -ArgumentList "-o", "window.opacity=$fmtNew"
        Write-Output "[Alacritty] Opened new window with opacity: $fmtNew"
        exit 0
    } else {
        Write-Error "[ERROR] alacritty executable not found in PATH."
        exit 1
    }
}

$filesToUpdate = @($TargetFile, $UserConfigAlacritty, $RepoAlacritty) | Select-Object -Unique
foreach ($file in $filesToUpdate) {
    if (Test-Path -LiteralPath $file) {
        $raw = [System.IO.File]::ReadAllText($file)
        $newRaw = [regex]::Replace($raw, '(?m)^(\s*opacity\s*=\s*)[0-9.]+', "`${1}$fmtNew")
        [System.IO.File]::WriteAllText($file, $newRaw, (New-Object System.Text.UTF8Encoding $false))
    }
}

Write-Output "[Alacritty] Opacity changed: $fmtCur -> $fmtNew"
