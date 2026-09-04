local gate = require("plugins.lsp.copilot_gate")

---@param name string Full path, or "" for an unnamed buffer.
---@param filetype string
---@return integer bufnr
local function buffer(name, filetype)
  local bufnr = vim.api.nvim_create_buf(false, true)
  if name ~= "" then
    vim.api.nvim_buf_set_name(bufnr, name)
  end
  vim.bo[bufnr].filetype = filetype
  return bufnr
end

describe("plugins.lsp.copilot_gate.is_blocked", function()
  it("blocks markdown", function()
    assert.is_true(gate.is_blocked(buffer("/tmp/vault/note.md", "markdown")))
  end)

  it("blocks .env whatever filetype detection made of it", function()
    assert.is_true(gate.is_blocked(buffer("/tmp/project/.env", "sh")))
  end)

  it("blocks .env.secret", function()
    assert.is_true(gate.is_blocked(buffer("/tmp/project/.env.secret", "")))
  end)

  it("blocks any other .env.* variant", function()
    assert.is_true(gate.is_blocked(buffer("/tmp/project/.env.local", "")))
  end)

  it("blocks .envrc", function()
    assert.is_true(gate.is_blocked(buffer("/tmp/project/.envrc", "envrc")))
  end)

  it("allows a python file", function()
    assert.is_false(gate.is_blocked(buffer("/tmp/project/main.py", "python")))
  end)

  it("allows a name that merely starts with env", function()
    assert.is_false(gate.is_blocked(buffer("/tmp/project/environment.py", "python")))
  end)

  it("allows a dotfile sharing the .env prefix without the separator", function()
    assert.is_false(gate.is_blocked(buffer("/tmp/project/.envoy.yaml", "yaml")))
  end)

  it("allows an unnamed buffer, where basename is empty", function()
    assert.is_false(gate.is_blocked(buffer("", "lua")))
  end)
end)
