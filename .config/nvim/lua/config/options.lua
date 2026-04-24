-- General settings (translated from myvimrc)
vim.opt.backspace = { "indent", "eol", "start" }
vim.opt.history = 10000
vim.opt.ruler = true
vim.opt.showcmd = true
vim.opt.incsearch = true
vim.opt.hlsearch = true
vim.opt.mouse = "a"
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.number = true
vim.opt.autoindent = true
vim.opt.copyindent = true
vim.opt.backup = false
vim.opt.swapfile = false
vim.opt.showmode = true
vim.opt.completeopt = { "menu" }
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.cursorline = true
vim.opt.shiftround = true
vim.opt.encoding = "utf-8"
vim.opt.colorcolumn = "80"
vim.opt.termguicolors = true
vim.opt.laststatus = 2
vim.opt.wrapscan = true
vim.opt.cindent = true
vim.opt.cinoptions = "g-1"
vim.opt.directory:prepend(vim.fn.expand("$HOME") .. "/.vim/tmp//")

-- Clipboard logic
if vim.fn.has("clipboard") == 1 then
  if vim.fn.has("unnamedplus") == 1 then
    vim.opt.clipboard = "unnamedplus"
  else
    vim.opt.clipboard = "unnamed"
  end
end

-- Font settings
if vim.fn.has("win32") == 1 then
  vim.opt.guifont = "Hack Nerd Font Mono:h12"
elseif vim.fn.has("linux") == 1 then
  vim.opt.guifont = "Hack Nerd Font:h10"
elseif vim.fn.has("mac") == 1 then
  vim.opt.guifont = "Hack Nerd Font:h11"
end

-- Plugin Globals
vim.g.winManagerWindowLayout = 'FileExplorer|TagList'
vim.g.Tlist_Show_One_File = 1
vim.g.LookupFile_MinPatLength = 3
vim.g.LookupFile_PreserveLastPattern = 0
vim.g.LookupFile_PreservePatternHistory = 1
vim.g.LookupFile_AlwaysAcceptFirst = 1
vim.g.LookupFile_AllowNewFiles = 0
vim.g.LookupFile_smartcase = 1
vim.g.LookupFile_EscCancelsPopup = 1
vim.g.LookupFile_ignorecase = 1
vim.g.LookupFile_EnableRemapCmd = 0
vim.g.LookupFile_TagExpr = '"filenametags"'

-- ALE Globals
vim.g.ale_fixers = { python = { 'black', 'isort', 'remove_trailing_lines', 'trim_whitespace' } }
vim.g.ale_cpp_cpplint_options = '--filter=-whitespace/braces,-legal/copyright,-whitespace/indent'
vim.g.ale_c_cpplint_options = '--filter=-whitespace/braces,-legal/copyright'
vim.g.ale_echo_msg_format = '[%linter%] %code: %%s [%severity%]'
vim.g.ale_lint_on_text_changed = 'never'
vim.g.ale_lint_on_insert_leave = 0
vim.g.ale_lint_on_enter = 0
vim.g.ale_fix_on_save = 0
vim.g.ale_lint_on_save = 0
vim.g.ale_virtualtext_cursor = 'current'

-- Tagbar TypeScript
vim.g.tagbar_type_typescript = {
  ctagstype = 'typescript',
  kinds = { 'c:classes', 'n:modules', 'f:functions', 'v:variables', 'v:varlambdas', 'm:members', 'i:interfaces', 'e:enums' }
}

-- FZF Configuration
vim.g.fzf_command_prefix = "Fzf"
vim.g.fzf_layout = { down = "40%" }
vim.env.FZF_DEFAULT_OPTS = (vim.env.FZF_DEFAULT_OPTS or "") .. ' --bind "ctrl-a:select-all,ctrl-d:deselect-all"'

-- Custom Frg command
vim.cmd([[
  command! -bang -nargs=* Frg call fzf#vim#grep("rg --column --line-number --no-heading --color=always --smart-case ".<q-args>, 1, fzf#vim#with_preview(), <bang>0)
]])

-- Theme settings
pcall(vim.cmd, "colorscheme gruvbox")
vim.opt.background = "dark"

-- Auto-restore cursor position
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- FileType specific settings
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "javascript", "html", "sh", "bash" },
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.opt_local.foldmethod = "indent"
  end,
})

-- Vimwiki Tab fix
vim.api.nvim_create_autocmd("FileType", {
  pattern = "vimwiki",
  callback = function()
    vim.keymap.set("i", "<Tab>", "<Tab>", { buffer = true })
  end,
})
