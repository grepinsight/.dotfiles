---Send a buffer range, plus surrounding context, to Claude Code (`claude -p`) as
---a background job and park the reply until you ask for it.
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
---  3. Prompt, context and selection go to `claude` on **stdin**, not argv: argv
---     has a length ceiling and would drag shell quoting into it.
---  4. On exit a `vim.notify` fires and the reply waits in a scratch buffer that
---     `:ClaudeLast` opens. Nothing steals focus mid-edit.
---
---Context is sent as the lines *outside* the selection, in `<context-before>`
---and `<context-after>` blocks. That keeps one code path for both "N lines
---either side" and "the whole buffer" (`full` just removes the bound), and the
---selection never appears twice in the payload.
---
---Per-call override, parsed off the front of the command args:
---     :'<,'>ClaudeAsk +full  summarize this
---     :'<,'>ClaudeAsk +120   what breaks here
---     :'<,'>ClaudeAsk +0     fix this typo
---Only command args are parsed. Text typed at the `vim.ui.input` prompt never
---is, which is the escape hatch when a prompt really does start with "+1".
---
---Replies live in an unlisted scratch buffer, not on disk: `claude://reply/N` is
---a buffer name, not a path, and it dies with the session. To keep one, either
---`:ClaudeSave {path}` (verbatim) or `:ClaudeExport` (a vault note carrying this
---vault's frontmatter shape, after a prompt for which of the three vaults).
---
---`:ClaudeRaw` is `:ClaudeAsk` with the customisations off. Measured 2026-08-26:
---`--safe-mode` alone still left 12 skills reachable, so `--disable-slash-commands`
---is needed to actually reach zero, and `--strict-mcp-config` drops the MCP
---servers. Use it when the surrounding config would only get in the way.
---
---Permissions: `--permission-mode auto` is passed so a prompt like "write a note
---about this" can actually create the file. Verified 2026-08-26 that a headless
---`-p` run under `auto` completes a file write; a mode that needed to *ask*
---would silently fail, because there is no TTY to ask on.
---
---Skills, plugins and MCP servers load by default, which is what lets "make a
---note about this" reach the vault skills. Measured 2026-08-26: 180 skills and
---~160 MCP tools, costing ~2s of a ~7.6s trivial round trip. Set
---`M.strict_mcp = true` to drop the MCP servers -- worth it to cut system-prompt
---tokens on small edits, not worth it for latency.
---
---Caveat: jobs are children of this Neovim, so `:qa` kills anything in flight.

local vault = require("util.vault")

local M = {}

---Lines of context on each side of the selection. A non-negative integer, or
---`"full"` for the whole buffer. Override per call with a `+N` / `+full` token.
M.context = 40

---Model alias passed to `--model`. Sonnet handles selection rewrites and note
---drafts; escalate per call by adding a `+opus`-style token if that ever pays.
M.model = "sonnet"

---Pass `--strict-mcp-config`, dropping every MCP server. Cuts system-prompt
---tokens rather than wall clock (see the header note).
M.strict_mcp = false

---Ceiling on total lines sent (context + selection). Past this, context is
---trimmed toward the selection and both the payload and a notify say so. The
---selection itself is never trimmed.
M.max_lines = 2000

---Subfolder inside the chosen vault that `:ClaudeExport` writes into.
M.export_dir = "03-Resources/Claude"

---Flags for `:ClaudeRaw`. All three are needed: `--safe-mode` on its own still
---left 12 skills reachable when measured, `--disable-slash-commands` takes skills
---to zero, and `--strict-mcp-config` drops the MCP servers.
M.raw_flags = { "--safe-mode", "--disable-slash-commands", "--strict-mcp-config" }

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

---A fence long enough to survive the payload's own backticks. Text pulled out of
---a markdown note routinely contains ``` already, and a three-backtick fence
---would end the block early. Computed once across every emitted line so the
---three blocks cannot disagree.
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

---`M.context`, defended against a bad value in someone's config.
---@return integer|string
local function default_context()
  if M.context == "full" then
    return "full"
  end
  local n = tonumber(M.context)
  if not n or n < 0 then
    vim.notify(
      string.format("ClaudeAsk: M.context is %s, expected a number >= 0 or \"full\"; using 0", vim.inspect(M.context)),
      vim.log.levels.WARN
    )
    return 0
  end
  return math.floor(n)
end

---Split a leading `+N` / `+full` context token off the command args.
---@param args string
---@return integer|string context
---@return string prompt
local function split_context(args)
  local token, rest = args:match("^(%S+)%s*(.*)$")
  if not token then
    return default_context(), args
  end
  if token == "+full" then
    return "full", rest
  end
  local n = token:match("^%+(%d+)$")
  if n then
    return tonumber(n), rest
  end
  return default_context(), args
end

---Context line ranges on each side of the selection, clamped to the buffer.
---`full` is this same computation with the bound removed, which is why there is
---one code path rather than a whole-buffer special case.
---@param bufnr integer
---@param first integer
---@param last integer
---@param context integer|string
---@return table|nil before
---@return table|nil after
local function context_ranges(bufnr, first, last, context)
  if context == 0 then
    return nil, nil
  end

  local total = vim.api.nvim_buf_line_count(bufnr)
  local span = context == "full" and total or context

  local before
  local b_from = math.max(1, first - span)
  if b_from <= first - 1 then
    before = { from = b_from, to = first - 1 }
  end

  local after
  local a_to = math.min(total, last + span)
  if last + 1 <= a_to then
    after = { from = last + 1, to = a_to }
  end

  return before, after
end

---Shrink context to fit `M.max_lines`, keeping the lines nearest the selection
---and never touching the selection itself. Records what was dropped: a silent
---truncation would read as full context, which is the one thing it must not.
---@param sel table
local function apply_cap(sel)
  local sel_n = #sel.lines
  local before_n = sel.before and #sel.before.lines or 0
  local after_n = sel.after and #sel.after.lines or 0
  local total = sel_n + before_n + after_n
  if total <= M.max_lines then
    return
  end

  -- Pin the cap in force right now: the reply is rendered later, and M.max_lines
  -- may have changed by then.
  sel.cap = M.max_lines
  local budget = math.max(0, M.max_lines - sel_n)
  local keep_after = math.min(after_n, math.floor(budget / 2))
  -- Hand any slack from a short side back to the other, so a selection near the
  -- top of a file still gets a full budget's worth of trailing context.
  local keep_before = math.min(before_n, budget - keep_after)
  keep_after = math.min(after_n, budget - keep_before)

  sel.dropped = (before_n - keep_before) + (after_n - keep_after)

  if keep_before == 0 then
    sel.before = nil
  elseif keep_before < before_n then
    local b = sel.before
    b.lines = vim.list_slice(b.lines, before_n - keep_before + 1, before_n)
    b.from = b.to - keep_before + 1
  end

  if keep_after == 0 then
    sel.after = nil
  elseif keep_after < after_n then
    local a = sel.after
    a.lines = vim.list_slice(a.lines, 1, keep_after)
    a.to = a.from + keep_after - 1
  end
end

---@param opts table Command options from `nvim_create_user_command`
---@param context integer|string
---@return table|nil sel nil when the range holds nothing but whitespace
local function capture(opts, context)
  local bufnr = vim.api.nvim_get_current_buf()
  local first, last = opts.line1, opts.line2

  local function slice(from, to)
    return vim.api.nvim_buf_get_lines(bufnr, from - 1, to, false)
  end

  local lines = slice(first, last)
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
  local sel = {
    path = name ~= "" and name or "[unsaved buffer]",
    first = first,
    last = last,
    filetype = vim.bo[bufnr].filetype,
    modified = vim.bo[bufnr].modified,
    context = context,
    lines = lines,
  }

  local before, after = context_ranges(bufnr, first, last, context)
  if before then
    sel.before = { from = before.from, to = before.to, lines = slice(before.from, before.to) }
  end
  if after then
    sel.after = { from = after.from, to = after.to, lines = slice(after.from, after.to) }
  end
  apply_cap(sel)

  return sel
end

---Compose what Claude reads on stdin. Each block is labelled with its real line
---range: the path is the one thing a literal paste would not carry, and it lets
---Claude open the file for anything beyond what was sent.
---@param prompt string
---@param sel table
---@return string
local function build_payload(prompt, sel)
  local everything = vim.list_extend({}, sel.lines)
  if sel.before then
    vim.list_extend(everything, sel.before.lines)
  end
  if sel.after then
    vim.list_extend(everything, sel.after.lines)
  end
  local fence = fence_for(everything)

  local parts = { prompt, "" }

  if sel.dropped and sel.dropped > 0 then
    table.insert(
      parts,
      string.format(
        "(context truncated to stay under %d lines: %d lines dropped, the ones nearest the selection kept)",
        sel.cap,
        sel.dropped
      )
    )
    table.insert(parts, "")
  end

  ---@param tag string
  ---@param from integer
  ---@param to integer
  ---@param lines string[]
  ---@param note string
  local function block(tag, from, to, lines, note)
    table.insert(parts, string.format("<%s %s lines %d-%d%s>", tag, sel.path, from, to, note))
    table.insert(parts, fence .. sel.filetype)
    vim.list_extend(parts, lines)
    table.insert(parts, fence)
    table.insert(parts, string.format("</%s>", tag))
    table.insert(parts, "")
  end

  if sel.before then
    block("context-before", sel.before.from, sel.before.to, sel.before.lines, "")
  end

  -- Claude has the path and the cwd, so it may read the file from disk. Say when
  -- that would be stale.
  local note = sel.modified and " -- buffer has unsaved changes, the text below is authoritative" or ""
  block("selection", sel.first, sel.last, sel.lines, note)

  if sel.after then
    block("context-after", sel.after.from, sel.after.to, sel.after.lines, "")
  end

  return table.concat(parts, "\n")
end

---@param raw boolean|nil Strip skills, plugins, hooks, CLAUDE.md and MCP
---@return string[]
local function build_cmd(raw)
  local cmd = {
    CLI,
    "-p",
    "--permission-mode",
    "auto",
    "--output-format",
    "text",
    "--model",
    M.model,
  }
  if raw then
    -- Nothing but the model: no skills, plugins, hooks, CLAUDE.md or MCP. The
    -- vault --add-dir is pointless here, since raw mode cannot reach the skills
    -- that would write a note.
    vim.list_extend(cmd, M.raw_flags)
    return cmd
  end
  if M.strict_mcp then
    table.insert(cmd, "--strict-mcp-config")
  end
  -- Fired from a code repo, `claude` cannot reach the Obsidian vault, so "make a
  -- note about this" has nowhere to write. Only pass the root when it is really
  -- there: vault.root() falls back to ~/Thoughts, which need not exist.
  local root = vault.root()
  if vim.fn.isdirectory(root) == 1 then
    vim.list_extend(cmd, { "--add-dir", root })
  end
  return cmd
end

---How much context a job actually carried, for the reply header and :ClaudeJobs.
---@param sel table
---@return string
local function context_label(sel)
  if sel.context == 0 then
    return "none"
  end
  local spec = sel.context == "full" and "full" or tostring(sel.context)
  local label = string.format(
    "%s (before %d, after %d)",
    spec,
    sel.before and #sel.before.lines or 0,
    sel.after and #sel.after.lines or 0
  )
  if sel.dropped and sel.dropped > 0 then
    label = label .. string.format(", %d dropped by the %d-line cap", sel.dropped, sel.cap)
  end
  return label
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

---A single-line H1 for a prompt that may be many lines long.
---
---A prompt typed at the input prompt or on the command line is one line, but a
---canned one (`:ClaudeAnalyze`) is a whole spec. Both other options are wrong:
---`nvim_buf_set_lines` rejects an embedded newline outright, and quietly keeping
---only the first line reads as if that were the whole prompt. So keep the first
---line and say how many followed.
---@param prompt string
---@return string
local function heading(prompt)
  local parts = vim.split(prompt, "\n", { plain = true })
  while #parts > 1 and parts[#parts] == "" do
    table.remove(parts)
  end
  if #parts == 1 then
    return "# " .. parts[1]
  end
  return string.format("# %s _(+%d more prompt lines)_", parts[1], #parts - 1)
end

---@param job table
---@return string[]
local function render(job)
  local lines = {
    heading(job.prompt),
    "",
    string.format("- source: `%s` lines %d-%d", job.source.path, job.source.first, job.source.last),
    string.format("- context: %s", context_label(job.source)),
    string.format("- model: %s%s", M.model, job.raw and " (raw: no skills, plugins, CLAUDE.md or MCP)" or ""),
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
---@param raw boolean|nil
local function start(prompt, sel, raw)
  local job = {
    id = #jobs + 1,
    prompt = prompt,
    source = sel,
    raw = raw or false,
    stdout = {},
    stderr = {},
    started_ns = vim.loop.hrtime(),
    finished = false,
  }

  local chan = vim.fn.jobstart(build_cmd(raw), {
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

  if sel.dropped and sel.dropped > 0 then
    vim.notify(
      string.format("ClaudeAsk: context capped at %d lines, %d dropped", sel.cap, sel.dropped),
      vim.log.levels.WARN
    )
  end
  vim.notify(
    string.format(
      "Claude #%d started (%d lines, context %s)%s",
      job.id,
      #sel.lines,
      context_label(sel),
      raw and " [raw]" or ""
    ),
    vim.log.levels.INFO
  )
end

---`:'<,'>ClaudeAsk [+N|+full] [prompt]`
---@param opts table
---@param cfg table|nil {raw=boolean}
function M.ask(opts, cfg)
  cfg = cfg or {}
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

  local context, prompt = split_context(vim.trim(opts.args or ""))

  -- Capture before prompting. `vim.ui.input` is async, and the cursor or even
  -- the current buffer can move while its prompt is open.
  local sel = capture(opts, context)
  if not sel then
    vim.notify("ClaudeAsk: selection is empty", vim.log.levels.WARN)
    return
  end

  if prompt ~= "" then
    start(prompt, sel, cfg.raw)
    return
  end

  vim.ui.input({ prompt = cfg.raw and "Claude (raw): " or "Claude: " }, function(input)
    if not input or vim.trim(input) == "" then
      vim.notify("ClaudeAsk: cancelled", vim.log.levels.INFO)
      return
    end
    start(vim.trim(input), sel, cfg.raw)
  end)
end

---Fold a canned prompt into command args.
---
---A canned-prompt command has to keep its own prompt without throwing away words
---the caller typed: `:ClaudeAnalyze just the verbs` should still run the analysis,
---with "just the verbs" narrowing it. So a leading context token stays out front
---where `split_context` can still find it, and anything else is appended to the
---prompt instead of becoming a prompt of its own.
---
---Only a real `+N` / `+full` token may sit in front. A token-shaped word that is
---not one (`+opus`) belongs to the caller, and leaving it there would let
---`split_context` drop it on the floor.
---@param base string Canned prompt
---@param args string Raw `opts.args`
---@return string args Rewritten, safe to hand to M.ask
function M.merge_prompt(base, args)
  args = vim.trim(args or "")
  if args == "" then
    return base
  end

  local token, rest = args:match("^(%S+)%s*(.*)$")
  if token == "+full" or (token and token:match("^%+%d+$")) then
    args = rest
  else
    token = nil
  end

  local prompt = base
  if args ~= "" then
    prompt = prompt .. "\n\nAdditional instruction from the caller: " .. args
  end

  return token and (token .. " " .. prompt) or prompt
end

---Turn a canned prompt into a command callback: `:'<,'>Cmd` then behaves like
---`:'<,'>ClaudeAsk <prompt>`, `+N` / `+full` included, but never opens the input
---prompt because the prompt is already known.
---@param base string Canned prompt
---@param cfg table|nil {raw=boolean}, forwarded to M.ask
---@return fun(opts: table)
function M.with_prompt(base, cfg)
  return function(opts)
    local merged = vim.tbl_extend("force", {}, opts)
    merged.args = M.merge_prompt(base, opts.args or "")
    -- fargs would now disagree with args. M.ask does not read it, but leaving a
    -- contradiction in opts is a trap for whoever reads it next.
    merged.fargs = nil
    M.ask(merged, cfg)
  end
end

---Vaults that exist on this machine, in the order CLAUDE.md lists them. Only the
---ones whose directory is really there: the env vars are machine-local, and a
---GUI-launched Neovim may not have inherited them at all.
---@return table[] Each {label=string, root=string}
local function vault_choices()
  local specs = {
    { label = "Thoughts (personal / non-work)", root = vault.root() },
    { label = "Work (infra, internal systems)", root = vim.env.OBSIDIAN_VAULT_WORK },
    { label = "Work-Personal (work projects)", root = vim.env.OBSIDIAN_VAULT_WORK_PERSONAL },
  }
  local found = {}
  for _, spec in ipairs(specs) do
    if spec.root and spec.root ~= "" then
      local root = vim.fs.normalize(spec.root)
      if vim.fn.isdirectory(root) == 1 then
        table.insert(found, { label = spec.label, root = root })
      end
    end
  end
  return found
end

---The job a save/export acts on: an explicit count (`:3ClaudeSave ...`) or the
---most recently finished one.
---@param opts table|nil
---@return table|nil
local function target_job(opts)
  local id = (opts and opts.count and opts.count > 0) and opts.count or last_finished
  if not id then
    vim.notify("Claude: no finished job to act on", vim.log.levels.WARN)
    return nil
  end
  local job = jobs[id]
  if not job then
    vim.notify(string.format("Claude: no job #%d this session", id), vim.log.levels.WARN)
    return nil
  end
  if not job.finished then
    vim.notify(string.format("Claude: job #%d is still running", id), vim.log.levels.WARN)
    return nil
  end
  return job
end

---@param path string
---@param lines string[]
---@param force boolean|nil Overwrite an existing file
---@return boolean ok
local function write_lines(path, lines, force)
  if vim.fn.filereadable(path) == 1 and not force then
    vim.notify(string.format("Claude: %s exists (add ! to overwrite)", path), vim.log.levels.ERROR)
    return false
  end
  local dir = vim.fs.dirname(path)
  if vim.fn.isdirectory(dir) == 0 and vim.fn.mkdir(dir, "p") == 0 then
    vim.notify(string.format("Claude: could not create %s", dir), vim.log.levels.ERROR)
    return false
  end
  if vim.fn.writefile(lines, path) ~= 0 then
    vim.notify(string.format("Claude: could not write %s", path), vim.log.levels.ERROR)
    return false
  end
  return true
end

---A filename-safe but still readable stand-in for the prompt.
---@param text string
---@return string
local function slugify(text)
  local out = text:gsub("[/\\:%*%?\"<>|%c]", " ")
  out = out:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if out == "" then
    out = "reply"
  end
  if #out > 60 then
    -- Trim back to a word boundary rather than cutting mid-word.
    out = out:sub(1, 60):gsub("%s+%S*$", "")
  end
  return out
end

---First free `stem.md`, `stem (2).md`, ... so an export never clobbers.
---@param dir string
---@param stem string
---@return string
local function unique_path(dir, stem)
  local path = vim.fs.joinpath(dir, stem .. ".md")
  local n = 2
  while vim.fn.filereadable(path) == 1 do
    path = vim.fs.joinpath(dir, string.format("%s (%d).md", stem, n))
    n = n + 1
  end
  return path
end

---A vault note: this vault's frontmatter shape, then the reply. The draft warning
---is not decoration -- CLAUDE.md requires generated output to stay labelled until
---a human has validated it.
---@param job table
---@return string[]
local function render_note(job)
  local today = os.date("%Y-%m-%d")
  local lines = {
    "---",
    "aliases:",
    "  - " .. slugify(job.prompt),
    "tags:",
    "  - claude-reply",
    "created_at: " .. today,
    "modified_at: " .. today,
    "---",
    "",
    "> [!warning] Unreviewed draft",
    "> Generated by `:ClaudeAsk` in Neovim and not yet reviewed by a human.",
    "",
  }
  vim.list_extend(lines, render(job))
  return lines
end

---`:[count]ClaudeSave[!] {path}` -- the reply verbatim, no frontmatter.
---@param opts table
function M.save(opts)
  local job = target_job(opts)
  if not job then
    return
  end
  local path = vim.fn.expand(vim.trim(opts.args or ""))
  if path == "" then
    vim.notify("ClaudeSave: needs a path", vim.log.levels.ERROR)
    return
  end
  if write_lines(path, render(job), opts.bang) then
    vim.notify(string.format("Claude #%d saved to %s", job.id, path), vim.log.levels.INFO)
  end
end

---`:[count]ClaudeExport` -- a vault note, after asking which vault.
---@param opts table
function M.export(opts)
  local job = target_job(opts)
  if not job then
    return
  end

  local choices = vault_choices()
  if #choices == 0 then
    vim.notify("ClaudeExport: no vault directory found (check $OBSIDIAN_VAULT*)", vim.log.levels.ERROR)
    return
  end

  local function write_to(choice)
    local dir = vim.fs.joinpath(choice.root, M.export_dir)
    local stem = string.format("Claude - %s (%s)", slugify(job.prompt), os.date("%Y-%m-%d"))
    local path = unique_path(dir, stem)
    -- force: unique_path already guaranteed there is nothing to clobber.
    if write_lines(path, render_note(job), true) then
      vim.notify(string.format("Claude #%d exported to %s", job.id, path), vim.log.levels.INFO)
    end
  end

  -- One vault leaves nothing to choose, so do not ask.
  if #choices == 1 then
    write_to(choices[1])
    return
  end

  local labels = {}
  for _, choice in ipairs(choices) do
    table.insert(labels, choice.label)
  end
  vim.ui.select(labels, { prompt = "Export to which vault?" }, function(_, idx)
    if not idx then
      vim.notify("ClaudeExport: cancelled", vim.log.levels.INFO)
      return
    end
    write_to(choices[idx])
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
    local ctx = job.source.context == "full" and "full" or tostring(job.source.context)
    table.insert(rows, string.format("#%d  %-14s  ctx %-5s  %s", job.id, status, ctx, job.prompt))
  end
  vim.api.nvim_echo({ { table.concat(rows, "\n") } }, false, {})
end

return M
