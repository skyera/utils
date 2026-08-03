return {
  -- Core & UI
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
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
          theme = "catppuccin-mocha",
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
          layout_strategy = "vertical",
          layout_config = {
            vertical = {
              prompt_position = "top",
              mirror = true,
              preview_height = 0.50, -- 50% height reserved for preview
              preview_cutoff = 0,    -- Always scale by percent without hiding
            },
            width = 0.90,  -- 90% of editor width
            height = 0.90, -- 90% of editor height
          },
        },
      })
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>sf", builtin.find_files, { desc = "Search Files (Telescope)" })
      vim.keymap.set("n", "<leader>sg", builtin.live_grep, { desc = "Search Live Grep (Telescope)" })
      vim.keymap.set("n", "<leader>sb", builtin.buffers, { desc = "Search Buffers (Telescope)" })
      vim.keymap.set("n", "<leader>sh", builtin.help_tags, { desc = "Search Help Tags (Telescope)" })
      vim.keymap.set("n", "<leader>sw", builtin.grep_string, { desc = "Search Word under cursor (Telescope)" })
      vim.keymap.set("n", "<leader>sr", builtin.oldfiles, { desc = "Search Recent Files (Telescope)" })
      vim.keymap.set("n", "<leader>sc", builtin.colorscheme, { desc = "Search Colorschemes (Telescope)" })
      vim.keymap.set("n", "<leader>sk", builtin.keymaps, { desc = "Search Keymaps (Telescope)" })
    end,
  },

  -- Navigation (Fzf-lua)
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local fzf = require("fzf-lua")
      fzf.setup({
        winopts = {
          height = 0.90, -- 90% of editor height
          width = 0.90,  -- 90% of editor width
          preview = {
            layout = "vertical",
            vertical = "down:50%", -- 50% bottom preview window
          },
        },
        fzf_opts = {
          ["--layout"] = "reverse",
        },
        keymap = {
          fzf = {
            ["ctrl-q"] = "select-all+accept",
          },
        },
      })
      -- Recommended Best Practice <leader>f* Mappings (Find Prefix)
      vim.keymap.set("n", "<leader>ff", fzf.files, { silent = true, desc = "Find Files" })
      vim.keymap.set("n", "<leader>fg", fzf.live_grep, { silent = true, desc = "Find Live Grep" })
      vim.keymap.set("n", "<leader>fb", fzf.buffers, { silent = true, desc = "Find Buffers" })
      vim.keymap.set("n", "<leader>fh", fzf.help_tags, { silent = true, desc = "Find Help Tags" })
      vim.keymap.set("n", "<leader>fw", fzf.grep_cword, { silent = true, desc = "Find Word under cursor" })
      vim.keymap.set("n", "<leader>fr", fzf.oldfiles, { silent = true, desc = "Find Recent Files (MRU)" })
      vim.keymap.set("n", "<leader>fl", fzf.lines, { silent = true, desc = "Find Buffer Lines" })
      vim.keymap.set("n", "<leader>fc", fzf.colorschemes, { silent = true, desc = "Find Colorschemes" })

      -- Legacy <leader>p* Aliases (Project Prefix)
      vim.keymap.set("n", "<leader>pf", fzf.files, { silent = true, desc = "FZF Files" })
      vim.keymap.set("n", "<leader>pg", fzf.live_grep, { silent = true, desc = "FZF Live Grep" })
      vim.keymap.set("n", "<leader>pb", fzf.buffers, { silent = true, desc = "FZF Buffers" })
    end,
  },

  -- File Explorer (Oil)
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("oil").setup({
        columns = { "icon" },
        view_options = { show_hidden = true },
      })
      vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
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
      vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<cr>", { desc = "Toggle NvimTree" })
      vim.keymap.set("n", "<leader>E", ":NvimTreeFindFile<cr>", { desc = "Find file in NvimTree" })
    end,
  },

  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    enabled = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").setup({
        ensure_installed = { "c", "lua", "vim", "vimdoc", "query", "python", "javascript", "typescript", "html", "css" },
        sync_install = false,
        auto_install = true,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        indent = { enable = true },
      })
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
    init = function() vim.g.ranger_map_keys = 0 end,
    enabled = function() return vim.fn.has("win32") == 0 and vim.fn.has("gui_running") == 0 end,
  },
  {
    "ptzz/lf.vim",
    init = function() vim.g.lf_map_keys = 0 end,
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
