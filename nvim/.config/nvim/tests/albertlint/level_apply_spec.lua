---Applying model-returned spans to build the corrected buffer.
---
---This module exists so that a level's boundary is an invariant rather than a request: the
---model can only return labeled spans, so it has no channel through which to reorder a clause
---or change tone. Everything here is therefore about placing spans exactly, and the cases
---below are the ones that silently corrupt text when they are wrong.
---
---No `vim.*` and no filesystem in the module under test, so these are string-literal unit
---tests.
local apply = require("albertlint.level.apply")

---@param over table|nil
---@return table
local function fix(over)
  local base = {
    line = 1,
    quote = "use LLM",
    replacement = "calls an LLM",
    label = "Subject-verb agreement",
    note = "`takes` and `use` share the subject `which`.",
  }
  return vim.tbl_extend("force", base, over or {})
end

describe("level.apply build", function()
  it("replaces a single span and reports where it landed", function()
    local lines = { "which takes the text and use LLM" }

    local corrected, placed, dropped = apply.build(lines, 1, { fix({}) })

    assert.same({ "which takes the text and calls an LLM" }, corrected)
    assert.equals(1, #placed)
    assert.equals(0, #dropped)
    assert.equals(1, placed[1].lnum)
    -- 0-indexed byte column of `use`, written as the length of everything before it so
    -- the expected value does not have to be recounted by hand.
    assert.equals(#("which takes the text and "), placed[1].col)
  end)

  it("leaves the original lines untouched", function()
    local lines = { "which takes the text and use LLM" }

    apply.build(lines, 1, { fix({}) })

    -- The caller diffs original against corrected, so mutating the input would
    -- produce an empty diff and look like "no findings".
    assert.same({ "which takes the text and use LLM" }, lines)
  end)

  it("applies two fixes on one line right to left", function()
    -- Applied left to right, the first replacement shifts every later offset on the
    -- line and the second fix lands in the wrong place or fails to match.
    local lines = { "a error and a apple" }

    local corrected, placed = apply.build(lines, 1, {
      fix({ quote = "a error", replacement = "an error" }),
      fix({ quote = "a apple", replacement = "an apple" }),
    })

    assert.same({ "an error and an apple" }, corrected)
    assert.equals(2, #placed)
    -- `placed` is sorted by position, not by the order the model returned them.
    assert.equals(0, placed[1].col)
    assert.equals(12, placed[2].col)
  end)

  it("drops the second of two overlapping spans and says why", function()
    local lines = { "the number of samples need review" }

    local corrected, placed, dropped = apply.build(lines, 1, {
      fix({ quote = "samples need", replacement = "samples needs" }),
      fix({ quote = "need review", replacement = "needs review" }),
    })

    -- Applying half of each would produce text neither the model nor the author wrote.
    assert.same({ "the number of samples needs review" }, corrected)
    assert.equals(1, #placed)
    assert.equals(1, #dropped)
    assert.equals("overlaps an earlier fix", dropped[1].reason)
  end)

  it("drops a fix whose quote is absent instead of guessing", function()
    local lines = { "this line is fine" }

    local corrected, placed, dropped = apply.build(lines, 1, { fix({ quote = "not here" }) })

    assert.same({ "this line is fine" }, corrected)
    assert.equals(0, #placed)
    assert.equals("quote not found", dropped[1].reason)
  end)

  it("resolves occurrence 2 to the second instance, not the first", function()
    -- `line` + `quote` alone cannot say which instance is meant. Taking the first
    -- would be silently wrong half the time.
    local lines = { "a error here and a error there" }

    local corrected = apply.build(lines, 1, {
      fix({ quote = "a error", replacement = "an error", occurrence = 2 }),
    })

    assert.same({ "a error here and an error there" }, corrected)
  end)

  it("defaults a missing occurrence to the first instance", function()
    local lines = { "a error here and a error there" }

    local corrected = apply.build(lines, 1, {
      fix({ quote = "a error", replacement = "an error" }),
    })

    assert.same({ "an error here and a error there" }, corrected)
  end)

  it("drops an occurrence past the last instance rather than clamping", function()
    local lines = { "a error here" }

    local _, placed, dropped = apply.build(lines, 1, {
      fix({ quote = "a error", occurrence = 3 }),
    })

    assert.equals(0, #placed)
    assert.equals("quote not found", dropped[1].reason)
  end)

  it("places a span that follows multibyte text", function()
    -- The author's buffers contain Korean. A character-based offset would misplace
    -- every span after the first multibyte run; Lua string ops are byte-based, and
    -- this test is what pins that they stay so.
    local lines = { "레베카는 a error 라고 했다" }

    local corrected, placed = apply.build(lines, 1, {
      fix({ quote = "a error", replacement = "an error" }),
    })

    assert.same({ "레베카는 an error 라고 했다" }, corrected)
    assert.equals(#("레베카는 "), placed[1].col)
  end)

  it("maps absolute line numbers through start_lnum", function()
    local lines = { "first", "a error", "third" }

    local corrected, placed = apply.build(lines, 1, {
      fix({ line = 2, quote = "a error", replacement = "an error" }),
    })

    assert.same({ "first", "an error", "third" }, corrected)
    assert.equals(2, placed[1].lnum)
  end)

  it("offsets a range that does not start at line 1", function()
    -- A selection-scoped pass hands over a slice, but the model answers with absolute
    -- buffer line numbers, so the module has to subtract start_lnum.
    local lines = { "a error" }

    local corrected, placed = apply.build(lines, 41, {
      fix({ line = 41, quote = "a error", replacement = "an error" }),
    })

    assert.same({ "an error" }, corrected)
    assert.equals(41, placed[1].lnum)
  end)

  it("drops a fix pointing outside the given range", function()
    local lines = { "only one line" }

    local _, placed, dropped = apply.build(lines, 1, { fix({ line = 99 }) })

    assert.equals(0, #placed)
    assert.equals("line out of range", dropped[1].reason)
  end)

  it("returns the lines unchanged for an empty findings list", function()
    -- An empty result is valid and common, and must not error.
    local lines = { "nothing wrong here" }

    local corrected, placed, dropped = apply.build(lines, 1, {})

    assert.same({ "nothing wrong here" }, corrected)
    assert.equals(0, #placed)
    assert.equals(0, #dropped)
  end)

  it("is deterministic in the order it reports dropped fixes", function()
    -- pairs() over a table keyed by line index has no defined order, so a naive
    -- implementation reports drops in a different order run to run, which makes
    -- the user-facing count message unstable and this test flaky.
    local lines = { "line one", "line two", "line three" }
    local fixes = {
      fix({ line = 3, quote = "absent" }),
      fix({ line = 1, quote = "absent" }),
      fix({ line = 2, quote = "absent" }),
    }

    local first, _, d1 = apply.build(lines, 1, fixes)
    local _, _, d2 = apply.build(lines, 1, fixes)

    assert.equals(3, #d1)
    assert.same({ 1, 2, 3 }, { d1[1].fix.line, d1[2].fix.line, d1[3].fix.line })
    assert.same({ d1[1].fix.line, d1[2].fix.line }, { d2[1].fix.line, d2[2].fix.line })
    assert.same({ "line one", "line two", "line three" }, first)
  end)
end)

describe("level.apply note_lines", function()
  it("puts the label on the first line and wraps the note", function()
    local out = apply.note_lines("Article", "One audience exists here so the determiner is obligatory.", 30)

    -- 28 chars, so it fits in 30; adding `here` would make 33 and wrap.
    assert.equals("Article: One audience exists", out[1])
    assert.is_true(#out > 1)
    for _, l in ipairs(out) do
      assert.is_true(#l <= 30)
    end
  end)

  it("never returns zero lines, because the mirror count would be zero", function()
    -- diffview mirrors this count as blank virt_lines on the other side. A zero-line
    -- note would produce an extmark with an empty virt_lines table, which is an error.
    local out = apply.note_lines("", "", 30)

    assert.equals(1, #out)
  end)

  it("does not split a word that is longer than the width", function()
    local out = apply.note_lines("X", "supercalifragilisticexpialidocious", 10)

    local joined = table.concat(out, " ")
    assert.is_true(joined:find("supercalifragilisticexpialidocious", 1, true) ~= nil)
  end)

  it("collapses newlines, because a note line becomes one virtual line", function()
    local out = apply.note_lines("Tense", "first part\n\nsecond part", 80)

    assert.equals(1, #out)
    assert.equals("Tense: first part second part", out[1])
  end)
end)
