---필사 read mode: pace yourself through a passage one word at a time.
---
---The inverse of `pilsa/init.lua`. There you type to reveal; here the text is
---already on screen and you press <Tab> to walk a boundary through it. Everything
---behind the boundary keeps its normal colours, everything ahead is gray, so the
---lit region grows as you read. <S-Tab> pulls the boundary back.
---
---Deliberately standalone. It shares no code with `pilsa/init.lua` -- the character
---helpers below are duplicated rather than extracted -- so that the transcription
---commands stay exactly as they are and neither mode can break the other. The two
---also render by different means: transcription draws virtual text over an empty
---buffer, read mode dims real buffer text with a highlight extmark, so there is
---less shared surface than the shared vocabulary suggests.
---
---Non-destructive: the buffer is never written to. It is held `nomodifiable` for
---the duration only so a stray keypress cannot edit the article you are reading.
---
---Commands: `:PilsaReadMode`, `:PilsaReadQuit`. In the buffer: <Tab> forward,
---<S-Tab> (or <BS>) back, q to leave.

local M = {}

local NS = vim.api.nvim_create_namespace("pilsa_read")

---@class PilsaReadState
---@field buf integer the buffer being read
---@field row integer boundary line, 1-indexed
---@field chr integer boundary character index within that line, 0-indexed
---@field modifiable boolean the buffer's `modifiable` before we took it away
---@field zen boolean whether we opened zen-mode and therefore owe it a close
local state = nil

-- Character-wise helpers. Byte arithmetic would drift on any line containing
-- Hangul or an em dash, so every index below counts characters.

local function charlen(s)
  return vim.fn.strcharlen(s)
end

local function charat(s, n)
  return vim.fn.strcharpart(s, n, 1)
end

local function byteoff(s, n)
  local b = vim.fn.byteidx(s, n)
  if b < 0 then
    return #s
  end
  return b
end

---Whitespace, including U+00A0 (nbsp) and U+3000 (the full-width space common in
---CJK copy). Lua's `%s` knows only the ASCII ones, and a space <Tab> refused to
---step over would read as the key having stopped working.
local function is_space(c)
  return c:match("^%s$") ~= nil or c == "\194\160" or c == "\227\128\128"
end

local function line_at(buf, row)
  return vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
end

---Collapse the two ways of writing "the boundary sits between line N and line
---N+1" into one.
---
---End-of-line-N and start-of-line-N+1 gray exactly the same region, so leaving both
---reachable let <Tab> and <S-Tab> settle on different encodings of one visual state
---and stopped the pair being exact inverses. Nothing on screen changed either way,
---but a boundary with two spellings is a bug waiting for the next feature to trip
---over. Blank lines collapse too, for the same reason `next_pos` steps over them.
local function normalize(buf, row, chr)
  local total = vim.api.nvim_buf_line_count(buf)
  while row < total and chr >= charlen(line_at(buf, row)) do
    row = row + 1
    chr = 0
  end
  return row, chr
end

---The boundary one word further on.
---
---Advancing consumes any space we are sitting in, then the word, then the space
---behind it, so the boundary comes to rest on the next word's first character.
---When a line has nothing left the search continues on the following one, which
---also steps straight over blank lines rather than spending a <Tab> on each.
local function next_pos(buf, row, chr)
  local total = vim.api.nvim_buf_line_count(buf)
  while row <= total do
    local line = line_at(buf, row)
    local n = charlen(line)
    local j = chr
    while j < n and is_space(charat(line, j)) do
      j = j + 1
    end
    while j < n and not is_space(charat(line, j)) do
      j = j + 1
    end
    while j < n and is_space(charat(line, j)) do
      j = j + 1
    end
    -- `j > chr`, not `j < n`: landing exactly on the end of a line is a real
    -- advance (the last word just lit up) and must not spill into the next line's
    -- first word on the same keypress.
    if j > chr then
      return row, j
    end
    row = row + 1
    chr = 0
  end
  return total, charlen(line_at(buf, total))
end

---The boundary one word back. Mirror of `next_pos`: step back over the space
---behind us, then over the word, landing on that word's first character.
local function prev_pos(buf, row, chr)
  while true do
    local line = line_at(buf, row)
    local j = math.min(chr, charlen(line))
    while j > 0 and is_space(charat(line, j - 1)) do
      j = j - 1
    end
    while j > 0 and not is_space(charat(line, j - 1)) do
      j = j - 1
    end
    if j < chr then
      return row, j
    end
    if row <= 1 then
      return 1, 0
    end
    row = row - 1
    chr = charlen(line_at(buf, row))
  end
