local outline = require("taskpaper.outline")

-- The outline every test below works on. Line 5 is blank on purpose: blank-line
-- ownership is the thing most likely to be wrong in a move, and the rule here is that a
-- blank line belongs to nobody, so it neither travels with a subtree nor ends one early.
local function fixture()
  return {
    "Project A:",       -- 1
    "\t- first",        -- 2
    "\t\t- nested",     -- 3
    "\t- second",       -- 4
    "",                 -- 5
    "Project B:",       -- 6
    "\t- other",        -- 7
  }
end

describe("taskpaper.outline.level", function()
  it("counts tabs", function()
    assert.equals(0, outline.level("Project A:"))
    assert.equals(1, outline.level("\t- first"))
    assert.equals(2, outline.level("\t\t- nested"))
  end)

  it("counts a run of shiftwidth spaces as one level", function()
    assert.equals(1, outline.level("    - first", 4))
    assert.equals(2, outline.level("        - nested", 4))
  end)

  it("has no level for a blank line, which is what keeps blanks out of subtrees", function()
    assert.is_nil(outline.level(""))
    assert.is_nil(outline.level("\t\t"))
  end)
end)

describe("taskpaper.outline.subtree", function()
  it("takes an item with its descendants", function()
    assert.same({ 2, 3 }, { outline.subtree(fixture(), 2) })
  end)

  it("stops at the next line of the same level", function()
    assert.same({ 4, 4 }, { outline.subtree(fixture(), 4) })
  end)

  it("takes a whole project but leaves the trailing blank line behind", function()
    assert.same({ 1, 4 }, { outline.subtree(fixture(), 1) })
  end)

  it("takes a leaf as itself", function()
    assert.same({ 3, 3 }, { outline.subtree(fixture(), 3) })
  end)

  it("runs to the end of the buffer when nothing closes it", function()
    assert.same({ 6, 7 }, { outline.subtree(fixture(), 6) })
  end)
end)

describe("taskpaper.outline.shift", function()
  it("indents an item and everything under it", function()
    local got = outline.shift(fixture(), 2, 1)
    assert.equals("\t\t- first", got[2])
    assert.equals("\t\t\t- nested", got[3])
    assert.equals("\t- second", got[4])
  end)

  it("outdents an item and everything under it", function()
    local got = outline.shift(fixture(), 2, -1)
    assert.equals("- first", got[2])
    assert.equals("\t- nested", got[3])
  end)

  it("refuses to outdent past the left margin", function()
    assert.is_nil(outline.shift(fixture(), 1, -1))
  end)
end)

describe("taskpaper.outline.move", function()
  it("swaps an item with its next sibling, carrying both subtrees", function()
    local got, lnum = outline.move(fixture(), 2, "down")
    assert.same({
      "Project A:",
      "\t- second",
      "\t- first",
      "\t\t- nested",
      "",
      "Project B:",
      "\t- other",
    }, got)
    assert.equals(3, lnum)
  end)

  it("swaps an item with its previous sibling", function()
    local got, lnum = outline.move(fixture(), 4, "up")
    assert.same({
      "Project A:",
      "\t- second",
      "\t- first",
      "\t\t- nested",
      "",
      "Project B:",
      "\t- other",
    }, got)
    assert.equals(2, lnum)
  end)

  it("keeps the blank line between two projects where it was", function()
    local got, lnum = outline.move(fixture(), 1, "down")
    assert.same({
      "Project B:",
      "\t- other",
      "",
      "Project A:",
      "\t- first",
      "\t\t- nested",
      "\t- second",
    }, got)
    assert.equals(4, lnum)
  end)

  -- A move with no sibling to swap with is a no-op rather than a reparenting, because
  -- moving an item out of its project is what Move to Project is for.
  it("is a no-op for the first child", function()
    assert.is_nil(outline.move(fixture(), 2, "up"))
  end)

  it("is a no-op for the last child", function()
    assert.is_nil(outline.move(fixture(), 4, "down"))
  end)

  it("does not treat a nephew as a sibling", function()
    assert.is_nil(outline.move(fixture(), 3, "down"))
  end)
end)

describe("taskpaper.outline.projects", function()
  it("lists every project line with its level", function()
    assert.same({
      { lnum = 1, level = 0, text = "Project A:" },
      { lnum = 6, level = 0, text = "Project B:" },
    }, outline.projects(fixture()))
  end)

  it("finds an indented project", function()
    local lines = { "Top:", "\tSub:", "\t\t- task" }
    assert.same({
      { lnum = 1, level = 0, text = "Top:" },
      { lnum = 2, level = 1, text = "\tSub:" },
    }, outline.projects(lines))
  end)

  it("does not mistake a task ending in a colon for a project", function()
    assert.same({}, outline.projects({ "\t- ask about the thing:" }))
  end)
end)

describe("taskpaper.outline.move_to_project", function()
  it("appends the subtree under the target, re-indented to be its child", function()
    local got, lnum = outline.move_to_project(fixture(), 2, 6)
    assert.same({
      "Project A:",
      "\t- second",
      "",
      "Project B:",
      "\t- other",
      "\t- first",
      "\t\t- nested",
    }, got)
    assert.equals(6, lnum)
  end)

  it("works backwards, into a project above the item", function()
    local got, lnum = outline.move_to_project(fixture(), 7, 1)
    assert.same({
      "Project A:",
      "\t- first",
      "\t\t- nested",
      "\t- second",
      "\t- other",
      "",
      "Project B:",
    }, got)
    assert.equals(5, lnum)
  end)

  it("refuses to move an item into its own subtree", function()
    assert.is_nil(outline.move_to_project(fixture(), 1, 1))
  end)
end)

