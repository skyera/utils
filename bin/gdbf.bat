@echo off
setlocal enabledelayedexpansion

:: 1. Verify git is installed
where git >nul 2>nul || (echo Error: git is not installed or not in PATH.& goto :end)

:: 2. If arguments passed, pass directly to git branch -D
if not "%~1"=="" (
    git branch -D %*
    goto :end
)

:: 3. Verify fzf is installed
where fzf >nul 2>nul || (echo Error: fzf is not installed or not in PATH.& goto :end)

:: 4. Temporary file for fzf selection
set "TMP_OUT=%TEMP%\gdbf_branch_%RANDOM%.txt"

:: 5. Run interactive multi-select fzf with branch preview (excluding current HEAD)
git branch --sort=-committerdate --format="%%(if)%%(HEAD)%%(then)%%(else)%%(refname:short)%%(end)" | findstr /v "^$" | fzf -m --height 40%% --reverse --ansi --header="[Git Delete Branch] TAB to multi-select, ENTER to delete (-D)" --preview "git log -15 --color=always --graph --pretty=format:\"%%Cred%%h%%Creset -%%C(yellow)%%d%%Creset %%s %%Cgreen(%%cr)%%Creset\" {1}" > "%TMP_OUT%"

if not exist "%TMP_OUT%" goto :end
for %%A in ("%TMP_OUT%") do if %%~zA equ 0 (
    del "%TMP_OUT%" 2>nul
    goto :end
)

:: 6. Delete selected branches
for /f "usebackq tokens=1" %%B in ("%TMP_OUT%") do (
    if not "%%B"=="" git branch -D "%%B"
)
del "%TMP_OUT%" 2>nul

:end
endlocal
