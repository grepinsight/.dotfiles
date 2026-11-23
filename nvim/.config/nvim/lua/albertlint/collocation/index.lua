---Build a collocation index from the writer's own collected phrases.
---
---Deliberately pure: no `vim.api`, no `vim.fn`, no filesystem. Takes note text in, gives
---entries out, and answers candidate queries over them. Same reason `annotate/anchor.lua`
---and `style/scope.lua` are pure, and the same payoff: the ranking rules are the part most
---likely to be wrong, and they are testable with string literals.
---
---Why a personal corpus rather than a model. A next-word suggester built from a general
---model offers general English. The point here is the opposite: surface the phrases the
---author has already collected and the replacements he has already been told to use, so the
---menu is a reminder of vocabulary he is trying to acquire rather than a source of prose he
---did not write. `~/Thoughts/03-Resources/English/` holds 151 phrase notes and 25
---Better English notes, every one of them recorded because it came up in his own writing.
local M = {}

--- Frontmatter ---------------------------------------------------------------------

---Strip one layer of surrounding quotes.
---@param s string
---@return string
local function unquote(s)
  local inner = s:match('^"(.*)"$') or s:match("^'(.*)'$")
  return inner or s
end

---Parse the YAML frontmatter of a note into scalars and string lists.
---
---A deliberately small parser, not a YAML implementation. It handles `key: value` and
---`key:` followed by `  - item` lines, which is every shape these notes actually use. A
---real YAML parser would be a dependency, and this config keeps Telescope optional rather
---than take one lightly.
---
---Anything it does not understand is skipped rather than erroring, because a hand-edited
---note with an odd line should cost one entry, not the whole index.
---@param text string
---@return table<string, string|string[]>
function M.parse_frontmatter(text)
  local fields = {}
  local lines = vim.split(text, "\n", { plain = true })
  if lines[1] ~= "---" then
    return fields
  end

  local list_key = nil
  for i = 2, #lines do
    local line = lines[i]
    if line == "---" then
      break
    end

    local item = line:match("^%s+%-%s+(.*)$")
    if item and list_key then
      table.insert(fields[list_key], unquote(vim.trim(item)))
    else
      local key, value = line:match("^([%w_]+):%s*(.*)$")
      if key then
        value = vim.trim(value)
        if value == "" then
          -- A key with nothing after it opens a list. If no items follow, it stays an
          -- empty list rather than becoming nil, so callers never branch on the shape.
          list_key = key
          fields[key] = {}
        else
          list_key = nil
          fields[key] = unquote(value)
        end
      end
    end
  end
  return fields
end

--- Entries -------------------------------------------------------------------------

---Split a comma-separated field into trimmed, non-empty parts.
---@param s string|nil
---@return string[]
local function csv(s)
  local out = {}
  for part in tostring(s or ""):gmatch("[^,]+") do
    local trimmed = vim.trim(part)
    if trimmed ~= "" then
      table.insert(out, trimmed)
    end
  end
  return out
end

---One entry per *surface form*, not per note.
---
---A note titled `Pushback` with alias `push back` yields two entries pointing at the same
---note, because the author may reach for either and both should match. Deduplicated on the
---lowercased surface, so a note whose alias repeats its title does not produce two
---identical menu rows.
---
---`be_replacement` notes contribute their replacement as the surface and their originals as
---extra match text, which is the useful direction: typing what he *would have* written
---should surface what he decided to write instead.
---@param notes table[] Each { text = string, path = string|nil, kind = string|nil }
---@return table[] entries

---A surface has to be short enough to be *vocabulary* rather than *composition*.
---
---This cap is the whole justification for this source existing alongside a blocked Copilot.
---A word or a short collocation is vocabulary, and choosing one from a menu is an act of
---judgment. A clause is composition, and accepting it with a keystroke is not. Running the
---first version over the real corpus surfaced two `be_replacement` values that are entire
---sentences (`"Check the daily notes: when did I ask which skills I have..."`), which the
---menu would have offered as one-key completions. That is precisely the Copilot behaviour
---the author blocked in markdown, arriving through a different door.
---
---Five words, and terminal punctuation disqualifies outright: a surface ending in `.`, `?`,
---or `!` is a sentence or an example, not a phrase. Longer Better English replacements are
---still valuable, they just belong to the annotation tier rather than the completion menu.
---@type integer
local MAX_SURFACE_WORDS = 5

---@param surface string
---@return boolean
local function completable(surface)
  if surface == "" or not surface:match("%a") then
    return false
  end
  if surface:match("[%.%?!]$") then
    return false
  end
  return #vim.split(surface, "%s+", { trimempty = true }) <= MAX_SURFACE_WORDS
end