describe("taskpaper.outline.changed_span", function()
  it("narrows to the lines that actually moved", function()
    local before = { "a", "b", "c", "d" }
    local after = { "a", "c", "b", "d" }
    assert.same({ 2, 3 }, { outline.changed_span(before, after) })
  end)

  it("reports nothing for an unchanged list", function()
    assert.is_nil(outline.changed_span({ "a", "b" }, { "a", "b" }))
  end)

  it("covers a single re-indented line", function()
    assert.same({ 2, 2 }, { outline.changed_span({ "a", "\tb" }, { "a", "\t\tb" }) })
  end)
end)

describe("taskpaper.outline.move_targets", function()
  local function fx()
    return {
      "Project A:",
      "\t- first",
      "\t\t- nested",
      "\t- second",
      "",
      "Project B:",
      "\t- other",
    }
  end

  -- The picker should not offer a destination the move would refuse, so the item's own
  -- subtree is filtered out before the list is shown rather than after a choice.
  it("offers both projects for a task, including the one it already sits in", function()
    local got = outline.move_targets(fx(), 2)
    assert.same({ 1, 6 }, vim.tbl_map(function(p) return p.lnum end, got))
  end)

  it("does not offer a project itself as a destination for itself", function()
    local got = outline.move_targets(fx(), 1)
    assert.same({ 6 }, vim.tbl_map(function(p) return p.lnum end, got))
  end)

  it("excludes a nested project that travels with the item", function()
    local lines = { "Top:", "\tSub:", "\t\t- task", "Other:" }
    local got = outline.move_targets(lines, 1)
    assert.same({ 4 }, vim.tbl_map(function(p) return p.lnum end, got))
  end)
end)

-- The app's Focus In and Focus Out, as a pure question: which item is this line inside,
-- and which item is that one inside. Focus is the only feature so far that has to walk
-- *up* the outline.
--
-- These asked about the nearest **project** until 2026-09-17, which made a nested list
-- unfocusable: a task's nearest project is the top-level heading however deep the task
-- sits, so Focus In anywhere inside a nested list jumped straight back to the root. The
-- unit is the item, not the project. IMPLEMENTATION_PLAN.md already said so for the
-- filter ("an ancestor can be a task or a note, not only a project") and focus had
-- narrowed it by mistake.
local function deep_fixture()
  return {
    "Project A:",            -- 1
    "\t- outer list",        -- 2
    "\t\t- middle list",     -- 3
    "\t\t\t- deep one",      -- 4
    "\t\t\t- deep two",      -- 5
    "\t\t- middle two",      -- 6
    "\t- outer two",         -- 7
  }
end

describe("taskpaper.outline.enclosing_item", function()
  it("answers a line that has children with itself", function()
    assert.equals(1, outline.enclosing_item(fixture(), 1))
    assert.equals(6, outline.enclosing_item(fixture(), 6))
  end)

  -- The bug, as reported: focusing at depth 3 has to give the list at depth 2, not the
  -- project at depth 0.
  it("answers a deeply nested line with the list it sits in, not the root", function()
    assert.equals(3, outline.enclosing_item(deep_fixture(), 4))
    assert.equals(3, outline.enclosing_item(deep_fixture(), 5))
  end)

  -- A task with children is a container, so it is its own answer. This is the case the
  -- project-only rule could not express at all.
  it("answers a task that has children with itself", function()
    assert.equals(3, outline.enclosing_item(deep_fixture(), 3))
    assert.equals(2, outline.enclosing_item(deep_fixture(), 2))
  end)

  -- Focusing a leaf would show one line, so a leaf resolves to its container.
  it("answers a leaf with its parent", function()
    assert.equals(2, outline.enclosing_item(deep_fixture(), 6))
    assert.equals(1, outline.enclosing_item(deep_fixture(), 7))
  end)

  it("resolves a blank line to the item it sits in", function()
    local lines = { "Project A:", "\t- first", "", "\t- second" }
    assert.equals(1, outline.enclosing_item(lines, 3))
  end)

  it("has no answer for a top-level leaf, because there is nothing to narrow to", function()
    assert.is_nil(outline.enclosing_item({ "- loose", "Another:" }, 1))
  end)
end)

describe("taskpaper.outline.parent", function()
  it("is the nearest strictly shallower line", function()
    assert.equals(2, outline.parent(deep_fixture(), 3))
    assert.equals(1, outline.parent(deep_fixture(), 2))
  end)

  -- The case a naive upward walk gets wrong: line 6 is a sibling of `- middle list`, so
  -- the walk has to step over that whole subtree rather than stop at its deepest line.
  it("steps over a deeper sibling subtree", function()
    assert.equals(2, outline.parent(deep_fixture(), 6))
  end)

  -- nil is what Focus Out reads as "there is nowhere wider left", which is Go Home.
  it("has no answer for a top-level line", function()
    assert.is_nil(outline.parent(fixture(), 1))
  end)

  it("can be a task rather than a project, which is the whole point", function()
    local lines = { "- a loose parent", "\t- child" }
    assert.equals(1, outline.parent(lines, 2))
  end)
end)
