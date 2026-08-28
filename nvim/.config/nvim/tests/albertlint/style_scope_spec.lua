---Section boundaries, scope identity, and payload construction.
---
---`scope_key` is what every finding's fingerprint is keyed on, so a wrong section identity
---means either two distinct findings collide into one or a dismissed finding comes back.
---That is why these are unit tests over plain line arrays rather than buffer tests.
local engine = require("albertlint.engine")
local scope = require("albertlint.style.scope")

---@param lines string[]
---@return string[] lines, table mask
local function with_mask(lines)
  return lines, engine._build_mask(lines)
end

describe("style.scope sections", function()
  it("treats a file with no headings as one level-0 section", function()
    local lines, mask = with_mask({ "just prose", "more prose" })

    local sections = scope.sections(lines, mask)

    assert.equals(1, #sections)
    assert.equals(0, sections[1].level)
    assert.equals("preamble:#1", sections[1].key)
    assert.equals(0, sections[1].start_lnum)
    assert.equals(2, sections[1].end_lnum)
  end)

  it("ends a section at the next heading of the same level", function()
    local lines, mask = with_mask({
      "# One",
      "prose a",
      "# Two",
      "prose b",
    })

    local sections = scope.sections(lines, mask)

    assert.equals(2, #sections)
    assert.equals(0, sections[1].start_lnum)
    assert.equals(2, sections[1].end_lnum)
    assert.equals(2, sections[2].start_lnum)
    assert.equals(4, sections[2].end_lnum)
  end)

  it("keeps a child section inside its parent", function()
    -- The load-bearing boundary rule. Stopping at the next heading of ANY level would cut
    -- an argument off from its own subsections.
    local lines, mask = with_mask({
      "# Parent",
      "parent prose",
      "## Child",
      "child prose",
      "# Sibling",
    })

    local sections = scope.sections(lines, mask)
    local parent = vim.tbl_filter(function(s)
      return s.text == "Parent"
    end, sections)[1]
    local child = vim.tbl_filter(function(s)
      return s.text == "Child"
    end, sections)[1]

    -- Parent runs to the sibling at line 4, so it contains the child.
    assert.equals(0, parent.start_lnum)
    assert.equals(4, parent.end_lnum)
    assert.equals(2, child.start_lnum)
    assert.equals(4, child.end_lnum)
  end)

  it("includes the heading line in its own section", function()
    local lines, mask = with_mask({ "# One", "prose" })

    local sections = scope.sections(lines, mask)

    assert.equals(0, sections[1].start_lnum)
  end)

  it("gives content above the first heading a level-0 section", function()
    local lines, mask = with_mask({ "preamble prose", "# One", "prose" })

    local sections = scope.sections(lines, mask)

    assert.equals(0, sections[1].level)
    assert.equals(0, sections[1].start_lnum)
    assert.equals(1, sections[1].end_lnum)
    assert.equals(1, sections[2].start_lnum)
  end)

  it("does not add an empty preamble when the file opens with a heading", function()
    local lines, mask = with_mask({ "# One", "prose" })

    local sections = scope.sections(lines, mask)

    assert.equals(1, #sections)
    assert.equals(1, sections[1].level)
  end)

  it("ignores a hash line inside a fenced code block", function()
    -- The reason `heading` consults the mask at all.
    local lines, mask = with_mask({
      "# Real",
      "```bash",
      "# not a heading, a shell comment",
      "```",
      "prose",
    })

    local sections = scope.sections(lines, mask)

    assert.equals(1, #sections)
    assert.equals("Real", sections[1].text)
    assert.equals(5, sections[1].end_lnum)
  end)

  it("ignores a hash line inside YAML frontmatter", function()
    local lines, mask = with_mask({
      "---",
      "# not a heading",
      "title: x",
      "---",
      "# Real",
    })

    local sections = scope.sections(lines, mask)
    local real = vim.tbl_filter(function(s)
      return s.level == 1
    end, sections)

    assert.equals(1, #real)
    assert.equals("Real", real[1].text)
  end)

  it("rejects seven hashes and a hash with no space", function()
    -- Seven is past ATX's range; no-space is a tag or an id, not a heading.
    local lines, mask = with_mask({ "####### too deep", "#nospace", "prose" })

    local sections = scope.sections(lines, mask)

    assert.equals(1, #sections)
    assert.equals(0, sections[1].level)
  end)

  it("does not recognise a Setext heading", function()
    -- Stated limitation, not an oversight: `---` is also frontmatter and a horizontal rule.
    local lines, mask = with_mask({ "Title", "=====", "prose" })

    local sections = scope.sections(lines, mask)

    assert.equals(1, #sections)
    assert.equals(0, sections[1].level)
  end)
end)

describe("style.scope scope_key", function()
  it("is the ancestor path, not the bare heading text", function()
    local lines, mask = with_mask({
      "# 2026-08-28",
      "## Symptoms",
      "prose",
    })

    local sections = scope.sections(lines, mask)
    local symptoms = sections[#sections]

    assert.equals("section:2026-08-28/symptoms#1", symptoms.key)
  end)

  it("distinguishes two identically named sections under different parents", function()
    -- Without the path, the same sentence under two `## Notes` headings would produce one
    -- fingerprint and the second finding would silently never exist.
    local lines, mask = with_mask({
      "# Alpha",
      "## Notes",
      "a",
      "# Beta",
      "## Notes",
      "b",
    })

    local sections = scope.sections(lines, mask)
    local notes = vim.tbl_filter(function(s)
      return s.text == "Notes"
    end, sections)

    assert.equals(2, #notes)
    assert.are_not.equals(notes[1].key, notes[2].key)
    assert.equals("section:alpha/notes#1", notes[1].key)
    assert.equals("section:beta/notes#1", notes[2].key)
  end)

  it("collapses whitespace and lowercases", function()
    assert.equals("section:a b/c d#1", scope.scope_key("section", { "A   B", "  c   D  " }, 1))
  end)

  it("distinguishes two SIBLING sections with the same name under one parent", function()
    -- The collision the ordinal exists for, and the one the path alone did not fix. Without
    -- it both sections key identically, so a finding in the second hashes the same as one in
    -- the first, reconciliation "touches" the first mark instead of inserting the second,
    -- and the second finding silently never exists.
    local lines, mask = with_mask({
      "# Day",
      "## Notes",
      "a",
      "## Notes",
      "b",
    })

    local notes = vim.tbl_filter(function(s)
      return s.text == "Notes"
    end, scope.sections(lines, mask))

    assert.equals(2, #notes)
    assert.are_not.equals(notes[1].key, notes[2].key)
    assert.equals("section:day/notes#1", notes[1].key)
    assert.equals("section:day/notes#2", notes[2].key)
  end)

  it("always carries an ordinal, so a later duplicate does not renumber the first", function()
    -- Omitting `#1` for the first occurrence would mean adding a second `## Notes` later
    -- changed the FIRST section's key, invalidating findings in a section nobody edited.
    local one = scope.sections(with_mask({ "## Notes", "a" }))
    local two = scope.sections(with_mask({ "## Notes", "a", "## Notes", "b" }))

    assert.equals(one[1].key, two[1].key)
    assert.equals("section:notes#1", one[1].key)
  end)

  it("separates a preamble from a section by kind, not just by path", function()
    local lines, mask = with_mask({ "loose prose", "# Real" })

    local sections = scope.sections(lines, mask)

    assert.is_truthy(sections[1].key:find("^preamble:"))
    assert.is_truthy(sections[2].key:find("^section:"))
  end)

  it("pops back out to a sibling at a shallower level", function()
    local lines, mask = with_mask({
      "# A",
      "## B",
      "### C",
      "## D",
      "prose",
    })

    local sections = scope.sections(lines, mask)
    local d = vim.tbl_filter(function(s)
      return s.text == "D"
    end, sections)[1]

    assert.equals("section:a/d#1", d.key)
  end)
end)

describe("style.scope section_at", function()
  it("returns the innermost containing section", function()
    -- A cursor inside a `###` block is inside its `##` parent too; the deeper one is the
    -- tighter context and the one the author is actually writing.
    local lines, mask = with_mask({
      "# Parent",
      "## Child",
      "prose",
      "# Sibling",
    })

    local section = scope.section_at(lines, mask, 2)

    assert.equals("Child", section.text)
  end)

  it("returns the preamble for a position above the first heading", function()
    local lines, mask = with_mask({ "preamble", "# One" })

    local section = scope.section_at(lines, mask, 0)

    assert.equals(0, section.level)
    assert.equals("preamble:#1", section.key)
  end)
end)

describe("style.scope payload", function()
  it("blanks masked columns in place, preserving byte length", function()
    -- The invariant everything downstream depends on: quotes are located by searching the
    -- text that was sent, so the payload must be byte-for-byte positionally identical.
    local lines, mask = with_mask({ "use the `slack` API" })

    local out = scope.payload(lines, mask, 0, 1)

    assert.equals(1, #out)
    assert.equals(#lines[1], #out[1])
    assert.is_falsy(out[1]:find("slack", 1, true))
    assert.is_truthy(out[1]:find("use the", 1, true))
  end)

  it("keeps fenced lines as blank lines rather than removing them", function()
    -- Removing them would shift every offset below the block.
    local lines, mask = with_mask({
      "prose above",
      "```",
      "code()",
      "```",
      "prose below",
    })

    local out = scope.payload(lines, mask, 0, 5)

    assert.equals(5, #out)
    assert.equals("prose above", out[1])
    assert.is_falsy(out[3]:find("code", 1, true))
    assert.equals("prose below", out[5])
    for i = 1, 5 do
      assert.equals(#lines[i], #out[i], "line " .. i .. " changed byte length")
    end
  end)

  it("respects the range bounds", function()
    local lines, mask = with_mask({ "a", "b", "c", "d" })

    local out = scope.payload(lines, mask, 1, 3)

    assert.same({ "b", "c" }, out)
  end)
end)

describe("style.scope prose_lines", function()
  it("counts prose lines, not raw lines", function()
    local lines, mask = with_mask({
      "# Heading",
      "one",
      "",
      "two",
    })

    -- Heading excluded, blank excluded.
    assert.equals(2, scope.prose_lines(lines, mask, 0, 4))
  end)

  it("does not count a code block as argument", function()
    -- A section with one sentence plus a code block must not look like enough lines for
    -- `no-claim` to fire.
    local lines, mask = with_mask({
      "## Section",
      "one sentence.",
      "```python",
      "x = 1",
      "y = 2",
      "z = 3",
      "```",
    })

    assert.equals(1, scope.prose_lines(lines, mask, 0, 7))
  end)

  it("counts a line that is only partly masked", function()
    local lines, mask = with_mask({ "the `slack` API is fine" })

    assert.equals(1, scope.prose_lines(lines, mask, 0, 1))
  end)

  it("does not count a line that masking empties entirely", function()
    local lines, mask = with_mask({ "prose", "```", "code", "```" })

    assert.equals(1, scope.prose_lines(lines, mask, 0, 4))
  end)
end)

describe("style.scope key_at", function()
  it("keys a finding by the section it sits in, not by what was scanned", function()
    -- The model change that made the rest simple. A whole-buffer pass produces findings in
    -- several sections, and each must carry its own section's identity. Keying them on the
    -- requested scope would give every finding in the pass one key, reintroducing exactly
    -- the collision the ordinal was added to fix.
    local lines, mask = with_mask({
      "# Alpha",
      "a prose",
      "# Beta",
      "b prose",
    })

    assert.equals("section:alpha#1", scope.key_at(lines, mask, 1))
    assert.equals("section:beta#1", scope.key_at(lines, mask, 3))
  end)

  it("keys a position above the first heading as the preamble", function()
    local lines, mask = with_mask({ "loose", "# Alpha" })

    assert.equals("preamble:#1", scope.key_at(lines, mask, 0))
  end)

  it("gives two identical sentences in sibling sections different keys", function()
    -- End to end: this is the scenario the whole change exists for.
    local lines, mask = with_mask({
      "# Day",
      "## Notes",
      "I feel motivationless.",
      "## Notes",
      "I feel motivationless.",
    })

    assert.are_not.equals(scope.key_at(lines, mask, 2), scope.key_at(lines, mask, 4))
  end)
end)

describe("style.scope request_key", function()
  it("is specific to the range, so two scopes do not cancel each other", function()
    -- Deliberately not scope_key: a scope key must be stable, a request key must be
    -- specific. Draft 3 used one value for both, so a pass over lines 1-20 could cancel a
    -- pass over lines 40-60.
    assert.are_not.equals(
      scope.request_key("section", 0, 20),
      scope.request_key("section", 40, 60)
    )
  end)

  it("distinguishes two kinds over the same range", function()
    assert.are_not.equals(
      scope.request_key("selection", 0, 10),
      scope.request_key("paragraph", 0, 10)
    )
  end)
end)
