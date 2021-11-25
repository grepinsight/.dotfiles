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

local Plug = vim.fn['plug#']

vim.call('plug#begin', '~/.config/nvim/plugged')

-- Essential
--Plug 'grepinsight/ctrlp.vim' -- my mutated version that supports vimwiki tag search
Plug 'tpope/vim-unimpaired'
Plug('junegunn/fzf', { dir = '~/.fzf', ['do'] = './install --all'  })
Plug 'junegunn/fzf.vim'
-- Plug 'vim-airline/vim-airline'
Plug 'hoob3rt/lualine.nvim'
Plug 'nvim-lua/lsp-status.nvim'
Plug 'akinsho/bufferline.nvim'
Plug 'airblade/vim-rooter'
Plug 'mhinz/vim-startify'

Plug('nvim-telescope/telescope.nvim', {['on'] = {'Telescope'}})
Plug 'nvim-telescope/telescope-fzy-native.nvim'

-- Colorschemes
Plug 'morhetz/gruvbox'
Plug 'arcticicestudio/nord-vim'
Plug 'NLKNguyen/papercolor-theme'
vim.cmd [[
  autocmd vimenter * ++nested colorscheme gruvbox
]]


-- Maintainence
Plug 'tweekmonster/startuptime.vim'


-- Files
Plug 'tpope/vim-eunuch'       -- unix's Mkdir, Delete, etc.
Plug('justinmk/vim-dirvish')
Plug('kyazdani42/nvim-tree.lua', {commit= '7c88a0f8ee6250a8408c28e0b03a4925b396c916'})      -- tree
Plug 'kyazdani42/nvim-web-devicons'  -- for file icons
Plug 'nanotee/zoxide.vim'


-- IDE Like Featues
-- Viewport
Plug 'szw/vim-maximizer'
Plug 'ggandor/lightspeed.nvim'
Plug('glacambre/firenvim', { ['do'] = ':call firenvim#install(0)' })

---- Metaview
Plug 'liuchengxu/vista.vim'
Plug('simrat39/symbols-outline.nvim', {['on'] = {"SymbolsOutline"}})

---- Projects
Plug 'tpope/vim-projectionist'
---- REPL
Plug 'jpalardy/vim-slime'


-- Git
Plug 'rhysd/committia.vim'
Plug 'airblade/vim-gitgutter'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-rhubarb'
Plug 'jreybert/vimagit'
Plug 'junegunn/gv.vim'
Plug 'rhysd/git-messenger.vim'
-- Plug('ThePrimeagen/git-worktree.nvim')
Plug('Juksuu/git-worktree.nvim', {['commit']="a50af35f923868deb728f9fcb668b85539926b42"})
Plug('pwntester/octo.nvim', {['on']= {'Octo'} })

-- Testing
Plug 'vim-test/vim-test'
Plug 'tpope/vim-dispatch'

-- Editing
Plug 'tpope/vim-surround'              -- surround text objects with whatever
Plug 'AndrewRadev/splitjoin.vim'
Plug 'junegunn/vim-easy-align'         -- perform alignment easier
Plug 'tpope/vim-repeat'
Plug 'sgur/vim-editorconfig'
-- Plug 'Yggdroot/indentLine'
Plug('lukas-reineke/indent-blankline.nvim', {['for'] = {"python"}})
Plug 'tpope/vim-commentary'          -- commenting plugin
Plug 'kana/vim-textobj-user'
Plug 'vim-scripts/BufOnly.vim'
Plug 'machakann/vim-highlightedyank'
Plug 'sbdchd/neoformat'
Plug('kkoomen/vim-doge', { ['do'] = ':call doge#install()', ['for'] = {"python"} })  -- doc generator

---- Snippets
Plug 'SirVer/ultisnips'
Plug 'honza/vim-snippets'

---- LSP
local fts = {"python", "react", "typescript", "typescriptreact", "lua", "rust"}
Plug('neovim/nvim-lspconfig' , {['for'] = fts})
Plug 'tjdevries/lsp_extensions.nvim'
Plug 'nvim-lua/completion-nvim'
Plug 'onsails/lspkind-nvim'
Plug 'folke/lsp-colors.nvim'

Plug('nvim-treesitter/nvim-treesitter' , {['for'] = fts })
Plug('SmiteshP/nvim-gps',{['for'] = fts})
Plug('nvim-treesitter/nvim-treesitter-textobjects', {['for'] = fts})

Plug('nvim-treesitter/playground' , {['for'] = fts})
Plug('code-biscuits/nvim-biscuits', {['for'] = fts}) -- in-editor annotations usually at the end of a closing tag/bracket/parenthesis/etc.
Plug('romgrk/nvim-treesitter-context', {['for'] = fts})
-- Plug 'glepnir/lspsaga.nvim'

--- Completion
local cmp_fts =  {"python", "lua"}
Plug('hrsh7th/nvim-cmp', {['for'] = cmp_fts})
Plug('hrsh7th/cmp-nvim-lsp', {['for'] = cmp_fts})
Plug('hrsh7th/cmp-buffer', {['for'] = cmp_fts})
Plug('hrsh7th/cmp-path', {['for'] = cmp_fts})
Plug('octaltree/cmp-look', {['for'] = cmp_fts})
Plug('hrsh7th/cmp-nvim-lua', {['for'] = cmp_fts})
Plug('quangnguyen30192/cmp-nvim-ultisnips', {['for'] = cmp_fts})
Plug 'tjdevries/complextras.nvim'
Plug 'ervandew/supertab'

Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'ThePrimeagen/harpoon'

---- Languages
------ Writing/Markdown/Rst
Plug 'dhruvasagar/vim-table-mode'
Plug 'tpope/vim-abolish'
Plug 'junegunn/goyo.vim'
Plug 'junegunn/limelight.vim'

------ Javascript
Plug 'maxmellon/vim-jsx-pretty'
Plug 'pangloss/vim-javascript'
Plug('prettier/vim-prettier', {['on'] = {"Prettier"}} )
Plug 'mattn/emmet-vim'

------ Python
Plug 'goerz/jupytext.vim'
Plug 'kalekundert/vim-coiled-snake'

------ Rust
Plug 'rust-lang/rust.vim'

------ Go
Plug('fatih/vim-go', {['for'] = {"go"}})

------ Latex
Plug 'lervag/vimtex'
vim.cmd 'let g:tex_flavor = "latex"'


------ Org
-- Plug 'axvr/org.vim'
Plug('kristijanhusak/orgmode.nvim', {['for'] = {"org"}})
Plug('akinsho/org-bullets.nvim', {['for'] = {"org"}})


------ Snakemake
Plug 'burneyy/vim-snakemake'


-- Plug 'luukvbaal/stabilize.nvim'
Plug 'folke/twilight.nvim'
-- Plug 'sunjon/shade.nvim'
Plug 'NFrid/due.nvim'
Plug('michaelb/sniprun', { ['do'] = 'bash install.sh 1', ['for'] = fts})

Plug('mrjones2014/dash.nvim', { ['do'] =  'make install', ['on'] = {'Dash'} })
-- Plug 'grepinsight/insight.nvim'

vim.call('plug#end')

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

