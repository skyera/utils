return {
  -- Core & UI
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
  "ellisonleao/gruvbox.nvim",
  "rafi/awesome-vim-colorschemes",
  "ryanoasis/vim-devicons",
  "nvim-tree/nvim-web-devicons",
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      bigfile = { enabled = true },
      bufdelete = { enabled = true },
      dashboard = {
        enabled = true,
        preset = {
          keys = {
            { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.picker.files()" },
            { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
            { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.picker.grep()" },
            { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.picker.recent()" },
            { icon = " ", key = "c", desc = "Neovim Config", action = ":lua Snacks.picker.files({ cwd = vim.fn.stdpath('config') })" },
            { icon = "󰒲 ", key = "l", desc = "Lazy Plugins", action = ":Lazy" },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          { pane = 2, icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
          { pane = 2, icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
          {
            pane = 2,
            icon = " ",
            title = "Git Status",
            section = "terminal",
            enabled = function() return Snacks.git.get_root() ~= nil end,
            cmd = "git status --short --branch",
            height = 5,
            padding = 1,
            ttl = 5 * 60,
            indent = 3,
          },
          { section = "startup" },
        },
      },
      explorer = { enabled = true },
      git = { enabled = true },
      indent = { enabled = true, only_scope = true },
      input = { enabled = true },
      lazygit = { enabled = true },
      notifier = { enabled = true, timeout = 3000 },
      picker = { enabled = true },
      quickfile = { enabled = true },
      scratch = { enabled = true },
      statuscolumn = { enabled = true },
      terminal = { enabled = true },
      words = { enabled = true },
      zen = { enabled = true },
    },
    init = function()
      vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        callback = function()
          -- Expose Snacks debug helpers globally
          _G.dd = function(...) Snacks.debug.inspect(...) end
          _G.bt = function() Snacks.debug.backtrace() end
          vim.print = _G.dd
        end,
      })
    end,
    keys = {
      -- Snacks Picker Mappings (<leader>s* namespace)
      { "<leader>sf", function() Snacks.picker.files() end, desc = "Find Files (Snacks)" },
      { "<leader>sg", function() Snacks.picker.grep() end, desc = "Live Grep (Snacks)" },
      { "<leader>sb", function() Snacks.picker.buffers() end, desc = "Buffers (Snacks)" },
      { "<leader>sr", function() Snacks.picker.recent() end, desc = "Recent Files (Snacks)" },
      { "<leader>sh", function() Snacks.picker.help() end, desc = "Help Tags (Snacks)" },
      { "<leader>su", function() Snacks.picker.undo() end, desc = "Undo Tree (Snacks)" },
      { "<leader>sG", function() Snacks.picker.git_status() end, desc = "Git Status (Snacks)" },
      { "<leader>sn", function() Snacks.picker.notifications() end, desc = "Notifications History (Snacks)" },
      { "<leader>sp", function() Snacks.picker.pickers() end, desc = "All Pickers List (Snacks)" },
      { "<leader>sl", function() Snacks.picker.lines() end, desc = "Search Buffer Lines (Snacks)" },
      { "<leader>sw", function() Snacks.picker.grep_word() end, desc = "Search Cursor Word (Snacks)" },
      { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Search Keymaps (Snacks)" },
      { "<leader>sc", function() Snacks.picker.command_history() end, desc = "Command History (Snacks)" },
      { "<leader>se", function() Snacks.picker.explorer() end, desc = "File Explorer Picker (Snacks)" },
      -- Snacks Utilities
      { "<leader>h",  function() Snacks.dashboard() end, desc = "Open Dashboard" },
      { "<leader>z",  function() Snacks.zen() end, desc = "Toggle Zen Mode" },
      { "<leader>Z",  function() Snacks.zen.zoom() end, desc = "Toggle Zoom" },
      { "<leader>.",  function() Snacks.scratch() end, desc = "Toggle Scratch Buffer" },
      { "<leader>S",  function() Snacks.scratch.select() end, desc = "Select Scratch Buffer" },
      { "<leader>nh", function() Snacks.notifier.show_history() end, desc = "Notification History" },
      { "<leader>bd", function() Snacks.bufdelete() end, desc = "Delete Buffer" },
      { "<leader>cR", function() Snacks.rename.rename_file() end, desc = "Rename File" },
      { "<leader>gB", function() Snacks.gitbrowse() end, desc = "Git Browse" },
      { "<leader>gb", function() Snacks.git.blame_line() end, desc = "Git Blame Line" },
      { "<leader>lg", function() Snacks.lazygit() end, desc = "Toggle Lazygit (Snacks)" },
      { "<leader>un", function() Snacks.notifier.hide() end, desc = "Dismiss All Notifications" },
      { "<c-/>",      function() Snacks.terminal() end, mode = { "n", "t" }, desc = "Toggle Terminal" },
      { "<c-_>",      function() Snacks.terminal() end, mode = { "n", "t" }, desc = "Toggle Terminal" },
    },
  },
  {
    "goolord/alpha-nvim",
    enabled = false,
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

  -- Navigation (Telescope - mapped under <leader>t*)
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("telescope").setup({
        defaults = {
          sorting_strategy = "ascending",
          layout_strategy = "vertical",
          layout_config = {
            vertical = {
              prompt_position = "top",
              mirror = true,        -- Places Results above Preview (Top->Bottom: Prompt -> Results -> Preview)
              preview_height = 0.50, -- 50% height reserved for preview at bottom
              preview_cutoff = 0,    -- Always scale by percent without hiding
            },
            width = 0.90,  -- 90% of editor width
            height = 0.90, -- 90% of editor height
          },
        },
      })
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>tf", builtin.find_files, { desc = "Search Files (Telescope)" })
      vim.keymap.set("n", "<leader>tg", builtin.live_grep, { desc = "Search Live Grep (Telescope)" })
      vim.keymap.set("n", "<leader>tb", builtin.buffers, { desc = "Search Buffers (Telescope)" })
      vim.keymap.set("n", "<leader>th", builtin.help_tags, { desc = "Search Help Tags (Telescope)" })
      vim.keymap.set("n", "<leader>tw", builtin.grep_string, { desc = "Search Word under cursor (Telescope)" })
      vim.keymap.set("n", "<leader>tr", builtin.oldfiles, { desc = "Search Recent Files (Telescope)" })
      vim.keymap.set("n", "<leader>tc", builtin.colorscheme, { desc = "Search Colorschemes (Telescope)" })
      vim.keymap.set("n", "<leader>tk", builtin.keymaps, { desc = "Search Keymaps (Telescope)" })
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
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = true,
  },
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
