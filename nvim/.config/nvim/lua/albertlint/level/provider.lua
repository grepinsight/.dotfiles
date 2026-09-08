---The two backends for the graded level passes.
---
---`claude` shells out so this plugin never sees a credential: the CLI already holds them.
---`openai` needs a key, and the whole of the credential handling below exists because argv
---is world-readable through `ps`. Passing the key as `-H "Authorization: Bearer ..."` would
---expose it to every local process for the lifetime of the request, so it goes to curl on
---stdin via `--config -` instead, and the request body goes to an owner-only temp file.
---
---Transport is `curl` rather than `vim.net.request`. `vim.net` exists on 0.12 and exposes a
---single `request` function, but it is experimental, and curl gives auditable control over
---where the credential goes, which is the whole point here.
local M = {}

---The vanilla-claude invocation.
---
---The three isolation flags are not re-derived here. `util/claude.lua` already carries them
---as `raw_flags` with a measurement from 2026-08-26: `--safe-mode` alone still left 12
---skills reachable, `--disable-slash-commands` is what takes skills to zero, and
---`--strict-mcp-config` drops the MCP servers. All three are needed to actually reach "no
---skills or plugins loaded", and a test fails if this list and that one drift apart.
---
---`--model sonnet` is carried over from `config.lua` for the reason recorded there: measured
---2026-08-28, the CLI's default model returned `{"findings":[]}` twice on a five-line sample
---with an obvious missing `the`, where sonnet found it. A slower pass that finds things beats
---a fast one that never does.
M.CLAUDE_CMD = {
  "claude", "-p", "--output-format", "text", "--model", "sonnet",
  "--safe-mode", "--disable-slash-commands", "--strict-mcp-config",
}

M.OPENAI_URL = "https://api.openai.com/v1/chat/completions"

---Measured, not guessed. Chosen 2026-09-08 by running `levels.prompt(1)` against a four-line
---sample with four known errors (agreement, `an LLM`, `errors`, `The audience`), three runs per
---model, through this module's own code path. Model list taken from a live `/v1/models` call
---rather than from memory.
---
---  model          hits over 3 runs   avg s   note
---  gpt-5.5        4, 4, 4            10.1    stable, and the oldest that is
---  gpt-5.6-sol    4, 4, 4            10.7    equally stable, the expensive tier
---  gpt-6-astra    4, 3, 4            10.6    NEWEST, and not stable
---  gpt-5.6-luna   3, 3, 4             5.9    fastest of the good ones, still not stable
---  gpt-5.4-mini   2                   1.5    restated whole clauses, breaking minimal span
---  gpt-5.4-nano   0                   1.6    returned zero findings
---  gpt-4o         0, 2, 0             1.7    returned zero findings on two runs of three
---
---`gpt-4o` was this default until the measurement, and it is the reason the measurement
---happened. Zero findings on flawed prose reads as "your writing is fine", which
---`config.lua` already records as the worst failure a linter has available, from the same
---mistake in the semantic tier on 2026-08-28. Do not pick a model here without measuring.
---
---Two conclusions worth keeping. Newest is not best: `gpt-6-astra` is three months newer than
---`gpt-5.5` and less consistent on this task. And the floor is real: the nano tier does not
---merely score worse, it silently returns nothing.
---
---Cheapness of `gpt-5.5` over `gpt-5.6-sol` is inferred from it being an older generation, not
---measured; `/v1/models` does not expose pricing.
M.OPENAI_DEFAULT_MODEL = "gpt-5.5"

---@param opts table|nil
---@return string[]
function M.claude_cmd(opts)
  opts = opts or {}
  -- Copied, not returned by reference. Returned by reference, a caller's model override
  -- would rewrite the module-level default for every later call in the session.
  local cmd = {}
  for _, arg in ipairs(M.CLAUDE_CMD) do
    table.insert(cmd, arg)
  end
  if opts.model then
    -- Replaced in place rather than appended, or the CLI receives a conflicting pair.
    for i, arg in ipairs(cmd) do
      if arg == "--model" then
        cmd[i + 1] = opts.model
        break
      end
    end
  end
  return cmd
end

---curl argv. The key is deliberately absent; see `openai_config`.
---@param body_path string Path to a file holding the JSON request body
---@param opts table|nil { url }
---@return string[]
function M.openai_argv(body_path, opts)
  opts = opts or {}
  return {
    "curl", "--silent", "--show-error", "--fail-with-body",
    -- Read the auth header from stdin so it never enters argv.
    "--config", "-",
    "--header", "Content-Type: application/json",
    -- By path, not inlined: a long prose body would hit argv's length ceiling and would
    -- also be visible in ps alongside everything else.
    "--data", "@" .. body_path,
    opts.url or M.OPENAI_URL,
  }
end

---The `curl --config -` payload, delivered on stdin.
---
---This is the ONLY place the key appears. curl's config format takes one directive per
---line; `header = "..."` is equivalent to `-H`, without the argv exposure.
---@param key string
---@return string
function M.openai_config(key)
  return ('header = "Authorization: Bearer %s"\n'):format(key)
end

---@param model string
---@param prompt string
---@param text string
---@return string json
function M.openai_body(model, prompt, text)
  -- `strict` plus an explicit schema makes malformed JSON structurally impossible, which
  -- removes the whole parse-failure path that the claude backend still needs. Every field
  -- is required because an omitted `occurrence` or `label` would have to be defaulted
  -- downstream, and a schema that guarantees them is cheaper than a defaulting branch.
  local schema = {
    type = "object",
    additionalProperties = false,
    required = { "findings" },
    properties = {
      findings = {
        type = "array",
        items = {
          type = "object",
          additionalProperties = false,
          required = { "line", "quote", "occurrence", "replacement", "label", "note" },
          properties = {
            line = { type = "integer" },
            quote = { type = "string" },
            occurrence = { type = "integer" },
            replacement = { type = "string" },
            label = { type = "string" },
            note = { type = "string" },
          },
        },
      },
    },
  }
  return vim.json.encode({
    model = model,
    messages = {
      { role = "system", content = prompt },
      { role = "user", content = text },
    },
    response_format = {
      type = "json_schema",
      json_schema = { name = "albertlint_findings", strict = true, schema = schema },
    },
  })
