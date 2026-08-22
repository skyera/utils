@echo off
setlocal enabledelayedexpansion

:: Capture script and repository directory early before shift affects %0
set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..") do set "REPO_DIR=%%~fI"
set "ALACRITTY_DIR=%APPDATA%\alacritty"
set "TARGET_FILE=%ALACRITTY_DIR%\shell.toml"
set "REPO_TARGET=!REPO_DIR!\.config\alacritty\shell.toml"

:: Parse command-line flags (-w / --window / -n / --new / -e / --exec / -i / -r / -c / --current / -h / --help)
set "NEW_WINDOW=0"
set "SHOW_CURRENT=0"
set "EXEC_SHELL=0"
set "QUERY="

:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="-w" (set "NEW_WINDOW=1" & shift & goto :parse_args)
if /i "%~1"=="--window" (set "NEW_WINDOW=1" & shift & goto :parse_args)
if /i "%~1"=="-n" (set "NEW_WINDOW=1" & shift & goto :parse_args)
if /i "%~1"=="--new" (set "NEW_WINDOW=1" & shift & goto :parse_args)
if /i "%~1"=="-e" (set "EXEC_SHELL=1" & shift & goto :parse_args)
if /i "%~1"=="--exec" (set "EXEC_SHELL=1" & shift & goto :parse_args)
if /i "%~1"=="-i" (set "EXEC_SHELL=1" & shift & goto :parse_args)
if /i "%~1"=="-r" (set "EXEC_SHELL=1" & shift & goto :parse_args)
if /i "%~1"=="--run" (set "EXEC_SHELL=1" & shift & goto :parse_args)
if /i "%~1"=="-c" (set "SHOW_CURRENT=1" & shift & goto :parse_args)
if /i "%~1"=="--current" (set "SHOW_CURRENT=1" & shift & goto :parse_args)
if /i "%~1"=="-h" goto :show_help
if /i "%~1"=="--help" goto :show_help
if /i "%~1"=="/?" goto :show_help
if not defined QUERY set "QUERY=%~1"
shift
goto :parse_args
:args_done

if "%SHOW_CURRENT%"=="1" (
    if exist "%TARGET_FILE%" (
        echo Current Alacritty shell config ^(%TARGET_FILE%^):
        type "%TARGET_FILE%"
    ) else (
        echo [INFO] No shell.toml found at "%TARGET_FILE%". Using Alacritty default.
    )
    exit /b 0
)

:: Detect available shells
set "SHELL_COUNT=0"

:: 1. CMD
call :register_shell "cmd" "cmd.exe" "" "Command Prompt"

:: 2. PowerShell (Windows PowerShell)
where powershell >nul 2>&1
if !errorlevel! equ 0 (
    call :register_shell "powershell" "powershell.exe" "-NoLogo" "Windows PowerShell (5.1)"
)

:: 3. PowerShell 7+ (pwsh)
where pwsh >nul 2>&1
if !errorlevel! equ 0 (
    call :register_shell "pwsh" "pwsh.exe" "-NoLogo" "PowerShell 7+ (pwsh)"
) else (
    if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
        call :register_shell "pwsh" "%ProgramFiles%\PowerShell\7\pwsh.exe" "-NoLogo" "PowerShell 7+ (pwsh)"
    )
)

:: 4. Git Bash
set "GIT_BASH_PATH="
if exist "%ProgramFiles%\Git\bin\bash.exe" (
    set "GIT_BASH_PATH=%ProgramFiles%\Git\bin\bash.exe"
) else if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" (
    set "GIT_BASH_PATH=%ProgramFiles(x86)%\Git\bin\bash.exe"
) else if exist "%LocalAppData%\Programs\Git\bin\bash.exe" (
    set "GIT_BASH_PATH=%LocalAppData%\Programs\Git\bin\bash.exe"
)
if defined GIT_BASH_PATH (
    call :register_shell "git-bash" "!GIT_BASH_PATH!" "--login -i" "Git Bash"
    call :register_shell "bash" "!GIT_BASH_PATH!" "--login -i" "Git Bash (alias)"
)

