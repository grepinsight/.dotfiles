---The app's Move menu, wired to a buffer.
---
---Thin on purpose: every decision about where a subtree ends and where it lands is in
---taskpaper.outline, which has no vim.api in it. What is left here is reading the
---buffer, writing the smallest span that changed, and putting the cursor back on the
---item the user was moving.

local outline = require("taskpaper.outline")

local M = {}

---@param bufnr integer
---@return string
local function indent_unit(bufnr)
  if vim.bo[bufnr].expandtab then
    return string.rep(" ", vim.fn.shiftwidth())
  end
  return "\t"
end

---Apply a pure outline operation to the current buffer.
---@param apply fun(lines: string[], lnum: integer, unit: string, sw: integer): string[]|nil, integer|nil
---@param lnum integer|nil Defaults to the cursor line.
---@return boolean moved false when the operation was not available
local function rewrite(apply, lnum)
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  lnum = lnum or cursor[1]
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local out, moved_to = apply(lines, lnum, indent_unit(bufnr), vim.fn.shiftwidth())
  if out == nil then
    return false
  end
  local first, last = outline.changed_span(lines, out)
  if first == nil then
    return false
  end
  vim.api.nvim_buf_set_lines(bufnr, first - 1, last, false, vim.list_slice(out, first, last))
  -- The column is clamped rather than kept, because an outdent can leave the old column
  -- past the end of the line.
  local target = moved_to or lnum
  local width = #(out[target] or "")
  vim.api.nvim_win_set_cursor(0, { target, math.min(cursor[2], math.max(width - 1, 0)) })
  return true
end

---@param delta integer
local function shift(delta)
  return rewrite(function(lines, lnum, unit, sw)
    return outline.shift(lines, lnum, delta, unit, sw)
  end)
end

function M.right()
  return shift(1)
end

function M.left()
  return shift(-1)
end

---@param dir "up"|"down"
local function move(dir)
  return rewrite(function(lines, lnum, _, sw)
    return outline.move(lines, lnum, dir, sw)
  end)
end

function M.up()
  return move("up")
end

function M.down()
  return move("down")
end

---@param project { lnum: integer, level: integer, text: string }
---@return string
local function display(project)
  return string.rep("  ", project.level) .. vim.trim(project.text)
end

---Choose a project, fuzzily.
---
---Telescope rather than vim.ui.select, because the built-in select is a numbered
---prompt: with thirty projects you read the list instead of typing at it, which is the
---whole reason the app's own Move to Project opens a search field. Built the way
---util/capture.lua builds its picker, including the pcall, so a missing telescope
---degrades to vim.ui.select instead of failing. The layer underneath does not care who
---picked.
---@param projects { lnum: integer, level: integer, text: string }[]
---@param on_choice fun(project: { lnum: integer, level: integer, text: string })
local function pick_project(projects, on_choice)
  local has_pickers, pickers = pcall(require, "telescope.pickers")
  if not has_pickers then
    vim.ui.select(projects, { prompt = "Move to project", format_item = display },
      function(choice)
        if choice ~= nil then
          on_choice(choice)
        end
      end)
    return
  end

  local finders = require("telescope.finders")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local conf = require("telescope.config").values

  pickers
    .new({}, {
      prompt_title = "Move to project",
      finder = finders.new_table({
        results = projects,
        entry_maker = function(project)
          return {
            value = project,
            display = display(project),
            -- Trimmed, unlike `display`: the indent is there to show depth, and
            -- leaving it in the ordinal makes every nested project match a query of
            -- spaces.
            ordinal = vim.trim(project.text),
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      -- The default select action opens a file, and there is no file here, so it has
      -- to be replaced or Enter silently does nothing.
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local entry = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if entry ~= nil then
            on_choice(entry.value)
          end
        end)
        return true
      end,
    })
    :find()
end

---The app's `Move to Project...`, as a fuzzy picker.
function M.to_project()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  -- Captured now: the picker is asynchronous, and the cursor can be anywhere by the
  -- time the choice comes back.
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local targets = outline.move_targets(lines, lnum, vim.fn.shiftwidth())
  if #targets == 0 then
    vim.notify("taskpaper: no project to move this into", vim.log.levels.WARN)
    return
  end

  pick_project(targets, function(choice)
    rewrite(function(ls, _, unit, sw)
      return outline.move_to_project(ls, lnum, choice.lnum, unit, sw)
    end, lnum)
  end)
end

return M
