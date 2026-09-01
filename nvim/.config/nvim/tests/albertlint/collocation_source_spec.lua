---The loader, the cache fingerprint, and the cmp source's text edits.
---
---These use a temp directory of fixture notes rather than the real vault, so they do not
---depend on what is currently collected. The `index.lua` tests cover ranking; these cover the
---parts that touch the filesystem and the parts that decide what actually gets typed into the
---buffer, which is where a wrong answer is most visible.
local col = require("albertlint.collocation")

---@return string root
local function fixture_vault()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/Phrases", "p")
  vim.fn.mkdir(root .. "/Better English", "p")

  vim.fn.writefile({
    "---",
    "title: Pushback",
    "aliases:",
    "  - pushback",
    "  - push back",
    'phrase_definition: "resistance offered in good faith"',
    'phrase_synonyms: "resistance, objections"',
    'phrase_canonical_example: "I want the AI to give me pushback, not fix my grammar."',
    "---",
  }, root .. "/Phrases/Pushback.md")

  vim.fn.writefile({
    "---",
    'title: "A One-Off"',
    "aliases:",
    "  - a one-off",
    'phrase_definition: "something done only once"',
    "---",
  }, root .. "/Phrases/A One-Off.md")

  vim.fn.writefile({
    "---",
    "title: Surface Whatever Needs My Attention",
    'be_replacement: "surface whatever needs my attention"',
    "be_why: One verb replaces a circumlocution.",
    "---",
  }, root .. "/Better English/Surface.md")

  return root
end

---@param root string
local function configure(root)
  package.loaded["albertlint.collocation"] = nil
  col = require("albertlint.collocation")
  col.config.root = root
  -- Per-test cache file, so one test's cache cannot answer another's query. Set through
  -- config rather than by patching `vim.fn.stdpath`: the first version of this helper
  -- wrapped that global and never restored it, so every call nested another closure and
  -- the patch outlived the test into whatever ran next in the same Neovim.
  col.config.cache_path = vim.fn.tempname() .. ".json"
  return col
end

---@param before string
---@return table[] items
local function complete(before)
  local items
  col.source:complete({
    context = { cursor_before_line = before, cursor = { row = 3 } },
  }, function(res)
    items = res.items
  end)
  return items
end

---Apply an item's textEdit to the line it came from, which is what the buffer would show.
---@param before string
---@param item table
---@return string
local function applied(before, item)
  local r = item.textEdit.range
  return before:sub(1, r.start.character) .. item.textEdit.newText
end

