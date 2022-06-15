require('impatient')
-- require'impatient'.enable_profile()
vim.opt.autoread       = true           -- automatically read changed file again
vim.opt.autowrite      = true -- Write the contents of the file, if it has been modified
vim.opt.cursorline     = true           --highlight current line
vim.opt.showmatch      = true          -- highlight matching [{()}]
vim.opt.foldenable     = false
-- vim.opt.foldenable     = true         -- enable folding
vim.opt.foldlevelstart = 10     --open most folds by default
vim.opt.splitright     = true   -- split to the right
vim.opt.splitbelow     = true   -- split below
vim.opt.hidden         = true   -- allow modified/unsaved buffers in the background.
vim.opt.number         = true
vim.opt.relativenumber = true
vim.opt.smartcase      = true   -- if capital letter is used, then do not ignore case
vim.opt.ignorecase     = true  -- If the 'ignorecase' option is on, the case of normal letters is ignored.
vim.opt.shiftwidth     = 4   -- size of an indent
vim.opt.softtabstop    = 4       -- Indentation levels very four columns"
vim.opt.tabstop        = 4           -- size of a hard tabstop number of visual spaces per TAB
vim.opt.incsearch      = true    -- search as characters are entered
vim.opt.hlsearch       = true   -- highlight matches
vim.opt.wildmenu       = true
vim.opt.swapfile       = false
vim.opt.conceallevel   = 2
vim.opt.scrolloff      = 2         -- Minimal number of screen lines to keep above and below the cursor.
-- vim.opt.iskeyword      =
vim.opt.background     = 'dark'   -- Setting dark mode
vim.opt.undofile       = true      -- Save undos after file closes
-- vim.opt.undodir        = "$HOME/.vim/undo"  --where to save undo histories
vim.opt.undolevels     = 10000         -- How many undos
vim.opt.undoreload     = 10000        --number of lines to save for undo
vim.opt.mouse          = 'a'
vim.opt.termguicolors  = true
vim.cmd [[
set list
set showbreak=↪\
set listchars=tab:→\ ,eol:↲,nbsp:␣,trail:•,extends:⟩,precedes:⟨
]]

vim.cmd [[packadd packer.nvim]]

local packer = require('packer')
packer.init {
    max_jobs = 50,
}

