---The two-window diff that renders a level pass.
---
---Native diff mode rather than a hand-built review buffer, deliberately: `]c`, `[c`, `do`,
---and `dp` already are hunk navigation and per-hunk accept and reject, so there is no apply
---code here to get wrong, and the author's existing diff habits transfer unchanged.
---
---The one non-obvious part is the mirrored blank virtual lines. Diff mode aligns two windows
---with filler lines it computes itself, while `virt_lines` add screen rows to one window
---only. Measured 2026-09-08 on a five-line pair with a single one-line note on the right
---buffer: line 3 sat at screen row 4 on the right and row 3 on the left, so every line below
---the note was out of alignment. Emitting an equal count of blank virtual lines on the other
---side restores it exactly.
---
---The blanks look like dead code. They are not, and a test measures the alignment directly
---rather than only counting them.
local apply = require("albertlint.level.apply")

local M = {}

---Width the note wraps to. Sized for a vertical split on a normal terminal rather than for
---the full window, since in diff mode each window holds roughly half the columns.
local NOTE_WIDTH = 64

---@class LevelDiffState
---@field source_buf integer
---@field scratch_buf integer
---@field source_win integer
---@field scratch_win integer
---@field ns integer
---@field count integer
---@field closed boolean

---@param bufnr integer
---@param corrected string[] The WHOLE buffer with the reviewed range corrected
---@param placed table[] { fix, lnum (1-indexed), col }
---@param opts table|nil { level }
---@return LevelDiffState
function M.open(bufnr, corrected, placed, opts)
  opts = opts or {}
  local ns = vim.api.nvim_create_namespace("albertlint_level")
  local source_win = vim.api.nvim_get_current_win()

  local scratch = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(scratch, 0, -1, false, corrected)
  vim.bo[scratch].buftype = "nofile"
  vim.bo[scratch].swapfile = false
  -- Same filetype as the source, so the corrected side gets the same syntax highlighting
  -- and the diff reads as prose rather than as plain text.
  vim.bo[scratch].filetype = vim.bo[bufnr].filetype
  local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
  pcall(
    vim.api.nvim_buf_set_name,
    scratch,
    ("albertlint://level%d/%s"):format(opts.level or 1, name == "" and "buffer" or name)
  )

  vim.cmd("vertical rightbelow split")
  local scratch_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(scratch_win, scratch)

  -- `diffthis` per window rather than `:windo diffthis`, so no other window in the tab is
  -- dragged into diff mode.
  vim.api.nvim_win_call(scratch_win, function()
    vim.cmd("diffthis")
  end)
  vim.api.nvim_win_call(source_win, function()
    vim.cmd("diffthis")
  end)

  -- Saved so close() can put back exactly what was here. `diffoff` restores the options
  -- diff mode itself changed, but not the ones set below it.
  local saved = {}
  for _, win in ipairs({ source_win, scratch_win }) do
    saved[win] = {
      foldenable = vim.wo[win].foldenable,
      foldcolumn = vim.wo[win].foldcolumn,
      winbar = vim.wo[win].winbar,
    }
  end

  for _, win in ipairs({ source_win, scratch_win }) do
    -- Diff mode turns on `foldmethod=diff` with `foldlevel=0`, which collapses every
    -- unchanged region. Measured 2026-09-08 on a 25-line pair with two changes: 5 lines
    -- hidden inside closed folds. For prose that is the wrong default, because the
    -- surrounding sentences are exactly the context needed to judge an article or a
    -- referent, so the thing being reviewed is the thing that gets folded away.
    vim.wo[win].foldenable = false
    -- With folding off the 2-column fold gutter is dead width. Set on BOTH windows, so it
    -- stays symmetric and cannot shift the columns of one side relative to the other.
    vim.wo[win].foldcolumn = "0"
  end

  -- The key hints live on a winbar, and it has to be on BOTH windows. Measured 2026-09-08:
  -- a winbar on the corrected side alone misaligned all 25 lines of the sample, which is
  -- the same failure mode as a one-sided `virt_lines`. Mirrored, 0 misaligned. The left
  -- label is not decoration; it is the mirror that keeps the rows lined up.
  vim.wo[source_win].winbar = "%#DiffText#  YOURS %#Comment#  (edits land here)"
  vim.wo[scratch_win].winbar = table.concat({
    ("%%#DiffAdd#  LEVEL %d %%#Comment#"):format(opts.level or 1),
    "  ]c next",
    "  do accept",
    "  dp reject",
    "  :AlbertLintLevelAccept one line",
    "  :AlbertLintLevelClose",
  })

  local count = 0
  for _, item in ipairs(placed or {}) do
    local row = item.lnum - 1
    local note = apply.note_lines(item.fix.label or "", item.fix.note or "", NOTE_WIDTH)

    local virt, blanks = {}, {}
    for _, text in ipairs(note) do
      table.insert(virt, { { "  " .. text, "Comment" } })
      -- One blank per note line. This COUNT, not the text, is what preserves alignment.
      table.insert(blanks, { { "", "Comment" } })
    end

    local ok_scratch = pcall(vim.api.nvim_buf_set_extmark, scratch, ns, row, 0, {
      virt_lines = virt,
      virt_lines_above = true,
    })
    local ok_source = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, 0, {
      virt_lines = blanks,
      virt_lines_above = true,
    })
    if ok_scratch and ok_source then
      count = count + 1
    else
      -- All or nothing per finding. A note on one side without its mirror is worse than
      -- no note, because it silently misaligns the diff the author is reading.
      pcall(vim.api.nvim_buf_clear_namespace, scratch, ns, row, row + 1)
      pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns, row, row + 1)
    end
  end

  -- Land in the SOURCE window, not the corrected one, and this is not a preference.
  -- `:diffget` modifies the CURRENT buffer, so `do` pressed in the scratch window
  -- overwrites the correction with the original: the exact opposite of accept, while the
  -- winbar says "do accept". Verified 2026-09-08 by pressing it -- the scratch line
  -- reverted and the source line did not change at all. Leaving the cursor there made the
  -- primary action of this feature do the reverse of what it advertised.
  vim.api.nvim_set_current_win(source_win)
  pcall(vim.api.nvim_win_set_cursor, source_win, { 1, 0 })
  vim.api.nvim_win_call(source_win, function()
    -- `]c` from a line that is ALREADY a change jumps to the next one, skipping the first
    -- hunk entirely, so only jump when line 1 is unchanged.
    if vim.fn.diff_hlID(1, 1) == 0 then
      pcall(vim.cmd, "normal! ]c")
    end
  end)

  ---@type LevelDiffState
  local state = {
    source_buf = bufnr,
    scratch_buf = scratch,
    source_win = source_win,
    scratch_win = scratch_win,
    ns = ns,
    count = count,
    closed = false,
    saved = saved,
  }

  -- Teardown on any route out, not only the close command. Without this, closing the
  -- scratch buffer by a path this plugin does not own leaves the real buffer stuck in diff
  -- mode, which reads as a broken editor rather than as a leftover.
  --
  -- `bufhidden` is deliberately NOT set to "wipe": that fires BufWipeout during the
  -- window teardown inside close(), which re-enters this callback mid-teardown.
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
    buffer = scratch,
    once = true,
    callback = function()
      M.close(state)
    end,
  })

  return state
