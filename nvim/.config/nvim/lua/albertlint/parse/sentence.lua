---Finding the sentence under the cursor, in Lua.
---
---Deliberately pure: no `vim.api`, no `vim.fn`, no filesystem. Same shape as
---`annotate/anchor.lua` and `style/scope.lua`.
---
---This module exists because of the latency target and for no other reason. spaCy already
---segments sentences, and better than this does, but asking it *which sentence is the cursor
---in* would put a pipe round trip on the hover path, and the hover path is the one thing in
---this feature that has to be sub-millisecond. So the daemon segments a whole buffer for the
---cache, and this segments the one paragraph under the cursor for the lookup. Two
---segmenters, on purpose. See the design doc, section 4.
---
---Line numbers are 0-indexed and end bounds are exclusive, matching
---`nvim_buf_set_extmark` and the rest of this plugin. Columns are 0-indexed, matching
---`engine._build_mask`. Offsets *within* a joined paragraph string are 1-indexed, because
---they index a Lua string.
local M = {}

---Words that take a period and are almost never sentence-final.
---
---`etc` is deliberately absent. It ends sentences constantly (`... and so on, etc. The next
---point is`), so listing it would merge two sentences every time, which is a worse and more
---frequent failure than splitting `Fig. 3` in half.
---
---`e.g.` and `i.e.` need no entry: they are caught by the single-letter rule in `boundary`,
---along with initials like `J. R. R.`
M.ABBREV = {
  al = true, approx = true, cf = true, co = true, dr = true, eq = true, fig = true,
  inc = true, jr = true, ltd = true, mr = true, mrs = true, ms = true, no = true,
  prof = true, sr = true, st = true, vs = true,
}

---Masked spans blanked in place, byte for byte.
---
---Byte-for-byte matters: the sentence span is reported back in buffer coordinates, so a
---substitution that changed the length would misplace every column after it. Same
---convention, and the same reason, as the payload builder in `style/scope.lua`.
---@param line string
---@param cols table|nil
---@return string
local function unmask(line, cols)
  if not cols then
    return line
  end
  local out = {}
  for col = 1, #line do
    out[col] = cols[col - 1] and " " or line:sub(col, col)
  end
  return table.concat(out)
end

---@param line string
---@return boolean
local function is_heading(line)
  return line:match("^#+%s") ~= nil
end

---@param line string
---@param cols table|nil
---@return boolean
local function is_prose(line, cols)
  if line:match("^%s*$") or is_heading(line) then
    return false
  end
  -- A fenced or frontmatter line gets a mask row that reports every column masked, so
  -- probing column 0 is enough to reject the whole line. Same probe `style/scope.lua` uses
  -- to keep a `# comment` inside a fence from reading as a heading.
  return not (cols and cols[0])
end

---The contiguous run of prose lines containing `lnum`.
---@param lines string[]
---@param lnum integer 0-indexed
---@param mask table|nil
---@return table|nil `{ start_lnum = integer, end_lnum = integer }`, end exclusive
function M.paragraph(lines, lnum, mask)
  local function prose(i)
    return lines[i + 1] ~= nil and is_prose(lines[i + 1], mask and mask[i])
  end
  if not prose(lnum) then
    return nil
  end
  local first, last = lnum, lnum
  while prose(first - 1) do
    first = first - 1
  end
  while prose(last + 1) do
    last = last + 1
  end
  return { start_lnum = first, end_lnum = last + 1 }
end

---Is there a sentence boundary at byte `i` of `text`?
---
---`i` is the index of the `.`, `!`, or `?` itself. A boundary needs three things: the mark,
---optional closing quotes or brackets, and then whitespace or end of string.
---@param text string
---@param i integer 1-indexed
---@return integer|nil after Index one past the end of the sentence, or nil
local function boundary(text, i)
  if not text:sub(i, i):match("[.!?]") then
    return nil
  end
  local j = i + 1
  -- Closing marks belong to the sentence they end: `he said "stop."` and `(see below.)`
  while text:sub(j, j):match("[\"'%)%]”’»]") do
    j = j + 1
  end
  local after = text:sub(j, j)
  if after ~= "" and not after:match("%s") then
    -- No space after the mark, so it is not a boundary. This is what keeps a footnote
    -- marker (`treatment success.1, 2, 3 However`), a decimal (`0.05`), a version
    -- (`v3.8`), and a filename (`config.lua`) from splitting a sentence in half.
    return nil
  end
  -- The word immediately before the mark decides the rest.
  --
  -- Scanned backwards a byte at a time rather than with `text:sub(1, i - 1):match("[%a]+$")`.
  -- That version allocated a substring the length of everything before the mark on every
  -- call, which made the whole splitter quadratic in the paragraph's byte length: measured
  -- 2026-09-09 at **39ms** for one `sentence.at` on a 200-line paragraph, against a 1ms
  -- budget for the entire hover. This version is proportional to the word.
  local start = i - 1
  while start >= 1 and text:sub(start, start):match("%a") do
    start = start - 1
  end
  local word = start < i - 1 and text:sub(start + 1, i - 1) or nil
  if word then
    if #word == 1 then
      -- A single letter before a period is an initial or the tail of `e.g.` / `i.e.`, never
      -- the end of a sentence in this writer's prose.
      return nil
    end
    if M.ABBREV[word:lower()] then
      return nil
    end
  end
  return j
