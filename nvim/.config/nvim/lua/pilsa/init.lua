---필사 (transcription practice) mode.
---
---Paste an article, select a phrase worth internalising, and retype it with the
---source shown as gray ghost text under the cursor. Each character you type
---replaces the gray character sitting in that column, the way typing-practice
---software works.
---
---Nothing about the typing is kept -- the point is the attention it costs, not the
---artifact. What *is* kept, optionally, is the thought you have afterwards: on
---completion a small note pane opens, and <C-s> appends it to today's daily note
---under `## 필사`.
---
---Rendering leans entirely on extmark overlays (`virt_text_pos = "overlay"`), the
---same primitive Copilot uses for its ghost text. The practice buffer is an
---ordinary modifiable scratch buffer, which is deliberate: undo, backspace,
---motions and IME composition stay Neovim's problem rather than ours. Trapping
---every printable key would give tighter control (a wrong character could be
---refused outright) but is expected to break Hangul input, and a 필사 tool that
---cannot take Korean is not worth having.
---
---Commands: `:Pilsa` (range or current paragraph), `:PilsaQuit`.

local vault = require("util.vault")

local M = {}

local NS = vim.api.nvim_create_namespace("pilsa")
local DAILY_DIR = "02-Calendar/Daily"
local HEADING = "## 필사"
local MAX_WIDTH = 80

---@class PilsaState
---@field src string[] wrapped source lines: the thing being copied
---@field buf integer practice buffer
---@field win integer practice window
---@field note_buf integer|nil reflection buffer, once the passage is done
---@field note_win integer|nil
---@field origin string|nil link back to where the passage came from
---@field done boolean completion has already fired, so it fires once
local state = nil

-- Character-wise helpers. Everything below counts characters, never bytes: one
-- keystroke is one character, and a Hangul syllable is three bytes. Getting this
-- wrong makes the ghost text drift out of alignment part-way along a Korean line.

local function charlen(s)
  return vim.fn.strcharlen(s)
end

local function charat(s, n)
  return vim.fn.strcharpart(s, n, 1)
end

---Byte offset of character index `n`. `byteidx` returns -1 past the end of the
---string, where the byte length is the answer we want.
local function byteoff(s, n)
  local b = vim.fn.byteidx(s, n)
  if b < 0 then
    return #s
  end
  return b
end

---Hard-wrap `lines` so none is wider than `width` display cells.
---
---Overlay virtual text does not wrap: whatever runs past the window edge is simply
---not drawn, so a paragraph pasted as one long line would show ghost text for its
---first screenful only. Existing structure is preserved -- lines that already fit
---pass through untouched -- so short lines, poetry and code do not get reflowed
---into prose.
local function wrap(lines, width)
  local out = {}
  for _, line in ipairs(lines) do
    if vim.fn.strdisplaywidth(line) <= width then
      table.insert(out, line)
    else
      local cur = ""
      for word in line:gmatch("%S+") do
        local candidate = cur == "" and word or (cur .. " " .. word)
        if cur ~= "" and vim.fn.strdisplaywidth(candidate) > width then
          table.insert(out, cur)
          cur = word
        else
          cur = candidate
        end
      end
      if cur ~= "" then
        table.insert(out, cur)
      end
    end
  end
  return out
end

local function blanks(n)
  local t = {}
  for _ = 1, n do
    table.insert(t, "")
  end
  return t
end

