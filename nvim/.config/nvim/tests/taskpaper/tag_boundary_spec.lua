local done = require("taskpaper.done")

-- One rule, two spellings: a Vim pattern in syntax/taskpaper.vim decides what is struck
-- through, and a Lua scanner in taskpaper.done decides what is stripped. On 2026-09-16 they
-- disagreed on three lines, and each was wrong in its own way, so the fixtures live in
-- one table and every case is asserted against both. A case added here is a case both
-- have to answer.
--
-- `done = true` means the line already carries a real @done tag: syntax strikes the
-- line through, and toggling it removes the tag.
local CASES = {
  { line = "\t- test done @done", done = true },
  { line = "\t- pay rent @done(2026-09-16)", done = true },
  { line = "\t- x @note(a) @done", done = true },
  { line = "@done", done = true },
  { line = "Project 1: @done(2026-09-16)", done = true },

  { line = "\t- keep working @donex", done = false },
  { line = "\t- task @done-later", done = false },
  { line = "\t- task @done.foo", done = false },
  { line = "\t- task @note(mention @done here)", done = false },
  { line = "\t- mail name@done.com", done = false },
  { line = "\t- plain task", done = false },
}

local TODAY = "2026-09-16"

describe("the @done boundary rule, as syntax sees it", function()
  before_each(function()
    vim.cmd("syntax enable")
  end)

  for _, case in ipairs(CASES) do
    local want = case.done and "strikes" or "leaves"
    it(want .. " " .. case.line:gsub("\t", ""), function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { case.line })
      vim.api.nvim_set_current_buf(bufnr)
      vim.bo[bufnr].filetype = "taskpaper"
      local col = case.line:find("%S") or 1
      -- synstack rather than synID: the done match contains taskpaperTag, so on a line
      -- that is nothing but `@done` the innermost group at the first non-blank column is
      -- the tag, and the struck container shows up only in the stack.
      local struck = false
      for _, id in ipairs(vim.fn.synstack(1, col)) do
        struck = struck or vim.fn.synIDattr(id, "name") == "taskpaperDone"
      end
      assert.equals(case.done, struck)
    end)
  end
end)

describe("the @done boundary rule, as the toggle sees it", function()
  for _, case in ipairs(CASES) do
    local want = case.done and "strips from" or "appends to"
    it(want .. " " .. case.line:gsub("\t", ""), function()
      local got = done.toggle(case.line, TODAY)
      if case.done then
        assert.is_not_nil(done.undone(case.line))
        assert.equals(done.undone(case.line), got)
      else
        assert.equals(case.line:gsub("%s+$", "") .. " @done(" .. TODAY .. ")", got)
        assert.is_nil(done.undone(case.line))
      end
    end)
  end
end)