end

---One extmark for the whole unread region, spanning from the boundary to the end
---of the buffer, rather than one per line.
---
---No `priority` is set because none is needed: an extmark defaults to 4096 and
---treesitter highlights sit at 100, so the gray already wins over the markdown
---syntax colours underneath. Verified rather than assumed.
local function render()
  if not state or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(state.buf, NS, 0, -1)

  local total = vim.api.nvim_buf_line_count(state.buf)
  local lastline = line_at(state.buf, total)
  local col = byteoff(line_at(state.buf, state.row), state.chr)

  -- Boundary past the final character: everything is read, nothing to gray out.
  if state.row >= total and col >= #lastline then
    return
  end

  vim.api.nvim_buf_set_extmark(state.buf, NS, state.row - 1, col, {
    end_row = total - 1,
    end_col = #lastline,
    hl_group = "PilsaUnread",
  })
end

---Move the cursor to the boundary so the view scrolls with it.
local function follow()
  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_buf(win) ~= state.buf then
    return
  end
  local col = byteoff(line_at(state.buf, state.row), state.chr)
  pcall(vim.api.nvim_win_set_cursor, win, { state.row, col })
end

local function step(forward)
  if not state or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end
  local fn = forward and next_pos or prev_pos
  state.row, state.chr = normalize(state.buf, fn(state.buf, state.row, state.chr))
  render()
  follow()
end

function M.stop()
  if not state then
    return
  end
  local s = state
  state = nil

  if vim.api.nvim_buf_is_valid(s.buf) then
    vim.api.nvim_buf_clear_namespace(s.buf, NS, 0, -1)
    vim.bo[s.buf].modifiable = s.modifiable
    -- The buffer is a real file, not a scratch one, so the mappings have to come
    -- back off. `q` in particular is macro recording and would be missed.
    for _, lhs in ipairs({ "<Tab>", "<S-Tab>", "<BS>", "q" }) do
      pcall(vim.keymap.del, "n", lhs, { buffer = s.buf })
    end
  end

  if s.zen then
    pcall(function()
      require("zen-mode").close()
    end)
  end
end

function M.start()
  M.stop()

  local buf = vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_line_count(buf) == 1 and line_at(buf, 1) == "" then
    vim.notify("필사 read: buffer is empty", vim.log.levels.WARN)
    return
  end

  state = {
    buf = buf,
    -- Start where the cursor is, so a long article can be resumed part-way rather
    -- than always restarted from the top.
    row = vim.api.nvim_win_get_cursor(0)[1],
    chr = 0,
    modifiable = vim.bo[buf].modifiable,
    zen = false,
  }

  state.zen = pcall(function()
    require("zen-mode").open()
  end)

  state.row, state.chr = normalize(buf, state.row, state.chr)
  vim.bo[buf].modifiable = false

  vim.keymap.set("n", "<Tab>", function()
    step(true)
  end, { buffer = buf, desc = "필사 read: next word" })

  -- <BS> alongside <S-Tab>: not every terminal reports shift+tab distinctly, and
  -- losing the ability to go back would be the whole feature.
  for _, lhs in ipairs({ "<S-Tab>", "<BS>" }) do
    vim.keymap.set("n", lhs, function()
      step(false)
    end, { buffer = buf, desc = "필사 read: previous word" })
  end

  vim.keymap.set("n", "q", M.stop, { buffer = buf, desc = "필사 read: leave" })

  -- If the buffer is wiped while a session is live there is nothing left to
  -- restore, and holding a stale handle would make the next stop() misfire.
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = vim.api.nvim_create_augroup("PilsaReadSession", { clear = true }),
    buffer = buf,
    callback = function()
      state = nil
    end,
  })

  render()
  follow()
end

vim.api.nvim_set_hl(0, "PilsaUnread", { link = "Comment", default = true })

vim.api.nvim_create_user_command("PilsaReadMode", M.start, {
  desc = "필사 read: walk the buffer one word at a time, unread text grayed",
})

vim.api.nvim_create_user_command("PilsaReadQuit", M.stop, {
  desc = "필사 read: leave read mode",
})

vim.keymap.set("n", "<localleader>pr", "<cmd>PilsaReadMode<CR>", {
  silent = true,
  desc = "필사 read mode",
})

return M