---Recompute every mark from scratch.
---
---Cheap enough to run on each keystroke (a session is a phrase, not a file) and far
---easier to reason about than incremental patching: exactly one function decides
---what is on screen, so there is no state to get out of step.
local function redraw()
  if not state or not vim.api.nvim_buf_is_valid(state.buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(state.buf, NS, 0, -1)

  local typed = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)

  -- Self-heal the line count. A <BS> at column 0 joins two lines, which would
  -- otherwise leave the buffer permanently one line short of the source and every
  -- later ghost line attached to the wrong text. Padding is lossless; truncating is
  -- not, so we only ever grow.
  if #typed < #state.src then
    vim.api.nvim_buf_set_lines(state.buf, #typed, #typed, false, blanks(#state.src - #typed))
    typed = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
  end

  local complete = #typed == #state.src

  for i, src in ipairs(state.src) do
    local got = typed[i] or ""
    local n_got, n_src = charlen(got), charlen(src)

    -- Index-based alignment, the model every typing trainer uses: your Nth
    -- character is judged against the source's Nth character. A wrong character
    -- still advances the index, so the ghost text holds its place and you can see
    -- the divergence, rather than the whole tail resynchronising around a typo.
    -- Characters typed past the end of the source line compare against "" and are
    -- therefore all flagged, which is the behaviour we want.
    for j = 0, n_got - 1 do
      if charat(got, j) ~= charat(src, j) then
        complete = false
        vim.api.nvim_buf_set_extmark(state.buf, NS, i - 1, byteoff(got, j), {
          end_col = byteoff(got, j + 1),
          hl_group = "PilsaError",
        })
      end
    end

    if n_got < n_src then
      complete = false
      vim.api.nvim_buf_set_extmark(state.buf, NS, i - 1, #got, {
        virt_text = { { vim.fn.strcharpart(src, n_got), "PilsaGhost" } },
        virt_text_pos = "overlay",
        hl_mode = "combine",
      })
    end
  end

  if complete and not state.done then
    state.done = true
    -- Scheduled: this runs from a TextChanged callback, and opening a window from
    -- inside one is not safe.
    vim.schedule(M.finish)
  end
end

