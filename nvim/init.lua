vim.opt.autoread       = true           -- automatically read changed file again
vim.opt.autowrite      = true -- Write the contents of the file, if it has been modified
vim.opt.cursorline     = true           --highlight current line
vim.opt.showmatch      = true          -- highlight matching [{()}]
vim.opt.foldenable     = true         -- enable folding
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

require('packer').startup(function()
	use 'wbthomason/packer.nvim'
    use 'lewis6991/impatient.nvim'


	-- Essential
    use 'tpope/vim-unimpaired'
    use {'junegunn/fzf', dir = '~/.fzf', run = './install --all' }
    use 'junegunn/fzf.vim'
    -- use 'nvim-lua/lsp-status.nvim'
	use { 'akinsho/bufferline.nvim', config = [[require('config.bufferline')]]}
	use {'airblade/vim-rooter', config= function()
		vim.cmd [[ let g:rooter_silent_chdir = 1
		let g:startify_change_to_dir = 0
		let g:rooter_change_directory_for_non_project_files = "current"
		let g:rooter_patterns = [".git", "Makefile", ".prjroot", ".hg"]
		]]
	end}
	use 'mhinz/vim-startify'

   -- Files
    use {
		'justinmk/vim-dirvish',
		config = [[require('config.dirvish')]]
	}
    use 'tpope/vim-eunuch'
    use 'kyazdani42/nvim-tree.lua'
    use 'kyazdani42/nvim-web-devicons'  -- for file icons

	-- Editing
	use 'tpope/vim-surround'              -- surround text objects with whatever
	use 'AndrewRadev/splitjoin.vim'
	use 'junegunn/vim-easy-align'         -- perform alignment easier
	use 'tpope/vim-repeat'
	use 'sgur/vim-editorconfig'
	use { 'lukas-reineke/indent-blankline.nvim', ft= {"python"}}
	use 'tpope/vim-commentary'          -- commenting plugin
	use 'kana/vim-textobj-user'
	use 'vim-scripts/BufOnly.vim'
	use 'machakann/vim-highlightedyank'
	use 'sbdchd/neoformat'
	use {
		'kkoomen/vim-doge',
		run = ':call doge#install()',
		ft = {"python"}
	} -- doc generat
    use 'ThePrimeagen/harpoon'

	-- Color Schemes
	use {'morhetz/gruvbox', config = function() vim.cmd [[ autocmd vimenter * ++nested colorscheme gruvbox ]] end}
	use 'arcticicestudio/nord-vim'
	use 'NLKNguyen/papercolor-theme'

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
		requires = {
			'nvim-treesitter/nvim-treesitter-textobjects',
			'nvim-treesitter/playground',
			'romgrk/nvim-treesitter-context',
		},
        config = [[require('config.treesitter')]],
		run = ':TSUpdate',
	}
	-- use {
	-- 	'SmiteshP/nvim-gps',
	-- 	requires = 'nvim-treesitter/nvim-treesitter',
	-- 	after = "nivm-treesitter"
	-- }
	use {
		'hoob3rt/lualine.nvim',
		config = [[require('config.lualine')]],
		-- requires = 'SmiteshP/nvim-gps',
	}
	-- Completion and linting
	use {
		'neovim/nvim-lspconfig',
		config = [[require('config.lsp')]],
	}

	use {
		'folke/lsp-colors.nvim',
		'onsails/lspkind-nvim',
	}

    use {
        'code-biscuits/nvim-biscuits',
        opt = true,
        config = [[
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
        ]],
        after = 'nvim-treesitter',
    }
    -- Completion
    ---- Snippets
    use { 'SirVer/ultisnips',
    config = function()
        vim.cmd 'let g:UltiSnipsExpandTrigger="<S-tab>"'
        vim.cmd 'let g:UltiSnipsJumpForwardTrigger="<Tab>"'
        vim.cmd 'let g:UltiSnipsJumpBackwardTrigger="<S-Tab>"'
        vim.cmd 'let g:UltiSnipsEditSplit="vertical"'
        vim.cmd 'let g:UltiSnipsNoPythonWarning = 1'
        vim.cmd 'let g:UltiSnipsSnippetDirectories=["mysnippets"]'
        vim.cmd 'noremap <silent> <Leader>ult :UltiSnipsEdit!<CR>2<CR>'
    end
}
    use 'honza/vim-snippets'
    use {
        'hrsh7th/nvim-cmp',
        requires = {
            {'hrsh7th/cmp-buffer', after = 'nvim-cmp'},
            {'quangnguyen30192/cmp-nvim-ultisnips', after = 'nvim-cmp'},
            'hrsh7th/cmp-nvim-lsp',
            {'hrsh7th/cmp-path', after = 'nvim-cmp'},
            {'octaltree/cmp-look', after = 'nvim-cmp'},
            {'hrsh7th/cmp-nvim-lua', after = 'nvim-cmp'},
            {'tjdevries/complextras.nvim', after = 'nvim-cmp'},
        },
        config = [[require('config.cmp')]],
        event = 'InsertEnter *',
    }
    -- Plug 'ervandew/supertab'

    ------ Org
    use {
        'kristijanhusak/orgmode.nvim',
        opt= true,
        config = [[require('config.org')]],
        ft = {"org"},
        requires = {
            {'akinsho/org-bullets.nvim', opt= true}
        }
    }
    -- Projects
    use 'tpope/vim-projectionist'


    -- -- IDE Like Featues
    use 'szw/vim-maximizer'
    use 'ggandor/lightspeed.nvim'
    use {'glacambre/firenvim', run = ':call firenvim#install(0)' }

    ---- Metaview
    use {'liuchengxu/vista.vim', cmd = "Vista"}
    use {'simrat39/symbols-outline.nvim', cmd = {"SymbolsOutline"}}

