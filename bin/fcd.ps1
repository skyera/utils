param(
    [string]$Path = "."
)

# Determine directory previewer (prefer eza if installed)
$previewCmd = 'cmd /c dir /b "{}" 2>nul'
if (Get-Command eza -ErrorAction SilentlyContinue) {
    $previewCmd = 'eza --tree --level=2 --icons=always --color=always {} 2>nul'
}

# Fuzzy find directories
if (Get-Command fd -ErrorAction SilentlyContinue) {
    $target = fd --type d --hidden --exclude .git . $Path 2>$null | fzf --prompt="Fuzzy CD> " --preview $previewCmd
} else {
    $target = Get-ChildItem -Path $Path -Directory -Recurse -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName | fzf --prompt="Fuzzy CD> " --preview $previewCmd
}

# Change directory if selection made
if ($target) {
    Set-Location $target
}
