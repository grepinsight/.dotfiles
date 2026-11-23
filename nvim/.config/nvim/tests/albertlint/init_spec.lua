---Attachment behaviour. These exist because "it should turn on for markdown" was true for
---a file opened after setup and false for a buffer that was already open, and the second
---case is the one a lazy-loaded or re-sourced config hits.
local albertlint = require("albertlint")

---@return integer
local function markdown_buf(text)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })
  vim.bo[buf].filetype = "markdown"
  return buf
end

---@param buf integer
---@return integer
local function count(buf)
  return #vim.diagnostic.get(buf, { namespace = albertlint.namespace })
end

describe("albertlint attachment", function()
  before_each(function()
    albertlint.setup({})
  end)

  it("lints a markdown buffer that was already open when setup ran", function()
    -- The buffer has to be created while NO autocmds exist, or setting its filetype
    -- fires FileType and lints it, which is what made the first version of this test
    -- fail on its own precondition. Clearing the augroup reproduces the real scenario:
    -- a lazy-loaded or re-sourced setup arriving after the buffer already exists.
    vim.api.nvim_create_augroup("AlbertLint", { clear = true })
    local buf = markdown_buf("we should meet on slack today")
    assert.equals(0, count(buf), "precondition: no autocmds, so nothing has linted it")

    albertlint.setup({})
    vim.wait(300, function()
      return count(buf) > 0
    end)
    assert.is_true(count(buf) > 0, "startup sweep should have linted the open buffer")
  end)

  it("lints on FileType, which fires for a new buffer that was never read from disk", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "meet on slack" })
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = "markdown" -- fires FileType
    vim.wait(200, function()
      return count(buf) > 0
    end)
    assert.is_true(count(buf) > 0)
  end)

  it("ignores a filetype that is not configured", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "meet on slack" })
    vim.bo[buf].filetype = "python"
    albertlint.setup({})
    vim.wait(100, function()
      return false
    end)
    assert.equals(0, count(buf), "source files are not prose and must be left alone")
  end)

  it("toggle clears and restores", function()
    local buf = markdown_buf("meet on slack")
    vim.api.nvim_set_current_buf(buf)
    albertlint.lint_all(buf)
    assert.is_true(count(buf) > 0)
    albertlint.toggle(buf)
    assert.equals(0, count(buf))
    albertlint.toggle(buf)
    assert.is_true(count(buf) > 0)
  end)
end)

describe("albertlint reload", function()
  before_each(function()
    albertlint.setup({})
  end)

  it("clears the semantic and config modules, not only rules and engine", function()
    -- This exists because it did not, and the omission cost a debugging session: a change
    -- teaching semantic.lua to read config.semantic.scope could not be picked up by any
    -- command, so the loaded module kept its old behaviour while the option looked set.
    require("albertlint.semantic")
    require("albertlint.config")
    assert.is_not_nil(package.loaded["albertlint.semantic"])

    vim.cmd("AlbertLintReload")

    -- Reload re-requires config itself, so assert on semantic, which it only clears.
    assert.is_nil(package.loaded["albertlint.semantic"])
  end)

  it("keeps the options passed to setup across a reload", function()
    -- Reloading config resets `options` to the file defaults, which would silently discard
    -- whatever setup() was given. A reload must be a no-op for configuration.
    albertlint.setup({ semantic = { scope = "buffer" } })

    vim.cmd("AlbertLintReload")

    assert.equals("buffer", require("albertlint.config").get().semantic.scope)
  end)
end)
