---Finding the sentence under the cursor, in Lua.
---
---This module is the cache key generator, which makes it the piece where a bug is hardest to
---see: a wrong boundary does not error, it produces a tree for slightly the wrong span, or a
---permanent cache miss on one sentence. Hence unit tests over plain line arrays, the same
---shape as `style_scope_spec.lua`.
local engine = require("albertlint.engine")
local sentence = require("albertlint.parse.sentence")

---@param lines string[]
---@return string[] lines, table mask
local function with_mask(lines)
  return lines, engine._build_mask(lines)
end

describe("parse.sentence split", function()
  it("splits on a period followed by a space", function()
    local out = sentence.split("The cat sat. It was warm.")

    assert.equals(2, #out)
    assert.equals("The cat sat.", out[1].text)
    assert.equals("It was warm.", out[2].text)
  end)

  it("splits on question and exclamation marks", function()
    local out = sentence.split("Why? Because. Stop!")

    assert.equals(3, #out)
    assert.equals("Why?", out[1].text)
    assert.equals("Stop!", out[3].text)
  end)

  it("keeps a closing quote or bracket with the sentence it ends", function()
    local out = sentence.split('He said "stop." Then he left.')

    assert.equals(2, #out)
    assert.equals('He said "stop."', out[1].text)
  end)

  it("does not split a footnote marker", function()
    -- Straight from the screenshot that prompted this feature: `treatment success.1, 2, 3`
    -- is a citation, not two sentences, and the tell is that no space follows the period.
    local out = sentence.split("predicting treatment success.1, 2, 3 However, data is siloed.")

    assert.equals(1, #out)
    assert.equals("predicting treatment success.1, 2, 3 However, data is siloed.", out[1].text)
  end)

  it("does not split a decimal, a version, or a filename", function()
    for _, text in ipairs({ "p was 0.05 overall.", "we run v3.8 here.", "see config.lua now." }) do
      assert.equals(1, #sentence.split(text), text)
    end
  end)

  it("does not split after a single letter, which covers e.g. and initials", function()
    assert.equals(1, #sentence.split("Use a linter, e.g. harper, on prose."))
    assert.equals(1, #sentence.split("Written by J. R. R. Tolkien in England."))
  end)

  it("does not split after a listed abbreviation", function()
    assert.equals(1, #sentence.split("Dr. Smith reviewed it."))
    assert.equals(1, #sentence.split("See Fig. 3 for the layout."))
  end)

  it("does split after etc., which is deliberately not in the list", function()
    -- `etc.` ends sentences constantly, so listing it would merge two sentences every time,
    -- which is a worse and more frequent failure than splitting `Fig. 3`.
    assert.equals(2, #sentence.split("Diagrams, tables, etc. The next point is separate."))
  end)

  it("returns the trailing fragment when the text has no final mark", function()
    local out = sentence.split("First one. and then a fragment")

    assert.equals(2, #out)
    assert.equals("and then a fragment", out[2].text)
  end)
end)

describe("parse.sentence normalize", function()
  it("collapses whitespace so a rewrapped sentence is the same cache key", function()
    assert.equals(
      sentence.normalize("a  sentence   wrapped"),
      sentence.normalize(" a sentence wrapped ")
    )
  end)
end)

describe("parse.sentence paragraph", function()
  it("takes the contiguous run of prose lines around the cursor", function()
    local lines, mask = with_mask({ "one", "two", "", "three" })

    local para = sentence.paragraph(lines, 1, mask)

    assert.equals(0, para.start_lnum)
    assert.equals(2, para.end_lnum)
  end)

  it("stops at a heading", function()
    local lines, mask = with_mask({ "# Title", "body one", "body two" })

    local para = sentence.paragraph(lines, 1, mask)

    assert.equals(1, para.start_lnum)
    assert.equals(3, para.end_lnum)
  end)

  it("returns nil on a blank line", function()
    local lines, mask = with_mask({ "prose", "", "more" })

    assert.is_nil(sentence.paragraph(lines, 1, mask))
  end)

  it("returns nil inside a fenced code block", function()
    local lines, mask = with_mask({ "```lua", "local x = 1. y = 2.", "```" })

    assert.is_nil(sentence.paragraph(lines, 1, mask))
  end)
end)

describe("parse.sentence at", function()
  it("finds the sentence under the cursor across a wrapped line pair", function()
    local lines, mask = with_mask({
      "The first sentence ends here. The second one",
      "continues onto a new line and ends here.",
    })

    local at = sentence.at(lines, 1, 5, mask)

    assert.equals("The second one continues onto a new line and ends here.", at.text)
    assert.equals(0, at.start_lnum)
    assert.equals(30, at.start_col)
    assert.equals(1, at.end_lnum)
  end)

  it("reports the sentence a period closes, not the one after it", function()
    local lines, mask = with_mask({ "One here. Two there." })

    -- Column 8 is the first period.
    local at = sentence.at(lines, 0, 8, mask)

    assert.equals("One here.", at.text)
  end)

  it("returns the last sentence when the cursor sits past the final mark", function()
    local lines, mask = with_mask({ "One here. Two there.  " })

    local at = sentence.at(lines, 0, 21, mask)

    assert.equals("Two there.", at.text)
  end)

  it("returns nil on a blank line", function()
    local lines, mask = with_mask({ "prose here.", "" })

    assert.is_nil(sentence.at(lines, 1, 0, mask))
  end)

  it("blanks an inline code span instead of parsing it", function()
    local lines, mask = with_mask({ "Run `x = 1. y = 2` and stop." })

    local at = sentence.at(lines, 0, 0, mask)

    -- One sentence, not three: the code span is whitespace by the time the splitter sees it.
    assert.equals("Run and stop.", at.text)
  end)
end)

describe("parse.sentence all", function()
  it("collects every sentence in the buffer, skipping code and headings", function()
    local lines, mask = with_mask({
      "# Heading",
      "First sentence. Second sentence.",
      "",
      "```",
      "code. more code.",
      "```",
      "",
      "Third sentence.",
    })

    local all = sentence.all(lines, mask)

    assert.same({ "First sentence.", "Second sentence.", "Third sentence." }, all)
  end)

  it("deduplicates, so a repeated sentence is parsed once", function()
    local lines, mask = with_mask({ "Same one.", "", "Same one." })

    assert.same({ "Same one." }, sentence.all(lines, mask))
  end)
end)

describe("parse.sentence performance", function()
  it("stays linear in the paragraph length", function()
    -- A regression test with a number in it, which this suite otherwise avoids. It earns the
    -- exception: `boundary` used to take a substring of everything before the mark on every
    -- call, which made the splitter quadratic in bytes and cost 39ms on this input against a
    -- 1ms budget for the whole hover. A correctness test cannot see that, because the output
    -- was right the whole time.
    local lines = {}
    for i = 1, 200 do
      lines[i] = ("Some prose sentence number %d sits here to pad the buffer out."):format(i)
    end
    local engine_mask = require("albertlint.engine")._build_mask(lines)

    local t0 = vim.uv.hrtime()
    local at = require("albertlint.parse.sentence").at(lines, 100, 5, engine_mask)
    local us = (vim.uv.hrtime() - t0) / 1000

    assert.is_not_nil(at)
    -- Two orders of magnitude of headroom over the fixed version's ~440us, so this fails on a
    -- return to quadratic behaviour and not on a slow CI box.
    assert.is_true(us < 15000, ("sentence.at took %.0f us on a 200-line paragraph"):format(us))
  end)
end)
