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

-- Theme settings
vim.cmd("colorscheme gruvbox")
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
