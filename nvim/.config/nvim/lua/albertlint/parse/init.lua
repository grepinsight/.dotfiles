---The sentence-structure sidebar: cache, window, and the hover path.
---
---The whole feature exists to answer one question fast: *what is the structure of the
---sentence I am looking at?* spaCy cannot answer it in under a millisecond (measured: 2.0 ms
---for 25 words, 3.6 ms for 44), so the parse is moved off the interaction path entirely and
---the hover becomes a table lookup. See
---`docs/superpowers/specs/2026-09-09-albertlint-syntax-tree-design.md`.
---
---The cache is keyed on **sentence text**, not on buffer position. Keying on offsets was the
---obvious design and is wrong: every keystroke shifts every offset after the cursor, so the
---cache would invalidate on each edit. Keyed on text, an edit invalidates exactly the one
---sentence you edited and the rest of the buffer stays hot for the session.
local config = require("albertlint.config")
local daemon = require("albertlint.parse.daemon")
local engine = require("albertlint.engine")
local sentence = require("albertlint.parse.sentence")
local tree = require("albertlint.parse.tree")

local M = {}

local NS = vim.api.nvim_create_namespace("albertlint_tree")
local AUGROUP = "AlbertLintTree"

---@type table<integer, table<string, table>>
local cache = {}
---@type table<integer, uv_timer_t>
local timers = {}

M.view = {
  win = nil,
  buf = nil,
  follow = false,
  ---@type table<integer, integer>
  index = {},
  last_key = nil,
  last_render_us = nil,
  hits = 0,
  misses = 0,
}

---@return table
local function opts()
  return config.get().parse or {}
end

---@param bufnr integer
---@return table<string, table>
local function bucket(bufnr)
  cache[bufnr] = cache[bufnr] or {}
  return cache[bufnr]
end

