---Rendering a dependency parse as a nested list.
---
---Deliberately pure: no `vim.api`, no `vim.fn`, no filesystem. Same reason
---`annotate/anchor.lua` and `style/scope.lua` are pure. This module is also the only thing
---on the hover path once a sentence is cached, so it is both the piece most likely to be
---wrong and the piece whose speed is the whole point of the feature. Both arguments say
---"testable with string literals".
---
---Input is the token list the daemon returns, which is spaCy's own shape: 0-indexed `i`,
---and `head` pointing at the governing token's `i`. A root is a token whose head is itself.
---
---Line numbers in the returned index are 1-indexed, matching `nvim_buf_set_lines` output
---rather than the 0-indexed extmark convention used elsewhere in this plugin. The index is
---consumed by a window-local cursor lookup, and window cursors are 1-indexed.
local M = {}

---Universal-ish dependency labels, glossed.
---
---Data, not logic, the same split `rules.lua` uses. `en_core_web_sm` emits the
---ClearNLP/OntoNotes scheme rather than strict Universal Dependencies, which is why
---`dobj` and `pobj` appear here and UD's `obj`/`obl` do not.
---
---These glosses are one reader's translation, chosen to name the grammatical role in words a
---writer would recognize. A linguist would argue with several of them; that is an accepted
---cost, because the raw label teaches nothing to someone who does not already know it, and
---`dep_labels = "raw"` is there for when the jargon is what you want.
M.GLOSS = {
  ROOT = "root",
  acl = "clause modifying a noun",
  acomp = "adjective complement",
  advcl = "adverbial clause",
  advmod = "adverb modifier",
  agent = "agent of a passive",
  amod = "adjective modifier",
  appos = "appositive",
  attr = "attribute",
  aux = "auxiliary",
  auxpass = "passive auxiliary",
  case = "case marker",
  cc = "coordinator",
  ccomp = "clausal complement",
  compound = "compound",
  conj = "coordinated with",
  csubj = "clausal subject",
  csubjpass = "clausal passive subject",
  dative = "indirect object",
  dep = "unclassified",
  det = "determiner",
  dobj = "direct object",
  expl = "existential there",
  intj = "interjection",
  mark = "subordinating conjunction",
  meta = "meta",
  neg = "negation",
  nmod = "noun modifier",
  npadvmod = "noun phrase as adverb",
  nsubj = "subject",
  nsubjpass = "passive subject",
  nummod = "number modifier",
  oprd = "object predicate",
  parataxis = "loosely joined clause",
  pcomp = "complement of preposition",
  pobj = "object of preposition",
  poss = "possessive",
  preconj = "pre-correlative",
  predet = "predeterminer",
  prep = "preposition",
  prt = "particle",
  punct = "punctuation",
  quantmod = "quantifier modifier",
  relcl = "relative clause",
  xcomp = "open clausal complement",
}

M.DEFAULTS = {
  include_punct = false,
  dep_labels = "gloss",
  separator = " · ",
}

---@param dep string
---@param mode string "gloss" | "raw" | "both"
---@return string
function M.label(dep, mode)
  local gloss = M.GLOSS[dep]
  if mode == "raw" or not gloss then
    return dep
  end
  if mode == "both" then
    return ("%s (%s)"):format(gloss, dep)
  end
  return gloss
end

---Drop punctuation that carries no structure.
---
---Only *leaf* punctuation is dropped. A `punct` token with children would orphan a subtree
---if it were removed, and while spaCy does not normally produce one, a malformed or
---hand-written token list can, and silently losing half a sentence is a worse failure than
---one stray comma on screen.
---@param tokens table[]
---@return table[]
local function without_punct_leaves(tokens)
  local has_children = {}
  for _, t in ipairs(tokens) do
    if t.head ~= t.i then
      has_children[t.head] = true
    end
  end
  local kept = {}
  for _, t in ipairs(tokens) do
    if t.pos ~= "PUNCT" or has_children[t.i] then
      table.insert(kept, t)
    end
  end
  return kept