:: 5. WSL
where wsl >nul 2>&1
if !errorlevel! equ 0 (
    call :register_shell "wsl" "wsl.exe" "~" "Windows Subsystem for Linux (WSL)"
)

:: 6. Cygwin
if exist "C:\cygwin64\bin\bash.exe" (
    call :register_shell "cygwin" "C:\cygwin64\bin\bash.exe" "--login -i" "Cygwin Bash (64-bit)"
) else if exist "C:\cygwin\bin\bash.exe" (
    call :register_shell "cygwin" "C:\cygwin\bin\bash.exe" "--login -i" "Cygwin Bash (32-bit)"
)

:: 7. Nushell
where nu >nul 2>&1
if !errorlevel! equ 0 (
    call :register_shell "nu" "nu.exe" "" "Nushell"
)

set "SELECTED_KEY="

:: Direct query matching
if defined QUERY (
    set "Q_LOWER=!QUERY!"
    for /l %%i in (1,1,%SHELL_COUNT%) do (
        if /i "!Q_LOWER!"=="!SHELL_KEY_%%i!" set "SELECTED_KEY=%%i"
    )
    if not defined SELECTED_KEY (
        for /l %%i in (1,1,%SHELL_COUNT%) do (
            if not defined SELECTED_KEY (
                echo !SHELL_KEY_%%i! | findstr /i /c:"!Q_LOWER!" >nul 2>&1
                if !errorlevel! equ 0 set "SELECTED_KEY=%%i"
            )
        )
    )
    if not defined SELECTED_KEY (
        echo [ERROR] Shell "!QUERY!" not found or not installed.
        echo Available shells:
        for /l %%i in (1,1,%SHELL_COUNT%) do (
            echo   - !SHELL_KEY_%%i! ^(!SHELL_LABEL_%%i!^)
        )
        exit /b 1
    )
) else (
    :: Interactive selection via fzf or fallback prompt
    where fzf >nul 2>&1
    if !errorlevel! equ 0 (
        set "TMP_SHELLS=%TEMP%\alacritty_shells_%RANDOM%.txt"
        set "TMP_OUT=%TEMP%\alacritty_shell_%RANDOM%.txt"
        (
            for /l %%i in (1,1,%SHELL_COUNT%) do (
                echo !SHELL_KEY_%%i!	!SHELL_LABEL_%%i!	!SHELL_PROG_%%i!
            )
        ) > "!TMP_SHELLS!"
        type "!TMP_SHELLS!" | fzf --prompt="Select Alacritty Shell > " --with-nth=1,2 --delimiter="\t" --layout=reverse --height=40%% --border --header="TAB: key / description" --no-preview > "!TMP_OUT!"
        if exist "!TMP_SHELLS!" del "!TMP_SHELLS!" 2>nul
        if exist "!TMP_OUT!" (
            for /f "usebackq tokens=1 delims=	" %%I in ("!TMP_OUT!") do (
                set "SEL_NAME=%%I"
            )
            del "!TMP_OUT!" 2>nul
            if defined SEL_NAME (
                for /l %%i in (1,1,%SHELL_COUNT%) do (
                    if /i "!SEL_NAME!"=="!SHELL_KEY_%%i!" set "SELECTED_KEY=%%i"
                )
            )
        )
    ) else (
        echo Available Alacritty Shells:
        for /l %%i in (1,1,%SHELL_COUNT%) do (
            echo   %%i. !SHELL_KEY_%%i! - !SHELL_LABEL_%%i! [!SHELL_PROG_%%i!]
        )
        set /p "CHOICE=Select shell number or name: "
        if defined CHOICE (
            for /l %%i in (1,1,%SHELL_COUNT%) do (
                if "!CHOICE!"=="%%i" set "SELECTED_KEY=%%i"
                if /i "!CHOICE!"=="!SHELL_KEY_%%i!" set "SELECTED_KEY=%%i"
            )
        )
    )
)

