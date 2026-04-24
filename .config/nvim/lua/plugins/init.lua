return {
  -- Core & UI
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
  "flazz/vim-colorschemes",
  "ellisonleao/gruvbox.nvim",
  "rafi/awesome-vim-colorschemes",
  "ryanoasis/vim-devicons",
  "nvim-tree/nvim-web-devicons",
  {
    "goolord/alpha-nvim",
    config = function() require("alpha").setup(require("alpha.themes.startify").config) end,
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          theme = "catppuccin",
          component_separators = { left = "|", right = "|" },
          section_separators = { left = "", right = "" },
        },
      })
    end,
  },

  -- Navigation (Telescope)
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("telescope").setup({
        defaults = {
          layout_strategy = "bottom_pane",
          layout_config = { bottom_pane = { height = 0.5, prompt_position = "bottom" } },
        },
      })
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>sf", builtin.find_files, {})
      vim.keymap.set("n", "<leader>sg", builtin.live_grep, {})
      vim.keymap.set("n", "<leader>sb", builtin.buffers, {})
      vim.keymap.set("n", "<leader>sh", builtin.help_tags, {})
    end,
  },

  -- Navigation (Fzf-lua)
  {
    "ibhagwan/fzf-lua",
    config = function()
      require("fzf-lua").setup({ keymap = { fzf = { ["ctrl-q"] = "select-all+accept" } } })
      vim.keymap.set("n", "<leader>pf", ":FzfLua files<CR>", { silent = true })
      vim.keymap.set("n", "<leader>pg", ":FzfLua live_grep<CR>", { silent = true })
      vim.keymap.set("n", "<leader>pb", ":FzfLua buffers<CR>", { silent = true })
    end,
  },

  -- Navigation (Classic Tools)
  "scrooloose/nerdtree",
  {
    "tiagofumo/vim-nerdtree-syntax-highlight",
    dependencies = { "scrooloose/nerdtree" },
  },
  "jlanzarotta/bufexplorer",
  "yegappan/mru",
  {
    "vim-scripts/lookupfile",
    dependencies = { "vim-scripts/genutils" },
  },
  "junegunn/fzf",
  {
    "junegunn/fzf.vim",
    dependencies = { "junegunn/fzf" },
  },
  "jremmen/vim-ripgrep",
  "mhinz/vim-grepper",
  "mileszs/ack.vim",
  "vim-scripts/Color-Scheme-Explorer",

  -- Tree
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        view = { width = 30, preserve_window_proportions = true },
        actions = { open_file = { resize_window = false } },
      })
      vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<cr>")
      vim.keymap.set("n", "<leader>n", ":NvimTreeFindFile<cr>")
    end,
  },

  -- Coding
  {
    "dhananjaylatkar/cscope_maps.nvim",
    config = function() require("cscope_maps").setup({ prefix = "<C-\\>", skip_input_prompt = true }) end,
  },
  "tpope/vim-surround",
  "tpope/vim-commentary",
  "tpope/vim-unimpaired",
  "tpope/vim-fugitive",
  "jiangmiao/auto-pairs",
  "godlygeek/tabular",
  "christoomey/vim-tmux-navigator",
  "tmhedberg/SimpylFold",
  "majutsushi/tagbar",
  "vimwiki/vimwiki",
  "psf/black",
  "Exafunction/windsurf.vim",
  "preservim/nerdcommenter",
  "vim-scripts/a.vim",
  "rbgrouleff/bclose.vim",

  -- Terminal Utilities (Conditional)
  {
    "francoiscabrol/ranger.vim",
    dependencies = { "rbgrouleff/bclose.vim" },
    enabled = function() return vim.fn.has("win32") == 0 and vim.fn.has("gui_running") == 0 end,
  },
  {
    "ptzz/lf.vim",
    enabled = function() return vim.fn.has("gui_running") == 0 end,
  },
  {
    "voldikss/vim-floaterm",
    enabled = function() return vim.fn.has("gui_running") == 0 end,
  },
  {
    "vifm/vifm.vim",
    enabled = function() return vim.fn.has("gui_running") == 0 end,
  },
}
