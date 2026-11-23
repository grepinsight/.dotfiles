---Buffer-facing layer: visual selection capture, extmark rendering, and persistence.
---
---Extmarks hold the live position of every mark, because Neovim moves them for free as
---the buffer is edited. The stored record holds the durable anchor. The two are kept in
---sync on write, with one rule that matters: an extmark's text is never allowed to
---overwrite `record.text`. Editing inside a marked range leaves the extmark in place but
---makes its text wrong ("bite the bullet" becomes " the bullet"), so trusting it would
---silently corrupt a good anchor into a fragment.
local anchor = require("annotate.anchor")
local config = require("annotate.config")
local store = require("annotate.store")

local M = {}

local NS = vim.api.nvim_create_namespace("annotate")

---@class annotate.BufState
---@field source string Absolute path of the annotated file
---@field marks annotate.Mark[]
---@field ids table<string, integer> mark id -> extmark id
---@field rev table<integer, string> extmark id -> mark id
---@field visible boolean
---@field read_only boolean Set when the store is from a newer format version

---@type table<integer, annotate.BufState>
local state = {}

local seq = 0

---Fields `add_many` accepts through `entry.meta`, for marks this module did not author.
---An allowlist rather than a free-form merge: see `M.add_many`.
local META_FIELDS = {
  author = true,       -- "user" | "llm"
  kind = true,         -- finding class id
  model = true,        -- which model produced it
  analyzer = true,     -- group id plus prompt version
  fingerprint = true,  -- immutable observation identity
  state = true,        -- "active" | "dismissed" | "resolved" | "stale"
}

--- Small helpers -------------------------------------------------------------------

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "annotate" })
end

---ISO 8601 timestamp with a colon in the offset, which `%z` omits.
---@return string
local function timestamp()
  local t = config.get().clock()
  local offset = os.date("%z", t)
  return os.date("%Y-%m-%dT%H:%M:%S", t) .. offset:sub(1, 3) .. ":" .. offset:sub(4)
end

---An allocator of mark ids unique within their file: a timestamp plus a session counter.
---
---Neovim has no UUID in stdlib. A restarted session resets the counter, so ids are checked
---against the ones already in the file rather than assumed unique.
---
---Returns an allocator rather than a single id because the taken-id set is built by
---scanning every existing mark. Doing that per id makes adding N marks quadratic in the
---mark count, which is invisible for a keypress and not for a batch. The allocator scans
---once and records what it mints, so a batch stays linear.
---@param marks annotate.Mark[]
---@return fun(): string
local function id_allocator(marks)
  local taken = {}
  for _, mark in ipairs(marks) do
    taken[mark.id] = true
  end

  -- One timestamp for the whole batch. `seq` disambiguates within it, and sharing the
  -- second is honest: these marks were created by one action.
  local now = config.get().clock()
  return function()
    while true do
      seq = seq + 1
      local candidate = ("%d-%d"):format(now, seq)
      if not taken[candidate] then
        taken[candidate] = true
        return candidate
      end
    end
  end
end

---@param bufnr integer
---@return string[]
local function buf_lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

---Current range of an extmark, or nil when it no longer has one.
---@param bufnr integer
---@param extmark_id integer
---@return table|nil range
local function extmark_range(bufnr, extmark_id)
  local found = vim.api.nvim_buf_get_extmark_by_id(bufnr, NS, extmark_id, { details = true })
  if not found or #found == 0 then
    return nil
  end
  local details = found[3] or {}
  if details.end_row == nil then
    return nil
  end
  return { start = { found[1], found[2] }, ["end"] = { details.end_row, details.end_col } }
end

--- Visual selection ----------------------------------------------------------------

