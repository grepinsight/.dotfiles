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
vim.opt.conceallevel   = 0
vim.opt.scrolloff      = 2         -- Minimal number of screen lines to keep above and below the cursor.
-- vim.opt.iskeyword      =
vim.opt.background     = 'dark'   -- Setting dark mode
vim.opt.undofile       = true      -- Save undos after file closes
-- vim.opt.undodir        = "$HOME/.vim/undo"  --where to save undo histories
vim.opt.undolevels     = 10000         -- How many undos
vim.opt.undoreload     = 10000        --number of lines to save for undo
vim.opt.mouse          = 'a'
vim.opt.termguicolors  = true

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

Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-telescope/telescope-fzy-native.nvim'

-- Colorschemes
Plug 'morhetz/gruvbox'
vim.cmd [[
  autocmd vimenter * ++nested colorscheme gruvbox
]]

-- Maintainence
Plug 'tweekmonster/startuptime.vim'


-- Files
Plug 'tpope/vim-eunuch'       -- unix's Mkdir, Delete, etc.
Plug 'justinmk/vim-dirvish'
Plug('kyazdani42/nvim-tree.lua', {commit= '7c88a0f8ee6250a8408c28e0b03a4925b396c916'})      -- tree
Plug 'kyazdani42/nvim-web-devicons'  -- for file icons
Plug 'nanotee/zoxide.vim'


-- IDE Like Featues
-- Viewport
Plug 'szw/vim-maximizer'
Plug 'ggandor/lightspeed.nvim'


---- Metaview
Plug 'liuchengxu/vista.vim'
Plug 'simrat39/symbols-outline.nvim'

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

-- Testing
Plug 'vim-test/vim-test'
Plug 'tpope/vim-dispatch'

-- Editing
Plug 'tpope/vim-surround'              -- surround text objects with whatever
Plug 'AndrewRadev/splitjoin.vim'
Plug 'junegunn/vim-easy-align'         -- perform alignment easier
Plug 'tpope/vim-repeat'
Plug 'sgur/vim-editorconfig'
Plug 'Yggdroot/indentLine'
Plug 'tpope/vim-commentary'          -- commenting plugin
Plug 'kana/vim-textobj-user'
Plug 'vim-scripts/BufOnly.vim'
Plug 'machakann/vim-highlightedyank'
Plug 'sbdchd/neoformat'
Plug('kkoomen/vim-doge', { ['do'] = ':call doge#install()' })  -- doc generator

---- Snippets
Plug 'SirVer/ultisnips'
Plug 'honza/vim-snippets'

---- LSP
Plug 'neovim/nvim-lspconfig'
Plug 'tjdevries/lsp_extensions.nvim'
Plug 'nvim-lua/completion-nvim'
Plug 'onsails/lspkind-nvim'
Plug 'folke/lsp-colors.nvim'

Plug 'nvim-treesitter/nvim-treesitter'
Plug 'SmiteshP/nvim-gps'
Plug 'nvim-treesitter/nvim-treesitter-textobjects'

Plug 'nvim-treesitter/playground'
-- Plug 'glepnir/lspsaga.nvim'

--- Completion
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'octaltree/cmp-look'
Plug 'hrsh7th/cmp-nvim-lua'
Plug 'quangnguyen30192/cmp-nvim-ultisnips'
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
Plug 'prettier/vim-prettier'
Plug 'mattn/emmet-vim'

------ Python
Plug 'goerz/jupytext.vim'
Plug 'kalekundert/vim-coiled-snake'

------ Rust
Plug 'rust-lang/rust.vim'

------ Go
Plug 'fatih/vim-go'

------ Latex
Plug 'lervag/vimtex'
vim.cmd 'let g:tex_flavor = "latex"'

------ Org
-- Plug 'axvr/org.vim'
Plug 'kristijanhusak/orgmode.nvim'
Plug 'akinsho/org-bullets.nvim'


------ Snakemake
Plug 'burneyy/vim-snakemake'


