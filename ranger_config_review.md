# Ranger Config Review

## Overview

A solid, well-integrated ranger setup with good VCS awareness, FZF integration, and thoughtful preview chains. The colorscheme is well-structured. Below are all issues found, ranked by priority.

---

## 🔴 P1 — Bugs (Will break things)

### 1. Colorscheme class name mismatch → colorscheme doesn't load

**File:** `gruvbox.py`

**Issue:** The class is named `Default`, but ranger looks for a class matching the filename (`Gruvbox`). This means your custom colorscheme never loads — which is also why `rc.conf` uses `set colorscheme solarized` instead of `gruvbox`.

**Fix:** Rename class `Default` → `Gruvbox`, then change `rc.conf` to `set colorscheme gruvbox`.

---

### 2. `;dd` binding broken

**File:** `rc.conf`

**Issue:** `map ;dd eval fm.execute_console('delete %s')` — the `;` key opens ranger's console input mode, so pressing `;` then `dd` just types `dd` into the console. The binding never fires.

**Fix:** Use a different prefix key (e.g., `map dd ...` would conflict with default delete, so use `map Dd` or similar).

---

### 3. `;u` binding broken

**File:** `rc.conf`

**Issue:** Same as above — `map ;u eval fm.execute_console('shell gdu')` — the `;` captures the first keystroke for the console.

**Fix:** Use a different key (e.g., `map gu shell gdu`).

---

### 4. `handle_image` called twice for images

**File:** `scope.sh`

**Issue:** `handle_image` is invoked twice for image files:
1. At the top level when `PV_IMAGE_ENABLED=True`
2. Again from within `handle_mime`

The top-level call only handles `image/*` via chafa. `handle_mime` → `handle_image` handles `image/svg+xml` via convert + `image/*` via chafa. Redundant logic, confusing order of operations.

**Fix:** Remove the top-level `handle_image` call and let `handle_mime` route to it. Or consolidate image handling in one place.

---

## 🟠 P2 — Key Collisions (Unpredictable behavior)

### 5. `cf` overrides default

**File:** `rc.conf`

**Issue:** `map cf shell nvim ~/.config/ranger/rc.conf` — `cf` in ranger default opens the current directory in the file manager. Your binding silently replaces that.

**Fix:** Use a non-conflicting key like `;c` or `rc`.

---

### 6. `cW` overrides default

**File:** `rc.conf`

**Issue:** `map cW shell nvim ~/.config/ranger/commands.py` — `cW` is ranger's default "rename with chmod" (capital W). Your binding replaces it.

**Fix:** Use a non-conflicting key like `;C` or `;w`.

---

## 🟡 P3 — Suboptimal Config (Degraded UX)

### 7. Ueberzug vs chafa conflict

**Files:** `rc.conf` + `scope.sh`

**Issue:** `rc.conf` sets `preview_images_method ueberzug` which tells ranger to handle images via ueberzug directly (bypassing scope.sh for image files). But `scope.sh` also has chafa rendering for `image/*` with `exit 4` (terminal output). They conflict — which one actually renders images is unpredictable.

**Fix:** Pick one approach:
- **Ueberzug:** Remove chafa from scope.sh, let ranger handle images directly via ueberzug
- **Chafa:** Set `preview_images_method chafa` and `preview_images false`, let scope.sh handle all previews

---

### 8. `fzf_locate` uses exact match

**File:** `commands.py`

**Issue:** `command = f"fd ... | fzf -e -i ..."` — `-e` is exact match mode, `-i` is case-insensitive. Combined they do exact+caseless matching. Most users expect fzf-style fuzzy matching (default).

**Fix:** Drop `-e` to use fuzzy matching, or keep `-e` if you intentionally want exact prefix matches.

---

### 9. `fzf_locate` scans entire `~/`

**File:** `commands.py`

**Issue:** `fd . ~/` lists every file under the home directory before piping to fzf. On a large home directory this is very slow.

**Fix:** Add a depth limit (`--max-depth 5`), or search from the current directory and let the user navigate. Alternatively, only search common subdirectories.

---

### 10. No preview window sizing on FZF

**File:** `commands.py`

**Issue:** Both FZF commands use `--preview 'bat ...'` without `--preview-window`, so fzf uses its default 50% split. No control over sizing or wrapping.

**Fix:** Add e.g. `--preview-window=right:60%:wrap` for consistent behavior.

---

## 🔵 P4 — Polish & Missing Features

### 11. No syntax highlighter fallback

**File:** `scope.sh`

**Issue:** The `text/*` MIME handler only tries `bat`. If `bat` is not installed, it falls through to `exit 2` (raw file display, no highlighting).

**Fix:** Add a fallback chain like `bat || pygmentize -g || cat`.

---

### 12. No `--line-range` on bat in scope.sh

**File:** `scope.sh`

**Issue:** For text/* files, `bat` outputs the entire file. Large files will be slow and wasteful. Your FZF commands already limit to 500 lines via `--line-range :500`.

**Fix:** Add `--line-range :$((PV_HEIGHT * 2))` or `--line-range :500` to the scope.sh bat invocation.

---

### 13. No `--` in chafa call

**File:** `scope.sh`

**Issue:** `chafa -c 256 -s "${PV_WIDTH}x${PV_HEIGHT}" "${FILE_PATH}"` — if `FILE_PATH` starts with `-`, chafa interprets it as a flag. This is a minor security/robustness issue.

**Fix:** Add `--` before the path: `chafa -- -c 256 ... "${FILE_PATH}"` or `chafa -c 256 -s "${PV_WIDTH}x${PV_HEIGHT}" -- "${FILE_PATH}"`.

---

### 14. `PV_WIDTH` unguarded in `fmt`

**File:** `scope.sh`

**Issue:** `fmt -w "${PV_WIDTH}"` — if `PV_WIDTH` is empty/0 (e.g., when called for terminal previews with no width constraint), `fmt -w ""` will fail or use default width.

**Fix:** Use `fmt -w "${PV_WIDTH:-80}"` for a safe fallback.

---

### 15. No `global_inode_type_filter`

**File:** `rc.conf`

**Issue:** When using devicons (`default_linemode devicons`), file type icons work best with `global_inode_type_filter` enabled.

**Fix:** Add `set global_inode_type_filter true`.

---

### 16. No hidden files toggle

**File:** `rc.conf`

**Issue:** `set show_hidden true` is always on with no key to toggle it.

**Fix:** Add `map zh set show_hidden!`.

---

### 17. Ternary style in colorscheme

**File:** `gruvbox.py`

**Issue:** `fg = context.good and cyan or magenta` — this Python idiom works but is less readable than a proper ternary. If `context.good` were ever falsy for a non-boolean reason, the logic breaks.

**Fix:** `fg = cyan if context.good else magenta`.

---

### 18. CRLF in Python and config files

**Files:** `gruvbox.py`, `rc.conf`

**Issue:** Windows `\r\n` line endings. Works fine functionally but inconsistent with `scope.sh` which uses Unix `\n` line endings.

**Fix:** Convert to LF with `dos2unix` or your editor.

---

## Summary

| Priority | Count | Notes |
|----------|-------|-------|
| 🔴 P1 — Bugs | 4 | Colorscheme broken, 2 bindings broken, image handler logic bug |
| 🟠 P2 — Collisions | 2 | `cf` and `cW` override defaults |
| 🟡 P3 — UX | 4 | Image method conflict, fzf mode/speed/sizing issues |
| 🔵 P4 — Polish | 8 | Fallbacks, flags, features, style |
