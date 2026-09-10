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
  ---@field timeout_ms integer|nil
  ---@field model string|nil Provider-specific model override
  ---@field mode string "finishing" | "practice"
  level = {
    enabled = true,

    -- "finishing" | "practice".
    --
    -- In finishing mode a finding that is unambiguous and meaning-preserving arrives as a
    -- diff hunk you can accept with `do`. In practice mode every finding is demoted to a
    -- question, so even `a error` -> `an error` has to be typed.
    --
    -- The distinction comes from an adversarial review on 2026-09-10, which pointed out
    -- that authorship and practice are different objectives and that this config had been
    -- bundling them: the stated goal, "to actually HAVE me write", is about practice, while
    -- accepting a correction you understand is a perfectly authorial act. Rather than the
    -- tool guessing which one a given session is for, it is a flag.
    --
    -- Default is "finishing" because that is what was asked for and confirmed. Set
    -- "practice" for a session where the point is the drill rather than the draft.
    mode = "finishing",

    -- "claude" needs no credential in this process: the CLI already holds one, which is
    -- why the semantic tier shells out too. "openai" reads OPENAI_API_KEY from the
    -- environment and is otherwise equivalent, with the advantage that a strict
    -- json_schema makes a malformed response impossible.
    provider = "claude",

    -- "buffer", not the semantic tier's "paragraph". A level pass opens a two-window
    -- diff, and a diff over one paragraph is not worth the split. An explicit `:'<,'>`
    -- range still wins over this, as it does for the semantic tier.
    scope = "buffer",

    -- nil means scale the timeout to how many lines are being sent; see `timeout_for` in
    -- level/init.lua for the measurements. A fixed value cannot serve both a paragraph and
    -- a whole note: 90s was shipped on 2026-09-08 after timing 4-line samples, and a
    -- 190-line note measured 105.6s the same day, so a real buffer was killed mid-answer
    -- after the model had already produced 74 findings. Set a number here to pin it.
    timeout_ms = nil,

    -- nil means the provider's own default, and both are pinned by measurement rather
    -- than by preference: sonnet for claude (see the semantic block above), gpt-5.5 for
    -- openai. The openai choice was measured 2026-09-08 across three runs per candidate
    -- on a sample with four known errors; gpt-4o found none on two runs of three, and
    -- gpt-6-astra, three months newer than gpt-5.5, was less consistent. The table is in
    -- `provider.lua`. Do not change either without re-running that measurement.
    model = nil,
  },

  ---@class AlbertLintParseConfig
  ---@field follow boolean Re-render the sidebar as the cursor crosses sentences
  ---@field phrases boolean Show the phrase each node stands for
  ---@field highlight_tokens boolean Color each word by part of speech
  ---@field pos_column boolean Show the POS tag as a text column
  ---@field include_punct boolean
  ---@field dep_labels string "gloss" | "raw" | "both"
  ---@field width integer
  ---@field debounce_ms integer
  ---@field highlight_sentence boolean
  ---@field max_sentences integer
  parse = {
    -- On, and it was `false` for exactly one day. The reasoning for off was that a sidebar
    -- re-rendering on every cursor move is a bad thing to inherit by opening a markdown
    -- file, and that reasoning is wrong: the sidebar only exists while it is open, and you
    -- open it with an explicit command, so opening it *is* the opt-in. Following the cursor
    -- is not an extra behaviour on top of the feature, it is the feature. Reported as a bug
    -- within minutes of shipping.
    follow = true,

    -- Show the phrase each node stands for, in brackets. On by default because it is what
    -- makes a dependency tree readable to someone who does not already think in
    -- dependencies: `In · ADP · preposition` is an honest label for a node whose subtree is
    -- `In this case`, and unreadable without the phrase beside it. `p` toggles it.
    phrases = true,

    -- Color each word by its part of speech. Verbs are bold, because the root of every
    -- clause is one and finding them is how you find the clause boundaries. `g?` in the
    -- sidebar shows the legend; the palette is in `parse/palette.lua`.
    highlight_tokens = true,

    -- The `· NOUN ·` column. Redundant once the colors are learned, so it is here to turn
    -- off rather than to keep forever.
    pos_column = true,

    -- A `punct` leaf hangs off nearly every clause boundary and carries no structure, so
    -- including it roughly triples the line count of a long sentence for no information.
    include_punct = false,

    -- "gloss" | "raw" | "both". `nsubj` is the searchable term and `subject` is the one
    -- that teaches, so the default shows the gloss and `K` on a line reports the raw tag.
    dep_labels = "gloss",

    width = 52,

    -- The buffer sweep after an edit. Longer than the live tier's 400 ms because the sweep
    -- is a subprocess round trip rather than a regex pass, and nothing on screen waits for
    -- it: a hover during the debounce window falls back to a single-sentence parse.
    debounce_ms = 500,

    -- Underline the span that was actually parsed. The Lua sentence splitter is a
    -- heuristic (abbreviations, footnote markers), so showing its answer in the buffer is
    -- how a wrong split becomes visible instead of confusing.
    highlight_sentence = true,

    -- A cap on one sweep, announced when it bites rather than applied silently. 400
    -- sentences is roughly a 6000-word note, which is longer than anything in the vault.
    max_sentences = 400,
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
