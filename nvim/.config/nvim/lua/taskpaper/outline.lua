---The outline, as pure functions over a list of lines.
---
---Everything the app's Move menu does is a rearrangement of an item together with its
---descendants, so the one operation worth getting right is "where does this subtree
---end". No vim.api here, which is what lets the awkward cases (blank lines between
---siblings, a nephew that is not a sibling, moving an item into itself) be tested with
---string literals instead of a buffer.

local M = {}

local DEFAULT_SHIFTWIDTH = 4

---Outline depth of a line, or nil for a blank one.
---
---Blank lines have no level on purpose. Giving a blank line level 0 would end every
---subtree at the first blank inside it, and these files are written with blank lines
---between groups of tasks.
---@param line string
---@param sw integer|nil Spaces per level. Defaults to 4.
---@return integer|nil
function M.level(line, sw)
  if line:match("^%s*$") then
    return nil
  end
  sw = sw or DEFAULT_SHIFTWIDTH
  local depth, spaces = 0, 0
  for ch in line:match("^[ \t]*"):gmatch(".") do
    if ch == "\t" then
      depth, spaces = depth + 1, 0
    else
      spaces = spaces + 1
      if spaces == sw then
        depth, spaces = depth + 1, 0
      end
    end
  end
  return depth
end

---The item at `lnum` together with its descendants.
---
---Trailing blank lines are excluded, so moving the last project in a file does not drag
---the file's trailing newlines around with it. A blank line that has a deeper line
---after it is still inside the subtree, because the run has not ended yet.
---@param lines string[]
---@param lnum integer
---@param sw integer|nil
---@return integer first
---@return integer last
function M.subtree(lines, lnum, sw)
  local root = M.level(lines[lnum], sw)
  local last = lnum
  for i = lnum + 1, #lines do
    local level = M.level(lines[i], sw)
    if level ~= nil then
      if root == nil or level <= root then
        break
      end
      last = i
    end
  end
  return lnum, last
end