describe("collocation loader", function()
  it("indexes every note under both source directories", function()
    configure(fixture_vault())

    local entries = col.entries(true)

    local surfaces = vim.tbl_map(function(e)
      return e.lower
    end, entries)
    assert.is_truthy(vim.tbl_contains(surfaces, "pushback"))
    assert.is_truthy(vim.tbl_contains(surfaces, "a one-off"))
    assert.is_truthy(vim.tbl_contains(surfaces, "surface whatever needs my attention"))
  end)

  it("tags entries by directory, not by which fields are filled in", function()
    configure(fixture_vault())

    local by_lower = {}
    for _, e in ipairs(col.entries(true)) do
      by_lower[e.lower] = e
    end

    assert.equals("phrase", by_lower["pushback"].kind)
    assert.equals("better-english", by_lower["surface whatever needs my attention"].kind)
  end)

  it("changes its fingerprint when a note is added", function()
    local root = fixture_vault()
    configure(root)
    local _, first = col._scan()

    vim.fn.writefile({ "---", "title: Churn Through", "---" }, root .. "/Phrases/Churn.md")
    local _, second = col._scan()

    assert.are_not.equals(first, second)
  end)

  it("changes its fingerprint when a note is REMOVED", function()
    -- The case a max-mtime cache misses: deleting a note does not move the newest
    -- timestamp, so a mtime-only cache would keep serving the deleted phrase forever.
    local root = fixture_vault()
    configure(root)
    local _, first = col._scan()

    vim.fn.delete(root .. "/Phrases/Pushback.md")
    local _, second = col._scan()

    assert.are_not.equals(first, second)
  end)

  it("changes its fingerprint when a note's content changes", function()
    local root = fixture_vault()
    configure(root)
    local _, first = col._scan()

    vim.fn.writefile({ "---", "title: Pushback", "aliases:", "  - shove back", "---" },
      root .. "/Phrases/Pushback.md")
    local _, second = col._scan()

    assert.are_not.equals(first, second)
  end)

  it("survives a missing vault directory rather than erroring", function()
    configure(vim.fn.tempname() .. "/does-not-exist")

    assert.equals(0, #col.entries(true))
  end)

  it("rebuilds rather than erroring on a corrupt cache", function()
    -- Derived data: the source of truth is on disk, so a bad cache is a rebuild. The
    -- opposite of annotate's store, which holds the only copy and refuses instead.
    configure(fixture_vault())
    col.entries(true)
    local fd = io.open(col._cache_path(), "w")
    fd:write("{ not json")
    fd:close()

    local root, cache = col.config.root, col.config.cache_path
    package.loaded["albertlint.collocation"] = nil
    local reloaded = require("albertlint.collocation")
    reloaded.config.root, reloaded.config.cache_path = root, cache

    assert.is_true(#reloaded.entries() > 0)
  end)
end)

describe("collocation cmp source", function()
  before_each(function()
    configure(fixture_vault())
    col.entries(true)
  end)

  it("is available only in configured prose filetypes", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_win_set_buf(0, buf)

    vim.bo[buf].filetype = "markdown"
    assert.is_true(col.source:is_available())

    vim.bo[buf].filetype = "python"
    assert.is_false(col.source:is_available())
  end)

  it("replaces the matched prefix, not just the current keyword", function()
    -- Without a textEdit spanning the match, accepting `pushback` after typing
    -- `give me push` yields `give me pushpushback`.
    local items = complete("I need push")

    assert.is_true(#items > 0)
    assert.equals("I need pushback", applied("I need push", items[1]))
  end)

  it("replaces a multi-word matched prefix", function()
    local items = complete("it was a one")

    assert.equals("a one", items[1].filterText)
    assert.equals("it was a one-off", applied("it was a one", items[1]))
  end)

  it("lowercases the tail when the typed text is lowercase", function()
    -- Notes are titled in Title Case because a title is a heading. Inserting `A One-Off`
    -- mid-sentence is wrong, and it is what the first version did.
    local items = complete("it was a one")

    assert.equals("it was a one-off", applied("it was a one", items[1]))
    assert.is_falsy(applied("it was a one", items[1]):find("One%-Off"))
  end)

  it("leaves case alone when the typed text carries a capital", function()
    -- A capital is the author signalling a sentence start.
    local items = complete("Push")

    assert.equals("Pushback", applied("Push", items[1]))
  end)

  it("offers nothing below min_chars", function()
    assert.equals(0, #complete("p"))
  end)

  it("marks the result incomplete so cmp re-queries as more is typed", function()
    -- The candidate set changes shape when a second word arrives; a cached one-shot result
    -- would not reflect that.
    local got
    col.source:complete({
      context = { cursor_before_line = "push", cursor = { row = 1 } },
    }, function(res)
      got = res
    end)

    assert.is_true(got.isIncomplete)
  end)

  it("attaches the definition and example as documentation", function()
    local items = complete("I need push")

    local doc = items[1].documentation.value
    assert.is_truthy(doc:find("resistance", 1, true))
    assert.equals("markdown", items[1].documentation.kind)
  end)
end)

describe("collocation cmp source position encoding", function()
  before_each(function()
    configure(fixture_vault())
    col.entries(true)
  end)

  it("declares utf-8, because the ranges it builds are byte offsets", function()
    -- cmp defaults an unimplemented source to UTF16 (cmp/source.lua:275) and then runs the
    -- range through vim.str_byteindex. Under the default it would translate an already
    -- correct byte offset and misplace the edit.
    assert.equals("utf-8", col.source:get_position_encoding_kind())
  end)

  it("builds a byte-correct range on a line with multibyte text before the cursor", function()
    -- The case the default encoding would break. Korean before the cursor, and the range
    -- must still describe bytes, so byte-slicing the line reproduces exactly what was typed.
    local before = "그래서 I need push"
    local items = complete(before)

    assert.is_true(#items > 0)
    local r = items[1].textEdit.range
    assert.equals("push", before:sub(r.start.character + 1, r["end"].character))
    assert.equals("그래서 I need pushback", applied(before, items[1]))
  end)

  it("keeps the range byte-correct for a multi-word match after multibyte text", function()
    local before = "음… it was a one"
    local items = complete(before)

    local r = items[1].textEdit.range
    assert.equals("a one", before:sub(r.start.character + 1, r["end"].character))
    assert.equals("음… it was a one-off", applied(before, items[1]))
  end)
end)

describe("collocation menu presentation", function()
  before_each(function()
    configure(fixture_vault())
    col.entries(true)
  end)

  it("labels the item with what accepting will insert, not the note's title", function()
    -- A menu that disagrees with its own result teaches the user to distrust it. The note is
    -- titled `A One-Off`, so the menu used to offer that mid-sentence while accepting
    -- inserted `a one-off`.
    local before = "it was a one"
    local items = complete(before)

    assert.equals("a one-off", items[1].label)
    assert.equals(applied(before, items[1]), before:sub(1, #before - #items[1].filterText) .. items[1].label)
  end)

  it("still labels with a capital when the typed text has one", function()
    local items = complete("Push")

    assert.equals("Pushback", items[1].label)
  end)

  it("puts no marker on phrase entries and marks only the Better English ones", function()
    -- "phrase" would repeat on 409 of 416 rows and say nothing.
    local phrase = complete("I need push")[1]
    local swap = complete("please sur")[1]

    assert.is_nil(phrase.labelDetails)
    assert.equals("preferred replacement", swap.labelDetails.description)
  end)

  it("orders documentation as definition, then example, then synonyms", function()
    -- Meaning and usage answer "is this the right word here?", which is the question being
    -- asked mid-sentence. A list of alternatives answers a later one.
    local doc = complete("I need push")[1].documentation.value
    local definition = doc:find("resistance offered", 1, true)
    local example = doc:find("> I want the AI", 1, true)
    local synonyms = doc:find("**Also:**", 1, true)

    assert.is_truthy(definition, "definition missing")
    assert.is_truthy(example, "example missing")
    assert.is_truthy(synonyms, "synonyms missing")
    assert.is_true(definition < example, "definition must come before the example")
    assert.is_true(example < synonyms, "example must come before the synonyms")
  end)
end)
