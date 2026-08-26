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

vim.cmd("runtime plugin/plenary.vim")
