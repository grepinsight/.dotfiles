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

describe("level timeout", function()
  it("gives a 190-line note more than the 105.6s it was measured to need", function()
    -- The exact failure a real session hit. 90s was shipped after timing 4-line samples;
    -- a 190-line note measured 105.6s on 2026-09-08 and was killed AFTER the model had
    -- already produced 74 findings. If this drops back under 105600, that recurs.
    assert.is_true(level._timeout_for(190) > 105600)
  end)

  it("floors a short selection rather than giving it a tight budget", function()
    -- Most of the cost is fixed overhead (~25s measured), so a 3-line selection needs
    -- nowhere near 3 lines' worth of time. The floor is 120s rather than 90s because the
    -- same 4-line input measured 22, 26, 35, 38 and 53s across runs, so a budget sized on
    -- the median clips a slow one -- and a timeout discards an answer already paid for.
    assert.equals(120000, level._timeout_for(3))
    assert.equals(120000, level._timeout_for(0))
  end)

  it("scales with the line count between the floor and the ceiling", function()
    assert.is_true(level._timeout_for(400) > level._timeout_for(200))
  end)

  it("refuses to wait more than ten minutes", function()
    -- A deliberate refusal, not a model limit: past this the right answer is a narrower
    -- scope, not a longer wait, and the timeout message says so.
    assert.equals(600000, level._timeout_for(100000))
  end)

  it("lets an explicit config value win over the scaling", function()
    config.setup({ level = { timeout_ms = 12345 } })

    assert.equals(12345, config.get().level.timeout_ms)

    config.setup({})
  end)

  it("defaults to nil, meaning scale it", function()
    config.setup({})

    assert.is_nil(config.get().level.timeout_ms)
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
    assert.is_true(config.get().level.enabled)
  end)

  it("allows more time than the semantic tier, because it sends more text", function()
    -- The level default is nil, meaning scaled, so compare the scaled value rather than
    -- the config field. Even the floor beats the semantic tier's fixed 60s.
    config.setup({})

    assert.is_true(level._timeout_for(1) > config.get().semantic.timeout_ms)
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

describe("level run reaches dispatch", function()
  -- THE gap that let a crash ship. Every other test in this file bails before the provider
  -- is called -- at the in-flight guard, the disabled check, an empty range, the cache, or
  -- an unimplemented level -- so nothing exercised the last stretch of run(), where the
  -- progress notify and the provider call live. A `local` declared below its own use in
  -- that stretch resolved to a nil global and `:AlbertLintLevel1` died with "attempt to
  -- perform arithmetic on global 'timeout_ms'" before reaching any provider. Reported from
  -- a real session 2026-09-08.
  --
  -- Stubbing provider.call is what makes this affordable: the whole path runs, nothing is
  -- spawned, and nothing is paid for.
  local provider = require("albertlint.level.provider")
  local real_call

  before_each(function()
    real_call = provider.call
    for _, tbl in ipairs({ level._in_flight, level._open_views, level._cache }) do
      for k in pairs(tbl) do
        tbl[k] = nil
      end
    end
  end)

  after_each(function()
    provider.call = real_call
    config.setup({})
  end)

  it("runs to the provider without erroring, and announces the real budget", function()
    local seen
    provider.call = function(name, prompt, text, opts, cb)
      seen = { name = name, prompt = prompt, text = text, opts = opts, cb = cb }
      return { kill = function() end }
    end
    local buf = prose_buf({ "a error here", "and a apple too" })

    local msgs = captured(function()
      level.run(1, false)
    end)

    assert.is_not_nil(seen, "provider.call was never reached")
    assert.equals("claude", seen.name)
    -- The scaled budget was computed and handed over, not left nil.
    assert.equals(level._timeout_for(2), seen.opts.timeout_ms)
    -- And the progress message states it, which is the line that crashed.
    assert.equals(1, #msgs)
    assert.is_true(msgs[1]:find("Allowing up to", 1, true) ~= nil)
    assert.is_true(msgs[1]:find(tostring(level._timeout_for(2) / 1000), 1, true) ~= nil)
    -- The guard is armed only once the call actually started.
    assert.is_not_nil(level._in_flight[buf])
  end)

  it("passes an explicit config timeout straight through", function()
    local seen
    provider.call = function(_, _, _, opts)
      seen = opts
      return { kill = function() end }
    end
    config.setup({ level = { timeout_ms = 45000 } })
    prose_buf({ "a error here" })

    captured(function()
      level.run(1, false)
    end)

    assert.equals(45000, seen.timeout_ms)
  end)

  it("sends the numbered payload, not the raw lines", function()
    local seen
    provider.call = function(_, _, text, _)
      seen = text
      return { kill = function() end }
    end
    prose_buf({ "first line", "second line" })

    captured(function()
      level.run(1, false)
    end)

    assert.equals("1: first line\n2: second line\n", seen)
  end)

  it("does not arm the guard when the provider refuses to start", function()
    -- provider.call returns nil when the CLI is missing or the key is unset. Recording
    -- that would wedge the buffer on a pass that never ran.
    provider.call = function(_, _, _, _, cb)
      cb({ ok = false, err = "`claude` is not on PATH" })
      return nil
    end
    local buf = prose_buf({ "a error here" })

    local msgs = captured(function()
      level.run(1, false)
    end)

    assert.is_nil(level._in_flight[buf])
    assert.is_true(#msgs >= 1)
  end)
end)

describe("level cache", function()
  before_each(function()
    for k in pairs(level._cache) do
      level._cache[k] = nil
    end
    for k in pairs(level._open_views) do
      level._open_views[k] = nil
    end
    for k in pairs(level._in_flight) do
      level._in_flight[k] = nil
    end
  end)

  it("serves a cached pass without calling the provider", function()
    -- A pass costs money and 30 to 90 seconds, so closing and reopening the diff must not
    -- pay for it twice. If this regresses, the diff becomes a call you think about rather
    -- than a panel you toggle.
    local buf = prose_buf({ "a error here", "second line" })
    level._cache[buf] = {
      [1] = {
        findings = {
          { line = 1, quote = "a error", occurrence = 1, replacement = "an error",
            label = "Article", note = "n" },
        },
        at = (vim.uv or vim.loop).hrtime(),
        provider = "claude",
      },
    }

    local msgs = captured(function()
      level.run(1, false)
    end)

    -- One message, and it is the cache-hit message, not the "~30-90s" one that precedes a
    -- real call.
    assert.equals(1, #msgs)
    assert.is_true(msgs[1]:find("from cache", 1, true) ~= nil)
    assert.is_nil(msgs[1]:find("30-90s", 1, true))
    -- And no pass was started.
    assert.is_nil(level._in_flight[buf])
    assert.is_not_nil(level._open_views[buf])

    level.close(buf)
  end)

  it("tells you how to force a fresh pass", function()
    local buf = prose_buf({ "a error here" })
    level._cache[buf] = { [1] = {
      findings = { { line = 1, quote = "a error", occurrence = 1, replacement = "an error", label = "A", note = "n" } },
      at = (vim.uv or vim.loop).hrtime(), provider = "claude",
    } }

    local msgs = captured(function()
      level.run(1, false)
    end)

    assert.is_true(msgs[1]:find("AlbertLintLevel1!", 1, true) ~= nil)
    level.close(buf)
  end)

  it("re-applies cached findings against the buffer as it is now", function()
    -- This is what makes the cache correct after a `do`: the accepted fix no longer matches
    -- its quote, so it drops out and the rest still place. Here the fix is pre-applied, so
    -- nothing should be left to show.
    local buf = prose_buf({ "an error here" })
    level._cache[buf] = { [1] = {
      findings = { { line = 1, quote = "a error", occurrence = 1, replacement = "an error", label = "A", note = "n" } },
      at = (vim.uv or vim.loop).hrtime(), provider = "claude",
    } }

    local msgs = captured(function()
      level.run(1, false)
    end)

    assert.is_true(msgs[1]:find("nothing left to apply", 1, true) ~= nil)
    assert.is_nil(level._open_views[buf])
  end)

  it("clear_cache drops the entry and reports whether there was one", function()
    local buf = prose_buf()
    level._cache[buf] = { [1] = { findings = {}, at = 0, provider = "claude" } }

    assert.is_true(level.clear_cache(buf))
    assert.is_nil(level._cache[buf])
    assert.is_false(level.clear_cache(buf))
  end)

  it("drops the cache when the buffer is deleted, because buffer numbers are reused", function()
    -- Without this a new buffer can inherit a dead buffer's findings and be shown a diff
    -- of somebody else's text.
    local buf = prose_buf()
    level._cache[buf] = { [1] = { findings = {}, at = 0, provider = "claude" } }

    vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, false))
    vim.api.nvim_buf_delete(buf, { force = true })

    assert.is_nil(level._cache[buf])
  end)
end)

describe("commands typed from the corrected side", function()
  -- The whole reason this block exists: every command here is naturally typed from
  -- whichever window you are looking at, and `close()` used to look up only
  -- `open_views[current_buf]`. Typed from the scratch buffer it found nothing and tore
  -- nothing down, leaving the real buffer in diff mode with a winbar on it. Verified
  -- 2026-09-08. The earlier diffview test missed it by calling diffview.close(state)
  -- directly and bypassing this lookup.
  local diffview = require("albertlint.level.diffview")

  before_each(function()
    for k in pairs(level._open_views) do
      level._open_views[k] = nil
    end
    for k in pairs(level._in_flight) do
      level._in_flight[k] = nil
    end
  end)

  ---@return integer source_buf, table state
  local function open_a_view()
    local buf = prose_buf({ "a error here", "second line" })
    local state = diffview.open(buf, { "an error here", "second line" }, {
      { lnum = 1, col = 0, fix = { label = "Article", note = "n" } },
    }, { level = 1 })
    level._open_views[buf] = state
    return buf, state
  end

  it("close tears down when typed from the scratch buffer", function()
    local buf, state = open_a_view()
    vim.api.nvim_set_current_win(state.scratch_win)
    assert.equals(state.scratch_buf, vim.api.nvim_get_current_buf())

    local ok = level.close()

    assert.is_true(ok)
    assert.is_nil(level._open_views[buf])
    assert.is_false(vim.wo[state.source_win].diff)
    assert.equals("", vim.wo[state.source_win].winbar)
  end)

  it("accept typed from the scratch side still moves text INTO the source", function()
    local buf, state = open_a_view()
    vim.api.nvim_set_current_win(state.scratch_win)
    vim.api.nvim_win_set_cursor(state.scratch_win, { 1, 0 })

    local ok = level.accept_line()

    local src = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
    level.close(buf)
    assert.is_true(ok)
    -- Not reverted to "a error here", which is what a naive `.,.diffget` in the scratch
    -- window would have produced.
    assert.equals("an error here", src)
  end)

  it("cancel typed from the scratch buffer finds the pass", function()
    local buf, state = open_a_view()
    level._in_flight[buf] = {
      handle = nil, started = (vim.uv or vim.loop).hrtime(), lines = 2, level = 1,
    }
    vim.api.nvim_set_current_win(state.scratch_win)

    local msgs = captured(function()
      assert.is_true(level.cancel())
    end)

    level.close(buf)
    assert.is_true(msgs[1]:find("cancelled", 1, true) ~= nil)
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
