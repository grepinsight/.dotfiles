---One bullet per sentence, over a range, a motion, or a visual selection.
---
---This changes no words. It splits on sentence boundaries and prepends a marker, so it sits in
---the same category as the parse tier rather than under the level-1 exception in CLAUDE.md:
---there is no replacement prose to accept or reject, and the transform is meaning-preserving by
---construction. It rewrites the buffer without a gate for the same reason `gq` does.
---
---Everything that touches the buffer or the pipe is here; the placement logic is in
---`format.lua`, which is pure.
local format = require("albertlint.bullets.format")

local M = {}

---@param a string[]
---@param b string[]
---@return boolean
local function same(a, b)
  if #a ~= #b then
    return false
  end
  for i = 1, #a do
    if a[i] ~= b[i] then
      return false
    end
  end
  return true
end

---Sentences per paragraph from the Lua splitter, used when spaCy is not available.
---@param texts string[]
---@return string[][]
local function split_locally(texts)
  local sentence = require("albertlint.parse.sentence")
  local groups = {}
  for i, text in ipairs(texts) do
    local list = {}
    for _, s in ipairs(sentence.split(text)) do
      table.insert(list, s.text)
    end
    groups[i] = list
  end
  return groups
end

---@param buf integer
---@param line1 integer 1-indexed inclusive
---@param line2 integer 1-indexed inclusive
---@param blocks table[]
---@param indices integer[]
---@param groups string[][]
---@param before string[]
local function write_back(buf, line1, line2, blocks, indices, groups, before)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  -- The segmenter runs behind a pipe, so the range can have moved under it. Re-reading and
  -- comparing is cheap; overwriting a range that has since changed is not recoverable except
  -- by undo, and the user would not know it happened.
  local now = vim.api.nvim_buf_get_lines(buf, line1 - 1, line2, false)
  if not same(now, before) then
    vim.notify("albertlint: the lines changed while spaCy was segmenting, nothing written",
      vim.log.levels.WARN)
    return
  end

  local by_block = {}
  for n, block_index in ipairs(indices) do
    by_block[block_index] = groups[n]
  end
  local out = format.render(blocks, by_block)
  if same(out, before) then
    vim.notify("albertlint: nothing to bullet in that range", vim.log.levels.INFO)
    return
  end
  vim.api.nvim_buf_set_lines(buf, line1 - 1, line2, false, out)
end

---Bullet the lines from `line1` to `line2`, both 1-indexed and inclusive.
---@param line1 integer
---@param line2 integer
function M.range(line1, line2)
  local buf = vim.api.nvim_get_current_buf()
  if not vim.bo[buf].modifiable then
    vim.notify("albertlint: buffer is not modifiable", vim.log.levels.ERROR)
    return
  end

  local before = vim.api.nvim_buf_get_lines(buf, line1 - 1, line2, false)
  if #before == 0 then
    return
  end
  local blocks = format.blocks(before)
  local texts, indices = format.prose_texts(blocks)
  if #texts == 0 then
    vim.notify("albertlint: nothing to bullet in that range", vim.log.levels.INFO)
    return
  end

  local daemon = require("albertlint.parse.daemon")
  if not daemon.installed() then
    -- Named rather than silent: the two splitters disagree on abbreviations and on anything
    -- without a space after the period, so a quality difference the user cannot see is worse
    -- than one extra message.
    vim.notify("albertlint: spaCy is not installed, used the Lua splitter "
      .. "(:AlbertLintTreeBootstrap to install it)", vim.log.levels.WARN)
    write_back(buf, line1, line2, blocks, indices, split_locally(texts), before)
    return
  end

  daemon.segment(texts, function(res)
    vim.schedule(function()
      local groups = res.sentences
      if res.error or not groups then
        vim.notify("albertlint: spaCy segmentation failed, used the Lua splitter (" ..
          tostring(res.error or "no sentences returned") .. ")", vim.log.levels.WARN)
        groups = split_locally(texts)
      end
      write_back(buf, line1, line2, blocks, indices, groups, before)
    end)
  end)
end

---`operatorfunc` target. Always linewise: a bullet is a line, so a charwise motion still
---rewrites every line it touched rather than splicing a marker mid-line.
function M.operator()
  M.range(vim.fn.line("'["), vim.fn.line("']"))
end

---Normal-mode `gb`, as an `expr` mapping so it takes a motion or a text object.
---@return string
function M.operator_expr()
  vim.o.operatorfunc = "v:lua.require'albertlint.bullets'.operator"
  return "g@"
end

---Visual-mode `gb`, over whatever is selected. Leaves visual mode first so the marks settle.
function M.visual()
  vim.cmd("normal! \27")
  M.range(vim.fn.line("'<"), vim.fn.line("'>"))
end

return M
