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
    cmd = { "claude", "-p", "--output-format", "text" },
    timeout_ms = 30000,
    scope = "paragraph",
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
