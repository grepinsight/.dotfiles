---The two-window diff, and the alignment invariant that makes the notes safe.
---
---Diff mode aligns two windows using filler lines it computes itself. `virt_lines` add
---screen rows to ONE window, so a note placed only on the corrected side pushes every line
---below it out of alignment. Measured 2026-09-08 on a five-line pair with one one-line note
---on the right buffer only: line 3 sat at screen row 4 on the right and row 3 on the left.
---Mirroring the note with an equal count of blank virtual lines on the left restored exact
---alignment.
---
---The blank extmarks therefore look like dead code and are not. This spec is what stops them
---being deleted, and the last test measures the alignment directly rather than trusting the
---count.
local diffview = require("albertlint.level.diffview")

---@return integer bufnr
local function source()
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "alpha",
    "which takes the text and use LLM",
    "beta",
    "grammar/expression error",
    "gamma",
  })
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_win_set_buf(0, buf)
  return buf
end

local CORRECTED = {
  "alpha",
  "which takes the text and calls an LLM",
  "beta",
  "grammar/expression errors",
  "gamma",
}

---@return table[]
local function placed()
  return {
    { lnum = 2, col = 25, fix = { label = "Agreement", note = "`takes` and `use` share a subject." } },
    { lnum = 4, col = 19, fix = { label = "Number", note = "Open-ended set, so the plural is the default." } },
  }
end

---Total virtual lines carried by every extmark in a namespace.
---@param buf integer
---@param ns integer
---@return integer
local function virt_line_count(buf, ns)
  local total = 0
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })) do
    total = total + #((mark[4] or {}).virt_lines or {})
  end
  return total
end

describe("level.diffview open", function()
  it("puts both windows in diff mode", function()
    local buf = source()

    local state = diffview.open(buf, CORRECTED, placed(), {})

    assert.is_true(vim.wo[state.source_win].diff)
    assert.is_true(vim.wo[state.scratch_win].diff)

    diffview.close(state)
  end)

  it("shows the corrected text in the scratch buffer and leaves the source alone", function()
    local buf = source()

    local state = diffview.open(buf, CORRECTED, placed(), {})

    assert.same(CORRECTED, vim.api.nvim_buf_get_lines(state.scratch_buf, 0, -1, false))
    -- The source buffer must be untouched until the author presses `do`.
    assert.equals("which takes the text and use LLM",
      vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1])

    diffview.close(state)
  end)

  it("keeps the scratch buffer a nofile scratch and unlisted", function()
    local buf = source()

    local state = diffview.open(buf, CORRECTED, placed(), {})

    assert.equals("nofile", vim.bo[state.scratch_buf].buftype)
    assert.is_false(vim.bo[state.scratch_buf].buflisted)

    diffview.close(state)
  end)

  it("mirrors every note with an equal count of blanks on the source side", function()
    -- THE invariant. If these two counts diverge, the diff visibly desyncs.
    local buf = source()

    local state = diffview.open(buf, CORRECTED, placed(), {})

    local on_source = virt_line_count(buf, state.ns)
    local on_scratch = virt_line_count(state.scratch_buf, state.ns)

    assert.is_true(on_scratch > 0)
    assert.equals(on_scratch, on_source)

    diffview.close(state)
  end)

  it("places the note at the row the fix landed on", function()
    local buf = source()

    local state = diffview.open(buf, CORRECTED, placed(), {})

    local rows = {}
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(state.scratch_buf, state.ns, 0, -1, {})) do
      rows[mark[2]] = true
    end

    -- placed lnums are 1-indexed; extmark rows are 0-indexed.
    assert.is_true(rows[1])
    assert.is_true(rows[3])

    diffview.close(state)
  end)

  it("reports how many findings it rendered", function()
    local buf = source()

    local state = diffview.open(buf, CORRECTED, placed(), {})

    assert.equals(2, state.count)

    diffview.close(state)
  end)

  it("handles an empty placed list without erroring", function()
    local buf = source()

    local state = diffview.open(buf, CORRECTED, {}, {})

    assert.equals(0, state.count)
    assert.equals(0, virt_line_count(buf, state.ns))

    diffview.close(state)
  end)

  it("keeps the two windows line-aligned with the notes rendered", function()
    -- The measurement, not the proxy. Without mirroring, line 3 sat one screen row lower
    -- on the annotated side and everything below it was off by the note's height.
    local buf = source()

    local state = diffview.open(buf, CORRECTED, placed(), {})

    local mismatches = {}
    for lnum = 1, 5 do
      local left = vim.fn.screenpos(state.source_win, lnum, 1).row
      local right = vim.fn.screenpos(state.scratch_win, lnum, 1).row
      if left ~= right then
        table.insert(mismatches, ("line %d: left row %d, right row %d"):format(lnum, left, right))
      end
    end

    diffview.close(state)
    assert.same({}, mismatches)
  end)
end)

describe("level.diffview close", function()
  it("leaves the source buffer out of diff mode", function()
    -- Without teardown a stale diffthis leaves the author's real buffer permanently in
    -- diff mode, which is the worst kind of leftover: it reads as a broken editor.
    local buf = source()
    local state = diffview.open(buf, CORRECTED, placed(), {})

    diffview.close(state)

    assert.is_false(vim.wo[state.source_win].diff)
  end)

  it("wipes the scratch buffer", function()
    local buf = source()
    local state = diffview.open(buf, CORRECTED, placed(), {})

    diffview.close(state)

    assert.is_false(vim.api.nvim_buf_is_valid(state.scratch_buf))
  end)

  it("clears the notes from the source buffer", function()
    local buf = source()
    local state = diffview.open(buf, CORRECTED, placed(), {})

    diffview.close(state)

    assert.equals(0, #vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, {}))
  end)

  it("is idempotent", function()
    local buf = source()
    local state = diffview.open(buf, CORRECTED, placed(), {})

    assert.is_true(diffview.close(state))
    assert.is_false(diffview.close(state))
  end)

  it("tolerates being called with nil", function()
    assert.is_false(diffview.close(nil))
  end)
end)
