---Buffers Copilot must not attach to.
---
---Gating attachment rather than the ghost text: a client sends the whole buffer in
---`textDocument/didOpen`, so hiding suggestions would still ship a `.env` to GitHub.
local M = {}

local BLOCKED_FILETYPES = {
  markdown = true,
}

---Matched by name, since `.env.secret` gets no filetype to match on.
---@param name string
---@return boolean
local function is_env_file(name)
  return name == ".env" or name == ".envrc" or vim.startswith(name, ".env.")
end

---@param bufnr integer
---@return boolean
function M.is_blocked(bufnr)
  if BLOCKED_FILETYPES[vim.bo[bufnr].filetype] then
    return true
  end
  return is_env_file(vim.fs.basename(vim.api.nvim_buf_get_name(bufnr)))
end

return M
