---The runner's own logic: payload construction, the in-flight guard, and config wiring.
---
---The network call itself is not tested here. `provider` covers argv and parsing, and a
---headless test must not spend money. What is tested is everything around it, including the
---in-flight guard, which exists because without one a second invocation spawns a second CLI
---process: two paid calls and two sets of results racing to overwrite each other with no way
---to tell. That failure already happened once in the semantic tier.
local config = require("albertlint.config")
local level = require("albertlint.level")

---Capture vim.notify for the duration of a call.
---@param fn function
---@return string[]
local function captured(fn)
  local msgs = {}
  local orig = vim.notify
  vim.notify = function(msg)
    table.insert(msgs, tostring(msg))
  end
  local ok, err = pcall(fn)
  vim.notify = orig
  if not ok then
    error(err)
  end
  return msgs
end

---@param lines string[]|nil
---@return integer
local function prose_buf(lines)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or { "a error here" })
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_win_set_buf(0, buf)
  return buf
end

describe("level payload", function()
  it("numbers lines with absolute buffer line numbers", function()
    -- Absolute, so the model's answer needs no offset arithmetic and a fix from a
    -- selection-scoped pass still points at the right buffer line.
    assert.equals("41: first\n42: second\n", level._numbered({ "first", "second" }, 41))
  end)

  it("handles an empty range without erroring", function()
    assert.equals("", level._numbered({}, 1))
  end)

  it("preserves a blank line rather than collapsing it", function()
    -- Paragraph structure matters to the model's judgment about a known referent, so a
    -- blank line has to survive into the payload.
    assert.equals("1: a\n2: \n3: b\n", level._numbered({ "a", "", "b" }, 1))
  end)
end)

describe("level config", function()
  after_each(function()
    config.setup({})
  end)

  it("defaults to the claude provider and buffer scope", function()
    config.setup({})

    local opts = config.get().level
    assert.equals("claude", opts.provider)
    -- A two-window diff over a single paragraph is not worth the split.
    assert.equals("buffer", opts.scope)
    assert.is_true(opts.enabled)
  end)

  it("lets the provider be overridden without wiping its siblings", function()
    -- tbl_deep_extend merges maps, so a partial override must keep the other defaults.
    config.setup({ level = { provider = "openai" } })

    assert.equals("openai", config.get().level.provider)
    assert.equals("buffer", config.get().level.scope)
    assert.is_true(config.get().level.timeout_ms > 0)
  end)

  it("allows a longer timeout than the semantic tier, because it sends more text", function()
    config.setup({})

    assert.is_true(config.get().level.timeout_ms >= config.get().semantic.timeout_ms)
  end)
end)

describe("level in-flight guard", function()
  before_each(function()
    for k in pairs(level._in_flight) do
      level._in_flight[k] = nil
    end
  end)

  it("refuses a second pass on the same buffer and reports progress", function()
    local buf = prose_buf()
    level._in_flight[buf] = {
      handle = nil,
      started = (vim.uv or vim.loop).hrtime(),
      lines = 1,
      level = 1,
    }

    local msgs = captured(function()
      level.run(1, false)
    end)

    assert.equals(1, #msgs)
    assert.is_true(msgs[1]:find("already running", 1, true) ~= nil)
    -- The refusal doubles as the liveness signal, so it must name the elapsed time.
    assert.is_true(msgs[1]:find("elapsed", 1, true) ~= nil)
  end)

  it("reports an unimplemented level rather than calling out", function()
    local buf = prose_buf()

    local msgs = captured(function()
      level.run(3, false)
    end)

    assert.equals(1, #msgs)
    assert.is_true(msgs[1]:find("level 3", 1, true) ~= nil)
    assert.is_nil(level._in_flight[buf])
  end)

  it("does nothing when the tier is disabled", function()
    prose_buf()
    config.setup({ level = { enabled = false } })

    local msgs = captured(function()
      level.run(1, false)
    end)

    config.setup({})
    assert.equals(1, #msgs)
    assert.is_true(msgs[1]:find("disabled", 1, true) ~= nil)
  end)

  it("refuses an empty range instead of sending an empty payload", function()
    local buf = prose_buf({ "" })
    config.setup({ level = { scope = "buffer" } })

    local msgs = captured(function()
      level.run(1, false)
    end)

    config.setup({})
    assert.equals(1, #msgs)
    assert.is_true(msgs[1]:find("nothing to review", 1, true) ~= nil)
    assert.is_nil(level._in_flight[buf])
  end)
end)

describe("level cancel and close", function()
  before_each(function()
    for k in pairs(level._in_flight) do
      level._in_flight[k] = nil
    end
    for k in pairs(level._open_views) do
      level._open_views[k] = nil
    end
  end)

  it("says so when there is no diff open", function()
    local buf = prose_buf()

    local msgs = captured(function()
      assert.is_false(level.close(buf))
    end)

    assert.is_true(msgs[1]:find("no level diff", 1, true) ~= nil)
  end)

  it("says so when there is no pass running", function()
    local buf = prose_buf()

    local msgs = captured(function()
      assert.is_false(level.cancel(buf))
    end)

    assert.is_true(msgs[1]:find("no level pass", 1, true) ~= nil)
  end)

  it("refuses a line-scoped accept when no diff is open", function()
    local buf = prose_buf()

    local msgs = captured(function()
      assert.is_false(level.accept_line(buf))
      assert.is_false(level.reject_line(buf))
    end)

    assert.equals(2, #msgs)
    assert.is_true(msgs[1]:find("no level diff", 1, true) ~= nil)
  end)

  it("cancels a running pass without requiring a live handle", function()
    -- The handle is nil when the provider refused to start. Cancel must still clear the
    -- report rather than erroring, or a failed start wedges the buffer.
    local buf = prose_buf()
    level._in_flight[buf] = {
      handle = nil,
      started = (vim.uv or vim.loop).hrtime(),
      lines = 3,
      level = 1,
    }

    local msgs = captured(function()
      assert.is_true(level.cancel(buf))
    end)

    assert.is_true(msgs[1]:find("cancelled", 1, true) ~= nil)
  end)
end)
