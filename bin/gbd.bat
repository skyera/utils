@echo off
setlocal enabledelayedexpansion

:: Check if git-forgit is available in PATH
where git-forgit >nul 2>nul
if %errorlevel% equ 0 (
    git forgit branch_delete %*
    goto :end
)

:: Verify git and fzf are installed
where git >nul 2>nul || (echo Error: git is not installed or not in PATH.& goto :end)
where fzf >nul 2>nul || (echo Error: fzf is not installed or not in PATH.& goto :end)

:: Temporary file to capture fzf output
set "TMP_OUT=%TEMP%\gbd_branches_%RANDOM%.txt"

:: Run interactive fzf branch selector with git log preview
git branch --format="%(refname:short)" | fzf -m --preview "git log --oneline --graph --color=always {}" --preview-window=right:60%% > "%TMP_OUT%"

if not exist "%TMP_OUT%" goto :end
for %%A in ("%TMP_OUT%") do if %%~zA equ 0 (
    del "%TMP_OUT%"
    goto :end
)

:: Delete each selected branch
for /f "usebackq delims=" %%B in ("%TMP_OUT%") do (
    if not "%%B"=="" (
        git branch -d "%%B" 2>nul || git branch -D "%%B"
    )
)

del "%TMP_OUT%" 2>nul

:end
endlocal
