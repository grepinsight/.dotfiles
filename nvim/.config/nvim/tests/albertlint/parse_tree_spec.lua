---Rendering a dependency parse as a nested list.
---
---Unit tests over hand-written token lists rather than buffer tests, because this module is
---pure and because it is the only thing on the hover path once a sentence is cached. If the
---guide characters or the child ordering are wrong, every tree in the sidebar is wrong.
local tree = require("albertlint.parse.tree")

---"The cat sat on the mat." as `en_core_web_sm` parses it, `idx` offsets included.
---@return table
local function cat_on_mat()
  return {
    text = "The cat sat on the mat.",
    tokens = {
      { i = 0, idx = 0, text = "The", pos = "DET", tag = "DT", dep = "det", head = 1 },
      { i = 1, idx = 4, text = "cat", pos = "NOUN", tag = "NN", dep = "nsubj", head = 2 },
      { i = 2, idx = 8, text = "sat", pos = "VERB", tag = "VBD", dep = "ROOT", head = 2 },
      { i = 3, idx = 12, text = "on", pos = "ADP", tag = "IN", dep = "prep", head = 2 },
      { i = 4, idx = 15, text = "the", pos = "DET", tag = "DT", dep = "det", head = 5 },
      { i = 5, idx = 19, text = "mat", pos = "NOUN", tag = "NN", dep = "pobj", head = 3 },
      { i = 6, idx = 22, text = ".", pos = "PUNCT", tag = ".", dep = "punct", head = 2 },
    },
  }
end

---The same sentence with `phrases` off, for the assertions about tree shape alone.
---@return string[] lines, table index, table[] highlights
local function bare(tree_arg, extra)
  local o = { phrases = false }
  for k, v in pairs(extra or {}) do
    o[k] = v
  end
  return tree.render(tree_arg or cat_on_mat(), o)
end

describe("parse.tree render", function()
  it("nests children under their head, in sentence order", function()
    local lines = bare()

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
    local lines, index = bare()

    assert.equals("sat · VERB · root", lines[4])
    assert.equals(2, index[4])
    assert.equals(1, index[5])
    assert.equals(0, index[6])
    -- The header, the word count, and the blank line carry no token.
    assert.is_nil(index[1])
    assert.is_nil(index[3])
  end)

  it("hides punctuation leaves by default and shows them on request", function()
    local hidden = bare()
    local shown = bare(nil, { include_punct = true })

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
    local lines = bare({
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
    local lines = bare(nil, { dep_labels = "raw" })

    assert.equals("├── cat · NOUN · nsubj", lines[5])
  end)
end)

describe("parse.tree malformed input", function()
  it("reports no parse for an empty token list", function()
    assert.same({ "(no parse)" }, tree.render({ text = "x", tokens = {} }))
  end)

  it("renders every root when a fragment has more than one", function()
    local lines = bare({
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
    local lines = bare({
      text = "orphan",
      tokens = { { i = 3, text = "orphan", pos = "NOUN", dep = "pobj", head = 99 } },
    })

    assert.equals("orphan · NOUN · object of preposition", lines[4])
  end)

  it("terminates on a cycle instead of spinning", function()
    -- The cycle guard is not defensive decoration: this runs on the hover path, so an
    -- infinite walk would hang the editor rather than log an error somewhere.
    local lines = bare({
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

describe("parse.tree phrases", function()
  it("shows the span each node stands for, so a head label is readable", function()
    local lines = tree.render(cat_on_mat())

    -- `on` is the head of `on the mat`, which is the thing a reader cannot recover from the
    -- label alone. That gap is the whole reason this column exists.
    -- `on the mat`, without the final period: the period's head is the root, not `on`, so
    -- it is outside this subtree. Worth asserting, because "the span looks about right" is
    -- how an off-by-one in the span walk would survive.
    assert.equals("└── on · ADP · preposition  [on the mat]", lines[7])
    assert.equals("├── cat · NOUN · subject  [The cat]", lines[5])
  end)

  it("omits the phrase on a leaf, where it would repeat the word", function()
    local lines = tree.render(cat_on_mat())

    assert.equals("│   └── The · DET · determiner", lines[6])
  end)

  it("omits the phrase on the root, where the header already shows it", function()
    local lines = tree.render(cat_on_mat())

    assert.equals("sat · VERB · root", lines[4])
  end)

  it("ellipsizes a phrase past phrase_max", function()
    local lines = tree.render(cat_on_mat(), { phrase_max = 8 })

    assert.is_true(lines[7]:find("…", 1, true) ~= nil)
  end)

  it("shows nothing rather than something wrong when tokens carry no idx", function()
    -- Every span would start at 0 without `idx`, so the column would show the sentence's
    -- first word against every node: confidently wrong, which is worse than absent.
    local lines = tree.render({
      text = "The cat sat.",
      tokens = {
        { i = 0, text = "The", pos = "DET", dep = "det", head = 1 },
        { i = 1, text = "cat", pos = "NOUN", dep = "nsubj", head = 2 },
        { i = 2, text = "sat", pos = "VERB", dep = "ROOT", head = 2 },
      },
    })

    assert.equals("└── cat · NOUN · subject", lines[5])
  end)

  it("computes a subtree span over the full token list, punctuation included", function()
    local spans = tree.subtree_spans(cat_on_mat().tokens)

    -- The root's subtree is the whole sentence, final period and all.
    assert.equals(0, spans[2].s)
    assert.equals(23, spans[2].e)
    -- `on` governs `on the mat.`
    assert.equals(12, spans[3].s)
  end)
end)

describe("parse.tree highlights", function()
  it("colors each word by its part of speech", function()
    local lines, _, highlights = bare()

    local by_line = {}
    for _, h in ipairs(highlights) do
      by_line[h.line] = by_line[h.line] or {}
      table.insert(by_line[h.line], h)
    end

    -- Line 4 is the root, `sat`, a VERB.
    local verb = vim.tbl_filter(function(h)
      return h.group == "AlbertLintTreeVerb"
    end, by_line[4])
    assert.equals(2, #verb) -- the word and its POS column
    assert.equals("sat", lines[4]:sub(verb[1].col + 1, verb[1].end_col))
  end)

  it("uses byte offsets, so the multibyte guides and separators line up", function()
    local lines, _, highlights = bare()

    for _, h in ipairs(highlights) do
      -- A span past the end of its line would be rejected by nvim_buf_set_extmark, which is
      -- the failure this asserts against: `#` counts bytes and the guides are 3 bytes a glyph.
      assert.is_true(h.end_col <= #lines[h.line],
        ("line %d: end_col %d past byte length %d"):format(h.line, h.end_col, #lines[h.line]))
      assert.is_true(h.col < h.end_col)
    end
  end)

  it("paints the guides, the dep label, and the phrase in their own groups", function()
    local _, _, highlights = tree.render(cat_on_mat())

    local groups = {}
    for _, h in ipairs(highlights) do
      groups[h.group] = true
    end

    assert.is_true(groups["AlbertLintTreeGuide"])
    assert.is_true(groups["AlbertLintTreeDep"])
    assert.is_true(groups["AlbertLintTreePhrase"])
    assert.is_true(groups["AlbertLintTreeHeader"])
    assert.is_true(groups["AlbertLintTreeCount"])
  end)

  it("drops the POS column but keeps the color when pos_column is off", function()
    local lines, _, highlights = bare(nil, { pos_column = false })

    assert.equals("├── cat · subject", lines[5])
    local noun = vim.tbl_filter(function(h)
      return h.group == "AlbertLintTreeNoun" and h.line == 5
    end, highlights)
    assert.equals(1, #noun)
  end)
end)
