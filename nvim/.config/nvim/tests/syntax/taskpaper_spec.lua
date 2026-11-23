-- The observable behaviour of a syntax file is which group a character lands in, so
-- these assert on group names at a column rather than on the file's contents.

---@param lines string[]
---@return integer bufnr
local function taskpaper_buffer(lines)
  vim.cmd("syntax enable")
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_current_buf(bufnr)
  vim.bo[bufnr].filetype = "taskpaper"
  return bufnr
end

---Syntax group covering the 1-indexed byte column `col` of line `lnum`.
---@param lnum integer
---@param col integer
---@return string
local function group_at(lnum, col)
  return vim.fn.synIDattr(vim.fn.synID(lnum, col, 1), "name")
end

---1-indexed byte column of `needle` in `line`.
---@param line string
---@param needle string
---@return integer
local function col_of(line, needle)
  local at = line:find(needle, 1, true)
  assert(at, "needle not in line: " .. needle)
  return at
end

---Every syntax group covering the 1-indexed byte column `col`, outermost first. A
---contained group hides its container from `synID`, so this is what answers "is this
---line struck" now that the done match carries a `contains`.
---@param lnum integer
---@param col integer
---@return string[]
local function stack_at(lnum, col)
  return vim.tbl_map(function(id)
    return vim.fn.synIDattr(id, "name")
  end, vim.fn.synstack(lnum, col))
end

describe("syntax/taskpaper", function()
  it("highlights a trailing tag", function()
    local line = "\t- Weekly review @important"
    taskpaper_buffer({ line })
    assert.equals("taskpaperTag", group_at(1, col_of(line, "@important")))
  end)

  it("highlights every tag when a task carries several", function()
    local line = "\t- Sort the mail @start @inprogress"
    taskpaper_buffer({ line })
    assert.equals("taskpaperTag", group_at(1, col_of(line, "@start")))
    assert.equals("taskpaperTag", group_at(1, col_of(line, "@inprogress")))
  end)

  it("includes a parenthesised tag value", function()
    local line = "\t- pay rent @due(2026-09-16)"
    taskpaper_buffer({ line })
    assert.equals("taskpaperTag", group_at(1, col_of(line, "(2026")))
    assert.equals("taskpaperTag", group_at(1, col_of(line, ")")))
  end)

  it("leaves the task text alone", function()
    local line = "\t- Weekly review @important"
    taskpaper_buffer({ line })
    assert.equals("", group_at(1, col_of(line, "Weekly")))
  end)

  -- An address is the case that makes a bare /@\w\+/ unusable: the whole point of the
  -- grey is to mark metadata, and half an email address is not metadata.
  it("does not treat an address as a tag", function()
    local line = "\t- mail name@example.com"
    taskpaper_buffer({ line })
    assert.equals("", group_at(1, col_of(line, "@example")))
  end)

  it("greys tags by linking them to Comment", function()
    taskpaper_buffer({ "\t- x @tag" })
    local hl = vim.api.nvim_get_hl(0, { name = "taskpaperTag" })
    assert.equals("Comment", hl.link)
  end)
end)

