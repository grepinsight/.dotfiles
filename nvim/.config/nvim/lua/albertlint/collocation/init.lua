---An nvim-cmp source over the writer's own collected phrases.
---
---Fills a gap the author's own config created. `plugins/lsp/copilot_gate.lua` blocks Copilot
---from markdown outright, and `plugins/cmp.lua` filters LuaSnip out of markdown, so a prose
---buffer's menu holds `nvim_lsp`, `path`, and `buffer` at five characters, and nothing that
---knows anything about English. This is the prose source for that hole.
---
---**Why this is not a Copilot substitute, and must not become one.** The unit is the whole
---distinction: a word or a short collocation is *vocabulary*, and picking one out of a menu
---is an act of judgment. A clause is *composition*, and accepting it with one keystroke is
---not. `index.lua` caps a surface at five words for exactly this reason. If that cap ever
---comes off, this stops being a vocabulary aid and becomes the thing the author deliberately
---blocked.
---
---Registration is left to the caller rather than done here, so this module never touches
---`plugins/cmp.lua`:
---
---```lua
---require("cmp").register_source("english", require("albertlint.collocation").source)
---  -- then add { name = "english", keyword_length = 2 } to the markdown sources
---```
local index = require("albertlint.collocation.index")

local M = {}

local uv = vim.uv or vim.loop

---Directories scanned, relative to the vault's English folder, with the `kind` each one
---contributes. The kind comes from the directory rather than from frontmatter because
---inferring it from which fields happen to be filled in dropped 32 of 176 real notes.
local SOURCES = {
  { dir = "Phrases", kind = "phrase" },
  { dir = "Better English", kind = "better-english" },
}

M.config = {
  ---Root holding `Phrases/` and `Better English/`. Resolved at first use, not at load, so a
  ---headless test can point it elsewhere.
  root = nil,
  ---Where the derived index is cached. `nil` means `stdpath("cache")`. Configurable so a
  ---test can point it at a temp file instead of monkey-patching `vim.fn.stdpath`, which
  ---would outlive the test and leak into whatever ran next in the same Neovim.
  cache_path = nil,
  filetypes = { markdown = true, text = true, gitcommit = true, mail = true, org = true },
  min_chars = 2,
  max_words = 3,
  limit = 20,
}

---@return string
local function root()
  return M.config.root
    or (vim.env.OBSIDIAN_VAULT or (vim.env.HOME .. "/Thoughts")) .. "/03-Resources/English"
end

---@return string
local function cache_path()
  return M.config.cache_path or (vim.fn.stdpath("cache") .. "/albertlint-collocation.json")
end

--- Scanning ------------------------------------------------------------------------

---Every note to index, with a fingerprint of the collection's state.
---
---The fingerprint is (path, mtime, size) per file, joined. Cheaper than reading 176 files
---and, unlike a max-mtime, it notices a *deletion*: removing a note lowers the count without
---moving the newest timestamp, and a max-mtime cache would serve the removed phrase forever.
---@return table[] notes, string fingerprint
local function scan()
  local notes, parts = {}, {}
  for _, source in ipairs(SOURCES) do
    local dir = root() .. "/" .. source.dir
    local ok, iter = pcall(vim.fs.dir, dir)
    if ok then
      local names = {}
      for name, kind in iter do
        if kind == "file" and name:match("%.md$") then
          table.insert(names, name)
        end
      end
      -- Sorted, so the fingerprint does not change with filesystem iteration order.
      table.sort(names)
      for _, name in ipairs(names) do
        local path = dir .. "/" .. name
        local stat = uv.fs_stat(path)
        if stat then
          table.insert(parts, ("%s:%d:%d"):format(path, stat.mtime.sec, stat.size))
          table.insert(notes, { path = path, kind = source.kind })
        end
      end
    end
  end
  return notes, vim.fn.sha256(table.concat(parts, "\n"))
end

---@param notes table[] With `path` set
---@return table[] notes With `text` filled in, unreadable files dropped
local function read_all(notes)
  local out = {}
  for _, note in ipairs(notes) do
    local fd = io.open(note.path, "r")
    if fd then
      note.text = fd:read("*a")
      fd:close()
      table.insert(out, note)
    end
  end
  return out
end

--- Cache ---------------------------------------------------------------------------

---@type table[]|nil
local entries = nil
---@type string|nil
local loaded_fingerprint = nil

---@param fingerprint string
---@return table[]|nil
local function read_cache(fingerprint)
  local fd = io.open(cache_path(), "r")
  if not fd then
    return nil
  end
  local raw = fd:read("*a")
  fd:close()
  local ok, decoded = pcall(vim.json.decode, raw)
  -- A corrupt cache is a rebuild, not an error: it is derived data and the source of truth
  -- is on disk. Same reasoning as annotate's store, inverted, because that one holds the
  -- only copy and so refuses rather than discards.
  if not ok or type(decoded) ~= "table" or decoded.fingerprint ~= fingerprint then
    return nil
  end
  return decoded.entries
end