require('packer').startup(function(use)

	use 'wbthomason/packer.nvim'
    use { 'lewis6991/impatient.nvim', opt = false }




	-- Essential
    use {
        'tpope/vim-unimpaired'
    }
    -- use 'mhinz/vim-sayonara'
    use {'junegunn/fzf', dir = '~/.fzf', run = './install --all' }
    use 'junegunn/fzf.vim'
    -- use 'nvim-lua/lsp-status.nvim'
	use {
		'akinsho/bufferline.nvim',
		opt = false,
		config = [[require('config.bufferline')]]
	}
	use {'airblade/vim-rooter', config= function()
		vim.cmd [[ let g:rooter_silent_chdir = 1
		let g:startify_change_to_dir = 0
		let g:rooter_change_directory_for_non_project_files = "current"
		let g:rooter_patterns = [".git", "Makefile", ".prjroot", ".hg"]
		]]
	end}
	use 'mhinz/vim-startify'

    -- use {
    --     'sunjon/shade.nvim',
    --     config = [[ require'shade'.setup({})]]
    -- }

   -- Files
    use {
		'justinmk/vim-dirvish',
		opt = false,
		config = [[require('config.dirvish')]]
	}
    use 'tpope/vim-eunuch'
    use {
        'kyazdani42/nvim-tree.lua',
        opt = true,
        requires = {
          'kyazdani42/nvim-web-devicons', -- optional, for file icon
        },
        config = function() require'nvim-tree'.setup {
            update_to_buf_dir = false,
            update_cwd = true,
        } end,
		cmd =  {'NvimTreeToggle', 'NvimTreeOpen'},
    }

	-- Editing
	use 'tpope/vim-surround'              -- surround text objects with whatever
	use 'AndrewRadev/splitjoin.vim'
	use 'junegunn/vim-easy-align'         -- perform alignment easier
	use 'tpope/vim-repeat'
	use 'sgur/vim-editorconfig'
    use {
        'lukas-reineke/indent-blankline.nvim',
        ft= {"python", "yaml"},
        config = function()
            require("indent_blankline").setup({buftype_exclude = {"terminal"} })
        end
    }
	-- use 'tpope/vim-commentary'          -- commenting plugin
    use {
    'numToStr/Comment.nvim',
    config = function()
        require('Comment').setup()
    end
    }
	use 'kana/vim-textobj-user'
    use 'Julian/vim-textobj-variable-segment'
    use 'glts/vim-textobj-comment'
    use 'kana/vim-textobj-entire'
	use 'vim-scripts/BufOnly.vim'
	-- use 'machakann/vim-highlightedyank'
	use 'sbdchd/neoformat'
    use 'goerz/jupytext.vim'
	use {
		'kkoomen/vim-doge',
		run = ':call doge#install()',
		ft = {"python", "typescriptreact", "javascript", "typescript"},
        config = function()
            vim.cmd [[ let g:doge_doc_standard_python = 'google' ]]
        end
	} -- doc generat
    use 'ThePrimeagen/harpoon'

	-- Color Schemes
	-- use {'morhetz/gruvbox', config = function() vim.cmd [[ autocmd vimenter * ++nested colorscheme gruvbox ]] end}
	-- use { 'arcticicestudio/nord-vim', config = function() vim.cmd [[ autocmd vimenter * ++nested colorscheme nord ]] end}
	-- use {'arcticicestudio/nord-vim'}
    use {'folke/tokyonight.nvim', config = function() vim.cmd [[ autocmd vimenter * ++nested colorscheme tokyonight]] end}


	use 'NLKNguyen/papercolor-theme'

    use {'rafi/awesome-vim-colorschemes'}

	use {
		'nvim-telescope/telescope.nvim',
		requires = {
		    'nvim-lua/popup.nvim',
			'nvim-lua/plenary.nvim',
            'nvim-telescope/telescope-fzy-native.nvim',
			'ThePrimeagen/git-worktree.nvim',
		},
		 wants = {
			'popup.nvim',
			'plenary.nvim',
		},
		config = [[require('config.telescope')]],
		cmd =  {'Telescope'},
	}


	use {
		'nvim-treesitter/nvim-treesitter',
        opt = true,
        ft = {"python", "org", "lua", "markdown", "html", "rmd", "r", "rust", "go"},
		requires = {
			'nvim-treesitter/nvim-treesitter-textobjects',
			'nvim-treesitter/playground',
		},
        config = [[require('config.treesitter')]],
		run = ':TSUpdate',
	}
	use {
        'romgrk/nvim-treesitter-context',
        opt = true,
        ft = {"python", "r", "rmd"},
        requires = 'nvim-treesitter/nvim-treesitter',
        after = "nvim-treesitter",
        config = function ()
            require'treesitter-context'.setup{
                enable = true, -- Enable this plugin (Can be enabled/disabled later via commands)
                throttle = true, -- Throttles plugin updates (may improve performance)
                max_lines = 0, -- How many lines the window should span. Values <= 0 mean no limit.
                patterns = { -- Match patterns for TS nodes. These get wrapped to match at word boundaries.
                -- For all filetypes
                -- Note that setting an entry here replaces all other patterns for this entry.
                -- By setting the 'default' entry below, you can control which nodes you want to
                -- appear in the context window.
                default = {
                    'class',
                    'function',
                    'method',
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
        }

        end
    }
	use { 'SmiteshP/nvim-gps',
        requires = 'nvim-treesitter/nvim-treesitter',
        after = "nvim-treesitter",
    }
    -- use {'nvim-lua/lsp-status.nvim'}
        -- -- opt = true,
        -- -- ft = {"python"},
        -- -- requires = 'nvim-treesitter/nvim-treesitter',
        -- -- after = "nvim-treesitter",
        -- -- config = function ()
        -- --     require("nvim-gps").setup({})
        -- -- end
	-- }
	use {
		'hoob3rt/lualine.nvim',
		opt = false,
		config = [[require('config.lualine')]],
		-- requires = 'SmiteshP/nvim-gps',
	}
	-- Completion and linting
	use {
		'neovim/nvim-lspconfig',
        opt = true,
        ft = {"python", "lua", "rust", "vue", "typescriptreact", "htmldjango", "css", "rmd", "r", "go"},
		config = [[require('config.lsp')]],
	}
  --   use {
  --       'jose-elias-alvarez/null-ls.nvim',
		-- config = [[require('config.nullls')]],
  --   }

	use { 'folke/lsp-colors.nvim' }

    use {
        'code-biscuits/nvim-biscuits',
        opt = true,
        ft = {"python"},
        config = function()
        require('nvim-biscuits').setup({
            toggle_keybind = "<leader>cb",
            cursor_line_only = true,
            default_config = {
                max_length = 12,
                min_distance = 5,
                prefix_string = " 📎 "
            },
            language_config = {
                html = {
                    prefix_string = " 🌐 "
                },
                javascript = {
                    prefix_string = " ✨ ",
                    max_length = 80
                },
                python = {
                    -- disabled = true
                    -- prefix_string = " ✨ ",
                }
            }
        })
        end,
        requires = 'nvim-treesitter/nvim-treesitter',
        after = 'nvim-treesitter',
    }
    -- Completion
    ---- Snippets
    use {
        "L3MON4D3/LuaSnip",
        config = [[require('config.snippets')]],
    }
    use "rafamadriz/friendly-snippets"

    -- use "rafamadriz/friendly-snippets"
    -- use { 'SirVer/ultisnips',
    -- config = function()
    --     vim.cmd 'let g:UltiSnipsExpandTrigger="<S-tab>"'
    --     vim.cmd 'let g:UltiSnipsJumpForwardTrigger="<Tab>"'
    --     vim.cmd 'let g:UltiSnipsJumpBackwardTrigger="<S-Tab>"'
    --     vim.cmd 'let g:UltiSnipsEditSplit="vertical"'
    --     vim.cmd 'let g:UltiSnipsNoPythonWarning = 1'
    --     vim.cmd 'let g:UltiSnipsSnippetDirectories=["mysnippets"]'
    --     vim.cmd 'noremap <silent> <Leader>ult :UltiSnipsEdit!<CR>2<CR>'
    -- end
    -- }
    -- use 'honza/vim-snippets'
	use 'onsails/lspkind-nvim'
    use {
        'hrsh7th/nvim-cmp',
        requires = {
            {'hrsh7th/cmp-buffer', after = 'nvim-cmp'},
            -- {'quangnguyen30192/cmp-nvim-ultisnips', after = 'nvim-cmp'},
            'hrsh7th/cmp-nvim-lsp',
            {'hrsh7th/cmp-path', after = 'nvim-cmp'},
            {'octaltree/cmp-look', after = 'nvim-cmp'},
            {'hrsh7th/cmp-nvim-lua', after = 'nvim-cmp'},
            {'tjdevries/complextras.nvim', after = 'nvim-cmp'},
            {'saadparwaiz1/cmp_luasnip', after = 'nvim-cmp'},
            {'hrsh7th/cmp-copilot', after = 'nvim-cmp'},
        },
        config = [[require('config.cmp')]],
        event = 'InsertEnter *',
    }
    use {
        'rcarriga/nvim-notify'
    }

    -- Plug 'ervandew/supertab'

    ------ Org
    use {
        'nvim-orgmode/orgmode',
        config = [[require('config.org')]],
        requires = {
            {'akinsho/org-bullets.nvim'},
            {'nvim-treesitter/nvim-treesitter'}
        },
        after = "nvim-treesitter"
    }
    -- Projects
    use 'tpope/vim-projectionist'


    -- -- IDE Like Featues
    use 'szw/vim-maximizer'
    -- Navigation
    -- use 'ggandor/lightspeed.nvim'
    use {
        'ggandor/leap.nvim',
        config = function()
            require('leap').set_default_keymaps()
        end
    }
    -- use {
    --     'phaazon/hop.nvim',
    --     branch = 'v1', -- optional but strongly recommended
    --     config = function()
    --         -- you can configure Hop the way you like here; see :h hop-config
    --         require'hop'.setup { keys = 'etovxqpdygfblzhckisuran' }
    --     end
    -- }
    -- use {'ray-x/navigator.lua', requires = {'ray-x/guihua.lua', run = 'cd lua/fzy && make'}}
    use {
        'glacambre/firenvim',
        run = ':call firenvim#install(0)',
        config = function()
            vim.cmd 'source ~/.dotfiles/nvim/lua/config/firenvim.vim'
        end
    }

    ---- Metaview
    use {'liuchengxu/vista.vim', cmd = "Vista"}
    use {'simrat39/symbols-outline.nvim', cmd = {"SymbolsOutline"}}
    use {'stevearc/aerial.nvim'}

    use {'IMOKURI/line-number-interval.nvim'}

-- ---- REPL
-- Plug 'jpalardy/vim-slime'


    -- Git
    -- use 'rhysd/committia.vim'
    -- use 'airblade/vim-gitgutter'
    use {
        'lewis6991/gitsigns.nvim',
        requires = {
            'nvim-lua/plenary.nvim'
        },
        config = function()
            require('gitsigns').setup()
        end
    }

    use {
        'hoschi/yode-nvim',
        requires = {
            'nvim-lua/plenary.nvim'
        },
        config = function()
            require('yode-nvim').setup({})
        end
    }

    use 'tpope/vim-fugitive'
    use 'tpope/vim-rhubarb'
    use {
        'jreybert/vimagit',
        opt = true,
        cmd = "Magit",
    }

    use {
        'junegunn/gv.vim',
        opt = true,
        cmd = "GV"
    }
    use 'rhysd/git-messenger.vim'
    use {
        'pwntester/octo.nvim',
        config = [[require('config.octo')]],
        cmd = {'Octo'}
    }

    -- Testing
    use {
        'vim-test/vim-test',
        opt = true,
        ft= {"python", "rust", "r", "go"},
        config = function ()
            vim.cmd [[
            let test#python#runner = 'pytest'
            let g:test_extra = ''
            let test#python#pytest#options = g:test_extra . '-s -v'
            ]]
        end

    }
    use { 'tpope/vim-dispatch', cmd = { 'Dispatch', 'Make', 'Focus', 'Start' } }

    -- https://alpha2phi.medium.com/neovim-dap-enhanced-ebc730ff498b
    -- use {
    --     'mfussenegger/nvim-dap',
    --     -- opt = true,
    --     ft = {"python","lua"},
    --     config = [[require('config.dap')]],
    --     requires = {
    --         'jbyuki/one-small-step-for-vimkind',
    --         'mfussenegger/nvim-dap-python',
    --         'rcarriga/nvim-dap-ui',
    --     },
    --     wants = 'one-small-step-for-vimkind',
    -- }


    -- use {
    --     'theHamsta/nvim-dap-virtual-text',
    --     opt = true,
    --     ft = "python",
    --     config = [[ require("nvim-dap-virtual-text").setup() ]],
    --     requires = {
    --         'mfussenegger/nvim-dap',
    --     }
    --
    --
    -- }
    -- use {
    --     'nvim-telescope/telescope-dap.nvim',
    --     opt = true,
    --     ft = "python",
    --     after = "telescope.nvim"
    -- }
    use {
        "rcarriga/vim-ultest",
        opt = true,
        config = "require('config.ultest').post()",
        requires = {"vim-test/vim-test"},
        cmd = {"Ultest", "UltestNearest"},
		run = ':UpdateRemotePlugins',
    }



-- ---- LSP
-- local fts = {"org", "python", "react", "typescript", "typescriptreact", "lua", "rust"}
-- Plug 'tjdevries/lsp_extensions.nvim'
-- Plug 'nvim-lua/completion-nvim'
-- -- Plug 'glepnir/lspsaga.nvim'



-- ---- Languages
-- ------ Writing/Markdown/Rst
    use { 'masukomi/vim-markdown-folding', opt = true, ft = "markdown"}
    use 'dhruvasagar/vim-table-mode'
    use { 'tpope/vim-abolish',

          config = function()
            vim.cmd 'source ~/.dotfiles/nvim/shortcuts.vim'
          end
}
    use {
        'junegunn/goyo.vim',
        opt = true,
        requires = {
            'junegunn/limelight.vim'
        },
        cmd = "Goyo"
    }

    use {
      "folke/zen-mode.nvim",
      config = function()
        require("zen-mode").setup {
          -- your configuration comes here
          -- or leave it empty to use the default settings
          -- refer to the configuration section below
        }
      end
    }

    -- Javascript
    use {
        'maxmellon/vim-jsx-pretty',
        ft = {"javascript", "react", "typescript", "typescriptreact"}

    }
    use {
        'pangloss/vim-javascript',
        ft = {"javascript", "react", "typescript", "typescriptreact"}
    }
    use {
        'prettier/vim-prettier',
        ft = {"javascript", "react", "typescript", "typescriptreact", "htmldjango"},
        cmd = {"Prettier"}
    }
    use {
        'mattn/emmet-vim',
        ft = {"javascript", "react", "typescript", "typescriptreact", "html"},
    }

-- ------ Python
-- Plug 'goerz/jupytext.vim'
    use {
        'kalekundert/vim-coiled-snake',
        opt = true,
        lock=true,
        ft = {"python"}
    }

    ------ Rust
    use { 'rust-lang/rust.vim', ft = {"rust"}}
    use {
        'simrat39/rust-tools.nvim',
        ft = {"rust"},
		config = [[require('config.rust_tools')]]
    }


    ------ Go
    use {'fatih/vim-go', opt = true, ft = {"go"}}

    ------ Latex
    use {
        'lervag/vimtex',
        opt = true,
        ft = {"tex", "latex"},
        config = function()
            vim.cmd 'let g:tex_flavor = "latex"'
        end
    }

    ------ Snakemake
    use { 'burneyy/vim-snakemake', opt = true, ft = {"snakemake" }}
    use {'pest-parser/pest.vim', opt = true, ft = "pest" }


    -- -- Plug 'luukvbaal/stabilize.nvim'
    use {
        'folke/twilight.nvim',
        opt = true,
        cmd = "Twilight",
        config = function()
            require("twilight").setup({
                exclude = {"lua"},
            })
        end
    }

    use {
        'NFrid/due.nvim',
        opt = true,
        ft = {"org"},
        config = function()
            require('due_nvim').setup({
                prescript = 'due: ',           -- prescript to due data
                prescript_hi = 'Comment',      -- highlight group of it
                due_hi = 'String',             -- highlight group of the data itself
                ft = '*.org,*.md',                   -- filename template to apply aucmds :)
                today = 'TODAY',               -- text for today's due
                today_hi = 'Character',        -- highlight group of today's due
                overdue = 'OVERDUE',           -- text for overdued
                overdue_hi = 'Error',          -- highlight group of overdued
                date_hi = 'Conceal',           -- highlight group of date string
                pattern_start = '<',           -- start for a date string pattern
                pattern_end = '>',             -- end for a date string pattern
                use_clock_time = false,        -- allow due.nvim to calculate hours, minutes, and seconds
                default_due_time = "midnight", -- if use_clock_time == true, calculate time until option on specified date.
                --   Accepts "midnight", for 23:59:59, or noon, for 12:00:00
            })
        end
    }

	-- Maintainence
	use { 'tweekmonster/startuptime.vim', opt = true, cmd = {'StartupTime'}}
    -- Lua
    use {
        "folke/trouble.nvim",
        requires = "kyazdani42/nvim-web-devicons",
        config = function()
            require("trouble").setup {
                -- your configuration comes here
                -- or leave it empty to use the default settings
                -- refer to the configuration section below
            }
        end
    }
    use {
        'mechatroner/rainbow_csv',
        opt = true
    }

    use {
        'chrisbra/csv.vim'
    }


    -- use {
    --     "folke/which-key.nvim",
    --     config = function()
    --         require("which-key").setup {
    --             -- your configuration comes here
    --             -- or leave it empty to use the default settings
    --             -- refer to the configuration section below
    --         }
    --     end
    -- }
    --
    use {
        'rhysd/vim-grammarous',
        opt = true,
        ft = {"rst", "org", "markdown", "rmd" },
        config = function()
            vim.g["grammarous#languagetool_cmd"] = vim.fn.stdpath('data')..'/site/pack/packer/opt/vim-grammarous/misc/LanguageTool-5.5/languagetool'
        end
    }


    use {
        'mg979/vim-visual-multi',
        config = [[require('config.multi')]],
    }

    use {
        'christoomey/vim-titlecase'
    }

    use {
        'github/copilot.vim'
    }



end)


-- local Plug = vim.fn['plug#']

-- vim.call('plug#begin', '~/.config/nvim/plugged')

-- Plug('michaelb/sniprun', { ['do'] = 'bash install.sh 1', ['for'] = fts})
-- Plug('mrjones2014/dash.nvim', { ['do'] =  'make install', ['on'] = {'Dash'} })
-- -- Plug 'grepinsight/insight.nvim'

-- vim.call('plug#end')

-- Define maplocalleader

vim.cmd 'source ~/.dotfiles/vim/leaders.vim'
vim.cmd 'source ~/.dotfiles/vim/remaps.vim'
vim.cmd 'source ~/.dotfiles/vim/functions.vim'
vim.cmd 'source ~/.dotfiles/nvim/autocmds.vim'
vim.cmd 'source ~/.dotfiles/vim/commands.vim'

if vim.fn.filereadable("~/.vimrc_work") then
    vim.cmd 'source ~/.vimrc_work'
end





vim.cmd 'let g:airline#extensions#tabline#enabled = 1'
vim.cmd "let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.6 } }"
