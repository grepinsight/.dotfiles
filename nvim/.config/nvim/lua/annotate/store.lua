---Persistence for annotate: path mapping, atomic JSON writes, and the source index.
---
---Every write goes to `<path>.tmp` and is then renamed over the target, so a crash
---mid-write cannot leave a truncated store behind. A store that fails to parse is
---renamed aside rather than overwritten, because silently discarding annotations is
---worse than a loud error.
local config = require("annotate.config")

local M = {}

local uv = vim.uv or vim.loop

--- JSON encoding -------------------------------------------------------------------

---Format a number without Lua's float notation for integral values.
---@param n number
---@return string
local function encode_number(n)
  if n == math.floor(n) and math.abs(n) < 2 ^ 53 then
    return string.format("%d", n)
  end
  return tostring(n)
end

---Encode a value as indented JSON.
---
---Written by hand rather than using `vim.json.encode` directly because these files are
---meant to be read and hand-edited. Object keys are emitted in sorted order so the
---output is byte-stable across runs, which is what makes the store diffable.
---@param value any
---@param depth integer|nil
---@return string
local function encode(value, depth)
  depth = depth or 0
  local pad = string.rep("  ", depth + 1)
  local close_pad = string.rep("  ", depth)

  local t = type(value)
  if value == nil or value == vim.NIL then
    return "null"
  elseif t == "boolean" then
    return tostring(value)
  elseif t == "number" then
    return encode_number(value)
  elseif t == "string" then
    return vim.json.encode(value)
  elseif t ~= "table" then
    error("annotate.store: cannot encode value of type " .. t)
  end

  if vim.islist(value) then
    if #value == 0 then
      return "[]"
    end
    local parts = {}
    for _, item in ipairs(value) do
      table.insert(parts, pad .. encode(item, depth + 1))
    end
    return "[\n" .. table.concat(parts, ",\n") .. "\n" .. close_pad .. "]"
  end

  local keys = vim.tbl_keys(value)
  if #keys == 0 then
    return "{}"
  end
  table.sort(keys)
  local parts = {}
  for _, key in ipairs(keys) do
    table.insert(parts, pad .. vim.json.encode(tostring(key)) .. ": " .. encode(value[key], depth + 1))
  end
  return "{\n" .. table.concat(parts, ",\n") .. "\n" .. close_pad .. "}"
end

M._encode = encode

--- Path mapping --------------------------------------------------------------------

---Absolute, normalized form of a source path.
---@param source string
---@return string
local function normalize(source)
  return vim.fs.normalize(vim.fn.fnamemodify(source, ":p"))
end

M.normalize = normalize

---Map a source file to the path of its store.
---@param source string Path to the annotated file
---@return string path
function M.store_path(source)
  local cfg = config.get()
  local abs = normalize(source)

  if cfg.storage.mode == "sidecar" then
    return abs .. ".json"
  elseif cfg.storage.mode == "sidecar_hidden" then
    return vim.fs.joinpath(vim.fs.dirname(abs), ".annotations", vim.fs.basename(abs) .. ".json")
  end

  -- central: mirror the absolute path under the store directory so the layout stays
  -- greppable and a store is traceable back to its source by eye.
  local mirrored = abs:gsub("^/", "")
  return vim.fs.joinpath(cfg.storage.dir, mirrored .. ".json")
end

---Path of the index listing every source that has a store.
---@return string
function M.index_path()
  return vim.fs.joinpath(config.get().storage.dir, "index.json")
end

--- Low-level file IO ---------------------------------------------------------------

---@param path string
---@return string|nil content
local function read_file(path)
  local fd = uv.fs_open(path, "r", 438)
  if not fd then
    return nil
  end
  local stat = uv.fs_fstat(fd)
  local content = stat and uv.fs_read(fd, stat.size, 0) or nil
  uv.fs_close(fd)
  return content
end

---Write atomically: full content to a temp file, then rename over the target.
---@param path string
---@param content string
---@return boolean ok, string|nil err
local function write_file(path, content)
  local dir = vim.fs.dirname(path)
  if vim.fn.isdirectory(dir) == 0 and vim.fn.mkdir(dir, "p") == 0 then
    return false, ("cannot create directory %s"):format(dir)
  end

  local tmp = path .. ".tmp"
  local fd, open_err = uv.fs_open(tmp, "w", 420)
  if not fd then
    return false, ("cannot open %s for writing: %s"):format(tmp, open_err or "unknown error")
  end

  local ok, write_err = uv.fs_write(fd, content, 0)
  uv.fs_close(fd)
  if not ok then
    uv.fs_unlink(tmp)
    return false, ("cannot write %s: %s"):format(tmp, write_err or "unknown error")
  end

  local renamed, rename_err = uv.fs_rename(tmp, path)
  if not renamed then
    uv.fs_unlink(tmp)
    return false, ("cannot rename %s to %s: %s"):format(tmp, path, rename_err or "unknown error")
  end
  return true, nil
