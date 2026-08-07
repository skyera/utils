# Snacks.nvim Configuration Review

## Overview

A comprehensive review of `folke/snacks.nvim` configuration and keybindings across the Neovim setup ([`.config/nvim/lua/plugins/init.lua`](file:///home/zliu/test/utils/.config/nvim/lua/plugins/init.lua) and [`.config/nvim/lua/config/keymaps.lua`](file:///home/zliu/test/utils/.config/nvim/lua/config/keymaps.lua)).

`snacks.nvim` is a modern, high-performance plugin collection for Neovim providing integrated features such as a dashboard, picker, floating terminal, notifier, scratch buffer, zen mode, bigfile handling, smooth scrolling, focus dimming, indent guides, quickfile, statuscolumn, words (LSP reference highlighting), file rename, git utilities, and debug helpers.

While the original setup established basic picker mappings and dashboard configuration, a detailed code audit identified several areas for structural, functional, and ergonomic enhancement. Below are all findings and applied improvements.

---

## 🔴 P1 — Critical Structural Cleanups

### 1. Keymap Duplication Resolution

**Files:** [`.config/nvim/lua/plugins/init.lua`](file:///home/zliu/test/utils/.config/nvim/lua/plugins/init.lua#L73-L110) & [`.config/nvim/lua/config/keymaps.lua`](file:///home/zliu/test/utils/.config/nvim/lua/config/keymaps.lua#L46-L48)

**Analysis:**
Keymaps were previously split between `keymaps.lua` (imperative `vim.keymap.set`) and `plugins/init.lua` (`keys` table in `lazy.nvim` spec). Maintaining keybindings in two places creates split-brain configuration and risks keymap drift. Furthermore, defining mappings inside `keys` in `lazy.nvim` enables proper lazy-loading triggers and cleaner lifecycle management.

**Resolution:**
All `snacks.nvim` keymap declarations are centralized inside `plugins/init.lua` under the `keys` table spec, with a clear reference comment retained in `keymaps.lua`.

---

## 🟠 P2 — Module Configuration & Native Integrations

### 2. Comprehensive Module Activation in `opts`

**File:** [`.config/nvim/lua/plugins/init.lua`](file:///home/zliu/test/utils/.config/nvim/lua/plugins/init.lua#L12-L61)

**Analysis:**
Several active utilities (such as `dim`, `scroll`, `gitbrowse`, `rename`, `bufdelete`, `scratch`, `zen`, `lazygit`, `explorer`, `input`) were missing explicit entries in the `opts = { ... }` configuration table.

Explicitly specifying module states in `opts`:
- Guarantees predictable module initialization.
- Exposes module-level customization (e.g., custom notification timeouts, scroll animation curves, focus dimming).

**Configured Modules:**
```lua
opts = {
  bigfile = { enabled = true },
  bufdelete = { enabled = true },
  dashboard = { enabled = true, preset = { ... }, sections = { ... } },
  dim = { enabled = true },
  explorer = { enabled = true },
  git = { enabled = true },
  gitbrowse = { enabled = true },
  indent = { enabled = true, only_scope = true },
  input = { enabled = true },
  lazygit = { enabled = true },
  notifier = { enabled = true, timeout = 3000 },
  picker = { enabled = true },
  quickfile = { enabled = true },
  rename = { enabled = true },
  scratch = { enabled = true },
  scroll = { enabled = true },
  statuscolumn = { enabled = true },
  terminal = { enabled = true },
  words = { enabled = true },
  zen = { enabled = true },
}
```

---

### 3. Global Debug Helpers & `VeryLazy` Lifecycle Hook

**File:** [`.config/nvim/lua/plugins/init.lua`](file:///home/zliu/test/utils/.config/nvim/lua/plugins/init.lua#L62-L72)

**Analysis:**
`snacks.nvim` provides modern debugging utilities (`Snacks.debug.inspect` and `Snacks.debug.backtrace`). Exposing global aliases allows rapid inspection in Lua code.

**Implementation:**
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

## 🟡 P3 — Expanded Picker & Power-User Mappings

### 4. Advanced Pickers, LSP References, and UI Toggles

**File:** [`.config/nvim/lua/plugins/init.lua`](file:///home/zliu/test/utils/.config/nvim/lua/plugins/init.lua#L73-L110)

The keymap suite is expanded to support full IDE feature parity:

- **Pickers (`<leader>s*` namespace):**
  - `<leader>sf` → `Snacks.picker.files()` (Find Files)
  - `<leader>sg` → `Snacks.picker.grep()` (Live Grep)
  - `<leader>sb` → `Snacks.picker.buffers()` (Open Buffers)
  - `<leader>sr` → `Snacks.picker.recent()` (Recent Files)
  - `<leader>sh` → `Snacks.picker.help()` (Help Tags)
  - `<leader>su` → `Snacks.picker.undo()` (Undo Tree)
  - `<leader>sG` → `Snacks.picker.git_status()` (Git Status)
  - `<leader>sn` → `Snacks.picker.notifications()` (Notification History)
  - `<leader>sp` → `Snacks.picker.pickers()` (Available Pickers)
  - `<leader>sl` → `Snacks.picker.lines()` (Buffer Lines)
  - `<leader>sw` → `Snacks.picker.grep_word()` (Grep Word under Cursor)
  - `<leader>sk` → `Snacks.picker.keymaps()` (Keymaps Finder)
  - `<leader>sc` → `Snacks.picker.command_history()` (Command History)
  - `<leader>sC` → `Snacks.picker.commands()` (Vim Commands)
  - `<leader>se` → `Snacks.picker.explorer()` (File Explorer)
  - `<leader>sd` → `Snacks.picker.diagnostics()` (Workspace Diagnostics)
  - `<leader>sD` → `Snacks.picker.diagnostics_buffer()` (Buffer Diagnostics)
  - `<leader>ss` → `Snacks.picker.lsp_symbols()` (LSP Document Symbols)
  - `<leader>sS` → `Snacks.picker.lsp_workspace_symbols()` (LSP Workspace Symbols)
  - `<leader>sq` → `Snacks.picker.qflist()` (Quickfix List)
  - `<leader>sm` → `Snacks.picker.marks()` (Marks)
  - `<leader>sj` → `Snacks.picker.jumps()` (Jumplist)

- **LSP Reference Navigation (`Snacks.words`):**
  - `]]` → Jump to next symbol reference.
  - `[[` → Jump to previous symbol reference.

- **Utilities & Git:**
  - `<leader>h` → `Snacks.dashboard()`
  - `<leader>z` / `<leader>Z` → Zen Mode & Zoom
  - `<leader>.` / `<leader>S` → Scratch Buffer / Select Scratch
  - `<leader>bd` → Delete Buffer safely (`Snacks.bufdelete`)
  - `<leader>cR` → LSP File Rename (`Snacks.rename.rename_file`)
  - `<leader>gB` → Git Browse (`Snacks.gitbrowse`)
  - `<leader>gb` → Git Blame Line (`Snacks.git.blame_line`)
  - `<leader>gL` → Git Log (`Snacks.picker.git_log`)
  - `<leader>lg` → Lazygit Floating Terminal (`Snacks.lazygit`)
  - `<c-/>` / `<c-_>` → Toggle Terminal

- **UI Toggles (`<leader>u*` namespace):**
  - `<leader>us` → Toggle Spell Check
  - `<leader>uw` → Toggle Line Wrap
  - `<leader>uL` → Toggle Line Numbers
  - `<leader>ud` → Toggle Diagnostics
  - `<leader>uC` → Toggle Conceal
  - `<leader>ui` → Toggle Indent Guides
  - `<leader>uD` → Toggle Focus Dimming
  - `<leader>ub` → Toggle Background (Dark/Light)

---

## 🔵 P4 — Multi-Picker Ecosystem Matrix

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
| **Diagnostics** | `<leader>sd` / `<leader>sD` | — | — | — |
| **LSP Symbols** | `<leader>ss` / `<leader>sS` | — | — | — |
| **Lazygit** | `<leader>lg` | — | — | — |

---

## Verification

 Verification was conducted by running Lua syntax validation and headless Neovim execution:

1. **Lua Syntax Validation**:
   ```bash
   luac -p .config/nvim/lua/plugins/init.lua .config/nvim/lua/config/keymaps.lua
   ```
   *Result:* Exit code `0` (Passed).

2. **Headless Neovim Initialization**:
   ```bash
   nvim --headless "+qa"
   ```
   *Result:* Clean initialization without Lua errors or missing module exceptions.