vim.call('plug#end')

-- Define maplocalleader

vim.cmd 'source ~/.dotfiles/vim/leaders.vim'
vim.cmd 'source ~/.dotfiles/vim/remaps.vim'
vim.cmd 'source ~/.dotfiles/vim/functions.vim'
vim.cmd 'source ~/.dotfiles/nvim/shortcuts.vim'
vim.cmd 'source ~/.dotfiles/nvim/autocmds.vim'
vim.cmd 'source ~/.dotfiles/vim/commands.vim'




vim.cmd 'let g:airline#extensions#tabline#enabled = 1'
vim.cmd "let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.6 } }"

-- local saga = require 'lspsaga'
-- saga.init_lsp_saga()

-- add your config value here
-- default value
-- use_saga_diagnostic_sign = true
-- error_sign = '',
-- warn_sign = '',
-- hint_sign = '',
-- infor_sign = '',
-- dianostic_header_icon = '   ',
-- code_action_icon = ' ',
-- code_action_prompt = {
--   enable = true,
--   sign = true,
--   sign_priority = 20,
--   virtual_text = true,
-- },
-- finder_definition_icon = '  ',
-- finder_reference_icon = '  ',
-- max_preview_lines = 10, -- preview lines of lsp_finder and definition preview
-- finder_action_keys = {
--   open = 'o', vsplit = 's',split = 'i',quit = 'q',scroll_down = '<C-f>', scroll_up = '<C-b>' -- quit can be a table
-- },
-- code_action_keys = {
--   quit = 'q',exec = '<CR>'
-- },
-- rename_action_keys = {
--   quit = '<C-c>',exec = '<CR>'  -- quit can be a table
-- },
-- definition_preview_icon = '  '
-- "single" "double" "round" "plus"
-- border_style = "single"
-- rename_prompt_prefix = '➤',
-- if you don't use nvim-lspconfig you must pass your server name and
-- the related filetypes into this table
-- like server_filetype_map = {metals = {'sbt', 'scala'}}
-- server_filetype_map = {}

-- saga.init_lsp_saga {
--   your custom option here
-- }
--
-- or --use default config
--
--

-- require'nvim-treesitter.configs'.setup {
--   playground = {
--     enable = true,
--     disable = {},
--     updatetime = 25, -- Debounced time for highlighting nodes in the playground from source code
--     persist_queries = false, -- Whether the query persists across vim sessions
--     keybindings = {
--       toggle_query_editor = 'o',
--       toggle_hl_groups = 'i',
--       toggle_injected_languages = 't',
--       toggle_anonymous_nodes = 'a',
--       toggle_language_display = 'I',
--       focus_language = 'f',
--       unfocus_language = 'F',
--       update = 'R',
--       goto_node = '<cr>',
--       show_help = '?',
--     },
--   },
--   textobjects = {
--     lsp_interop = {
--       enable = true,
--       border = 'none',
--       peek_definition_code = {
--         ["<leader>df"] = "@function.outer",
--         ["<leader>dF"] = "@class.outer",
--       },
--     },
--     swap = {
--       enable = true,
--       swap_next = {
--         [",,n"] = "@parameter.inner",
--       },
--       swap_previous = {
--         [",,p"] = "@parameter.inner",
--       },
--     },
--     select = {
--       enable = true,

--       -- Automatically jump forward to textobj, similar to targets.vim
--       lookahead = true,

--       keymaps = {
--         -- You can use the capture groups defined in textobjects.scm
--         ["af"] = "@function.outer",
--         ["if"] = "@function.inner",
--         ["ac"] = "@class.outer",
--         ["ic"] = "@class.inner",

--         -- Or you can define your own textobjects like this
--         ["iF"] = {
--           python = "(function_definition) @function",
--           cpp = "(function_definition) @function",
--           c = "(function_definition) @function",
--           java = "(method_declaration) @function",
--         },
--       },
--     },
--   },
-- }