if not defined SELECTED_KEY (
    echo No shell selected.
    exit /b 0
)

set "TARGET_PROG=!SHELL_PROG_%SELECTED_KEY%!"
set "TARGET_ARGS=!SHELL_ARGS_%SELECTED_KEY%!"
set "TARGET_LABEL=!SHELL_LABEL_%SELECTED_KEY%!"
set "TARGET_KEY=!SHELL_KEY_%SELECTED_KEY%!"

:: Escape backslashes for TOML
set "TOML_PROG=!TARGET_PROG:\=\\!"

:: Generate shell.toml
set "TMP_CONFIG=%TEMP%\alacritty_shell_gen_%RANDOM%.toml"
(
    echo [terminal.shell]
    echo program = "!TOML_PROG!"
    if not "!TARGET_ARGS!"=="" (
        set "ARGS_LINE="
        for %%a in (!TARGET_ARGS!) do (
            if not defined ARGS_LINE (
                set ARGS_LINE="%%~a"
            ) else (
                set ARGS_LINE=!ARGS_LINE!, "%%~a"
            )
        )
        echo args = [!ARGS_LINE!]
    )
) > "!TMP_CONFIG!"

if not exist "%ALACRITTY_DIR%" mkdir "%ALACRITTY_DIR%" 2>nul
copy /Y "!TMP_CONFIG!" "%TARGET_FILE%" >nul 2>&1
if exist "!REPO_DIR!\.config\alacritty\." (
    copy /Y "!TMP_CONFIG!" "!REPO_TARGET!" >nul 2>&1
)
if exist "!TMP_CONFIG!" del "!TMP_CONFIG!" 2>nul

echo [Alacritty] Default shell set to: !TARGET_KEY! (!TARGET_LABEL!)

:: If -w / -n flag specified, spawn new window immediately
if "%NEW_WINDOW%"=="1" (
    where alacritty >nul 2>&1
    if !errorlevel! equ 0 (
        if not "!TARGET_ARGS!"=="" (
            alacritty msg create-window -e "!TARGET_PROG!" !TARGET_ARGS! 2>nul || start "" alacritty -e "!TARGET_PROG!" !TARGET_ARGS!
        ) else (
            alacritty msg create-window -e "!TARGET_PROG!" 2>nul || start "" alacritty -e "!TARGET_PROG!"
        )
        echo [Alacritty] Opened new window with !TARGET_KEY!.
    )
)

:: If -e / --exec / -i / -r flag specified, launch shell in current console
if "%EXEC_SHELL%"=="1" (
    if not "!TARGET_ARGS!"=="" (
        "!TARGET_PROG!" !TARGET_ARGS!
    ) else (
        "!TARGET_PROG!"
    )
)

endlocal
exit /b 0

:register_shell
set /a SHELL_COUNT+=1
set "SHELL_KEY_%SHELL_COUNT%=%~1"
set "SHELL_PROG_%SHELL_COUNT%=%~2"
set "SHELL_ARGS_%SHELL_COUNT%=%~3"
set "SHELL_LABEL_%SHELL_COUNT%=%~4"
exit /b 0

:show_help
echo Usage: shell [OPTIONS] [SHELL_NAME]
echo.
echo Switch Alacritty's default shell dynamically or launch a new window.
echo.
echo Options:
echo   -e, --exec, -i, -r         Launch/enter the selected shell in current console
echo   -w, --window, -n, --new    Open a new Alacritty window with the selected shell
echo   -c, --current              Display currently configured shell
echo   -h, --help                 Show this help message
echo.
echo Available shell names (when installed):
echo   cmd, powershell, pwsh, git-bash, bash, wsl, cygwin, nu
echo.
echo Examples:
echo   shell                      Interactive selection via fzf
echo   shell -e                   Interactive selection and launch in current console
echo   shell cmd                  Set default shell to Command Prompt
echo   shell -e powershell        Enter Windows PowerShell immediately
echo   shell -e git-bash          Enter Git Bash immediately
echo   shell -w wsl               Open new WSL window immediately
exit /b 0
