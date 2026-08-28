---albertlint: a prose linter for one writer's catalogued mistakes.
---
---Rules are derived from a personal log of logged corrections and the
---an earlier corpus review, so every rule traces to a slip that actually happened rather
---than to a style guide. See `rules.lua` for the catalogue and the `drill_ref` on each.
---
---Two tiers, because they answer different questions:
---  live  cheap single-token rules, debounced while typing, cursor word exempt
---  exit  sentence-level rules, on InsertLeave and write, when the sentence is finished
---
---Usage:
---  require("albertlint").setup({})
local config = require("albertlint.config")
local engine = require("albertlint.engine")

local M = {}

local NS = vim.api.nvim_create_namespace("albertlint")
local AUGROUP = "AlbertLint"

---@type table<integer, uv_timer_t>
local timers = {}
---@type table<integer, boolean>
local paused = {}

---@param bufnr integer
---@return boolean
local function attached(bufnr)
  if paused[bufnr] then
    return false
  end
  local ft = vim.bo[bufnr].filetype
  return vim.tbl_contains(config.get().filetypes, ft)
end

---Drop diagnostics that touch the word the cursor is sitting in.
---
---Without this, every live rule fires on a word in progress: `Slac` reads as a lowercase
---brand until the `k` arrives, and the diagnostic flickers on and off as you type.
---@param diagnostics vim.Diagnostic[]
---@return vim.Diagnostic[]
local function exempt_cursor_word(diagnostics)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local lnum = row - 1
  local line = vim.api.nvim_get_current_line()
  -- Word boundaries around the cursor. `col` is 0-indexed and may sit one past the last
  -- character in insert mode, which is why the scan starts at col rather than col + 1.
  local ws, we = col, col
  while ws > 0 and line:sub(ws, ws):match("[%w'%-]") do
    ws = ws - 1
  end
  while we < #line and line:sub(we + 1, we + 1):match("[%w'%-]") do
    we = we + 1
  end
  return vim.tbl_filter(function(d)
    if d.lnum ~= lnum then
      return true
    end
    -- Keep only diagnostics that end before the word starts or begin after it ends.
    return d.end_col <= ws or d.col >= we
  end, diagnostics)
end

---@param bufnr integer
---@param tier string
function M.lint(bufnr, tier)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) or not attached(bufnr) then
    return
  end
  local opts = config.get()
  local diagnostics = engine.scan(bufnr, tier, opts)

  if tier == "live" then
    -- A live pass must not clear the exit-tier diagnostics it did not compute, so the
    -- previous exit results are carried through untouched.
    local existing = vim.diagnostic.get(bufnr, { namespace = NS })
    local kept = vim.tbl_filter(function(d)
      return d.user_data and d.user_data.tier == "exit"
    end, existing)
    for _, d in ipairs(diagnostics) do
      d.user_data = { tier = "live" }
    end
    vim.list_extend(diagnostics, kept)
    if opts.skip_cursor_word and vim.api.nvim_get_current_buf() == bufnr then
      diagnostics = exempt_cursor_word(diagnostics)
    end
  else
    for _, d in ipairs(diagnostics) do
      d.user_data = { tier = d.user_data and d.user_data.tier or "exit" }
    end
  end

  vim.diagnostic.set(NS, bufnr, diagnostics)
end

---@param bufnr integer
local function schedule_live(bufnr)
  local ms = config.get().live_debounce_ms
  if timers[bufnr] then
    timers[bufnr]:stop()
    timers[bufnr]:close()
    timers[bufnr] = nil
  end
  local timer = (vim.uv or vim.loop).new_timer()
  timers[bufnr] = timer
  timer:start(ms, 0, vim.schedule_wrap(function()
    if timers[bufnr] then
      timers[bufnr]:stop()
      timers[bufnr]:close()
      timers[bufnr] = nil
    end
    M.lint(bufnr, "live")
  end))
end

