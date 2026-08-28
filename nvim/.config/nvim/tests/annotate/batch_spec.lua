---Batch mutation and rename retargeting.
---
---`add_many` exists because `add_range` writes the entire store per call, which is right
---for a keypress and quadratic for a generated batch: N marks meant N atomic rewrites plus
---N taken-id scans. `retarget` exists because `BufState.source` was captured once at load
---and there was no `BufFilePost` handler, so after `:saveas` every write went to the store
---keyed by the original path.
local config = require("annotate.config")
local marks = require("annotate.marks")
local store = require("annotate.store")

local FIXTURE = {
  "line one",
  "we just have to bite the bullet and ship it",
  "line three",
}

-- Three non-overlapping ranges on row 1, end columns exclusive. The row is 43 bytes:
-- "we" at 0..2, "bite the bullet" at 16..31, "ship it" at 36..43.
local BULLET = { start = { 1, 16 }, ["end"] = { 1, 31 } }
local WE = { start = { 1, 0 }, ["end"] = { 1, 2 } }
local SHIP = { start = { 1, 36 }, ["end"] = { 1, 43 } }

local function configure()
  config.reset()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local cfg, errors = config.setup({
    storage = { dir = dir },
    export = { path = dir .. "/export.md" },
    clock = function()
      return 1756240980
    end,
  })
  assert(errors == nil, vim.inspect(errors))
  return cfg
end

---@return integer bufnr, string path
local function open_fixture(lines)
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local path = dir .. "/note.md"
  vim.fn.writefile(lines or FIXTURE, path)
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  return vim.api.nvim_get_current_buf(), path
end

local function fresh()
  marks.reset()
  configure()
end

---Count calls to store.write for the duration of `fn`, then restore it.
---@param fn function
---@return integer writes
local function count_writes(fn)
  local real = store.write
  local writes = 0
  store.write = function(...)
    writes = writes + 1
    return real(...)
  end
  local ok, err = pcall(fn)
  store.write = real
  assert(ok, err)
  return writes
end

