-- Minimal init for plenary.busted runs: only this config's lua/ and plenary itself.
-- Deliberately does not load plugins.lua; see lua/util/headless.lua for why headless
-- Neovim must stay away from plugins that spawn long-lived external processes.
local here = debug.getinfo(1, "S").source:sub(2)
local config_root = vim.fn.fnamemodify(here, ":p:h:h")
local plenary = os.getenv("PLENARY_DIR")
  or vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim")

vim.opt.runtimepath:append(config_root)
vim.opt.runtimepath:append(plenary)
vim.opt.swapfile = false

-- The config root has to be on the runtimepath for `require("annotate...")` to resolve,
-- which also drags in ftplugin/. Those are not under test and some of them call commands
-- that only exist once plugins are loaded (ftplugin/python.vim runs
-- :UpdateRemotePlugins), so opening such a file under --clean would error out of an
-- unrelated test. Keep the harness actually minimal.
vim.cmd("filetype plugin indent off")

vim.cmd("runtime plugin/plenary.vim")
