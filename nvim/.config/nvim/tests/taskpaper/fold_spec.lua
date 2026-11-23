local outline = require("taskpaper.outline")

-- Stage 4 of IMPLEMENTATION_PLAN.md ships no code: measured 2026-09-17, nvim-ufo's
-- indent provider already returns heading-inclusive ranges on a taskpaper buffer, so
-- `zc` on a project line folds the project and its heading together and the app's whole
-- Expand/Collapse menu falls out of `zo zO zc zC zr zR zm zM`.
--
-- A stage with no code has nothing holding it up, which is what these tests are for.
-- They pin the one thing it rests on, and they do not need ufo loaded to do it.
--
-- ufo derives a fold level arithmetically (`lua/ufo/provider/indent.lua`): it expands
-- the leading whitespace to columns using 'tabstop', then takes
-- `math.ceil(columns / shiftwidth)`. taskpaper.outline counts one tab as one level. The
-- two agree only while 'tabstop' equals 'shiftwidth'. Set `ts=4 sw=2` and one tab
-- becomes two fold levels against one outline level, and every fold in the file is
-- drawn at the wrong depth while every test over the pure functions stays green.
describe("taskpaper folding", function()
  ---@return integer bufnr
  local function ftplugin_buffer()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(bufnr)
    -- The harness runs with `filetype plugin off`, so the ftplugin has to be sourced
    -- by hand. Its settings are all `setlocal`, so they land on this buffer only.
    vim.cmd("runtime! ftplugin/taskpaper.vim")
    return bufnr
  end

  ---ufo's level maths, from lua/ufo/provider/indent.lua.
  ---@param line string
  ---@param ts integer
  ---@param sw integer
  ---@return integer
  local function ufo_level(line, ts, sw)
    local columns = 0
    for col = 1, #line do
      local byte = line:byte(col)
      if byte == 0x20 then
        columns = columns + 1
      elseif byte == 0x09 then
        columns = columns + (ts - (columns % ts))
      else
        break
      end
    end
    return math.ceil(columns / sw)
  end

  it("indents with hard tabs, which is the unit ufo measures", function()
    ftplugin_buffer()
    assert.is_false(vim.bo.expandtab)
  end)

  -- The coupling itself, stated as the thing it protects rather than as two numbers:
  -- equal ts and sw are what make one tab one fold level.
  it("keeps tabstop equal to shiftwidth, so one tab is one fold level", function()
    ftplugin_buffer()
    assert.equals(vim.bo.tabstop, vim.bo.shiftwidth)
  end)

  it("gives ufo the same level for a tab-indented line as the outline does", function()
    ftplugin_buffer()
    local ts, sw = vim.bo.tabstop, vim.bo.shiftwidth
    for depth = 0, 3 do
      local line = ("\t"):rep(depth) .. "- a task"
      assert.equals(depth, outline.level(line, sw))
      assert.equals(ufo_level(line, ts, sw), outline.level(line, sw))
    end
  end)
end)
