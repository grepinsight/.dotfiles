---Graded review levels, on demand.
---
---One command per level, each answering a different question, so feedback arrives in an
---order the writer can absorb rather than all at once. Level 1 is grammar and usage; see
---`levels.lua` for the ladder and
---`docs/superpowers/specs/2026-09-08-albertlint-graded-levels-design.md` for why the model
---returns spans rather than a rewrite, and for the scoped exception to the no-replacement-
---prose doctrine that this command represents.
---
---On demand only, like the semantic tier. Nothing here runs on a keystroke: it shells out,
---it takes tens of seconds, and it costs money.
local apply = require("albertlint.level.apply")
local config = require("albertlint.config")
local diffview = require("albertlint.level.diffview")
local levels = require("albertlint.level.levels")
local provider = require("albertlint.level.provider")
local semantic = require("albertlint.semantic")

local M = {}

---Passes currently running, keyed by buffer.
---
---The semantic tier learned this the expensive way: with no guard, a second invocation
---spawned a second CLI process, which meant two paid calls and two sets of results racing
---to overwrite each other with no way to tell which won. The guard also answers the liveness
---question for free, since running the command again while one is in flight reports how long
---it has been going instead of silently doubling the bill.
---@type table<integer, { handle: table|nil, started: number, lines: integer, level: integer }>
local in_flight = {}

---Diff views currently open, keyed by source buffer.
---@type table<integer, table>
local open_views = {}

---Buffers whose pass the writer stopped on purpose.
---
---Killing the process still delivers a completion callback with a non-zero exit, so without
---this a cancel produced two messages: "cancelled after 4s" immediately followed by "pass
---failed, so nothing changed. Run it again." The second one is noise at best and reads as a
---bug at worst, since nothing failed.
---@type table<integer, boolean>
local cancelled = {}

---The last findings fetched per buffer and level, so closing and reopening the diff is free.
---
---A pass costs money and 30 to 90 seconds. Without this, `:AlbertLintLevelClose` followed by
---`:AlbertLintLevel1` is a second paid call for an answer already in memory, which makes the
---diff something you keep open rather than something you consult.
---
---The cache holds the raw findings, not the corrected lines, and they are re-applied against
---the buffer as it is *now*. That is what makes it behave correctly after a `do`: an accepted
---fix no longer matches its quote, so `apply.build` drops it and the remaining findings still
---place. A stale finding cannot mis-apply either, because placement needs a byte-exact quote
---match and an edited line will not provide one.
---@type table<integer, table<integer, { findings: table[], at: number, provider: string }>>
local cache = {}

---@param started integer Nanoseconds from vim.uv.hrtime
---@return string
local function elapsed(started)
  return ("%.0fs"):format(((vim.uv or vim.loop).hrtime() - started) / 1e9)
end

---Find the level view for a buffer, accepting EITHER side of the diff.
---
---Every one of these commands is naturally typed from whichever window you happen to be
---looking at, and one of them is the corrected scratch buffer. Looking up only
---`open_views[bufnr]` therefore found nothing and `:AlbertLintLevelClose` silently tore
---nothing down, leaving the real buffer in diff mode with a winbar still on it. Verified
---2026-09-08; the unit test missed it because it called `diffview.close(state)` directly and
---bypassed this lookup entirely.
---@param bufnr integer
---@return integer|nil source_buf
---@return table|nil state
local function resolve(bufnr)
  if open_views[bufnr] then
    return bufnr, open_views[bufnr]
  end
  for source_buf, state in pairs(open_views) do
    if state.scratch_buf == bufnr then
      return source_buf, state
    end
  end
  return nil, nil
end

---Render the range as absolute-numbered lines.
---
---Absolute rather than 1-based-within-the-range, matching `semantic.lua`, so the model's
---answer needs no offset arithmetic and a fix from a selection-scoped pass still points at
---the right buffer line.
---@param lines string[]
---@param start_lnum integer 1-indexed
---@return string
function M._numbered(lines, start_lnum)
  if #lines == 0 then
    return ""
  end
  local out = {}
  for i, line in ipairs(lines) do
    table.insert(out, ("%d: %s"):format(start_lnum + i - 1, line))
  end
  return table.concat(out, "\n") .. "\n"