end

---@param state LevelDiffState|nil
---@return boolean closed True if this call did the teardown
function M.close(state)
  if not state or state.closed then
    return false
  end
  -- Set before doing any work, so the BufWipeout autocmd firing during the buffer delete
  -- below re-enters here and returns immediately instead of recursing.
  state.closed = true

  for _, win in ipairs({ state.source_win, state.scratch_win }) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_call(win, function()
        pcall(vim.cmd, "diffoff")
      end)
      -- Put back what was here before. `diffoff` restores the options diff mode set
      -- itself, but not `foldenable`, `foldcolumn`, or `winbar`, which this module set on
      -- top of it. Leaving a winbar behind on the author's real buffer would be a visible
      -- leftover, and leaving folding disabled would silently change an unrelated setting.
      local was = (state.saved or {})[win]
      if was then
        pcall(function()
          vim.wo[win].foldenable = was.foldenable
          vim.wo[win].foldcolumn = was.foldcolumn
          vim.wo[win].winbar = was.winbar
        end)
      end
    end
  end

  for _, buf in ipairs({ state.source_buf, state.scratch_buf }) do
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_clear_namespace, buf, state.ns, 0, -1)
    end
  end

  if vim.api.nvim_buf_is_valid(state.scratch_buf) then
    pcall(vim.api.nvim_buf_delete, state.scratch_buf, { force = true })
  end

  return true
end

M._NOTE_WIDTH = NOTE_WIDTH
return M
