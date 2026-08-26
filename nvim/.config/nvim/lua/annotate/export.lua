---Render every stored mark into one markdown review note, grouped by category.
---
---Regeneration is idempotent and non-destructive: the generated content lives between
---two HTML comment delimiters and only that region is replaced. Anything written outside
---them, including a title, front matter, or notes added by hand, survives.
local config = require("annotate.config")
local store = require("annotate.store")

local M = {}

M.BEGIN = "<!-- annotate:begin -->"
M.END = "<!-- annotate:end -->"

local DEFAULT_TITLE = "# Marked Phrases"

--- Rendering helpers ---------------------------------------------------------------

---Collapse newlines and runs of whitespace so a multi-line anchor fits one quote line.
---@param s string|nil
---@return string
local function one_line(s)
  if s == nil or s == "" then
    return ""
  end
  return (s:gsub("%s+", " "))
end

---A link back to the source, as an Obsidian wiki link when the file is in the vault.
---
---A wiki link only resolves inside the vault, so anything outside it gets a plain
---markdown link to the absolute path instead of a link that would silently dangle.
---@param source string
---@return string
local function source_link(source)
  local ok, vault = pcall(require, "util.vault")
  if ok then
    -- Both sides must be canonicalised the same way. Source paths come back from
    -- store.normalize with symlinks resolved, so a vault root that passes through a
    -- symlink would never match a raw string compare, and every vault note would
    -- silently degrade to a plain link.
    local root = store.normalize(vault.root())
    if source:sub(1, #root + 1) == root .. "/" then
      return ("[[%s]]"):format(vim.fn.fnamemodify(source, ":t:r"))
    end
  end
  return ("[%s](%s)"):format(vim.fn.fnamemodify(source, ":t"), source)
end

---The marked phrase in its surrounding sentence, with the phrase emphasised.
---
---An ellipsis is added only on a side whose stored context actually hit the configured
---window, so the reader can tell a trimmed context from a real sentence boundary.
---@param mark annotate.Mark
---@param context_chars integer
---@return string
local function context_quote(mark, context_chars)
  local before = one_line(mark.prefix)
  local after = one_line(mark.suffix)
  local body = one_line(mark.text)

  local head = ""
  if before ~= "" then
    head = (#(mark.prefix or "") >= context_chars and "..." or "") .. before
  end

  local tail = ""
  if after ~= "" then
    tail = after .. (#(mark.suffix or "") >= context_chars and "..." or "")
  end

  return head .. "**" .. body .. "**" .. tail
end

--- Collection ----------------------------------------------------------------------

---@class annotate.ExportEntry
---@field source string
---@field mark annotate.Mark

---Every non-orphaned mark across every known source.
---
---Orphaned marks are excluded: they are a repair queue, not review material.
---@return table<string, annotate.ExportEntry[]> by_category
---@return table stats { marks, orphans, files }
function M.collect()
  local by_category = {}
  local stats = { marks = 0, orphans = 0, files = 0 }

  for _, source in ipairs(store.list_sources()) do
    local marks = store.read(source)
    local counted = false
    for _, mark in ipairs(marks) do
      if mark.orphaned then
        stats.orphans = stats.orphans + 1
      else
        by_category[mark.category] = by_category[mark.category] or {}
        table.insert(by_category[mark.category], { source = source, mark = mark })
        stats.marks = stats.marks + 1
        counted = true
      end
    end
    if counted then
      stats.files = stats.files + 1
    end
  end

  -- Sort within each category by source then position, so the note is byte-stable
  -- across runs and a regeneration produces no spurious diff.
  for _, entries in pairs(by_category) do
    table.sort(entries, function(a, b)
      if a.source ~= b.source then
        return a.source < b.source
      end
      local ah = a.mark.hint and a.mark.hint.start or { 0, 0 }
      local bh = b.mark.hint and b.mark.hint.start or { 0, 0 }
      if ah[1] ~= bh[1] then
        return ah[1] < bh[1]
      end
      return (ah[2] or 0) < (bh[2] or 0)
    end)
  end

  return by_category, stats
end

--- Rendering -----------------------------------------------------------------------

---Render the generated block, delimiters included.
---@param by_category table<string, annotate.ExportEntry[]>
---@return string[] lines
function M.render(by_category)
  local context_chars = config.get().context_chars
  local lines = { M.BEGIN, "" }

  local any = false
  for _, category in ipairs(config.ordered_categories()) do
    local entries = by_category[category.name]
    if entries and #entries > 0 then
      any = true
      table.insert(lines, "## " .. category.label)
      table.insert(lines, "")
      for _, entry in ipairs(entries) do
        local mark = entry.mark
        table.insert(lines, ("- **%s** - %s"):format(one_line(mark.text), source_link(entry.source)))
        table.insert(lines, "  > " .. context_quote(mark, context_chars))
        if mark.note and mark.note ~= "" then
          table.insert(lines, "")
          table.insert(lines, "  note: " .. one_line(mark.note))
        end
        table.insert(lines, "")
      end
    end
  end

  -- Categories not present in the config still hold marks; emit them rather than
  -- silently dropping data after a category is renamed or removed.
  local known = {}
  for _, category in ipairs(config.ordered_categories()) do
    known[category.name] = true
  end
  local leftovers = {}
  for name in pairs(by_category) do
    if not known[name] then
      table.insert(leftovers, name)
    end
  end
  table.sort(leftovers)
  for _, name in ipairs(leftovers) do
    any = true
    table.insert(lines, "## " .. name)
    table.insert(lines, "")
    for _, entry in ipairs(by_category[name]) do
      table.insert(lines, ("- **%s** - %s"):format(one_line(entry.mark.text), source_link(entry.source)))
      table.insert(lines, "  > " .. context_quote(entry.mark, context_chars))
      table.insert(lines, "")
    end
  end

  if not any then
    table.insert(lines, "_No marks yet._")
    table.insert(lines, "")
  end

  table.insert(lines, M.END)
  return lines
end

--- Splicing ------------------------------------------------------------------------

---Replace the delimited region in `existing`, or append it when absent.
---@param existing string[] Current file contents
---@param block string[] Generated block, delimiters included
---@return string[] lines
function M.splice(existing, block)
  local begin_at, end_at
  for i, line in ipairs(existing) do
    local trimmed = vim.trim(line)
    if trimmed == M.BEGIN and begin_at == nil then
      begin_at = i
    elseif trimmed == M.END then
      end_at = i
    end
  end

  if begin_at and end_at and end_at > begin_at then
    local out = {}
    for i = 1, begin_at - 1 do
      table.insert(out, existing[i])
    end
    vim.list_extend(out, block)
    for i = end_at + 1, #existing do
      table.insert(out, existing[i])
    end
    return out
  end

  -- No usable delimiters: keep whatever is there and append the block. An unmatched
  -- delimiter is left alone rather than guessed at, so nothing is destroyed.
  local out = vim.deepcopy(existing)
  if #out == 0 then
    out = { DEFAULT_TITLE, "" }
  elseif vim.trim(out[#out]) ~= "" then
    table.insert(out, "")
  end
  vim.list_extend(out, block)
  return out
end

--- Entry point ---------------------------------------------------------------------

---Regenerate the export note.
---@return boolean ok, string|nil err, table stats
function M.run()
  local path = config.get().export.path
  local by_category, stats = M.collect()
  local block = M.render(by_category)

  local existing = {}
  if vim.fn.filereadable(path) == 1 then
    existing = vim.fn.readfile(path)
  end

  local dir = vim.fs.dirname(path)
  if vim.fn.isdirectory(dir) == 0 and vim.fn.mkdir(dir, "p") == 0 then
    return false, ("cannot create directory %s"):format(dir), stats
  end

  if vim.fn.writefile(M.splice(existing, block), path) ~= 0 then
    return false, ("cannot write %s"):format(path), stats
  end

  stats.path = path
  return true, nil, stats
end

return M