---A wikilink when the passage came from inside the vault, so Obsidian resolves it
---and the backlink shows up on the source note; a plain path otherwise.
local function origin_link(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return nil
  end
  local norm = vim.fs.normalize(name)
  local root = vault.root()
  if norm:sub(1, #root + 1) == root .. "/" then
    return "[[" .. vim.fn.fnamemodify(norm, ":t:r") .. "]]"
  end
  return "`" .. vim.fn.fnamemodify(norm, ":~") .. "`"
end

---Append the passage and the thought to today's daily note under `## 필사`.
---
---Path convention is taken from `custom_commands.lua` (`:Daily` and friends) rather
---than restated, so there is one idea of where a daily note lives.
local function append_to_daily(thought)
  local date = os.date("%Y-%m-%d")
  local filepath = vault.path(DAILY_DIR, date .. ".md")
  vim.fn.mkdir(vault.path(DAILY_DIR), "p")

  local lines = {}
  if vim.fn.filereadable(filepath) == 1 then
    lines = vim.fn.readfile(filepath)
  end

  local entry = { "### " .. os.date("%I:%M %p") }
  for _, l in ipairs(state.src) do
    table.insert(entry, "> " .. l)
  end
  table.insert(entry, "")
  vim.list_extend(entry, thought)
  if state.origin then
    table.insert(entry, "")
    table.insert(entry, "Source: " .. state.origin)
  end

  -- Land the entry at the end of the 필사 section, not the end of the file: the
  -- daily note has other sections after it and they should stay after it.
  local at = nil
  for i, l in ipairs(lines) do
    if l:match("^##%s+필사%s*$") then
      at = #lines + 1
      for j = i + 1, #lines do
        if lines[j]:match("^##%s") then
          at = j
          break
        end
      end
      break
    end
  end

  local out = {}
  if at then
    for i = 1, at - 1 do
      table.insert(out, lines[i])
    end
    while #out > 0 and out[#out] == "" do
      table.remove(out)
    end
    table.insert(out, "")
    vim.list_extend(out, entry)
    table.insert(out, "")
    for i = at, #lines do
      table.insert(out, lines[i])
    end
  else
    out = lines
    if #out > 0 and out[#out] ~= "" then
      table.insert(out, "")
    end
    table.insert(out, HEADING)
    table.insert(out, "")
    vim.list_extend(out, entry)
  end

  vim.fn.writefile(out, filepath)
  return filepath
end

---Tear down both panes and forget the session.
function M.close()
  if not state then
    return
  end
  local s = state
  state = nil
  -- Built up conditionally rather than as `{ s.note_win, s.win }`: a session aborted
  -- before completion has no note window, and `ipairs` over a table whose first
  -- element is nil stops immediately, so the practice window would never close.
  local wins = {}
  if s.note_win then
    table.insert(wins, s.note_win)
  end
  if s.win then
    table.insert(wins, s.win)
  end
  for _, w in ipairs(wins) do
    if vim.api.nvim_win_is_valid(w) then
      vim.api.nvim_win_close(w, true)
    end
  end
end

M.abort = M.close

---Open the reflection pane.
---
---Deliberately after the typing rather than beside it: the thought is a reaction to
---the completed act, and a second pane on screen while you type is one more thing
---competing for the attention the exercise exists to buy. The practice pane stays
---open above it, because the passage you just wrote is the context for the thought.
function M.finish()
  if not state or state.note_buf then
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"

  vim.cmd("botright 8split")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].winfixheight = true

  state.note_buf, state.note_win = buf, win

  -- Instructions as a virtual line rather than buffer text, so they cannot end up
  -- inside the saved note.
  vim.api.nvim_buf_set_extmark(buf, NS, 0, 0, {
    virt_lines_above = true,
    virt_lines = { { { "  필사 · <C-s> save to today's daily note · q discard", "PilsaGhost" } } },
  })

  local function save()
    local thought = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    while #thought > 0 and thought[#thought]:match("^%s*$") do
      table.remove(thought)
    end
    while #thought > 0 and thought[1]:match("^%s*$") do
      table.remove(thought, 1)
    end
    if #thought == 0 then
      M.close()
      vim.notify("필사: nothing written, discarded", vim.log.levels.INFO)
      return
    end
    local path = append_to_daily(thought)
    M.close()
    vim.notify("필사 → " .. vim.fn.fnamemodify(path, ":t"), vim.log.levels.INFO)
  end

  vim.keymap.set({ "n", "i" }, "<C-s>", save, { buffer = buf, desc = "필사: save note" })
  vim.keymap.set("n", "q", M.close, { buffer = buf, desc = "필사: discard note" })

  vim.cmd("startinsert")
end

---The paragraph the cursor is sitting in, used when `:Pilsa` is called with no range.
local function current_paragraph(bufnr)
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if #lines == 0 or not (lines[cur] or ""):match("%S") then
    return {}
  end
  local s, e = cur, cur
  while s > 1 and lines[s - 1]:match("%S") do
    s = s - 1
  end
  while e < #lines and lines[e + 1]:match("%S") do
    e = e + 1
  end
  return vim.list_slice(lines, s, e)
end

---The text a `:'<,'>Pilsa` invocation meant.
---
---A user command runs after visual mode has ended, so the selection is read back
---from the `<`/`>` marks. Columns are honoured only for charwise mode, so selecting
---a phrase inside a line works; `V` and `<C-v>` take whole lines. The `visualmode()`
---check can in principle be stale (it reports the last visual mode used, not
---necessarily the one that produced this range), which is why the mark rows must
---also match the range the command was given.
local function selected_text(bufnr, line1, line2)
  local s = vim.api.nvim_buf_get_mark(bufnr, "<")
  local e = vim.api.nvim_buf_get_mark(bufnr, ">")
  if vim.fn.visualmode() ~= "v" or s[1] ~= line1 or e[1] ~= line2 then
    return vim.api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)
  end

  local last = vim.api.nvim_buf_get_lines(bufnr, e[1] - 1, e[1], false)[1] or ""
  local ecol = math.min(e[2] + 1, #last)
  -- The `>` mark points at the first byte of the final character; step past its
  -- continuation bytes so a selection ending on a Hangul syllable is not cut in half.
  while ecol < #last do
    local b = last:byte(ecol + 1)
    if b and b >= 0x80 and b < 0xC0 then
      ecol = ecol + 1
    else
      break
    end
  end
  return vim.api.nvim_buf_get_text(bufnr, s[1] - 1, s[2], e[1] - 1, ecol, {})
end

function M.start(opts)
  M.close()

  local origin_buf = vim.api.nvim_get_current_buf()
  local src
  if opts and opts.range and opts.range > 0 then
    src = selected_text(origin_buf, opts.line1, opts.line2)
  else
    src = current_paragraph(origin_buf)
  end

  local width = math.max(20, math.min(MAX_WIDTH, vim.api.nvim_win_get_width(0) - 8))
  src = wrap(src, width)
  while #src > 0 and src[#src]:match("^%s*$") do
    table.remove(src)
  end
  while #src > 0 and src[1]:match("^%s*$") do
    table.remove(src, 1)
  end
  if #src == 0 then
    vim.notify("필사: nothing to transcribe", vim.log.levels.WARN)
    return
  end

  local origin = origin_link(origin_buf)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "pilsa"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, blanks(#src))

  local height = math.max(3, math.min(#src + 1, math.floor(vim.o.lines * 0.5)))
  vim.cmd("botright " .. height .. "split")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)

  -- Anything that draws in the text area competes with the overlay for the same
  -- columns, so all of it goes off: `listchars` (init.lua sets `eol:↲`), conceal
  -- (`conceallevel` is 2 globally), signs, numbers, and wrapping.
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].list = false
  vim.wo[win].conceallevel = 0
  vim.wo[win].wrap = false
  vim.wo[win].spell = false
  vim.wo[win].cursorline = false
  vim.wo[win].winfixheight = true

  state = {
    src = src,
    buf = buf,
    win = win,
    origin = origin,
    done = false,
  }

  -- <CR> must not split the line. The buffer is pre-seeded with one blank line per
  -- source line; inserting a break would push every later line out of step with its
  -- ghost text. Jump to the next line instead.
  vim.keymap.set("i", "<CR>", function()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    if row < vim.api.nvim_buf_line_count(buf) then
      vim.api.nvim_win_set_cursor(win, { row + 1, 0 })
    end
  end, { buffer = buf, desc = "필사: next line" })

  -- An escape hatch: forgiving mode lets you finish a passage with errors still in
  -- it, but it will not call that complete, so there has to be a way to stop and
  -- still write the note.
  vim.keymap.set({ "n", "i" }, "<C-s>", function()
    vim.cmd("stopinsert")
    M.finish()
  end, { buffer = buf, desc = "필사: stop here and write the note" })

  vim.keymap.set("n", "q", M.close, { buffer = buf, desc = "필사: abort" })

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP" }, {
    group = vim.api.nvim_create_augroup("PilsaSession", { clear = true }),
    buffer = buf,
    callback = redraw,
  })

  redraw()
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
  vim.cmd("startinsert")
end

-- `default = true` so a colorscheme, or you, can override these without being
-- clobbered when this file reloads.
vim.api.nvim_set_hl(0, "PilsaGhost", { link = "Comment", default = true })
vim.api.nvim_set_hl(0, "PilsaError", { link = "ErrorMsg", default = true })

vim.api.nvim_create_user_command("Pilsa", M.start, {
  range = true,
  desc = "필사: transcribe the selection (or the current paragraph) over ghost text",
})

vim.api.nvim_create_user_command("PilsaQuit", M.close, {
  desc = "필사: abort the current session",
})

vim.keymap.set({ "n", "x" }, "<localleader>pp", ":Pilsa<CR>", {
  silent = true,
  desc = "필사 transcription practice",
})

return M
