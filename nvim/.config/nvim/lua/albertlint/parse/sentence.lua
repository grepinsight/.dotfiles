---Finding the sentence under the cursor, in Lua. Pure, same shape as `style/scope.lua`.
---
---Exists for the latency target and no other reason. spaCy segments better than this does,
---but asking it *which sentence is the cursor in* would put a pipe round trip on the hover
---path. It is also the cache-key generator, so the daemon must not re-split: trees would come
---back filed under strings nobody looked up. Design doc §3, §4.
---
---Line numbers 0-indexed, end bounds exclusive, matching `nvim_buf_set_extmark`. Offsets
---*within* a joined paragraph are 1-indexed, because they index a Lua string.
local M = {}

---Words that take a period and are almost never sentence-final.
---
---`etc` is deliberately absent: it ends sentences constantly, so listing it would merge two
---every time, a worse failure than splitting `Fig. 3`. `e.g.` and `i.e.` need no entry, being
---caught by the single-letter rule in `boundary` along with initials like `J. R. R.`
M.ABBREV = {
  al = true, approx = true, cf = true, co = true, dr = true, eq = true, fig = true,
  inc = true, jr = true, ltd = true, mr = true, mrs = true, ms = true, no = true,
  prof = true, sr = true, st = true, vs = true,
}

---Masked spans blanked in place, byte for byte, so the reported span stays in buffer
---coordinates. Same convention and reason as the payload builder in `style/scope.lua`.
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
  -- A fenced or frontmatter line masks every column, so probing column 0 rejects the line.
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
    -- No space after the mark, which is what keeps a footnote marker (`success.1, 2, 3`), a
    -- decimal (`0.05`), a version (`v3.8`), and a filename (`config.lua`) from splitting.
    return nil
  end
  -- The word before the mark decides the rest, scanned backwards rather than with
  -- `text:sub(1, i - 1):match("[%a]+$")`. That allocated a substring the length of everything
  -- before the mark on every call, making the splitter quadratic in bytes: **39ms** for one
  -- `sentence.at` on a 200-line paragraph, measured 2026-09-09, against a 1ms hover budget.
  local start = i - 1
  while start >= 1 and text:sub(start, start):match("%a") do
    start = start - 1
  end
  local word = start < i - 1 and text:sub(start + 1, i - 1) or nil
  if word then
    if #word == 1 then
      -- An initial, or the tail of `e.g.` / `i.e.`; never a sentence end in practice.
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
    -- Jump to the next candidate rather than testing every byte: a few dozen `boundary`
    -- calls on a long paragraph instead of one per character.
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

---Join a paragraph's lines into one string, keeping a map back to buffer coordinates. Joined
---with a single space: a sentence wrapped across two lines is one sentence.
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
    -- `<=`, so sitting on the final period reports the sentence it closes, not the next.
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

---The cache key for a sentence. Whitespace collapsed, so rewrapping a paragraph does not
---cold-miss every sentence in it while changing none of them.
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
        -- Deduplicated: a repeated sentence should not be parsed twice.
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
