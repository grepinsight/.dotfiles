---Rendering a dependency parse as a nested list.
---
---Pure: no `vim.api`, no filesystem, same as `annotate/anchor.lua`. Also the only thing on
---the hover path once a sentence is cached, so it is both the likeliest to be wrong and the
---one whose speed matters.
---
---Input is spaCy's token shape: 0-indexed `i`, `head` pointing at the governing token's `i`,
---a root being a token whose head is itself. Returned line numbers are 1-indexed, matching
---window cursors rather than the 0-indexed extmark convention used elsewhere here.
local palette = require("albertlint.parse.palette")

local M = {}

---Dependency labels, glossed. Data, not logic, the same split `rules.lua` uses.
---
---`en_core_web_sm` emits the ClearNLP scheme, not strict Universal Dependencies, hence
---`dobj`/`pobj` rather than UD's `obj`/`obl`. The glosses are one reader's translation and a
---linguist would argue with several; `dep_labels = "raw"` is there for when the jargon is
---what you want.
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
  pos_column = true,
  phrases = true,
  phrase_max = 46,
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
---Leaves only. Removing a `punct` token with children would orphan its subtree, and losing
---half a sentence is a worse failure than one stray comma on screen.
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

---`vim.tbl_extend` would do this, and is the one `vim.*` call that would otherwise appear in
---a file that claims to run without an editor.
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

---The text span each token's whole subtree covers.
---
---What makes the tree readable rather than merely correct: a dependency tree names the *head*
---of a phrase, so `In · ADP · preposition` is the honest label for a node whose subtree is
---`In this case`, and the phrase is unrecoverable from the label alone.
---
---Over the **full** token list, so a phrase does not silently lose its comma. Offsets are
---spaCy's `idx`, 0-indexed from the start of the sentence.
---@param tokens table[]
---@return table<integer, table> `{ [token.i] = { s = integer, e = integer } }`
function M.subtree_spans(tokens)
  -- Without `idx` every span starts at 0 and the column shows the sentence's first word
  -- against every node: confidently wrong, which is worse than absent.
  if #tokens == 0 or tokens[1].idx == nil then
    return {}
  end
  local by_index, spans = {}, {}
  for _, t in ipairs(tokens) do
    by_index[t.i] = t
    spans[t.i] = { s = t.idx, e = t.idx + #t.text }
  end

  -- Widen toward the ancestors rather than descending: cannot blow the stack or spin on the
  -- malformed input the render's cycle guard exists for.
  --
  -- `by_index` is load-bearing. Finding each parent by scanning the token list made this
  -- O(n^3) and cost 437us median / 760us worst against a 1ms hover budget, measured
  -- 2026-09-09. Do not replace the lookup with a search.
  for _, t in ipairs(tokens) do
    local node, hops = t, 0
    local s, e = spans[t.i].s, spans[t.i].e
    while node.head ~= node.i and hops < #tokens do
      local parent = by_index[node.head]
      if not parent then
        break
      end
      local span = spans[parent.i]
      if s < span.s then
        span.s = s
      end
      if e > span.e then
        span.e = e
      end
      node, hops = parent, hops + 1
    end
  end
  return spans
end

---Render a parsed sentence as an indented nested list.
---
---Returns highlight spans rather than applying them, since this module is pure. **Byte**
---offsets: the guide glyphs and the `·` separator are multibyte and extmarks count bytes.
---@param tree table `{ text = string, tokens = table[] }`
---@param opts table|nil
---@return string[] lines, table<integer, integer> index, table[] highlights
function M.render(tree, opts)
  opts = with_defaults(opts)
  local tokens = tree and tree.tokens or {}
  if #tokens == 0 then
    return { "(no parse)" }, {}, {}
  end

  local displayed = opts.include_punct and tokens or without_punct_leaves(tokens)
  local _, children, roots = build(displayed)
  local spans = opts.phrases and M.subtree_spans(tokens) or {}
  local text = tree.text or ""

  local lines, index, highlights = {}, {}, {}

  ---@param line integer
  ---@param col integer
  ---@param str string
  ---@param group string|nil
  local function mark(line, col, str, group)
    if group and #str > 0 then
      table.insert(highlights, { line = line, col = col, end_col = col + #str, group = group })
    end
  end

  if text ~= "" then
    table.insert(lines, text)
    mark(#lines, 0, text, "AlbertLintTreeHeader")
  end
  local count = ("(%d words)"):format(M.word_count(tokens))
  table.insert(lines, count)
  mark(#lines, 0, count, "AlbertLintTreeCount")
  table.insert(lines, "")

  ---The phrase a node stands for, or nil when it adds nothing: a leaf, where the phrase is
  ---the word, or a root, where the header already shows the whole sentence.
  ---@param token table
  ---@param is_root boolean
  ---@return string|nil
  local function phrase_of(token, is_root)
    if not opts.phrases or is_root or text == "" then
      return nil
    end
    local span = spans[token.i]
    if not span then
      return nil
    end
    local slice = text:sub(span.s + 1, span.e)
    if slice == token.text or slice == "" then
      return nil
    end
    if #slice > opts.phrase_max then
      slice = slice:sub(1, opts.phrase_max - 1) .. "…"
    end
    return "[" .. slice .. "]"
  end

  local function emit(token, prefix, guide, is_root)
    local line = #lines + 1
    local col = 0
    local chunks = {}
    local function add(str, group)
      table.insert(chunks, str)
      mark(line, col, str, group)
      col = col + #str
    end

    add(prefix .. guide, "AlbertLintTreeGuide")
    add(token.text, palette.group(token.pos))
    if opts.pos_column and token.pos then
      add(opts.separator, "AlbertLintTreeGuide")
      add(token.pos, palette.group(token.pos))
    end
    add(opts.separator, "AlbertLintTreeGuide")
    add(M.label(token.dep, opts.dep_labels), "AlbertLintTreeDep")
    local phrase = phrase_of(token, is_root)
    if phrase then
      add("  ", nil)
      add(phrase, "AlbertLintTreePhrase")
    end

    table.insert(lines, table.concat(chunks))
    index[line] = token.i
  end

  -- `seen` is a cycle guard: a malformed parse must give a truncated tree, not a hung editor.
  -- `last` is threaded rather than inferred from the guide string, because `guide:sub(1, 3)`
  -- against "└──" compares one glyph to three: the box characters are 3 bytes each.
  local seen = {}
  local function walk(token, prefix, guide, last, is_root)
    if seen[token.i] then
      return
    end
    seen[token.i] = true
    emit(token, prefix, guide, is_root)
    local kids = children[token.i] or {}
    local child_prefix = prefix
    if guide ~= "" then
      child_prefix = prefix .. (last and "    " or "│   ")
    end
    for n, kid in ipairs(kids) do
      local is_last = n == #kids
      walk(kid, child_prefix, is_last and "└── " or "├── ", is_last, false)
    end
  end

  for _, root in ipairs(roots) do
    walk(root, "", "", true, true)
  end

  return lines, index, highlights
end

return M
