-- Filetype using lua only
vim.g.maplocalleader = " "
-- Map \ as leader key

-- vim.g.do_filetype_lua = 0
-- vim.g.did_load_filetypes = 0

vim.g.editorconfig = true
vim.opt.autoread = true   -- automatically read changed file again
vim.opt.autowrite = true  -- Write the contents of the file, if it has been modified
vim.opt.cursorline = true --highlight current line
vim.opt.showmatch = true  -- highlight matching [{()}]
vim.opt.foldenable = false
-- vim.opt.foldenable     = true         -- enable folding
vim.opt.foldlevelstart = 10 --open most folds by default
vim.opt.splitright = true   -- split to the right
vim.opt.splitbelow = true   -- split below
vim.opt.hidden = true       -- allow modified/unsaved buffers in the background.
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.smartcase = true  -- if capital letter is used, then do not ignore case
vim.opt.ignorecase = true -- If the 'ignorecase' option is on, the case of normal letters is ignored.
vim.opt.shiftwidth = 4    -- size of an indent
vim.opt.softtabstop = 4   -- Indentation levels very four columns"
vim.opt.tabstop = 4       -- size of a hard tabstop number of visual spaces per TAB
vim.opt.incsearch = true  -- search as characters are entered
vim.opt.hlsearch = true   -- highlight matches
vim.opt.wildmenu = true
vim.opt.swapfile = false
vim.opt.conceallevel = 2
vim.opt.scrolloff = 2       -- Minimal number of screen lines to keep above and below the cursor.
-- vim.opt.iskeyword      =
vim.opt.background = "dark" -- Setting dark mode
vim.opt.undofile = true     -- Save undos after file closes
-- vim.opt.undodir        = "$HOME/.vim/undo"  --where to save undo histories
vim.opt.undolevels = 10000  -- How many undos
vim.opt.undoreload = 10000  --number of lines to save for undo
vim.opt.mouse = "a"
vim.opt.termguicolors = true
vim.cmd([[
"set list
set showbreak=↪\
set listchars=tab:→\ ,eol:↲,nbsp:␣,trail:•,extends:⟩,precedes:⟨
]])

-- Packages

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
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

require("lazy").setup({
	-- {
	--     "LazyVim/LazyVim",
	--     import = "lazyvim.plugins",
	-- },
	-- { import = "lazyvim.plugins.extras.ui.edgy" },
	-- { import = "lazyvim.plugins.extras.editor.flash" },
	{ import = "plugins" },
}, {
	defaults = { lazy = true },
	install = { colorscheme = { "tokyonight" } },
	checker = { enabled = false },
	performance = {
		rtp = {
			disabled_plugins = {
				"gzip",
				"matchit",
				"matchparen",
				"netrwPlugin",
				"tarPlugin",
				"tohtml",
				"tutor",
				"zipPlugin",
			},
		},
	},
	-- debug = true,
})

vim.cmd("source ~/.dotfiles/vim/leaders.vim")
vim.cmd("source ~/.dotfiles/vim/remaps.vim")
vim.cmd("source ~/.dotfiles/vim/functions.vim")
vim.cmd("source ~/.config/nvim/autocmds.vim")
vim.cmd("source ~/.dotfiles/vim/commands.vim")

local vimrc_work = vim.fn.expand("~/.vimrc_work")
if vim.fn.filereadable(vimrc_work) == 1 then
	vim.cmd("source " .. vimrc_work)
end

vim.cmd("let g:airline#extensions#tabline#enabled = 1")
vim.cmd("let g:fzf_layout = { 'window': { 'width': 0.9, 'height': 0.6 } }")

require("config.globals")
require("config.keymaps")


-- Define a function to call the Lua script
function SuggestAccounts()
	local transaction_description = vim.fn.input("Enter transaction description: ")
	local script_path = "/Users/allee/scratch/2024-11-04--lua-hledger/mapper.lua"
	local command = string.format("lua %s %q", script_path, transaction_description)
	os.execute(command)
end

-- Create a Neovim command to trigger the function
vim.api.nvim_create_user_command('SuggestAccounts', SuggestAccounts, {})

