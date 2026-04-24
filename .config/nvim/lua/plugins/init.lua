return {
  -- Core
  "flazz/vim-colorschemes",
  "ellisonleao/gruvbox.nvim", -- Modern Gruvbox for Neovim
  
  -- Navigation
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("telescope").setup({
        defaults = {
          layout_strategy = "bottom_pane",
          layout_config = {
            bottom_pane = {
              height = 0.5,
              prompt_position = "bottom",
            },
          },
        },
      })
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>sf", builtin.find_files, {})
      vim.keymap.set("n", "<leader>sg", builtin.live_grep, {})
      vim.keymap.set("n", "<leader>sb", builtin.buffers, {})
      vim.keymap.set("n", "<leader>sh", builtin.help_tags, {})
    end,
  },
  
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        view = {
          width = 30,
          preserve_window_proportions = true,
        },
        actions = {
          open_file = {
            resize_window = false,
          },
        },
      })
      vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<cr>")
      vim.keymap.set("n", "<leader>n", ":NvimTreeFindFile<cr>")
    end,
  },
  
  {
    "ibhagwan/fzf-lua",
    config = function()
      require("fzf-lua").setup({
        keymap = {
          fzf = {
            ["ctrl-q"] = "select-all+accept",
          },
        },
      })
      vim.keymap.set("n", "<leader>pf", ":FzfLua files<CR>", { silent = true })
      vim.keymap.set("n", "<leader>pg", ":FzfLua live_grep<CR>", { silent = true })
      vim.keymap.set("n", "<leader>pb", ":FzfLua buffers<CR>", { silent = true })
    end,
  },

  -- UI
  {
    "goolord/alpha-nvim",
    config = function()
      require("alpha").setup(require("alpha.themes.startify").config)
    end,
  },
  
  -- Coding
  {
    "dhananjaylatkar/cscope_maps.nvim",
    config = function()
      require("cscope_maps").setup({
        prefix = "<C-\\>",
        skip_input_prompt = true,
      })
    end,
  },
  "tpope/vim-surround",
  "tpope/vim-commentary",
  "tpope/vim-unimpaired",
  "tpope/vim-fugitive",
  "jiangmiao/auto-pairs",
  "godlygeek/tabular",
  "dense-analysis/ale",
  "christoomey/vim-tmux-navigator",
  
  -- Misc
  "majutsushi/tagbar",
  "vimwiki/vimwiki",
  "itchyny/lightline.vim",
}
