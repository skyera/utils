# fzf_keybindings.ps1 - Shell keybindings (Ctrl+R, Ctrl+T, Alt+C) using fzf for PowerShell on Windows / WezTerm

if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
    return
}

if (Get-Module -Name PSReadLine) {

    # -------------------------------------------------------------
    # 1. Ctrl+R : Interactive Command History Search with fzf
    # -------------------------------------------------------------
    Set-PSReadLineKeyHandler -Key 'Ctrl+r' -BriefDescription 'FZF History Search' -ScriptBlock {
        $historyFile = (Get-PSReadLineOption).HistorySavePath
        $lines = @()
        if ($historyFile -and (Test-Path $historyFile)) {
            $lines = Get-Content $historyFile -Encoding UTF8 -ErrorAction SilentlyContinue
        } else {
            $lines = Get-History | Select-Object -ExpandProperty CommandLine
        }

        if ($lines) {
            [array]::Reverse($lines)
            $selected = $lines | Select-Object -Unique | fzf --height 40% --reverse --header="History Search (Ctrl+R)" --tiebreak=index
            if ($selected) {
                [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
                [Microsoft.PowerShell.PSConsoleReadLine]::Insert($selected)
            }
        }
    }

    # -------------------------------------------------------------
    # 2. Ctrl+T : Interactive File Search & Insert with fzf
    # -------------------------------------------------------------
    Set-PSReadLineKeyHandler -Key 'Ctrl+t' -BriefDescription 'FZF File Search' -ScriptBlock {
        $hasFd = [bool](Get-Command fd -ErrorAction SilentlyContinue)
        if ($hasFd) {
            $file = fd --type f --hidden --exclude .git | fzf --height 40% --reverse --header="File Finder (Ctrl+T)"
        } else {
            $file = Get-ChildItem -File -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName | fzf --height 40% --reverse --header="File Finder (Ctrl+T)"
        }

        if ($file) {
            if ($file -match '\s') {
                $file = "`"$file`""
            }
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert($file)
        }
    }

    # -------------------------------------------------------------
    # 3. Alt+C : Interactive Directory Search & CD with fzf
    # -------------------------------------------------------------
    $altCScript = {
        $hasFd = [bool](Get-Command fd -ErrorAction SilentlyContinue)
        if ($hasFd) {
            $dir = fd --type d --hidden --exclude .git | fzf --height 40% --reverse --header="Directory Change (Alt+C)"
        } else {
            $dir = Get-ChildItem -Directory -Recurse -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName | fzf --height 40% --reverse --header="Directory Change (Alt+C)"
        }

        if ($dir -and (Test-Path $dir)) {
            Set-Location $dir
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::Repaint()
        }
    }

    Set-PSReadLineKeyHandler -Key 'Alt+c' -BriefDescription 'FZF CD Directory' -ScriptBlock $altCScript
    Set-PSReadLineKeyHandler -Key 'Escape,c' -BriefDescription 'FZF CD Directory (ESC+c)' -ScriptBlock $altCScript
}
