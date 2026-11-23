---Browse marks across every annotated file and jump to one.
---
---Uses Telescope when it is loadable and falls back to `vim.ui.select`, so the module
---does not hard-depend on a plugin that is lazy-loaded on `:Telescope` in this config.
local anchor = require("annotate.anchor")
local config = require("annotate.config")
local marks = require("annotate.marks")
local store = require("annotate.store")

local M = {}

---@class annotate.PickerEntry
---@field source string
---@field mark annotate.Mark
---@field display string
---@field ordinal string

---@param mark annotate.Mark
---@return integer row 1-indexed, for display
local function display_row(mark)
  local hint = mark.hint and mark.hint.start
  return (hint and hint[1] or 0) + 1
end

---@param opts table|nil { orphans_only?: boolean, source?: string }
---@return annotate.PickerEntry[]
function M.entries(opts)
  opts = opts or {}
  local sources = opts.source and { store.normalize(opts.source) } or store.list_sources()

  local out = {}
  for _, source in ipairs(sources) do
    for _, mark in ipairs(store.read(source)) do
      local include = opts.orphans_only and mark.orphaned or not opts.orphans_only
      if include then
        local category = config.category(mark.category)
        local label = category and category.label or mark.category
        local phrase = mark.text:gsub("%s+", " ")
        if #phrase > 60 then
          phrase = phrase:sub(1, 57) .. "..."
        end
        local name = vim.fn.fnamemodify(source, ":t")
        local flag = mark.orphaned and " [orphaned]" or ""
        local note = (mark.note and mark.note ~= "") and ("  (" .. mark.note:gsub("%s+", " ") .. ")") or ""

        table.insert(out, {
          source = source,
          mark = mark,
          display = ("%-18s %s%s  %s:%d%s"):format("[" .. label .. "]", phrase, note, name, display_row(mark), flag),
          ordinal = table.concat({ label, phrase, mark.note or "", name }, " "),
        })
      end
    end
  end

  table.sort(out, function(a, b)
    if a.source ~= b.source then
      return a.source < b.source
    end
    return display_row(a.mark) < display_row(b.mark)
  end)
  return out
end

---Open the entry's file and put the cursor on the mark.
---@param entry annotate.PickerEntry
function M.jump(entry)
  if entry == nil then
    return
  end

  vim.cmd("edit " .. vim.fn.fnameescape(entry.source))
  local bufnr = vim.api.nvim_get_current_buf()
  marks.load(bufnr)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local range = anchor.resolve(lines, entry.mark)
  if range then
    vim.api.nvim_win_set_cursor(0, { range.start[1] + 1, range.start[2] })
    vim.cmd("normal! zz")
    return
  end

  -- Orphaned: the text is not in the file any more, so the stored row is only a hint.
  -- Land near it rather than refusing to move, and say why.
  local row = math.min(display_row(entry.mark), #lines)
  vim.api.nvim_win_set_cursor(0, { math.max(row, 1), 0 })
  vim.notify(
    ("this mark could not be located; showing its last known position (looking for %q)")
      :format(entry.mark.text:gsub("%s+", " ")),
    vim.log.levels.WARN,
    { title = "annotate" }
  )
end

---@param entries annotate.PickerEntry[]
---@param title string
local function select_fallback(entries, title)
  vim.ui.select(entries, {
    prompt = title,
    format_item = function(entry)
      return entry.display
    end,
  }, function(choice)
    M.jump(choice)
  end)
end

---@param entries annotate.PickerEntry[]
---@param title string
---@return boolean handled
local function select_telescope(entries, title)
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    return false
  end
  local finders = require("telescope.finders")
  local telescope_config = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers
    .new({}, {
      prompt_title = title,
      finder = finders.new_table({
        results = entries,
        entry_maker = function(entry)
          return { value = entry, display = entry.display, ordinal = entry.ordinal }
        end,
      }),
      sorter = telescope_config.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selected = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selected then
            M.jump(selected.value)
          end
        end)
        return true
      end,
    })
    :find()
  return true
end

---@param opts table|nil { orphans_only?: boolean, source?: string }
function M.list(opts)
  opts = opts or {}
  local entries = M.entries(opts)
  if #entries == 0 then
    vim.notify(
      opts.orphans_only and "no orphaned marks" or "no marks yet",
      vim.log.levels.INFO,
      { title = "annotate" }
    )
    return
  end

  local title = opts.orphans_only and "Orphaned annotations" or "Annotations"
  if not select_telescope(entries, title) then
    select_fallback(entries, title)
  end
end

return M
