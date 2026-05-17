# LF Config Review

## Overview

A clean, well-structured dual-platform (Linux + Windows) lf setup with good consistency between OSes. FZF integration, image previews via chafa, and Nerd Font icons are all solid choices. Below are all issues found, ranked by priority.

---

## 🔴 P1 — Bugs (Will break things)

### 1. Unquoted `$f` breaks on filenames with spaces

**Files:** `lfrc` (Linux), `lfrc_windows` (Windows)

**Issue:**
- Linux: `map e $$EDITOR $f` and `map <enter> $$EDITOR $f` — if `$f` contains spaces, the shell splits it into multiple arguments.
- Windows: `map e $if (Get-Command ...) { nvim $env:f }` — `$env:f` in PowerShell also needs quoting for paths with spaces.

**Fix:**
- Linux: `map e $$EDITOR "$f"` and `map <enter> $$EDITOR "$f"`
- Windows: `map e $if (Get-Command nvim -ErrorAction SilentlyContinue) { nvim "$env:f" } else { vim "$env:f" }`

---

### 2. `cmd delete` is unsafe and fragile

**File:** `lfrc`

**Issue:**
1. `rm -rf $fx` — unquoted `$fx` breaks on spaces (deletes wrong files).
2. `read -r ans` in an lf `%{{` command is unreliable; stdin may not be connected to the terminal in all contexts (e.g., inside tmux, over SSH, or certain terminal emulators).
3. With `set shellopts '-eu'`, if `$fx` is empty (no selection), `rm -rf` may still misbehave.

**Fix:** Use lf's built-in `delete` command (if available in your lf version) or a simpler shell approach. At minimum, quote everything:
```bash
cmd delete %{{
    printf "Delete? [y/n] "
    read -r ans
    [ "$ans" = "y" ] && rm -rf "$fx"
}}
```
Better yet, use a synchronous `$` command so the terminal is properly attached:
```bash
map D $printf "Delete $f? [y/n] " && read ans && [ "$ans" = "y" ] && rm -rf "$fx"
```

---

### 3. `echo -n` does not work in PowerShell

**File:** `lfrc_windows`

**Issue:** `map <c-c> $echo -n $env:f | clip` — `echo` in PowerShell is an alias for `Write-Output`, which has **no `-n` parameter**. This command will either error or output `-n` literally before the path.

**Fix:** Use PowerShell-native clipboard or suppress the newline properly:
```powershell
map <c-c> $Set-Clipboard -Value $env:f
```
Or if `Set-Clipboard` is unavailable (older Windows PowerShell):
```powershell
map <c-c> $[Console]::Out.Write($env:f) | clip
```

---

### 4. Preview scripts use fixed size instead of lf-provided dimensions

**Files:** `bin/lf-preview.sh`, `bin/lf-preview.bat`

**Issue:** Both scripts hardcode `--size=40x20` for chafa. lf passes preview width and height as `$2` and `$3` to the previewer script. Ignoring them means:
- Wasted space in large preview panes
- Truncated images in small panes
- Inconsistent experience across window resizes

**Fix:**
- `lf-preview.sh`: Use `WIDTH=${2:-40}; HEIGHT=${3:-20}; [ "$WIDTH" -lt 1 ] && WIDTH=1; [ "$HEIGHT" -lt 1 ] && HEIGHT=1` and `chafa --size="${WIDTH}x${HEIGHT}"`.
- `lf-preview.bat`: Use `if "%WIDTH%"=="0" set "WIDTH=1"` etc.
- Also made extension matching case-insensitive and added `file` utility fallback for images without extensions.

---

### 5. `lf-preview.bat` extension check is buggy

**File:** `bin/lf-preview.bat`

**Issue:** `if /i "%FILE:~-4%"==".png"` checks the last 4 characters of the full path, not the extension. A file like `C:\path.to\myfile.png` would fail because `:-4` gives `.png` (correct), but `C:\path.png\myfile.txt` would match `.png` incorrectly.

Wait — actually `C:\path.png\myfile.txt` gives `.txt` as the last 4 chars. But `C:\my.dir\file.png` is fine. The real issue is `C:\my.png` (a file without extension named `my.png`) — it works. A dir like `C:\test\file.bak.png` also works.

The actual bug: `C:\some.dir\file` (no extension) with `:-4` checks `file` → not `.png`, fine. But for `.jpeg` (5 chars), `:-5` on `C:\a\b.jpeg` gives `.jpeg`, fine. However, for a path like `C:\test.jpeg\other.jpg`, `:-4` on the full path gives `.jpg`... no, the full path ends with `.jpg`.

