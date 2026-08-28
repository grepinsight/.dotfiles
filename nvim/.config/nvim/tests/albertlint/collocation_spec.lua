---Collocation index: frontmatter parsing, entry building, and candidate ranking.
---
---Pure-string tests, no filesystem and no editor state, because the ranking rules are the
---part most likely to be wrong and the part a buffer test would obscure.
local index = require("albertlint.collocation.index")

local PUSHBACK = [[---
title: Pushback
aliases:
  - pushback
  - push back
  - 반박
phrase_id: "156"
phrase_definition: "resistance or disagreement offered in response to a proposal"
phrase_synonyms: "resistance, objections, a counterargument"
phrase_canonical_example: "I want the AI to give me pushback, not just fix my grammar."
---
# Pushback
]]

local ONE_OFF = [[---
title: "A One-Off"
aliases:
  - a one-off
  - one-off
phrase_id: "25"
phrase_definition: "something done only once and that will not recur"
phrase_synonyms: "one-time, non-recurring"
phrase_canonical_example: "Yeah, but that's a one-off."
---
]]

local LEAD = [[---
title: Lead With the Action
be_kind: guidance
be_replacement: "Check the daily notes: when did I ask which skills I have?"
be_originals:
  - "when did i ask you about what skills i have to learn a topic? check daily notes"
be_why: The instruction is what the reader acts on, so it goes first.
---
]]

local function notes(...)
  local out = {}
  for _, text in ipairs({ ... }) do
    table.insert(out, { text = text, path = "/tmp/note.md" })
  end
  return out
end

