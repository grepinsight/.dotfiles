---Turning model-returned spans into the corrected copy of a buffer.
---
---The level tiers ask the model for labeled spans rather than a rewritten paragraph, and
---this module is why that choice pays: with no channel for free-form prose, a level-1 pass
---cannot reorder a clause or change tone even if the model wants to. Out-of-level edits are
---unrepresentable rather than forbidden by prompt.
---
---No `vim.*` and no filesystem, deliberately. This is the logic most likely to be wrong, so
---it is testable with string literals. Every offset here is a BYTE offset: the author's
---buffers contain Korean, and Lua's string functions are byte-based, so a character-based
---index would misplace every span after the first multibyte run.
local M = {}

---@class LevelFix
---@field line integer 1-indexed buffer line
---@field quote string Exact substring to replace
---@field replacement string
---@field label string
---@field note string
---@field occurrence integer|nil 1-indexed, defaults to 1

---Byte span of the nth occurrence of `needle` in `haystack`.
---
---Advances by one byte rather than past the whole match, so overlapping occurrences are
---each reachable. That is nearly irrelevant for prose but costs nothing and avoids a
---surprising gap in the counting.
---@param haystack string
---@param needle string
---@param n integer
---@return integer|nil s 1-indexed
---@return integer|nil e 1-indexed, inclusive
local function nth_find(haystack, needle, n)
  if needle == "" or n < 1 then
    return nil
  end
  local from, s, e = 1, nil, nil
  for _ = 1, n do
    s, e = haystack:find(needle, from, true)
    if not s then
      return nil
    end
    from = s + 1
  end
  return s, e
end

---Build the corrected lines from the originals plus a list of fixes.
---
---`lines` is normally the WHOLE buffer even when the pass covered a smaller range, because
---the caller diffs this result against the real buffer and a range-only array would make
---every untouched line read as a deletion. Fixes carry absolute line numbers, matching the
---convention `semantic.lua` already uses so the model needs no offset arithmetic.
---@param lines string[]
---@param start_lnum integer 1-indexed buffer line of lines[1]
---@param fixes LevelFix[]
---@return string[] corrected
---@return table[] placed { fix, lnum (1-indexed), col (0-indexed byte) }, sorted by position
---@return table[] dropped { fix, reason }, sorted by line then by the order given.
---  `reason` is "line out of range", "quote not found", "already applied", or
---  "overlaps an earlier fix"
function M.build(lines, start_lnum, fixes)
  local corrected = {}
  for i, line in ipairs(lines) do
    corrected[i] = line
  end

  -- Resolve every fix to a byte span first, so overlap detection can compare spans rather
  -- than re-searching. `order` preserves the model's ordering as a stable tiebreak.
  local by_line, indices, pending_drops = {}, {}, {}
  for order, fix in ipairs(fixes or {}) do
    local lnum = tonumber(fix.line)
    local idx = lnum and (lnum - start_lnum + 1) or nil
    if not idx or not lines[idx] then
      table.insert(pending_drops, {
        fix = fix, reason = "line out of range", key = math.huge, order = order,
      })
    else
      local s, e = nth_find(lines[idx], tostring(fix.quote or ""), tonumber(fix.occurrence) or 1)
      local repl = tostring(fix.replacement or "")
      if not s then
        table.insert(pending_drops, {
          fix = fix, reason = "quote not found", key = idx, order = order,
        })
      elseif repl ~= "" and lines[idx]:sub(s, s + #repl - 1) == repl then
        -- Already applied. This is reachable whenever the replacement CONTAINS the quote,
        -- because the quote then still matches inside its own output:
        -- `expression error` -> `expression errors` matched again on the corrected line and
        -- produced `expression errorss`. Verified 2026-09-08, and reachable in normal use as
        -- soon as findings are cached and re-applied after a `do`, or if the writer fixes a
        -- line by hand and reruns. A quote-not-found check alone does not catch it.
        table.insert(pending_drops, {
          fix = fix, reason = "already applied", key = idx, order = order,
        })
      else
        if not by_line[idx] then
          by_line[idx] = {}
          table.insert(indices, idx)
        end
        table.insert(by_line[idx], { fix = fix, s = s, e = e, order = order })
      end
    end
  end

  -- Walk lines in index order rather than via `pairs`, which has no defined iteration
  -- order. Without this the dropped-fix list comes back shuffled run to run, which makes
  -- the user-facing "N could not be attached" message unstable.
  table.sort(indices)

  local placed = {}
  for _, idx in ipairs(indices) do
    local items = by_line[idx]
    table.sort(items, function(a, b)
      if a.s ~= b.s then
        return a.s < b.s
      end
      return a.order < b.order
    end)

    local kept, last_e = {}, 0
    for _, item in ipairs(items) do
      if item.s <= last_e then
        -- Two spans cannot both apply. Applying half of each produces text that neither
        -- the model nor the author wrote, so the later one is dropped and counted.
        table.insert(pending_drops, {
          fix = item.fix, reason = "overlaps an earlier fix", key = idx, order = item.order,
        })
      else
        table.insert(kept, item)
        last_e = item.e
      end
    end

    -- Right to left. Applied left to right, the first replacement invalidates every later
    -- offset on the line.
    for i = #kept, 1, -1 do
      local item = kept[i]
      local line = corrected[idx]
      corrected[idx] = line:sub(1, item.s - 1) .. tostring(item.fix.replacement or "") .. line:sub(item.e + 1)
    end

    for _, item in ipairs(kept) do
      table.insert(placed, { fix = item.fix, lnum = start_lnum + idx - 1, col = item.s - 1 })
    end
  end

  table.sort(placed, function(a, b)
    if a.lnum ~= b.lnum then
      return a.lnum < b.lnum
    end
    return a.col < b.col
  end)
  table.sort(pending_drops, function(a, b)
    if a.key ~= b.key then
      return a.key < b.key
    end
    return a.order < b.order
  end)

  local dropped = {}
  for _, d in ipairs(pending_drops) do
    table.insert(dropped, { fix = d.fix, reason = d.reason })
  end

  return corrected, placed, dropped
end

---Render a label and note into wrapped lines for the diff view's virtual text.
---
---Returns at least one line, always. `diffview` mirrors this count as blank virtual lines on
---the other side of the diff to keep the two windows aligned, and an extmark with an empty
---`virt_lines` table is an error rather than a no-op.
---
---Whitespace is collapsed first, because one returned line becomes one virtual line: an
---embedded newline would otherwise produce a virtual line containing a newline, which
---renders as a control character rather than as a break.
---@param label string|nil
---@param note string|nil
---@param width integer
---@return string[]
function M.note_lines(label, note, width)
  label = label or ""
  note = note or ""
  local text = (label ~= "") and (label .. ": " .. note) or note
  text = text:gsub("%s+", " "):gsub("^ +", ""):gsub(" +$", "")
  if text == "" then
    return { "" }
  end

  local out, current = {}, ""
  for word in text:gmatch("%S+") do
    if current == "" then
      current = word
    elseif #current + 1 + #word <= width then
      current = current .. " " .. word
    else
      table.insert(out, current)
      current = word
    end
  end
  if current ~= "" then
    table.insert(out, current)
  end
  -- A single word longer than `width` is left intact rather than split. Breaking a token
  -- mid-word to satisfy a wrap makes the note harder to read than an overlong line does.
  return out
end

M._nth_find = nth_find
return M
