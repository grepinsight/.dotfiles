---Obsidian vault location, resolved at call time instead of hardcoded.
---
---The vault root lives in `$OBSIDIAN_VAULT` (exported from
---`bash/local/bash_settings_local`, which is machine-local and untracked). This
---config is tracked, so it must not carry the path itself: a checkout on another
---machine or under another username would point at a directory that does not
---exist, and the `:Daily`-style commands would happily `mkdir` an empty vault
---there instead of failing.
---
---Resolution order:
---  1. `$OBSIDIAN_VAULT`      -- the documented name, set in bash_settings_local
---  2. `$OBSIDIAN_VAULT_PATH` -- older name, still set on some machines
---  3. `~/Thoughts`           -- last-resort default
---
---Neovim only inherits these when launched from a shell that sourced the dotfiles
---(GUI launchers may not), so step 3 is a real code path, not dead weight.
local M = {}

local DEFAULT_ROOT = "~/Thoughts"

---@param name string Environment variable name
---@return string|nil value Non-empty value, or nil when unset or blank
local function env(name)
  local value = vim.env[name]
  if value == nil or value == "" then
    return nil
  end
  return value
end

---Absolute path to the vault root, with `~`/`$VAR` expanded and no trailing slash.
---@return string
function M.root()
  return vim.fs.normalize(env("OBSIDIAN_VAULT") or env("OBSIDIAN_VAULT_PATH") or DEFAULT_ROOT)
end

---Join path segments onto the vault root.
---@param ... string Segments relative to the vault root (e.g. "02-Calendar/Daily", "2026-08-07.md")
---@return string
function M.path(...)
  return vim.fs.joinpath(M.root(), ...)
end

return M
