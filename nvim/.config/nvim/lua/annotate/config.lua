---Configuration for the annotate module: defaults, validation, ordered accessors.
---
---Categories carry an explicit `order` because Lua's `pairs()` iteration order is
---undefined. Without it, generated keymaps and the export note's section order would
---shuffle between sessions, and the export could not be idempotent.
local M = {}

---Bumped only on a breaking change to the on-disk JSON shape.
M.FORMAT_VERSION = 1

local VALID_MODES = { central = true, sidecar = true, sidecar_hidden = true }

---@class annotate.Category
---@field key string Single character appended to `prefix` to form the keymap
---@field label string Human-readable name, used as the export section heading
---@field hl string Highlight group applied to the marked range
---@field order integer Sort position for keymaps and export sections
---@field prompt boolean|nil When true, capture asks for note text before saving

local defaults = {
  categories = {
    idiom      = { key = "i", label = "Idiom",            hl = "AnnotateIdiom",      order = 1 },
    jargon     = { key = "j", label = "Jargon",           hl = "AnnotateJargon",     order = 2 },
    expression = { key = "e", label = "Great expression", hl = "AnnotateExpression", order = 3 },
    phrase     = { key = "p", label = "Great phrase",     hl = "AnnotatePhrase",     order = 4 },
    note       = { key = "n", label = "Note",             hl = "AnnotateNote",       order = 5, prompt = true },
  },

  storage = {
    ---"central" mirrors the source path under `dir`; "sidecar" writes `<file>.json`
    ---beside the source; "sidecar_hidden" writes `.annotations/<file>.json` beside it.
    mode = "central",
    ---nil means `stdpath("data") .. "/annotate"`, resolved at setup so tests can override.
    dir = nil,
  },

  ---nil means `03-Resources/English/Marked Phrases.md` under the Obsidian vault.
  export = { path = nil },

  ---Characters of surrounding text stored on each side of a mark, used to disambiguate
  ---a phrase that occurs more than once in the file.
  context_chars = 40,

  virtual_text = true,

  ---Filetypes in which a new mark may be created. `nil` means anywhere, which is the
  ---default because refusing by default would be a surprise. Loading existing marks is
  ---deliberately NOT gated on this; see the FileType autocmd in init.lua.
  filetypes = nil,

  prefix = "<leader>a",

  ---Injected so tests can pin time. Returns a Unix timestamp.
  clock = os.time,
}

---@type table
local current = nil

---@param opts table
---@return string[] errors Empty when the config is valid
local function validate(opts)
  local errors = {}

  if type(opts.categories) ~= "table" or next(opts.categories) == nil then
    table.insert(errors, "categories must be a non-empty table")
    return errors
  end

  local seen_keys = {}
  for name, cat in pairs(opts.categories) do
    local where = ("categories.%s"):format(name)
    if type(cat) ~= "table" then
      table.insert(errors, where .. " must be a table")
    else
      for _, field in ipairs({ "key", "label", "hl" }) do
        if type(cat[field]) ~= "string" or cat[field] == "" then
          table.insert(errors, ("%s.%s must be a non-empty string"):format(where, field))
        end
      end
      if type(cat.key) == "string" and #cat.key ~= 1 then
        table.insert(errors, where .. ".key must be exactly one character")
      end
      if type(cat.order) ~= "number" then
        table.insert(errors, where .. ".order must be a number")
      end
      if seen_keys[cat.key] then
        table.insert(errors, ("categories.%s and categories.%s both use key %q")
          :format(seen_keys[cat.key], name, cat.key))
      elseif type(cat.key) == "string" then
        seen_keys[cat.key] = name
      end
    end
  end

  if not VALID_MODES[opts.storage.mode] then
    table.insert(errors, ("storage.mode must be one of central, sidecar, sidecar_hidden (got %q)")
      :format(tostring(opts.storage.mode)))
  end

  if type(opts.context_chars) ~= "number" or opts.context_chars < 1 then
    table.insert(errors, "context_chars must be a positive number")
  end

  if type(opts.clock) ~= "function" then
    table.insert(errors, "clock must be a function returning a Unix timestamp")
  end

  return errors
end

---Merge user options over the defaults and validate.
---@param opts table|nil
---@return table|nil config, string[]|nil errors
function M.setup(opts)
  local merged = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})

  -- tbl_deep_extend copies functions by reference, but a user-supplied clock must not be
  -- clobbered by the default; deep_extend already handles that. Restore only if dropped.
  merged.clock = (opts and opts.clock) or defaults.clock

  local errors = validate(merged)
  if #errors > 0 then
    return nil, errors
  end

  merged.storage.dir = merged.storage.dir or (vim.fn.stdpath("data") .. "/annotate")
  if merged.export.path == nil then
    local ok, vault = pcall(require, "util.vault")
    merged.export.path = ok and vault.path("03-Resources/English/Marked Phrases.md")
      or vim.fn.expand("~/Marked Phrases.md")
  end

  current = merged
  return merged, nil
end

---@return table config
function M.get()
  if current == nil then
    -- Defaults are valid by construction, so an implicit setup cannot fail.
    local cfg = M.setup({})
    return cfg
  end
  return current
end

---Reset to unconfigured. Test-only.
function M.reset()
  current = nil
end

---Categories as a stable array, sorted by `order` then name.
---@return table[] list Each entry is the category table plus a `name` field
function M.ordered_categories()
  local cfg = M.get()
  local list = {}
  for name, cat in pairs(cfg.categories) do
    local entry = vim.deepcopy(cat)
    entry.name = name
    table.insert(list, entry)
  end
  table.sort(list, function(a, b)
    if a.order ~= b.order then
      return a.order < b.order
    end
    return a.name < b.name
  end)
  return list
end

---@param name string
---@return annotate.Category|nil
function M.category(name)
  return M.get().categories[name]
end

---@param ft string
---@return boolean
function M.handles_filetype(ft)
  local fts = M.get().filetypes
  if fts == nil then
    return true
  end
  return vim.tbl_contains(fts, ft)
end

return M
