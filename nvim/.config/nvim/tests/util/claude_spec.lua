local claude = require("util.claude")

-- Multiline on purpose: a canned prompt is a paragraph, and `split_context` peels
-- tokens off the front of it. A single-line fixture would not catch a regression
-- there, because Lua's `.` matches newlines and the bug would only show on wrap.
local BASE = "Analyze the English in the selection.\n\nReturn the five tables below."

describe("util.claude.merge_prompt", function()
  it("uses the canned prompt verbatim when the command got no args", function()
    assert.equals(BASE, claude.merge_prompt(BASE, ""))
  end)

  it("keeps a leading +full ahead of the prompt, where split_context can see it", function()
    assert.equals("+full " .. BASE, claude.merge_prompt(BASE, "+full"))
  end)

  it("keeps a leading +N ahead of the prompt", function()
    assert.equals("+120 " .. BASE, claude.merge_prompt(BASE, "+120"))
  end)

  it("keeps +0 ahead of the prompt, so a caller can ask for no context", function()
    assert.equals("+0 " .. BASE, claude.merge_prompt(BASE, "+0"))
  end)

  it("appends extra words as a focus note rather than replacing the prompt", function()
    local merged = claude.merge_prompt(BASE, "just the verbs")
    assert.equals(1, merged:find(BASE, 1, true))
    assert.truthy(merged:find("just the verbs", 1, true))
  end)

  it("carries a context token and a focus note at once", function()
    local merged = claude.merge_prompt(BASE, "+full just the verbs")
    assert.equals("+full ", merged:sub(1, 6))
    assert.truthy(merged:find(BASE, 1, true))
    assert.truthy(merged:find("just the verbs", 1, true))
  end)

  it("ignores a token that only looks like a context token", function()
    -- `+opus` is not a context token, so it is the caller's own words and belongs
    -- in the focus note, not in front of the prompt where split_context would
    -- silently swallow it.
    local merged = claude.merge_prompt(BASE, "+opus")
    assert.equals(1, merged:find(BASE, 1, true))
    assert.truthy(merged:find("+opus", 1, true))
  end)
end)

describe("util.claude.with_prompt", function()
  -- Silenced for the whole block rather than per test: claude.lua defers its
  -- "done" notify through vim.schedule, so it can fire after an after_each would
  -- have put the real one back. PlenaryBustedDirectory runs each spec file in its
  -- own Neovim, so a permanent stub cannot leak into another file.
  --
  -- Do NOT stub vim.schedule to make that deferral synchronous. plenary's own
  -- runner schedules through it, and replacing it corrupted the runner: this
  -- block reported 15/15 green on a tree where one test must fail, and produced
  -- one spurious failure in seven runs.
  vim.notify = function() end

  local sent
  local spawned
  local saved

  before_each(function()
    sent = {}
    spawned = nil
    saved = {
      executable = vim.fn.executable,
      jobstart = vim.fn.jobstart,
      chansend = vim.fn.chansend,
      chanclose = vim.fn.chanclose,
    }

    vim.fn.executable = function()
      return 1
    end
    -- Finish the job inline. Left running, four calls would hit MAX_IN_FLIGHT and
    -- every later test in this block would silently bail.
    vim.fn.jobstart = function(cmd, opts)
      spawned = cmd
      opts.on_exit(42, 0)
      return 42
    end
    vim.fn.chansend = function(_, data)
      table.insert(sent, data)
    end
    vim.fn.chanclose = function() end
  end)

  after_each(function()
    vim.fn.executable = saved.executable
    vim.fn.jobstart = saved.jobstart
    vim.fn.chansend = saved.chansend
    vim.fn.chanclose = saved.chanclose
  end)

  ---Run the wrapped command over a 100-line scratch buffer and return the payload
  ---that reached the CLI's stdin. 100 lines so the default 40-line context is
  ---distinguishable from `+full`.
  ---@param args string
  ---@param cfg table|nil
  ---@return string
  local function run(args, cfg)
    sent = {}
    local lines = {}
    for i = 1, 100 do
      lines[i] = "line " .. i
    end
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_set_current_buf(bufnr)

    claude.with_prompt(BASE, cfg)({ args = args, line1 = 50, line2 = 51 })
    return table.concat(sent, "\n")
  end

  it("puts the canned prompt at the top of the payload", function()
    local payload = run("")
    assert.equals(1, payload:find(BASE, 1, true))
  end)

  it("sends the selected lines, not just the prompt", function()
    local payload = run("")
    assert.truthy(payload:find("line 50", 1, true))
    assert.truthy(payload:find("line 51", 1, true))
  end)

  it("never opens the input prompt, since the prompt is already known", function()
    local asked = false
    local saved_input = vim.ui.input
    vim.ui.input = function()
      asked = true
    end
    run("")
    vim.ui.input = saved_input
    assert.is_false(asked)
  end)

  it("still honours +full, so the analysis can see the whole buffer", function()
    assert.truthy(run(""):find("lines 10%-49"))
    assert.truthy(run("+full"):find("lines 1%-49"))
  end)

  it("forwards cfg to M.ask, so a canned prompt can run raw", function()
    run("", { raw = true })
    assert.truthy(vim.tbl_contains(spawned, "--safe-mode"))
    assert.truthy(vim.tbl_contains(spawned, "--disable-slash-commands"))
  end)

  it("leaves the command unrestricted when cfg is omitted", function()
    run("")
    assert.is_false(vim.tbl_contains(spawned, "--safe-mode"))
  end)

  -- Regression: render() built the reply's H1 as "# " .. job.prompt, which was
  -- fine for a one-line typed prompt and made nvim_buf_set_lines throw
  -- "'replacement string' item contains newlines" for a canned one.
  it("renders a reply buffer even though the canned prompt spans several lines", function()
    run("")
    claude.last()
    assert.truthy(vim.api.nvim_buf_get_name(0):match("^claude://reply/"))
    assert.equals(
      "# Analyze the English in the selection. _(+2 more prompt lines)_",
      vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
    )
  end)

  it("leaves a one-line prompt's heading unadorned", function()
    sent = {}
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "one", "two" })
    vim.api.nvim_set_current_buf(bufnr)

    claude.with_prompt("summarize this")({ args = "", line1 = 1, line2 = 2 })
    claude.last()
    assert.equals("# summarize this", vim.api.nvim_buf_get_lines(0, 0, 1, false)[1])
  end)
end)
