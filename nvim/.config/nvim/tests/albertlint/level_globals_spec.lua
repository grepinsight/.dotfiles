---A static check for accidental global reads in the level modules.
---
---Two crashes shipped from this module in one day, and this class caused the second: a
---`local` declared BELOW its own use resolved to a nil global, so `:AlbertLintLevel1` died
---with "attempt to perform arithmetic on global 'timeout_ms'" before it reached any
---provider. Lua accepts that silently -- it compiles, and it only fails when the line runs.
---
---The behavioural test for it lives in `level_init_spec.lua`, which now drives `run()` all
---the way to dispatch. This file catches the same class on lines no test reaches, which is
---the part a behavioural test cannot promise. `luac -l` emits one `_ENV "name"` entry per
---global read, so the check is a grep over a bytecode listing and takes under a second.
---
---Skipped rather than failed when `luac` is absent, since it is not part of Neovim and this
---config is checked out on machines that will not have it.
local ALLOWED = {
  -- Neovim and Lua's own globals. Anything else in these modules is a mistake.
  vim = true,
  require = true,
  string = true,
  table = true,
  math = true,
  os = true,
  io = true,
  pcall = true,
  xpcall = true,
  error = true,
  assert = true,
  type = true,
  tostring = true,
  tonumber = true,
  ipairs = true,
  pairs = true,
  next = true,
  select = true,
  unpack = true,
  setmetatable = true,
  getmetatable = true,
  rawget = true,
  rawset = true,
  rawequal = true,
  rawlen = true,
  print = true,
  debug = true,
  package = true,
  coroutine = true,
  utf8 = true,
  _G = true,
  arg = true,
}

---@return string|nil root Absolute path to this config, or nil
local function config_root()
  local here = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(here, ":p:h:h:h")
end

---Global names read by a Lua file, via a bytecode listing.
---@param path string
---@return string[]|nil names, string|nil err
local function global_reads(path)
  local out = vim.fn.systemlist({ "luac", "-l", path })
  if vim.v.shell_error ~= 0 then
    return nil, table.concat(out, " "):sub(1, 200)
  end
  local seen, names = {}, {}
  for _, line in ipairs(out) do
    -- Lua 5.2+ compiles a global read as `GETTABUP ... ; _ENV "name"`.
    for name in line:gmatch('_ENV "([A-Za-z_][A-Za-z0-9_]*)"') do
      if not ALLOWED[name] and not seen[name] then
        seen[name] = true
        table.insert(names, name)
      end
    end
  end
  return names, nil
end

describe("level modules read no unexpected globals", function()
  local root = config_root()
  local files = {
    "lua/albertlint/level/init.lua",
    "lua/albertlint/level/apply.lua",
    "lua/albertlint/level/levels.lua",
    "lua/albertlint/level/provider.lua",
    "lua/albertlint/level/diffview.lua",
  }

  for _, rel in ipairs(files) do
    it(rel, function()
      if vim.fn.executable("luac") == 0 then
        -- Not a silent pass: say why, so a clean run on a machine without luac is not
        -- mistaken for the check having run.
        print("SKIP " .. rel .. ": `luac` is not on PATH, so the static check cannot run")
        return
      end

      local path = vim.fs.joinpath(root, rel)
      assert.equals(1, vim.fn.filereadable(path), "not readable: " .. path)

      local names, err = global_reads(path)
      assert.is_nil(err, "luac failed: " .. tostring(err))
      assert.same({}, names)
    end)
  end
end)
