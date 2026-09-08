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
    vim.notify("albertlint: automatic diagnostics paused and cleared for this buffer", vim.log.levels.INFO)
  else
    M.lint_all(bufnr)
    vim.notify("albertlint: automatic diagnostics resumed for this buffer", vim.log.levels.INFO)
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
    "Article: missing `the` before a specific, known referent (129 logged as of 2026-09-08, his largest)",
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
  -- Kept so `:AlbertLintReload` can re-apply them after clearing `albertlint.config`,
  -- which otherwise resets `options` to the file's defaults and drops these silently.
  M._opts = opts

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
  end, { desc = "albertlint: run the free deterministic checks on this buffer (not the LLM one)" })

  vim.api.nvim_create_user_command("AlbertLintToggle", function()
    M.toggle()
  end, { desc = "albertlint: pause or resume the automatic diagnostics in this buffer" })

  vim.api.nvim_create_user_command("AlbertLintCoverage", function()
    M.coverage()
  end, { desc = "albertlint: which logged mistake patterns have a rule, and which cannot" })

  vim.api.nvim_create_user_command("AlbertLintReload", function()
    -- `semantic` and `config` are in this list because they were not, and it cost a real
    -- debugging session: a fix that taught `semantic.lua` to read `config.semantic.scope`
    -- could not be picked up by any command, so setting the option at runtime wrote to a
    -- field the loaded module never read, and the pass silently kept its old behaviour.
    -- A command called Reload should mean "pick up my edits to this plugin".
    for _, mod in ipairs({
      "albertlint.rules",
      "albertlint.engine",
      "albertlint.semantic",
      "albertlint.config",
      "albertlint.collocation.index",
      -- The level tier, on this list for exactly the reason `semantic` is: a fix that the
      -- command called Reload cannot pick up costs a full restart to test.
      "albertlint.level",
      "albertlint.level.apply",
      "albertlint.level.levels",
      "albertlint.level.provider",
      "albertlint.level.diffview",
    }) do
      package.loaded[mod] = nil
    end

    -- Reloading `config` resets `options` to the file's defaults, which would silently
    -- discard whatever was passed to `setup()`. Re-applying the stored opts is what keeps
    -- reload a no-op for configuration while still picking up new default values.
    config = require("albertlint.config")
    config.setup(M._opts)

    engine = require("albertlint.engine")
    engine.reset()
    M.lint_all()
    vim.notify("albertlint: rules, engine, semantic, level, and config reloaded. Restart Neovim to pick up "
      .. "changes to init.lua or to the commands themselves.", vim.log.levels.INFO)
  end, { desc = "albertlint: reload rules, engine, semantic, level, and config" })

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
  end, { range = true, desc = "albertlint: LLM grammar check over the configured scope, or a given range" })

  vim.api.nvim_create_user_command("AlbertLintSemanticCancel", function()
    require("albertlint.semantic").cancel()
  end, { desc = "albertlint: stop the LLM grammar check running in this buffer" })

  -- The graded level tiers. Unlike every other tier here, these produce replacement prose
  -- with an accept key, which is a scoped and deliberate exception to the doctrine in
  -- CLAUDE.md rather than an oversight. Read that section before changing this.
  -- Bang forces a fresh pass. Without it the command serves the cached findings, so the
  -- diff can be closed and reopened without paying for the call twice.
  vim.api.nvim_create_user_command("AlbertLintLevel1", function(cmd)
    require("albertlint.level").run(1, cmd.range > 0, cmd.bang)
  end, {
    range = true,
    bang = true,
    desc = "albertlint: level 1 (grammar/usage) as a reviewable diff. ! re-runs, ignoring the cache",
  })

  vim.api.nvim_create_user_command("AlbertLintLevelClearCache", function()
    local level = require("albertlint.level")
    vim.notify(
      level.clear_cache() and "albertlint: cached level findings dropped for this buffer"
        or "albertlint: nothing cached for this buffer",
      vim.log.levels.INFO
    )
  end, { desc = "albertlint: forget the cached level findings for this buffer" })

  -- Vim merges adjacent changed lines into one hunk, so `do` on two findings that landed
  -- on consecutive lines takes both. These are line-scoped, for when that matters.
  vim.api.nvim_create_user_command("AlbertLintLevelAccept", function()
    require("albertlint.level").accept_line()
  end, { desc = "albertlint: accept only the line under the cursor, not the whole hunk" })

  vim.api.nvim_create_user_command("AlbertLintLevelReject", function()
    require("albertlint.level").reject_line()
  end, { desc = "albertlint: reject only the line under the cursor, not the whole hunk" })

  vim.api.nvim_create_user_command("AlbertLintLevelClose", function()
    require("albertlint.level").close()
  end, { desc = "albertlint: close the level diff and leave diff mode" })

  vim.api.nvim_create_user_command("AlbertLintLevelCancel", function()
    require("albertlint.level").cancel()
  end, { desc = "albertlint: stop the level pass running in this buffer" })

  -- One place that answers "is this thing working". Added because the question came up
  -- repeatedly and the honest answer needed four separate commands plus reading source.
  vim.api.nvim_create_user_command("AlbertLintStatus", function()
    local cfg = config.get()
    local bufnr = vim.api.nvim_get_current_buf()
    local lines = {
      ("filetype %s: %s"):format(
        vim.bo[bufnr].filetype,
        vim.tbl_contains(cfg.filetypes, vim.bo[bufnr].filetype) and "attached" or "not a configured prose filetype"
      ),
      ("automatic diagnostics: %s"):format(attached(bufnr) and "on" or "paused"),
      ("semantic: %s, scope %s, timeout %dms, `%s` %s"):format(
        cfg.semantic.enabled and "enabled" or "disabled",
        cfg.semantic.scope or "paragraph",
        cfg.semantic.timeout_ms,
        cfg.semantic.cmd[1],
        vim.fn.executable(cfg.semantic.cmd[1]) == 1 and "found" or "NOT ON PATH"
      ),
      ("level: %s, provider %s, scope %s, timeout %dms%s"):format(
        cfg.level.enabled and "enabled" or "disabled",
        cfg.level.provider,
        cfg.level.scope,
        cfg.level.timeout_ms,
        -- Report only whether the credential is PRESENT, never any part of its value.
        cfg.level.provider == "openai"
            and ((vim.env.OPENAI_API_KEY or "") ~= "" and ", OPENAI_API_KEY set" or ", OPENAI_API_KEY NOT SET")
          or ""
      ),
    }

    -- Reported rather than assumed: the collocation module is optional, and a missing one
    -- should show up here as "not loaded" instead of erroring this command.
    local ok, collocation = pcall(require, "albertlint.collocation")
    if ok then
      local entries = collocation.entries()
      table.insert(lines, ("collocation: %d entries from %s"):format(#entries, collocation.root()))
    else
      table.insert(lines, "collocation: not loaded")
    end

    vim.notify("albertlint status\n  " .. table.concat(lines, "\n  "), vim.log.levels.INFO)
  end, { desc = "albertlint: report what is on, what scope, and whether the CLI is reachable" })

  return M
end

M.namespace = NS
return M
