---Configuration for albertlint.
---
---Defaults are deliberately conservative on the rules most likely to misfire. A linter
---that cries wolf in prose gets disabled within a week, so a rule earns its place in the
---default set by having a low false-positive rate, not by being high-value.
local M = {}

---@class AlbertLintConfig
---@field filetypes string[] Filetypes the linter attaches to.
---@field live_debounce_ms integer Idle time before cheap rules run while typing.
---@field skip_cursor_word boolean Exempt the word being typed from live diagnostics.
---@field disabled_rules string[] Rule ids to switch off entirely.
---@field enabled_optional string[] Ids from the opt-in rule set to switch on.
---@field severity table<string, integer> Per-rule severity overrides, keyed by rule id.
---@field semantic AlbertLintSemanticConfig
---@field level AlbertLintLevelConfig
local defaults = {
  -- Prose filetypes only. Source files are excluded because a lowercase `python` in
  -- code is correct and the linter has no business there.
  filetypes = { "markdown", "text", "gitcommit", "mail", "asciidoc", "rst", "org" },

  -- 400ms is long enough that a fast typist finishes a word before the scan lands, and
  -- short enough to feel immediate. Below ~250ms the cursor-word exemption starts doing
  -- all the work and the diagnostics flicker.
  live_debounce_ms = 400,

  -- A half-typed `Slac` must not be flagged as a lowercase brand. Without this, every
  -- rule that matches a word prefix fires on every word in progress.
  skip_cursor_word = true,

  disabled_rules = {},

  -- Rules held back from the default set because they misfire in his corpus. See
  -- rules.lua for the reason attached to each.
  enabled_optional = {},

  severity = {},

  ---@class AlbertLintSemanticConfig
  ---@field enabled boolean
  ---@field cmd string[] Command receiving the prompt on stdin, returning JSON on stdout.
  ---@field timeout_ms integer
  ---@field scope string "paragraph" | "buffer" | "selection"
  semantic = {
    enabled = true,
    -- Shells out rather than embedding an API key. The CLI already holds credentials,
    -- so the plugin never sees one. `-p` is single-shot print mode.
    --
    -- `--model sonnet` is not optional decoration. Measured 2026-08-28 on a five-line
    -- sample with an obvious missing `the`: without the flag, the CLI's default model
    -- returned `{"findings":[]}` twice in a row in 6.6s, while sonnet found the error in
    -- 34.6s. The tier was reporting nothing on visibly flawed prose, which reads as "your
    -- writing is fine" and is the worst possible failure for a linter. A slower pass that
    -- finds things beats a fast one that never does.
    cmd = { "claude", "-p", "--output-format", "text", "--model", "sonnet" },

    -- 60s, because the measurement above took 34.6s and the previous 30000 would have
    -- aborted it. Sized at roughly 1.7x the slowest observed run rather than tight to it.
    timeout_ms = 60000,

    -- "paragraph" | "buffer" | "selection". Read by `semantic.scope_range`; before
    -- 2026-08-28 it was declared here and never read.
    scope = "paragraph",
  },

  ---@class AlbertLintLevelConfig
  ---@field enabled boolean
  ---@field provider string "claude" | "openai"
  ---@field scope string "paragraph" | "buffer" | "selection"
  ---@field timeout_ms integer
  ---@field model string|nil Provider-specific model override
  level = {
    enabled = true,

    -- "claude" needs no credential in this process: the CLI already holds one, which is
    -- why the semantic tier shells out too. "openai" reads OPENAI_API_KEY from the
    -- environment and is otherwise equivalent, with the advantage that a strict
    -- json_schema makes a malformed response impossible.
    provider = "claude",

    -- "buffer", not the semantic tier's "paragraph". A level pass opens a two-window
    -- diff, and a diff over one paragraph is not worth the split. An explicit `:'<,'>`
    -- range still wins over this, as it does for the semantic tier.
    scope = "buffer",

    -- 90s against the semantic tier's 60s. Not arbitrary: a buffer-scoped pass sends the
    -- whole note where a paragraph-scoped pass sends a few lines, and the slowest
    -- measured semantic run was 34.6s on five lines.
    timeout_ms = 90000,

    -- nil means the provider's own default: sonnet for claude, pinned for the reason in
    -- the semantic block above. For openai, `provider.OPENAI_DEFAULT_MODEL` applies, and
    -- that string is NOT verified against OpenAI's current lineup as of 2026-09-08. Set
    -- this explicitly if a call returns an unknown-model error.
    model = nil,
  },
}

---@type AlbertLintConfig
M.options = vim.deepcopy(defaults)

---@param opts table|nil
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  -- tbl_deep_extend merges list-like tables by index rather than replacing them, which
  -- would silently keep a default filetype the user meant to drop. Replace outright.
  for _, key in ipairs({ "filetypes", "disabled_rules", "enabled_optional" }) do
    if opts and opts[key] then
      M.options[key] = opts[key]
    end
  end
  return M.options
end

---@return AlbertLintConfig
function M.get()
  return M.options
end

M.defaults = defaults
return M
