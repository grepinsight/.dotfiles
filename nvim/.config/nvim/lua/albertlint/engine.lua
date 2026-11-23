---Turns the rule catalogue into diagnostics for a buffer.
---
---The engine's real job is knowing where NOT to look. A prose linter that flags
---`python -m venv` inside backticks, or a lowercase brand inside a URL, gets switched off
---within a day, so context masking is not a refinement here: it is the reason the rule set
---can be aggressive at all.
local rules_mod = require("albertlint.rules")

local M = {}

---One compiled regex per rule, built lazily and cached. Rebuilt only when the catalogue
---changes, which in practice means on `:AlbertLintReload`.
local compiled = {}

---@param s string
---@return string escaped for use as a literal inside a Vim regex
local function escape_literal(s)
  return (s:gsub("[\\^$.*~%[%]/]", "\\%0"))
end

---Sorted for determinism: an unstable key order would make the compiled regex, and so
---the diagnostic column on an overlapping match, vary between sessions.
---@param map table<string, string>
---@return string[]
local function sorted_keys(map)
  local keys = {}
  for k in pairs(map) do
    table.insert(keys, k)
  end
  table.sort(keys)
  return keys
end

---@param rule table
---@return vim.regex|nil, string|nil kind
local function compile(rule)
  if compiled[rule.id] ~= nil then
    return compiled[rule.id].re, compiled[rule.id].kind
  end
  local re, kind
  if rule.words then
    local alts = {}
    for _, word in ipairs(sorted_keys(rule.words)) do
      table.insert(alts, escape_literal(word))
    end
    -- \C forces case sensitivity so `Slack` is not reported as a miss of `slack`.
    re = vim.regex([[\C\<\(]] .. table.concat(alts, [[\|]]) .. [[\)\>]])
    kind = "words"
  elseif rule.phrases then
    local alts = {}
    for _, phrase in ipairs(sorted_keys(rule.phrases)) do
      table.insert(alts, escape_literal(phrase))
    end
    re = vim.regex([[\c\(]] .. table.concat(alts, [[\|]]) .. [[\)]])
    kind = "phrases"
  elseif rule.vimre then
    re = vim.regex(rule.vimre)
    kind = "vimre"
  else
    kind = "fn"
  end
  compiled[rule.id] = { re = re, kind = kind }
  return re, kind
end

function M.reset()
  compiled = {}
end

---All non-overlapping matches of `re` in `text`, as 0-indexed byte ranges.
---
---`match_str` only ever reports the first match, so the caller has to walk the string.
---The `math.max` guard stops a zero-width match from spinning forever.
---@param re vim.regex
---@param text string
---@return integer[][] list of {start, stop}
local function all_matches(re, text)
  local out, offset = {}, 0
  while offset <= #text do
    local s, e = re:match_str(text:sub(offset + 1))
    if not s then
      break
    end
    table.insert(out, { offset + s, offset + e })
    offset = offset + math.max(e, s + 1)
  end
  return out
end

---Columns that rules must ignore, as a per-line boolean mask.
---
---Masked: inline code spans, fenced code blocks, YAML frontmatter, URLs, and markdown
---link targets. Every one of these is a place where a lowercase brand or a slash is
---correct, so a match there is noise by construction rather than by degree.
---@param lines string[]
---@return table<integer, boolean[]> mask keyed by 0-indexed line
local function build_mask(lines)
  local mask = {}
  local in_fence, in_frontmatter = false, false

  for i, line in ipairs(lines) do
    local lnum = i - 1
    local cols = {}

    if i == 1 and line:match("^%-%-%-%s*$") then
      in_frontmatter = true
      mask[lnum] = setmetatable({}, { __index = function() return true end })
      goto continue
    elseif in_frontmatter then
      if line:match("^%-%-%-%s*$") then
        in_frontmatter = false
      end
      mask[lnum] = setmetatable({}, { __index = function() return true end })
      goto continue
    end

    if line:match("^%s*```") or line:match("^%s*~~~") then
      in_fence = not in_fence
      mask[lnum] = setmetatable({}, { __index = function() return true end })
      goto continue
    end
    if in_fence then
      mask[lnum] = setmetatable({}, { __index = function() return true end })
      goto continue
    end

    -- Inline code spans. Toggling on every backtick handles the common cases and
    -- degrades gracefully on an unmatched one: the tail of the line goes unlinted,
    -- which is quieter than the alternative of linting inside code.
    do
      local inside = false
      for col = 1, #line do
        local ch = line:sub(col, col)
        if ch == "`" then
          inside = not inside
          cols[col - 1] = true
        elseif inside then
          cols[col - 1] = true
        end
      end
    end

    -- URLs and markdown link targets.
    for _, pat in ipairs({ "https?://%S+", "www%.%S+", "%]%([^)]*%)" }) do
      local init = 1
      while true do
        local s, e = line:find(pat, init)
        if not s then
          break
        end
        for col = s, e do
          cols[col - 1] = true
        end
        init = e + 1
      end
    end

    mask[lnum] = cols
    ::continue::
  end

  return mask