---@param notes table[] Each { text = string, path = string|nil, kind = string|nil }
---@return table[] entries
function M.build(notes)
  local entries = {}
  local seen = {}

  for _, note in ipairs(notes) do
    local f = M.parse_frontmatter(note.text)
    local surfaces = {}
    local detail, example, source_kind

    -- `note.kind` comes from the caller, which knows the directory. Inferring it from which
    -- frontmatter fields happen to be filled in was too strict and silently dropped 32 of
    -- 176 real notes: older phrase notes carry a title and aliases but no
    -- `phrase_definition`, and `AI-Pilled`, `Churn Through`, `Heavy Tail` and `I Buy That`
    -- are exactly the vocabulary this source exists to surface.
    local kind = note.kind
    if not kind then
      kind = f.be_replacement and "better-english" or "phrase"
    end

    if kind == "better-english" and f.be_replacement then
      -- The replacement is the thing to offer, not the original: typing what he WOULD have
      -- written should surface what he decided to write instead.
      table.insert(surfaces, f.be_replacement)
      detail = f.be_why
      example = type(f.be_originals) == "table" and f.be_originals[1] or f.be_originals
      source_kind = "better-english"
    elseif kind == "phrase" and f.title then
      table.insert(surfaces, f.title)
      for _, alias in ipairs(type(f.aliases) == "table" and f.aliases or {}) do
        table.insert(surfaces, alias)
      end
      detail = f.phrase_definition
      example = f.phrase_canonical_example
      source_kind = "phrase"
    end

    for _, surface in ipairs(surfaces) do
      surface = vim.trim(tostring(surface or ""))
      local key = surface:lower()
      -- `completable` drops empties, Korean glosses (an alias field occasionally holds one,
      -- useful to read and useless to complete English on), and anything sentence-shaped.
      if not seen[key] and completable(surface) then
        seen[key] = true
        table.insert(entries, {
          surface = surface,
          lower = key,
          words = #vim.split(key, "%s+", { trimempty = true }),
          detail = detail and vim.trim(tostring(detail)) or nil,
          example = example and vim.trim(tostring(example)) or nil,
          synonyms = csv(f.phrase_synonyms),
          kind = source_kind,
          title = f.title,
          path = note.path,
        })
      end
    end
  end

  return entries
end

--- Matching ------------------------------------------------------------------------

---The trailing words of `before` that could be the start of a phrase.
---
---Up to `max_words` of them, longest first, which is what makes this a *collocation*
---completer rather than a dictionary lookup. Matching only the current word would offer
---every phrase beginning with `push`; also matching `give me push` lets the index answer
---"what did I collect that continues this".
---@param before string Text on the line before the cursor
---@param max_words integer
---@return string[] prefixes Longest first
function M.prefixes(before, max_words)
  local words = vim.split(vim.trim(before), "%s+", { trimempty = true })
  local out = {}
  for n = math.min(max_words, #words), 1, -1 do
    local slice = {}
    for i = #words - n + 1, #words do
      table.insert(slice, words[i])
    end
    table.insert(out, table.concat(slice, " "):lower())
  end
  return out
end

---Candidates for the text before the cursor, best first.
---
---Ranking, in order, and each rule exists to keep a specific kind of noise out:
---
---  1. **Longer matched prefix wins.** A two-word match is far more likely to be what he
---     means than a one-word match that happens to share three letters.
---  2. **Then fewer words in the phrase.** Given the same match, the shorter completion is
---     the lower-commitment suggestion.
---  3. **Then alphabetical.** Not a quality signal, just determinism: without a total order
---     the menu reshuffles between identical queries, which reads as flicker.
---
---A prefix shorter than `min_chars` returns nothing. Completing on one character would put
---the whole index in the menu on the first keystroke of every word.
---@param entries table[] From `M.build`
---@param before string Text on the line before the cursor
---@param opts table|nil { min_chars = 2, max_words = 3, limit = 20 }
---@return table[] matches Each entry plus `matched` (the prefix it matched on)
function M.candidates(entries, before, opts)
  opts = opts or {}
  local min_chars = opts.min_chars or 2
  local max_words = opts.max_words or 3
  local limit = opts.limit or 20

  local matches, taken = {}, {}
  for _, prefix in ipairs(M.prefixes(before, max_words)) do
    if #prefix >= min_chars then
      for _, entry in ipairs(entries) do
        -- A phrase equal to the prefix is not a completion, it is what he already typed.
        if not taken[entry.lower]
          and entry.lower ~= prefix
          and entry.lower:sub(1, #prefix) == prefix
        then
          taken[entry.lower] = true
          table.insert(matches, vim.tbl_extend("keep", { matched = prefix }, entry))
        end
      end
    end
  end

  table.sort(matches, function(a, b)
    if #a.matched ~= #b.matched then
      return #a.matched > #b.matched
    end
    if a.words ~= b.words then
      return a.words < b.words
    end
    return a.lower < b.lower
  end)

  if #matches > limit then
    -- Truncate loudly rather than silently: the caller reports the drop.
    local kept = {}
    for i = 1, limit do
      kept[i] = matches[i]
    end
    return kept, #matches - limit
  end
  return matches, 0
end

M._completable = completable
M._MAX_SURFACE_WORDS = MAX_SURFACE_WORDS
return M
