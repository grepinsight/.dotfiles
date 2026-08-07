local M = {
  {
    "voldikss/vim-floaterm",
    cmd = { "FloatermNew", "NNN", "LL" },
    config = function()
      vim.cmd([[command! NNN FloatermNew nnn]])
      vim.cmd([[command! LL FloatermNew --height=0.9 --width=0.9 lazygit]])
      vim.cmd([[command! LG FloatermNew lazygit]])
      vim.cmd([[nnoremap   <silent>   <F7>    :FloatermNew<CR>]])
      vim.cmd([[tnoremap   <silent>   <F7>    <C-\><C-n>:FloatermNew<CR>]])
      vim.cmd([[nnoremap   <silent>   <F8>    :FloatermPrev<CR>]])
      vim.cmd([[tnoremap   <silent>   <F8>    <C-\><C-n>:FloatermPrev<CR>]])
      vim.cmd([[nnoremap   <silent>   <F9>    :FloatermNext<CR>]])
      vim.cmd([[tnoremap   <silent>   <F9>    <C-\><C-n>:FloatermNext<CR>]])
      vim.cmd([[nnoremap   <silent>   <F12>   :FloatermToggle<CR>]])
      vim.cmd([[tnoremap   <silent>   <F12>   <C-\><C-n>:FloatermToggle<CR>]])
    end,
  },
  {
    "projekt0n/github-nvim-theme",
    lazy = false, -- make sure we load this during startup if it is your main colorscheme
    priority = 1000, -- make sure to load this before all the other start plugins
    config = function()
      require("github-theme").setup({
        -- ...
      })

      vim.cmd("colorscheme github_dark")
    end,
  },
  -- {
  --     "folke/tokyonight.nvim",
  --     lazy = false, -- make sure we load this during startup if it is your main colorscheme
  --     priority = 1000, -- make sure to load this before all the other start plugins
  --     config = function()
  --         -- load the colorscheme here
  --         vim.cmd([[colorscheme tokyonight]])
  --     end,
  -- },
  -- Reading
  {
    "romgrk/nvim-treesitter-context",
    ft = { "python", "r", "rmd", "cpp", "yaml" },
    dependencies = "nvim-treesitter/nvim-treesitter",
    config = function()
      require("treesitter-context").setup({
        enable = true, -- Enable this plugin (Can be enabled/disabled later via commands)
        throttle = true, -- Throttles plugin updates (may improve performance)
        max_lines = 0, -- How many lines the window should span. Values <= 0 mean no limit.
        patterns = { -- Match patterns for TS nodes. These get wrapped to match at word boundaries.
          -- For all filetypes
          -- Note that setting an entry here replaces all other patterns for this entry.
          -- By setting the 'default' entry below, you can control which nodes you want to
          -- appear in the context window.
          default = {
            "class",
            "function",
            "method",
            -- 'for', -- These won't appear in the context
            -- 'while',
            -- 'if',
            -- 'switch',
            -- 'case',
          },
          -- Example for a specific filetype.
          -- If a pattern is missing, *open a PR* so everyone can benefit.
          --   rust = {
          --       'impl_item',
          --   },
        },
      })
    end,
  },

  {
    -- folding plugin
    "kevinhwang91/nvim-ufo",
    lazy = false,
    dependencies = "kevinhwang91/promise-async",
    config = function()
      require("config.ufo")
    end,
  },
  -- { "masukomi/vim-markdown-folding", ft = "markdown" }, -- Disabled: auto-folding on save
  { "preservim/vim-markdown", ft = "markdown" },
  -- Overview
  { "liuchengxu/vista.vim", cmd = "Vista" },


  -- Project Overview
  {
    "kyazdani42/nvim-tree.lua",
    -- dependencies = {
    --     "kyazdani42/nvim-web-devicons", -- optional, for file icon
    -- },
    config = function()
      require("nvim-tree").setup({
        update_cwd = true,
        hijack_directories = {
          enable = false,
        },
      })
    end,
    cmd = { "NvimTreeToggle", "NvimTreeOpen", "NvimTreeFindFileToggle" },
    ft = { "svelte", "typescript" },
  },

  -- Editing
  {
    "numToStr/Comment.nvim",
    lazy = false,
    config = function()
      require("Comment").setup()
    end,
  },
  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",
    config = function()
      require("zen-mode").setup({
        -- your configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
        window = {
          backdrop = 0.95, -- shade the backdrop of the Zen window. Set to 1 to keep the same as Normal
          -- height and width can be:
          -- * an absolute number of cells when > 1
          -- * a percentage of the width / height of the editor when <= 1
          -- * a function that returns the width or the height
          width = 120, -- width of the Zen window
          height = 1, -- height of the Zen window
          -- by default, no options are changed for the Zen window
          -- uncomment any of the options below, or add other vim.wo options you want to apply
          options = {
            -- signcolumn = "no", -- disable signcolumn
            number = false, -- disable number column
            relativenumber = false, -- disable relative numbers
            -- cursorline = false, -- disable cursorline
            -- cursorcolumn = false, -- disable cursor column
            -- foldcolumn = "0", -- disable fold column
            -- list = false, -- disable whitespace characters
          },
        },
      })
    end,
  },
  { "tpope/vim-unimpaired", lazy = false },
  {
    "mg979/vim-visual-multi",
    lazy = false,
    config = function()
      vim.g.VM_maps = {
        ["Add Cursor Down"] = "<M-C-j>",
        ["Add Cursor Up"] = "<M-C-k>",
      }
      vim.g.VM_mouse_mappings = 1
    end,
  },
  {
    "junegunn/fzf.vim",
    dependencies = {
      {
        "junegunn/fzf",
        dir = "~/.fzf",
        build = "./install --all",
        lazy = false,
      },
    },
    lazy = false,
  },
  {
    "akinsho/bufferline.nvim",
    lazy = false,
    config = function()
      require("config.bufferline")
    end,
  },
  -- {
  --     "hoob3rt/lualine.nvim",
  --     lazy = false,
  --     config = function()
  --         require("config.lualine")
  --     end,
  -- },

  {
    "nvim-treesitter/nvim-treesitter",
    ft = { "python", "org", "lua", "markdown", "html", "rmd", "r", "rust", "go", "cpp", "svelte", "yaml" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
      "nvim-treesitter/playground",
    },
    config = function()
      require("config.treesitter")
    end,
    build = ":TSUpdate",
  },
  {
    "airblade/vim-rooter",
    lazy = false,
    config = function()
      vim.cmd([[
                let g:rooter_silent_chdir = 1
                let g:startify_change_to_dir = 0
                let g:rooter_change_directory_for_non_project_files = "current"
                let g:rooter_patterns = [".git", "Makefile", ".prjroot", ".hg", "justfile"]
            ]])
    end,
  },
  { "mhinz/vim-startify", lazy = false },
  -- Copilot is no longer a plugin. Neovim 0.12 ships vim.lsp.inline_completion, so
  -- ghost text now comes from copilot-language-server driven directly by vim.lsp.
  -- Configured in lua/plugins/lsp/init.lua; keys are unchanged (<M-l>/<M-]>/<M-[>).
  { "tpope/vim-surround", lazy = false }, -- surround text objects with whatever
  { "tpope/vim-repeat", lazy = false },
  { "tpope/vim-dispatch", cmd = { "Dispatch", "Make", "Focus", "Start" } },
  "AndrewRadev/splitjoin.vim",
  { "junegunn/vim-easy-align", lazy = false }, -- perform alignment easier,
  --{
  --    "L3MON4D3/LuaSnip",
  --    ft = {"python", "org", "lua", "markdown", "html", "rmd", "r", "rust", "go", "cpp"},
  --    config = function()
  --        require('config.snippets')
  --    end,
  --},
  {
    "justinmk/vim-dirvish",
    lazy = false,
    config = function()
      vim.cmd([[
            call dirvish#add_icon_fn({p -> p[-1:]=='/'?'📂':'📄'})
            " How to unmap things
            " augroup dirvish_config
            "   autocmd!
            "   autocmd FileType dirvish silent! unmap <buffer> <C-p>
            " augroup END

            augroup dirvish_config
            autocmd!
            autocmd FileType dirvish
            \ nnoremap <silent><buffer> t ddO<Esc>:let @"=substitute(@", '\n', '', 'g')<CR>:r ! find "<C-R>"" -maxdepth 1 -print0 \| xargs -0 ls -Fd<CR>:silent! keeppatterns %s/\/\//\//g<CR>:silent! keeppatterns %s/[^a-zA-Z0-9\/]$//g<CR>:silent! keeppatterns g/^$/d<CR>:noh<CR>
            augroup END
            ]])
    end,
  },
  { "tpope/vim-eunuch", lazy = false },
  -- { 'kyazdani42/nvim-web-devicons', lazy = false }, -- optional, for file icon

  -- Git
  {
    "tpope/vim-fugitive",
    cmd = { "Git", "Gwrite" },
    ft = { "makrdown", "python", "rust", "html", "css", "rmd", "r", "go", "cpp" },
  },
  "tpope/vim-rhubarb",
  {
    "jreybert/vimagit",
    cmd = "Magit",
  },
  {
    "junegunn/gv.vim",
    cmd = "GV",
  },
  "rhysd/git-messenger.vim",
  {
    "pwntester/octo.nvim",
    config = [[require('config.octo')]],
    cmd = { "Octo" },
  },

  -- Magic
  {
    "dstein64/vim-startuptime",
    -- lazy-load on a command
    cmd = "StartupTime",
    -- init is called during startup. Configuration for vim plugins typically should be set in an init function
    init = function()
      vim.g.startuptime_tries = 10
    end,
  },
  -- {
  --     "jackMort/ChatGPT.nvim",
  --     event = "VeryLazy",
  --     config = function()
  --         require("chatgpt").setup(
  --         {
  --             openai_params = {
  --                 model = "gpt-4",
  --                 frequency_penalty = 0,
  --                 presence_penalty = 0,
  --                 max_tokens = 500,
  --                 temperature = 0,
  --                 top_p = 1,
  --                 n = 1,
  --             }
  --         }
  --         )
  --
  --     end,
  --     dependencies = {
  --         "MunifTanjim/nui.nvim",
  --         "nvim-lua/plenary.nvim",
  --         "nvim-telescope/telescope.nvim"
  --     }
  -- },

  { "ThePrimeagen/harpoon", ft = { "svelte", "python", "rust" } },
  -- syntax highlights
  { "vmchale/just-vim", ft = "just" },
  { "burneyy/vim-snakemake", ft = { "snakemake" } },
  { "pest-parser/pest.vim", ft = "pest" },
  { "mechatroner/rainbow_csv", ft = "csv" },
  { "snakemake/snakefmt", ft = "snakemake" },
  { "evanleck/vim-svelte", ft = "svelte" },
  { "ap/vim-css-color", ft = { "svelte", "css", "python", "javascript", "lua" } },
  {
    "folke/twilight.nvim",
    cmd = "Twilight",
    config = function()
      require("twilight").setup({
        exclude = { "lua" },
        treesitter = true,
        context = 0,
      })
    end,
  },
  { "vim-scripts/BufOnly.vim", cmd = "BOnly" },
  {
    "prettier/vim-prettier",
    ft = { "javascript", "react", "typescript", "typescriptreact", "htmldjango", "svelte" },
    cmd = { "Prettier" },
  },
  {
    "tpope/vim-abolish",
    ft = { "markdown" },
    config = function()
      vim.cmd("source ~/.config/nvim/shortcuts.vim")
    end,
  },
  {
    "dhruvasagar/vim-table-mode",
    ft = { "markdown", "svelte" },
  },
  {
    "tpope/vim-projectionist",
    ft = { "python", "rust", "r", "go" },
  },
  {
    "vim-test/vim-test",
    ft = { "python", "rust", "r", "go" },
    config = function()
      vim.cmd([[
            let test#python#runner = 'pytest'
            let g:test_extra = ''
            let test#python#pytest#options = g:test_extra . '-s -v'
            ]])
    end,
  },
  {
    "mattn/emmet-vim",
    ft = { "javascript", "react", "typescript", "typescriptreact", "html", "svelte" },
  },
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    ---@type Flash.Config
    opts = {},
    keys = {
      {
        "s",
        mode = { "n", "x", "o" },
        function()
          -- default options: exact mode, multi window, all directions, with a backdrop
          require("flash").jump()
        end,
        desc = "Flash",
      },
      {
        "S",
        mode = { "n", "o", "x" },
        function()
          -- show labeled treesitter nodes around the cursor
          require("flash").treesitter()
        end,
        desc = "Flash Treesitter",
      },
      {
        "r",
        mode = "o",
        function()
          -- jump to a remote location to execute the operator
          require("flash").remote()
        end,
        desc = "Remote Flash",
      },
      {
        "R",
        mode = { "n", "o", "x" },
        function()
          -- show labeled treesitter nodes around the search matches
          require("flash").treesitter_search()
        end,
        desc = "Treesitter Search",
      },
    },
  },
  {
    -- automatic f-string in python
    "chrisgrieser/nvim-puppeteer",
    lazy = false, -- plugin lazy-loads itself. Can also load on filetypes.
  },
  {
    "cuducos/yaml.nvim",
    ft = { "yaml" }, -- optional
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-telescope/telescope.nvim", -- optional
    },
  },
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    ft = { "python" },
    opts = {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    },
  },
  {
    "goerz/jupytext.vim",
    lazy = false,
  },
  {
    "tommcdo/vim-exchange",
    lazy = false,
  },
  {
    "chrisgrieser/nvim-various-textobjs",
    lazy = false,
    kepmaps = { useDefaults = true },
  },
  {
    "stevearc/overseer.nvim",
    ft = { "python", "cpp" },
    config = function()
      require("overseer").setup({
        templates = { "builtin", "user.cpp_build" },
      })
    end,
  },
  -- {
  --   "OXY2DEV/markview.nvim",
  --   ft = "markdown",
  --
  --   dependencies = {
  --     -- You may not need this if you don't lazy load
  --     -- Or if the parsers are in your $RUNTIMEPATH
  --     "nvim-treesitter/nvim-treesitter",
  --
  --     "nvim-tree/nvim-web-devicons",
  --   },
  -- },
  {
    "vim-pandoc/vim-rmarkdown",
    ft = { "rmd", "rmarkdown" },
  },
  -- {
  --   "yetone/avante.nvim",
  --   event = "VeryLazy",
  --   opts = {
  --     -- add any opts here
  --   },
  --   dependencies = {
  --     "stevearc/dressing.nvim",
  --     "nvim-lua/plenary.nvim",
  --     "MunifTanjim/nui.nvim",
  --     --- The below dependencies are optional,
  --     "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
  --     {
  --       -- support for image pasting
  --       "HakonHarnes/img-clip.nvim",
  --       event = "VeryLazy",
  --       opts = {
  --         -- recommended settings
  --         default = {
  --           embed_image_as_base64 = false,
  --           prompt_for_file_name = false,
  --           drag_and_drop = {
  --             insert_mode = true,
  --           },
  --         },
  --       },
  --     },
  --     {
  --       -- Make sure to setup it properly if you have lazy=true
  --       "MeanderingProgrammer/render-markdown.nvim",
  --       opts = {
  --         file_types = { "markdown", "Avante" },
  --       },
  --       ft = { "markdown", "Avante" },
  --     },
  --   },
  -- },
  -- avante.nvim removed 2026-08-07. `lazy = false` made it load on every nvim
  -- start, dragging copilot.lua in as a dependency and spawning a node LSP even
  -- under --headless. Agentic work happens in Claude Code in a terminal split.
  {
    "vhyrro/luarocks.nvim",
    priority = 1000, -- Very high priority is required, luarocks.nvim should run as the first plugin in your config.
    config = true,
    opts = {
      rocks = { "fzy", "magick", "luasocket" }, -- specifies a list of rocks to install
      -- luarocks_build_args = { "--with-lua=/my/path" }, -- extra options to pass to luarocks's configuration script
    },
  },
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
    },
    keys = {
      { "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
      { "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>" },
      { "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>" },
      { "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>" },
      { "<c-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
    },
  },
  {
    "kiyoon/python-import.nvim",
    -- build = "pipx install . --force",
    build = "uv tool install . --force --reinstall",
    keys = {
      {
        "<M-CR>",
        function()
          require("python_import.api").add_import_current_word_and_notify()
        end,
        mode = { "i", "n" },
        silent = true,
        desc = "Add python import",
        ft = "python",
      },
      {
        "<M-CR>",
        function()
          require("python_import.api").add_import_current_selection_and_notify()
        end,
        mode = "x",
        silent = true,
        desc = "Add python import",
        ft = "python",
      },
      {
        "<space>i",
        function()
          require("python_import.api").add_import_current_word_and_move_cursor()
        end,
        mode = "n",
        silent = true,
        desc = "Add python import and move cursor",
        ft = "python",
      },
      {
        "<space>i",
        function()
          require("python_import.api").add_import_current_selection_and_move_cursor()
        end,
        mode = "x",
        silent = true,
        desc = "Add python import and move cursor",
        ft = "python",
      },
      {
        "<space>tr",
        function()
          require("python_import.api").add_rich_traceback()
        end,
        silent = true,
        desc = "Add rich traceback",
        ft = "python",
      },
    },
    opts = {
      -- Example 1:
      -- Default behaviour for `tqdm` is `from tqdm.auto import tqdm`.
      -- If you want to change it to `import tqdm`, you can set `import = {"tqdm"}` and `import_from = {tqdm = nil}` here.
      -- If you want to change it to `from tqdm import tqdm`, you can set `import_from = {tqdm = "tqdm"}` here.

      -- Example 2:
      -- Default behaviour for `logger` is `import logging`, ``, `logger = logging.getLogger(__name__)`.
      -- If you want to change it to `import my_custom_logger`, ``, `logger = my_custom_logger.get_logger()`,
      -- you can set `statement_after_imports = {logger = {"import my_custom_logger", "", "logger = my_custom_logger.get_logger()"}}` here.
      extend_lookup_table = {
        ---@type string[]
        import = {
          -- "tqdm",
        },

        ---@type table<string, string>
        import_as = {
          -- These are the default values. Here for demonstration.
          -- np = "numpy",
          -- pd = "pandas",
        },

        ---@type table<string, string>
        import_from = {
          -- tqdm = nil,
          -- tqdm = "tqdm",
        },

        ---@type table<string, string[]>
        statement_after_imports = {
          -- logger = { "import my_custom_logger", "", "logger = my_custom_logger.get_logger()" },
        },
      },

      ---Return nil to indicate no match is found and continue with the default lookup
      ---Return a table to stop the lookup and use the returned table as the result
      ---Return an empty table to stop the lookup. This is useful when you want to add to wherever you need to.
      ---@type fun(winnr: integer, word: string, ts_node: TSNode?): string[]?
      custom_function = function(winnr, word, ts_node)
        -- if vim.endswith(word, "_DIR") then
        --   return { "from my_module import " .. word }
        -- end
      end,
    },
  },
  "rcarriga/nvim-notify",

  {
    "rgroli/other.nvim",
    cmd = "Other",
    config = function()
      require("other-nvim").setup({
        mappings = {
          -- custom mapping
          {
            pattern = "/models/(.*)/(.*).sql$",
            target = "/models/%1/%2.yml",
          },
          {
            pattern = "/models/(.*)/(.*).yml$",
            target = "/models/%1/%2.sql",
          },
        },
      })
    end,
  },
  {
    "niklasl/vim-rdf",
    ft = { "turtle" },
  },
}

return M
