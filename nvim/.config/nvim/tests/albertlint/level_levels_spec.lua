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
    -- `spans_only` used to live here. It is deliberately gone: the invariant moved from the
    -- TIER onto the individual finding, as `confident`. The 2026-09-08 review showed the
    -- tier-shaped version was fiction, because a grammar hunk can still contain an
    -- authorial choice (`in a calculator`, `to audience to audience to`).
    assert.is_nil(def.spans_only)
  end)

  it("defines level 2 as coherence and clarity", function()
    local def = levels.get(2)

    assert.equals(2, def.id)
    assert.equals("coherence/clarity", def.name)
  end)

  it("returns nil for a level that still has no command", function()
    -- Levels 3-4 exist as comments recording intent. get() must not invent one, or the
    -- runner would call out with a nil prompt.
    assert.is_nil(levels.get(3))
    assert.is_nil(levels.get(99))
  end)

  it("gives level 1 a spelling slot, which is why typos used to survive", function()
    -- `resontates` and `birthay` came through a real level 1 pass untouched on 2026-09-08
    -- because the allow list had no slot for a misspelling, so the model correctly declined
    -- to report one.
    local allow = table.concat(levels.get(1).allow, " | "):lower()

    assert.is_true(allow:find("spelling", 1, true) ~= nil)
    assert.is_true(allow:find("typo", 1, true) ~= nil)
  end)

  it("keeps level 2 off level 1's and level 3's territory", function()
    local forbid = table.concat(levels.get(2).forbid, " | "):lower()

    assert.is_true(forbid:find("grammar", 1, true) ~= nil)
    assert.is_true(forbid:find("reordering", 1, true) ~= nil)
    -- Plain prose is not a defect, and saying so is what stops level 2 rewriting
    -- everything it touches.
    assert.is_true(forbid:find("plain", 1, true) ~= nil)
  end)

  it("tolerates a non-numeric id", function()
    assert.is_nil(levels.get("banana"))
    assert.is_nil(levels.get(nil))
  end)
end)

describe("level.levels confidence contract", function()
  -- The rule the whole ladder rests on after the 2026-09-08 review: certainty that
  -- something is wrong does not establish certainty about its replacement.

  for _, id in ipairs({ 1, 2 }) do
    it(("level %d asks for confident/replacement or question, never both"):format(id), function()
      local p = levels.prompt(id)

      assert.is_true(p:find("confident", 1, true) ~= nil)
      assert.is_true(p:find("question", 1, true) ~= nil)
      assert.is_true(p:find("replacement", 1, true) ~= nil)
    end)

    it(("level %d says which way to fall when unsure"):format(id), function()
      -- Without this the model defaults to being helpful, which here means guessing at
      -- repairs and handing over sentences the writer did not write.
      local p = levels.prompt(id):lower()

      assert.is_true(p:find("when in doubt", 1, true) ~= nil)
      assert.is_true(p:find("false", 1, true) ~= nil)
    end)

    it(("level %d forbids a suggestion disguised as a question"):format(id), function()
      -- `Did you mean X?` with a single X is a replacement wearing a question mark, and it
      -- routes around the whole gate.
      local p = levels.prompt(id)

      assert.is_true(p:find("wearing a question mark", 1, true) ~= nil)
    end)
  end

  it("level 2 admits that almost nothing at that level is confident", function()
    local p = levels.prompt(2):lower()

    assert.is_true(p:find("almost nothing at this level", 1, true) ~= nil)
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

  it("forbids overlapping findings, which cannot both be applied", function()
    -- Measured against a live model 2026-09-08: asked to review `takes the text and use
    -- LLM`, it returned `use` -> `uses` AND `use LLM` -> `use an LLM` as two findings.
    -- Both are correct and they overlap, so apply.build kept the first and dropped the
    -- second, producing `uses LLM` with the article error silently surviving.
    local p = levels.prompt(1):lower()

    assert.is_true(p:find("overlap", 1, true) ~= nil)
  end)

  it("tells the model to fix capitalization it creates in its own replacement", function()
    -- Same live run: `Audience` -> `The Audience`, keeping the sentence-initial capital
    -- mid-phrase, because the ignore list says capitalization is out of scope. Reporting
    -- a capitalization error and producing one are different acts.
    local p = levels.prompt(1):lower()

    assert.is_true(p:find("begins a sentence", 1, true) ~= nil)
  end)

  it("returns nil for an unimplemented level", function()
    assert.is_nil(levels.prompt(3))
  end)

  it("builds a prompt for level 2", function()
    local p = levels.prompt(2)

    assert.is_not_nil(p)
    assert.is_true(p:find("coherence/clarity", 1, true) ~= nil)
  end)

  it("ends with the marker the caller appends numbered lines after", function()
    -- The runner concatenates prompt .. numbered_lines, so the prompt must end in a
    -- state where a bare `41: some text` reads as data rather than as prose.
    local p = levels.prompt(1)

    assert.is_true(p:find("one line per numbered entry", 1, true) ~= nil)
    assert.equals("\n", p:sub(-1))
  end)
end)
