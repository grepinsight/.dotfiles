local anchor = require("annotate.anchor")

-- "bite the bullet" sits at row 1, byte cols 16..31 (end exclusive).
local LINES = {
  "line one",
  "we just have to bite the bullet and ship it",
  "line three",
}

local function bullet_mark(overrides)
  return vim.tbl_extend("force", {
    text = "bite the bullet",
    prefix = "we just have to ",
    suffix = " and ship it",
    hint = { start = { 1, 16 }, ["end"] = { 1, 31 } },
  }, overrides or {})
end

---Prepend n filler lines.
local function with_padding(n, lines)
  local out = {}
  for i = 1, n do
    table.insert(out, "pad " .. i)
  end
  vim.list_extend(out, lines)
  return out
end

describe("annotate.anchor.build", function()
  it("captures a charwise single-line selection with its context", function()
    local a = anchor.build(LINES, { 1, 16 }, { 1, 31 }, 16)
    assert.equals("bite the bullet", a.text)
    assert.equals("we just have to ", a.prefix)
    assert.equals(" and ship it\nlin", a.suffix)
    assert.same({ 1, 16 }, a.hint.start)
    assert.same({ 1, 31 }, a.hint["end"])
  end)

  it("captures a selection spanning two lines, joined with a newline", function()
    local a = anchor.build(LINES, { 0, 5 }, { 1, 7 }, 5)
    assert.equals("one\nwe just", a.text)
    assert.equals("line ", a.prefix)
    assert.equals(" have", a.suffix)
  end)

  it("captures a whole linewise paragraph", function()
    local a = anchor.build(LINES, { 0, 0 }, { 2, 10 }, 10)
    assert.equals(table.concat(LINES, "\n"), a.text)
    assert.equals("", a.prefix)
    assert.equals("", a.suffix)
  end)

  it("yields an empty prefix at the start of the buffer", function()
    local a = anchor.build(LINES, { 0, 0 }, { 0, 4 }, 10)
    assert.equals("line", a.text)
    assert.equals("", a.prefix)
    assert.equals(" one\nwe ju", a.suffix)
  end)

  it("yields an empty suffix at the end of the buffer", function()
    local a = anchor.build(LINES, { 2, 5 }, { 2, 10 }, 10)
    assert.equals("three", a.text)
    assert.equals("", a.suffix)
  end)
end)

describe("annotate.anchor.text_at", function()
  it("reads the text at a stored position", function()
    assert.equals("bite the bullet", anchor.text_at(LINES, { start = { 1, 16 }, ["end"] = { 1, 31 } }))
  end)

  it("returns nil for a row past the end of the buffer", function()
    assert.is_nil(anchor.text_at(LINES, { start = { 9, 0 }, ["end"] = { 9, 4 } }))
  end)

  it("returns nil for a column past the end of its line", function()
    assert.is_nil(anchor.text_at(LINES, { start = { 0, 0 }, ["end"] = { 0, 999 } }))
  end)

  it("returns nil for a malformed hint", function()
    assert.is_nil(anchor.text_at(LINES, nil))
    assert.is_nil(anchor.text_at(LINES, { start = { 1, 16 } }))
  end)
end)

describe("annotate.anchor.resolve tier 1", function()
  it("accepts the stored position when the buffer is unchanged", function()
    local range, relocated = anchor.resolve(LINES, bullet_mark())
    assert.same({ 1, 16 }, range.start)
    assert.same({ 1, 31 }, range["end"])
    assert.is_false(relocated)
  end)
end)

