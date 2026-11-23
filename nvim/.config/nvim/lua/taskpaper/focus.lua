---The app's Focus In, Focus Out, and Go Home.
---
---A projection rather than folds, for the reasons in IMPLEMENTATION_PLAN.md stage 5: a
---closed fold always keeps a summary row, so folding cannot actually hide the rest of
---the file, and fold state is window-local so the same buffer in two windows has two of
---them. nvim-ufo owns the folds here anyway and re-applies them on every change, so a
---fold this module created would not survive the next keystroke.
---
---It departs from that plan in one way, deliberately: the view is **editable** and
---writes back. Focus in the app is a working mode, not a reading mode, and a read-only
---view of one project is useless for the thing a task file is for. What makes that
---affordable is that a focused range is *contiguous*, so write-back is one
---`nvim_buf_set_lines` over the source's slice. The plan's warning that "identity is
---the hard part" was about the search filter, where the visible set is scattered and a
---line number really is the only handle. It does not apply to a subtree.
---
---The source is never written to disk here. Write-back edits the source *buffer*, and
---`:w` in the view then writes the source the way `:w` always does.

local outline = require("taskpaper.outline")

local M = {}

---@class TaskPaperFocus
---@field src integer Source buffer.
---@field first integer First source line the view holds.
---@field last integer Last source line the view holds.
---@field root integer Source line of the focused item.
---@field tick integer Source changedtick as of the last agreed-on state.

---@type table<integer, integer> view buffer per source buffer
local views = {}
---@type table<integer, TaskPaperFocus>
local state = {}

---@param bufnr integer
---@return integer
local function shiftwidth_of(bufnr)
  local sw = vim.bo[bufnr].shiftwidth
  -- 'shiftwidth' of 0 means "use 'tabstop'", and outline.level would read the 0 as a
  -- space-run length of zero and loop forever on a space-indented line.
  if sw == 0 then
    return vim.bo[bufnr].tabstop
  end
  return sw
end

---Copy the view's lines back over the source's slice.
---
---Refuses when the source moved for any reason other than our own last write. `first`
---and `last` are source line numbers, so an edit from another window makes them point
---at the wrong text, and writing anyway would overwrite whatever now sits there. The
---caller is expected to stop when this returns false, which leaves the view on screen
---with the user's edit still in it.
---
---`quiet` is for the callers where a refusal is not news: the BufLeave sync, which runs
---on every window switch, and a forced Go Home, where the user has already said to
---discard. Speaking there warns twice about the thing that was just asked for.
---@param view integer
---@param quiet boolean|nil
---@return boolean
local function sync(view, quiet)
  local st = state[view]
  if st == nil or not vim.api.nvim_buf_is_valid(st.src) then
    return false
  end
  if vim.api.nvim_buf_get_changedtick(st.src) ~= st.tick then
    if not quiet then
      vim.notify(
        "taskpaper: the source buffer changed underneath this view, so it was not written back",
        vim.log.levels.WARN
      )
    end
    return false
  end

  local new = vim.api.nvim_buf_get_lines(view, 0, -1, false)
  local old = vim.api.nvim_buf_get_lines(st.src, st.first - 1, st.last, false)
  -- Writing identical lines still bumps changedtick and sets 'modified', so focusing
  -- and going home without typing anything would leave the file looking edited.
  if not vim.deep_equal(old, new) then
    vim.api.nvim_buf_set_lines(st.src, st.first - 1, st.last, false, new)
    st.last = st.first + #new - 1
    st.tick = vim.api.nvim_buf_get_changedtick(st.src)
  end
  vim.bo[view].modified = false
  return true
end

---@param src integer
---@return integer
local function view_for(src)
  local view = views[src]
  if view ~= nil and vim.api.nvim_buf_is_valid(view) then
    return view
  end

  view = vim.api.nvim_create_buf(false, true)
  views[src] = view
  -- acwrite rather than nofile: `:w` in the view should mean "write the file this came
  -- from", and BufWriteCmd is the only hook that gets to define that.
  vim.bo[view].buftype = "acwrite"
  vim.bo[view].swapfile = false

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = view,
    callback = function()
      if sync(view) then
        vim.api.nvim_buf_call(state[view].src, function()
          vim.cmd("write")
        end)
      end
    end,
  })

  -- Leaving the view is an exit path like any other, and an edit that is only in the
  -- view is an edit that is nowhere. This writes the source buffer, not the file, so it
  -- loses nothing the user has not already typed.
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = view,
    callback = function()
      sync(view, true)
    end,
  })

  return view
end