describe("collocation parse_frontmatter", function()
  it("reads scalars and unquotes them", function()
    local f = index.parse_frontmatter(ONE_OFF)

    assert.equals("A One-Off", f.title)
    assert.equals("25", f.phrase_id)
  end)

  it("reads a list into a table", function()
    local f = index.parse_frontmatter(PUSHBACK)

    assert.equals("table", type(f.aliases))
    assert.equals(3, #f.aliases)
    assert.equals("push back", f.aliases[2])
  end)

  it("returns an empty table for a note with no frontmatter", function()
    assert.same({}, index.parse_frontmatter("# Just a heading\n"))
  end)

  it("leaves a key with no value as an empty list, not nil", function()
    -- So callers never have to branch on the shape.
    local f = index.parse_frontmatter("---\naliases:\ntitle: X\n---\n")

    assert.equals("table", type(f.aliases))
    assert.equals(0, #f.aliases)
  end)

  it("stops at the closing delimiter", function()
    local f = index.parse_frontmatter("---\ntitle: X\n---\ntitle: NOT THIS\n")

    assert.equals("X", f.title)
  end)
end)

describe("collocation build", function()
  it("makes one entry per surface form, not per note", function()
    -- `Pushback` plus two English aliases. The author may reach for either form.
    local entries = index.build(notes(PUSHBACK))

    local surfaces = vim.tbl_map(function(e)
      return e.surface
    end, entries)
    assert.is_truthy(vim.tbl_contains(surfaces, "Pushback"))
    assert.is_truthy(vim.tbl_contains(surfaces, "push back"))
  end)

  it("deduplicates a surface that repeats the title", function()
    -- `title: Pushback` and `aliases: [pushback, ...]` differ only in case.
    local entries = index.build(notes(PUSHBACK))
    local seen = {}
    for _, e in ipairs(entries) do
      assert.is_nil(seen[e.lower], "duplicate surface " .. e.lower)
      seen[e.lower] = true
    end
  end)

  it("drops a surface with no letters", function()
    -- An alias field sometimes holds a Korean gloss, which is useful to read and useless
    -- to complete English on.
    local entries = index.build(notes(PUSHBACK))

    for _, e in ipairs(entries) do
      assert.is_truthy(e.surface:match("%a"), e.surface .. " has no letters")
    end
    assert.is_falsy(vim.tbl_contains(
      vim.tbl_map(function(e)
        return e.surface
      end, entries),
      "반박"
    ))
  end)

  it("carries the definition and example, so choosing teaches", function()
    local entries = index.build(notes(PUSHBACK))
    local first = entries[1]

    assert.is_truthy(first.detail:find("resistance", 1, true))
    assert.is_truthy(first.example:find("give me pushback", 1, true))
    assert.equals("phrase", first.kind)
  end)

  it("offers a Better English note's replacement, not its original", function()
    -- The useful direction: what he decided to write, not what he wrote.
    local entries = index.build(notes(LEAD))

    assert.equals(1, #entries)
    assert.is_truthy(entries[1].surface:find("^Check the daily notes"))
    assert.equals("better-english", entries[1].kind)
  end)

  it("counts words per surface, for ranking", function()
    local entries = index.build(notes(PUSHBACK, ONE_OFF))
    local by_surface = {}
    for _, e in ipairs(entries) do
      by_surface[e.lower] = e
    end

    assert.equals(1, by_surface["pushback"].words)
    assert.equals(2, by_surface["push back"].words)
  end)

  it("ignores a note that is neither a phrase nor a Better English note", function()
    local entries = index.build(notes("---\ntitle: Random\ntags:\n  - x\n---\n"))

    assert.equals(0, #entries)
  end)
end)

describe("collocation prefixes", function()
  it("returns trailing word groups, longest first", function()
    assert.same(
      { "give me push", "me push", "push" },
      index.prefixes("please give me push", 3)
    )
  end)

  it("caps at max_words", function()
    assert.same({ "b c", "c" }, index.prefixes("a b c", 2))
  end)

  it("handles a single word and trailing whitespace", function()
    assert.same({ "push" }, index.prefixes("  push  ", 3))
  end)

  it("returns nothing for empty text", function()
    assert.same({}, index.prefixes("   ", 3))
  end)
end)

describe("collocation candidates", function()
  local entries = index.build(notes(PUSHBACK, ONE_OFF, LEAD))

  it("matches a word prefix", function()
    local out = index.candidates(entries, "give me push")

    assert.is_true(#out > 0)
    assert.is_truthy(vim.tbl_contains(
      vim.tbl_map(function(e)
        return e.lower
      end, out),
      "pushback"
    ))
  end)

  it("prefers a longer matched prefix", function()
    -- This is what makes it a collocation completer rather than a dictionary: a two-word
    -- match is far more likely to be meant than a one-word prefix sharing four letters.
    local out = index.candidates(entries, "a one")

    assert.equals("a one", out[1].matched)
    assert.equals("a one-off", out[1].lower)
  end)

  it("breaks a tie on fewer words, then alphabetically", function()
    -- Determinism matters more than the ordering itself: without a total order the menu
    -- reshuffles between identical queries, which reads as flicker.
    local out = index.candidates(entries, "push")
    local first_two = { out[1].lower, out[2] and out[2].lower }

    assert.equals("pushback", first_two[1])
    assert.equals("push back", first_two[2])
  end)

  it("does not offer a phrase equal to what was already typed", function()
    local out = index.candidates(entries, "pushback")

    for _, e in ipairs(out) do
      assert.are_not.equals("pushback", e.lower)
    end
  end)

  it("returns nothing below min_chars", function()
    -- Completing on one character would put the whole index in the menu on the first
    -- keystroke of every word.
    assert.equals(0, #index.candidates(entries, "p"))
    assert.equals(0, #index.candidates(entries, "pu", { min_chars = 3 }))
  end)

  it("does not repeat a surface matched by two different prefixes", function()
    local out = index.candidates(entries, "me push")
    local seen = {}
    for _, e in ipairs(out) do
      assert.is_nil(seen[e.lower], "repeated " .. e.lower)
      seen[e.lower] = true
    end
  end)

  it("reports how many it dropped rather than truncating silently", function()
    local many = {}
    for i = 1, 30 do
      table.insert(many, {
        text = ("---\ntitle: pushy%02d\nphrase_definition: d\n---\n"):format(i),
        path = "/tmp/x.md",
      })
    end
    local big = index.build(many)

    local out, dropped = index.candidates(big, "pushy", { limit = 5 })

    assert.equals(5, #out)
    assert.equals(25, dropped)
  end)

  it("is case-insensitive on the typed text", function()
    local out = index.candidates(entries, "PUSH")

    assert.is_true(#out > 0)
  end)
end)
