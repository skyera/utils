# FZF Lua Keys & Configuration Review

## Overview

A comprehensive review of FZF and `fzf-lua` keybindings, configurations, and fuzzy-finder integration across the codebase (including `.config/nvim/lua/plugins/init.lua`, `.config/nvim/lua/config/keymaps.lua`, `.config/nvim/lua/config/options.lua`, and `myvimrc`).

Overall, the setup is functional, but exhibits fuzzy-finder fragmentation (coexistence of `fzf.vim`, `fzf-lua`, and `telescope.nvim`), un-idiomatic string command invocations in Lua keymaps, missing keybindings, and option leakage between `fzf.vim` and `fzf-lua`.

Below are all identified issues, ranked by priority.

---

## 🔴 P1 — Critical Issues & Redundancies (Bugs / Tech Debt)

### 1. Dual/Triple Fuzzy Finder Redundancy

**Files:** `.config/nvim/lua/plugins/init.lua`, `keymaps.lua`

**Issue:** Three separate fuzzy finders are concurrently installed and mapped to different leader prefixes:
- `fzf-lua` (`ibhagwan/fzf-lua`): mapped to `<leader>p*` (`<leader>pf`, `<leader>pg`, `<leader>pb`)
- `fzf.vim` (`junegunn/fzf.vim`): mapped to `<leader>*` (`<leader>f`, `<leader>g`, `<leader>b`, `<leader>t`, `<leader>l`, etc.)
- `telescope.nvim` (`nvim-telescope/telescope.nvim`): mapped to `<leader>s*` (`<leader>sf`, `<leader>sg`, `<leader>sb`, `<leader>sh`)

Having three different fuzzy finder plugins installed simultaneously creates UI inconsistency (different floating windows, keybindings, and previewers), wastes memory/startup time, and leads to keymap confusion.

**Fix:** Standardize on **`fzf-lua`** as the primary fuzzy finder for Neovim (it offers C-level fzf performance, native Neovim floating UI, and low overhead) and unify keybindings under a consistent prefix scheme (e.g. `<leader>f*` or `<leader>p*`).

---

### 2. Un-idiomatic String Command Invocations in Lua Keymaps

**File:** `.config/nvim/lua/plugins/init.lua`

**Issue:** Previously, `fzf-lua` keymaps were defined using command strings:
```lua
vim.keymap.set("n", "<leader>pf", ":FzfLua files<CR>", { silent = true })
```
Using Vim command strings in Lua keybindings:
1. Adds unnecessary parsing overhead through Neovim's command-line parser.
2. Contaminates the Vim command history (`:` history).
3. Prevents passing Lua options directly (such as custom cwd, previewer toggles, or filter options).

**Fix:** Use native Lua function references directly:
```lua
local fzf = require("fzf-lua")
vim.keymap.set("n", "<leader>pf", fzf.files, { silent = true, desc = "FZF Lua Files" })
```

---

## 🟠 P2 — Key Collisions & Deficiencies

### 3. Missing Essential `fzf-lua` Mappings

**File:** `.config/nvim/lua/plugins/init.lua`

**Issue:** `fzf-lua` previously only mapped 3 basic commands (`files`, `live_grep`, `buffers`). Useful built-in finders were absent:
- `help_tags` (Vim documentation search)
- `grep_cword` (Search word under cursor)
- `oldfiles` (Recent files / MRU)
- `lines` / `blines` (Search buffer lines)
- `colorschemes` (Interactive colorscheme switcher)
- `tags` / `btags` / LSP symbol finders

**Fix:** Expand `fzf-lua` mappings to cover full project workflow needs (`<leader>ph` for help, `<leader>pw` for word under cursor, `<leader>pr` for recent files, `<leader>pl` for buffer lines, `<leader>pc` for colorschemes).

---

### 4. `fzf.vim` Vim Global Variables Leakage into Neovim Lua Options

**File:** `.config/nvim/lua/config/options.lua`