---@param fingerprint string
---@param built table[]
local function write_cache(fingerprint, built)
  local fd = io.open(cache_path(), "w")
  if not fd then
    return
  end
  fd:write(vim.json.encode({ fingerprint = fingerprint, entries = built }))
  fd:close()
end

---Entries for the current state of the collection, from cache when it is still valid.
---@param force boolean|nil Rebuild even when the fingerprint matches
---@return table[]
function M.entries(force)
  local notes, fingerprint = scan()
  if not force and entries and loaded_fingerprint == fingerprint then
    return entries
  end

  if not force then
    local cached = read_cache(fingerprint)
    if cached then
      entries, loaded_fingerprint = cached, fingerprint
      return entries
    end
  end

  entries = index.build(read_all(notes))
  loaded_fingerprint = fingerprint
  write_cache(fingerprint, entries)
  return entries
end

--- cmp source ----------------------------------------------------------------------

local source = {}

function source:get_debug_name()
  return "english"
end

function source:is_available()
  return M.config.filetypes[vim.bo.filetype] == true
end

---@param entry table
---@return string
local function documentation(entry)
  local lines = {}
  if entry.detail then
    table.insert(lines, entry.detail)
  end
  if entry.synonyms and #entry.synonyms > 0 then
    table.insert(lines, "")
    table.insert(lines, "**Also:** " .. table.concat(entry.synonyms, ", "))
  end
  if entry.example then
    table.insert(lines, "")
    table.insert(lines, "> " .. entry.example)
  end
  if entry.kind == "better-english" then
    table.insert(lines, "")
    table.insert(lines, "_from Better English_")
  end
  return table.concat(lines, "\n")
end

function source:complete(params, callback)
  local before = params.context.cursor_before_line
  local matches, dropped = index.candidates(M.entries(), before, {
    min_chars = M.config.min_chars,
    max_words = M.config.max_words,
    limit = M.config.limit,
  })

  local items = {}
  for _, entry in ipairs(matches) do
    -- `textEdit` rather than a bare label, and this is the detail that makes multi-word
    -- matching work at all. The matched prefix may span several words, so accepting has to
    -- REPLACE it. Without this, typing `give me push` and accepting `pushback` yields
    -- `give me pushpushback`, because cmp would only replace the current keyword.
    local start_col = #before - #entry.matched

    -- Case follows what was typed, not what the note is titled.
    --
    -- Notes are titled in Title Case, because a note title is a heading. Inserting the
    -- surface verbatim mid-sentence gave `it was A One-Off` and `please Surface`. So the
    -- typed text is kept verbatim and the tail is lowercased, unless the typed text itself
    -- carries a capital, which is the author signalling a sentence start.
    --
    -- This does lowercase a genuine proper noun inside a phrase. Accepted, because the
    -- deterministic `brand-caps` rule sits in the same plugin and flags exactly that on the
    -- next keystroke, so the failure is caught immediately and next to where it happened.
    local typed = before:sub(start_col + 1)
    local tail = entry.surface:sub(#entry.matched + 1)
    if typed == typed:lower() then
      tail = tail:lower()
    end

    table.insert(items, {
      label = entry.surface,
      filterText = entry.matched,
      documentation = { kind = "markdown", value = documentation(entry) },
      labelDetails = { description = entry.kind == "phrase" and "phrase" or "better english" },
      textEdit = {
        range = {
          start = { line = params.context.cursor.row - 1, character = start_col },
          ["end"] = { line = params.context.cursor.row - 1, character = #before },
        },
        newText = typed .. tail,
      },
    })
  end

  -- `isIncomplete` so cmp re-queries as more is typed: the candidate set changes shape when
  -- a second word arrives, which a cached one-shot result would not reflect.
  callback({ items = items, isIncomplete = true })

  if dropped > 0 then
    -- No silent caps. One notify per query would be unbearable, so this is a debug-level
    -- message that shows up in `:messages` when someone goes looking.
    vim.schedule(function()
      vim.notify(
        ("albertlint: %d more collocation matches not shown"):format(dropped),
        vim.log.levels.DEBUG
      )
    end)
  end
end

M.source = source

--- Commands ------------------------------------------------------------------------

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  vim.api.nvim_create_user_command("AlbertLintCollocationRebuild", function()
    local built = M.entries(true)
    vim.notify(
      ("albertlint: collocation index rebuilt, %d entries"):format(#built),
      vim.log.levels.INFO
    )
  end, { desc = "albertlint: rebuild the collocation index from the vault" })

  vim.api.nvim_create_user_command("AlbertLintCollocationStatus", function()
    local built = M.entries()
    local by_kind = {}
    for _, entry in ipairs(built) do
      by_kind[entry.kind] = (by_kind[entry.kind] or 0) + 1
    end
    local parts = {}
    for kind, n in pairs(by_kind) do
      table.insert(parts, ("%s %d"):format(kind, n))
    end
    table.sort(parts)
    vim.notify(
      ("albertlint: %d collocation entries (%s), cache %s"):format(
        #built,
        table.concat(parts, ", "),
        cache_path()
      ),
      vim.log.levels.INFO
    )
  end, { desc = "albertlint: report collocation index size and cache location" })

  return M
end

M._scan = scan
M._cache_path = cache_path
return M