Actually the bigger issue is a file named `some.png.txt` — `:-4` gives `.txt` so it won't match `.png`. That's correct.

But consider: `C:\Users\name.dir\image.png` — `:-4` gives `.png`, correct.

Hmm, the substring approach is actually mostly correct for files. But a proper way is `%~x1` which gives the extension.

**Fix:** Use `%~x1` (batch parameter extension for file extension):
```batch
if /i "%~x1"==".png" goto :image
```

---

### 6. Video extensions incorrectly categorized as images in icons

**File:** `.config/lf/icons`

**Issue:** `.mov`, `.mpg`, `.mpeg`, `.mkv`, `.mp4`, `.avi`, `.flv`, etc. are listed under the `# image formats` section and all assigned the image icon ``. They should have their own section (ideally with a video icon like `` or a distinct one) and at minimum a comment that reflects reality.

**Fix:** Move video extensions to a `# video formats` section. If keeping the same icon, at least fix the comment.

---

## 🟠 P2 — Behavior Issues (Risky or inconsistent)

### 7. `set shellopts '-eu'` is too strict for lf

**File:** `lfrc`

**Issue:** `-e` (exit on error) and `-u` (error on unset variables) break legitimate lf workflows:
- `-e`: If any command in a chain returns non-zero (e.g., `bat` on a binary file, `rm` on a nonexistent file), the shell aborts the entire command.
- `-u`: If `$f` or `$fx` is ever unset (empty directory, no selection), the shell errors out immediately.

Many lf commands and plugins assume a forgiving shell.

**Fix:** Remove `set shellopts '-eu'` or use a more conservative set like `set shellopts '-e'` without `-u`. Better yet, leave it at the default and add error handling only where needed in individual commands.

---

### 8. Windows editor mappings block lf

**File:** `lfrc_windows`

**Issue:** `map e $if (Get-Command ...)` and `map <enter> $if ...` use `$` (synchronous execution). This means lf **blocks** until the editor exits. On Linux, `map e $$EDITOR "$f"` uses `$$` (async) so the editor opens in the background and lf remains interactive.

**Fix:** Decide the desired behavior. If you want lf to stay interactive while editing (like Linux), use `$$`:
```powershell
map e $$if (Get-Command nvim ...) { nvim "$env:f" } else { vim "$env:f" }
```
If blocking is intentional, document it. But consistency across platforms is better.

---

### 9. `cmd doc` likely doesn't work as intended

**File:** `lfrc`

**Issue:** `cmd doc $lf -doc | bat -p` — `cmd` without `%{{` defines an lf command sequence, not a shell block. The pipe (`|`) may not work as a shell pipe in this context because lf may interpret `|` as its own command separator.

**Fix:** Use a shell block:
```bash
cmd doc %{{
    $lf -doc | bat -p
}}
```
Or simply: `cmd doc $lf -doc | less` if piping works in your lf version. Verify with `:doc` in lf.

---

### 10. `fzf_find` temp files use predictable names

**Files:** `bin/fzf_find.sh`, `bin/fzf_find.bat`

**Issue:** `/tmp/fzf_result.txt` and `%TEMP%\fzf_result.txt` are hardcoded. If multiple lf instances run fzf simultaneously, they will collide and overwrite each other's results.

**Fix:** Use `mktemp` on Linux:
```bash
tmpfile=$(mktemp /tmp/lf_fzf.XXXXXX)
# ... use $tmpfile ...
rm "$tmpfile"
```
On Windows, use `%RANDOM%`:
```batch
set "tmpfile=%TEMP%\lf_fzf_%RANDOM%.txt"
```

---

## 🟡 P3 — UX / Suboptimal Config

### 11. Preview scripts handle only images and text

**Files:** `bin/lf-preview.sh`, `bin/lf-preview.bat`

**Issue:** No handling for:
- Directories (could show `ls`/`exa`/`eza` output)
- Symlinks (could show target info)
- Archives (could show contents with `unzip -l`, `tar -tf`)
- Binary files (could show `file` output + hex dump)
- Empty files

**Fix:** Add a `case`/`if` ladder for common file types, mirroring the richer preview logic in `scope.sh` (from the ranger config).

---

### 12. Colors missing modern file extensions

**File:** `.config/lf/colors`