describe("annotate.marks add_many", function()
  before_each(fresh)

  it("adds every entry and returns them in input order", function()
    local bufnr = open_fixture()

    local records, errors = marks.add_many(bufnr, {
      { range = WE, category = "idiom" },
      { range = BULLET, category = "phrase" },
      { range = SHIP, category = "jargon" },
    })

    assert.equals(0, #errors)
    assert.equals(3, #records)
    assert.equals("we", records[1].text)
    assert.equals("bite the bullet", records[2].text)
    assert.equals("ship it", records[3].text)
  end)

  it("persists exactly once for a batch, not once per entry", function()
    -- The whole reason this function exists. Three marks through add_range would be three
    -- full atomic rewrites of the store.
    local bufnr = open_fixture()

    local writes = count_writes(function()
      marks.add_many(bufnr, {
        { range = WE, category = "idiom" },
        { range = BULLET, category = "phrase" },
        { range = SHIP, category = "jargon" },
      })
    end)

    assert.equals(1, writes)
  end)

  it("mints unique ids within one batch", function()
    local bufnr = open_fixture()

    local records = marks.add_many(bufnr, {
      { range = WE, category = "idiom" },
      { range = BULLET, category = "phrase" },
      { range = SHIP, category = "jargon" },
    })

    -- The clock is pinned, so ids sharing a timestamp must still differ by counter. An
    -- allocator that forgot to record what it minted would collide here.
    local seen = {}
    for _, record in ipairs(records) do
      assert.is_nil(seen[record.id], "duplicate id " .. record.id)
      seen[record.id] = true
    end
    assert.equals(3, vim.tbl_count(seen))
  end)

  it("does not collide with ids already in the store", function()
    local bufnr = open_fixture()
    local first = marks.add_many(bufnr, { { range = WE, category = "idiom" } })
    local second = marks.add_many(bufnr, { { range = BULLET, category = "phrase" } })

    assert.are_not.equals(first[1].id, second[1].id)
  end)

  it("attaches an extmark per added record", function()
    local bufnr = open_fixture()

    local records = marks.add_many(bufnr, {
      { range = WE, category = "idiom" },
      { range = BULLET, category = "phrase" },
    })

    local st = marks.state(bufnr)
    for _, record in ipairs(records) do
      assert.is_number(st.ids[record.id])
    end
  end)

  it("keeps good entries when one entry is bad", function()
    -- Errors are collected rather than fatal: a generated batch with one unusable finding
    -- should not discard the usable ones.
    local bufnr = open_fixture()

    local records, errors = marks.add_many(bufnr, {
      { range = WE, category = "idiom" },
      { range = BULLET, category = "nonsense" },
      { range = SHIP, category = "jargon" },
    })

    assert.equals(2, #records)
    assert.equals(1, #errors)
    assert.is_truthy(errors[1]:match("unknown category"))
  end)

  it("reports an empty selection per entry without failing the batch", function()
    local bufnr = open_fixture()

    local records, errors = marks.add_many(bufnr, {
      { range = { start = { 1, 16 }, ["end"] = { 1, 16 } }, category = "idiom" },
      { range = BULLET, category = "phrase" },
    })

    assert.equals(1, #records)
    assert.equals(1, #errors)
    assert.equals("selection is empty", errors[1])
  end)

  it("does not write when every entry failed", function()
    local bufnr = open_fixture()

    local writes = count_writes(function()
      local records, errors = marks.add_many(bufnr, {
        { range = BULLET, category = "nonsense" },
      })
      assert.equals(0, #records)
      assert.equals(1, #errors)
    end)

    assert.equals(0, writes)
  end)

  it("returns one filetype error for the batch, not one per entry", function()
    config.reset()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    config.setup({ storage = { dir = dir }, filetypes = { "markdown" } })
    local bufnr = open_fixture()
    vim.bo[bufnr].filetype = "python"

    local records, errors = marks.add_many(bufnr, {
      { range = WE, category = "idiom" },
      { range = BULLET, category = "phrase" },
      { range = SHIP, category = "jargon" },
    })

    assert.equals(0, #records)
    assert.equals(1, #errors)
    assert.is_truthy(errors[1]:match("not enabled for filetype"))
  end)

  it("is a no-op for an empty entry list", function()
    local bufnr = open_fixture()

    local writes = count_writes(function()
      local records, errors = marks.add_many(bufnr, {})
      assert.equals(0, #records)
      assert.equals(0, #errors)
    end)

    assert.equals(0, writes)
  end)
end)

describe("annotate.marks add_range after the refactor", function()
  before_each(fresh)

  it("still returns a record and no error on success", function()
    local bufnr = open_fixture()

    local record, err = marks.add_range(bufnr, BULLET, "idiom")

    assert.is_nil(err)
    assert.equals("bite the bullet", record.text)
  end)

  it("still returns nil plus an error for an unknown category", function()
    local bufnr = open_fixture()

    local record, err = marks.add_range(bufnr, BULLET, "nonsense")

    assert.is_nil(record)
    assert.is_truthy(err:match("unknown category"))
  end)

  it("still returns nil plus an error for an empty selection", function()
    local bufnr = open_fixture()

    local record, err =
      marks.add_range(bufnr, { start = { 1, 16 }, ["end"] = { 1, 16 } }, "idiom")

    assert.is_nil(record)
    assert.equals("selection is empty", err)
  end)
end)

describe("annotate.marks retarget", function()
  before_each(fresh)

  it("moves later writes to the new path after a rename", function()
    local bufnr, path = open_fixture()
    marks.add_range(bufnr, BULLET, "idiom")
    local new_path = vim.fn.fnamemodify(path, ":h") .. "/renamed.md"

    vim.cmd("saveas " .. vim.fn.fnameescape(new_path))
    local retargeted = marks.retarget(bufnr)

    assert.is_true(retargeted)
    assert.equals(store.normalize(new_path), marks.state(bufnr).source)
    -- The store for the new path exists, which is what was broken: without retarget the
    -- file the author is now editing has no marks at all.
    assert.is_true(store.exists(new_path))
  end)

  it("leaves the original store alone, because :saveas leaves the original file", function()
    local bufnr, path = open_fixture()
    marks.add_range(bufnr, BULLET, "idiom")
    local new_path = vim.fn.fnamemodify(path, ":h") .. "/renamed.md"

    vim.cmd("saveas " .. vim.fn.fnameescape(new_path))
    marks.retarget(bufnr)

    -- Same content still sits at the old path, so its marks are still true of it.
    assert.is_true(store.exists(path))
    local old_marks = store.read(path)
    assert.equals(1, #old_marks)
  end)

  it("is a no-op when the name did not change", function()
    local bufnr = open_fixture()
    marks.add_range(bufnr, BULLET, "idiom")

    assert.is_false(marks.retarget(bufnr))
  end)

  it("is a no-op for a buffer with no loaded marks", function()
    local bufnr = open_fixture()

    assert.is_false(marks.retarget(bufnr))
  end)
end)

describe("annotate.marks AI lifecycle", function()
  before_each(fresh)

  it("defaults new marks to author user and state active", function()
    local bufnr = open_fixture()

    local record = marks.add_range(bufnr, BULLET, "idiom")

    assert.equals("user", record.author)
    assert.equals("active", record.state)
  end)

  it("accepts allowlisted meta fields", function()
    local bufnr = open_fixture()

    local records, errors = marks.add_many(bufnr, {
      {
        range = BULLET,
        category = "note",
        note = "three facts, no claim",
        meta = {
          author = "llm",
          kind = "no-claim",
          model = "gpt-5.4-nano",
          analyzer = "discourse@1",
          fingerprint = "a1b2c3d4e5f60718",
        },
      },
    })

    assert.equals(0, #errors)
    assert.equals("llm", records[1].author)
    assert.equals("no-claim", records[1].kind)
    assert.equals("discourse@1", records[1].analyzer)
    -- Not overridden, so the default still applies.
    assert.equals("active", records[1].state)
  end)

  it("rejects an unknown meta field loudly", function()
    -- The only way to hit this is a caller typo, which is exactly when silence is worse
    -- than a failure.
    local bufnr = open_fixture()

    local records, errors = marks.add_many(bufnr, {
      { range = BULLET, category = "idiom", meta = { auther = "llm" } },
    })

    assert.equals(0, #records)
    assert.equals(1, #errors)
    assert.is_truthy(errors[1]:match("unknown meta field"))
  end)

  it("normalizes a legacy record with no author or state", function()
    -- A store written before these fields existed must not become invisible under an exact
    -- state == "active" render test.
    local bufnr, path = open_fixture()
    marks.add_range(bufnr, BULLET, "idiom")
    local stored = store.read(path)
    stored[1].author = nil
    stored[1].state = nil
    store.write(path, stored)

    marks.reset()
    marks.load(bufnr)

    local record = marks.state(bufnr).marks[1]
    assert.equals("user", record.author)
    assert.equals("active", record.state)
    -- And it still renders: it has an extmark.
    assert.is_number(marks.state(bufnr).ids[record.id])
  end)

  it("does not render a dismissed mark", function()
    local bufnr = open_fixture()
    local records = marks.add_many(bufnr, {
      { range = BULLET, category = "note", note = "x", meta = { author = "llm", state = "dismissed" } },
    })

    marks.rebuild(bufnr)

    assert.is_nil(marks.state(bufnr).ids[records[1].id])
  end)

  it("dismisses a machine finding and keeps the record as a tombstone", function()
    local bufnr = open_fixture()
    local records = marks.add_many(bufnr, {
      { range = BULLET, category = "note", note = "x", meta = { author = "llm", kind = "no-claim" } },
    })
    vim.api.nvim_win_set_cursor(0, { 2, 20 })

    local ok = marks.dismiss_at_cursor(bufnr)

    assert.is_true(ok)
    -- The record survives, because it is what suppresses the next pass re-raising it.
    assert.equals(1, #marks.state(bufnr).marks)
    assert.equals("dismissed", marks.state(bufnr).marks[1].state)
    assert.is_nil(marks.state(bufnr).ids[records[1].id])
  end)

  it("refuses to dismiss a user mark", function()
    -- Nothing to suppress, and the author's own annotation should be deleted or edited.
    local bufnr = open_fixture()
    marks.add_range(bufnr, BULLET, "idiom")
    vim.api.nvim_win_set_cursor(0, { 2, 20 })

    local ok = marks.dismiss_at_cursor(bufnr)

    assert.is_false(ok)
    assert.equals("active", marks.state(bufnr).marks[1].state)
  end)

  it("is idempotent when the finding is already dismissed", function()
    local bufnr = open_fixture()
    marks.add_many(bufnr, {
      { range = BULLET, category = "note", note = "x", meta = { author = "llm", state = "dismissed" } },
    })
    vim.api.nvim_win_set_cursor(0, { 2, 20 })

    assert.is_false(marks.dismiss_at_cursor(bufnr))
    assert.equals(1, #marks.state(bufnr).marks)
  end)
end)
