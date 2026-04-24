-- Keymaps (translated from myvimrc)
vim.g.mapleader = "\\" -- Set backslash as leader

-- General mappings
vim.keymap.set("n", "<leader>ll", ":LUBufs<cr>", { silent = true })
vim.keymap.set("n", "<F6>", ":cn<cr>")
vim.keymap.set("n", "<F7>", ":cp<cr>")
vim.keymap.set("n", "<F8>", ":bn<cr>")
vim.keymap.set("n", "<F9>", ":bp<cr>")
vim.keymap.set("n", "<F10>", ":tn<cr>")
vim.keymap.set("n", "<C-F10>", ":tp<cr>")
vim.keymap.set("n", "<F4>", ':execute "vimgrep /" . expand("<cword>") . "/j **" <Bar> cw<CR>')
vim.keymap.set("n", "<F11>", ":silent !start explorer /select,%:p<CR>")
vim.keymap.set("n", "<C-F2>", ":browse edit<cr>")
vim.keymap.set("n", "<leader>tfix", ":call ToggleALEFixOnSave()<CR>")
vim.keymap.set("n", "<space>", "za")
vim.keymap.set("v", "<space>", "zf")
vim.keymap.set("n", "cp", ':let @* = expand("%:p") <cr>')

-- Tmux Navigator
vim.keymap.set("n", "<M-h>", ":TmuxNavigateLeft<cr>", { silent = true })
vim.keymap.set("n", "<M-j>", ":TmuxNavigateDown<cr>", { silent = true })
vim.keymap.set("n", "<M-k>", ":TmuxNavigateUp<cr>", { silent = true })
vim.keymap.set("n", "<M-l>", ":TmuxNavigateRight<cr>", { silent = true })

-- Original FZF Mappings (to coexist with Telescope)
vim.keymap.set("n", "<leader>f", ":FzfFiles<CR>", { silent = true })
vim.keymap.set("n", "<leader>g", ":FzfRg<CR>", { silent = true })
vim.keymap.set("n", "<leader>b", ":FzfBuffers<CR>", { silent = true })
vim.keymap.set("n", "<leader>t", ":FzfTags<CR>", { silent = true })
vim.keymap.set("n", "<leader>l", ":FzfLines<CR>", { silent = true })

-- ALE Mappings
vim.keymap.set("n", "<C-k>", "<Plug>(ale_previous_wrap)", { silent = true })
vim.keymap.set("n", "<C-j>", "<Plug>(ale_next_wrap)", { silent = true })
vim.keymap.set("n", "<leader>al", ":ALELint<CR>", { silent = true })

-- NERDTree Mappings
vim.keymap.set("n", "<leader>nn", ":NERDTreeToggle<cr>")
vim.keymap.set("n", "<leader>nb", ":NERDTreeFromBookmark ")
vim.keymap.set("n", "<leader>nf", ":NERDTreeFind<cr>")

-- AI Plugin Mappings (Codeium style)
vim.keymap.set("i", "<C-;>", "<Cmd>call codeium#CycleCompletions(1)<CR>")
vim.keymap.set("i", "<C-,>", "<Cmd>call codeium#CycleCompletions(-1)<CR>")
vim.keymap.set("i", "<C-x>", "<Cmd>call codeium#Clear()<CR>")

-- Alignment helper
vim.keymap.set("i", "|", function()
  local line = vim.api.nvim_get_current_line()
  vim.api.nvim_put({"|"}, "c", true, true)
  if vim.fn.exists(":Tabularize") == 1 and line:match("^%s*|") then
      vim.cmd("Tabularize/\\\\@<!|/l1")
  end
end)
