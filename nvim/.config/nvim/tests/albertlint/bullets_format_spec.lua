---Turning a selection into a bullet list, the pure half.
---
---The transform changes no words, so the whole risk surface is *placement*: which lines get a
---marker, which are left alone, and where the sentence boundaries fall inside a wrapped
---paragraph. Every case below is one that silently mangles a draft when it is wrong, which is
---why they are string literals against a module with no `vim.*` in it.
local format = require("albertlint.bullets.format")

---The sentences for every prose block, as the segmenter would return them.
---@param blocks table[]
---@param lists table<integer, string[]>
---@return string[]
local function render(blocks, lists)
  return format.render(blocks, lists)
end

describe("bullets.format.blocks", function()
  it("splits a selection at blank lines", function()
    local blocks = format.blocks({ "One. Two.", "", "Three." })
    assert.equals(3, #blocks)
    assert.equals("prose", blocks[1].kind)
    assert.equals("blank", blocks[2].kind)
    assert.equals("prose", blocks[3].kind)
  end)

  it("joins a wrapped paragraph into one text, single-spaced", function()
    local blocks = format.blocks({ "A sentence that wraps", "onto a second line." })
    assert.equals(1, #blocks)
    assert.equals("A sentence that wraps onto a second line.", blocks[1].text)
  end)

  it("takes the indent from the block's first line", function()
    local blocks = format.blocks({ "    Indented prose." })
    assert.equals("    ", blocks[1].indent)
    assert.equals("Indented prose.", blocks[1].text)
  end)

  it("trims each line before joining, so a trailing space is not doubled", function()
    local blocks = format.blocks({ "First half   ", "   second half." })
    assert.equals("First half second half.", blocks[1].text)
  end)

  it("marks a block that is already a bullet list as skip", function()
    for _, marker in ipairs({ "- ", "* ", "+ ", "1. ", "2) " }) do
      local blocks = format.blocks({ marker .. "Already a list item." })
      assert.equals("skip", blocks[1].kind, "marker " .. marker)
    end
  end)

  it("marks a heading as skip", function()
    local blocks = format.blocks({ "## A heading" })
    assert.equals("skip", blocks[1].kind)
  end)

  it("keeps a heading's own block separate from the prose under it", function()
    local blocks = format.blocks({ "## Heading", "Prose under it." })
    assert.equals(2, #blocks)
    assert.equals("skip", blocks[1].kind)
    assert.equals("prose", blocks[2].kind)
    assert.equals("Prose under it.", blocks[2].text)
  end)

  it("does not treat a hyphen inside a word as a list marker", function()
    local blocks = format.blocks({ "well-scoped work is the goal." })
    assert.equals("prose", blocks[1].kind)
  end)

  it("does not treat an em-rule sentence start as a list marker", function()
    -- `-5 degrees` has no space after the hyphen, so it is not a marker.
    local blocks = format.blocks({ "-5 degrees is cold." })
    assert.equals("prose", blocks[1].kind)
  end)
end)

describe("bullets.format.prose_texts", function()
  it("returns the prose texts and the block index each one came from", function()
    local blocks = format.blocks({ "- skip me", "", "Bullet me." })
    local texts, indices = format.prose_texts(blocks)
    assert.same({ "Bullet me." }, texts)
    assert.same({ 3 }, indices)
  end)

  it("returns nothing when the selection has no prose", function()
    local texts, indices = format.prose_texts(format.blocks({ "- a", "- b" }))
    assert.same({}, texts)
    assert.same({}, indices)
  end)
end)

describe("bullets.format.render", function()
  it("emits one bullet per sentence", function()
    local blocks = format.blocks({ "One. Two." })
    assert.same({ "- One.", "- Two." }, render(blocks, { [1] = { "One.", "Two." } }))
  end)

  it("keeps the blank line between paragraph groups", function()
    local blocks = format.blocks({ "One. Two.", "", "Three." })
    local out = render(blocks, { [1] = { "One.", "Two." }, [3] = { "Three." } })
    assert.same({ "- One.", "- Two.", "", "- Three." }, out)
  end)

  it("preserves however many blank lines there were", function()
    local blocks = format.blocks({ "One.", "", "", "Two." })
    -- Block 2, not 3 and 4: a run of blank lines is one block holding both of them, which is
    -- why `prose_texts` returns indices rather than the caller counting paragraphs itself.
    assert.equals(3, #blocks)
    local out = render(blocks, { [1] = { "One." }, [3] = { "Two." } })
    assert.same({ "- One.", "", "", "- Two." }, out)
  end)

  it("carries the indent onto every bullet in the block", function()
    local blocks = format.blocks({ "  One. Two." })
    assert.same({ "  - One.", "  - Two." }, render(blocks, { [1] = { "One.", "Two." } }))
  end)

  it("passes a skip block through verbatim", function()
    local blocks = format.blocks({ "- Already bulleted.", "  continued here." })
    assert.same({ "- Already bulleted.", "  continued here." }, render(blocks, {}))
  end)

  it("is idempotent, so running it twice does not double-bullet", function()
    local once = render(format.blocks({ "One. Two." }), { [1] = { "One.", "Two." } })
    local twice = render(format.blocks(once), {})
    assert.same(once, twice)
  end)

  it("passes a prose block through verbatim when it segments to nothing", function()
    local blocks = format.blocks({ "Prose." })
    assert.same({ "Prose." }, render(blocks, { [1] = {} }))
  end)

  it("trims whitespace off a sentence the segmenter handed back padded", function()
    local blocks = format.blocks({ "One. Two." })
    assert.same({ "- One.", "- Two." }, render(blocks, { [1] = { " One. ", "\tTwo." } }))
  end)

  it("drops a sentence that is only whitespace", function()
    local blocks = format.blocks({ "One." })
    assert.same({ "- One." }, render(blocks, { [1] = { "One.", "   " } }))
  end)
end)

describe("bullets.format end to end on an announcement-shaped draft", function()
  -- Synthetic, and deliberately so: this repo is public, and the real text that prompted the
  -- module named a product and a partner. What the fixture has to keep is the *shape*, since
  -- that is what the code can get wrong. Three paragraphs, two sentences in the first, four
  -- hyphenated compound modifiers (what a list-marker pattern without a trailing space
  -- mistakes for a bullet), and a comma-heavy opening sentence a naive splitter breaks in the
  -- middle of.
  --
  -- The two-sentence split below is not a guess. Checked against the installed model on
  -- 2026-09-12: `nlp.pipe` over these three paragraphs returns 2, 1, and 1 sentences, exactly
  -- as asserted.
  local lines = {
    "We are glad to share that the review board cleared our long-running toolkit as a "
      .. "first-line option for well-scoped, low-latency editing work. This is the earliest "
      .. "cleared option of its kind for tracking a draft over time, which changes how we "
      .. "define a finished paragraph and shows what a local parser can do to guide a rewrite.",
    "",
    "The decision reflects a multi-year collaboration with the tooling group, letting us fold "
      .. "these parts into everyday practice.",
    "",
    "Read more about it here.",
  }

  it("produces four bullets in three groups", function()
    local blocks = format.blocks(lines)
    local texts, indices = format.prose_texts(blocks)
    assert.equals(3, #texts)
    assert.same({ 1, 3, 5 }, indices)

    -- Segmented where spaCy segments it, so the fixture is the real contract rather than a
    -- guess: the commas and the hyphens inside the first sentence are not boundaries.
    local lists = {}
    lists[indices[1]] = {
      "We are glad to share that the review board cleared our long-running toolkit as a "
        .. "first-line option for well-scoped, low-latency editing work.",
      "This is the earliest cleared option of its kind for tracking a draft over time, which "
        .. "changes how we define a finished paragraph and shows what a local parser can do to "
        .. "guide a rewrite.",
    }
    lists[indices[2]] = { texts[2] }
    lists[indices[3]] = { texts[3] }

    local out = format.render(blocks, lists)
    assert.equals(6, #out)
    assert.equals("", out[3])
    assert.equals("", out[5])
    assert.equals("- Read more about it here.", out[6])
    for _, i in ipairs({ 1, 2, 4, 6 }) do
      assert.truthy(out[i]:match("^%- %S"), "line " .. i .. " should be a bullet: " .. out[i])
    end
  end)

  it("treats a hyphenated modifier at the start of a line as prose, not a bullet", function()
    -- The same trap as the fixture's `long-running`, isolated: if the list-marker pattern drops
    -- its trailing space, this block is classified `skip` and the command silently no-ops.
    local blocks = format.blocks({ "well-scoped work is the goal." })
    assert.equals("prose", blocks[1].kind)
  end)
end)
