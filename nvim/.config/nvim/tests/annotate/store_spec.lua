local config = require("annotate.config")
local store = require("annotate.store")

local uv = vim.uv or vim.loop
local FIXED_TIME = 1756240980

---@return string dir A fresh temp directory
local function tmpdir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  return dir
end

local function configure(overrides)
  config.reset()
  local cfg, errors = config.setup(vim.tbl_deep_extend("force", {
    storage = { dir = tmpdir() },
    export = { path = tmpdir() .. "/export.md" },
    clock = function()
      return FIXED_TIME
    end,
  }, overrides or {}))
  assert(errors == nil, vim.inspect(errors))
  return cfg
end

local function mark(overrides)
  return vim.tbl_extend("force", {
    id = "1-1",
    category = "idiom",
    text = "bite the bullet",
    prefix = "we just have to ",
    suffix = " and ship it",
    hint = { start = { 40, 16 }, ["end"] = { 40, 31 } },
    created_at = "2026-08-26T14:03:00-07:00",
    orphaned = false,
  }, overrides or {})
end

local function write_raw(path, content)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local fd = assert(uv.fs_open(path, "w", 420))
  uv.fs_write(fd, content, 0)
  uv.fs_close(fd)
end

local function read_raw(path)
  local fd = uv.fs_open(path, "r", 438)
  if not fd then
    return nil
  end
  local stat = uv.fs_fstat(fd)
  local content = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)
  return content
end

describe("annotate.store path mapping", function()
  it("mirrors the absolute source path under the store dir in central mode", function()
    local cfg = configure({ storage = { mode = "central" } })
    local path = store.store_path("/nonexistent/notes/note.md")
    assert.equals(cfg.storage.dir .. "/nonexistent/notes/note.md.json", path)
  end)

  it("writes beside the source in sidecar mode", function()
    configure({ storage = { mode = "sidecar" } })
    assert.equals("/nonexistent/notes/note.md.json", store.store_path("/nonexistent/notes/note.md"))
  end)

  it("writes into a dot directory in sidecar_hidden mode", function()
    configure({ storage = { mode = "sidecar_hidden" } })
    assert.equals(
      "/nonexistent/notes/.annotations/note.md.json",
      store.store_path("/nonexistent/notes/note.md")
    )
  end)

  it("maps a symlinked path and its real path to the same store", function()
    configure({ storage = { mode = "central" } })
    local real_dir = tmpdir()
    write_raw(real_dir .. "/note.md", "prose")

    local link_dir = vim.fn.tempname() .. "-link"
    assert(uv.fs_symlink(real_dir, link_dir), "could not create symlink for the test")

    assert.equals(
      store.store_path(real_dir .. "/note.md"),
      store.store_path(link_dir .. "/note.md")
    )
  end)

  it("rejects an unknown storage mode at setup", function()
    config.reset()
    local cfg, errors = config.setup({ storage = { mode = "nonsense" } })
    assert.is_nil(cfg)
    assert.is_truthy(errors)
    assert.is_truthy(errors[1]:match("storage%.mode"))
  end)
end)