end

M._build_mask = build_mask

---Custom matchers for rules whose logic is counting or lookup rather than a pattern.
---Each returns a list of {col, end_col, message_args}.
local fns = {}

---A slash between two word characters, minus the forms where a slash is correct.
fns.slash_list = function(line)
  local allow = {
    ["and/or"] = true, ["he/she"] = true, ["she/he"] = true, ["read/write"] = true,
    ["i/o"] = true, ["km/h"] = true, ["24/7"] = true, ["w/"] = true, ["n/a"] = true,
    ["ca/co"] = true, ["a/b"] = true, ["r/w"] = true, ["s/n"] = true,
  }
  local out, init = {}, 1
  while true do
    local s, e = line:find("[%w%-]+/[%w%-]+", init)
    if not s then
      break
    end
    local token = line:sub(s, e):lower()
    -- A date (2020/09/01) or a path fragment is not an undecided word pair.
    if not allow[token] and not token:match("^%d+/%d+$") then
      table.insert(out, { s - 1, e, {} })
    end
    init = e + 1
  end
  return out
end

---Two or more relative pronouns inside one sentence.
fns.stacked_relatives = function(line)
  local out = {}
  for sentence_start, sentence in line:gmatch("()([^.!?]+)") do
    local count, first = 0, nil
    for pos, word in sentence:gmatch("()(%a+)") do
      local w = word:lower()
      if w == "which" or w == "that" or w == "where" or w == "who" then
        count = count + 1
        first = first or pos
      end
    end
    if count >= 2 and first then
      local col = sentence_start + first - 2
      table.insert(out, { col, col + 5, {} })
    end
  end
  return out
end

---`a`/`an` before an uncountable noun, allowing up to two modifiers in between.
---
---The modifier slot is why this cannot be a Lua pattern: the real instance from the 2020
---corpus is `a write access`, not `a access`, and Lua has no optional multi-word group.
local mass_re
fns.mass_noun_article = function(line)
  if not mass_re then
    local alts = {}
    for _, noun in ipairs(rules_mod.mass_nouns) do
      table.insert(alts, (noun:gsub("%s+", [[\s\+]])))
    end
    mass_re = vim.regex(
      [[\c\<an\?\s\+\(\a\+\s\+\)\{0,2}\(]] .. table.concat(alts, [[\|]]) .. [[\)\>]]
    )
  end
  local out, offset = {}, 0
  while offset <= #line do
    local st, en = mass_re:match_str(line:sub(offset + 1))
    if not st then
      break
    end
    local matched = line:sub(offset + st + 1, offset + en)
    local noun = matched:match("(%S+)$")
    table.insert(out, { offset + st, offset + en, { noun } })
    offset = offset + math.max(en, st + 1)
  end
  return out
end

---Two additive markers in one clause.
fns.double_additive = function(line)
  local lower = line:lower()
  local out = {}
  local a = lower:find("%f[%a]also%f[%A]")
  if a and (lower:find("%f[%a]as well%f[%A]", a) or lower:find("%f[%a]too%f[%A]", a)) then
    table.insert(out, { a - 1, a + 3, {} })
  end
  local add = lower:find("%f[%a]add%a*%f[%A]")
  if add then
    local extra = lower:find("%f[%a]additional%f[%A]", add)
    if extra then
      table.insert(out, { extra - 1, extra + 9, {} })
    end
  end
  return out
end

---Three or more hedges in one line. Line-scoped rather than paragraph-scoped because a
---diagnostic has to attach somewhere, and the first hedge on the line is the honest
---anchor for "this sentence is over-hedged".
fns.hedge_density = function(line)
  local hedges = {
    "i guess", "maybe", "possibly", "perhaps", "kind of", "sort of", "probably",
    "i think", "apologies", "dumb question", "basic question", "i could be wrong",
    "not sure if", "supposedly", "presumably",
  }
  local lower = line:lower()
  local count, first = 0, nil
  for _, h in ipairs(hedges) do
    local s = lower:find(h, 1, true)
    if s then
      count = count + 1
      first = math.min(first or s, s)
    end
  end
  if count >= 3 and first then
    return { { first - 1, first - 1 + 8, {} } }
  end
  return {}
end

