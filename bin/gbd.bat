@echo off
setlocal enabledelayedexpansion

:: 1. Try git forgit if available
git forgit help >nul 2>nul
if %errorlevel% equ 0 (
    git forgit branch_delete %*
    goto :end
)

:: 2. Verify git and fzf are installed
where git >nul 2>nul || (echo Error: git is not installed or not in PATH.& goto :end)
where fzf >nul 2>nul || (echo Error: fzf is not installed or not in PATH.& goto :end)

:: 3. Temporary file for fzf selection
set "TMP_OUT=%TEMP%\gbd_branches_%RANDOM%.txt"

:: 4. Run interactive fzf with rich branch formatting (like forgit)
git branch --sort=-committerdate --color=always --format="%%(if)%%(HEAD)%%(then)%%(else)%%(color:bold green)%%(refname:short)%%(color:reset) %%(color:yellow)%%(objectname:short)%%(color:reset) %%(color:white)%%(subject)%%(color:reset) %%(color:green)(%%(committerdate:relative))%%(color:reset)%%(end)" | findstr /r /v "^$" | fzf -m --ansi --nth=1 --preview "git log --oneline --graph --color=always {1}" --preview-window=right:60%% > "%TMP_OUT%"

if not exist "%TMP_OUT%" goto :end
for %%A in ("%TMP_OUT%") do if %%~zA equ 0 (
    del "%TMP_OUT%"
    goto :end
)

:: 5. Extract branch names (first token) and delete
for /f "usebackq tokens=1" %%B in ("%TMP_OUT%") do (
    if not "%%B"=="" if not "%%B"=="*" (
        git branch -D "%%B"
    )
)

del "%TMP_OUT%" 2>nul

:end
endlocal
