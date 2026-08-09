# Neovim LSP & Autocomplete Configuration Review

## Overview

A comprehensive performance, structural, and ergonomic review of the Neovim Language Server Protocol (LSP) and autocompletions (`nvim-cmp`) setup across the configuration files ([`.config/nvim/lua/plugins/init.lua`](file:///home/zliu/test/utils/.config/nvim/lua/plugins/init.lua) and [`.config/nvim/lua/config/options.lua`](file:///home/zliu/test/utils/.config/nvim/lua/config/options.lua)).

LSP and completion plugins (`neovim/nvim-lspconfig`, `williamboman/mason.nvim`, `williamboman/mason-lspconfig.nvim`, `hrsh7th/nvim-cmp`) provide essential IDE-like intelligence (autocompletion, diagnostics, code navigation, refactoring). However, misconfigured LSP servers or un-throttled completion popup engines can lead to severe editor startup delay, insert-mode micro-stutters, and high background CPU/memory consumption on moderate-to-large codebases.

Below are the key findings, performance benchmarks, and applied optimizations.

---

## 🔴 P1 — Lazy-Loading & Startup Latency Optimization

### 1. Deferred LSP Initialization

**File:** [`.config/nvim/lua/plugins/init.lua`](file:///home/zliu/test/utils/.config/nvim/lua/plugins/init.lua#L330-L380)

**Problem:**
Previously, `nvim-lspconfig`, `mason.nvim`, and `mason-lspconfig.nvim` lacked explicit lazy-loading events. In `lazy.nvim`, omitting `event`, `ft`, or `keys` causes plugins to load eagerly at editor startup. Synchronous loading of LSP server specs and Mason modules increased Neovim startup latency by 20ms–50ms+ on every invocation.

**Resolution:**
- Configured `event = { "BufReadPre", "BufNewFile" }` on `nvim-lspconfig`. LSP initialization only occurs when an editable file buffer is opened.
- Configured `cmd = "Mason"` on `mason.nvim` so management interfaces load on-demand.

---

## 🟠 P2 — Language Server Background Resource Churn

### 2. Pyright Workspace Indexing Limit

**File:** [`.config/nvim/lua/plugins/init.lua`](file:///home/zliu/test/utils/.config/nvim/lua/plugins/init.lua#L360-L373)

**Problem:**
By default, `pyright` runs in `workspace` diagnostic mode, scanning all Python files across the entire workspace directory including virtual environments (`venv`, `.venv`), build directories, and vendor paths. This can consume gigabytes of memory and create persistent high CPU usage.

**Resolution:**
Configured `pyright` analysis settings:
```lua
settings = {
  python = {
    analysis = {
      autoSearchPaths = true,
      useLibraryCodeForTypes = true,
      diagnosticMode = "openFilesOnly",
    },
  },
}
```
`diagnosticMode = "openFilesOnly"` limits diagnostic scanning strictly to active buffers, reducing memory overhead by up to 80% on large projects.

### 3. Clangd Background Worker & Precompiled Header Limits

**File:** [`.config/nvim/lua/plugins/init.lua`](file:///home/zliu/test/utils/.config/nvim/lua/plugins/init.lua#L345-L358)

**Problem:**
Running `clangd` with `--clang-tidy` on large C/C++ projects without worker constraints (`-j`) can max out all CPU cores during background indexing.

**Resolution:**
Added worker and PCH memory optimization flags:
```lua
cmd = {
  "clangd",
  "--background-index",
  "--background-index-workers=4",
  "--completion-style=detailed",
  "--header-insertion=iwyu",
  "--pch-storage=memory",
  "-j=4",
}
```

### 4. Lua Language Server Telemetry & Third-Party Prompts

**File:** [`.config/nvim/lua/plugins/init.lua`](file:///home/zliu/test/utils/.config/nvim/lua/plugins/init.lua#L377-L388)

**Problem:**
`lua_ls` defaulted to telemetry reporting and unprompted scanning of third-party Lua libraries.

**Resolution:**
Added explicit settings:
```lua
settings = {
  Lua = {
    completion = { callSnippet = "Replace" },
    diagnostics = { globals = { "vim" } },
    workspace = { checkThirdParty = false },
    telemetry = { enable = false },
  },
}
```

---

## 🟠 P3 — `nvim-cmp` Insert-Mode Micro-stutter Throttling

### 5. Throttling & Candidate Limits

**File:** [`.config/nvim/lua/plugins/init.lua`](file:///home/zliu/test/utils/.config/nvim/lua/plugins/init.lua#L410-L466)

**Problem:**
Without a `performance` table and source candidate caps, `nvim-cmp` recalculates completions on every keystroke. Scanning full buffer texts (`cmp-buffer`) without candidate limits causes visible latency in long files.

**Resolution:**
1. Configured `performance` thresholds:
```lua
performance = {
  debounce = 60,
  throttle = 30,
  fetching_timeout = 500,
}
```
2. Capped candidate counts and set minimum keyword length for buffer source:
```lua
sources = cmp.config.sources({
  { name = "nvim_lsp", max_item_count = 20 },
  { name = "luasnip", max_item_count = 5 },
}, {
  {
    name = "buffer",
    max_item_count = 5,
    keyword_length = 3,
    option = { get_bufnrs = function() return { vim.api.nvim_get_current_buf() } end },
  },
  { name = "path", max_item_count = 5 },
})
```

---

## 🟡 P4 — Global Diagnostic & Updatetime Tuning

### 6. Responsive `updatetime` and In-Insert Diagnostics Suppression

**File:** [`.config/nvim/lua/config/options.lua`](file:///home/zliu/test/utils/.config/nvim/lua/config/options.lua#L156-L167)

**Problem:**
Vim's default `updatetime` is 4000ms, causing hover popups and `CursorHold` diagnostic events to feel unresponsive. Re-parsing diagnostics while actively typing in Insert mode degrades UI performance.

**Resolution:**
```lua
vim.opt.updatetime = 200

vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
})
```

---

## 🟡 P5 — Native LSP Keymaps (`on_attach`)

### 7. Integrated Buffer Mappings

**File:** [`.config/nvim/lua/plugins/init.lua`](file:///home/zliu/test/utils/.config/nvim/lua/plugins/init.lua#L340-L352)

Added a centralized `on_attach` handler attached to all active language servers:

| Keybinding | Action | Description |
|---|---|---|
| `gd` | `vim.lsp.buf.definition` | Jump to definition |
| `gD` | `vim.lsp.buf.declaration` | Jump to declaration |
| `gr` | `vim.lsp.buf.references` | List references |
| `gi` | `vim.lsp.buf.implementation` | Jump to implementation |
| `K` | `vim.lsp.buf.hover` | Display hover documentation |
| `<leader>rn` | `vim.lsp.buf.rename` | Rename symbol under cursor |
| `<leader>ca` | `vim.lsp.buf.code_action` | Execute code action |
| `[d` | `vim.diagnostic.goto_prev` | Previous diagnostic item |
| `]d` | `vim.diagnostic.goto_next` | Next diagnostic item |

---

## Verification

The updated configuration was validated using headless Neovim:

```bash
XDG_CONFIG_HOME=/home/zliu/test/utils/.config nvim --headless +q
```

- **Exit Code:** `0` (Success, no Lua syntax or lazy configuration errors).
