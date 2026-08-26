---Send a buffer range to Claude Code (`claude -p`) as a background job and park
---the reply until you ask for it.
---
---Why a job and not a terminal split: `vim.fn.jobstart` spawns `claude` as a
---separate OS process and delivers its output through Neovim's event loop, so
---the editor never blocks. This is not a Lua thread -- Neovim gives you no user
---threads here -- but the observable effect is the one you want: you keep
---editing while the model works.
---
---Flow:
---  1. `:'<,'>ClaudeAsk` captures the range. A visual selection is line-wise,
---     like every other range command in this config (see JoinURL/JoinClaude).
---  2. It asks for a prompt through `vim.ui.input`, unless one came in as args.
---  3. Prompt plus fenced selection go to `claude` on **stdin**, not argv: argv
---     has a length ceiling and would drag shell quoting into it.
---  4. On exit a `vim.notify` fires and the reply waits in a scratch buffer that
---     `:ClaudeLast` opens. Nothing steals focus mid-edit.
---
---Permissions: `--permission-mode auto` is passed so a prompt like "write a note
---about this" can actually create the file. Verified 2026-08-26 that a headless
---`-p` run under `auto` completes a file write; a mode that needed to *ask*
---would silently fail, because there is no TTY to ask on.
---
---Caveat: jobs are children of this Neovim, so `:qa` kills anything in flight.

local vault = require("util.vault")

local M = {}

local CLI = "claude"

---Guard against a stuck key turning into a fleet of CLI processes.
local MAX_IN_FLIGHT = 4

---Every job started this session, indexed by id, newest last. Never pruned: the
---count is bounded by how fast you can type, and `:ClaudeJobs` wants the history.
---@type table[]
local jobs = {}

---Id of the most recently *finished* job, which is what `:ClaudeLast` opens.
---@type integer|nil
local last_finished

---@param sink string[]
---@param data string[]|nil Chunk handed over by jobstart
local function collect(sink, data)
  if not data then
    return
  end
  for _, line in ipairs(data) do
    table.insert(sink, line)
  end
end

---Drop trailing blank lines. Buffered jobstart output ends with an empty string
---whenever the process wrote a final newline, which it always does.
---@param lines string[]
local function rstrip_blank(lines)
  while #lines > 0 and lines[#lines]:match("^%s*$") do
    table.remove(lines)
  end
end

---A fence long enough to survive the selection's own backticks. Text pulled out
---of a markdown note routinely contains ``` already, and a three-backtick fence
---would end the block early.
---@param lines string[]
---@return string
local function fence_for(lines)
  local longest = 0
  for _, line in ipairs(lines) do
    for run in line:gmatch("`+") do
      longest = math.max(longest, #run)
    end
  end
  return string.rep("`", math.max(3, longest + 1))
end

---Compose what Claude reads on stdin: the prompt, then the selection, fenced and
---labelled with its real path. The path is the one thing a literal paste would
---not carry, and it lets Claude open the file for surrounding context.
---@param prompt string
---@param sel table As returned by `capture`
---@return string
local function build_payload(prompt, sel)
  local fence = fence_for(sel.lines)
  local parts = {
    prompt,
    "",
    string.format("<selection from %s lines %d-%d>", sel.path, sel.first, sel.last),
    fence .. sel.filetype,
  }
  vim.list_extend(parts, sel.lines)
  table.insert(parts, fence)
  table.insert(parts, "</selection>")
  return table.concat(parts, "\n") .. "\n"
end

---@param opts table Command options from `nvim_create_user_command`
---@return table|nil sel nil when the range holds nothing but whitespace
local function capture(opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local first, last = opts.line1, opts.line2
  local lines = vim.api.nvim_buf_get_lines(bufnr, first - 1, last, false)

  local has_text = false
  for _, line in ipairs(lines) do
    if not line:match("^%s*$") then
      has_text = true
      break
    end
  end
  if not has_text then
    return nil
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  return {
    path = name ~= "" and name or "[unsaved buffer]",
    first = first,
    last = last,
    filetype = vim.bo[bufnr].filetype,
    lines = lines,
  }
end

---@return string[]
local function build_cmd()
  local cmd = { CLI, "-p", "--permission-mode", "auto", "--output-format", "text" }
  -- Fired from a code repo, `claude` cannot reach the Obsidian vault, so "make a
  -- note about this" has nowhere to write. Only pass the root when it is really
  -- there: vault.root() falls back to ~/Thoughts, which need not exist.
  local root = vault.root()
  if vim.fn.isdirectory(root) == 1 then
    vim.list_extend(cmd, { "--add-dir", root })
  end
  return cmd
end

---@return integer
local function in_flight()
  local count = 0
  for _, job in ipairs(jobs) do
    if not job.finished then
      count = count + 1
    end
  end
  return count
end

---@param job table
---@return string[]
local function render(job)
  local lines = {
    "# " .. job.prompt,
    "",
    string.format("- source: `%s` lines %d-%d", job.source.path, job.source.first, job.source.last),
    string.format("- exit %d in %.1fs", job.exit_code, job.elapsed),
    "",
  }
  if #job.stdout > 0 then
    vim.list_extend(lines, job.stdout)
  else
    table.insert(lines, "_(nothing on stdout)_")
  end
  if #job.stderr > 0 then
    vim.list_extend(lines, { "", "## stderr", "" })
    vim.list_extend(lines, job.stderr)
  end
  return lines
end

---Open a finished job's reply in a split, building the buffer on first ask.
---Cached on the job because a second `nvim_buf_set_name` with the same name
---would collide (E95).
---@param job table
local function open(job)
  if not (job.bufnr and vim.api.nvim_buf_is_valid(job.bufnr)) then
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, "claude://reply/" .. job.id)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, render(job))
    vim.bo[bufnr].filetype = "markdown"
    vim.bo[bufnr].modifiable = false
    job.bufnr = bufnr
  end
  vim.cmd("split")
  vim.api.nvim_win_set_buf(0, job.bufnr)
