local config = require("annotate.config")
local marks = require("annotate.marks")
local store = require("annotate.store")

local uv = vim.uv or vim.loop

-- "bite the bullet" sits at row 1, byte cols 16..31 (end exclusive).
local FIXTURE = {
  "line one",
  "we just have to bite the bullet and ship it",
  "line three",
}
local BULLET = { start = { 1, 16 }, ["end"] = { 1, 31 } }

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

---Open a real on-disk file, since a buffer with no name has nowhere to store marks.
---@return integer bufnr, string path
local function open_fixture(lines)
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local path = dir .. "/note.md"
  vim.fn.writefile(lines or FIXTURE, path)
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  return vim.api.nvim_get_current_buf(), path
end

local function extmark_for(bufnr, record)
  local st = marks.state(bufnr)
  local id = st.ids[record.id]
  if not id then
    return nil
  end
  local found = vim.api.nvim_buf_get_extmark_by_id(bufnr, marks.namespace(), id, { details = true })
  if not found or #found == 0 then
    return nil
  end
  return { row = found[1], col = found[2], end_row = found[3].end_row, end_col = found[3].end_col }
end

local function fresh()
  marks.reset()
  configure()
end

describe("annotate.marks add", function()
  before_each(fresh)

  it("records the anchor and creates an extmark", function()
    local bufnr = open_fixture()
    local record, err = marks.add_range(bufnr, BULLET, "idiom")

    assert.is_nil(err)
    assert.equals("bite the bullet", record.text)
    assert.equals("idiom", record.category)
    -- context_chars defaults to 40, so the prefix reaches back past the line break.
    assert.equals("line one\nwe just have to ", record.prefix)
    assert.is_false(record.orphaned)

    local extmark = extmark_for(bufnr, record)
    assert.same({ row = 1, col = 16, end_row = 1, end_col = 31 }, extmark)
  end)

  it("persists to the store immediately, without waiting for a buffer write", function()
    local bufnr, path = open_fixture()
    marks.add_range(bufnr, BULLET, "jargon")

    assert.is_truthy(uv.fs_stat(store.store_path(path)))
    local stored = store.read(path)
    assert.equals(1, #stored)
    assert.equals("jargon", stored[1].category)
  end)

  it("keeps an attached note", function()
    local bufnr = open_fixture()
    local record = marks.add_range(bufnr, BULLET, "note", "use when a decision is overdue")
    assert.equals("use when a decision is overdue", record.note)
    assert.equals("use when a decision is overdue", store.read(record and marks.state(bufnr).source)[1].note)
  end)

  it("rejects an unknown category", function()
    local bufnr = open_fixture()
    local record, err = marks.add_range(bufnr, BULLET, "nonsense")
    assert.is_nil(record)
    assert.is_truthy(err:match("unknown category"))
  end)

  it("refuses a buffer with no file name", function()
    local bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, FIXTURE)
    vim.api.nvim_set_current_buf(bufnr)
    local record, err = marks.add_range(bufnr, BULLET, "idiom")
    assert.is_nil(record)
    assert.is_truthy(err:match("no file name"))
  end)

  it("refuses an empty selection", function()
    local bufnr = open_fixture()
    local record, err = marks.add_range(bufnr, { start = { 1, 16 }, ["end"] = { 1, 16 } }, "idiom")
    assert.is_nil(record)
    assert.is_truthy(err:match("empty"))
  end)
end)

describe("annotate.marks extmark tracking", function()
  before_each(fresh)

  it("follows the text when lines are inserted above", function()
    local bufnr = open_fixture()
    local record = marks.add_range(bufnr, BULLET, "idiom")

    local pad = {}
    for i = 1, 10 do
      pad[i] = "pad " .. i
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, pad)

    local extmark = extmark_for(bufnr, record)
    assert.equals(11, extmark.row)
    assert.equals(16, extmark.col)
  end)

  it("follows the text when it shifts on its own line", function()
    local bufnr = open_fixture()
    local record = marks.add_range(bufnr, BULLET, "idiom")
    vim.api.nvim_buf_set_text(bufnr, 1, 0, 1, 0, { "REALLY " })

    local extmark = extmark_for(bufnr, record)
    assert.equals(1, extmark.row)
    assert.equals(23, extmark.col)
  end)
end)

