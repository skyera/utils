# Snacks.nvim Configuration Review

## Overview

A comprehensive review of `folke/snacks.nvim` configuration and keybindings across the Neovim setup (`.config/nvim/lua/plugins/init.lua` and `.config/nvim/lua/config/keymaps.lua`).

`snacks.nvim` is a modern, high-performance plugin collection for Neovim providing integrated features such as a dashboard, picker, terminal, notifier, scratch buffer, zen mode, bigfile handling, indent guides, quickfile, statuscolumn, words (LSP reference highlighting), and Git utilities.

While the existing setup established basic picker mappings and dashboard configuration, it suffered from **duplicate keymap definitions across multiple files**, **unconfigured active modules (`bufdelete`, `git`, `scratch`, `zen`, `lazygit`, `explorer`, `input`)**, **missing global debug helpers (`_G.dd`, `_G.bt`)**, and **absent high-value picker mappings** (`lines`, `grep_word`, `keymaps`, `command_history`, `explorer`, `lazygit`).

Below are all identified issues, ranked by priority, followed by the applied refactoring.

---

## 🔴 P1 — Critical Issues & Redundancies

### 1. Duplicate Keymap Declarations Across Multiple Files

**Files:** [`.config/nvim/lua/plugins/init.lua`](file:///home/zliu/test/utils/.config/nvim/lua/plugins/init.lua#L75-L105) & [`.config/nvim/lua/config/keymaps.lua`](file:///home/zliu/test/utils/.config/nvim/lua/config/keymaps.lua#L46-L60)

**Issue:**
All `<leader>s*` picker mappings (`sf`, `sg`, `sb`, `sr`, `sh`, `su`, `sG`, `sn`, `sp`) and terminal mappings (`<c-/>`) were defined in **two separate places**:
1. Inside the `keys = { ... }` table of the `snacks.nvim` spec in `plugins/init.lua`.
2. Inside `keymaps.lua` using imperative `vim.keymap.set(...)` statements.

Maintaining duplicate keymap definitions across two files creates split-brain configuration, increases code debt, and risks keymap drift. Furthermore, `keymaps.lua` is loaded at startup before `lazy.nvim` initializes plugins, whereas `keys` in `lazy.nvim` automatically handles plugin lazy-loading and keymap registration seamlessly.

**Fix:** Consolidated all `snacks.nvim` keymap declarations into `plugins/init.lua` under the `keys` table spec, and removed the duplicate calls from `keymaps.lua` with a reference comment.

---

## 🟠 P2 — Suboptimal Module Configuration & Missing Native Integrations

### 2. Unconfigured Active Modules (`bufdelete`, `git`, `scratch`, `zen`, `lazygit`, `explorer`, `input`)

**File:** [`.config/nvim/lua/plugins/init.lua`](file:///home/zliu/test/utils/.config/nvim/lua/plugins/init.lua#L12-L55)

**Issue:**
Keybindings were bound for functions like `Snacks.bufdelete()` (`<leader>bd`), `Snacks.scratch()` (`<leader>.`), `Snacks.zen()` (`<leader>z`), and `Snacks.gitbrowse()` (`<leader>gB`), but their module declarations were absent from the `opts = { ... }` table.

While `snacks.nvim` can load some modules on-demand when invoked, explicitly defining module configs in `opts`:
- Ensures predictable module initialization and lifecycle management.
- Enables custom styling, option overrides, and feature toggles (such as `lazygit` terminal styling or `scratch` buffer defaults).

**Fix:** Explicitly added module tables into `opts`:
```lua
opts = {
  bigfile = { enabled = true },
  bufdelete = { enabled = true },
  dashboard = { enabled = true, ... },
  explorer = { enabled = true },
  git = { enabled = true },
  indent = { enabled = true, only_scope = true },
  input = { enabled = true },
  lazygit = { enabled = true },
  notifier = { enabled = true, timeout = 3000 },
  picker = { enabled = true },
  quickfile = { enabled = true },
  scratch = { enabled = true },
  statuscolumn = { enabled = true },
  terminal = { enabled = true },
  words = { enabled = true },
  zen = { enabled = true },
}
```

---

### 3. Missing Global Debug Helpers (`_G.dd`, `_G.bt`) and `VeryLazy` Initialization

**File:** [`.config/nvim/lua/plugins/init.lua`](file:///home/zliu/test/utils/.config/nvim/lua/plugins/init.lua#L62-L73)

**Issue:**
`snacks.nvim` provides modern debugging and inspection utilities (`Snacks.debug.inspect` and `Snacks.debug.backtrace`), as well as notification integrations. Without registering global aliases during Neovim initialization, developers cannot easily call `dd(...)` or inspect data structures interactively in Lua code.

**Fix:** Added an `init()` callback in `plugins/init.lua` with a `VeryLazy` autocommand:
```lua
init = function()
  vim.api.nvim_create_autocmd("User", {
    pattern = "VeryLazy",
    callback = function()
      _G.dd = function(...) Snacks.debug.inspect(...) end
      _G.bt = function() Snacks.debug.backtrace() end
      vim.print = _G.dd
    end,
  })
end
```

---

## 🟡 P3 — Missing Power-User Mappings & Ergonomics

### 4. Absent High-Value Picker & Utility Keybindings

**File:** [`.config/nvim/lua/plugins/init.lua`](file:///home/zliu/test/utils/.config/nvim/lua/plugins/init.lua#L75-L105)

**Issue:**
Several high-utility `Snacks` pickers and tools were missing dedicated keymaps:
- `Snacks.picker.lines()`: Search lines within current buffer.
- `Snacks.picker.grep_word()`: Search for word under cursor project-wide.
- `Snacks.picker.keymaps()`: Interactive keymap finder.
- `Snacks.picker.command_history()`: Command-line history picker.
- `Snacks.picker.explorer()`: Modern file tree picker.
- `Snacks.lazygit()`: Integrated floating Lazygit overlay terminal.

**Fix:** Expanded `keys` in `plugins/init.lua` to include:
- `{ "<leader>sl", function() Snacks.picker.lines() end, desc = "Search Buffer Lines (Snacks)" }`
- `{ "<leader>sw", function() Snacks.picker.grep_word() end, desc = "Search Cursor Word (Snacks)" }`
- `{ "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Search Keymaps (Snacks)" }`
- `{ "<leader>sc", function() Snacks.picker.command_history() end, desc = "Command History (Snacks)" }`
- `{ "<leader>se", function() Snacks.picker.explorer() end, desc = "File Explorer Picker (Snacks)" }`
- `{ "<leader>lg", function() Snacks.lazygit() end, desc = "Toggle Lazygit (Snacks)" }`
- Added terminal mode fallback `<c-_>` alongside `<c-/>` for full terminal emulator compatibility.

---

## 🔵 P4 — Multi-Picker Ecosystem Matrix

### Picker Namespace Mapping Comparison

The workspace cleanly organizes multiple search ecosystems via non-overlapping leader namespaces:

| Feature | `snacks.nvim` (`<leader>s*`) | `fzf-lua` (`<leader>f*` / `<leader>p*`) | `telescope.nvim` (`<leader>t*`) | `fzf.vim` (`<leader>v*`) |
| :--- | :--- | :--- | :--- | :--- |
| **Find Files** | `<leader>sf` | `<leader>ff` / `<leader>pf` | `<leader>tf` | `<leader>vf` |
| **Live Grep** | `<leader>sg` | `<leader>fg` / `<leader>pg` | `<leader>tg` | `<leader>vg` |
| **Buffers** | `<leader>sb` | `<leader>fb` / `<leader>pb` | `<leader>tb` | `<leader>vb` |
| **Recent Files** | `<leader>sr` | `<leader>fr` | `<leader>tr` | — |
| **Help Tags** | `<leader>sh` | `<leader>fh` | `<leader>th` | — |
| **Undo Tree** | `<leader>su` | — | — | — |
| **Git Status** | `<leader>sG` | — | — | — |
| **Buffer Lines** | `<leader>sl` | `<leader>fl` | — | `<leader>vl` |
| **Grep Word** | `<leader>sw` | `<leader>fw` | `<leader>tw` | — |
| **Keymaps** | `<leader>sk` | — | `<leader>tk` | — |
| **Explorer** | `<leader>se` | — | — | — |
| **Lazygit** | `<leader>lg` | — | — | — |

---

## Summary of Applied Changes

1. **Eliminated Keymap Duplication**: Removed duplicate `Snacks` mappings from `keymaps.lua` and unified them under `plugins/init.lua`'s `keys` spec.
2. **Explicit Module Activation**: Enabled `bufdelete`, `explorer`, `git`, `input`, `lazygit`, `scratch`, and `zen` explicitly in `opts`.
3. **Global Debug Setup**: Created `init()` callback with `VeryLazy` listener for `_G.dd`, `_G.bt`, and `vim.print` override.
4. **Expanded Picker Workflows**: Added `<leader>sl`, `<leader>sw`, `<leader>sk`, `<leader>sc`, `<leader>se`, and `<leader>lg` for comprehensive search and Git integration.
