-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Basic Settings
vim.g.mapleader = " " -- Make sure to set this before lazy setup
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus" -- Sync with system clipboard
vim.opt.breakindent = true
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.opt.inccommand = 'split'
vim.opt.cursorline = true
vim.opt.scrolloff = 10
vim.opt.termguicolors = true
vim.opt.guicursor = {
  "n-v-c:block-blinkwait700-blinkon400-blinkoff250",
  "i-ci-ve:ver25-blinkwait700-blinkon400-blinkoff250",
  "r-cr:hor20-blinkwait700-blinkon400-blinkoff250",
  "o:hor50-blinkwait700-blinkon400-blinkoff250",
  "a:blinkwait700-blinkon400-blinkoff250",
}
-- Claude theme follows the terminal background. Your Ghostty is cream, so
-- default to "light". Flip this one line to "dark" if you switch Ghostty to
-- a dark background — the warm-charcoal Claude variant will kick in.
vim.opt.background = "light"

-- Keymaps
vim.keymap.set("i", "kj", "<Esc>", { desc = "Escape insert mode" })

-- Setup Plugins
require("lazy").setup({
  -- Theme — Claude warm. Transparent background (adopts the terminal/Ghostty
  -- color); only the accents + syntax are tuned to the clay/coral palette that
  -- tmux + starship already use. "auto" => latte on a light bg, frappe on dark.
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "auto",
        background = { light = "latte", dark = "frappe" },
        transparent_background = true, -- editor follows the terminal background
        show_end_of_buffer = false,
        term_colors = true,
        styles = {
          comments = { "italic" },
          keywords = { "bold" },
        },
        color_overrides = {
          -- Light: tuned to read on Ghostty's cream (#faf9f5). Same hexes as
          -- the claude_light palette in ~/.config/starship.toml.
          latte = {
            rosewater = "#c15f3c",
            flamingo  = "#b5654d",
            pink      = "#b5567d",
            mauve     = "#8b4789",
            red       = "#b83d2e",
            maroon    = "#a8443a",
            peach     = "#c15f3c", -- clay — keywords / accents
            yellow    = "#a87b1f", -- ochre — types
            green     = "#5f7a2e", -- sage — strings
            teal      = "#2e8b8b",
            sky       = "#3f9a9a",
            sapphire  = "#2f7d8a",
            blue      = "#b5654d", -- functions -> terracotta (kept warm)
            lavender  = "#8b4789",
            text      = "#3d3d3a",
            subtext1  = "#55554f",
            subtext0  = "#6b6b66",
            overlay2  = "#8a8a85",
            overlay1  = "#9a9a92",
            overlay0  = "#aaaaa0",
            surface2  = "#ddd6c7",
            surface1  = "#e4dfd2",
            surface0  = "#ece7d8",
            base      = "#faf9f5",
            mantle    = "#f2efe6",
            crust     = "#2b2b28",
          },
          -- Dark: warm charcoal + coral, in case you flip Ghostty to dark.
          frappe = {
            rosewater = "#f2d5cc",
            flamingo  = "#e8a896",
            pink      = "#e0a0c0",
            mauve     = "#c98aa0",
            red       = "#e8806a",
            maroon    = "#e0907a",
            peach     = "#d97757", -- coral — keywords / accents
            yellow    = "#d9a85f", -- warm gold — types
            green     = "#a3b86a", -- sage — strings
            teal      = "#7fc0bd",
            sky       = "#8fd0cd",
            sapphire  = "#7db5c0",
            blue      = "#e0a088", -- functions -> warm
            lavender  = "#d2a0b0",
            text      = "#e8e6dc",
            subtext1  = "#cfcdc4",
            subtext0  = "#b5b3aa",
            overlay2  = "#8a8a82",
            overlay1  = "#76766f",
            overlay0  = "#62625c",
            surface2  = "#4a4a45",
            surface1  = "#3a3a37",
            surface0  = "#30302e",
            base      = "#262624",
            mantle    = "#1f1e1d",
            crust     = "#191817",
          },
        },
        custom_highlights = function(C)
          return {
            ["@keyword"]       = { fg = C.peach, bold = true },
            ["@keyword.function"] = { fg = C.peach, bold = true },
            ["@function"]      = { fg = C.flamingo },
            ["@function.call"] = { fg = C.flamingo },
            ["@string"]        = { fg = C.green },
            ["@type"]          = { fg = C.yellow },
            ["@constant"]      = { fg = C.peach },
            ["@number"]        = { fg = C.yellow },
            ["@comment"]       = { fg = C.overlay2, style = { "italic" } },
            Search             = { bg = C.surface1, fg = C.peach, bold = true },
            IncSearch          = { bg = C.peach, fg = C.base },
            Visual             = { bg = C.surface1 },
            MatchParen         = { fg = C.peach, bold = true },
            ColorColumn        = { bg = C.mantle },
            CursorLineNr       = { fg = C.peach, bold = true },
          }
        end,
        integrations = {
          treesitter = true,
          native_lsp = { enabled = true },
          gitsigns = true,
          nvimtree = true,
          telescope = { enabled = true },
          cmp = true,
        },
      })
      vim.cmd.colorscheme("catppuccin")
    end,
  },

  -- Status Line
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "catppuccin",
        component_separators = '|',
        section_separators = '',
      },
    },
  },

  -- File Explorer
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({})
      vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { desc = "Toggle File Explorer" })
    end,
  },

  -- Fuzzy Finder (Telescope)
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.6",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
      },
    },
    config = function()
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>sf", builtin.find_files, { desc = "[S]earch [F]iles" })
      vim.keymap.set("n", "<leader>sg", builtin.live_grep, { desc = "[S]earch by [G]rep" })
      vim.keymap.set("n", "<leader><space>", builtin.buffers, { desc = "[ ] Find existing buffers" })
      
      -- Load fzf extension
      require('telescope').setup({
        extensions = {
          fzf = {
            fuzzy = true,                    -- false will only do exact matching
            override_generic_sorter = true,  -- override the generic sorter
            override_file_sorter = true,     -- override the file sorter
            case_mode = "smart_case",        -- or "ignore_case" or "respect_case"
          }
        }
      })
      require('telescope').load_extension('fzf')
    end,
  },

  -- Syntax Highlighting (Treesitter)
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "c", "lua", "vim", "vimdoc", "query", "python", "javascript", "typescript" },
        auto_install = false,
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },

  -- Git Integration
  {
    "lewis6991/gitsigns.nvim",
    opts = {},
  },

  -- Autocompletion & LSP
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-buffer",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-d>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
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
        sources = {
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "path" },
          { name = "buffer" },
        },
      })
    end,
  },

  -- LSP Config
  {
    "neovim/nvim-lspconfig",
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      
      -- Setup some common language servers (ensure you have them installed on your system)
      -- e.g. npm install -g pyright typescript-language-server

      -- Pyright
      vim.lsp.config('pyright', { capabilities = capabilities })
      vim.lsp.enable('pyright')

      -- TS LS
      vim.lsp.config('ts_ls', { capabilities = capabilities })
      vim.lsp.enable('ts_ls')

      -- C/C++ (clangd)
      vim.lsp.config('clangd', { capabilities = capabilities })
      vim.lsp.enable('clangd')

      -- Fortran (fortls)
      vim.lsp.config('fortls', { capabilities = capabilities })
      vim.lsp.enable('fortls')

      -- Bash (bashls)
      vim.lsp.config('bashls', { capabilities = capabilities })
      vim.lsp.enable('bashls')

      -- Lua LS
      vim.lsp.config('lua_ls', {
        capabilities = capabilities,
        settings = {
          Lua = {
             diagnostics = { globals = { 'vim' } },
          },
        },
      })
      vim.lsp.enable('lua_ls')

      -- Keymaps for LSP
      vim.keymap.set('n', 'K', vim.lsp.buf.hover, {})
      vim.keymap.set('n', 'gd', vim.lsp.buf.definition, {})
      vim.keymap.set({ 'n', 'v' }, '<leader>ca', vim.lsp.buf.code_action, {})
    end,
  },
})


-- Also run it every time a colorscheme is loaded 
-- (Colorschemes often override manual settings)
local function set_transparent()
    local highlights = {
        "Normal", "NormalFloat", "NonText", "SignColumn", 
        "EndOfBuffer", "MsgArea", "NormalNC",
        "CursorLine", -- Add this!
    }
    for _, group in ipairs(highlights) do
        vim.api.nvim_set_hl(0, group, { bg = "none", ctermbg = "none" })
    end
    
    -- Optional: If you still want to see where the cursor is, 
    -- add an underline instead of a background color
    vim.api.nvim_set_hl(0, "CursorLine", { underline = true })
end

set_transparent()