end

---@param tokens table[]
---@return table<integer, table> by_index, table<integer, table[]> children, table[] roots
local function build(tokens)
  local by_index, children, roots = {}, {}, {}
  for _, t in ipairs(tokens) do
    by_index[t.i] = t
  end
  for _, t in ipairs(tokens) do
    if t.head == t.i or by_index[t.head] == nil then
      -- A head pointing outside the token list means the sentence was split away from its
      -- governor, which happens when `include_punct` drops a token or when a caller passes a
      -- slice. Treat it as a root rather than dropping the subtree.
      table.insert(roots, t)
    else
      children[t.head] = children[t.head] or {}
      table.insert(children[t.head], t)
    end
  end
  -- Sentence order, not parse order, so the tree reads left to right the way the sentence does.
  for _, list in pairs(children) do
    table.sort(list, function(a, b)
      return a.i < b.i
    end)
  end
  table.sort(roots, function(a, b)
    return a.i < b.i
  end)
  return by_index, children, roots
end

---@param tokens table[]
---@return integer
function M.word_count(tokens)
  local n = 0
  for _, t in ipairs(tokens) do
    if t.pos ~= "PUNCT" and t.pos ~= "SPACE" then
      n = n + 1
    end
  end
  return n
end

---`vim.tbl_extend` would do this, but it is the one `vim.*` call that would otherwise appear
---in the file, and a module that claims to be runnable without an editor should be.
---@param opts table|nil
---@return table
local function with_defaults(opts)
  local merged = {}
  for k, v in pairs(M.DEFAULTS) do
    merged[k] = v
  end
  for k, v in pairs(opts or {}) do
    merged[k] = v
  end
  return merged
end

---Render a parsed sentence as an indented nested list.
---@param tree table `{ text = string, tokens = table[] }`
---@param opts table|nil
---@return string[] lines, table<integer, integer> index Line number (1-indexed) to token `i`
function M.render(tree, opts)
  opts = with_defaults(opts)
  local tokens = tree and tree.tokens or {}
  if #tokens == 0 then
    return { "(no parse)" }, {}
  end

  local displayed = opts.include_punct and tokens or without_punct_leaves(tokens)
  local _, children, roots = build(displayed)

  local lines, index = {}, {}
  local header = tree.text or ""
  if header ~= "" then
    table.insert(lines, header)
  end
  table.insert(lines, ("(%d words)"):format(M.word_count(tokens)))
  table.insert(lines, "")

  local function emit(token, prefix, guide)
    local parts = { token.text }
    if token.pos then
      table.insert(parts, token.pos)
    end
    table.insert(parts, M.label(token.dep, opts.dep_labels))
    table.insert(lines, prefix .. guide .. table.concat(parts, opts.separator))
    index[#lines] = token.i
  end

  -- `seen` is a cycle guard. A dependency parse is a tree by construction, so a cycle means
  -- the input is malformed, and the honest failure is a truncated tree rather than a hung
  -- editor. This is on the hover path; it must not be able to spin.
  --
  -- `depth` is threaded rather than inferred from the guide string. Inferring it meant
  -- comparing `guide:sub(1, 3)` against "└──", which is wrong on the first byte: the box
  -- characters are three bytes each in UTF-8, so that slice is one glyph, not three.
  local seen = {}
  local function walk(token, prefix, guide, last)
    if seen[token.i] then
      return
    end
    seen[token.i] = true
    emit(token, prefix, guide)
    local kids = children[token.i] or {}
    local child_prefix = prefix
    if guide ~= "" then
      child_prefix = prefix .. (last and "    " or "│   ")
    end
    for n, kid in ipairs(kids) do
      local is_last = n == #kids
      walk(kid, child_prefix, is_last and "└── " or "├── ", is_last)
    end
  end

  for _, root in ipairs(roots) do
    walk(root, "", "", true)
  end

  return lines, index
end

return M
