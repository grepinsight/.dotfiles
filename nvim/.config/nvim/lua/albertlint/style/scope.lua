---Section boundaries, scope identity, and payload construction for the style tier.
---
---Deliberately pure: no `vim.api`, no `vim.fn`, nothing but Lua over a list of lines and a
---column mask. Same reason `annotate/anchor.lua` is pure. Section identity is what every
---finding's fingerprint is keyed on, so it is the piece that most needs to be testable
---without a running editor.
---
---Line numbers are 0-indexed and end bounds are exclusive, matching
---`nvim_buf_set_extmark` and the rest of this config. Mask columns are 0-indexed, matching
---`engine._build_mask`.
local M = {}

---A line is a heading when it opens with one to six `#` followed by whitespace, and its
---first column is not masked.
---
---The mask check is what keeps a `# comment` inside a fenced code block from being read as
---a heading: `engine._build_mask` gives a fenced line a metatable returning true for every
---column, so column 0 is masked. It also, harmlessly, rejects a line opening with a
---backtick or a URL, neither of which can be a heading anyway.
---@param line string
---@param cols table|nil Mask row for this line, 0-indexed columns
---@return integer|nil level, string|nil text
local function heading(line, cols)
  if cols and cols[0] then
    return nil, nil
  end
  local hashes, rest = line:match("^(#+)%s+(.*)$")
  if not hashes or #hashes > 6 then
    return nil, nil
  end
  return #hashes, (rest:gsub("%s+$", ""))
end

---Collapse whitespace and lowercase, for building a key rather than for display.
---@param s string
---@return string
local function normalize(s)
  return (s:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""):lower())
end

---`scope_key` for a heading path: the ancestor chain, not just the heading text.
---
---The path rather than the bare text, so two sections both called `Notes` under different
---parents are distinguishable. A finding's fingerprint includes this, and without the
---ancestors the same sentence under two `## Notes` headings would collide.
---
---An empty path means the file has no headings, or the position is above the first one.
---@param path string[] Root first
---@return string
function M.scope_key(path)
  local parts = {}
  for i, text in ipairs(path) do
    parts[i] = normalize(text)
  end
  return table.concat(parts, "/")
end

---Every section of the document, in order.
---
---A section runs from its heading line to the line before the next heading of the **same or
---higher level**, so a `##` block contains its `###` children. The alternative, stopping at
---the next heading of any level, would cut an argument off from its own subsections, and
---"the unit a claim belongs to" is the whole point of scoping by section.
---
---Content above the first heading becomes a level-0 section with an empty key, because the
---cursor can sit there and `section_at` has to return something. A file with no headings is
---one such section covering everything.
---@param lines string[]
---@param mask table|nil Keyed by 0-indexed line, from `engine._build_mask`
---@return table[] sections Each { level, text, path, key, start_lnum, end_lnum }
function M.sections(lines, mask)
  local found = {}
  for i, line in ipairs(lines) do
    local lnum = i - 1
    local level, text = heading(line, mask and mask[lnum])
    if level then
      table.insert(found, { lnum = lnum, level = level, text = text })
    end
  end

  local sections = {}

  -- The preamble: everything above the first heading. Present even when empty only if the
  -- file has no headings at all, so a normal document does not gain a zero-length section.
  local first = found[1] and found[1].lnum or #lines
  if first > 0 or #found == 0 then
    table.insert(sections, {
      level = 0,
      text = "",
      path = {},
      key = "",
      start_lnum = 0,
      end_lnum = first,
    })
  end

  local stack = {}
  for idx, h in ipairs(found) do
    while #stack > 0 and stack[#stack].level >= h.level do
      table.remove(stack)
    end
    table.insert(stack, h)

    local path = {}
    for i, entry in ipairs(stack) do
      path[i] = entry.text
    end

    -- End at the next heading of the same or higher level, so children stay inside.
    local end_lnum = #lines
    for j = idx + 1, #found do
      if found[j].level <= h.level then
        end_lnum = found[j].lnum
        break
      end
    end

    table.insert(sections, {
      level = h.level,
      text = h.text,
      path = path,
      key = M.scope_key(path),
      start_lnum = h.lnum,
      end_lnum = end_lnum,
    })
  end

  return sections
end

---The innermost section containing `lnum`.
---
---Innermost rather than outermost: sections nest, and a cursor inside a `###` block is
---inside its `##` parent too. The deeper one is the tighter context and the one whose claim
---the author is actually writing.
---@param lines string[]
---@param mask table|nil
---@param lnum integer 0-indexed
---@return table|nil section
function M.section_at(lines, mask, lnum)
  local best
  for _, section in ipairs(M.sections(lines, mask)) do
    if lnum >= section.start_lnum and lnum < section.end_lnum then
      if best == nil or section.level > best.level then
        best = section
      end
    end
  end
  return best
end

---Line with every masked column replaced by a space, byte for byte.
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

---The text to send a provider, with masked spans blanked rather than removed.
---
---Blanked **in place, byte for byte**, and this is the part that has to be right: quotes
---coming back from the model are located by searching the text that was sent, so the
---payload must keep the same line count and the same byte length per line as the buffer.
---Deleting a code block would shift every offset after it and silently misplace every
---finding below it.
---
---Fully masked lines are still sent, as blank lines. A model judging whether two paragraphs
---connect should be able to see that something interrupted them.
---@param lines string[]
---@param mask table|nil
---@param start_lnum integer 0-indexed inclusive
---@param end_lnum integer 0-indexed exclusive
---@return string[]
function M.payload(lines, mask, start_lnum, end_lnum)
  local out = {}
  for lnum = start_lnum, end_lnum - 1 do
    local line = lines[lnum + 1]
    if line ~= nil then
      table.insert(out, unmask(line, mask and mask[lnum]))
    end
  end
  return out
end

---Count of lines that actually carry prose, for `min_lines` eligibility.
---
---Not the raw line count. A section holding one sentence plus a twenty-line code block
---would otherwise look like twenty-one lines of argument and let `no-claim` fire on it.
---Blank lines and fully masked lines do not count, and a heading line does not count
---either: it is context the classes read, not content they judge. It is still *sent*.
---@param lines string[]
---@param mask table|nil
---@param start_lnum integer 0-indexed inclusive
---@param end_lnum integer 0-indexed exclusive
---@return integer
function M.prose_lines(lines, mask, start_lnum, end_lnum)
  local count = 0
  for lnum = start_lnum, end_lnum - 1 do
    local line = lines[lnum + 1]
    if line ~= nil then
      local cols = mask and mask[lnum]
      if heading(line, cols) == nil then
        local visible = unmask(line, cols)
        if visible:match("%S") then
          count = count + 1
        end
      end
    end
  end
  return count
end

M._heading = heading
M._normalize = normalize
return M
