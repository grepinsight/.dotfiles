---The level catalogue and the prompt built from it.
---
---Level 1's whole value is its boundary: it must not reorder, retone, or rewrite for
---concision, because those are levels 3, 2, and 4. These tests pin the boundary in the
---prompt text, and pin the ignore list, which exists because the author's allowlist has
---settled three families (contractions, space-before-a-mark, capitalization) as deliberate
---typing shortcuts. Without the ignore list a generic grammar prompt surfaces exactly those
---and drowns the findings that matter.
local levels = require("albertlint.level.levels")

describe("level.levels catalogue", function()
  it("defines level 1 as grammar and usage", function()
    local def = levels.get(1)

    assert.equals(1, def.id)
    assert.equals("grammar/usage", def.name)
    assert.is_true(def.spans_only)
  end)

  it("returns nil for a level that has no command yet", function()
    -- Levels 2-4 exist as comments recording intent. get() must not invent one, or the
    -- runner would call out with a nil prompt.
    assert.is_nil(levels.get(2))
    assert.is_nil(levels.get(99))
  end)

  it("tolerates a non-numeric id", function()
    assert.is_nil(levels.get("banana"))
    assert.is_nil(levels.get(nil))
  end)
end)

describe("level.levels prompt", function()
  it("names the JSON contract, including occurrence", function()
    local p = levels.prompt(1)

    for _, field in ipairs({ "findings", "quote", "occurrence", "replacement", "label", "note" }) do
      assert.is_true(p:find(field, 1, true) ~= nil, "prompt must name " .. field)
    end
  end)

  it("forbids the things that belong to higher levels", function()
    local p = levels.prompt(1):lower()

    for _, banned in ipairs({ "reorder", "tone", "concision", "content" }) do
      assert.is_true(p:find(banned, 1, true) ~= nil, "prompt must forbid " .. banned)
    end
  end)

  it("tells the model to ignore the settled typing shortcuts", function()
    local p = levels.prompt(1):lower()

    assert.is_true(p:find("capitalization", 1, true) ~= nil)
    assert.is_true(p:find("contraction", 1, true) ~= nil)
    assert.is_true(p:find("space before", 1, true) ~= nil)
  end)

  it("says an empty findings array is a valid answer", function()
    -- Without this the model invents work, and a false positive in prose trains the
    -- author to ignore the tool, which is the failure the whole config guards against.
    local p = levels.prompt(1):lower()

    assert.is_true(p:find("empty", 1, true) ~= nil)
  end)

  it("asks for the shortest span rather than a whole rewritten line", function()
    -- A replacement that restates the surrounding words produces a diff hunk far larger
    -- than the error, which defeats the point of a minimal-span review.
    local p = levels.prompt(1):lower()

    assert.is_true(p:find("shortest", 1, true) ~= nil)
  end)

  it("returns nil for an unimplemented level", function()
    assert.is_nil(levels.prompt(2))
  end)

  it("ends with the marker the caller appends numbered lines after", function()
    -- The runner concatenates prompt .. numbered_lines, so the prompt must end in a
    -- state where a bare `41: some text` reads as data rather than as prose.
    local p = levels.prompt(1)

    assert.is_true(p:find("one line per numbered entry", 1, true) ~= nil)
    assert.equals("\n", p:sub(-1))
  end)
end)