---Read the active visual selection as a 0-indexed range with an exclusive end column.
---
---Reads `getpos("v")` and `getpos(".")` rather than the `'<` / `'>` marks, because those
---marks are only updated when visual mode ends; from inside a visual-mode mapping they
---still describe the *previous* selection.
---@return table|nil range, string|nil err
local function selection()
  local mode = vim.fn.mode()
  if mode == "\22" then
    return nil, "blockwise selection is not supported for annotation; use v or V"
  end
  if mode ~= "v" and mode ~= "V" then
    return nil, "no visual selection active"
  end

  local a = vim.fn.getpos("v")
  local b = vim.fn.getpos(".")
  -- getpos gives 1-indexed line and 1-indexed byte column.
  local start_row, start_col = a[2] - 1, a[3] - 1
  local end_row, end_col = b[2] - 1, b[3] - 1
  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, start_col, end_row, end_col = end_row, end_col, start_row, start_col
  end

  local lines = buf_lines(vim.api.nvim_get_current_buf())
  if end_row >= #lines then
    return nil, "selection extends past the end of the buffer"
  end

  if mode == "V" then
    return { start = { start_row, 0 }, ["end"] = { end_row, #lines[end_row + 1] } }
  end

  -- Charwise visual includes the character under the cursor. Extend past that whole
  -- character rather than a single byte, so a multibyte character is not cut in half.
  local last_line = lines[end_row + 1]
  local char = vim.fn.strpart(last_line, end_col, 1, true)
  local exclusive = math.min(end_col + math.max(#char, 1), #last_line)
  return { start = { start_row, start_col }, ["end"] = { end_row, exclusive } }
end

--- State ---------------------------------------------------------------------------

---Give every record the fields added for machine-authored marks.
---
---Runs here, immediately after `store.read`, and deliberately not in `store.read` and not
---in accessors. `store.read` is annotate's storage boundary and has no business knowing
---about AI fields. Accessors are the wrong place because there are several of them, and one
---missed call site would silently reintroduce the bug this prevents: a record written
---before these fields existed has no `state`, so an exact `state == "active"` render test
---would hide every pre-existing mark. Normalizing once, at the single point where records
---enter memory, makes that equality test safe everywhere downstream.
---
---Absent `author` reads as `"user"`, never as a falsy AI mark, so a store written by any
---earlier version keeps behaving exactly as it did.
---@param marks annotate.Mark[]
local function normalize_records(marks)
  for _, record in ipairs(marks) do
    record.author = record.author or "user"
    record.state = record.state or "active"
  end
end

---@param bufnr integer
---@return annotate.BufState|nil, string|nil err
local function ensure_loaded(bufnr)
  if state[bufnr] then
    return state[bufnr], nil
  end

  local source = vim.api.nvim_buf_get_name(bufnr)
  if source == "" then
    return nil, "this buffer has no file name, so there is nowhere to store marks"
  end

  local marks, err, read_only = store.read(source)
  if err then
    notify(err, vim.log.levels.ERROR)
  end
  normalize_records(marks)

  state[bufnr] = {
    source = store.normalize(source),
    marks = marks,
    ids = {},
    rev = {},
    visible = true,
    read_only = read_only or false,
  }
  return state[bufnr], nil
end

---@param bufnr integer
---@param bufnr integer
---@return boolean ok False when the store was not written
local function persist(bufnr)
  local st = state[bufnr]
  if not st then
    return false
  end
  if st.read_only then
    notify("store is from a newer format version; refusing to write", vim.log.levels.ERROR)
    return false
  end
  local ok, err = store.write(st.source, st.marks)
  if not ok then
    notify(err or "could not write store", vim.log.levels.ERROR)
    return false
  end
  return true
end

--- Rendering ----------------------------------------------------------------------

---@param bufnr integer
---@param st annotate.BufState
---@param record annotate.Mark
---@param range table
local function attach(bufnr, st, record, range)
  local category = config.category(record.category)
  local hl = category and category.hl or "AnnotateNote"
  local opts = {
    end_row = range["end"][1],
    end_col = range["end"][2],
    hl_group = hl,
  }
  if config.get().virtual_text then
    local label = category and category.label or record.category
    if record.note and record.note ~= "" then
      label = label .. ": " .. record.note
    end
    opts.virt_text = { { " " .. label, "AnnotateVirtual" } }
    opts.virt_text_pos = "eol"
  end

  local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, NS, range.start[1], range.start[2], opts)
  st.ids[record.id] = extmark_id
  st.rev[extmark_id] = record.id
end

---@param bufnr integer
---@param st annotate.BufState
---@param record annotate.Mark
local function detach(bufnr, st, record)
  local extmark_id = st.ids[record.id]
  if extmark_id then
    vim.api.nvim_buf_del_extmark(bufnr, NS, extmark_id)
    st.rev[extmark_id] = nil
    st.ids[record.id] = nil
  end
end

---Give every non-orphaned record an extmark, resolving only the ones that lack one.
---
---Existing extmarks are left alone on purpose: they carry positions Neovim has been
---tracking through unsaved edits, which is more accurate than re-resolving against a
---stale stored hint.
---@param bufnr integer
function M.render(bufnr)
  local st = state[bufnr]
  if not st or not st.visible then
    return
  end

  local lines = buf_lines(bufnr)
  for _, record in ipairs(st.marks) do
    -- `state ~= "active"` covers dismissed and resolved machine findings. Detaching rather
    -- than merely skipping matters: a record can be dismissed while it already has an
    -- extmark, and leaving that extmark would keep the highlight on screen after the
    -- author explicitly said no.
    if record.orphaned or record.state ~= "active" then
      detach(bufnr, st, record)
    elseif st.ids[record.id] == nil then
      local range = anchor.resolve(lines, record)
      if range then
        attach(bufnr, st, record, range)
      else
        record.orphaned = true
      end
    end
  end
end

---Drop every extmark and rebuild from the records.
---@param bufnr integer
function M.rebuild(bufnr)
  local st = state[bufnr]
  if not st then
    return
  end
  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  st.ids, st.rev = {}, {}
  M.render(bufnr)
end

--- Load, sync, toggle --------------------------------------------------------------

---Load marks for a buffer and render them. Cheap no-op when no store exists.
---@param bufnr integer
function M.load(bufnr)
  local source = vim.api.nvim_buf_get_name(bufnr)
  if source == "" then
    return
  end
  if state[bufnr] then
    M.render(bufnr)
    return
  end

  local orphans = 0
  local st = ensure_loaded(bufnr)
  if not st then
    return
  end

  local lines = buf_lines(bufnr)
  for _, record in ipairs(st.marks) do
    local range = anchor.resolve(lines, record)
    if range then
      record.orphaned = false
      attach(bufnr, st, record, range)
    else
      record.orphaned = true
      orphans = orphans + 1
    end
  end

  if orphans > 0 then
    notify(("%d mark%s could not be located; see :AnnotateOrphans")
      :format(orphans, orphans == 1 and "" or "s"))
  end
end

---Reconcile records against extmarks after the buffer was written.
---
---An extmark whose text still equals the stored text is authoritative, and its context
---is refreshed. Any other outcome, including the zero-width extmark left behind when the
---marked line is deleted, means the mark must be re-resolved from content and orphaned
---if that fails.
---@param bufnr integer
function M.sync(bufnr)
  local st = state[bufnr]
  if not st then
    return
  end

  local lines = buf_lines(bufnr)
  local context_chars = config.get().context_chars
  local changed = false

  for _, record in ipairs(st.marks) do
    local range = st.ids[record.id] and extmark_range(bufnr, st.ids[record.id]) or nil
    local current = range and anchor.text_at(lines, range) or nil

    if current ~= record.text then
      -- Either the marked text itself was edited or its line is gone. Re-resolve using
      -- the extmark's position as the proximity hint, which is fresher than the stored
      -- one, but never trust its text.
      local probe = vim.tbl_extend("force", record, { hint = range or record.hint })
      range = anchor.resolve(lines, probe)
    end

    if range then
      local rebuilt = anchor.build(lines, range.start, range["end"], context_chars)
      if record.hint == nil
        or rebuilt.hint.start[1] ~= record.hint.start[1]
        or rebuilt.hint.start[2] ~= record.hint.start[2]
        or rebuilt.prefix ~= record.prefix
        or rebuilt.suffix ~= record.suffix
        or record.orphaned
      then
        changed = true
      end
      record.hint = rebuilt.hint
      record.prefix = rebuilt.prefix
      record.suffix = rebuilt.suffix
      record.orphaned = false
    elseif not record.orphaned then
      record.orphaned = true
      changed = true
    end
  end

  if changed then
    persist(bufnr)
  end
  M.rebuild(bufnr)
end

---@param bufnr integer
function M.toggle(bufnr)
  local st = state[bufnr]
  if not st then
    M.load(bufnr)
    return
  end
  if st.visible then
    vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
    st.ids, st.rev = {}, {}
    st.visible = false
    notify("marks hidden")
  else
    st.visible = true
    M.render(bufnr)
    notify("marks shown")
  end
end

---@param bufnr integer
function M.detach_buffer(bufnr)
  state[bufnr] = nil
end

---Point this buffer's marks at its current file name.
---
---`BufState.source` is captured once in `ensure_loaded` and never revisited, and there was
---no `BufFilePost` handler, so after `:saveas other.md` every later write went to the store
---keyed by the ORIGINAL path. The marks then described a file the author was no longer
---editing, and the ones for the file they were editing did not exist.
---
---`:saveas` leaves the original file on disk with its original content, so its store stays
---correct for it and is deliberately left alone. This copies the marks forward to the new
---path rather than moving them: the same content now lives in two places and both
---descriptions are true. A caller wanting a move should delete the old store explicitly.
---@param bufnr integer
---@return boolean retargeted False when there was nothing to do
function M.retarget(bufnr)
  local st = state[bufnr]
  if not st then
    return false
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return false
  end

  local source = store.normalize(name)
  if source == st.source then
    return false
  end

  local previous = st.source
  st.source = source
  -- No `store.index_add` here: `store.write` adds the source only after the write
  -- succeeds, so doing it up front would list a source whose store does not exist.
  if not persist(bufnr) then
    -- Roll back, or the buffer is left pointing at a path it failed to write and the next
    -- successful write lands somewhere the caller was told about but never verified.
    st.source = previous
    return false
  end
  return true
end

--- Mutation -----------------------------------------------------------------------

---Add a mark over an explicit range.
---
---Split out from `M.add` so the buffer layer can be exercised without driving real
---visual mode, which is not reliably reproducible from a script.
---@param bufnr integer
---@param range table { start = {row, col}, ["end"] = {row, col} }
---@param category_name string
---@param note string|nil
---@return annotate.Mark|nil record, string|nil err
function M.add_range(bufnr, range, category_name, note)
  local records, errors =
    M.add_many(bufnr, { { range = range, category = category_name, note = note } })
  if records[1] then
    return records[1], nil
  end
  return nil, errors[1] or "could not add mark"
end

---Add several marks in one pass, persisting once.
---
---`add_range` writes the whole store on every call, which is right for a keypress and
---quadratic for a batch: N marks means N full atomic rewrites (temp file plus rename) on
---top of N taken-id scans. A generated batch of a dozen findings would rewrite the store a
---dozen times. This builds every anchor, attaches every extmark, and writes once.
---
---The filetype gate is hoisted ahead of the loop, because N identical "not enabled for
---filetype" messages is noise when the answer is a single fact about the buffer. One
---consequence worth naming: for a single entry that is BOTH an unknown category AND in a
---disabled filetype, the reported error is now the filetype rather than the category.
---Either is correct and no caller distinguishes them.
---
---Errors are collected rather than fatal, so one bad entry in a batch does not discard the
---good ones. A caller wanting all-or-nothing should validate before calling.
---`entry.meta` carries provenance for machine-authored marks. It is an explicit allowlist
---rather than a free-form merge, so this module's vocabulary stays readable and a typo in a
---caller is a loud error instead of a silently dropped field. An unknown key fails that
---entry: the only way to hit it is a programming mistake, which is exactly when a loud
---failure is worth more than a lenient one.
---@param bufnr integer
---@param entries table[] Each { range = table, category = string, note = string|nil, meta = table|nil }
---@return annotate.Mark[] records Added, in input order, skipping failures
---@return string[] errors One per entry that could not be added
function M.add_many(bufnr, entries)
  if #entries == 0 then
    return {}, {}
  end

  local filetype = vim.bo[bufnr].filetype
  if not config.handles_filetype(filetype) then
    return {}, {
      ("annotate is not enabled for filetype %q; add it to `filetypes` in setup()")
        :format(filetype),
    }
  end

  local st, load_err = ensure_loaded(bufnr)
  if not st then
    return {}, { load_err }
  end

  -- Read the buffer and the config once for the whole batch rather than per entry. Safe
  -- because nothing here modifies the buffer, so every caller-supplied range stays valid.
  local lines = buf_lines(bufnr)
  local context_chars = config.get().context_chars
  local allocate = id_allocator(st.marks)
  local records, errors = {}, {}

  for _, entry in ipairs(entries) do
    local bad_meta = nil
    for key in pairs(entry.meta or {}) do
      if not META_FIELDS[key] then
        bad_meta = key
        break
      end
    end

    if not config.category(entry.category) then
      table.insert(errors, ("unknown category %q"):format(tostring(entry.category)))
    elseif bad_meta then
      table.insert(errors, ("unknown meta field %q"):format(tostring(bad_meta)))
    else
      -- pcall because `anchor.build` indexes the line array directly and throws on a
      -- missing or out-of-buffer range. Without this the documented "one bad entry does
      -- not discard the good ones" contract was false: a single malformed range from a
      -- generated batch aborted the whole call.
      local built, a = pcall(anchor.build, lines, entry.range and entry.range.start,
        entry.range and entry.range["end"], context_chars)
      if not built then
        table.insert(errors, ("unusable range: %s"):format(tostring(a):gsub("^.-:%d+: ", "")))
      elseif a.text == "" then
        table.insert(errors, "selection is empty")
      else
        local record = {
          id = allocate(),
          category = entry.category,
          note = entry.note,
          text = a.text,
          prefix = a.prefix,
          suffix = a.suffix,
          hint = a.hint,
          created_at = timestamp(),
          orphaned = false,
          author = "user",
          state = "active",
        }
        for key in pairs(META_FIELDS) do
          if entry.meta and entry.meta[key] ~= nil then
            record[key] = entry.meta[key]
          end
        end
        table.insert(st.marks, record)
        -- Only active records get an extmark. Attaching one for a record created already
        -- dismissed or resolved would show its highlight until the next rebuild, which is
        -- the opposite of what the state means.
        if record.state == "active" then
          attach(bufnr, st, record, entry.range)
        end
        table.insert(records, record)
      end
    end
  end

  if #records > 0 then
    persist(bufnr)
  end
  return records, errors
end

---Add a mark over the active visual selection.
---
---A category with `prompt = true` asks for note text first. The selection is captured
---before the prompt opens, because visual mode is gone by the time the callback runs.
---@param category_name string
function M.add(category_name)
  local bufnr = vim.api.nvim_get_current_buf()
  local category = config.category(category_name)
  if not category then
    notify(("unknown category %q"):format(category_name), vim.log.levels.ERROR)
    return
  end

  local range, sel_err = selection()
  -- Leave visual mode so the highlight is visible immediately and the prompt is clean.
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)

  if not range then
    notify(sel_err or "no selection", vim.log.levels.WARN)
    return
  end

  local function commit(note)
    local record, err = M.add_range(bufnr, range, category_name, note)
    if not record then
      notify(err or "could not add mark", vim.log.levels.ERROR)
      return
    end
    local preview = record.text:gsub("\n", " ")
    if #preview > 50 then
      preview = preview:sub(1, 47) .. "..."
    end
    notify(("%s: %s"):format(category.label, preview))
  end

  if category.prompt then
    vim.ui.input({ prompt = category.label .. ": " }, function(value)
      if value == nil then
        return -- cancelled
      end
      commit(value ~= "" and value or nil)
    end)
  else
    commit(nil)
  end
end

---Expose the selection reader for tests.
M._selection = selection

---The mark whose range contains the cursor, preferring the innermost one.
---@param bufnr integer
---@return annotate.Mark|nil
function M.at_cursor(bufnr)
  local st = state[bufnr]
  if not st then
    return nil
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]
  local found = vim.api.nvim_buf_get_extmarks(bufnr, NS, { row, 0 }, { row, -1 }, {
    details = true,
    overlap = true,
  })

  local best, best_size
  for _, entry in ipairs(found) do
    local extmark_id, start_row, start_col = entry[1], entry[2], entry[3]
    local details = entry[4] or {}
    local end_row, end_col = details.end_row, details.end_col
    if end_row ~= nil then
      local after_start = row > start_row or (row == start_row and col >= start_col)
      local before_end = row < end_row or (row == end_row and col < end_col)
      if after_start and before_end then
        local size = (end_row - start_row) * 10000 + (end_col - start_col)
        if best == nil or size < best_size then
          best, best_size = extmark_id, size
        end
      end
    end
  end

  if not best then
    return nil
  end
  local mark_id = st.rev[best]
  for _, record in ipairs(st.marks) do
    if record.id == mark_id then
      return record
    end
  end
  return nil
end

---@param bufnr integer
function M.delete_at_cursor(bufnr)
  if not state[bufnr] then
    M.load(bufnr)
  end
  local st = state[bufnr]
  local record = M.at_cursor(bufnr)
  if not record then
    notify("no mark under the cursor", vim.log.levels.WARN)
    return
  end

  detach(bufnr, st, record)
  for i, candidate in ipairs(st.marks) do
    if candidate.id == record.id then
      table.remove(st.marks, i)
      break
    end
  end
  persist(bufnr)
  notify("mark deleted")
end

---Dismiss the mark under the cursor instead of deleting it.
---
---Deliberately separate from `delete_at_cursor`, which keeps deleting outright. The two
---differ in what has to survive: deleting the author's own mark should leave nothing, while
---dismissing a machine finding must leave a record behind, because that record is what
---stops the next pass raising the same finding again. A dismissal that deleted would be
---undone within seconds.
---
---Refuses to dismiss a user mark. Dismissal is meaningless for one: there is no generator
---to suppress, and the author's own annotation should be deleted or edited, not silenced.
---@param bufnr integer
---@return boolean dismissed
function M.dismiss_at_cursor(bufnr)
  if not state[bufnr] then
    M.load(bufnr)
  end
  local st = state[bufnr]
  local record = M.at_cursor(bufnr)
  if not record then
    notify("no mark under the cursor", vim.log.levels.WARN)
    return false
  end
  if record.author ~= "llm" then
    notify("only machine findings can be dismissed; use delete for your own marks", vim.log.levels.WARN)
    return false
  end
  if record.state == "dismissed" then
    notify("already dismissed")
    return false
  end

  record.state = "dismissed"
  detach(bufnr, st, record)
  persist(bufnr)
  notify("finding dismissed")
  return true
end

---@param bufnr integer
function M.note_at_cursor(bufnr)
  if not state[bufnr] then
    M.load(bufnr)
  end
  local st = state[bufnr]
  local record = M.at_cursor(bufnr)
  if not record then
    notify("no mark under the cursor", vim.log.levels.WARN)
    return
  end

  vim.ui.input({ prompt = "note: ", default = record.note or "" }, function(value)
    if value == nil then
      return
    end
    record.note = value ~= "" and value or nil
    -- The note is rendered as virtual text, so the extmark must be recreated.
    detach(bufnr, st, record)
    local range = anchor.resolve(buf_lines(bufnr), record)
    if range then
      attach(bufnr, st, record, range)
    end
    persist(bufnr)
    notify(record.note and "note saved" or "note cleared")
  end)
end

--- Accessors ----------------------------------------------------------------------

---@param bufnr integer
---@return annotate.BufState|nil
function M.state(bufnr)
  return state[bufnr]
end

---@return integer
function M.namespace()
  return NS
end

---Test-only: forget all buffer state.
function M.reset()
  for bufnr in pairs(state) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
    end
  end
  state = {}
  seq = 0
end

return M
