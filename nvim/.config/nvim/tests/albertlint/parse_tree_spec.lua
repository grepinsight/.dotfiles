---Rendering a dependency parse as a nested list.
---
---Unit tests over hand-written token lists rather than buffer tests, because this module is
---pure and because it is the only thing on the hover path once a sentence is cached. If the
---guide characters or the child ordering are wrong, every tree in the sidebar is wrong.
local tree = require("albertlint.parse.tree")

---"The cat sat on the mat." as `en_core_web_sm` parses it.
---@return table
local function cat_on_mat()
  return {
    text = "The cat sat on the mat.",
    tokens = {
      { i = 0, text = "The", pos = "DET", tag = "DT", dep = "det", head = 1 },
      { i = 1, text = "cat", pos = "NOUN", tag = "NN", dep = "nsubj", head = 2 },
      { i = 2, text = "sat", pos = "VERB", tag = "VBD", dep = "ROOT", head = 2 },
      { i = 3, text = "on", pos = "ADP", tag = "IN", dep = "prep", head = 2 },
      { i = 4, text = "the", pos = "DET", tag = "DT", dep = "det", head = 5 },
      { i = 5, text = "mat", pos = "NOUN", tag = "NN", dep = "pobj", head = 3 },
      { i = 6, text = ".", pos = "PUNCT", tag = ".", dep = "punct", head = 2 },
    },
  }
end

describe("parse.tree render", function()
  it("nests children under their head, in sentence order", function()
    local lines = tree.render(cat_on_mat())

    assert.same({
      "The cat sat on the mat.",
      "(6 words)",
      "",
      "sat · VERB · root",
      "├── cat · NOUN · subject",
      "│   └── The · DET · determiner",
      "└── on · ADP · preposition",
      "    └── mat · NOUN · object of preposition",
      "        └── the · DET · determiner",
    }, lines)
  end)

  it("returns a line-to-token index for the rendered rows", function()
    local lines, index = tree.render(cat_on_mat())

    assert.equals("sat · VERB · root", lines[4])
    assert.equals(2, index[4])
    assert.equals(1, index[5])
    assert.equals(0, index[6])
    -- The header, the word count, and the blank line carry no token.
    assert.is_nil(index[1])
    assert.is_nil(index[3])
  end)

  it("hides punctuation leaves by default and shows them on request", function()
    local hidden = tree.render(cat_on_mat())
    local shown = tree.render(cat_on_mat(), { include_punct = true })

    assert.is_nil(vim.tbl_filter(function(l)
      return l:match("%. · PUNCT")
    end, hidden)[1])
    assert.equals(1, #vim.tbl_filter(function(l)
      return l:match("%. · PUNCT · punctuation$")
    end, shown))
  end)

  it("counts words without counting punctuation", function()
    assert.equals(6, tree.word_count(cat_on_mat().tokens))
  end)

  it("keeps punctuation that has children, rather than orphaning the subtree", function()
    -- Not a shape spaCy produces, which is exactly why it is tested: dropping a head would
    -- silently lose half a sentence, and one stray glyph on screen is the better failure.
    local lines = tree.render({
      text = "a - b",
      tokens = {
        { i = 0, text = "a", pos = "NOUN", dep = "ROOT", head = 0 },
        { i = 1, text = "-", pos = "PUNCT", dep = "punct", head = 0 },
        { i = 2, text = "b", pos = "NOUN", dep = "conj", head = 1 },
      },
    })

    assert.equals("└── - · PUNCT · punctuation", lines[5])
    assert.equals("    └── b · NOUN · coordinated with", lines[6])
  end)
end)

describe("parse.tree labels", function()
  it("glosses a known label by default", function()
    assert.equals("subject", tree.label("nsubj", "gloss"))
  end)

  it("passes an unknown label through unchanged, in every mode", function()
    -- A model update that adds a label should show the raw tag, not an empty column.
    assert.equals("newdep", tree.label("newdep", "gloss"))
    assert.equals("newdep", tree.label("newdep", "both"))
  end)

  it("shows the raw tag on request", function()
    assert.equals("nsubj", tree.label("nsubj", "raw"))
    assert.equals("subject (nsubj)", tree.label("nsubj", "both"))
  end)

  it("threads the label mode through render", function()
    local lines = tree.render(cat_on_mat(), { dep_labels = "raw" })

    assert.equals("├── cat · NOUN · nsubj", lines[5])
  end)
end)

describe("parse.tree malformed input", function()
  it("reports no parse for an empty token list", function()
    assert.same({ "(no parse)" }, tree.render({ text = "x", tokens = {} }))
  end)

  it("renders every root when a fragment has more than one", function()
    local lines = tree.render({
      text = "Yes. No.",
      tokens = {
        { i = 0, text = "Yes", pos = "INTJ", dep = "ROOT", head = 0 },
        { i = 1, text = "No", pos = "INTJ", dep = "ROOT", head = 1 },
      },
    })

    assert.equals("Yes · INTJ · root", lines[4])
    assert.equals("No · INTJ · root", lines[5])
  end)

  it("treats a head pointing outside the token list as a root", function()
    local lines = tree.render({
      text = "orphan",
      tokens = { { i = 3, text = "orphan", pos = "NOUN", dep = "pobj", head = 99 } },
    })

    assert.equals("orphan · NOUN · object of preposition", lines[4])
  end)

  it("terminates on a cycle instead of spinning", function()
    -- The cycle guard is not defensive decoration: this runs on the hover path, so an
    -- infinite walk would hang the editor rather than log an error somewhere.
    local lines = tree.render({
      text = "a b",
      tokens = {
        { i = 0, text = "a", pos = "NOUN", dep = "ROOT", head = 0 },
        { i = 1, text = "b", pos = "NOUN", dep = "conj", head = 2 },
        { i = 2, text = "c", pos = "NOUN", dep = "conj", head = 1 },
      },
    })

    -- b and c point at each other, so neither is reachable from the root and the tree is
    -- just the root. The point of the test is that it returns at all.
    assert.equals(4, #lines)
  end)
end)