---@param line string
---@param unit string
---@param sw integer
---@return string|nil line with one indent unit removed, or nil if it had none
local function outdent_line(line, unit, sw)
  if line:sub(1, 1) == "\t" then
    return line:sub(2)
  end
  local spaces = line:match("^ +")
  if spaces then
    return line:sub(math.min(#spaces, sw) + 1)
  end
  return unit == "" and line or nil
end

---Move an item and its descendants one level right or left.
---@param lines string[]
---@param lnum integer
---@param delta integer 1 to indent, -1 to outdent
---@param unit string|nil The indent unit. Defaults to one hard tab.
---@param sw integer|nil
---@return string[]|nil lines, or nil when the move is not available
function M.shift(lines, lnum, delta, unit, sw)
  unit = unit or "\t"
  sw = sw or DEFAULT_SHIFTWIDTH
  local root = M.level(lines[lnum], sw)
  if root == nil or (delta < 0 and root == 0) then
    return nil
  end
  local first, last = M.subtree(lines, lnum, sw)
  local out = vim.deepcopy(lines)
  for i = first, last do
    if M.level(out[i], sw) ~= nil then
      if delta > 0 then
        out[i] = unit .. out[i]
      else
        out[i] = outdent_line(out[i], unit, sw) or out[i]
      end
    end
  end
  return out
end

---First line of the sibling before or after `lnum`, skipping over blanks.
---
---A line shallower than the item means the search left the parent, so there is no
---sibling that way. Searching upward also has to step over the previous sibling's own
---descendants, which is why it looks for an equal level rather than the nearest item.
---@param lines string[]
---@param lnum integer
---@param dir "up"|"down"
---@param sw integer|nil
---@return integer|nil
local function sibling(lines, lnum, dir, sw)
  local root = M.level(lines[lnum], sw)
  if root == nil then
    return nil
  end
  local from, to, step
  if dir == "down" then
    local _, last = M.subtree(lines, lnum, sw)
    from, to, step = last + 1, #lines, 1
  else
    from, to, step = lnum - 1, 1, -1
  end
  for i = from, to, step do
    local level = M.level(lines[i], sw)
    if level ~= nil then
      if level < root then
        return nil
      elseif level == root then
        return i
      end
    end
  end
  return nil
end

---Swap an item with the sibling above or below it, each carrying its own descendants.
---@param lines string[]
---@param lnum integer
---@param dir "up"|"down"
---@param sw integer|nil
---@return string[]|nil lines, or nil when there is no sibling that way
---@return integer|nil lnum the item's new line number
function M.move(lines, lnum, dir, sw)
  local sib = sibling(lines, lnum, dir, sw)
  if sib == nil then
    return nil
  end
  local first, last = M.subtree(lines, lnum, sw)
  local sfirst, slast = M.subtree(lines, sib, sw)

  local function slice(a, b)
    return vim.list_slice(lines, a, b)
  end

  local out, moved_to
  if dir == "down" then
    -- The blank lines that sat between the two items stay between them, rather than
    -- travelling with either, which is the only arrangement that survives a round trip.
    local gap = slice(last + 1, sfirst - 1)
    out = slice(1, first - 1)
    vim.list_extend(out, slice(sfirst, slast))
    vim.list_extend(out, gap)
    vim.list_extend(out, slice(first, last))
    vim.list_extend(out, slice(slast + 1, #lines))
    moved_to = first + (slast - sfirst + 1) + #gap
  else
    local gap = slice(slast + 1, first - 1)
    out = slice(1, sfirst - 1)
    vim.list_extend(out, slice(first, last))
    vim.list_extend(out, gap)
    vim.list_extend(out, slice(sfirst, slast))
    vim.list_extend(out, slice(last + 1, #lines))
    moved_to = sfirst
  end
  return out, moved_to
end

---Is this line a project, by the same rule the syntax file uses?
---@param line string
---@return boolean
local function is_project(line)
  if line:match("^%s*$") or line:match("^%s*%-%s") then
    return false
  end
  -- Ends in a colon, optionally followed by tags, as in `inbox: @hold`.
  return line:match("^%s*.-:%s*$") ~= nil
    or line:match("^%s*.-:%s*%@[%w_.-]+%b()%s*$") ~= nil
    or line:match("^%s*.-:%s*%@[%w_.-]+%s*$") ~= nil
end

---Every project in the buffer, in order, for a picker to choose from.
---@param lines string[]
---@param sw integer|nil
---@return { lnum: integer, level: integer, text: string }[]
function M.projects(lines, sw)
  local out = {}
  for lnum, line in ipairs(lines) do
    if is_project(line) then
      table.insert(out, { lnum = lnum, level = M.level(line, sw), text = line })
    end
  end
  return out
end

---The line directly above `lnum` in the outline: the nearest strictly shallower one.
---
---"Nearest shallower" rather than "nearest" is what steps over a sibling's whole
---subtree. In
---
---    - outer list
---        - middle list
---            - deep one
---        - middle two
---
---the line above `- middle two` is `- deep one`, and its parent is `- outer list`.
---
---A blank line has no level and so has no parent; the callers that start from one
---resolve it to a real line first.
---@param lines string[]
---@param lnum integer
---@param sw integer|nil
---@return integer|nil
function M.parent(lines, lnum, sw)
  local root = M.level(lines[lnum], sw)
  if root == nil then
    return nil
  end
  for i = lnum - 1, 1, -1 do
    local level = M.level(lines[i], sw)
    if level ~= nil and level < root then
      return i
    end
  end
  return nil
end

---The item to focus when the cursor is on `lnum`: the innermost one containing it.
---
---**The unit is the item, not the project.** This asked for the nearest *project* until
---2026-09-17, which made a nested list unfocusable: a task's nearest project is the
---top-level heading no matter how deep the task sits, so Focus In from anywhere inside a
---nested list jumped straight back to the root. Reported from a real file.
---
---A line with children is its own answer, because that is the container the cursor is
---standing on. A leaf resolves to its parent, since focusing a leaf would show one line.
---That also makes repeated Focus In behave the way the app's does: it narrows to what the
---cursor is inside, so going deeper means moving the cursor onto the child first rather
---than pressing the key again.
---@param lines string[]
---@param lnum integer
---@param sw integer|nil
---@return integer|nil
function M.enclosing_item(lines, lnum, sw)
  -- A blank line is inside whatever the line above it is inside, so start from there.
  local at = lnum
  while at >= 1 and M.level(lines[at], sw) == nil do
    at = at - 1
  end
  if at < 1 then
    return nil
  end

  local _, last = M.subtree(lines, at, sw)
  if last > at then
    return at
  end
  return M.parent(lines, at, sw)
end

---Reparent an item and its descendants as the last child of a project.
---@param lines string[]
---@param lnum integer
---@param plnum integer Line number of the target project.
---@param unit string|nil
---@param sw integer|nil
---@return string[]|nil lines, or nil when the target is inside the item's own subtree
---@return integer|nil lnum the item's new line number
function M.move_to_project(lines, lnum, plnum, unit, sw)
  unit = unit or "\t"
  sw = sw or DEFAULT_SHIFTWIDTH
  local first, last = M.subtree(lines, lnum, sw)
  if plnum >= first and plnum <= last then
    return nil
  end

  local target_level = M.level(lines[plnum], sw)
  if target_level == nil then
    return nil
  end
  local delta = (target_level + 1) - M.level(lines[first], sw)

  local block = vim.list_slice(lines, first, last)
  for i, line in ipairs(block) do
    if M.level(line, sw) ~= nil then
      if delta > 0 then
        block[i] = unit:rep(delta) .. line
      else
        for _ = 1, -delta do
          block[i] = outdent_line(block[i], unit, sw) or block[i]
        end
      end
    end
  end

  local _, plast = M.subtree(lines, plnum, sw)
  local rest = vim.list_slice(lines, 1, first - 1)
  vim.list_extend(rest, vim.list_slice(lines, last + 1, #lines))

  -- plast is an index into the original list, so it shifts left by the size of the
  -- block when the block sat above the target.
  local insert_after = plast
  if last < plnum then
    insert_after = plast - (last - first + 1)
  end

  local out = vim.list_slice(rest, 1, insert_after)
  vim.list_extend(out, block)
  vim.list_extend(out, vim.list_slice(rest, insert_after + 1, #rest))
  return out, insert_after + 1
end

---The inclusive range of lines that differ between two equal-length lists.
---
---Every operation here permutes or re-indents lines and never adds or removes one, so
---the caller can replace this span instead of the whole buffer. That matters for more
---than speed: replacing every line marks every line changed, which moves extmarks and
---loses the change marks even where nothing moved.
---@param before string[]
---@param after string[]
---@return integer|nil first
---@return integer|nil last nil when the two are identical
function M.changed_span(before, after)
  local first
  for i = 1, math.max(#before, #after) do
    if before[i] ~= after[i] then
      first = i
      break
    end
  end
  if first == nil then
    return nil
  end
  local last = first
  for i = math.max(#before, #after), first, -1 do
    if before[i] ~= after[i] then
      last = i
      break
    end
  end
  return first, last
end

---Projects that `lnum` can actually be moved into.
---
---A project inside the item's own subtree is not a destination: the move would have to
---put the item inside itself. Filtering here rather than rejecting a choice later is
---what keeps the picker from offering something it will then refuse.
---@param lines string[]
---@param lnum integer
---@param sw integer|nil
---@return { lnum: integer, level: integer, text: string }[]
function M.move_targets(lines, lnum, sw)
  local first, last = M.subtree(lines, lnum, sw)
  return vim.tbl_filter(function(project)
    return project.lnum < first or project.lnum > last
  end, M.projects(lines, sw))
end

return M