**Issue:** Missing `.webp`, `.heic`, `.avif` for images, and `.7z` is listed but `.rar`, `.tar.gz`, `.tar.xz` coverage is incomplete (`.tar.gz` is not matched by `*.tar` or `*.gz` because lf colors don't chain extensions like dircolors). Also no `.json`, `.toml`, `.yaml` colors for config files.

**Fix:** Add modern extensions. Note that lf's colors format does **not** support compound extensions like `*.tar.gz`; you would need `*.gz` which already exists.

---

### 13. Linux has `mkdir`/`touch`/`delete` custom commands, Windows lacks them

**File:** `lfrc_windows`

**Issue:** The Linux config adds useful custom commands (`mkdir`, `touch`, `delete`). The Windows config has none of these, creating an inconsistent experience.

**Fix:** Add PowerShell equivalents:
```powershell
cmd mkdir %{{
    New-Item -ItemType Directory -Path "$args"
    lf -remote "send $env:id reload"
}}

cmd touch %{{
    New-Item -ItemType File -Path "$args"
    lf -remote "send $env:id reload"
}}
```

---

### 14. `go_origin` navigation is slightly fragile

**File:** `lfrc` and `lfrc_windows`

**Issue:** The command relies on `$(pwd)` or `$PWD` being evaluated at lf startup. If lf is launched from a directory that later gets renamed or deleted, `go_origin` will fail.

This is a minor edge case, but worth noting.

**Fix:** Consider using a shell wrapper that stores the original directory in an environment variable before launching lf, or simply document the behavior.

---

## 🔵 P4 — Polish & Missing Features

### 15. `lfrc.default` `map f filter` is dead code on Linux/Windows

**File:** `.config/lf/lfrc.default`

**Issue:** `map f filter` is defined in the default, but both `lfrc` and `lfrc_windows` override it with `map f :fzf_find`. This is fine functionally, but if you ever stop sourcing the default or change the override, the default behavior might surprise you.

**Fix:** Add a comment in `lfrc.default` noting that `f` is remapped by platform configs, or remove `map f filter` from the default if it's never used.

---

### 16. `lfrc_windows` hardcodes `c:\app\bin`

**File:** `lfrc_windows`

**Issue:** `set previewer 'c:\app\bin\lf-preview.bat'` and `cmd fzf_find $C:/app/bin/fzf_find.bat` assume a fixed `c:\app\bin` directory. This makes the config non-portable.

**Fix:** Use `%USERPROFILE%\bin` or a configurable environment variable, and document the expected layout.

---

### 17. No `hidden` toggle comment in Windows

**File:** `lfrc_windows`

**Issue:** `set hidden false` is set, and `zh` toggles it via the default config, but it's not obvious because `map zh set hidden!` is only in `lfrc.default`.

**Fix:** Add `map zh set hidden!` explicitly in `lfrc_windows` for clarity, or add a comment.

---

### 18. `lf-preview.bat` doesn't pass extra args to bat

**File:** `bin/lf-preview.bat`

**Issue:** For non-image files, `bat --style="numbers" --color=always --paging=never "%FILE%"` uses `"numbers"` style, while the Linux version uses `"plain,numbers"`. This inconsistency means Windows previews show headers/decorations that Linux doesn't.

**Fix:** Align Windows with Linux: `bat --style="plain,numbers" --color=always --paging=never`.

---

### 19. fzf_find scripts could include directories

**Files:** `bin/fzf_find.sh`, `bin/fzf_find.bat`

**Issue:** `fd . --type f` only finds files. Sometimes you want to jump to a directory.

**Fix:** Consider `fd . --type f --type d` or make it configurable.

---

### 20. No lf version guard or conditional config

**File:** all

**Issue:** lf occasionally adds new options. Using very new features without guarding them can break on older lf versions (e.g., `set drawbox` was added in a relatively recent version).

**Fix:** Not critical, but adding a comment noting the minimum lf version required by these configs is helpful for future setup.

---

## Summary

| Priority | Count | Notes |
|----------|-------|-------|
| 🔴 P1 — Bugs | 6 | Unquoted paths, broken PowerShell echo, fixed-size previews, buggy ext check, wrong icon categorization |
| 🟠 P2 — Behavior | 4 | Strict shellopts, sync editor blocks lf, doc cmd syntax, temp file collisions |
| 🟡 P3 — UX | 4 | Limited preview types, missing colors, missing Windows commands, fragile go_origin |
| 🔵 P4 — Polish | 5 | Dead code, hardcoded paths, style inconsistency, missing dir search, no version notes |
