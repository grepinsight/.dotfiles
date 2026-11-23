local focus = require("taskpaper.focus")

-- Focus is the first taskpaper feature with no pure core to test on its own: the whole
-- behaviour is "which buffer is in this window and what is in it". So these run against
-- real buffers, which is also where IMPLEMENTATION_PLAN.md's testing note says the
-- blind spot is.

---@param lines string[]
---@return integer bufnr
local function source_buffer(lines)
  local bufnr = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_current_buf(bufnr)
  vim.bo[bufnr].filetype = "taskpaper"
  return bufnr
end

---@return string[]
local function shown()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function fixture()
  return {
    "Project A:", -- 1
    "\t- first", -- 2
    "\t\t- nested", -- 3
    "\t- second", -- 4
    "", -- 5
    "Project B:", -- 6
    "\t- other", -- 7
  }
end

-- Nested *tasks*, not nested projects. This is the shape the 2026-09-17 report was
-- about: the only project is at line 1, so a project-based Focus In collapses every
-- depth in here to the same answer.
local function deep_fixture()
  return {
    "Project A:", -- 1
    "\t- outer list", -- 2
    "\t\t- middle list", -- 3
    "\t\t\t- deep one", -- 4
    "\t\t\t- deep two", -- 5
    "\t\t- middle two", -- 6
  }
end

local function nested_fixture()
  return {
    "Project A:", -- 1
    "\tSub B:", -- 2
    "\t\t- deep", -- 3
    "\t- alongside", -- 4
    "Project C:", -- 5
  }
end

