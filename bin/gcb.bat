@echo off
setlocal enabledelayedexpansion

:: 1. Verify git is installed
where git >nul 2>nul || (echo Error: git is not installed or not in PATH.& goto :end)

:: 2. If arguments passed, pass directly to git checkout
if not "%~1"=="" (
    git checkout %*
    goto :end
)

:: 3. Verify fzf is installed
where fzf >nul 2>nul || (echo Error: fzf is not installed or not in PATH.& goto :end)

:: 4. Temporary file for fzf selection
set "TMP_OUT=%TEMP%\gcb_branch_%RANDOM%.txt"

:: 5. Run interactive fzf with branch preview
git branch --all --sort=-committerdate --format="%%(refname:short)" | findstr /v /i /c:"/HEAD" | fzf --height 40%% --reverse --ansi --preview "git log -15 --color=always --graph --pretty=format:\"%%Cred%%h%%Creset -%%C(yellow)%%d%%Creset %%s %%Cgreen(%%cr)%%Creset\" {1}" > "%TMP_OUT%"

if not exist "%TMP_OUT%" goto :end
for %%A in ("%TMP_OUT%") do if %%~zA equ 0 (
    del "%TMP_OUT%" 2>nul
    goto :end
)

:: 6. Extract branch name and checkout
set "BRANCH="
for /f "usebackq tokens=1" %%B in ("%TMP_OUT%") do (
    set "BRANCH=%%B"
)
del "%TMP_OUT%" 2>nul

if defined BRANCH (
    set "BRANCH=!BRANCH:origin/=!"
    set "BRANCH=!BRANCH:remotes/=!"
    git checkout !BRANCH!
)

:end
endlocal
