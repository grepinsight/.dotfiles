local done = require("taskpaper.done")

local TODAY = "2026-09-16"

describe("taskpaper.done.toggle", function()
  it("appends a dated tag to a plain task", function()
    assert.equals("- buy milk @done(2026-09-16)", done.toggle("- buy milk", TODAY))
  end)

  it("appends after the tags a task already carries", function()
    assert.equals(
      "- ship it @important @done(2026-09-16)",
      done.toggle("- ship it @important", TODAY)
    )
  end)

  it("keeps the indent, because the indent is the item's place in the outline", function()
    assert.equals("\t\t- nested @done(2026-09-16)", done.toggle("\t\t- nested", TODAY))
  end)

  it("does not leave a double space when the line had trailing whitespace", function()
    assert.equals("- Sort the mail @done(2026-09-16)", done.toggle("- Sort the mail ", TODAY))
  end)

  it("removes a bare @done", function()
    assert.equals("- test done", done.toggle("- test done @done", TODAY))
  end)

  it("removes a dated @done and the space that introduced it", function()
    assert.equals("- pay rent", done.toggle("- pay rent @done(2026-09-14)", TODAY))
  end)

  it("closes the gap when the tag sat mid-line", function()
    assert.equals("- foo bar", done.toggle("- foo @done bar", TODAY))
  end)

  -- @donex is a different tag, so toggling should mark the line done, not undo it.
  it("does not mistake @donex for @done", function()
    assert.equals("- keep going @donex @done(2026-09-16)", done.toggle("- keep going @donex", TODAY))
  end)

  it("marks a project done the same way, after the colon", function()
    assert.equals("Project 1: @done(2026-09-16)", done.toggle("Project 1:", TODAY))
  end)

  it("leaves a blank line alone", function()
    assert.equals("", done.toggle("", TODAY))
    assert.equals("\t", done.toggle("\t", TODAY))
  end)
end)

describe("taskpaper.done.toggle_range", function()
  ---@param lines string[]
  ---@return integer bufnr
  local function buffer(lines)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_set_current_buf(bufnr)
    return bufnr
  end

  it("toggles every line in the range and leaves the rest alone", function()
    local bufnr = buffer({ "- a", "- b", "- c" })
    done.toggle_range(1, 2, TODAY)
    assert.same({
      "- a @done(2026-09-16)",
      "- b @done(2026-09-16)",
      "- c",
    }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
  end)

  it("undoes a line that was already done, in the same pass", function()
    local bufnr = buffer({ "- a @done(2026-09-14)", "- b" })
    done.toggle_range(1, 2, TODAY)
    assert.same({
      "- a",
      "- b @done(2026-09-16)",
    }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
  end)
end)