describe("taskpaper.focus.focus_in", function()
  it("narrows the window to the project's subtree", function()
    source_buffer(fixture())
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    focus.focus_in()
    assert.same({ "Project A:", "\t- first", "\t\t- nested", "\t- second" }, shown())
  end)

  it("focuses the list a task sits in, not the project above it", function()
    source_buffer(fixture())
    -- Line 3 is `- nested`, whose container is `- first` on line 2, not Project A.
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    focus.focus_in()
    assert.same({ "\t- first", "\t\t- nested" }, shown())
  end)

  -- The report, end to end: Focus In at depth 3 used to jump back to the root because
  -- the only project in the file is line 1.
  it("focuses a deeply nested list rather than jumping back to the root", function()
    source_buffer(deep_fixture())
    vim.api.nvim_win_set_cursor(0, { 4, 0 })
    focus.focus_in()
    assert.same({ "\t\t- middle list", "\t\t\t- deep one", "\t\t\t- deep two" }, shown())
  end)

  it("walks down one level at a time as the cursor moves onto a child", function()
    source_buffer(deep_fixture())
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    focus.focus_in()
    assert.same({
      "\t- outer list",
      "\t\t- middle list",
      "\t\t\t- deep one",
      "\t\t\t- deep two",
      "\t\t- middle two",
    }, shown())
    -- View line 2 is `- middle list`, so focusing from there narrows again.
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    focus.focus_in()
    assert.same({ "\t\t- middle list", "\t\t\t- deep one", "\t\t\t- deep two" }, shown())
  end)

  -- The view is its own buffer, so the source is not truncated while it is on screen.
  -- Losing this is the difference between a view and a destructive edit.
  it("leaves the source buffer whole", function()
    local src = source_buffer(fixture())
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    focus.focus_in()
    assert.are_not.equal(src, vim.api.nvim_get_current_buf())
    assert.equals(7, vim.api.nvim_buf_line_count(src))
  end)

  it("narrows again from inside a view, on the view's own cursor line", function()
    source_buffer(nested_fixture())
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    focus.focus_in()
    -- View line 2 is `Sub B:`, which is source line 2.
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    focus.focus_in()
    assert.same({ "\tSub B:", "\t\t- deep" }, shown())
  end)

  -- A top-level leaf has no container and no children, so there is nothing to narrow
  -- to. A top-level leaf *with* children is focusable now even though it is not a
  -- project, which is the change the report forced.
  it("keeps the buffer it was given when there is nothing to narrow to", function()
    local src = source_buffer({ "- loose", "Another:", "\t- child" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    focus.focus_in()
    assert.equals(src, vim.api.nvim_get_current_buf())
  end)

  it("focuses a parent task, which the project-based rule could not express", function()
    source_buffer({ "- loose parent", "\t- child" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    focus.focus_in()
    assert.same({ "- loose parent", "\t- child" }, shown())
  end)
end)

describe("taskpaper.focus write-back", function()
  it("puts an edit back on the source line it came from", function()
    local src = source_buffer(fixture())
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    focus.focus_in()
    vim.api.nvim_buf_set_lines(0, 1, 2, false, { "\t- first, edited" })
    focus.home()
    assert.same({
      "Project A:",
      "\t- first, edited",
      "\t\t- nested",
      "\t- second",
      "",
      "Project B:",
      "\t- other",
    }, vim.api.nvim_buf_get_lines(src, 0, -1, false))
  end)

  -- The index maths that is easy to get wrong: a view that grows has to push the lines
  -- after it down rather than overwrite them.
  it("pushes the rest of the file down when the view grows", function()
    local src = source_buffer(fixture())
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    focus.focus_in()
    vim.api.nvim_buf_set_lines(0, 4, 4, false, { "\t- third" })
    focus.home()
    assert.same({
      "Project A:",
      "\t- first",
      "\t\t- nested",
      "\t- second",
      "\t- third",
      "",
      "Project B:",
      "\t- other",
    }, vim.api.nvim_buf_get_lines(src, 0, -1, false))
  end)

  it("pulls the rest of the file up when the view shrinks", function()
    local src = source_buffer(fixture())
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    focus.focus_in()
    vim.api.nvim_buf_set_lines(0, 2, 4, false, {})
    focus.home()
    assert.same({
      "Project A:",
      "\t- first",
      "",
      "Project B:",
      "\t- other",
    }, vim.api.nvim_buf_get_lines(src, 0, -1, false))
  end)

  -- A view holds source line numbers, so a source edited from somewhere else makes them
  -- lies. Refusing is the only safe answer, and keeping the view open is what stops the
  -- refusal from also throwing the user's edit away.
  it("refuses to write back a view whose source moved underneath it", function()
    local src = source_buffer(fixture())
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    focus.focus_in()
    local view = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(src, 0, 0, false, { "Inserted above:" })
    vim.api.nvim_buf_set_lines(0, 1, 2, false, { "\t- first, edited" })
    focus.home()
    assert.equals(view, vim.api.nvim_get_current_buf())
    assert.equals("Project A:", vim.api.nvim_buf_get_lines(src, 1, 2, false)[1])
  end)
end)

describe("taskpaper.focus.focus_out", function()
  it("widens to the parent project", function()
    source_buffer(nested_fixture())
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    focus.focus_in()
    assert.same({ "\tSub B:", "\t\t- deep" }, shown())
    focus.focus_out()
    assert.same({ "Project A:", "\tSub B:", "\t\t- deep", "\t- alongside" }, shown())
  end)

  it("goes home from a top-level project, because there is nothing wider", function()
    local src = source_buffer(fixture())
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    focus.focus_in()
    focus.focus_out()
    assert.equals(src, vim.api.nvim_get_current_buf())
    assert.same(fixture(), shown())
  end)

  -- The ladder: out of a deep list to its parent list, out of that to the project, out
  -- of that to home. Every rung but the last is a task, which is why Focus Out cannot be
  -- project-based either.
  it("climbs one item at a time out of a nested list", function()
    local src = source_buffer(deep_fixture())
    vim.api.nvim_win_set_cursor(0, { 4, 0 })
    focus.focus_in()
    assert.same({ "\t\t- middle list", "\t\t\t- deep one", "\t\t\t- deep two" }, shown())

    focus.focus_out()
    assert.same({
      "\t- outer list",
      "\t\t- middle list",
      "\t\t\t- deep one",
      "\t\t\t- deep two",
      "\t\t- middle two",
    }, shown())

    focus.focus_out()
    assert.same(deep_fixture(), shown())

    focus.focus_out()
    assert.equals(src, vim.api.nvim_get_current_buf())
  end)

  it("is a no-op outside a view", function()
    local src = source_buffer(fixture())
    focus.focus_out()
    assert.equals(src, vim.api.nvim_get_current_buf())
  end)
end)

describe("taskpaper.focus.home", function()
  it("restores the source with the cursor on the item that was focused", function()
    local src = source_buffer(fixture())
    vim.api.nvim_win_set_cursor(0, { 6, 0 })
    focus.focus_in()
    focus.home()
    assert.equals(src, vim.api.nvim_get_current_buf())
    assert.equals(6, vim.api.nvim_win_get_cursor(0)[1])
  end)

  it("is a no-op outside a view", function()
    local src = source_buffer(fixture())
    focus.home()
    assert.equals(src, vim.api.nvim_get_current_buf())
  end)

  -- Refusing to write back a stale view is right; refusing to *leave* one traps the
  -- user in a buffer with no way out but :bd!. With nothing unwritten in it there is
  -- nothing to lose, so going back to the source is both safe and the only correct
  -- answer available: the remembered line numbers cannot be trusted to rebuild from.
  it("still leaves a stale view that has nothing unwritten in it", function()
    local src = source_buffer(fixture())
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    focus.focus_in()
    vim.api.nvim_buf_set_lines(src, 0, 0, false, { "Inserted above:" })
    focus.home()
    assert.equals(src, vim.api.nvim_get_current_buf())
  end)

  it("leaves a stale view with unwritten edits when told to, and keeps the source", function()
    local src = source_buffer(fixture())
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    focus.focus_in()
    vim.api.nvim_buf_set_lines(src, 0, 0, false, { "Inserted above:" })
    vim.api.nvim_buf_set_lines(0, 1, 2, false, { "\t- first, edited" })
    focus.home(true)
    assert.equals(src, vim.api.nvim_get_current_buf())
    assert.equals("\t- first", vim.api.nvim_buf_get_lines(src, 2, 3, false)[1])
  end)
end)

-- The commands are what the app's menu items actually become, so a rename or a dropped
-- line in the ftplugin should fail here rather than the next time the user reaches for
-- the key.
describe("taskpaper.focus warnings", function()
  ---@param fn function
  ---@return string[] messages vim.notify was given
  local function captured(fn)
    local notes = {}
    local real = vim.notify
    vim.notify = function(msg)
      table.insert(notes, msg)
    end
    local ok, err = pcall(fn)
    vim.notify = real
    assert(ok, err)
    return notes
  end

  -- Forcing the discard used to warn twice that the view "was not written back": once
  -- from home() and once from the BufLeave sync that home() triggers by swapping the
  -- window's buffer. Both fire after the user has explicitly said to discard, so they
  -- read as something going wrong rather than as the thing that was asked for.
  it("says nothing about a write-back the user asked to skip", function()
    local src = source_buffer(fixture())
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    focus.focus_in()
    vim.api.nvim_buf_set_lines(src, 0, 0, false, { "Inserted above:" })
    vim.api.nvim_buf_set_lines(0, 1, 2, false, { "\t- first, edited" })

    assert.same({}, captured(function()
      focus.home(true)
    end))
    assert.equals(src, vim.api.nvim_get_current_buf())
  end)

  -- The other half of the same rule: refusing has to explain itself, because a silent
  -- refusal looks like a broken key.
  it("names the escape when it refuses to leave a stale view", function()
    local src = source_buffer(fixture())
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    focus.focus_in()
    vim.api.nvim_buf_set_lines(src, 0, 0, false, { "Inserted above:" })
    vim.api.nvim_buf_set_lines(0, 1, 2, false, { "\t- first, edited" })

    local notes = captured(function()
      focus.home()
    end)
    assert.is_truthy(table.concat(notes, "\n"):find("TaskPaperHome!", 1, true))
  end)
end)

describe("taskpaper ftplugin focus commands", function()
  ---@return table<string, boolean> rhs values of this buffer's normal-mode maps
  local function mapped_commands()
    local out = {}
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
      out[map.rhs or ""] = true
    end
    return out
  end

  local function ftplugin_buffer()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    vim.cmd("runtime! ftplugin/taskpaper.vim")
    return bufnr
  end

  -- The unit tests above call focus.home(true) directly, so they cannot see a command
  -- definition that fails to deliver the bang. `<bang>0` is a *vimscript* idiom -- `!0`
  -- is vimscript's logical not -- and pasted into a :lua line it is a syntax error. The
  -- quieter trap is the one after it: `<bang>0` yields 0 or 1, and Lua counts 0 as true,
  -- so an unbanged command would have forced the discard.
  it("delivers the bang through the command, not only through the function", function()
    local src = source_buffer(fixture())
    vim.cmd("runtime! ftplugin/taskpaper.vim")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.cmd("TaskPaperFocusIn")
    -- The view is its own buffer, so it needs the buffer-local commands too. Setting
    -- 'filetype' does that in real use; the harness runs with `filetype plugin off`.
    vim.cmd("runtime! ftplugin/taskpaper.vim")
    vim.api.nvim_buf_set_lines(src, 0, 0, false, { "Inserted above:" })
    vim.api.nvim_buf_set_lines(0, 1, 2, false, { "\t- first, edited" })

    vim.cmd("TaskPaperHome")
    assert.are_not.equal(src, vim.api.nvim_get_current_buf())
    vim.cmd("TaskPaperHome!")
    assert.equals(src, vim.api.nvim_get_current_buf())
  end)

  it("defines a command per focus menu item", function()
    ftplugin_buffer()
    assert.equals(2, vim.fn.exists(":TaskPaperFocusIn"))
    assert.equals(2, vim.fn.exists(":TaskPaperFocusOut"))
    assert.equals(2, vim.fn.exists(":TaskPaperHome"))
  end)

  it("binds a key to each of them", function()
    ftplugin_buffer()
    local mapped = mapped_commands()
    assert.is_true(mapped["<Cmd>TaskPaperFocusIn<CR>"])
    assert.is_true(mapped["<Cmd>TaskPaperFocusOut<CR>"])
    assert.is_true(mapped["<Cmd>TaskPaperHome<CR>"])
  end)
end)
