---Anchor construction and resolution.
---
---Deliberately pure: no `vim.api`, no `vim.fn`, nothing but Lua string operations over a
---list of lines. Relocating a mark after the file changed is the hardest part of this
---module, so it is also the part that must be testable without a running editor.
---
---Positions are 0-indexed rows and 0-indexed **byte** columns, with end columns
---**exclusive**, matching `nvim_buf_set_extmark` exactly. Byte columns rather than
---character columns keeps this consistent with what Neovim hands us and lets plain Lua
---string indexing work on UTF-8 text without a conversion layer.
local M = {}

--- Line indexing -------------------------------------------------------------------

---Flatten lines into one document plus a row-start offset table.
---
---Searching a flattened document rather than line by line is what makes multi-line
---(linewise) marks work with no special case: a paragraph anchor is just a string that
---happens to contain newlines.
---@param lines string[]
---@return table index
local function index_lines(lines)
  local starts = {}
  local offset = 0
  for i = 1, #lines do
    starts[i] = offset
    offset = offset + #lines[i] + 1 -- +1 for the newline joining to the next line
  end
  return { doc = table.concat(lines, "\n"), starts = starts, count = #lines }
end

---Convert a 0-based byte offset in the flattened document to a 0-indexed row and column.
---@param index table
---@param offset integer
---@return integer row, integer col
local function to_pos(index, offset)
  local lo, hi = 1, index.count
  while lo < hi do
    local mid = math.floor((lo + hi + 1) / 2)
    if index.starts[mid] <= offset then
      lo = mid
    else
      hi = mid - 1
    end
  end
  return lo - 1, offset - index.starts[lo]
end

--- String helpers ------------------------------------------------------------------

---Length of the longest common suffix of two strings.
---@param a string
---@param b string
---@return integer
local function common_suffix_len(a, b)
  local limit = math.min(#a, #b)
  local n = 0
  while n < limit and a:byte(#a - n) == b:byte(#b - n) do
    n = n + 1
  end
  return n
end

---Length of the longest common prefix of two strings.
---@param a string
---@param b string
---@return integer
local function common_prefix_len(a, b)
  local limit = math.min(#a, #b)
  local n = 0
  while n < limit and a:byte(n + 1) == b:byte(n + 1) do
    n = n + 1
  end
  return n
end

--- Public API ----------------------------------------------------------------------

---Text currently occupying a stored position, or nil when the position is out of range.
---@param lines string[]
---@param hint table|nil { start = {row, col}, ["end"] = {row, col} }
---@return string|nil
function M.text_at(lines, hint)
  if type(hint) ~= "table" or type(hint.start) ~= "table" or type(hint["end"]) ~= "table" then
    return nil
  end
  local sr, sc = hint.start[1], hint.start[2]
  local er, ec = hint["end"][1], hint["end"][2]
  if type(sr) ~= "number" or type(sc) ~= "number" or type(er) ~= "number" or type(ec) ~= "number" then
    return nil
  end
  if sr < 0 or ec < 0 or er >= #lines or er < sr then
    return nil
  end

  local first, last = lines[sr + 1], lines[er + 1]
  if sc > #first or ec > #last then
    return nil
  end

  if sr == er then
    if ec < sc then
      return nil
    end
    return first:sub(sc + 1, ec)
  end

  local parts = { first:sub(sc + 1) }
  for row = sr + 1, er - 1 do
    table.insert(parts, lines[row + 1])
  end
  table.insert(parts, last:sub(1, ec))
  return table.concat(parts, "\n")
end

---Build an anchor for a range.
---@param lines string[]
---@param start_pos integer[] {row, col}, inclusive
---@param end_pos integer[] {row, col}, col exclusive
---@param context_chars integer Bytes of surrounding text to keep on each side
---@return table anchor { text, prefix, suffix, hint }
function M.build(lines, start_pos, end_pos, context_chars)
  local index = index_lines(lines)
  local s = index.starts[start_pos[1] + 1] + start_pos[2]
  local e = index.starts[end_pos[1] + 1] + end_pos[2]

  return {
    text = index.doc:sub(s + 1, e),
    prefix = index.doc:sub(math.max(1, s - context_chars + 1), s),
    suffix = index.doc:sub(e + 1, e + context_chars),
    hint = {
      start = { start_pos[1], start_pos[2] },
      ["end"] = { end_pos[1], end_pos[2] },
    },
  }
end

---Find the best occurrence of an anchor's text, scored by surrounding context.
---
---Uses plain (non-pattern) search because annotated phrases routinely contain `.`, `(`,
---`*` and friends, which as a Lua pattern would silently match the wrong thing or
---nothing at all.
---
---Scoring is context overlap: how much of the stored prefix still precedes the
---candidate, plus how much of the stored suffix still follows it. Ties break toward the
---candidate nearest the remembered row, then toward the earliest occurrence, so the
---result is deterministic even for a phrase repeated in identical surroundings.
---@param lines string[]
---@param mark table Needs `text`; uses `prefix`, `suffix`, `hint` when present
---@return table|nil range { start = {row, col}, ["end"] = {row, col} }
function M.search(lines, mark)
  if type(mark.text) ~= "string" or mark.text == "" then
    return nil
  end

  local index = index_lines(lines)
  local prefix = mark.prefix or ""
  local suffix = mark.suffix or ""
  local hint_row = 0
  if type(mark.hint) == "table" and type(mark.hint.start) == "table" then
    hint_row = mark.hint.start[1] or 0
  end

  local best, best_score, best_distance
  local init = 1
  while true do
    local first, last = index.doc:find(mark.text, init, true)
    if not first then
      break
    end

    local before = index.doc:sub(math.max(1, first - #prefix), first - 1)
    local after = index.doc:sub(last + 1, last + #suffix)
    local score = common_suffix_len(before, prefix) + common_prefix_len(after, suffix)

    local row = to_pos(index, first - 1)
    local distance = math.abs(row - hint_row)

    if best == nil or score > best_score or (score == best_score and distance < best_distance) then
      best, best_score, best_distance = { first - 1, last }, score, distance
    end

    init = first + 1
  end

  if best == nil then
    return nil
  end

  local start_row, start_col = to_pos(index, best[1])
  local end_row, end_col = to_pos(index, best[2])
  return { start = { start_row, start_col }, ["end"] = { end_row, end_col } }
end

---Locate a mark in the current lines.
---
---Tier 1: the remembered position still holds the remembered text. O(1), and the case
---that applies whenever nothing changed.
---Tier 2: search by content, scored by context.
---
---@param lines string[]
---@param mark table
---@return table|nil range { start = {row, col}, ["end"] = {row, col} }
---@return boolean relocated True when the position differs from the stored hint
function M.resolve(lines, mark)
  if M.text_at(lines, mark.hint) == mark.text then
    return {
      start = { mark.hint.start[1], mark.hint.start[2] },
      ["end"] = { mark.hint["end"][1], mark.hint["end"][2] },
    }, false
  end

  local found = M.search(lines, mark)
  if found == nil then
    return nil, false
  end
  return found, true
end

return M
