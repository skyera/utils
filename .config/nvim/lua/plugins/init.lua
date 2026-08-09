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
      dim = { enabled = true },
      explorer = { enabled = true },
      git = { enabled = true },
      indent = { enabled = true, only_scope = true },
      input = { enabled = true },
      lazygit = { enabled = true },
      notifier = { enabled = true, timeout = 3000 },
      picker = { enabled = true },
      quickfile = { enabled = true },
      scratch = { enabled = true },
      scroll = { enabled = true },
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
      { "<leader>sC", function() Snacks.picker.commands() end, desc = "Vim Commands (Snacks)" },
      { "<leader>se", function() Snacks.picker.explorer() end, desc = "File Explorer Picker (Snacks)" },
      { "<leader>sd", function() Snacks.picker.diagnostics() end, desc = "Workspace Diagnostics (Snacks)" },
      { "<leader>sD", function() Snacks.picker.diagnostics_buffer() end, desc = "Buffer Diagnostics (Snacks)" },
      { "<leader>ss", function() Snacks.picker.lsp_symbols() end, desc = "LSP Document Symbols (Snacks)" },
      { "<leader>sS", function() Snacks.picker.lsp_workspace_symbols() end, desc = "LSP Workspace Symbols (Snacks)" },
      { "<leader>sq", function() Snacks.picker.qflist() end, desc = "Quickfix List (Snacks)" },
      { "<leader>sm", function() Snacks.picker.marks() end, desc = "Marks (Snacks)" },
      { "<leader>sj", function() Snacks.picker.jumps() end, desc = "Jumps (Snacks)" },
      -- Snacks Utilities & Git
      { "<leader>h",  function() Snacks.dashboard() end, desc = "Open Dashboard" },
      { "<leader>z",  function() Snacks.zen() end, desc = "Toggle Zen Mode" },
      { "<leader>Z",  function() Snacks.zen.zoom() end, desc = "Toggle Zoom" },
      { "<leader>.",  function() Snacks.scratch() end, desc = "Toggle Scratch Buffer" },
      { "<leader>S",  function() Snacks.scratch.select() end, desc = "Select Scratch Buffer" },
      { "<leader>nh", function() Snacks.notifier.show_history() end, desc = "Notification History" },
      { "<leader>bd", function() Snacks.bufdelete() end, desc = "Delete Buffer" },
      { "<leader>gb", function() Snacks.git.blame_line() end, desc = "Git Blame Line" },
      { "<leader>gL", function() Snacks.picker.git_log() end, desc = "Git Log (Snacks)" },
      { "<leader>lg", function() Snacks.lazygit() end, desc = "Toggle Lazygit (Snacks)" },
      { "<leader>un", function() Snacks.notifier.hide() end, desc = "Dismiss All Notifications" },
      -- Snacks Toggles (<leader>u* namespace)
      { "<leader>us", function() Snacks.toggle.option("spell"):toggle() end, desc = "Toggle Spelling" },
      { "<leader>uw", function() Snacks.toggle.option("wrap"):toggle() end, desc = "Toggle Line Wrap" },
      { "<leader>uL", function() Snacks.toggle.line_number():toggle() end, desc = "Toggle Line Numbers" },
      { "<leader>ud", function() Snacks.toggle.diagnostics():toggle() end, desc = "Toggle Diagnostics" },
      { "<leader>uC", function() Snacks.toggle.option("conceallevel", { off = 0, on = 2, name = "Conceal" }):toggle() end, desc = "Toggle Conceal" },
      { "<leader>ui", function() Snacks.toggle.indent():toggle() end, desc = "Toggle Indent Guides" },
      { "<leader>uD", function() Snacks.toggle.dim():toggle() end, desc = "Toggle Focus Dimming" },
      { "<leader>ub", function() Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):toggle() end, desc = "Toggle Dark Background" },
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

  -- LSP & Autocomplete (C/C++, Python, Bash, Lua)
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "luvit-meta/library", words = { "vim%.uv" } },
      },
    },
  },
  {
    "williamboman/mason.nvim",
    opts = {},
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "pyright", "bashls", "lua_ls" },
        automatic_installation = false,
        handlers = {
          function(server_name)
            -- Suppress automatic server setup since all servers are explicitly configured in nvim-lspconfig
          end,
        },
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local lspconfig = require("lspconfig")
      local util = require("lspconfig.util")
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

      -- Custom Hover Handler to deduplicate clangd hover signatures & add rounded borders
      local default_hover = vim.lsp.handlers["textDocument/hover"]
      vim.lsp.handlers["textDocument/hover"] = function(err, result, ctx, config)
        config = config or {}
        config.border = "rounded"
        if result and result.contents then
          local val = nil
          if type(result.contents) == "table" and result.contents.value then
            val = result.contents.value
          elseif type(result.contents) == "string" then
            val = result.contents
          end
          if val then
            -- Remove redundant trailing raw signature line in clangd hover output
            val = val:gsub("\n%s*%-%-%-%s*\n%s*[^\n]+%([^%)]*%)%s*$", "")
            if type(result.contents) == "table" and result.contents.value then
              result.contents.value = val
            elseif type(result.contents) == "string" then
              result.contents = val
            end
          end
        end
        local target_handler = default_hover or vim.lsp.handlers.hover
        if target_handler and target_handler ~= vim.lsp.handlers["textDocument/hover"] then
          return target_handler(err, result, ctx, config)
        end
      end

      -- Custom Diagnostic Handler to filter out undeclared identifier/function noise
      local default_publish_diag = vim.lsp.handlers["textDocument/publishDiagnostics"]
        or vim.lsp.diagnostic.on_publish_diagnostics
      vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
        if result and result.diagnostics then
          local filtered = {}
          for _, diag in ipairs(result.diagnostics) do
            local msg = (diag.message or ""):lower()
            local is_noise = msg:find("undeclared function", 1, true)
              or msg:find("undeclared identifier", 1, true)
              or msg:find("implicit declaration", 1, true)
              or msg:find("call to undeclared", 1, true)
              or msg:find("use of undeclared", 1, true)
            if not is_noise then
              table.insert(filtered, diag)
            end
          end
          result.diagnostics = filtered
        end
        local target_handler = default_publish_diag or vim.lsp.diagnostic.on_publish_diagnostics
        if target_handler and target_handler ~= vim.lsp.handlers["textDocument/publishDiagnostics"] then
          return target_handler(err, result, ctx, config)
        end
      end

      local on_attach = function(client, bufnr)
        local map = function(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = "LSP: " .. desc })
        end

        map("n", "gd", vim.lsp.buf.definition, "Goto Definition")
        map("n", "gD", vim.lsp.buf.declaration, "Goto Declaration")
        map("n", "gr", vim.lsp.buf.references, "Goto References")
        map("n", "gi", vim.lsp.buf.implementation, "Goto Implementation")
        map("n", "K", vim.lsp.buf.hover, "Hover Documentation")
        map({ "n", "i" }, "<C-k>", vim.lsp.buf.signature_help, "Signature Help")
        map("n", "<leader>rn", vim.lsp.buf.rename, "Rename Symbol")
        map("n", "<leader>ca", vim.lsp.buf.code_action, "Code Action")
        map("n", "[d", vim.diagnostic.goto_prev, "Previous Diagnostic")
        map("n", "]d", vim.diagnostic.goto_next, "Next Diagnostic")
      end

      -- C / C++ / CUDA Server Setup
      local clangd_capabilities = vim.lsp.protocol.make_client_capabilities()
      clangd_capabilities = require("cmp_nvim_lsp").default_capabilities(clangd_capabilities)
      clangd_capabilities.offsetEncoding = { "utf-16" }

      local clangd_cmd = vim.fn.executable("/usr/bin/clangd") == 1 and "/usr/bin/clangd" or "clangd"

      lspconfig.clangd.setup({
        on_attach = on_attach,
        capabilities = clangd_capabilities,
        filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
        root_dir = util.root_pattern("compile_commands.json", "compile_flags.txt", ".git"),
        cmd = {
          clangd_cmd,
          "--background-index",
          "--completion-style=detailed",
          "--header-insertion=never",
          "--pch-storage=memory",
          "-j=4",
        },
      })

      -- Python Server Setup
      lspconfig.pyright.setup({
        on_attach = on_attach,
        capabilities = capabilities,
        settings = {
          python = {
            analysis = {
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
              diagnosticMode = "openFilesOnly",
            },
          },
        },
      })

      -- Bash / Shell Server Setup
      lspconfig.bashls.setup({
        on_attach = on_attach,
        capabilities = capabilities,
      })

      -- Lua Server Setup
      lspconfig.lua_ls.setup({
        on_attach = on_attach,
        capabilities = capabilities,
        settings = {
          Lua = {
            completion = { callSnippet = "Replace" },
            diagnostics = { globals = { "vim" } },
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
          },
        },
      })

      vim.cmd("filetype detect")
    end,
  },
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-nvim-lsp-signature-help",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      require("luasnip.loaders.from_vscode").lazy_load()

      local kind_icons = {
        Text = "󰉿",
        Method = "m",
        Function = "󰊕",
        Constructor = "",
        Field = "",
        Variable = "󰆧",
        Class = "󰌗",
        Interface = "",
        Module = "",
        Property = "",
        Unit = "",
        Value = "󰎠",
        Enum = "",
        Keyword = "󰌋",
        Snippet = "",
        Color = "󰏘",
        File = "󰈙",
        Reference = "",
        Folder = "󰉋",
        EnumMember = "",
        Constant = "󰏿",
        Struct = "",
        Event = "",
        Operator = "󰆕",
        TypeParameter = "󰅲",
      }

      cmp.setup({
        performance = {
          debounce = 60,
          throttle = 30,
          fetching_timeout = 500,
        },
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        formatting = {
          fields = { "kind", "abbr", "menu" },
          format = function(entry, vim_item)
            vim_item.kind = string.format("%s %s", kind_icons[vim_item.kind] or "", vim_item.kind)
            vim_item.menu = ({
              nvim_lsp = "[LSP]",
              nvim_lsp_signature_help = "[Sig]",
              luasnip = "[Snippet]",
              buffer = "[Buffer]",
              path = "[Path]",
            })[entry.source.name]
            return vim_item
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<C-k>"] = cmp.mapping(function()
            vim.lsp.buf.signature_help()
          end, { "i", "s" }),
          ["<CR>"] = cmp.mapping.confirm({ select = false }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp", max_item_count = 20 },
          { name = "nvim_lsp_signature_help" },
          { name = "luasnip", max_item_count = 5 },
        }, {
          {
            name = "buffer",
            max_item_count = 5,
            keyword_length = 3,
            option = {
              get_bufnrs = function()
                return { vim.api.nvim_get_current_buf() }
              end,
            },
          },
          { name = "path", max_item_count = 5 },
        }),
      })
    end,
  },


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
