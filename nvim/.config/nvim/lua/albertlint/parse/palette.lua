---Colors for the structure sidebar, one per part of speech. Data only; `parse/init.lua`
---applies it.
---
---**Explicit hex rather than links to `Function` and `Type`.** Linking follows the colorscheme
---for free and was the first design, but the classic groups collide (`Statement`, `Keyword`,
---and `Operator` are one color in most schemes) and a tree whose purpose is separating
---fourteen parts of speech cannot have three of them identical. Every group is registered
---`default = true`, so one `nvim_set_hl` line overrides any of it.
---
---Two palettes picked by `&background`, same hues, the light one darkened for contrast.
local M = {}

---Universal POS tag to highlight group, as emitted in `token.pos_`.
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

---Content words first, then function words: a hierarchy of how much meaning a class carries,
---which reads better in a legend than alphabetical order.
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

---Verbs get the brightest hue and the only `bold`: a dependency tree hangs off its verbs, so
---finding them is how you find the clause boundaries. `AUX` shares the hue without the bold,
---being a verb doing structural work rather than carrying a clause.
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

  -- Scaffolding, which must recede: fourteen colors only read if the guides and labels do
  -- not compete with the words.
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