---Misspellings, via Neovim's own spell checker.
---
---`vim.spell.check` works with `spell` off and returns {word, kind, col}, so this needs no
---window state and no dictionary of its own. Only `bad` is reported:
---  bad    a genuine misspelling            -> flag
---  caps   a lowercase sentence start       -> SKIP, allowlisted in his English Practice
---  rare   a real but unusual word          -> skip, too noisy in technical prose
---  local  correct in another region        -> skip
---
---A word he coins on purpose (`motivationless`) will show as `bad` once. `zg` adds it to
---his spellfile and it never returns, which is the correct escape hatch and the reason this
---rule can be on by default despite technical prose being full of jargon.
fns.typo = function(line)
  local ok, hits = pcall(vim.spell.check, line)
  if not ok then
    return {}
  end
  local out = {}
  for _, hit in ipairs(hits) do
    local word, kind, col = hit[1], hit[2], hit[3]
    -- Technical prose is full of words no dictionary has. Three cheap tests remove the
    -- entire false-positive class without a dictionary of our own:
    --   ALLCAPS         an initialism (MCP, SQL, ETL), never a typo here
    --   inner capital   a product name (GitHub, RStudio, JavaScript), same
    --   known_words     already in this plugin's own brand and acronym tables
    -- The cost is that a misspelled proper noun (`GitHb`) is missed. For his prose that is
    -- the right side to err on: ordinary-word typos are the ones that reach a reader.
    local allcaps = word:upper() == word and word:match("%a")
    local inner_capital = word:match("%a%u")
    local known = rules_mod.known_words[word:lower()]
    if kind == "bad" and not allcaps and not inner_capital and not known then
      table.insert(out, { col - 1, col - 1 + #word, { word } })
    end
  end
  return out
end

---`a`/`an` chosen by letter rather than by sound.
fns.a_vs_an = function(line)
  local ex = rules_mod.an_exceptions
  local function listed(word, list)
    for _, w in ipairs(list) do
      if word == w then
        return true
      end
    end
    return false
  end
  local out = {}
  for pos, article, word in line:gmatch("()%f[%a]([Aa]n?)%s+(%a+)") do
    local a, w = article:lower(), word:lower()
    local vowel_letter = w:match("^[aeiou]") ~= nil
    local wrong
    if a == "a" then
      wrong = vowel_letter and not listed(w, ex.a_despite_vowel)
    else
      wrong = (not vowel_letter) and not listed(w, ex.an_despite_consonant)
    end
    if wrong then
      table.insert(out, { pos - 1, pos - 1 + #article, { a == "a" and "an" or "a" } })
    end
  end
  return out
end

M._fns = fns

---@param rule table
---@param matched string
---@param replacement string|nil
---@return string
local function render(rule, matched, replacement)
  local slots = select(2, rule.message:gsub("%%s", ""))
  if slots >= 2 then
    return rule.message:format(matched, replacement or "")
  elseif slots == 1 then
    return rule.message:format(replacement or matched)
  end
  return rule.message
end

---@param bufnr integer
---@param tier string "live" | "exit" | "all"
---@param opts table config
---@return vim.Diagnostic[]
function M.scan(bufnr, tier, opts)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local mask = build_mask(lines)
  local disabled = {}
  for _, id in ipairs(opts.disabled_rules or {}) do
    disabled[id] = true
  end
  local enabled_optional = {}
  for _, id in ipairs(opts.enabled_optional or {}) do
    enabled_optional[id] = true
  end

  local active = {}
  for _, rule in ipairs(rules_mod.rules) do
    if not disabled[rule.id] and (tier == "all" or rule.tier == tier) then
      table.insert(active, rule)
    end
  end
  for _, rule in ipairs(rules_mod.optional) do
    if enabled_optional[rule.id] and (tier == "all" or rule.tier == tier) then
      table.insert(active, rule)
    end
  end

  local diagnostics = {}
  for i, line in ipairs(lines) do
    local lnum = i - 1
    local cols = mask[lnum] or {}
    for _, rule in ipairs(active) do
      local re, kind = compile(rule)
      local hits = {}
      if kind == "fn" then
        for _, hit in ipairs(fns[rule.fn](line, lnum)) do
          table.insert(hits, { hit[1], hit[2], hit[3] })
        end
      elseif re then
        for _, range in ipairs(all_matches(re, line)) do
          local matched = line:sub(range[1] + 1, range[2])
          local replacement
          if kind == "words" then
            replacement = rule.words[matched]
            -- A catalogue entry whose replacement equals the match produces a diagnostic
            -- that says `dbt is an initialism: dbt`. Guard here rather than trusting every
            -- future table edit to get it right.
            if replacement == matched then
              goto continue_hit
            end
          elseif kind == "phrases" then
            replacement = rule.phrases[matched:lower()]
          end
          table.insert(hits, { range[1], range[2], { matched, replacement } })
          ::continue_hit::
        end
      end
      for _, hit in ipairs(hits) do
        if not cols[hit[1]] then
          local args = hit[3] or {}
          table.insert(diagnostics, {
            lnum = lnum,
            col = hit[1],
            end_lnum = lnum,
            end_col = hit[2],
            severity = (opts.severity or {})[rule.id] or rule.severity,
            source = "albertlint",
            code = rule.id,
            message = render(rule, args[1] or line:sub(hit[1] + 1, hit[2]), args[2] or args[1]),
          })
        end
      end
    end
  end
  return diagnostics
end

return M