---@param src integer
---@param root integer Source line of the item to focus.
---@param sw integer
---@param at integer|nil Source line to put the cursor on. Defaults to `root`.
local function show(src, root, sw, at)
  local lines = vim.api.nvim_buf_get_lines(src, 0, -1, false)
  local first, last = outline.subtree(lines, root, sw)
  local view = view_for(src)

  state[view] = {
    src = src,
    first = first,
    last = last,
    root = root,
    tick = vim.api.nvim_buf_get_changedtick(src),
  }

  vim.api.nvim_buf_set_lines(view, 0, -1, false, vim.list_slice(lines, first, last))
  vim.bo[view].modified = false
  vim.bo[view].filetype = "taskpaper"
  local name = ("taskpaper://%d/%s"):format(src, vim.trim(lines[root]))
  -- pcall: two sources can hold projects with the same heading, and a name collision
  -- is not a reason to refuse to focus.
  pcall(vim.api.nvim_buf_set_name, view, name)

  vim.api.nvim_win_set_buf(0, view)
  local lnum = math.min(math.max((at or root) - first + 1, 1), last - first + 1)
  vim.api.nvim_win_set_cursor(0, { lnum, 0 })
end

---Where the cursor is, in source coordinates, or nil when the view is stale.
---@return integer|nil src
---@return integer|nil lnum
local function cursor_in_source()
  local cur = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local st = state[cur]
  if st == nil then
    return cur, lnum
  end
  if not sync(cur) then
    return nil, nil
  end
  return st.src, st.first + lnum - 1
end

---The app's Focus In: show the item the cursor is in, and nothing else.
---
---Called from inside a view it narrows again, which is how walking down a nesting works.
---That is why the cursor line is translated back into source coordinates first rather
---than used as given.
---
---The unit is the item rather than the project. Asking for the enclosing *project* made
---a nested list unfocusable, since a task's nearest project is the top-level heading
---however deep the task sits; see outline.enclosing_item.
function M.focus_in()
  local src, lnum = cursor_in_source()
  if src == nil then
    return
  end

  local sw = shiftwidth_of(src)
  local lines = vim.api.nvim_buf_get_lines(src, 0, -1, false)
  local root = outline.enclosing_item(lines, lnum, sw)
  if root == nil then
    vim.notify("taskpaper: nothing to focus here", vim.log.levels.WARN)
    return
  end
  show(src, root, sw, lnum)
end

---The app's Focus Out: widen to the item containing the focused one.
---
---No parent means there is nothing wider than what is on screen, and the next step out
---from there is the whole file, so it goes home rather than doing nothing. Item-based
---like Focus In, so the two form a ladder: out of a deep list to its parent list, out of
---that to the project, out of that to home.
function M.focus_out()
  local view = vim.api.nvim_get_current_buf()
  local st = state[view]
  if st == nil or not sync(view) then
    return
  end

  local sw = shiftwidth_of(st.src)
  local lines = vim.api.nvim_buf_get_lines(st.src, 0, -1, false)
  local parent = outline.parent(lines, st.root, sw)
  if parent == nil then
    return M.home()
  end
  show(st.src, parent, sw)
end

---The app's Go Home: the whole file again, with the cursor on the item just left.
---
---Leaving is not the same as writing, and conflating the two trapped the view: a source
---edited from another window makes the write-back refuse, and refusing to *leave* as
---well left a buffer whose only exit was `:bd!`. So a view with nothing unwritten in it
---goes home quietly even when it is stale, since it has nothing to lose, and one that
---does hold an edit needs `force` -- the bargain `:q` and `:q!` already make. Rebuilding
---the view from the moved source is not on the menu: `root` is a line number, and a
---source that shifted underneath is exactly the case where it no longer means anything.
---@param force boolean|nil Leave even when the edit cannot be written back.
function M.home(force)
  local view = vim.api.nvim_get_current_buf()
  local st = state[view]
  if st == nil then
    return
  end
  -- A clean view has nothing to write, so it never reaches sync and never warns. A
  -- forced one still tries, because the bang means "discard if you must", not "discard":
  -- an edit that can still be written back should be.
  if vim.bo[view].modified and not sync(view, force) and not force then
    vim.notify(
      "taskpaper: :TaskPaperHome! leaves this view and discards the edit",
      vim.log.levels.WARN
    )
    return
  end

  if vim.api.nvim_buf_is_valid(st.src) then
    vim.api.nvim_win_set_buf(0, st.src)
    local count = vim.api.nvim_buf_line_count(st.src)
    vim.api.nvim_win_set_cursor(0, { math.min(st.root, count), 0 })
  end

  state[view] = nil
  views[st.src] = nil
  if vim.api.nvim_buf_is_valid(view) then
    vim.api.nvim_buf_delete(view, { force = true })
  end
end

---@param bufnr integer|nil Defaults to the current buffer.
---@return TaskPaperFocus|nil
function M.state(bufnr)
  return state[bufnr or vim.api.nvim_get_current_buf()]
end

return M
