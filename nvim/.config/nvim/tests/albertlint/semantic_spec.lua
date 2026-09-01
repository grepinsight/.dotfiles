---Scope selection for the semantic tier.
---
---These exist because `config.semantic.scope` was declared with a full `---@field`
---annotation and never read: `M.run` branched on the range flag and otherwise called
---`paragraph_range` unconditionally, so `scope = "buffer"` was a config option that did
---nothing. The observed symptom was "0 semantic findings" on visibly broken prose, because a
---note written as one-line paragraphs has a one-line paragraph under the cursor, and the two
---classes needing prior context (ARTICLE-DEFINITE for an already-introduced referent, and
---REFERENCE) have nothing to work with there. These tests pin the range, which is what this
---module decides; they do not claim a one-line pass can never report anything.
local semantic = require("albertlint.semantic")

---A buffer whose paragraphs are single lines separated by blanks, which is the shape that
---exposed the bug. Line 3 (1-indexed) sits alone between two blanks.
---@return integer
local function one_line_paragraphs()
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "My head hurts. slightly behind temple areas, above the ears.",
    "",
    "I've been sleep deprived for several days.",
    "",
    "let's make a ticket.",
  })
  vim.bo[buf].filetype = "markdown"
  return buf
end

---Put the cursor on a 1-indexed line of `buf` in the current window.
---@param buf integer
---@param lnum integer
local function focus(buf, lnum)
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_win_set_cursor(0, { lnum, 0 })
end

describe("semantic scope_range", function()
  it("returns the cursor's paragraph when scope is paragraph", function()
    local buf = one_line_paragraphs()
    focus(buf, 3)

    local s, e = semantic._scope_range(buf, "paragraph")

    -- 0-indexed, end exclusive: line 3 alone.
    assert.equals(2, s)
    assert.equals(3, e)
  end)

  it("defaults to the paragraph when scope is nil", function()
    local buf = one_line_paragraphs()
    focus(buf, 3)

    local s, e = semantic._scope_range(buf, nil)

    assert.equals(2, s)
    assert.equals(3, e)
  end)

  it("returns the whole buffer when scope is buffer", function()
    local buf = one_line_paragraphs()
    focus(buf, 3)

    local s, e = semantic._scope_range(buf, "buffer")

    assert.equals(0, s)
    assert.equals(5, e)
  end)

  it("covers every line of a one-line-paragraph buffer under scope buffer", function()
    -- The regression this whole change exists for: under `paragraph`, a cursor on the
    -- last line sends one line and the discourse classes cannot fire. Under `buffer` it
    -- sends all five.
    local buf = one_line_paragraphs()
    focus(buf, 5)

    local ps, pe = semantic._scope_range(buf, "paragraph")
    local bs, be = semantic._scope_range(buf, "buffer")

    assert.equals(1, pe - ps)
    assert.equals(5, be - bs)
  end)

  it("returns the last visual selection when scope is selection", function()
    local buf = one_line_paragraphs()
    focus(buf, 1)
    -- Set the marks directly rather than driving visual mode: `'<` and `'>` are what the
    -- code reads, and they persist after visual mode ends.
    vim.api.nvim_buf_set_mark(buf, "<", 1, 0, {})
    vim.api.nvim_buf_set_mark(buf, ">", 3, 0, {})

    local s, e = semantic._scope_range(buf, "selection")

    assert.equals(0, s)
    assert.equals(3, e)
  end)

  it("falls back to the paragraph when scope is selection but none was ever made", function()
    -- `line("'<")` is 0 in a buffer that has never been visually selected, and a
    -- 0-indexed start of -1 is an API error rather than an empty range.
    local buf = one_line_paragraphs()
    focus(buf, 3)
    vim.api.nvim_buf_del_mark(buf, "<")
    vim.api.nvim_buf_del_mark(buf, ">")

    local s, e = semantic._scope_range(buf, "selection")

    assert.equals(2, s)
    assert.equals(3, e)
    assert.is_true(s >= 0)
  end)

  it("clamps a selection whose end mark outlived the lines it pointed at", function()
    -- A mark can survive the deletion of the line it referenced. Returning a range past
    -- the last line would make the contract "a range that may not exist"; the caller
    -- should not have to know that nvim_buf_get_lines tolerates that.
    local buf = one_line_paragraphs()
    focus(buf, 1)
    vim.api.nvim_buf_set_mark(buf, "<", 1, 0, {})
    vim.api.nvim_buf_set_mark(buf, ">", 5, 0, {})
    vim.api.nvim_buf_set_lines(buf, 3, 5, false, {})

    local s, e = semantic._scope_range(buf, "selection")

    assert.equals(0, s)
    assert.equals(3, e)
    assert.equals(vim.api.nvim_buf_line_count(buf), e)
  end)

  it("warns and falls back to the paragraph on an unknown scope", function()
    local buf = one_line_paragraphs()
    focus(buf, 3)

    local s, e, warning = semantic._scope_range(buf, "prargraph")

    assert.equals(2, s)
    assert.equals(3, e)
    assert.is_string(warning)
    assert.is_truthy(warning:find("prargraph", 1, true))
  end)

  it("does not warn on a recognised scope", function()
    local buf = one_line_paragraphs()
    focus(buf, 3)

    local _, _, paragraph_warning = semantic._scope_range(buf, "paragraph")
    local _, _, buffer_warning = semantic._scope_range(buf, "buffer")

    assert.is_nil(paragraph_warning)
    assert.is_nil(buffer_warning)
  end)
end)

