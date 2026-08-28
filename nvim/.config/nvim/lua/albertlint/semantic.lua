---Tier 2: the patterns no regex can see.
---
---His largest logged category is `missing "the" before a specific, known referent` at 106+
---instances, and it is undetectable by pattern matching because deciding it needs to know
---whether the reader has already met the referent. Same for `missing "a" before a count
---noun`, agreement across an intervening phrase, and pronoun ambiguity. Those four are the
---reason this tier exists; everything a regex can catch stays in the deterministic tier
---where it costs nothing.
---
---On demand only. Nothing here runs on a keystroke: it shells out, it takes seconds, and
---it costs money.
local config = require("albertlint.config")

local M = {}

---@param bufnr integer
---@return integer start_lnum, integer end_lnum 0-indexed, end exclusive
local function paragraph_range(bufnr)
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local function blank(i)
    return not lines[i + 1] or lines[i + 1]:match("^%s*$") ~= nil
  end
  local s, e = row, row
  while s > 0 and not blank(s - 1) do
    s = s - 1
  end
  while e < #lines - 1 and not blank(e + 1) do
    e = e + 1
  end
  return s, e + 1
end

---Line range for a configured scope.
---
---`config.semantic.scope` was declared in `config.lua` with a full annotation from the
---start but never read here, so `scope = "buffer"` was an option that did nothing and the
---scope was pinned to the cursor's paragraph. That matters more than it sounds: in a note
---built from one-line paragraphs, the paragraph under the cursor IS one line, and the two
---classes that need prior context (ARTICLE-DEFINITE for an already-introduced referent, and
---REFERENCE) have nothing to work with there. The other two can fire inside one sentence, so
---one line is not literally undiagnosable, but "0 semantic findings" on visibly broken prose
---was the observed symptom.
---
---An explicit `:'<,'>` range still wins over the config, because a range typed at the
---command line is a direct instruction and the config is only a default.
---
---An unknown scope falls back to `paragraph` rather than erroring: a typo in config should
---degrade to the old behaviour, not make the command unusable.
---@param bufnr integer
---@param scope string|nil "paragraph" | "buffer" | "selection"
---@return integer start_lnum, integer end_lnum 0-indexed, end exclusive
---@return string|nil warning Set when the scope value was not recognised
local function scope_range(bufnr, scope)
  if scope == "buffer" then
    return 0, vim.api.nvim_buf_line_count(bufnr)
  elseif scope == "selection" then
    -- The `'<` / `'>` marks survive leaving visual mode, so this is the last selection
    -- rather than a live one. line("'<") is 0 when no selection was ever made in this
    -- buffer, and a 0-indexed start of -1 would be an API error, so guard it.
    local first, last = vim.fn.line("'<"), vim.fn.line("'>")
    if first < 1 or last < first then
      return paragraph_range(bufnr)
    end
    -- Clamp BOTH ends. A mark can outlive the lines it pointed at, and clamping only the
    -- end is not enough: if the buffer shrank past both marks, `first - 1` lands at or
    -- past the line count and the range comes back empty, which would send nothing and
    -- report no findings. Clamping the start and falling back on an empty result keeps the
    -- contract "a non-empty range that exists in this buffer".
    local count = vim.api.nvim_buf_line_count(bufnr)
    local s, e = math.min(first - 1, count - 1), math.min(last, count)
    if s < 0 or e <= s then
      return paragraph_range(bufnr)
    end
    return s, e
  elseif scope == nil or scope == "paragraph" then
    return paragraph_range(bufnr)
  end
  local s, e = paragraph_range(bufnr)
  return s, e, ("unknown scope %q, falling back to paragraph"):format(tostring(scope))
end

local PROMPT = [[
You are checking one writer's English for four specific error classes that pattern matching
cannot detect. He is a fluent Korean L1 speaker; his mechanical slips are already handled
elsewhere, so ignore capitalization, spacing, typos, and hyphenation entirely.

Report ONLY these:

1. ARTICLE-DEFINITE: a missing `the` before a referent the reader has already met, or one
   that is uniquely identifiable from context. His most frequent error by a wide margin.
   Also the mirror case: `the` used for a first mention where `a` is required.
2. ARTICLE-INDEFINITE: a missing `a`/`an` before a singular count noun, including predicate
   nominals (`Is X a python shop?`) and job titles.
3. AGREEMENT: a verb agreeing with the nearest noun rather than its actual head, typically
   across an intervening prepositional phrase (`the number of failed samples need`).
4. REFERENCE: a pronoun or bare `this` with two or more available antecedents, where a
   wrong resolution would change the meaning.

Rules for your output:
- Report a finding ONLY if you are confident. A false positive here is worse than a miss,
  because it trains him to ignore the linter.
- Do not report style, tone, verbosity, or word choice. Those are out of scope.
- Quote the exact substring from the line so the caller can locate it.
- Return STRICT JSON, no prose, no markdown fence:
  {"findings":[{"line":<number as given>,"quote":"<exact substring>","severity":"warn"|"hint","kind":"ARTICLE-DEFINITE","message":"<one sentence: the fix and why>"}]}
- An empty findings array is a valid and common answer. Return it rather than inventing work.

The text, one line per numbered entry:
]]

