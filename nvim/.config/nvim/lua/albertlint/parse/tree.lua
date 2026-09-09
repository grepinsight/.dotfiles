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
---
---`palette.lua` is required for the group names only. It is a data table, so this module is
---still runnable outside an editor.
local palette = require("albertlint.parse.palette")

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

---The text span each token's whole subtree covers.
---
---This is what makes the tree readable rather than merely correct. A dependency tree names
---the *head* of every phrase, so `In · ADP · preposition` is the honest label for a node whose
---subtree is the phrase `In this case`, and a reader who does not already think in
---dependencies cannot recover the phrase from the label. Showing the span turns each line
---into a statement about a piece of the sentence you can point at.
---
---Computed over the **full** token list, including punctuation that the render drops, so a
---phrase is not silently missing its comma. Offsets are spaCy's `idx`, which is 0-indexed
---from the start of the sentence.
---@param tokens table[]
---@return table<integer, table> `{ [token.i] = { s = integer, e = integer } }`
function M.subtree_spans(tokens)
  -- No offsets, no phrases. Without `idx` every span would start at 0 and the column would
  -- show the sentence's first word against every node, which is worse than showing nothing:
  -- it is confidently wrong. Caught by the existing specs on 2026-09-09, whose hand-written
  -- fixtures predate `idx` and so exercised exactly this path.
  if #tokens == 0 or tokens[1].idx == nil then
    return {}
  end
  local by_index, spans = {}, {}
  for _, t in ipairs(tokens) do
    by_index[t.i] = t
    spans[t.i] = { s = t.idx, e = t.idx + #t.text }
  end

  -- Widen from each token toward its ancestors, rather than a recursive descent. Same
  -- result, and it cannot blow the stack or spin on the malformed input the render's cycle
  -- guard exists for.
  --
  -- `by_index` is the whole performance story here. The first version found each parent by
  -- scanning the token list, which made this O(n^3) and took the hover from 95us to 437us
  -- median with a 760us worst case, close enough to the 1ms target to matter. Measured
  -- 2026-09-09; do not replace the lookup with a search.
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
---Returns highlight spans alongside the lines rather than applying them, because this module
---is pure. The caller turns them into extmarks. Byte offsets, not character offsets: the
---guide glyphs and the `·` separator are multibyte, and `nvim_buf_set_extmark` counts bytes.
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

  ---The phrase a node stands for, or nil when it adds nothing.
  ---
  ---Skipped for a leaf (the phrase is the word) and for a root (the header already shows the
  ---whole sentence), which is what keeps the column from repeating what is on screen.
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

  -- `seen` is a cycle guard. A dependency parse is a tree by construction, so a cycle means
  -- the input is malformed, and the honest failure is a truncated tree rather than a hung
  -- editor. This is on the hover path; it must not be able to spin.
  --
  -- `depth` is threaded rather than inferred from the guide string. Inferring it meant
  -- comparing `guide:sub(1, 3)` against "└──", which is wrong on the first byte: the box
  -- characters are three bytes each in UTF-8, so that slice is one glyph, not three.
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