describe("annotate.anchor.resolve tier 2", function()
  it("relocates after lines are inserted above", function()
    local range, relocated = anchor.resolve(with_padding(10, LINES), bullet_mark())
    assert.same({ 11, 16 }, range.start)
    assert.same({ 11, 31 }, range["end"])
    assert.is_true(relocated)
  end)

  it("relocates a multi-line mark after lines are inserted above", function()
    local mark = {
      text = "one\nwe just",
      prefix = "line ",
      suffix = " have",
      hint = { start = { 0, 5 }, ["end"] = { 1, 7 } },
    }
    local range = anchor.resolve(with_padding(3, LINES), mark)
    assert.same({ 3, 5 }, range.start)
    assert.same({ 4, 7 }, range["end"])
  end)

  it("picks the occurrence whose context matches, not the nearest one", function()
    local lines = {
      "alpha bite the bullet omega",
      "we just have to bite the bullet and ship it",
      "zeta bite the bullet theta",
    }
    -- Hint row 5 is out of range, so tier 1 cannot fire and proximity favours row 2.
    local range = anchor.resolve(lines, bullet_mark({ hint = { start = { 5, 0 }, ["end"] = { 5, 15 } } }))
    assert.same({ 1, 16 }, range.start)
  end)

  it("breaks a context tie toward the row nearest the hint", function()
    local lines = { "x foo bar x", "x foo bar x" }
    local mark = { text = "foo bar", prefix = "x ", suffix = " x" }

    local near_top = anchor.search(lines, vim.tbl_extend("force", mark, {
      hint = { start = { 0, 2 }, ["end"] = { 0, 9 } },
    }))
    assert.same({ 0, 2 }, near_top.start)

    local near_bottom = anchor.search(lines, vim.tbl_extend("force", mark, {
      hint = { start = { 9, 2 }, ["end"] = { 9, 9 } },
    }))
    assert.same({ 1, 2 }, near_bottom.start)
  end)

  it("breaks a full tie toward the earliest occurrence, deterministically", function()
    local lines = { "x foo bar x", "filler line", "x foo bar x" }
    local mark = {
      text = "foo bar",
      prefix = "x ",
      suffix = " x",
      -- Row 1 is equidistant from rows 0 and 2.
      hint = { start = { 1, 0 }, ["end"] = { 1, 7 } },
    }
    for _ = 1, 5 do
      assert.same({ 0, 2 }, anchor.search(lines, mark).start)
    end
  end)

  it("searches for literal text, not as a Lua pattern", function()
    -- As a pattern, "a.c" would match "abc" on row 0. Plain search must not.
    local lines = { "abc", "a.c" }
    local range = anchor.search(lines, { text = "a.c", prefix = "", suffix = "" })
    assert.same({ 1, 0 }, range.start)
    assert.same({ 1, 3 }, range["end"])
  end)

  it("finds a phrase containing parentheses and asterisks", function()
    local lines = { "prose line", "call foo(x) * 2 here" }
    local range = anchor.search(lines, { text = "foo(x) * 2", prefix = "call ", suffix = " here" })
    assert.same({ 1, 5 }, range.start)
    assert.same({ 1, 15 }, range["end"])
  end)

  it("resolves a match ending exactly at end of line", function()
    local lines = { "the phrase", "next" }
    local range = anchor.search(lines, { text = "phrase", prefix = "the ", suffix = "" })
    assert.same({ 0, 4 }, range.start)
    assert.same({ 0, 10 }, range["end"])
  end)
end)

describe("annotate.anchor.resolve failure", function()
  it("returns nil when the text is gone", function()
    local range, relocated = anchor.resolve({ "nothing here at all" }, bullet_mark())
    assert.is_nil(range)
    assert.is_false(relocated)
  end)

  it("returns nil for an empty or missing text", function()
    assert.is_nil(anchor.search(LINES, { text = "" }))
    assert.is_nil(anchor.search(LINES, {}))
  end)
end)

describe("annotate.anchor.resolve tier 3 (reflow)", function()
  it("finds a phrase that a rewrap split across two lines", function()
    local lines = { "we just have to bite the", "bullet and ship it" }
    local range = anchor.resolve(lines, bullet_mark({ hint = { start = { 9, 0 }, ["end"] = { 9, 15 } } }))
    assert.same({ 0, 16 }, range.start)
    assert.same({ 1, 6 }, range["end"])
  end)

  it("finds a multi-line phrase that a rewrap joined onto one line", function()
    local mark = {
      text = "one\nwe just",
      prefix = "line ",
      suffix = " have",
      hint = { start = { 0, 5 }, ["end"] = { 1, 7 } },
    }
    local range = anchor.resolve({ "line one we just have" }, mark)
    assert.same({ 0, 5 }, range.start)
    assert.same({ 0, 16 }, range["end"])
  end)

  it("tolerates a rewrap that also changed the indentation", function()
    local lines = { "prose", "    bite   the", "      bullet", "more" }
    local range = anchor.search_reflowed(lines, { text = "bite the bullet", prefix = "", suffix = "" })
    assert.same({ 1, 4 }, range.start)
    assert.same({ 2, 12 }, range["end"])
  end)

  it("does not match across a paragraph break", function()
    -- "the" ends one paragraph and "bullet" starts the next; joining them would be a
    -- phantom match, so a blank line stays a hard boundary.
    local range = anchor.search_reflowed({ "ends with the", "", "bullet starts here" }, {
      text = "the bullet",
      prefix = "",
      suffix = "",
    })
    assert.is_nil(range)
  end)

  it("still matches a mark that genuinely spans a paragraph break", function()
    local lines = { "first para end", "", "second para start" }
    local mark = { text = "end\n\nsecond", prefix = "", suffix = "" }
    local range = anchor.search_reflowed(lines, mark)
    assert.same({ 0, 11 }, range.start)
    assert.same({ 2, 6 }, range["end"])
  end)

  it("prefers a literal match over a reflowed one", function()
    local lines = {
      "aaa bite the bullet zzz",
      "and bite the",
      "bullet again",
    }
    local range = anchor.resolve(lines, bullet_mark({ hint = { start = { 9, 0 }, ["end"] = { 9, 15 } } }))
    assert.same({ 0, 4 }, range.start)
    assert.same({ 0, 19 }, range["end"])
  end)

  it("returns nil when the words are gone, not just rewrapped", function()
    assert.is_nil(anchor.search_reflowed({ "nothing like it here" }, bullet_mark()))
    local range, relocated = anchor.resolve({ "nothing like it here" }, bullet_mark())
    assert.is_nil(range)
    assert.is_false(relocated)
  end)
end)