**Issue:**
```lua
vim.g.fzf_command_prefix = "Fzf"
vim.g.fzf_layout = { down = "40%" }
vim.env.FZF_DEFAULT_OPTS = (vim.env.FZF_DEFAULT_OPTS or "") .. ' --bind "ctrl-a:select-all,ctrl-d:deselect-all"'
```
`vim.g.fzf_command_prefix` and `vim.g.fzf_layout` are specific to **`fzf.vim`** (Vimscript plugin), **not** `fzf-lua`. `fzf-lua` ignores these variables completely and uses its own `winopts` and `setup({})` dictionary in Lua.

**Fix:** Clearly document which options target `fzf.vim` vs `fzf-lua` in `options.lua`, and configure `fzf-lua` window layout inside `require("fzf-lua").setup({ winopts = { ... } })`.

---

### 5. Scattered Keymap Definitions Across Multiple Files

**Files:** `.config/nvim/lua/plugins/init.lua` vs `.config/nvim/lua/config/keymaps.lua`

**Issue:** Fuzzy finder keymaps are split across files:
- `fzf-lua` & `telescope` keymaps inside `plugins/init.lua`
- `fzf.vim` keymaps inside `config/keymaps.lua`

This split makes auditing keymaps and detecting collisions difficult.

**Fix:** Consolidate keymaps or keep plugin-specific mappings neatly documented with `desc` labels.

---

## 🟡 P3 — Suboptimal Configs & UX

### 6. Missing Keymap `desc` Metadata

**Files:** `.config/nvim/lua/plugins/init.lua`, `config/keymaps.lua`

**Issue:** Keymaps were created without `desc` parameters. In modern Neovim:
- Keymaps without `desc` show cryptic command strings in Which-Key or `:map`.
- Neovim 0.10+ native keymap inspector benefits from clean descriptions.

**Fix:** Add `desc = "..."` attributes to all `vim.keymap.set` declarations.

---

### 7. Missing Icon Dependencies for `fzf-lua`

**File:** `.config/nvim/lua/plugins/init.lua`

**Issue:** `fzf-lua` supports `nvim-web-devicons` for rendering filetype icons in the picker window, but `nvim-web-devicons` was not listed as an explicit dependency for `fzf-lua` in lazy.nvim plugin specs.

**Fix:** Add `dependencies = { "nvim-tree/nvim-web-devicons" }` to the `fzf-lua` spec in `plugins/init.lua`.

---

## 🔵 P4 — Modernization & Recommended Strategy

### Summary of Keymap Mapping Matrix

| Feature | `fzf-lua` Keymap | `fzf.vim` Keymap | `telescope` Keymap |
| :--- | :--- | :--- | :--- |
| **Find Files** | `<leader>pf` | `<leader>f` | `<leader>sf` |
| **Live Grep** | `<leader>pg` | `<leader>g` | `<leader>sg` |
| **Buffers** | `<leader>pb` | `<leader>b` | `<leader>sb` |
| **Help Tags** | `<leader>ph` | — | `<leader>sh` |
| **Grep Cursor Word** | `<leader>pw` | `<leader>F4` (vimgrep) | — |
| **Recent Files** | `<leader>pr` | — | — |
| **Buffer Lines** | `<leader>pl` | `<leader>l` / `<leader>lb` | — |
| **Colorschemes** | `<leader>pc` | — | `<leader>sc` |

### Recommended Action Plan

1. **Applied Best Practice (`<leader>f*` Scheme)**:
   - Configured `fzf-lua` in [`.config/nvim/lua/plugins/init.lua`](file:///home/zliu/test/utils/.config/nvim/lua/plugins/init.lua#L55-L75) to use the standard `<leader>f*` Find prefix (`<leader>ff`, `<leader>fg`, `<leader>fb`, `<leader>fh`, `<leader>fw`, `<leader>fr`, `<leader>fl`, `<leader>fc`).
   - Retained legacy `<leader>p*` (`<leader>pf`, `<leader>pg`, `<leader>pb`) as aliases.
   - Commented out single-letter `<leader>f`, `<leader>g`, `<leader>b` in [`.config/nvim/lua/config/keymaps.lua`](file:///home/zliu/test/utils/.config/nvim/lua/config/keymaps.lua#L27-L35) to eliminate keymap timeout delays (`timeoutlen`).

2. **Long Term (Recommended)**:
   - Complete the transition away from `fzf.vim` and `telescope` to standardize 100% of fuzzy search workflows on `fzf-lua`.