end

M._write_file = write_file

---Move a store that failed to parse aside instead of overwriting it.
---@param path string
---@return string quarantined Path the file was moved to
local function quarantine(path)
  local target = ("%s.bad-%s"):format(path, tostring(config.get().clock()))
  uv.fs_rename(path, target)
  return target
end

--- Store read and write ------------------------------------------------------------

---@class annotate.Mark
---@field id string
---@field category string
---@field note string|nil
---@field text string
---@field prefix string
---@field suffix string
---@field hint table { start = {row, col}, ["end"] = {row, col} }, 0-indexed
---@field created_at string
---@field orphaned boolean

---Read the marks for a source file.
---
---A missing store is not an error: it yields an empty list. A corrupt store is moved
---aside and reported, and reading continues with an empty list so the session stays
---usable. A store written by a newer format version is refused outright, so this
---version cannot clobber it.
---@param source string
---@return annotate.Mark[] marks
---@return string|nil err
---@return boolean read_only True when the store must not be written
function M.read(source)
  local path = M.store_path(source)
  local content = read_file(path)
  if content == nil or content == "" then
    return {}, nil, false
  end

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= "table" then
    local moved = quarantine(path)
    return {}, ("annotate: %s could not be parsed and was moved to %s"):format(path, moved), false
  end

  local version = tonumber(decoded.version) or 0
  if version > config.FORMAT_VERSION then
    return {},
      ("annotate: %s uses format version %d but this version supports %d; refusing to read or write it")
        :format(path, version, config.FORMAT_VERSION),
      true
  end

  local marks = decoded.marks
  if type(marks) ~= "table" then
    marks = {}
  end
  return marks, nil, false
end

---Write the marks for a source file, and keep the index in sync.
---
---An empty mark list removes the store and drops the source from the index, so
---deleting the last mark leaves no residue behind.
---@param source string
---@param marks annotate.Mark[]
---@return boolean ok, string|nil err
function M.write(source, marks)
  local abs = normalize(source)
  local path = M.store_path(abs)

  -- Re-check the version gate: a store may have been replaced by a newer writer since
  -- it was read.
  local _, read_err, read_only = M.read(abs)
  if read_only then
    return false, read_err
  end

  if #marks == 0 then
    uv.fs_unlink(path)
    M.index_remove(abs)
    return true, nil
  end

  local payload = { version = config.FORMAT_VERSION, source = abs, marks = marks }
  local ok, err = write_file(path, encode(payload) .. "\n")
  if not ok then
    return false, err
  end

  M.index_add(abs)
  return true, nil
end

--- Source index --------------------------------------------------------------------
---
--- Which files have marks cannot be answered by scanning in sidecar modes without
--- walking whole directory trees, so it is recorded explicitly. The index always lives
--- in the central store directory, since it is a local lookup cache rather than
--- content that should travel with the notes.

---@return string[] sources
local function read_index()
  local content = read_file(M.index_path())
  if content == nil or content == "" then
    return {}
  end
  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= "table" or type(decoded.sources) ~= "table" then
    return {}
  end
  return decoded.sources
end

---@param sources string[]
local function write_index(sources)
  table.sort(sources)
  write_file(M.index_path(), encode({ version = config.FORMAT_VERSION, sources = sources }) .. "\n")
end

---@param source string
function M.index_add(source)
  local abs = normalize(source)
  local sources = read_index()
  if vim.tbl_contains(sources, abs) then
    return
  end
  table.insert(sources, abs)
  write_index(sources)
end

---@param source string
function M.index_remove(source)
  local abs = normalize(source)
  local kept = vim.tbl_filter(function(s)
    return s ~= abs
  end, read_index())
  write_index(kept)
end

---Every source that currently has a readable store.
---
---Entries whose store has since been deleted are dropped, so a stale index self-heals
---instead of producing phantom entries in the export.
---@return string[] sources
function M.list_sources()
  local alive = {}
  local changed = false
  for _, source in ipairs(read_index()) do
    if uv.fs_stat(M.store_path(source)) then
      table.insert(alive, source)
    else
      changed = true
    end
  end
  if changed then
    write_index(vim.deepcopy(alive))
  end
  return alive
end

return M