end

---Split a single-line string into sentences.
---@param text string
---@return table[] `{ { text = string, s = integer, e = integer } }`, 1-indexed, e inclusive
function M.split(text)
  local out = {}
  local start = 1
  local i = 1
  while i <= #text do
    -- Jump to the next candidate mark rather than testing every byte. On a long paragraph
    -- this is the difference between a few dozen `boundary` calls and one per character.
    local mark = text:find("[.!?]", i)
    if not mark then
      break
    end
    local after = boundary(text, mark)
    if after then
      local chunk = text:sub(start, after - 1)
      if chunk:match("%S") then
        table.insert(out, { text = chunk, s = start, e = after - 1 })
      end
      -- Skip the whitespace between sentences so it belongs to neither.
      while text:sub(after, after):match("%s") do
        after = after + 1
      end
      start = after
      i = after
    else
      i = mark + 1
    end
  end
  local tail = text:sub(start)
  if tail:match("%S") then
    table.insert(out, { text = tail, s = start, e = #text })
  end
  return out
end

---Join a paragraph's lines into one string, keeping a map back to buffer coordinates.
---
---Lines are joined with a single space, because a sentence wrapped across two lines is one
---sentence and the newline is not part of it.
---@param lines string[]
---@param para table
---@param mask table|nil
---@return string text, integer[] starts Flat 1-indexed offset at which each line begins
local function flatten(lines, para, mask)
  local parts, starts = {}, {}
  local offset = 1
  for lnum = para.start_lnum, para.end_lnum - 1 do
    local line = unmask(lines[lnum + 1], mask and mask[lnum])
    starts[lnum] = offset
    table.insert(parts, line)
    offset = offset + #line + 1
  end
  return table.concat(parts, " "), starts
end

---@param starts integer[]
---@param para table
---@param offset integer 1-indexed flat offset
---@return integer lnum, integer col Both 0-indexed
local function to_position(starts, para, offset)
  local found = para.start_lnum
  for lnum = para.start_lnum, para.end_lnum - 1 do
    if starts[lnum] <= offset then
      found = lnum
    else
      break
    end
  end
  return found, offset - starts[found]
end

---The sentence containing the cursor.
---@param lines string[]
---@param lnum integer 0-indexed
---@param col integer 0-indexed
---@param mask table|nil
---@return table|nil `{ text, start_lnum, start_col, end_lnum, end_col }`, end_col exclusive
function M.at(lines, lnum, col, mask)
  local para = M.paragraph(lines, lnum, mask)
  if not para then
    return nil
  end
  local text, starts = flatten(lines, para, mask)
  local cursor = starts[lnum] + col
  local sentences = M.split(text)
  if #sentences == 0 then
    return nil
  end

  local chosen = sentences[#sentences]
  for _, s in ipairs(sentences) do
    -- `cursor <= s.e` rather than `< s.e`: sitting on the final period should report the
    -- sentence it closes, not the next one.
    if cursor <= s.e then
      chosen = s
      break
    end
  end

  local start_lnum, start_col = to_position(starts, para, chosen.s)
  local end_lnum, end_col = to_position(starts, para, chosen.e)
  return {
    text = M.normalize(chosen.text),
    start_lnum = start_lnum,
    start_col = start_col,
    end_lnum = end_lnum,
    end_col = end_col + 1,
  }
end

---The cache key for a sentence.
---
---Whitespace is collapsed and the ends trimmed, so a sentence rewrapped across a different
---set of lines is the same cache entry. Without this, reformatting a paragraph would cold-
---miss every sentence in it while changing none of them.
---@param text string
---@return string
function M.normalize(text)
  return (text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", ""))
end

---Every sentence in the buffer, in order, for the whole-buffer parse.
---@param lines string[]
---@param mask table|nil
---@return string[]
function M.all(lines, mask)
  local out, seen = {}, {}
  local lnum = 0
  while lnum < #lines do
    local para = M.paragraph(lines, lnum, mask)
    if not para then
      lnum = lnum + 1
    else
      local text = flatten(lines, para, mask)
      for _, s in ipairs(M.split(text)) do
        local key = M.normalize(s.text)
        -- Deduplicated, because the daemon is billed per sentence and a buffer with a
        -- repeated heading-and-sentence pattern would otherwise pay for it twice.
        if not seen[key] then
          seen[key] = true
          table.insert(out, key)
        end
      end
      lnum = para.end_lnum
    end
  end
  return out
end

return M