-- ---- REPL
-- Plug 'jpalardy/vim-slime'


    -- Git
    use 'rhysd/committia.vim'
    use 'airblade/vim-gitgutter'
    use 'tpope/vim-fugitive'
    use 'tpope/vim-rhubarb'
    use 'jreybert/vimagit'
    use 'junegunn/gv.vim'
    use 'rhysd/git-messenger.vim'
    use {
        'pwntester/octo.nvim',
        config = [[require('config.octo')]],
        cmd = {'Octo'}
    }

    -- Testing
    use 'vim-test/vim-test'
    use { 'tpope/vim-dispatch', cmd = { 'Dispatch', 'Make', 'Focus', 'Start' } }



-- ---- LSP
-- local fts = {"org", "python", "react", "typescript", "typescriptreact", "lua", "rust"}
-- Plug 'tjdevries/lsp_extensions.nvim'
-- Plug 'nvim-lua/completion-nvim'
-- -- Plug 'glepnir/lspsaga.nvim'



-- ---- Languages
-- ------ Writing/Markdown/Rst
    use 'dhruvasagar/vim-table-mode'
    use 'tpope/vim-abolish'
    use {
        'junegunn/goyo.vim',
        opt = true,
        requires = {
            'junegunn/limelight.vim'
        },
        cmd = "Goyo"
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
        ft = {"javascript", "react", "typescript", "typescriptreact"},
        cmd = {"Prettier"}
    }
    use {
        'mattn/emmet-vim',
        ft = {"javascript", "react", "typescript", "typescriptreact", "html"},
    }

-- ------ Python
-- Plug 'goerz/jupytext.vim'
-- Plug 'kalekundert/vim-coiled-snake'

-- ------ Rust
-- Plug 'rust-lang/rust.vim'

-- ------ Go
-- Plug('fatih/vim-go', {['for'] = {"go"}})

-- ------ Latex
-- Plug 'lervag/vimtex'
-- vim.cmd 'let g:tex_flavor = "latex"'




-- ------ Snakemake
-- Plug 'burneyy/vim-snakemake'


-- -- Plug 'luukvbaal/stabilize.nvim'
-- Plug 'folke/twilight.nvim'
-- -- Plug 'sunjon/shade.nvim'
-- Plug 'NFrid/due.nvim'

	-- Maintainence
	use { 'tweekmonster/startuptime.vim', opt = true, cmd = {'StartupTime'}}
end)


-- local Plug = vim.fn['plug#']

-- vim.call('plug#begin', '~/.config/nvim/plugged')


-- Plug('nvim-telescope/telescope.nvim', {['on'] = {'Telescope'}})
-- Plug 'nvim-telescope/telescope-fzy-native.nvim'
-- Plug('michaelb/sniprun', { ['do'] = 'bash install.sh 1', ['for'] = fts})

-- Plug('mrjones2014/dash.nvim', { ['do'] =  'make install', ['on'] = {'Dash'} })
-- -- Plug 'grepinsight/insight.nvim'

-- vim.call('plug#end')

-- Define maplocalleader

vim.cmd 'source ~/.dotfiles/vim/leaders.vim'
vim.cmd 'source ~/.dotfiles/vim/remaps.vim'
vim.cmd 'source ~/.dotfiles/vim/functions.vim'
vim.cmd 'source ~/.dotfiles/nvim/shortcuts.vim'
vim.cmd 'source ~/.dotfiles/nvim/autocmds.vim'
vim.cmd 'source ~/.dotfiles/vim/commands.vim'

if vim.fn.filereadable("~/.vimrc_work") then
    vim.cmd 'source ~/.vimrc_work'
end





vim.cmd 'let g:airline#extensions#tabline#enabled = 1'
vim.cmd "let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.6 } }"