describe("annotate.store read and write", function()
  it("returns an empty list when no store exists", function()
    configure()
    local marks, err = store.read("/nowhere/absent.md")
    assert.same({}, marks)
    assert.is_nil(err)
  end)

  it("round-trips marks", function()
    configure()
    local source = tmpdir() .. "/note.md"
    local ok, err = store.write(source, { mark(), mark({ id = "1-2", category = "jargon", text = "backpressure" }) })
    assert.is_true(ok)
    assert.is_nil(err)

    local marks = store.read(source)
    assert.equals(2, #marks)
    assert.equals("bite the bullet", marks[1].text)
    assert.equals("jargon", marks[2].category)
    assert.same({ 40, 16 }, marks[1].hint.start)
  end)

  it("writes indented JSON with sorted keys so stores stay diffable", function()
    configure()
    local source = tmpdir() .. "/note.md"
    store.write(source, { mark() })
    local content = read_raw(store.store_path(source))

    assert.is_truthy(content:match('\n  "marks": %['), "expected indented marks array")
    -- Sorted keys put category before created_at before hint.
    local cat_at = content:find('"category"')
    local created_at = content:find('"created_at"')
    local text_at = content:find('"text"')
    assert.is_true(cat_at < created_at)
    assert.is_true(created_at < text_at)
  end)

  it("encodes integers without a decimal point", function()
    configure()
    local source = tmpdir() .. "/note.md"
    store.write(source, { mark() })
    local content = read_raw(store.store_path(source))
    assert.is_truthy(content:match("40"))
    assert.is_nil(content:match("40%.0"))
  end)

  it("leaves no .tmp file behind", function()
    configure()
    local source = tmpdir() .. "/note.md"
    store.write(source, { mark() })
    assert.is_nil(uv.fs_stat(store.store_path(source) .. ".tmp"))
  end)

  it("removes the store when the last mark is deleted", function()
    configure()
    local source = tmpdir() .. "/note.md"
    store.write(source, { mark() })
    assert.is_truthy(uv.fs_stat(store.store_path(source)))

    store.write(source, {})
    assert.is_nil(uv.fs_stat(store.store_path(source)))
    assert.same({}, store.list_sources())
  end)
end)

describe("annotate.store failure handling", function()
  it("quarantines a corrupt store instead of overwriting it", function()
    configure()
    local source = tmpdir() .. "/note.md"
    local path = store.store_path(source)
    write_raw(path, "{ this is not json")

    local marks, err = store.read(source)
    assert.same({}, marks)
    assert.is_truthy(err)
    assert.is_truthy(err:match("could not be parsed"))

    local quarantined = path .. ".bad-" .. tostring(FIXED_TIME)
    assert.is_truthy(uv.fs_stat(quarantined), "corrupt store should be moved aside")
    assert.equals("{ this is not json", read_raw(quarantined))
  end)

  it("refuses to read or write a store from a newer format version", function()
    configure()
    local source = tmpdir() .. "/note.md"
    write_raw(store.store_path(source), vim.json.encode({ version = 99, source = source, marks = {} }))

    local marks, err, read_only = store.read(source)
    assert.same({}, marks)
    assert.is_true(read_only)
    assert.is_truthy(err:match("format version 99"))

    local ok, write_err = store.write(source, { mark() })
    assert.is_false(ok)
    assert.is_truthy(write_err:match("refusing"))
    -- The newer file must still be intact.
    assert.is_truthy(read_raw(store.store_path(source)):match('"version":99'))
  end)

  it("treats a store with a non-table marks field as empty rather than erroring", function()
    configure()
    local source = tmpdir() .. "/note.md"
    write_raw(store.store_path(source), vim.json.encode({ version = 1, source = source, marks = "oops" }))
    local marks, err = store.read(source)
    assert.same({}, marks)
    assert.is_nil(err)
  end)
end)

describe("annotate.store source index", function()
  it("tracks sources that have marks", function()
    configure()
    local a = tmpdir() .. "/a.md"
    local b = tmpdir() .. "/b.md"
    store.write(a, { mark() })
    store.write(b, { mark() })

    local sources = store.list_sources()
    assert.equals(2, #sources)
    assert.is_true(vim.tbl_contains(sources, store.normalize(a)))
    assert.is_true(vim.tbl_contains(sources, store.normalize(b)))
  end)

  it("does not duplicate a source written twice", function()
    configure()
    local source = tmpdir() .. "/note.md"
    store.write(source, { mark() })
    store.write(source, { mark(), mark({ id = "1-2" }) })
    assert.equals(1, #store.list_sources())
  end)

  it("drops index entries whose store has disappeared", function()
    configure()
    local source = tmpdir() .. "/note.md"
    store.write(source, { mark() })
    uv.fs_unlink(store.store_path(source))
    assert.same({}, store.list_sources())
  end)
end)