---Full pass: both tiers, no cursor exemption.
---@param bufnr integer|nil
function M.lint_all(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not attached(bufnr) then
    return
  end
  local diagnostics = engine.scan(bufnr, "all", config.get())
  for _, d in ipairs(diagnostics) do
    d.user_data = { tier = "exit" }
  end
  vim.diagnostic.set(NS, bufnr, diagnostics)
end

function M.clear(bufnr)
  vim.diagnostic.reset(NS, bufnr or vim.api.nvim_get_current_buf())
end

---@param bufnr integer|nil
function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  paused[bufnr] = not paused[bufnr]
  if paused[bufnr] then
    M.clear(bufnr)
    vim.notify("albertlint paused for this buffer", vim.log.levels.INFO)
  else
    M.lint_all(bufnr)
    vim.notify("albertlint resumed", vim.log.levels.INFO)
  end
end

---Report which drilled patterns have a rule and which do not.
---
---The point is to make the gap visible. A pattern that reaches the drill list without a
---linter rule is one the plugin silently cannot help with, and that should be a fact on
---screen rather than a surprise months later.
function M.coverage()
  local rules = require("albertlint.rules")
  local lines = { "# albertlint coverage", "" }
  local by_tier = { live = {}, exit = {} }
  for _, rule in ipairs(rules.rules) do
    table.insert(by_tier[rule.tier], rule)
  end
  for _, tier in ipairs({ "live", "exit" }) do
    table.insert(lines, ("## %s tier (%d rules)"):format(tier, #by_tier[tier]))
    for _, rule in ipairs(by_tier[tier]) do
      table.insert(lines, ("- `%s`  <-  %s"):format(rule.id, rule.drill_ref))
    end
    table.insert(lines, "")
  end
  table.insert(lines, ("## optional, off by default (%d)"):format(#rules.optional))
  for _, rule in ipairs(rules.optional) do
    table.insert(lines, ("- `%s`  <-  %s"):format(rule.id, rule.drill_ref))
  end
  table.insert(lines, "")
  table.insert(lines, "## known NOT covered by any deterministic rule")
  table.insert(lines, "These need the semantic tier (`:AlbertLintSemantic`); no regex sees them.")
  for _, item in ipairs({
    "Article: missing `the` before a specific, known referent (106+ logged, his largest)",
    "Article: missing `a` before a singular count noun (25 logged)",
    "Number: subject-verb agreement across an intervening phrase",
    "Pronoun reference with two available antecedents",
    "Coordination: `not only X but also Y` branch mismatch",
    "Information structure: heavy new-information subject",
  }) do
    table.insert(lines, "- " .. item)
  end

  vim.cmd("new")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = "markdown"
  vim.bo.modified = false
end

---@param opts table|nil
function M.setup(opts)
  config.setup(opts)

  -- Namespace-scoped display so the plugin cannot fight his global diagnostic config.
  -- Underline rather than virtual text by default: prose is read left to right, and a
  -- floating message per line breaks that. The message is available on hover and on the
  -- current line only.
  local display = {
    underline = true,
    signs = false,
    severity_sort = true,
    virtual_text = false,
  }
  -- `current_line` landed in 0.11. On older versions virtual text stays off entirely,
  -- which is the safer failure.
  if vim.fn.has("nvim-0.11") == 1 then
    display.virtual_text = { current_line = true, prefix = "󰓆" }
  end
  vim.diagnostic.config(display, NS)

  local group = vim.api.nvim_create_augroup(AUGROUP, { clear = true })

  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP" }, {
    group = group,
    callback = function(ev)
      if attached(ev.buf) then
        schedule_live(ev.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged", "BufWritePost", "FileType" }, {
    group = group,
    callback = function(ev)
      if attached(ev.buf) then
        M.lint_all(ev.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(ev)
      if timers[ev.buf] then
        timers[ev.buf]:stop()
        timers[ev.buf]:close()
        timers[ev.buf] = nil
      end
      paused[ev.buf] = nil
    end,
  })

  vim.api.nvim_create_user_command("AlbertLint", function()
    M.lint_all()
  end, { desc = "albertlint: full pass on this buffer" })

  vim.api.nvim_create_user_command("AlbertLintToggle", function()
    M.toggle()
  end, { desc = "albertlint: pause or resume for this buffer" })

  vim.api.nvim_create_user_command("AlbertLintCoverage", function()
    M.coverage()
  end, { desc = "albertlint: which drilled patterns have rules" })

  vim.api.nvim_create_user_command("AlbertLintReload", function()
    for _, mod in ipairs({ "albertlint.rules", "albertlint.engine" }) do
      package.loaded[mod] = nil
    end
    engine = require("albertlint.engine")
    require("albertlint.engine").reset()
    M.lint_all()
    vim.notify("albertlint: catalogue reloaded", vim.log.levels.INFO)
  end, { desc = "albertlint: reload the rule catalogue" })

  -- Catch buffers that were already open. Every autocmd above is an event that has
  -- already fired for them, so without this sweep a lazy-loaded or re-sourced setup
  -- leaves the current buffer unlinted until the next keystroke.
  vim.schedule(function()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) and attached(bufnr) then
        M.lint_all(bufnr)
      end
    end
  end)

  vim.api.nvim_create_user_command("AlbertLintSemantic", function(cmd)
    require("albertlint.semantic").run(NS, cmd.range > 0)
  end, { range = true, desc = "albertlint: semantic pass (LLM) on paragraph or selection" })

  return M
end

M.namespace = NS
return M
