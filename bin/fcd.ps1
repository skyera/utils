param(
    [string]$Path = "",
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$QueryArgs
)

$baseDir = "."
$query = ""

if ($Path -and (Test-Path -Path $Path -PathType Container)) {
    if ($Path -match '^[.\\/]|:' -or $Path.Contains('\') -or $Path.Contains('/')) {
        $baseDir = $Path
        if ($QueryArgs) {
            $query = $QueryArgs -join " "
        }
    } else {
        $query = if ($QueryArgs) { "$Path " + ($QueryArgs -join " ") } else { $Path }
    }
} elseif ($Path) {
    $query = if ($QueryArgs) { "$Path " + ($QueryArgs -join " ") } else { $Path }
}

# Determine directory previewer (prefer eza if installed)
$previewCmd = 'cmd /c dir /b "{}" 2>nul'
if (Get-Command eza -ErrorAction SilentlyContinue) {
    $previewCmd = 'eza --tree --level=2 --icons=always --color=always "{}" 2>nul'
}

$fzfArgs = @('--layout=reverse', "--preview=$previewCmd")
if ($query) {
    $fzfArgs += "--query=$query"
}

# Fuzzy find directories
if (Get-Command fd -ErrorAction SilentlyContinue) {
    $target = fd --type d --hidden --exclude .git -a . $baseDir 2>$null | fzf @fzfArgs
} else {
    $target = Get-ChildItem -Path $baseDir -Directory -Recurse -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName | fzf @fzfArgs
}

# Change directory if selection made
if ($target) {
    Set-Location $target
}
