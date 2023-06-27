local M = {
    {
        "projekt0n/github-nvim-theme",
        lazy = false,    -- make sure we load this during startup if it is your main colorscheme
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
    { "NLKNguyen/papercolor-theme",    lazy = false },
    -- Reading
    {
        "nullchilly/fsread.nvim",
        cmd = { "FSRead", "FSClear", "FSToggle" },
    },
    {
        "SmiteshP/nvim-gps",
        dependencies = "nvim-treesitter/nvim-treesitter",
        ft = { "python", "rust", "json" },
    },
    {
        "romgrk/nvim-treesitter-context",
        ft = { "python", "r", "rmd", "cpp" },
        dependencies = "nvim-treesitter/nvim-treesitter",
        config = function()
            require("treesitter-context").setup({
                enable = true,   -- Enable this plugin (Can be enabled/disabled later via commands)
                throttle = true, -- Throttles plugin updates (may improve performance)
                max_lines = 0,   -- How many lines the window should span. Values <= 0 mean no limit.
                patterns = {     -- Match patterns for TS nodes. These get wrapped to match at word boundaries.
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
        config = [[require('config.ufo')]],
    },
    { "masukomi/vim-markdown-folding", ft = "markdown" },
    { "preservim/vim-markdown",        ft = "markdown" },
    -- Overview
    { "liuchengxu/vista.vim",          cmd = "Vista" },
    { "simrat39/symbols-outline.nvim", cmd = { "SymbolsOutline" } },

    {
        "code-biscuits/nvim-biscuits",
        ft = { "python", "rust", "go", "json" },
        config = function()
            require("nvim-biscuits").setup({
                toggle_keybind = "<leader>cb",
                cursor_line_only = true,
                default_config = {
                    max_length = 12,
                    min_distance = 5,
                    prefix_string = " 📎 ",
                },
                language_config = {
                    html = {
                        prefix_string = " 🌐 ",
                    },
                    javascript = {
                        prefix_string = " ✨ ",
                        max_length = 80,
                    },
                    python = {
                        -- disabled = true
                        prefix_string = " ✨ ",
                    },
                },
            })
        end,
        dependencies = "nvim-treesitter/nvim-treesitter",
    },

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
                    height = 1,  -- height of the Zen window
                    -- by default, no options are changed for the Zen window
                    -- uncomment any of the options below, or add other vim.wo options you want to apply
                    options = {
                        -- signcolumn = "no", -- disable signcolumn
                        number = false,         -- disable number column
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
    {
        "junegunn/goyo.vim",
        dependencies = {
            "junegunn/limelight.vim",
        },
        cmd = "Goyo",
    },
    { "tpope/vim-unimpaired", lazy = false },
    {
        "mg979/vim-visual-multi",
        config = function()
            vim.g.VM_maps = {
                ["Add Cursor Down"] = "<M-C-j>",
                ["Add Cursor Up"] = "<M-C-k>",
            }
            vim.g.VM_mouse_mappings = 1
        end,
    },
    {
        "junegunn/fzf",
        build = "./install --all",
        dir = "~/.fzf",
        lazy = false,
    },
    {
        "junegunn/fzf.vim",
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
        ft = { "python", "org", "lua", "markdown", "html", "rmd", "r", "rust", "go", "cpp", "svelte" },
        dependencies = {
            "nvim-treesitter/nvim-treesitter-textobjects",
            "nvim-treesitter/playground",
        },
        config = [[require('config.treesitter')]],
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
    { "mhinz/vim-startify",   lazy = false },
    { "github/copilot.vim",   lazy = false },
    { "tpope/vim-surround",   lazy = false }, -- surround text objects with whatever
    { "tpope/vim-repeat",     lazy = false },
    { "tpope/vim-dispatch",   cmd = { "Dispatch", "Make", "Focus", "Start" } },
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
    {
        "chipsenkbeil/distant.nvim",
        lazy = false,
        branch = "v0.2",
        config = function()
            require("distant").setup({
                -- Applies Chip's personal settings to every machine you connect to
                --
                -- 1. Ensures that distant servers terminate with no connections
                -- 2. Provides navigation bindings for remote directories
                -- 3. Provides keybinding to jump into a remote file's parent directory
                ["*"] = require("distant.settings").chip_default(),
                {
                    ssh = {
                        idendity_files = { "~/.ssh/id_rsa" },
                        user = { "allee" },
                    },
                },
            })
        end,
    },
    { "tpope/vim-eunuch",        lazy = false },
    -- { 'kyazdani42/nvim-web-devicons', lazy = false }, -- optional, for file icon

    -- Git
    {
        "tpope/vim-fugitive",
        cmd = { "Git" },
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
        "glacambre/firenvim",
        lazy = false,
        build = ":call firenvim#install(0)",
        config = function()
            vim.cmd("source ~/.dotfiles/nvim/lua/config/firenvim.vim")
        end,
    },
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

    { "ThePrimeagen/harpoon",    ft = { "svelte", "python", "rust" } },
    -- syntax highlights
    { "vmchale/just-vim",        ft = "just" },
    { "burneyy/vim-snakemake",   ft = { "snakemake" } },
    { "pest-parser/pest.vim",    ft = "pest" },
    { "mechatroner/rainbow_csv", ft = "csv" },
    { "snakemake/snakefmt",      ft = "snakemake" },
    { "evanleck/vim-svelte",     ft = "svelte" },
    { "ap/vim-css-color",        ft = { "svelte", "css", "python", "javascript", "lua" } },
    {
        "folke/twilight.nvim",
        cmd = "Twilight",
        config = function()
            require("twilight").setup({
                exclude = { "lua" },
                treesitter = true,
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
        lazy = false,
        config = function()
            vim.cmd("source ~/.dotfiles/nvim/shortcuts.vim")
        end,
    },
    {
        "svermeulen/text-to-colorscheme.nvim",
        lazy = false,
        config = function()
            require("text-to-colorscheme").setup({
                ai = {
                    openai_api_key = os.getenv("OPENAI_API_KEY"),
                },
                hex_palettes = {
                    {
                        name = "feeling_punk",
                        background_mode = "dark",
                        background = "#1c1c1c",
                        foreground = "#f5f5f5",
                        accents = {
                            "#ff4d4d",
                            "#ff9a00",
                            "#f7e600",
                            "#00d95a",
                            "#00baff",
                            "#ff00ff",
                            "#ff007a",
                        },
                    },
                },
            })
        end,
    },
    {
        "HampusHauffman/block.nvim",
        cmd = "Block",
        config = function()
            require("block").setup({})
        end,
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
            }
        },
    }
}

return M
