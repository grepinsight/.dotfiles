---Quick capture: hand a thought to `~/bin/capture` and get out of the way.
---
---The writer lives in `~/.dotfiles/capture` and owns the filename, the
---frontmatter, and the collision handling. This module is only an adapter, so
---the parts worth testing (`argv`, `selection_text`, `basename`) are kept free
---of `vim.*` and covered in `tests/util/capture_spec.lua`.
---
---No vault resolution here, deliberately. `capture` reads `$OBSIDIAN_VAULT`
---itself and refuses when it is unset. `util.vault` would instead fall back to
---`~/Thoughts`, which is right for a reader -- the worst case is opening the
---wrong file -- and wrong for a writer, where it means a thought saved to a
---directory the user never opens. A refusal is recoverable; a silent write to
---the wrong vault is not.
local M = {}

M.executable = vim.fs.normalize("~/bin/capture")

---Argument list for `vim.fn.system`, which takes a list and so needs no quoting.
---@param text string The thought, verbatim
---@param source string Which door this came from, for the frontmatter
---@return string[]
function M.argv(text, source)
  -- `--` so a thought that opens with a hyphen is text, not a flag.
  return { M.executable, "--source", source or "nvim", "--", text }
end

---Join selected lines into one thought, trimming the blank edges a visual
---selection usually picks up while leaving the interior shape alone.
---@param lines string[]|nil
---@return string
function M.selection_text(lines)
  local text = table.concat(lines or {}, "\n")
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

---Last path component, for a notification that fits on one line.
---@param path string
---@return string
function M.basename(path)
  return path:match("([^/]+)/?$") or path
end

---Write the thought and report where it landed.
---@param text string|nil
---@param opts table|nil { source = string, open = boolean }
---@return string|nil path Absolute path written, or nil on refusal/failure
function M.run(text, opts)
  opts = opts or {}

  if text == nil or text:match("^%s*$") then
    vim.notify("Capture: nothing to capture", vim.log.levels.WARN)
    return nil
  end

  local output = vim.fn.system(M.argv(text, opts.source))
  if vim.v.shell_error ~= 0 then
    -- Surface the writer's own message: it names the fix for both likely
    -- causes ($OBSIDIAN_VAULT unset, ~/bin/capture not linked).
    vim.notify("Capture failed: " .. vim.trim(output), vim.log.levels.ERROR)
    return nil
  end

  local path = vim.trim(output)
  vim.notify("Captured → " .. M.basename(path))

  if opts.open then
    vim.cmd.split(vim.fn.fnameescape(path))
  end

  return path
end

-- ---------------------------------------------------------------------------
-- Reading side: a picker over 00-Capture.
-- ---------------------------------------------------------------------------

M.list_executable = vim.fs.normalize("~/bin/captures")

---Argument list for `captures --json`.
---@param limit integer|nil
---@return string[]
function M.list_argv(limit)
  return { M.list_executable, "--json", "-n", tostring(limit or 200) }
end

---One picker line for a capture record.
---
---Timestamp format matches the `captures` CLI on purpose: the same thought
---should look the same whichever way you list it.
---@param record table
---@return string
function M.display_for(record)
  local created = record.created_at or ""
  local stamp = "?"
  if #created >= 16 then
    stamp = created:sub(1, 10) .. " " .. created:sub(12, 16)
  elseif record.name and #record.name >= 15 then
    stamp = record.name:sub(1, 10) .. " " .. record.name:sub(12, 13) .. ":" .. record.name:sub(14, 15)
  end

  local text = record.first_line
  if text == nil or text == "" then
    text = "(empty)"
  end
  if record.multiline then
    text = text .. " [...]"
  end

  return stamp .. "  " .. text
end

---Telescope-ready entries from the JSON `captures --json` prints.
---
---Pure: takes the JSON text, returns a list. Returns an empty list rather than
---throwing on malformed input, because the picker should say "nothing to show"
---instead of erroring inside a keymap.
---@param json_text string
---@return table[]
function M.entries_from_json(json_text)
  if json_text == nil or vim.trim(json_text) == "" then
    return {}
  end

  local ok, records = pcall(vim.json.decode, json_text)
  if not ok or type(records) ~= "table" then
    return {}
  end

  local entries = {}
  for _, record in ipairs(records) do
    if type(record) == "table" and record.path then
      table.insert(entries, {
        path = record.path,
        display = M.display_for(record),
        -- Fuzzy-match against the thought and its door, so `hammerspoon`
        -- filters by where it came from and words filter by what it says.
        ordinal = (record.first_line or "") .. " " .. (record.source or ""),
      })
    end
  end
  return entries
end

---Open a Telescope picker over the captures, newest first.
---@param opts table|nil { limit = integer }
function M.pick(opts)
  opts = opts or {}

  local has_pickers, pickers = pcall(require, "telescope.pickers")
  if not has_pickers then
    vim.notify("Captures: telescope is not available", vim.log.levels.ERROR)
    return
  end
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values

  local output = vim.fn.system(M.list_argv(opts.limit))
  if vim.v.shell_error ~= 0 then
    vim.notify("Captures failed: " .. vim.trim(output), vim.log.levels.ERROR)
    return
  end

  local entries = M.entries_from_json(output)
  if #entries == 0 then
    vim.notify("Captures: nothing captured yet")
    return
  end

  pickers
    .new(opts, {
      prompt_title = "Captures (newest first)",
      finder = finders.new_table({
        results = entries,
        entry_maker = function(entry)
          -- Both `path` and `filename`: telescope's default select action has
          -- read one or the other depending on version, and getting it wrong
          -- makes Enter silently do nothing.
          return {
            value = entry.path,
            path = entry.path,
            filename = entry.path,
            display = entry.display,
            ordinal = entry.ordinal,
          }
        end,
      }),
      sorter = conf.generic_sorter(opts),
      previewer = conf.file_previewer(opts),
    })
    :find()
end

return M