---@param bufnr integer
---@return string[] lines, table mask
local function buffer_lines(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return lines, engine._build_mask(lines)
end

--- Submit every sentence in the buffer that is not already cached.
---@param bufnr integer|nil
---@param on_done fun()|nil
function M.sweep(bufnr, on_done)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local lines, mask = buffer_lines(bufnr)
  local store = bucket(bufnr)
  local todo = {}
  for _, text in ipairs(sentence.all(lines, mask)) do
    if not store[text] then
      table.insert(todo, text)
    end
  end
  if #todo == 0 then
    if on_done then
      on_done()
    end
    return
  end

  local cap = opts().max_sentences or 400
  if #todo > cap then
    -- Named, not silent. A truncated sweep looks exactly like a working one from the
    -- sidebar, and the difference only shows up as unexplained misses much later.
    vim.notify(
      ("albertlint: parsing the first %d of %d uncached sentences (parse.max_sentences)")
        :format(cap, #todo),
      vim.log.levels.WARN
    )
    todo = vim.list_slice(todo, 1, cap)
  end

  daemon.request(todo, function(res)
    if res.error then
      vim.notify("albertlint: parser: " .. res.error, vim.log.levels.ERROR)
      return
    end
    local into = bucket(bufnr)
    for n, t in ipairs(res.trees or {}) do
      into[todo[n]] = t
    end
    if on_done then
      on_done()
    end
  end)
end

---@return integer
local function sidebar_buf()
  if M.view.buf and vim.api.nvim_buf_is_valid(M.view.buf) then
    return M.view.buf
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "albertlint-tree"
  vim.bo[buf].bufhidden = "hide"
  vim.api.nvim_buf_set_name(buf, "albertlint://tree")
  vim.keymap.set("n", "q", function()
    M.close()
  end, { buffer = buf, desc = "albertlint: close the structure sidebar" })
  vim.keymap.set("n", "K", function()
    M.explain()
  end, { buffer = buf, desc = "albertlint: raw tag and dependency label for this token" })
  M.view.buf = buf
  return buf
end

---@return integer|nil
local function sidebar_win()
  if M.view.win and vim.api.nvim_win_is_valid(M.view.win) then
    return M.view.win
  end
  return nil
end

---@param source_win integer
local function ensure_window(source_win)
  if sidebar_win() then
    return
  end
  local buf = sidebar_buf()
  local width = opts().width or 52
  vim.api.nvim_win_call(source_win, function()
    vim.cmd("noautocmd botright vsplit")
    M.view.win = vim.api.nvim_get_current_win()
  end)
  vim.api.nvim_win_set_buf(M.view.win, buf)
  vim.api.nvim_win_set_width(M.view.win, width)
  local wo = vim.wo[M.view.win]
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = "no"
  wo.wrap = true
  wo.linebreak = true
  wo.winfixwidth = true
  vim.api.nvim_set_current_win(source_win)
end

---@param bufnr integer
---@param span table|nil
local function highlight(bufnr, span)
  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  if not span or not opts().highlight_sentence then
    return
  end
  for lnum = span.start_lnum, span.end_lnum do
    local line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1]
    if not line then
      break
    end
    local from = lnum == span.start_lnum and span.start_col or 0
    local to = lnum == span.end_lnum and math.min(span.end_col, #line) or #line
    if to > from then
      vim.api.nvim_buf_set_extmark(bufnr, NS, lnum, from, {
        end_col = to,
        hl_group = "AlbertLintTreeSentence",
      })
    end
  end
end

---Render the sentence under the cursor.
---
---This is the hover path, and the only thing on it is a table lookup and
---`tree.render`, both pure Lua. Nothing here talks to Python on a cache hit; that is what
---makes the sub-millisecond claim true, and `:AlbertLintTreeStatus` reports the measured
---number so it can be checked rather than believed.
---@param force boolean|nil Re-render even if the sentence has not changed
---@return boolean rendered
function M.render_current(force)
  local win = sidebar_win()
  if not win then
    return false
  end
  local bufnr = vim.api.nvim_get_current_buf()
  if bufnr == M.view.buf then
    return false
  end
  local t0 = vim.uv.hrtime()

  local lines, mask = buffer_lines(bufnr)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local span = sentence.at(lines, row - 1, col, mask)
  if not span then
    M.view.last_key = nil
    vim.bo[M.view.buf].modifiable = true
    vim.api.nvim_buf_set_lines(M.view.buf, 0, -1, false, { "(no sentence under the cursor)" })
    vim.bo[M.view.buf].modifiable = false
    highlight(bufnr, nil)
    return true
  end
  if span.text == M.view.last_key and not force then
    return false
  end

  local parsed = bucket(bufnr)[span.text]
  if not parsed then
    M.view.misses = M.view.misses + 1
    vim.bo[M.view.buf].modifiable = true
    vim.api.nvim_buf_set_lines(M.view.buf, 0, -1, false, { span.text, "", "(parsing...)" })
    vim.bo[M.view.buf].modifiable = false
    highlight(bufnr, span)
    local key = span.text
    daemon.request({ key }, function(res)
      if res.error or not res.trees or not res.trees[1] then
        return
      end
      bucket(bufnr)[key] = res.trees[1]
      -- Re-read the cursor rather than rendering `key` blind: 2 to 5 ms is long enough to
      -- have moved on, and drawing a tree for the sentence you just left is worse than a
      -- blank pane.
      M.render_current(true)
    end)
    return true
  end

  M.view.hits = M.view.hits + 1
  local rendered, index = tree.render(parsed, {
    include_punct = opts().include_punct,
    dep_labels = opts().dep_labels,
  })
  vim.bo[M.view.buf].modifiable = true
  vim.api.nvim_buf_set_lines(M.view.buf, 0, -1, false, rendered)
  vim.bo[M.view.buf].modifiable = false
  M.view.index = index
  M.view.last_key = span.text
  highlight(bufnr, span)
  M.view.last_render_us = (vim.uv.hrtime() - t0) / 1000
  return true
end

---Open the sidebar, or refresh it if it is already open.
function M.open()
  local source_win = vim.api.nvim_get_current_win()
  if vim.api.nvim_get_current_buf() == M.view.buf then
    return
  end
  ensure_window(source_win)
  local bufnr = vim.api.nvim_get_current_buf()
  M.render_current(true)
  -- Warm the rest of the buffer behind the first render, so moving to the next sentence
  -- is a hit rather than another 2 ms round trip.
  M.sweep(bufnr, function()
    if sidebar_win() then
      M.render_current(true)
    end
  end)
end

function M.close()
  local win = sidebar_win()
  if win then
    vim.api.nvim_win_close(win, true)
  end
  M.view.win = nil
  M.view.last_key = nil
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
    end
  end
end

function M.toggle()
  if sidebar_win() then
    M.close()
  else
    M.open()
  end
end

---@return boolean following
function M.toggle_follow()
  M.view.follow = not M.view.follow
  if M.view.follow and not sidebar_win() then
    M.open()
  end
  return M.view.follow
end

---The raw labels for the token on the sidebar line under the cursor.
---
---The sidebar shows glossed labels because `subject` teaches and `nsubj` does not, but the
---raw tag is the searchable term, so it stays one keystroke away rather than being replaced.
function M.explain()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local token_i = M.view.index and M.view.index[row]
  if not token_i then
    vim.notify("albertlint: no token on this line", vim.log.levels.INFO)
    return
  end
  local parsed
  for _, store in pairs(cache) do
    if store[M.view.last_key] then
      parsed = store[M.view.last_key]
      break
    end
  end
  if not parsed then
    return
  end
  for _, token in ipairs(parsed.tokens) do
    if token.i == token_i then
      local head = "root"
      for _, other in ipairs(parsed.tokens) do
        if other.i == token.head and other.i ~= token.i then
          head = other.text
        end
      end
      vim.notify(("%s  pos=%s  tag=%s  dep=%s  head=%s"):format(
        token.text, token.pos, token.tag, token.dep, head
      ), vim.log.levels.INFO)
      return
    end
  end
end

---@param bufnr integer
local function schedule_sweep(bufnr)
  local ms = opts().debounce_ms or 500
  if timers[bufnr] then
    timers[bufnr]:stop()
    timers[bufnr]:close()
    timers[bufnr] = nil
  end
  local timer = vim.uv.new_timer()
  timers[bufnr] = timer
  timer:start(ms, 0, vim.schedule_wrap(function()
    if timers[bufnr] then
      timers[bufnr]:stop()
      timers[bufnr]:close()
      timers[bufnr] = nil
    end
    M.sweep(bufnr, function()
      if sidebar_win() then
        M.render_current(true)
      end
    end)
  end))
end

---Cache size, daemon state, and the measured hover latency.
function M.status()
  local total = 0
  for _, store in pairs(cache) do
    for _ in pairs(store) do
      total = total + 1
    end
  end
  local lines = {
    "# albertlint parser status",
    "",
    ("installed          %s"):format(daemon.installed() and daemon.root() or "no, run :AlbertLintTreeBootstrap"),
    ("daemon             %s"):format(
      daemon.state.ready and "ready" or (daemon.state.starting and "starting" or "not running")
    ),
    ("model load         %s"):format(daemon.state.load_ms and (daemon.state.load_ms .. " ms") or "-"),
    ("pipes              %s"):format(daemon.state.pipes and table.concat(daemon.state.pipes, ", ") or "-"),
    ("last parse         %s"):format(daemon.state.last_parse_ms and (daemon.state.last_parse_ms .. " ms") or "-"),
    ("parse requests     %d, %d sentences"):format(daemon.state.parses, daemon.state.sentences_parsed),
    "",
    ("cached sentences   %d across %d buffers"):format(total, vim.tbl_count(cache)),
    ("hover hits         %d"):format(M.view.hits),
    ("hover misses       %d"):format(M.view.misses),
    ("last hover render  %s"):format(
      M.view.last_render_us and ("%.1f us"):format(M.view.last_render_us) or "-"
    ),
    ("follow mode        %s"):format(M.view.follow and "on" or "off"),
  }
  if daemon.state.error then
    table.insert(lines, "")
    table.insert(lines, "error              " .. daemon.state.error)
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

---Measure the hover path over every cached sentence in this buffer.
---
---Exists because section 1 of the design doc makes a latency promise, and a promise about
---someone's machine should be checkable on that machine. Reports the render only: the cache
---lookup plus `tree.render`, which is exactly what a hover on a cached sentence costs.
---@param bufnr integer|nil
function M.benchmark(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local store = bucket(bufnr)
  local samples = {}
  local render_opts = { include_punct = opts().include_punct, dep_labels = opts().dep_labels }
  for key, parsed in pairs(store) do
    local t0 = vim.uv.hrtime()
    tree.render(parsed, render_opts)
    table.insert(samples, { us = (vim.uv.hrtime() - t0) / 1000, words = #parsed.tokens, key = key })
  end
  if #samples == 0 then
    vim.notify("albertlint: nothing cached yet; open the sidebar first", vim.log.levels.WARN)
    return
  end
  table.sort(samples, function(a, b)
    return a.us < b.us
  end)
  local sum = 0
  for _, s in ipairs(samples) do
    sum = sum + s.us
  end
  local worst = samples[#samples]
  vim.notify(table.concat({
    ("albertlint hover benchmark over %d cached sentences"):format(#samples),
    ("  median  %.1f us"):format(samples[math.ceil(#samples / 2)].us),
    ("  mean    %.1f us"):format(sum / #samples),
    ("  worst   %.1f us  (%d tokens)"):format(worst.us, worst.words),
    "  measured: cache lookup plus render, which is the whole hover path on a hit",
  }, "\n"), vim.log.levels.INFO)
end

---@param bufnr integer|nil
function M.clear_cache(bufnr)
  if bufnr then
    cache[bufnr] = nil
  else
    cache = {}
  end
  M.view.last_key = nil
end

function M.setup()
  vim.api.nvim_set_hl(0, "AlbertLintTreeSentence", { link = "Underlined", default = true })

  local group = vim.api.nvim_create_augroup(AUGROUP, { clear = true })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorHold" }, {
    group = group,
    callback = function(ev)
      if M.view.follow and sidebar_win() and ev.buf ~= M.view.buf then
        M.render_current(false)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, {
    group = group,
    callback = function(ev)
      if sidebar_win() and ev.buf ~= M.view.buf then
        schedule_sweep(ev.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(ev)
      cache[ev.buf] = nil
      if timers[ev.buf] then
        timers[ev.buf]:stop()
        timers[ev.buf]:close()
        timers[ev.buf] = nil
      end
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      daemon.stop()
    end,
  })
end

return M