end

---@param lines string[]
---@return boolean
local function all_blank(lines)
  for _, line in ipairs(lines) do
    if line:match("%S") then
      return false
    end
  end
  return true
end

---Open the diff from findings, whether they just arrived or came from the cache.
---@param bufnr integer
---@param def table
---@param findings table[]
---@return integer placed, integer dropped
local function present(bufnr, def, findings)
  -- The WHOLE buffer, not the reviewed range: the scratch copy is diffed against the real
  -- buffer, and a range-only array would make every untouched line outside the range read
  -- as a deletion.
  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local corrected, placed, dropped = apply.build(all_lines, 1, findings or {})
  if #placed > 0 then
    open_views[bufnr] = diffview.open(bufnr, corrected, placed, { level = def.id })
  end
  return #placed, #dropped
end

---@param n integer
---@param one string
---@param many string
---@return string
local function plural(n, one, many)
  return n == 1 and one or many
end

---@param id integer
---@param use_selection boolean
---@param force boolean|nil Skip the cache and make a fresh call
function M.run(id, use_selection, force)
  local opts = config.get().level
  if not opts.enabled then
    vim.notify("albertlint: the level tiers are disabled in config", vim.log.levels.WARN)
    return
  end

  local def = levels.get(id)
  local prompt = levels.prompt(id)
  if not def or not prompt then
    vim.notify(
      ("albertlint: level %s is not implemented yet. Only level 1 (grammar/usage) has a "
        .. "command; see levels.lua for the planned ladder."):format(tostring(id)),
      vim.log.levels.WARN
    )
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()

  local running = in_flight[bufnr]
  if running then
    vim.notify(
      ("albertlint: a level %d pass is already running here (%s elapsed, %d lines). "
        .. ":AlbertLintLevelCancel to stop it.")
        :format(running.level, elapsed(running.started), running.lines),
      vim.log.levels.WARN
    )
    return
  end

  -- One view per buffer. A second diff over the same buffer would stack diffthis windows
  -- and leave no clear way back out.
  if open_views[bufnr] then
    M.close(bufnr)
  end

  -- Serve from cache before spending anything. This is what makes the diff a panel you can
  -- toggle rather than a call you have to think about.
  local hit = not force and (cache[bufnr] or {})[def.id] or nil
  if hit then
    local placed, dropped = present(bufnr, def, hit.findings)
    local age = ("%.0fs"):format(((vim.uv or vim.loop).hrtime() - hit.at) / 1e9)
    if placed == 0 then
      vim.notify(
        ("albertlint: level %d has nothing left to apply from the cached pass (%s old). "
          .. ":AlbertLintLevel%d! to run a fresh one."):format(def.id, age, def.id),
        vim.log.levels.INFO
      )
      return
    end
    local msg = ("albertlint: level %d, %d fix%s from cache (%s old, %s). "
      .. ":AlbertLintLevel%d! to re-run."):format(
      def.id, placed, plural(placed, "", "es"), age, hit.provider, def.id
    )
    if dropped > 0 then
      -- Usually because they were already accepted, which is the good case, so this is
      -- phrased as information rather than as a failure.
      msg = msg .. (" %d no longer %s the text, most likely already applied."):format(
        dropped, plural(dropped, "matches", "match")
      )
    end
    vim.notify(msg, vim.log.levels.INFO)
    return
  end

  local start_lnum, end_lnum, scope_name
  if use_selection then
    start_lnum = vim.fn.line("'<") - 1
    end_lnum = vim.fn.line("'>")
    scope_name = "selection"
  else
    local warning
    start_lnum, end_lnum, warning = semantic._scope_range(bufnr, opts.scope)
    -- On an unrecognised scope `scope_range` falls back to paragraph, so report paragraph
    -- rather than echoing the bad value back as if it had been honoured.
    scope_name = warning and "paragraph" or (opts.scope or "buffer")
    if warning then
      vim.notify("albertlint: " .. warning, vim.log.levels.WARN)
    end
  end

  local range_lines = vim.api.nvim_buf_get_lines(bufnr, start_lnum, end_lnum, false)
  if #range_lines == 0 or all_blank(range_lines) then
    -- Refused rather than sent. A payload of blank numbered lines costs a paid call and
    -- can only come back empty.
    vim.notify("albertlint: nothing to review in that range", vim.log.levels.INFO)
    return
  end
  local payload = M._numbered(range_lines, start_lnum + 1)

  vim.notify(
    ("albertlint: level %d (%s) over %d lines (%s scope) via %s, ~30-90s. "
      .. "Run again to check progress.")
      :format(def.id, def.name, #range_lines, scope_name, opts.provider),
    vim.log.levels.INFO
  )

  local started = (vim.uv or vim.loop).hrtime()
  local handle = provider.call(opts.provider, prompt, payload, {
    timeout_ms = opts.timeout_ms,
    model = opts.model,
  }, function(res)
    -- Cleared on every path, so a failed, timed-out, or cancelled pass cannot wedge the
    -- guard and lock this buffer out of ever running again.
    in_flight[bufnr] = nil

    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    if not res.ok then
      -- A cancel the writer asked for is not a failure, and cancel() has already said so.
      if cancelled[bufnr] then
        cancelled[bufnr] = nil
        return
      end
      vim.notify(
        ("albertlint: level %d pass failed, so nothing changed. %s"):format(def.id, tostring(res.err)),
        vim.log.levels.ERROR
      )
      return
    end

    -- Cached before presenting, and cached even when nothing placed, so a clean result is
    -- not re-paid for either.
    cache[bufnr] = cache[bufnr] or {}
    cache[bufnr][def.id] = {
      findings = res.findings or {},
      at = (vim.uv or vim.loop).hrtime(),
      provider = opts.provider,
    }

    local placed, dropped = present(bufnr, def, res.findings)

    ---@param msg string
    ---@return string
    local function with_dropped(msg)
      if dropped == 0 then
        return msg
      end
      -- "quote not found" is parser vocabulary. What is actionable is that rerunning
      -- usually places them.
      return msg
        .. (" %d result%s could not be attached, because the text moved or was quoted "
          .. "inexactly; run the check again to place %s.")
          :format(dropped, plural(dropped, "", "s"), plural(dropped, "it", "them"))
    end

    if placed == 0 then
      -- Zero has to read as a verdict, not as a no-op. "0 findings" on its own is
      -- indistinguishable from "the tool did not really run", which misled the author for
      -- a real reason once in the semantic tier, so name the line count and the scope.
      vim.notify(
        with_dropped(("albertlint: level %d found nothing to fix in %d lines (%s scope, %s)."):format(
          def.id, #range_lines, scope_name, elapsed(started)
        )),
        vim.log.levels.INFO
      )
      return
    end

    -- The keys are on the winbar now, so this does not repeat them. It names the one thing
    -- the winbar cannot say: that reopening is free.
    vim.notify(
      with_dropped(("albertlint: level %d, %d fix%s in %d lines (%s scope, %s). "
        .. "Keys are on the winbar. Closing and reopening is free; "
        .. ":AlbertLintLevel%d! forces a fresh pass."):format(
        def.id, placed, plural(placed, "", "es"), #range_lines, scope_name, elapsed(started), def.id
      )),
      vim.log.levels.INFO
    )
  end)

  -- Only recorded when the call actually started. `provider.call` returns nil when the CLI
  -- is missing or the key is unset, and recording those would wedge the guard on a pass
  -- that never ran.
  if handle then
    in_flight[bufnr] = { handle = handle, started = started, lines = #range_lines, level = def.id }
  end
end

---@param bufnr integer|nil
---@return boolean
function M.close(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local source_buf, state = resolve(bufnr)
  if not state then
    vim.notify("albertlint: no level diff open for this buffer", vim.log.levels.INFO)
    return false
  end
  open_views[source_buf] = nil
  diffview.close(state)
  return true
end

---Accept or reject only the line under the cursor, not the whole hunk.
---
---Vim merges adjacent changed lines into a single diff hunk, so two unrelated findings that
---happen to land on consecutive lines become one hunk and `do` takes both. Measured
---2026-09-08: with a Number fix on line 3 and an Article fix on line 4, one `do` applied
---both. That defeats per-finding review, which is the whole point of the diff.
---
---`:.,.diffget` is line-scoped and restores the granularity, verified in the same session.
---Exposed as commands rather than keymaps so nothing is claimed in the user's keyspace
---uninvited; bind them if they earn it.
---@param direction string "get" to accept the correction, "put" to reject it
---@param bufnr integer|nil
---@return boolean
local function line_scoped(direction, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local _, state = resolve(bufnr)
  if not state then
    vim.notify("albertlint: no level diff open for this buffer", vim.log.levels.INFO)
    return false
  end
  if not vim.api.nvim_win_is_valid(state.source_win) then
    vim.notify("albertlint: the window this diff was opened in is gone", vim.log.levels.WARN)
    return false
  end

  -- The command is named accept, so it always moves text INTO the author's buffer no matter
  -- which window it was typed in. `:diffget` modifies the CURRENT buffer, so this has to run
  -- in the source window; run from the corrected side it would overwrite the correction with
  -- the original, which is what `do` itself does there and is why that surprised us.
  --
  -- Line N maps to line N across the two buffers because `apply.build` only ever replaces
  -- spans within a line, never adds or removes one, so the corrected copy has the same line
  -- count. That is what makes taking the cursor's line number across windows safe.
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local ok, err = pcall(vim.api.nvim_win_call, state.source_win, function()
    vim.cmd(("%d,%ddiff%s"):format(lnum, lnum, direction))
  end)
  if not ok then
    -- The usual cause is a cursor that is not on a changed line, which is a normal thing
    -- to do rather than an error worth a stack trace.
    vim.notify(
      ("albertlint: could not take this line (%s). Put the cursor on a changed line; ]c jumps to one.")
        :format(tostring(err):gsub("^.*:%s*", "")),
      vim.log.levels.WARN
    )
    return false
  end
  return true
end

---@param bufnr integer|nil
---@return boolean
function M.accept_line(bufnr)
  return line_scoped("get", bufnr)
end

---@param bufnr integer|nil
---@return boolean
function M.reject_line(bufnr)
  return line_scoped("put", bufnr)
end

---Stop the pass running on this buffer, if any.
---@param bufnr integer|nil
---@return boolean cancelled
function M.cancel(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  -- `in_flight` is keyed by the source buffer, so a cancel typed from the corrected side
  -- has to be mapped back the same way close() does.
  local source_buf = resolve(bufnr)
  bufnr = source_buf or bufnr
  local running = in_flight[bufnr]
  if not running then
    vim.notify("albertlint: no level pass running on this buffer", vim.log.levels.INFO)
    return false
  end
  -- SIGTERM is enough for both backends and leaves them a chance to exit cleanly. The
  -- in-flight record is cleared by the completion callback rather than here, because
  -- killing still delivers one. The handle is nil when the provider never started, and
  -- cancel must still clear the report rather than erroring.
  if running.handle then
    cancelled[bufnr] = true
    pcall(function()
      running.handle:kill("sigterm")
    end)
  end
  in_flight[bufnr] = nil
  vim.notify(
    ("albertlint: level %d pass cancelled after %s"):format(running.level, elapsed(running.started)),
    vim.log.levels.INFO
  )
  return true
end

---Forget the cached findings for a buffer, so the next run pays for a fresh pass.
---@param bufnr integer|nil
---@param id integer|nil Level to forget, or all levels when nil
---@return boolean had_any
function M.clear_cache(bufnr, id)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local per_buf = cache[bufnr]
  if not per_buf then
    return false
  end
  if id == nil then
    cache[bufnr] = nil
    return true
  end
  local had = per_buf[id] ~= nil
  per_buf[id] = nil
  return had
end

-- Cache and in-flight records are keyed by buffer number, and buffer numbers are reused
-- after a delete. Without this, a new buffer can inherit a dead buffer's cached findings
-- and be handed a diff of somebody else's text.
vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
  group = vim.api.nvim_create_augroup("AlbertLintLevelCache", { clear = true }),
  callback = function(ev)
    cache[ev.buf] = nil
    in_flight[ev.buf] = nil
    open_views[ev.buf] = nil
    cancelled[ev.buf] = nil
  end,
})

M._in_flight = in_flight
M._open_views = open_views
M._cache = cache
M._cancelled = cancelled
M._all_blank = all_blank
M._present = present
return M
