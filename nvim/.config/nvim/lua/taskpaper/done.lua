---Marking a task done, as a pure string transform plus a thin buffer wrapper.
---
---The transform is separated out because every case that can go wrong is a string
---case, and an adversarial review on 2026-09-16 found three of them that a single
---pattern got wrong. It is a scanner rather than a gsub for that reason: two of the
---three need paren depth, which a Lua pattern cannot carry.
---
---`tests/taskpaper/tag_boundary_spec.lua` runs the same fixtures through here and
---through syntax/taskpaper.vim, because these are two spellings of one rule and the
---bug was that they disagreed.

local M = {}

---Characters that can appear in a tag name. `-` and `.` are the load-bearing two:
---@done-later and @done.foo are tags named `done-later` and `done.foo`, not `@done`,
---and Vim's \> boundary does not know that because neither is a keyword character.
local TAG_CHAR = "[%w_.-]"

---Locate a top-level `@done` tag, with the whitespace that introduced it.
---@param line string
---@return integer|nil from 1-indexed, inclusive
---@return integer|nil to 1-indexed, inclusive
local function find_done(line)
  local depth = 0
  for i = 1, #line do
    local c = line:sub(i, i)
    if c == "(" then
      depth = depth + 1
    elseif c == ")" then
      depth = math.max(depth - 1, 0)
    elseif c == "@" and depth == 0 and line:sub(i, i + 4) == "@done" then
      -- The @ has to open a word, or the domain of name@done.com would qualify.
      local opens_word = i == 1 or line:sub(i - 1, i - 1):match("%s") ~= nil
      local name_ends = line:sub(i + 5, i + 5):match(TAG_CHAR) == nil
      if opens_word and name_ends then
        local to = i + 4
        if line:sub(to + 1, to + 1) == "(" then
          to = line:find(")", to + 2, true) or to
        end
        local from = i
        while from > 1 and line:sub(from - 1, from - 1):match("%s") do
          from = from - 1
        end
        return from, to
      end
    end
  end
  return nil
end

---Strip a `@done` tag from a line.
---@param line string
---@return string|nil line without the tag, or nil if it carried none
function M.undone(line)
  local from, to = find_done(line)
  if not from then
    return nil
  end
  return ((line:sub(1, from - 1) .. line:sub(to + 1)):gsub("%s+$", ""))
end

---Add a dated `@done` tag, or remove the one already there.
---@param line string
---@param today string The tag's value, as YYYY-MM-DD.
---@return string
function M.toggle(line, today)
  if line:match("^%s*$") then
    return line
  end
  -- The trailing trim is not cosmetic: the sample file has tasks ending in a space,
  -- and appending to one of those reads as a double space in the buffer.
  return M.undone(line) or (line:gsub("%s+$", "") .. " @done(" .. today .. ")")
end

---Toggle `@done` on every line of an inclusive, 1-indexed range in the current buffer.
---@param first integer
---@param last integer
---@param today string|nil Defaults to today, and is injectable so the tests can pin it.
function M.toggle_range(first, last, today)
  today = today or tostring(os.date("%Y-%m-%d"))
  local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
  for i, line in ipairs(lines) do
    lines[i] = M.toggle(line, today)
  end
  vim.api.nvim_buf_set_lines(0, first - 1, last, false, lines)
end

return M
