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

---How long to allow, scaled to how much text is being sent.
---
---A fixed timeout cannot serve both a paragraph and a whole note, and the shipped 90s was
---sized against 4-line samples. Measured 2026-09-08 through this module's own code path:
---
---    4 lines   22, 26, 35, 38, 53s   across six runs
---   12 lines   22-27s
---  190 lines   105.6s                <- exceeded the 90s default and was killed mid-answer
---
---That last run succeeded on the model's side, returning 74 findings, and was then thrown
---away by the timeout. Roughly 25s of fixed overhead plus 0.42s per line, so this allows 30s
---plus 0.75s per line.
---
---The floor is 120s rather than 90s because of the variance in that first row: the same
---four-line input ranged from 22s to 53s, so a budget sized on the median clips a slow run.
---Erring long is close to free here and erring short is not, since a timeout discards an
---answer the model already finished paying for.
---
---The ceiling is a deliberate refusal rather than a limit of the model: past ten minutes the
---right answer is a narrower scope, not a longer wait, and the timeout message says so.
---@param line_count integer
---@return integer milliseconds
local function timeout_for(line_count)
  local ms = math.floor((30 + 0.75 * line_count) * 1000)
  return math.max(120000, math.min(600000, ms))
end

---Open the diff from findings, whether they just arrived or came from the cache.
---@param bufnr integer
---@param def table
---@param findings table[]
---@return integer placed, integer dropped
local function present(bufnr, def, findings, lines, view)
  -- The WHOLE buffer, not the reviewed range: the scratch copy is diffed against the real
  -- buffer, and a range-only array would make every untouched line outside the range read
  -- as a deletion.
  --
  -- `lines` is the snapshot taken when the panel opened, which under the blocking flow is
  -- the buffer verbatim. The cache path passes the buffer as it is now instead.
  lines = lines or vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local corrected, placed, dropped = apply.build(lines, 1, findings or {})
  if #placed == 0 then
    return 0, #dropped
  end
  if view then
    diffview.populate(view, corrected, placed)
  else
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
    local msg = ("albertlint: level %d, %d fix%s from cache (%s old), :AlbertLintLevel%d! re-runs")
      :format(def.id, placed, plural(placed, "", "es"), age, def.id)
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

  -- An explicit `timeout_ms` in config wins; nil means scale it to the payload. Declared
  -- BEFORE the notify that prints it: with the declaration below, `timeout_ms` in the
  -- notify resolved to a nil global and `:AlbertLintLevel1` died with "attempt to perform
  -- arithmetic on global 'timeout_ms'" before it ever reached the provider. Reported from a
  -- real session 2026-09-08.
  local timeout_ms = opts.timeout_ms or timeout_for(#range_lines)

  -- One short line. The previous version listed the budget, a measurement and an
  -- instruction, wrapped past the cmdline, and triggered a hit-enter prompt that blocked
  -- the writer in order to tell them about progress. Seen in a screenshot 2026-09-08.
  -- The waiting state lives on the winbar instead, where it costs nothing.
  vim.notify(
    ("albertlint: level %d over %d lines, up to %ds"):format(def.id, #range_lines, timeout_ms / 1000),
    vim.log.levels.INFO
  )

  -- Open the panel BEFORE the call, then block until it answers. Two reasons, and the
  -- second is a correctness one.
  --
  -- Asynchronous, the pass finished into whatever the buffer had become. Measured
  -- 2026-09-08: a line inserted above a finding made its quote unfindable, so the fix was
  -- silently dropped -- and worse, when the same quote happened to sit at that line number
  -- afterwards, the fix applied to a DIFFERENT sentence. The safety was probabilistic.
  -- Blocking makes the snapshot below equal to the buffer by construction.
  --
  -- `vim.wait` blocks the main loop but keeps pumping the event loop, so the provider's
  -- callback still fires and Ctrl-C still interrupts. A truly synchronous wait would freeze
  -- the editor with no way out.
  local snapshot = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local view = diffview.open(bufnr, snapshot, {}, { level = def.id, pending = true })
  open_views[bufnr] = view
  vim.cmd("redraw")

  local answer
  local started = (vim.uv or vim.loop).hrtime()
  local handle = provider.call(opts.provider, prompt, payload, {
    timeout_ms = timeout_ms,
    model = opts.model,
  }, function(res)
    answer = res
  end)

  if handle then
    in_flight[bufnr] = { handle = handle, started = started, lines = #range_lines, level = def.id }
  end

  -- +2s so the provider's own timeout fires first and reports itself, rather than this
  -- giving up and leaving the process running.
  local completed = vim.wait(timeout_ms + 2000, function() return answer ~= nil end, 100)
  in_flight[bufnr] = nil

  if not completed then
    -- Either Ctrl-C or the wait elapsing. Kill the process either way: leaving it running
    -- would deliver an answer into a torn-down view.
    if handle then
      pcall(function() handle:kill("sigterm") end)
    end
    M.close(bufnr)
    vim.notify(
      ("albertlint: level %d aborted after %s"):format(def.id, elapsed(started)),
      vim.log.levels.WARN
    )
    return
  end

  do
    local res = answer

    if not vim.api.nvim_buf_is_valid(bufnr) then
      M.close(bufnr)
      return
    end
    if not res.ok then
      -- Tear the pending panel down: it shows an empty diff and would sit there looking
      -- like a result.
      M.close(bufnr)
      -- A cancel the writer asked for is not a failure, and cancel() has already said so.
      if cancelled[bufnr] then
        cancelled[bufnr] = nil
        return
      end
      vim.notify(
        ("albertlint: level %d failed, nothing changed. %s"):format(def.id, tostring(res.err)),
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

    local placed, dropped = present(bufnr, def, res.findings, snapshot, view)

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
      -- Nothing to review, so the panel goes away rather than sitting there as an empty
      -- diff that looks like a result.
      M.close(bufnr)
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

    -- Deliberately short. The keys are on the winbar, and a notify long enough to repeat
    -- them wraps past the cmdline and triggers the hit-enter prompt, which is what was
    -- interrupting the writer to tell them the tool would not interrupt them.
    vim.notify(
      with_dropped(("albertlint: level %d, %d fix%s in %d lines (%s)"):format(
        def.id, placed, plural(placed, "", "es"), #range_lines, elapsed(started)
      )),
      vim.log.levels.INFO
    )
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
M._timeout_for = timeout_for
M._present = present
return M
