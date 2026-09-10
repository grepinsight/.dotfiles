---The spaCy process: bootstrap, lifecycle, and JSON-lines framing. Separate from `tree.lua`
---and `sentence.lua` because everything here touches the outside world and those are pure.
---
---A persistent venv, not `uv run --script`, and that is not a style preference. Measured
---2026-09-09: the first `import spacy` in a freshly created environment takes **19.6s** on
---macOS, the OS verifying a few dozen new shared objects; every later import in the same
---location takes 332 to 413ms. `uv run --script` builds a new environment per invocation, so
---it pays the 19.6s every time. Which is also why bootstrap is an explicit command: a
---twenty-second silent stall on a keystroke is indistinguishable from a hang.
local M = {}

M.SPACY = "spacy==3.8.16"
M.MODEL_WHEEL = "https://github.com/explosion/spacy-models/releases/download/"
  .. "en_core_web_sm-3.8.0/en_core_web_sm-3.8.0-py3-none-any.whl"

---@type table|nil
local proc = nil
---@type table<integer, fun(res: table)>
local pending = {}
local next_id = 0
local stdout_tail = ""

---@type table
M.state = {
  ready = false,
  starting = false,
  error = nil,
  load_ms = nil,
  last_parse_ms = nil,
  parses = 0,
  sentences_parsed = 0,
}

---@return string
function M.root()
  return vim.fs.joinpath(vim.fn.stdpath("data"), "albertlint-parse")
end

---@return string
function M.python()
  return vim.fs.joinpath(M.root(), "bin", "python")
end

---The daemon script, resolved from this file rather than hardcoded: it sits next to this one,
---so the symlink under `~/.config/nvim` resolves both together and there is no link to forget.
---@return string
function M.script()
  local source = debug.getinfo(1, "S").source:sub(2)
  return vim.fs.joinpath(vim.fs.dirname(source), "daemon.py")
end

---Is the environment usable, not merely present?
---
---Checks for the model package, not the interpreter. Checking the interpreter lied: a
---successful `uv venv` followed by a failed `uv pip install` leaves a working `bin/python`
---with no spaCy in it, and the daemon then died on `ModuleNotFoundError` three layers from
---the cause.
---@return boolean
function M.installed()
  if vim.fn.executable(M.python()) ~= 1 then
    return false
  end
  local hits = vim.fn.glob(vim.fs.joinpath(M.root(), "lib", "python*", "site-packages", "en_core_web_sm"), false, true)
  return #hits > 0
end

---@param res table
local function dispatch(res)
  local id = res.id
  if id == 0 then
    if res.error then
      M.state.error = res.error
      M.state.ready = false
    else
      M.state.ready = true
      M.state.load_ms = res.load_ms
      M.state.pipes = res.pipes
    end
    M.state.starting = false
    return
  end
  local cb = pending[id]
  pending[id] = nil
  if cb then
    cb(res)
  end
end

---@param data string|nil
local function on_stdout(_, data)
  if not data then
    return
  end
  stdout_tail = stdout_tail .. data
  while true do
    local nl = stdout_tail:find("\n")
    if not nl then
      break
    end
    local line = stdout_tail:sub(1, nl - 1)
    stdout_tail = stdout_tail:sub(nl + 1)
    if line ~= "" then
      local ok, res = pcall(vim.json.decode, line)
      if ok and type(res) == "table" then
        vim.schedule(function()
          dispatch(res)
        end)
      end
    end
  end
end

---Start the process if it is not already up.
---@return boolean started_or_running
function M.start()
  if proc then
    return true
  end
  if not M.installed() then
    M.state.error = "not bootstrapped; run :AlbertLintTreeBootstrap"
    return false
  end
  M.state.starting = true
  M.state.error = nil
  stdout_tail = ""
  proc = vim.system({ M.python(), "-u", M.script() }, {
    stdin = true,
    stdout = on_stdout,
    -- Kept, not discarded: a traceback here is the only evidence of a broken venv, and
    -- swallowing stderr is how the semantic tier stayed silently dead. Labelled, because
    -- spaCy writes deprecation warnings here too and an unlabelled one reads as fatal.
    stderr = function(_, data)
      if data and data:match("%S") then
        M.state.error = "stderr: " .. vim.trim(data)
      end
    end,
  }, function()
    vim.schedule(function()
      proc = nil
      M.state.ready = false
      M.state.starting = false
      for id, cb in pairs(pending) do
        pending[id] = nil
        cb({ id = id, error = "daemon exited" })
      end
    end)
  end)
  return true