-- Stage 1 of IMPLEMENTATION_PLAN.md: the other three item types. Every line-level
-- group starts at column 1, so these also pin down the precedence between them.
describe("syntax/taskpaper item types", function()
  it("highlights a project heading", function()
    local line = "Project 1:"
    taskpaper_buffer({ line })
    assert.equals("taskpaperProject", group_at(1, col_of(line, "Project")))
  end)

  it("still highlights a project when tags trail the colon", function()
    local line = "inbox: @hold"
    taskpaper_buffer({ line })
    assert.equals("taskpaperProject", group_at(1, col_of(line, "inbox")))
    assert.equals("taskpaperTag", group_at(1, col_of(line, "@hold")))
  end)

  -- The dash is the explicit marker, so it wins over a trailing colon, which in a task
  -- is usually just prose.
  it("keeps a task a task even when it ends in a colon", function()
    local line = "\t- ask about the thing:"
    taskpaper_buffer({ line })
    assert.equals("", group_at(1, col_of(line, "ask")))
  end)

  it("treats a line that is neither task nor project as a note", function()
    local line = "some loose prose about the project"
    taskpaper_buffer({ line })
    assert.equals("taskpaperNote", group_at(1, col_of(line, "loose")))
  end)

  it("greys the task marker without touching the task text", function()
    local line = "\t- Weekly review"
    taskpaper_buffer({ line })
    assert.equals("taskpaperListItem", group_at(1, col_of(line, "-")))
    assert.equals("", group_at(1, col_of(line, "Weekly")))
  end)

  -- The app strikes the item through and leaves the @done tag itself plain, so the strike
  -- covers the marker and the text and stops where the tag begins.
  it("strikes a done task over its text and its marker", function()
    local line = "\t- test done @done"
    taskpaper_buffer({ line })
    assert.equals("taskpaperDone", group_at(1, col_of(line, "test")))
    assert.equals("taskpaperDone", group_at(1, col_of(line, "-")))
  end)

  it("leaves the @done tag reading as a tag rather than as struck text", function()
    local line = "\t- test done @done"
    taskpaper_buffer({ line })
    assert.equals("taskpaperTag", group_at(1, col_of(line, "@done")))
    assert.same({ "taskpaperDone", "taskpaperTag" }, stack_at(1, col_of(line, "@done")))
  end)

  it("strikes a done task carrying a date", function()
    local line = "\t- pay rent @done(2026-09-16)"
    taskpaper_buffer({ line })
    assert.equals("taskpaperDone", group_at(1, col_of(line, "pay")))
  end)

  -- @donex is a different tag. Without a word boundary after `done` it strikes the line.
  it("does not read @donex as done", function()
    local line = "\t- keep working @donex"
    taskpaper_buffer({ line })
    assert.equals("", group_at(1, col_of(line, "keep")))
  end)

  -- A link rather than attributes, changed 2026-09-18: `Title` already means heading, and
  -- linking leaves the color the colorscheme's to pick. Asserted both ways on purpose.
  -- The link is the decision, and the resolved bold is what the reader actually sees, so a
  -- colorscheme that dropped the weight fails here instead of silently rendering a heading
  -- that is only colored. `link = false` is what resolves it; without that argument
  -- nvim_get_hl answers `{ link = "Title" }` and every attribute reads as nil.
  it("links a project heading to Title, and that Title carries weight", function()
    taskpaper_buffer({ "Project 1:" })
    assert.equals("Title", vim.api.nvim_get_hl(0, { name = "taskpaperProject" }).link)
    local resolved = vim.api.nvim_get_hl(0, { name = "taskpaperProject", link = false })
    assert.is_true(resolved.bold)
    assert.is_not_nil(resolved.fg)
  end)

  -- A strike is a line drawn through words, so drawing it across the indent draws it
  -- through nothing: on a tab-indented list every done task grows a long rule out to the
  -- left margin and the strikes chain into each other. Reported 2026-09-16 from a real
  -- buffer. The indent stays inside the done match, so the line still reads as done.
  it("starts the strike at the marker, not at column 1", function()
    local line = "\t\t- Weekly review @done"
    taskpaper_buffer({ line })
    assert.equals("taskpaperDonePad", group_at(1, 1))
    assert.equals("taskpaperDonePad", group_at(1, 2))
    assert.equals("taskpaperDone", group_at(1, col_of(line, "-")))
    assert.same({ "taskpaperDone", "taskpaperDonePad" }, stack_at(1, 1))
  end)

  -- The mirror of the same defect, at the other end of the line.
  it("ends the strike at the last non-blank, not at the line end", function()
    local line = "\t- Email @done  "
    taskpaper_buffer({ line })
    assert.equals("taskpaperDonePad", group_at(1, #line))
    assert.equals("taskpaperDone", group_at(1, col_of(line, "Email")))
  end)

  -- The gap between the text and a tag is not text either, and leaving it struck is what
  -- chains the strike into the tags so they read as crossed out too. Same report.
  it("stops the strike at the gap before a tag", function()
    local line = "\t- Weekly review @important @done"
    taskpaper_buffer({ line })
    assert.equals("taskpaperDone", group_at(1, col_of(line, "review")))
    assert.equals("taskpaperDonePad", group_at(1, col_of(line, " @important")))
    assert.equals("taskpaperDonePad", group_at(1, col_of(line, " @done")))
    assert.equals("taskpaperTag", group_at(1, col_of(line, "@important")))
  end)

  -- The guard against over-correcting the case above: a gap between two words is text,
  -- and a strike that breaks there would look like two items on one line.
  it("keeps the strike running across a gap between two words", function()
    local line = "\t- merged  the thing @done"
    taskpaper_buffer({ line })
    local gap = col_of(line, "  the")
    assert.equals("taskpaperDone", group_at(1, gap))
    assert.equals("taskpaperDone", group_at(1, gap + 1))
  end)

  it("leaves the carved-out padding unstruck", function()
    taskpaper_buffer({ "\t- x @done" })
    -- hlexists first: an undefined group reports no attributes either, so without this
    -- the assertions below would pass on a syntax file that never defined the group.
    assert.equals(1, vim.fn.hlexists("taskpaperDonePad"))
    local hl = vim.api.nvim_get_hl(0, { name = "taskpaperDonePad" })
    assert.is_nil(hl.strikethrough)
    assert.is_nil(hl.link)
  end)

  -- Strikethrough is an attribute rather than a link, and unlike the project heading above
  -- it stays one: no standard group means "body text, struck", and a done item has to stay
  -- as readable as the app renders it, so it is struck and deliberately not recolored.
  it("strikes done tasks without recoloring them, and still greys task markers", function()
    taskpaper_buffer({ "\t- x @done" })
    local done_hl = vim.api.nvim_get_hl(0, { name = "taskpaperDone" })
    assert.is_true(done_hl.strikethrough)
    assert.is_nil(done_hl.fg)
    assert.is_nil(done_hl.link)
    assert.equals("Comment", vim.api.nvim_get_hl(0, { name = "taskpaperListItem" }).link)
  end)
end)

-- Found by an adversarial review of the patterns above, 2026-09-16, and all three were
-- real: the done match was firing on tags that merely start with `done`, and on a
-- `@done` sitting inside another tag's value, where it is text rather than a tag.
describe("syntax/taskpaper done detection boundaries", function()
  it("does not read @done-later as done, because - is a tag-name character", function()
    local line = "\t- task @done-later"
    taskpaper_buffer({ line })
    assert.equals("", group_at(1, col_of(line, "task")))
  end)

  it("does not read @done.foo as done, because . is a tag-name character", function()
    local line = "\t- task @done.foo"
    taskpaper_buffer({ line })
    assert.equals("", group_at(1, col_of(line, "task")))
  end)

  it("does not read a @done inside another tag's value as done", function()
    local line = "\t- task @note(mention @done here)"
    taskpaper_buffer({ line })
    assert.equals("", group_at(1, col_of(line, "task")))
  end)

  -- The guard against over-correcting the case above: a closed tag value earlier in the
  -- line must not hide a real @done after it.
  it("still reads a real @done that follows a closed tag value", function()
    local line = "\t- x @note(a) @done"
    taskpaper_buffer({ line })
    assert.equals("taskpaperDone", group_at(1, col_of(line, "x")))
  end)
end)