end

---@param prompt string
---@param sel table
local function start(prompt, sel)
  local job = {
    id = #jobs + 1,
    prompt = prompt,
    source = sel,
    stdout = {},
    stderr = {},
    started_ns = vim.loop.hrtime(),
    finished = false,
  }

  local chan = vim.fn.jobstart(build_cmd(), {
    cwd = vim.fn.getcwd(),
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      collect(job.stdout, data)
    end,
    on_stderr = function(_, data)
      collect(job.stderr, data)
    end,
    on_exit = function(_, code)
      job.finished = true
      job.exit_code = code
      job.elapsed = (vim.loop.hrtime() - job.started_ns) / 1e9
      rstrip_blank(job.stdout)
      rstrip_blank(job.stderr)
      last_finished = job.id
      vim.schedule(function()
        if code == 0 then
          vim.notify(
            string.format("Claude #%d done (%.0fs) -- :ClaudeLast", job.id, job.elapsed),
            vim.log.levels.INFO
          )
        else
          -- Report the failure rather than leaving a job that never speaks up.
          local tail = job.stderr[#job.stderr] or "nothing on stderr"
          vim.notify(
            string.format("Claude #%d failed (exit %d): %s -- :ClaudeLast", job.id, code, tail),
            vim.log.levels.ERROR
          )
        end
      end)
    end,
  })

  if chan <= 0 then
    vim.notify(
      string.format("ClaudeAsk: could not start `%s` (jobstart returned %d)", CLI, chan),
      vim.log.levels.ERROR
    )
    return
  end

  job.chan = chan
  table.insert(jobs, job)
  vim.fn.chansend(chan, build_payload(prompt, sel))
  vim.fn.chanclose(chan, "stdin")
  vim.notify(string.format("Claude #%d started (%d lines)", job.id, #sel.lines), vim.log.levels.INFO)
end

---`:'<,'>ClaudeAsk [prompt]`
---@param opts table
function M.ask(opts)
  if vim.fn.executable(CLI) ~= 1 then
    vim.notify(string.format("ClaudeAsk: `%s` is not on $PATH", CLI), vim.log.levels.ERROR)
    return
  end

  local running = in_flight()
  if running >= MAX_IN_FLIGHT then
    vim.notify(
      string.format("ClaudeAsk: %d jobs already running (cap %d) -- see :ClaudeJobs", running, MAX_IN_FLIGHT),
      vim.log.levels.WARN
    )
    return
  end

  -- Capture before prompting. `vim.ui.input` is async, and the cursor or even
  -- the current buffer can move while its prompt is open.
  local sel = capture(opts)
  if not sel then
    vim.notify("ClaudeAsk: selection is empty", vim.log.levels.WARN)
    return
  end

  local args = vim.trim(opts.args or "")
  if args ~= "" then
    start(args, sel)
    return
  end

  vim.ui.input({ prompt = "Claude: " }, function(input)
    if not input or vim.trim(input) == "" then
      vim.notify("ClaudeAsk: cancelled", vim.log.levels.INFO)
      return
    end
    start(vim.trim(input), sel)
  end)
end

---`:ClaudeLast`
function M.last()
  if not last_finished then
    local running = in_flight()
    if running > 0 then
      vim.notify(string.format("ClaudeLast: nothing finished yet (%d running)", running), vim.log.levels.INFO)
    else
      vim.notify("ClaudeLast: no jobs this session", vim.log.levels.WARN)
    end
    return
  end
  open(jobs[last_finished])
end

---`:ClaudeJobs`
function M.list()
  if #jobs == 0 then
    vim.notify("ClaudeJobs: no jobs this session", vim.log.levels.INFO)
    return
  end

  local rows = {}
  for _, job in ipairs(jobs) do
    local status
    if not job.finished then
      status = string.format("running %.0fs", (vim.loop.hrtime() - job.started_ns) / 1e9)
    elseif job.exit_code == 0 then
      status = string.format("done %.0fs", job.elapsed)
    else
      status = string.format("exit %d", job.exit_code)
    end
    table.insert(rows, string.format("#%d  %-14s  %s", job.id, status, job.prompt))
  end
  vim.api.nvim_echo({ { table.concat(rows, "\n") } }, false, {})
end

return M
