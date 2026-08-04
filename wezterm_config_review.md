# WezTerm Config Review

## Overview

A review of `.wezterm.lua` targeting configuration correctness, UI responsiveness, keybinding ergonomics, and modern WezTerm features.

While the existing setup established a basic Gruvbox theme and status bar, it suffered from **layout thrashing inside `update-status`**, **incomplete Leader keybindings**, **disabled Kitty keyboard protocol**, hardcoded hex colors, and a sub-optimal default shell on Windows (`cmd.exe`).

Below are all identified issues, ranked by priority, followed by the implemented fixes.

---

## 🔴 P1 — Critical Issues & Performance Bottlenecks

### 1. Dynamic Config Overrides inside `update-status` Event (Layout Thrashing & CPU Lag)

**File:** [`.wezterm.lua`](file:///C:/test/utils/.wezterm.lua#L81-L89)

**Issue:**
```lua
wezterm.on("update-status", function(window, pane)
    local overrides = window:get_config_overrides() or {}
    local dimensions = pane:get_dimensions()
    local show_scroll_bar = dimensions.scrollback_rows > dimensions.viewport_rows and not pane:is_alt_screen_active()

    if overrides.enable_scroll_bar ~= show_scroll_bar then
        overrides.enable_scroll_bar = show_scroll_bar
        window:set_config_overrides(overrides)
    end
...
```
`set_config_overrides` forces WezTerm to recalculate window geometry and re-render. Toggling `enable_scroll_bar` dynamically changes the viewport pixel width, which immediately triggers another status event. Executing `set_config_overrides` inside `update-status` on every tick creates **infinite layout thrashing, UI flicker, and CPU spikes**.

**Fix:** Remove dynamic `set_config_overrides` calls from `update-status`. Set `config.enable_scroll_bar = true` statically or handle viewport scrollbar preferences globally.

---

### 2. Half-Baked Leader Key & Missing Core Navigation Bindings

**File:** [`.wezterm.lua`](file:///C:/test/utils/.wezterm.lua#L57-L77)

**Issue:**
- `config.leader` was set to `CTRL+/`, but splitting (`CTRL+SHIFT+"`, `CTRL+SHIFT+%`) didn't use `LEADER`.
- No keybindings existed for **pane navigation** (`LEADER + h/j/k/l`).
- No keybindings existed for **closing panes** (`LEADER + x`), **toggling zoom** (`LEADER + z`), or **tab switching** (`LEADER + 1..9`).
- Only tab renaming (`LEADER + ,`) was bound under `LEADER`.

**Fix:** Add tmux-idiomatic keymaps under `LEADER`:
- `LEADER + h/j/k/l`: Switch active pane focus (Left / Down / Up / Right).
- `LEADER + -` & `LEADER + |`: Split pane vertically and horizontally.
- `LEADER + x`: Close current pane.
- `LEADER + z`: Toggle pane zoom (maximize pane).
- `LEADER + c`: Create new tab.
- `LEADER + 1..9`: Jump directly to tabs 1 through 9.

---

### 3. Sub-optimal Default Shell on Windows (`cmd.exe`)

**File:** [`.wezterm.lua`](file:///C:/test/utils/.wezterm.lua#L20-L26)

**Issue:**
```lua
if os:find("windows") then
    config.default_prog = { "cmd.exe" }
```
`cmd.exe` lacks modern UTF-8 support out of the box, lacks rich prompt support, and does not support modern shell integration features.

**Fix:** Default to `powershell.exe` with `-NoLogo` on Windows systems.

---

## 🟡 P2 — Usability & Visual Inconsistencies

### 4. Disabled Kitty Keyboard Protocol (`enable_kitty_keyboard = false`)

**File:** [`.wezterm.lua`](file:///C:/test/utils/.wezterm.lua#L36)

**Issue:** Disabling kitty keyboard protocol (`config.enable_kitty_keyboard = false`) prevents terminal applications like Neovim, Helix, and modern CLI tools from receiving enhanced key events (such as distinguishing `<C-i>` from `<Tab>` or `<C-[>` from `<Esc>`).

**Fix:** Set `config.enable_kitty_keyboard = true`.

---

### 5. Zero Vertical Window Padding (`top = 0, bottom = 0`)

**File:** [`.wezterm.lua`](file:///C:/test/utils/.wezterm.lua#L34)

**Issue:** `config.window_padding = { left = 2, right = 2, top = 0, bottom = 0 }` causes text lines at the top and bottom edges to touch the window frame, causing clipping on high-DPI scaling setups.

**Fix:** Increase padding to a balanced `{ left = 4, right = 4, top = 4, bottom = 4 }`.

---

### 6. Hardcoded Color Values in `update-status` Right Status

**File:** [`.wezterm.lua`](file:///C:/test/utils/.wezterm.lua#L97-L105)

**Issue:** `Foreground = { Color = "#fabd2f" }` and `Foreground = { Color = "#ffffff" }` hardcoded colors break if the user switches color schemes.

**Fix:** Dynamically query `window:effective_config().resolved_palette` so status text colors adapt to whatever color scheme is active (`palette.ansi[4]` and `palette.foreground`).

---

### 7. Incomplete Tab Bar Styling

**File:** [`.wezterm.lua`](file:///C:/test/utils/.wezterm.lua#L48-L55)

**Issue:** Only `active_tab` was styled. `inactive_tab`, `inactive_tab_hover`, and `new_tab` fell back to default WezTerm colors, creating visual contrast glitches when `use_fancy_tab_bar = false`.

**Fix:** Add explicit Gruvbox colors for `inactive_tab`, `inactive_tab_hover`, `new_tab`, `new_tab_hover`, and `background`.

---

## 🟢 P3 — Code Quality & Font Fallbacks

### 8. Incomplete Font Fallback Chain

**File:** [`.wezterm.lua`](file:///C:/test/utils/.wezterm.lua#L38-L41)

**Issue:** Font fallback chain only contained `Hack Nerd Font` and `JetBrains Mono`. Emoji symbols and CJK characters were missing fallback definitions.

**Fix:** Add `Segoe UI Emoji` (for Windows) and `Microsoft YaHei` (for CJK) to fallback list.

---

### 9. Color Scheme Name Normalization (`GruvboxDark`)

**File:** [`.wezterm.lua`](file:///C:/test/utils/.wezterm.lua#L29)

**Issue:** WezTerm's built-in theme registry registers Gruvbox dark as `"GruvboxDark"`, `"Gruvbox (Gogh)"`, or `"Gruvbox Dark (Gogh)"`. Setting `color_scheme = "Gruvbox Dark"` with a space causes WezTerm to fail theme lookup at runtime, resulting in startup warnings or window instantiation failures.

**Fix:** Standardize scheme name to built-in `"GruvboxDark"`.

---

## Summary of Applied Changes

The `.wezterm.lua` file has been refactored and updated with:
1. Removal of `set_config_overrides` loop in `update-status`.
2. Full tmux-style pane and tab keybindings under `LEADER` (`CTRL+/`).
3. Modern PowerShell default shell on Windows.
4. Progressive keyboard enhancement enabled (`enable_kitty_keyboard = true`).
5. Unified Gruvbox styling (`GruvboxDark`) across tab bar and dynamic status bar.
6. Expanded font fallback chain for Emoji & CJK text rendering.
