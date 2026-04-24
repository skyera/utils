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
vim.keymap.set("n", "<F2>", "<Esc>:1,$!xmllint --format -<CR>")
vim.keymap.set("n", "<F12>", "<Esc>:syntax sync fromstart<CR>")
vim.keymap.set("n", "<space>", "za")
vim.keymap.set("v", "<space>", "zf")
vim.keymap.set("n", "cp", ':let @* = expand("%:p") <cr>')

-- Tmux Navigator
vim.keymap.set("n", "<M-h>", ":TmuxNavigateLeft<cr>", { silent = true })
vim.keymap.set("n", "<M-j>", ":TmuxNavigateDown<cr>", { silent = true })
vim.keymap.set("n", "<M-k>", ":TmuxNavigateUp<cr>", { silent = true })
vim.keymap.set("n", "<M-l>", ":TmuxNavigateRight<cr>", { silent = true })

-- Original FZF Mappings
vim.keymap.set("n", "<leader>f", ":FzfFiles<CR>", { silent = true })
vim.keymap.set("n", "<leader>g", ":FzfRg<CR>", { silent = true })
vim.keymap.set("n", "<leader>b", ":FzfBuffers<CR>", { silent = true })
vim.keymap.set("n", "<leader>t", ":FzfTags<CR>", { silent = true })
vim.keymap.set("n", "<leader>l", ":FzfLines<CR>", { silent = true })
vim.keymap.set("n", "<leader>lb", ":FzfBLines<CR>", { silent = true })
vim.keymap.set("n", "<leader>tb", ":FzfBTags<CR>", { silent = true })

-- NERDTree Mappings
vim.keymap.set("n", "<leader>nn", ":NERDTreeToggle<cr>")
vim.keymap.set("n", "<leader>nb", ":NERDTreeFromBookmark ")
vim.keymap.set("n", "<leader>nf", ":NERDTreeFind<cr>")

-- AI Plugin Mappings (Codeium style)
vim.keymap.set("i", "<C-;>", "<Cmd>call codeium#CycleCompletions(1)<CR>")
vim.keymap.set("i", "<C-,>", "<Cmd>call codeium#CycleCompletions(-1)<CR>")
vim.keymap.set("i", "<C-x>", "<Cmd>call codeium#Clear()<CR>")

-- Terminal Tool Mappings (Only if not GUI)
if vim.fn.has("gui_running") == 0 then
  vim.keymap.set("n", "<leader>r", ":Ranger<CR>", { silent = true })
  vim.keymap.set("n", "<leader>lf", ":Lf<CR>", { silent = true })
end

vim.keymap.set("n", "<leader>sc", ":Telescope colorscheme<CR>", { silent = true })

-- Functions
vim.cmd([[
function! s:align()
  let p = '^\s*|\s.*\s|\s*$'
  if exists(':Tabularize') && getline('.') =~# '^\s*|' && (getline(line('.')-1) =~# p || getline(line('.')+1) =~# p)
    let column = strlen(substitute(getline('.')[0:col('.')],'[^|]','','g'))
    let position = strlen(matchstr(getline('.')[0:col('.')],'.*|\s*\zs.*'))
    Tabularize/\\\@<!|/l1
    normal! 0
    call search(repeat('[^|]*|',column).'\s\{-\}'.repeat('.',position),'ce',line('.'))
  endif
endfunction
]])

-- Alignment helper keymap
vim.keymap.set("i", "|", "|<Esc>:call <SID>align()<CR>a")