---@param text string
---@return table|nil parsed, string|nil err
local function parse_response(text)
  -- Models wrap JSON in a fence often enough that stripping it is cheaper than
  -- re-prompting. Take the outermost braces.
  local json = text:match("%b{}")
  if not json then
    return nil, "no JSON object in response"
  end
  local ok, decoded = pcall(vim.json.decode, json)
  if not ok then
    return nil, "invalid JSON: " .. tostring(decoded)
  end
  if type(decoded) ~= "table" or decoded.findings == nil then
    return nil, "response has no `findings` key"
  end
  return decoded, nil
end

---@param ns integer diagnostic namespace
---@param use_selection boolean
function M.run(ns, use_selection)
  local opts = config.get().semantic
  if not opts.enabled then
    vim.notify("albertlint: semantic tier is disabled in config", vim.log.levels.WARN)
    return
  end
  if vim.fn.executable(opts.cmd[1]) == 0 then
    vim.notify(
      ("albertlint: `%s` not on PATH, so the semantic tier cannot run"):format(opts.cmd[1]),
      vim.log.levels.ERROR
    )
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local start_lnum, end_lnum
  if use_selection then
    start_lnum = vim.fn.line("'<") - 1
    end_lnum = vim.fn.line("'>")
  else
    local warning
    start_lnum, end_lnum, warning = scope_range(bufnr, opts.scope)
    if warning then
      vim.notify("albertlint: " .. warning, vim.log.levels.WARN)
    end
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_lnum, end_lnum, false)
  local numbered = {}
  for i, line in ipairs(lines) do
    -- Absolute buffer line numbers so the model's answer needs no offset arithmetic.
    table.insert(numbered, ("%d: %s"):format(start_lnum + i, line))
  end
  local payload = PROMPT .. table.concat(numbered, "\n") .. "\n"

  vim.notify(("albertlint: semantic pass over %d lines..."):format(#lines), vim.log.levels.INFO)

  vim.system(opts.cmd, { stdin = payload, text = true, timeout = opts.timeout_ms }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        vim.notify(
          ("albertlint: semantic pass failed (exit %d): %s")
            :format(res.code, (res.stderr or ""):sub(1, 200)),
          vim.log.levels.ERROR
        )
        return
      end
      local parsed, err = parse_response(res.stdout or "")
      if not parsed then
        vim.notify("albertlint: " .. err, vim.log.levels.ERROR)
        return
      end

      local severity_map = { warn = vim.diagnostic.severity.WARN, hint = vim.diagnostic.severity.HINT }
      local added, unlocatable = {}, 0
      for _, f in ipairs(parsed.findings) do
        local lnum = tonumber(f.line)
        if lnum then
          lnum = lnum - 1
          local line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1]
          -- Locate the quote rather than trusting a column from the model. If the quote
          -- is not in the line, the finding is dropped and counted: a diagnostic on the
          -- wrong span is worse than no diagnostic.
          local s = line and f.quote and line:find(f.quote, 1, true)
          if s then
            table.insert(added, {
              lnum = lnum,
              col = s - 1,
              end_lnum = lnum,
              end_col = s - 1 + #f.quote,
              severity = severity_map[(f.severity or "hint"):lower()] or vim.diagnostic.severity.HINT,
              source = "albertlint",
              code = "semantic:" .. (f.kind or "?"):lower(),
              message = f.message or "semantic finding",
              user_data = { tier = "semantic" },
            })
          else
            unlocatable = unlocatable + 1
          end
        end
      end

      -- Replace previous semantic findings in this range, keep the deterministic ones.
      local existing = vim.tbl_filter(function(d)
        local is_semantic = d.user_data and d.user_data.tier == "semantic"
        local in_range = d.lnum >= start_lnum and d.lnum < end_lnum
        return not (is_semantic and in_range)
      end, vim.diagnostic.get(bufnr, { namespace = ns }))
      vim.list_extend(existing, added)
      vim.diagnostic.set(ns, bufnr, existing)

      local msg = ("albertlint: %d semantic finding%s"):format(#added, #added == 1 and "" or "s")
      if unlocatable > 0 then
        msg = msg .. (", %d dropped (quote not found in the line)"):format(unlocatable)
      end
      vim.notify(msg, vim.log.levels.INFO)
    end)
  end)
end

M._parse_response = parse_response
M._paragraph_range = paragraph_range
M._scope_range = scope_range
return M
