---The catalogue of graded review levels.
---
---Data, not logic, in the shape of `rules.lua`: adding level 2 should be one row, not a
---rewrite. Four levels are planned and they answer different questions, which is the whole
---point of grading them rather than running one pass that does everything:
---
---  1  Is it grammatical?
---  2  Does it hold together?
---  3  Is it in the right order?
---  4  Is it substantive, and what would make it convincing?
---
---Only level 1 has a command. Rows 2 through 4 are recorded below as comments rather than as
---half-built entries, so `get()` cannot hand the runner a level with no prompt.
local M = {}

---The three families the author has settled as deliberate typing shortcuts rather than
---knowledge gaps, and which therefore must not be reported.
---
---This is the one concession to personalization in an otherwise generic prompt, and it sits
---on the negative side only: suppressing known non-issues is a different act from hunting
---known issues, and only the second was declined. The counts come from the author's fix log.
---The contraction family was retired from the drill list at 10 instances on 2026-08-27 and
---space-before-a-mark was settled at 31 instances on 2026-09-04, both explicitly as typing
---artifacts rather than gaps. Without this list a generic grammar prompt surfaces exactly
---these and drowns everything that matters.
local IGNORE = {
  "capitalization of any kind, including a sentence starting lowercase and a lone `i`",
  "a missing apostrophe in a contraction: `dont`, `didnt`, `cant`, `wont`, `whats`, `isnt`",
  "a space before a punctuation mark, as in `why ?` or `3 times , investigate`",
  "spacing, hyphenation, and line wrapping",
}

---@class LevelDef
---@field id integer
---@field name string
---@field spans_only boolean
---@field brief string
---@field allow string[]
---@field forbid string[]
---@field ignore string[]

---@type table<integer, LevelDef>
M.levels = {
  [1] = {
    id = 1,
    name = "grammar/usage",
    spans_only = true,
    brief = "Report only grammar and usage errors.",
    allow = {
      "articles, definite and indefinite",
      "subject-verb agreement, including across an intervening phrase",
      "verb tense and aspect",
      "prepositions",
      "singular and plural",
      "pronoun case, and pronoun reference where the sentence is ungrammatical without a change",
      "fixed idioms used in a form that is not English",
      "a word used in a sense it does not have",
    },
    forbid = {
      "reordering clauses, sentences, or ideas",
      "tone, register, or formality",
      "concision: do not cut a word merely because it is unnecessary",
      "content: do not add, remove, or argue with what is being said",
    },
    ignore = IGNORE,
  },

  -- Not implemented, and deliberately absent from the table rather than stubbed, so that
  -- `get()` cannot return a level whose prompt does not exist. Each needs the same
  -- treatment level 1 got: a data shape that makes an out-of-level edit unrepresentable.
  --   [2] coherence   -- does each sentence follow from the one before it
  --   [3] rearrange   -- is this the right order for these ideas
  --   [4] substantive -- is the claim carried, and what would make it convincing
}

---@param id integer|string|nil
---@return LevelDef|nil
function M.get(id)
  return M.levels[tonumber(id) or -1]
end

---@param items string[]
---@return string
local function bullets(items)
  local out = {}
  for _, item in ipairs(items) do
    table.insert(out, "- " .. item)
  end
  return table.concat(out, "\n")
end

---Build the prompt for a level.
---
---The JSON contract asks for `quote` plus `occurrence` rather than a column, for two
---reasons. A column from a model is not trustworthy, which `semantic.lua` already learned
---and works around by locating the quote itself. And the same quote can legitimately appear
---twice on one line, which a line-and-quote pair cannot disambiguate.
---
---Ends with a trailing newline and the "one line per numbered entry" marker, because the
---runner concatenates this directly onto the numbered lines.
---@param id integer
---@return string|nil
function M.prompt(id)
  local def = M.get(id)
  if not def then
    return nil
  end

  return table.concat({
    ("You are reviewing one writer's English at level %d of four: %s."):format(def.id, def.name),
    def.brief,
    "",
    "He is a fluent Korean L1 speaker. Report only these categories:",
    bullets(def.allow),
    "",
    "Do NOT report any of the following. Each belongs to a later level, and reporting it",
    "here defeats the point of grading the passes:",
    bullets(def.forbid),
    "",
    "Ignore entirely. These are deliberate typing shortcuts, not mistakes:",
    bullets(def.ignore),
    "",
    "Rules for your output:",
    "- Report a finding ONLY if you are confident. A false positive in prose trains him to",
    "  ignore the tool, which is worse than a miss.",
    "- `quote` must be the shortest exact substring of the given line that contains the",
    "  error, copied byte for byte. `replacement` is that same span, corrected, and nothing",
    "  more. Do not restate the surrounding words.",
    "- `occurrence` is 1-indexed and says which instance of `quote` on that line you mean.",
    "  Use 1 unless the substring genuinely appears more than once.",
    "- NEVER return two findings whose quotes overlap on the same line. If one span has two",
    "  errors in it, return ONE finding whose quote covers the whole span and whose",
    "  replacement has both corrected. Overlapping findings cannot both be applied, so the",
    "  second one is discarded and its error silently survives.",
    "- If your replacement changes which word begins a sentence, correct the capitalization",
    "  inside the replacement. That is not a capitalization report, which is out of scope; it",
    "  is part of making your own replacement grammatical.",
    "- `label` is a short name for the error category. `note` is one sentence: the fix and",
    "  why it is the fix.",
    "- Return STRICT JSON, no prose, no markdown fence:",
    '  {"findings":[{"line":<number as given>,"quote":"<exact substring>","occurrence":1,'
      .. '"replacement":"<corrected span>","label":"<category>","note":"<one sentence>"}]}',
    "- An empty findings array is a valid and common answer. Return it rather than inventing",
    "  work.",
    "",
    "The text, one line per numbered entry:",
    "",
  }, "\n")
end

M._IGNORE = IGNORE
return M