describe("annotate.marks sync", function()
  before_each(fresh)

  it("refreshes the stored hint after the mark shifts", function()
    local bufnr, path = open_fixture()
    marks.add_range(bufnr, BULLET, "idiom")

    vim.api.nvim_buf_set_text(bufnr, 1, 0, 1, 0, { "REALLY " })
    marks.sync(bufnr)

    local stored = store.read(path)
    assert.same({ 1, 23 }, stored[1].hint.start)
    assert.same({ 1, 38 }, stored[1].hint["end"])
    assert.is_false(stored[1].orphaned)
  end)

  it("never overwrites the stored text from the extmark", function()
    local bufnr, path = open_fixture()
    marks.add_range(bufnr, BULLET, "idiom")

    -- Edit inside the marked range: "the" -> "THE". The extmark survives but its text
    -- is now a fragment, which must not become the anchor.
    vim.api.nvim_buf_set_text(bufnr, 1, 21, 1, 24, { "THE" })
    marks.sync(bufnr)

    local stored = store.read(path)
    assert.equals("bite the bullet", stored[1].text)
    assert.is_true(stored[1].orphaned)
  end)

  it("orphans a mark whose line was deleted", function()
    local bufnr, path = open_fixture()
    marks.add_range(bufnr, BULLET, "idiom")

    vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, {})
    marks.sync(bufnr)

    local stored = store.read(path)
    assert.is_true(stored[1].orphaned)
    assert.equals("bite the bullet", stored[1].text)
  end)

  it("re-adopts a mark when its text reappears", function()
    local bufnr, path = open_fixture()
    marks.add_range(bufnr, BULLET, "idiom")

    vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, {})
    marks.sync(bufnr)
    assert.is_true(store.read(path)[1].orphaned)

    vim.api.nvim_buf_set_lines(bufnr, 1, 1, false, { FIXTURE[2] })
    marks.sync(bufnr)

    local stored = store.read(path)
    assert.is_false(stored[1].orphaned)
    assert.same({ 1, 16 }, stored[1].hint.start)
  end)
end)

describe("annotate.marks load", function()
  before_each(fresh)

  it("restores marks and highlights them on reload", function()
    local bufnr, path = open_fixture()
    marks.add_range(bufnr, BULLET, "idiom")

    marks.reset()
    marks.load(bufnr)

    local st = marks.state(bufnr)
    assert.equals(1, #st.marks)
    assert.equals("bite the bullet", st.marks[1].text)
    local extmark = extmark_for(bufnr, st.marks[1])
    assert.same({ row = 1, col = 16, end_row = 1, end_col = 31 }, extmark)
    assert.equals(store.normalize(path), st.source)
  end)

  it("relocates a mark when the file changed while it was closed", function()
    local bufnr, path = open_fixture()
    marks.add_range(bufnr, BULLET, "idiom")
    marks.reset()

    -- Simulate an edit made elsewhere, for example in Obsidian.
    local shifted = { "brand new heading", "", FIXTURE[1], FIXTURE[2], FIXTURE[3] }
    vim.fn.writefile(shifted, path)
    vim.cmd("edit! " .. vim.fn.fnameescape(path))
    bufnr = vim.api.nvim_get_current_buf()
    marks.load(bufnr)

    local st = marks.state(bufnr)
    local extmark = extmark_for(bufnr, st.marks[1])
    assert.equals(3, extmark.row)
    assert.equals(16, extmark.col)
  end)

  it("orphans a mark whose text is gone from the file", function()
    local bufnr, path = open_fixture()
    marks.add_range(bufnr, BULLET, "idiom")
    marks.reset()

    vim.fn.writefile({ "completely different content" }, path)
    vim.cmd("edit! " .. vim.fn.fnameescape(path))
    bufnr = vim.api.nvim_get_current_buf()
    marks.load(bufnr)

    local st = marks.state(bufnr)
    assert.is_true(st.marks[1].orphaned)
    assert.is_nil(extmark_for(bufnr, st.marks[1]))
  end)
end)

describe("annotate.marks cursor operations", function()
  before_each(fresh)

  it("finds the innermost mark under the cursor", function()
    local bufnr = open_fixture()
    marks.add_range(bufnr, { start = { 1, 0 }, ["end"] = { 1, 43 } }, "phrase")
    marks.add_range(bufnr, BULLET, "idiom")

    vim.api.nvim_win_set_cursor(0, { 2, 20 })
    local found = marks.at_cursor(bufnr)
    assert.equals("idiom", found.category)
    assert.equals("bite the bullet", found.text)
  end)

  it("returns nil when the cursor is outside every mark", function()
    local bufnr = open_fixture()
    marks.add_range(bufnr, BULLET, "idiom")
    vim.api.nvim_win_set_cursor(0, { 1, 2 })
    assert.is_nil(marks.at_cursor(bufnr))
  end)

  it("deletes the mark under the cursor and clears the store", function()
    local bufnr, path = open_fixture()
    marks.add_range(bufnr, BULLET, "idiom")
    vim.api.nvim_win_set_cursor(0, { 2, 20 })

    marks.delete_at_cursor(bufnr)

    assert.equals(0, #marks.state(bufnr).marks)
    assert.is_nil(uv.fs_stat(store.store_path(path)))
    assert.equals(0, #vim.api.nvim_buf_get_extmarks(bufnr, marks.namespace(), 0, -1, {}))
  end)
end)

describe("annotate.marks visibility", function()
  before_each(fresh)

  it("hides and restores highlights without touching the records", function()
    local bufnr = open_fixture()
    marks.add_range(bufnr, BULLET, "idiom")

    marks.toggle(bufnr)
    assert.equals(0, #vim.api.nvim_buf_get_extmarks(bufnr, marks.namespace(), 0, -1, {}))
    assert.equals(1, #marks.state(bufnr).marks)

    marks.toggle(bufnr)
    assert.equals(1, #vim.api.nvim_buf_get_extmarks(bufnr, marks.namespace(), 0, -1, {}))
  end)
end)

describe("annotate.marks selection guard", function()
  before_each(fresh)

  it("reports no selection when not in visual mode", function()
    open_fixture()
    local range, err = marks._selection()
    assert.is_nil(range)
    assert.is_truthy(err:match("no visual selection"))
  end)
end)
