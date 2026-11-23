---UI presence detection, used to keep interactive-only plugins out of scripted Neovim.
---
---Why this module exists: plugins that spawn a long-lived external process are a
---liability under `nvim --headless`. There is no human to accept a suggestion, but
---the child process is spawned anyway, and a script that exits a second later races
---Neovim's LSP teardown (`runtime/lua/vim/lsp.lua`, the VimLeavePre exit handler).
---The child is then reparented to launchd/init and never reaped.
---
---Measured on 2026-08-07: `avante.nvim` is specced `lazy = false` and lists
---`zbirenbaum/copilot.lua` as a dependency, so every headless invocation eagerly
---started Copilot's node language server. A single `nvim --headless -c 'qa!'` leaked
---one. They ignore SIGTERM (so Neovim's `sysobj:kill(15)` does not reap them), spin
---at 100-290% CPU, and grow past 2 GB RSS each. Six of them held 16.8 GB of an 18 GB
---machine and drove load average to 137.
---
---`nvim --embed` is NOT headless. Neovim opens the RPC channel and blocks until
---`nvim_ui_attach()`, only then sourcing init.lua, so by the time lazy.nvim evaluates
---plugin specs the UI list is already populated. Neovide, nvim-qt, and VSCode-neovim
---are all safe. `--headless` skips that wait and leaves the list empty.
---
---Known limitation: this reads "no UI attached right now", not "`--headless` was
---passed". A `nvim --headless --listen <addr>` server that a GUI attaches to later
---evaluates specs before the attach, so gated plugins stay off for that session.
---Start such servers without `--headless` if you want Copilot in them.
local M = {}

---True when Neovim is running without any attached UI (`--headless`, scripts, CI).
---@return boolean
function M.is_headless()
  return #vim.api.nvim_list_uis() == 0
end

---True when a real UI is attached. Use as a lazy.nvim `cond` for interactive-only plugins.
---@return boolean
function M.has_ui()
  return not M.is_headless()
end

return M