end

function M.stop()
  if not proc then
    return
  end
  pcall(function()
    proc:write('{"id":-1,"quit":true}\n')
  end)
  -- Not killed: it exits on reading the quit line, and a kill races an in-flight request.
  proc = nil
  M.state.ready = false
end

---Parse a list of sentences. The callback gets `{ trees, parse_ms }` or `{ error }`.
---
---Queued rather than dropped while the model loads: the first sweep of a session fires well
---before the 0.5s startup completes.
---@param sentences string[]
---@param cb fun(res: table)
function M.request(sentences, cb)
  if #sentences == 0 then
    cb({ trees = {} })
    return
  end
  if not M.start() then
    cb({ error = M.state.error or "daemon unavailable" })
    return
  end
  next_id = next_id + 1
  local id = next_id
  pending[id] = function(res)
    if res.parse_ms then
      M.state.last_parse_ms = res.parse_ms
      M.state.parses = M.state.parses + 1
      M.state.sentences_parsed = M.state.sentences_parsed + #sentences
    end
    cb(res)
  end
  local payload = vim.json.encode({ id = id, sentences = sentences })
  local ok, err = pcall(function()
    proc:write(payload .. "\n")
  end)
  if not ok then
    pending[id] = nil
    cb({ error = tostring(err) })
  end
end

M.PUBLIC_INDEX = "https://pypi.org/simple"

---Create the venv and install spaCy plus the model.
---
---Noisy on purpose: 60 MB of download and a twenty-second first import, so the notifications
---are the difference between "working" and "frozen".
---
---`public_index` exists because uv may be configured against a private package index that
---is not reachable from every network, and the failure then surfaces as a DNS error four
---`Caused by:` levels deep, which reads as a bug in this plugin. So the default honours
---whatever uv is configured to use and the failure names the likely reason, while the bypass
---to public PyPI stays a deliberate second command: which index an install goes through is
---not a decision a text editor should make silently.
---@param public_index boolean|nil Install from public PyPI, ignoring the configured index
---@param on_done fun(ok: boolean, msg: string)|nil
function M.bootstrap(public_index, on_done)
  local done = on_done or function(ok, msg)
    vim.notify("albertlint: " .. msg, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
  end
  if vim.fn.executable("uv") ~= 1 then
    done(false, "uv not found on PATH; install it first (brew install uv)")
    return
  end
  local root = M.root()
  vim.notify("albertlint: creating the parser venv at " .. root, vim.log.levels.INFO)
  -- `--allow-existing`, not `--clear`, so re-running after a failed install repairs the
  -- environment instead of re-downloading it. Without it the retry dies on "a virtual
  -- environment already exists" before reaching the part that was broken.
  vim.system({ "uv", "venv", "--allow-existing", "--python", "3.12", root }, { text = true }, function(venv)
    if venv.code ~= 0 then
      vim.schedule(function()
        done(false, "uv venv failed: " .. vim.trim(venv.stderr or ""))
      end)
      return
    end
    local cmd = { "uv", "pip", "install", "--python", M.python() }
    if public_index then
      -- `--no-config` as well as `--default-index`, and the first is what actually works: a
      -- configured `[[index]]` is *added* to the search rather than replaced by the flag, so
      -- `--default-index` alone still resolves through it.
      vim.list_extend(cmd, { "--no-config", "--default-index", M.PUBLIC_INDEX })
    end
    vim.list_extend(cmd, { M.SPACY, M.MODEL_WHEEL })
    vim.schedule(function()
      vim.notify(("albertlint: installing spaCy and en_core_web_sm, about 60 MB%s")
        :format(public_index and " from public PyPI" or ""), vim.log.levels.INFO)
    end)
    vim.system(cmd, { text = true }, function(install)
      vim.schedule(function()
        if install.code ~= 0 then
          local err = vim.trim(install.stderr or "")
          local hint = ""
          if err:match("dns error") or err:match("Failed to fetch") or err:match("Connect") then
            hint = "\nThe configured package index is unreachable. If it is a private one, "
              .. "check your network and retry, or run :AlbertLintTreeBootstrap! to install "
              .. "from public PyPI instead."
          end
          done(false, "uv pip install failed: " .. err .. hint)
          return
        end
        done(true, "parser installed. The first parse takes about 20 s while macOS "
          .. "verifies the new libraries; every one after that takes about 0.5 s to start.")
      end)
    end)
  end)
end

return M