describe("semantic scope_range selection edge cases", function()
  it("falls back when the buffer shrank past BOTH marks", function()
    -- Clamping only the end is not enough: `first - 1` then lands at or past the line
    -- count and the range comes back empty, so the pass would send nothing and report no
    -- findings, which is the exact failure this whole change exists to remove.
    local buf = one_line_paragraphs()
    focus(buf, 1)
    vim.api.nvim_buf_set_mark(buf, "<", 4, 0, {})
    vim.api.nvim_buf_set_mark(buf, ">", 5, 0, {})
    vim.api.nvim_buf_set_lines(buf, 1, 5, false, {})

    local s, e = semantic._scope_range(buf, "selection")

    assert.is_true(s >= 0)
    assert.is_true(e > s, "range must not be empty")
    assert.is_true(e <= vim.api.nvim_buf_line_count(buf))
  end)
end)

describe("semantic in-flight guard and cancel", function()
  it("reports nothing to cancel when no pass is running", function()
    local buf = one_line_paragraphs()
    focus(buf, 1)

    assert.is_false(semantic.cancel(buf))
  end)

  it("exposes its in-flight table empty when idle", function()
    -- The guard exists because a second :AlbertLintSemantic spawned a second `claude`: two
    -- paid calls and two sets of diagnostics racing to overwrite each other.
    assert.equals(0, vim.tbl_count(semantic._in_flight))
  end)

  it("refuses a second pass and leaves the first alone", function()
    -- Simulated rather than driven through vim.system, so the test needs no CLI and no
    -- network. What is under test is the guard, not the request.
    local buf = one_line_paragraphs()
    focus(buf, 1)
    semantic._in_flight[buf] = {
      handle = { kill = function() end },
      started = (vim.uv or vim.loop).hrtime(),
      scope = "buffer",
      lines = 5,
    }

    local notified
    local real = vim.notify
    vim.notify = function(msg) notified = msg end
    semantic.run(vim.api.nvim_create_namespace("test"), false)
    vim.notify = real

    assert.is_truthy(notified:find("already running", 1, true))
    assert.is_truthy(notified:find("AlbertLintSemanticCancel", 1, true))
    assert.is_not_nil(semantic._in_flight[buf], "the first pass must survive the refusal")

    semantic._in_flight[buf] = nil
  end)

  it("cancels a running pass by killing its handle", function()
    local buf = one_line_paragraphs()
    focus(buf, 1)
    local killed
    semantic._in_flight[buf] = {
      handle = { kill = function(_, sig) killed = sig end },
      started = (vim.uv or vim.loop).hrtime(),
      scope = "buffer",
      lines = 5,
    }

    local real = vim.notify
    vim.notify = function() end
    local ok = semantic.cancel(buf)
    vim.notify = real

    assert.is_true(ok)
    assert.equals("sigterm", killed)
    semantic._in_flight[buf] = nil
  end)
end)
