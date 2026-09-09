---Colors for the structure sidebar, one per part of speech.
---
---Data, not logic, the same split `rules.lua` uses. Nothing here calls `vim.api`; the
---application lives in `parse/init.lua`.
---
---**Explicit hex rather than links to `Function`, `Type`, and friends.** Linking would follow
---the colorscheme for free and was the first design, and it is wrong for this particular job.
---Classic highlight groups collide constantly (`Statement`, `Keyword`, and `Operator` are one
---color in most schemes), and a tree whose whole purpose is to distinguish fourteen parts of
---speech cannot afford three of them looking identical. Treesitter captures are more
---distinct but not guaranteed to be defined.
---
---Every group is registered with `default = true`, so one `vim.api.nvim_set_hl` line in a
---colorscheme override replaces any of them.
---
---Two palettes, picked by `&background`. The hues are the same in both; the light variant is
---darkened for contrast on white.
local M = {}

---Part-of-speech tag to highlight group. Universal POS tags, which is what
---`en_core_web_sm` emits in `token.pos_`.
M.POS_GROUP = {
  NOUN = "AlbertLintTreeNoun",
  PROPN = "AlbertLintTreeProper",
  VERB = "AlbertLintTreeVerb",
  AUX = "AlbertLintTreeAux",
  ADJ = "AlbertLintTreeAdj",
  ADV = "AlbertLintTreeAdv",
  PRON = "AlbertLintTreePron",
  DET = "AlbertLintTreeDet",
  ADP = "AlbertLintTreePrep",
  CCONJ = "AlbertLintTreeConj",
  SCONJ = "AlbertLintTreeConj",
  NUM = "AlbertLintTreeNum",
  PART = "AlbertLintTreePart",
  INTJ = "AlbertLintTreeIntj",
  PUNCT = "AlbertLintTreeFaint",
  SYM = "AlbertLintTreeFaint",
  SPACE = "AlbertLintTreeFaint",
  X = "AlbertLintTreeFaint",
}

---Legend order: content words first, then function words, then the faint tail. Chosen so the
---legend reads as a hierarchy of how much meaning a word carries rather than alphabetically.
M.LEGEND_ORDER = {
  "VERB", "NOUN", "PROPN", "ADJ", "ADV", "PRON", "NUM",
  "AUX", "ADP", "DET", "CCONJ", "PART", "INTJ", "PUNCT",
}

M.LEGEND_GLOSS = {
  NOUN = "noun",
  PROPN = "proper noun",
  VERB = "verb",
  AUX = "auxiliary verb",
  ADJ = "adjective",
  ADV = "adverb",
  PRON = "pronoun",
  DET = "determiner",
  ADP = "preposition",
  CCONJ = "conjunction",
  NUM = "number",
  PART = "particle (to, 's, not)",
  INTJ = "interjection",
  PUNCT = "punctuation, symbols",
}

---Verbs are bold, and that is the one deliberate asymmetry in the palette.
---
---A dependency tree hangs off its verb: the root is almost always one, every clause has one,
---and finding them is how you find the clause boundaries. So the verb gets the brightest hue
---in the palette *and* the only `bold`, which reads at a glance even in a narrow sidebar.
---`AUX` shares the hue without the bold, because an auxiliary is a verb doing structural work
---rather than carrying the clause.
M.DARK = {
  AlbertLintTreeVerb = { fg = "#7dcfff", bold = true },
  AlbertLintTreeAux = { fg = "#7dcfff" },
  AlbertLintTreeNoun = { fg = "#e0af68" },
  AlbertLintTreeProper = { fg = "#ff9e64" },
  AlbertLintTreeAdj = { fg = "#9ece6a" },
  AlbertLintTreeAdv = { fg = "#bb9af7" },
  AlbertLintTreePron = { fg = "#f7768e" },
  AlbertLintTreePrep = { fg = "#2ac3de" },
  AlbertLintTreeConj = { fg = "#ff757f" },
  AlbertLintTreeNum = { fg = "#ffc777" },
  AlbertLintTreeDet = { fg = "#737aa2" },
  AlbertLintTreePart = { fg = "#737aa2" },
  AlbertLintTreeIntj = { fg = "#c3e88d", italic = true },
  AlbertLintTreeFaint = { fg = "#545c7e" },

  -- Scaffolding. The guides and the dependency gloss must recede, or a fourteen-color tree
  -- becomes a fourteen-color mess: the words are the content, everything else is a label.
  AlbertLintTreeGuide = { fg = "#3b4261" },
  AlbertLintTreeDep = { fg = "#828bb8", italic = true },
  AlbertLintTreePhrase = { fg = "#565f89" },
  AlbertLintTreeHeader = { fg = "#c8d3f5", bold = true },
  AlbertLintTreeCount = { fg = "#545c7e", italic = true },
}

M.LIGHT = {
  AlbertLintTreeVerb = { fg = "#0f7490", bold = true },
  AlbertLintTreeAux = { fg = "#0f7490" },
  AlbertLintTreeNoun = { fg = "#8f6424" },
  AlbertLintTreeProper = { fg = "#b45309" },
  AlbertLintTreeAdj = { fg = "#3f7d20" },
  AlbertLintTreeAdv = { fg = "#6d28d9" },
  AlbertLintTreePron = { fg = "#b4243f" },
  AlbertLintTreePrep = { fg = "#0e7490" },
  AlbertLintTreeConj = { fg = "#be123c" },
  AlbertLintTreeNum = { fg = "#a16207" },
  AlbertLintTreeDet = { fg = "#6b7280" },
  AlbertLintTreePart = { fg = "#6b7280" },
  AlbertLintTreeIntj = { fg = "#3f6212", italic = true },
  AlbertLintTreeFaint = { fg = "#9ca3af" },

  AlbertLintTreeGuide = { fg = "#c4c8d4" },
  AlbertLintTreeDep = { fg = "#6b7280", italic = true },
  AlbertLintTreePhrase = { fg = "#9ca3af" },
  AlbertLintTreeHeader = { fg = "#1f2335", bold = true },
  AlbertLintTreeCount = { fg = "#9ca3af", italic = true },
}

---@param pos string|nil
---@return string
function M.group(pos)
  return M.POS_GROUP[pos] or "AlbertLintTreeFaint"
end

return M
