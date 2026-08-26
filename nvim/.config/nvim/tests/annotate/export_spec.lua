local config = require("annotate.config")
local export = require("annotate.export")
local store = require("annotate.store")

local ctx = {}

local function tmpdir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  return dir
end

local function fresh()
  config.reset()
  ctx.store_dir = tmpdir()
  ctx.vault = tmpdir()
  ctx.notes = ctx.vault .. "/03-Resources/English"
  vim.fn.mkdir(ctx.notes, "p")
  ctx.export_path = ctx.notes .. "/Marked Phrases.md"

  -- util.vault reads $OBSIDIAN_VAULT, so point it at a scratch vault to keep the
  -- wiki-link branch testable without touching the real one.
  ctx.saved_vault = vim.env.OBSIDIAN_VAULT
  vim.env.OBSIDIAN_VAULT = ctx.vault

  local _, errors = config.setup({
    storage = { dir = ctx.store_dir },
    export = { path = ctx.export_path },
    clock = function()
      return 1756240980
    end,
  })
  assert(errors == nil, vim.inspect(errors))
end

local function restore()
  vim.env.OBSIDIAN_VAULT = ctx.saved_vault
end

local function mark(overrides)
  return vim.tbl_extend("force", {
    id = "1-1",
    category = "idiom",
    text = "bite the bullet",
    prefix = "we just have to ",
    suffix = " and ship it",
    hint = { start = { 40, 16 }, ["end"] = { 40, 31 } },
    created_at = "2026-08-26T14:03:00-07:00",
    orphaned = false,
  }, overrides or {})
end

---Create a note inside the scratch vault and give it marks.
local function seed(name, marks)
  local path = ctx.notes .. "/" .. name
  vim.fn.writefile({ "prose" }, path)
  store.write(path, marks)
  return path
end

local function read_export()
  return vim.fn.readfile(ctx.export_path)
end

local function joined()
  return table.concat(read_export(), "\n")
end

local function count(haystack, needle)
  local n = 0
  local at = 1
  while true do
    local found = haystack:find(needle, at, true)
    if not found then
      return n
    end
    n = n + 1
    at = found + 1
  end
end

describe("annotate.export grouping", function()
  before_each(fresh)
  after_each(restore)

  it("groups marks under category headings in configured order", function()
    seed("A.md", {
      mark({ id = "1-1", category = "jargon", text = "backpressure" }),
      mark({ id = "1-2", category = "idiom", text = "bite the bullet" }),
    })

    local ok, err = export.run()
    assert.is_true(ok)
    assert.is_nil(err)

    local text = joined()
    local idiom_at = text:find("## Idiom", 1, true)
    local jargon_at = text:find("## Jargon", 1, true)
    assert.is_truthy(idiom_at)
    assert.is_truthy(jargon_at)
    -- idiom has order 1, jargon order 2.
    assert.is_true(idiom_at < jargon_at)
  end)

  it("excludes orphaned marks but still counts them", function()
    seed("A.md", {
      mark({ id = "1-1", text = "kept phrase" }),
      mark({ id = "1-2", text = "lost phrase", orphaned = true }),
    })

    local _, _, stats = export.run()
    assert.equals(1, stats.marks)
    assert.equals(1, stats.orphans)

    local text = joined()
    assert.is_truthy(text:find("kept phrase", 1, true))
    assert.is_nil(text:find("lost phrase", 1, true))
  end)

  it("emits marks whose category is no longer configured", function()
    seed("A.md", { mark({ category = "retired_category", text = "orphan category phrase" }) })
    export.run()
    local text = joined()
    assert.is_truthy(text:find("## retired_category", 1, true))
    assert.is_truthy(text:find("orphan category phrase", 1, true))
  end)

  it("writes a placeholder when there is nothing to export", function()
    local ok = export.run()
    assert.is_true(ok)
    local text = joined()
    assert.is_truthy(text:find("No marks yet", 1, true))
    assert.equals(1, count(text, export.BEGIN))
  end)
end)

describe("annotate.export entry rendering", function()
  before_each(fresh)
  after_each(restore)

  it("quotes the phrase in its sentence, emphasised", function()
    seed("A.md", { mark() })
    export.run()
    assert.is_truthy(joined():find("we just have to **bite the bullet** and ship it", 1, true))
  end)

  it("marks a truncated context with an ellipsis on the truncated side only", function()
    seed("A.md", {
      mark({
        prefix = string.rep("x", config.get().context_chars),
        suffix = " short",
      }),
    })
    export.run()
    local text = joined()
    assert.is_truthy(text:find("...", 1, true))
    assert.is_nil(text:find("short...", 1, true))
  end)

  it("includes an attached note", function()
    seed("A.md", { mark({ note = "use when a decision is overdue" }) })
    export.run()
    assert.is_truthy(joined():find("note: use when a decision is overdue", 1, true))
  end)

  it("links vault sources with a wiki link", function()
    seed("Bat a Thousand.md", { mark() })
    export.run()
    assert.is_truthy(joined():find("[[Bat a Thousand]]", 1, true))
  end)

  it("links non-vault sources with a plain markdown link", function()
    local outside = tmpdir() .. "/README.md"
    vim.fn.writefile({ "prose" }, outside)
    store.write(outside, { mark() })
    export.run()
    local text = joined()
    assert.is_nil(text:find("[[README]]", 1, true))
    assert.is_truthy(text:find("[README.md](", 1, true))
  end)

  it("collapses a multi-line phrase onto one quote line", function()
    seed("A.md", { mark({ text = "first half\nsecond half" }) })
    export.run()
    local text = joined()
    assert.is_truthy(text:find("**first half second half**", 1, true))
  end)
end)

describe("annotate.export splicing", function()
  before_each(fresh)
  after_each(restore)

  it("replaces the generated block instead of appending a second one", function()
    seed("A.md", { mark() })
    export.run()
    export.run()
    local text = joined()
    assert.equals(1, count(text, export.BEGIN))
    assert.equals(1, count(text, export.END))
  end)

  it("is byte-stable across regenerations", function()
    seed("A.md", { mark(), mark({ id = "1-2", category = "jargon", text = "backpressure" }) })
    export.run()
    local first = joined()
    export.run()
    assert.equals(first, joined())
  end)

  it("preserves content written outside the delimiters", function()
    vim.fn.writefile({
      "---",
      "tags: [english]",
      "---",
      "# My Own Title",
      "",
      "A paragraph I wrote by hand.",
    }, ctx.export_path)

    seed("A.md", { mark() })
    export.run()
    seed("B.md", { mark({ id = "2-1", text = "second phrase" }) })
    export.run()

    local text = joined()
    assert.is_truthy(text:find("tags: [english]", 1, true))
    assert.is_truthy(text:find("# My Own Title", 1, true))
    assert.is_truthy(text:find("A paragraph I wrote by hand.", 1, true))
    assert.is_truthy(text:find("second phrase", 1, true))
    assert.equals(1, count(text, export.BEGIN))
  end)

  it("appends rather than guessing when a delimiter is unmatched", function()
    local existing = { "# Title", "", export.BEGIN, "half written" }
    local out = export.splice(existing, { export.BEGIN, "fresh", export.END })
    assert.equals("half written", out[4])
    assert.equals(2, count(table.concat(out, "\n"), export.BEGIN))
  end)

  it("creates a title when the target file is empty", function()
    local out = export.splice({}, { export.BEGIN, "body", export.END })
    assert.equals("# Marked Phrases", out[1])
  end)
end)