end

---Remove anything credential-shaped from text about to be shown to the user.
---
---`vim.notify` output lands in the message history and persists there for the session, and
---curl writes the effective request to stderr under some verbosity settings. Scrub rather
---than trust. The literal environment value is scrubbed too, as a backstop for a key from a
---gateway or proxy that does not match the `sk-` shape.
---@param s string|nil
---@return string
function M.scrub(s)
  if not s then
    return ""
  end

  -- The literal value goes FIRST, before any pattern. Order is load-bearing and a test
  -- pins it: with the patterns first, a key containing an `sk-` substring anywhere in it
  -- (`GATEWAY-abc123-not-sk-shaped`) gets partially rewritten by the pattern, after which
  -- the literal match no longer finds it and a PREFIX OF THE REAL KEY survives into
  -- vim.notify. Scrubbing the exact value first makes the patterns pure backstop.
  local key = vim.env.OPENAI_API_KEY
  if key and key ~= "" then
    s = s:gsub(vim.pesc(key), "[redacted]")
  end

  s = s:gsub("[Bb]earer%s+[%w%-%._~%+/=]+", "Bearer [redacted]")
  s = s:gsub("sk%-[%w%-%._]+", "[redacted]")
  return s
end

---Pull a findings table out of whatever the backend returned.
---
---Handles three shapes: a bare object, an object inside a markdown fence (models do this
---often enough that stripping is cheaper than re-prompting), and an OpenAI chat completion
---envelope whose `content` is itself a JSON string.
---@param text string|nil
---@return table|nil parsed
---@return string|nil err
function M.parse(text)
  local json = (text or ""):match("%b{}")
  if not json then
    return nil, "no JSON object in response"
  end
  local ok, decoded = pcall(vim.json.decode, json)
  if not ok then
    return nil, "invalid JSON: " .. tostring(decoded)
  end
  if type(decoded) ~= "table" then
    return nil, "response was not an object"
  end

  -- Unwrap a chat completion envelope, whose content is a JSON string, not a table.
  if decoded.findings == nil and decoded.choices then
    local content = vim.tbl_get(decoded, "choices", 1, "message", "content")
    if type(content) == "string" then
      return M.parse(content)
    end
  end

  if decoded.findings == nil then
    return nil, "response has no `findings` key"
  end
  return decoded, nil
end

---@param name string "claude" | "openai"
---@param prompt string
---@param text string The numbered lines
---@param opts table { timeout_ms, model, url }
---@param cb fun(res: { ok: boolean, findings: table[]|nil, err: string|nil })
---@return table|nil handle A vim.system handle, or nil if the call could not start
function M.call(name, prompt, text, opts, cb)
  opts = opts or {}
  local function finish(res)
    vim.schedule(function()
      cb(res)
    end)
  end

  if name == "claude" then
    local cmd = M.claude_cmd(opts)
    if vim.fn.executable(cmd[1]) == 0 then
      finish({ ok = false, err = ("`%s` is not on PATH"):format(cmd[1]) })
      return nil
    end
    return vim.system(cmd, {
      stdin = prompt .. text,
      text = true,
      timeout = opts.timeout_ms,
    }, function(res)
      if res.code ~= 0 then
        finish({
          ok = false,
          err = ("claude exited %d: %s"):format(res.code, M.scrub(res.stderr):sub(1, 200)),
        })
        return
      end
      local parsed, err = M.parse(res.stdout or "")
      if not parsed then
        finish({ ok = false, err = err })
      else
        finish({ ok = true, findings = parsed.findings })
      end
    end)
  end

  if name == "openai" then
    local key = vim.env.OPENAI_API_KEY
    if not key or key == "" then
      -- Name the variable, never a value.
      finish({ ok = false, err = "OPENAI_API_KEY is not set in this environment" })
      return nil
    end
    if vim.fn.executable("curl") == 0 then
      finish({ ok = false, err = "`curl` is not on PATH" })
      return nil
    end

    local body_path = vim.fn.tempname() .. ".json"
    local fd = io.open(body_path, "w")
    if not fd then
      finish({ ok = false, err = "could not create a temp file for the request body" })
      return nil
    end
    fd:write(M.openai_body(opts.model or M.OPENAI_DEFAULT_MODEL, prompt, text))
    fd:close()
    -- Owner-only. The body holds the author's prose, and a world-readable file in a shared
    -- temp directory is an avoidable disclosure even with no credential in it.
    pcall((vim.uv or vim.loop).fs_chmod, body_path, tonumber("600", 8))

    return vim.system(M.openai_argv(body_path, opts), {
      stdin = M.openai_config(key),
      text = true,
      timeout = opts.timeout_ms,
    }, function(res)
      os.remove(body_path)
      if res.code ~= 0 then
        finish({
          ok = false,
          err = ("curl exited %d: %s"):format(res.code, M.scrub(res.stderr or res.stdout):sub(1, 200)),
        })
        return
      end
      local parsed, err = M.parse(res.stdout or "")
      if not parsed then
        finish({ ok = false, err = err })
      else
        finish({ ok = true, findings = parsed.findings })
      end
    end)
  end

  finish({ ok = false, err = ("unknown provider %q"):format(tostring(name)) })
  return nil
end

return M
