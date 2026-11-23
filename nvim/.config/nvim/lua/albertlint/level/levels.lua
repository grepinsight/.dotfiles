---The catalogue of graded review levels.
---
---Data, not logic, in the shape of `rules.lua`: adding a level should be one row, not a
---rewrite. Four levels are planned and they answer different questions, which is the whole
---point of grading them rather than running one pass that does everything:
---
---  1  Is it grammatical?
---  2  Does it hold together, and does it read well?
---  3  Is it in the right order?
---  4  Is it substantive, and what would make it convincing?
---
---Levels 1 and 2 have commands. Rows 3 and 4 are recorded below as comments rather than as
---half-built entries, so `get()` cannot hand the runner a level with no prompt.
---
---## What every level shares: the confidence gate
---
---A finding either claims `confident` and carries a `replacement`, or it does not and carries
---a `question` instead. The first becomes a diff hunk with an accept key; the second becomes
---an annotation with nothing to accept.
---
---This replaced an earlier rule that split by TIER: grammar got replacement prose, judgement
---tiers got annotations only. An adversarial review on 2026-09-08 broke that with one line,
---*certainty that something is wrong does not establish certainty about its replacement*, and
---used this tool's own output to do it. `in a calculator` is not inherently wrong. The
---writer's duplicated `to audience to audience to` repairs either as `have the audience type`
---or as `ask the audience to type`, which are different stage directions. Both arrive inside
---a "grammar" hunk, so the tier-shaped line was fiction and the decision belongs on the
---individual edit.
---
---It also fixes level 1, which used to guess at repairs it could not be sure of.
local M = {}

---The three families the author has settled as deliberate typing shortcuts rather than
---knowledge gaps, and which therefore must not be reported.
---
---This is the one concession to personalization in an otherwise generic prompt, and it sits
---on the negative side only: suppressing known non-issues is a different act from hunting
---known issues, and only the second was declined. The counts come from the author's fix log.
---The contraction family was retired from the drill list at 10 instances on 2026-08-27 and
---space-before-a-mark was settled at 31 instances on 2026-09-04, both explicitly as typing
---artifacts rather than gaps. Without this list a generic prompt surfaces exactly these and
---drowns everything that matters.
local IGNORE = {
  "capitalization of any kind, including a sentence starting lowercase and a lone `i`",
  "a missing apostrophe in a contraction: `dont`, `didnt`, `cant`, `wont`, `whats`, `isnt`",
  "a space before a punctuation mark, as in `why ?` or `3 times , investigate`",
  "spacing, hyphenation, and line wrapping",
}

---@class LevelDef
---@field id integer
---@field name string
---@field brief string
---@field allow string[]
---@field forbid string[]
---@field ignore string[]
---@field confident_examples string[] When a replacement is safe to offer
---@field question_examples string[] When it is not

---@type table<integer, LevelDef>
M.levels = {
  [1] = {
    id = 1,
    name = "grammar/usage",
    brief = "Report only grammar, usage, and spelling errors.",
    allow = {
      "articles, definite and indefinite",
      "subject-verb agreement, including across an intervening phrase",
      "verb tense and aspect",
      "prepositions",
      "singular and plural",
      "pronoun case, and pronoun reference where the sentence is ungrammatical without a change",
      "fixed idioms used in a form that is not English",
      "a word used in a sense it does not have",
      -- Added 2026-09-10. Its absence is why `resontates` and `birthay` survived a level 1
      -- pass over a real draft: the allow list simply had no slot for a misspelling, so the
      -- model correctly declined to report one.
      "spelling, including a dropped or doubled letter",
      "an obvious typo, including a duplicated word or a repeated fragment",
    },
    forbid = {
      "reordering clauses, sentences, or ideas",
      "tone, register, or formality",
      "concision: do not cut a word merely because it is unnecessary",
      "content: do not add, remove, or argue with what is being said",
    },
    ignore = IGNORE,
    confident_examples = {
      "`a error` -> `an error`. One correct answer, and the meaning does not move.",
      "`resontates` -> `resonates`. A misspelling has a spelling.",
      "`the number of samples need` -> `needs`. Agreement has a correct answer.",
    },
    question_examples = {
      "`type the following in a calculator`. `into` is likely, but `in` is defensible if the "
        .. "calculator is an app, so ASK which action is meant.",
      "`I have the audience to audience to type`. The duplication is certain; the repair is "
        .. "not, because `have the audience type` and `ask the audience to type` are "
        .. "different instructions. ASK.",
      "any fix that would also change who does what, or when.",
    },
  },

  [2] = {
    id = 2,
    name = "coherence/clarity",
    brief = "Report where the writing does not hold together, or says less than it means.",
    allow = {
      "a sentence that does not follow from the one before it",
      "a referent that is never introduced, so the reader cannot resolve it",
      "a claim that arrives with no setup, or a setup whose payoff never arrives",
      "a sentence whose subject is doing something the writer did not mean",
      "padding: a phrase that adds length without adding information",
      "vagueness where the writer plainly knows the specific thing",
      "a hedge that undercuts a claim the writer means to make",
      "a sentence so overloaded that the reader has to re-read it to parse it",
    },
    forbid = {
      "grammar, usage, and spelling: that is level 1's job and it has already run",
      "reordering sections or paragraphs, which is level 3",
      "adding content, evidence, or argument, which is level 4",
      "rewriting a sentence that is merely plain. Plain is not a defect.",
    },
    ignore = IGNORE,
    confident_examples = {
      "almost nothing at this level. Clarity is a judgement, so default to a question.",
      "the rare exception is a mechanical redundancy with one obvious reading, such as "
        .. "`visually see` -> `see`, where no meaning is lost and no choice is being made.",
    },
    question_examples = {
      "`For some reason, you get this number...`. Something is missing, but supplying it "
        .. "means deciding WHAT is true about the number, which is the writer's to say. ASK "
        .. "what makes the result predictable.",
      "`Just write it down in this`. `this` resolves to nothing. ASK what the object is.",
      "any phrasing you would improve by choosing words the writer did not choose.",
    },
  },

  -- Not implemented, and deliberately absent from the table rather than stubbed, so that
  -- `get()` cannot return a level whose prompt does not exist.
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
---The JSON contract asks for `quote` plus `occurrence` rather than a column, for two reasons.
---A column from a model is not trustworthy, which `semantic.lua` already learned and works
---around by locating the quote itself. And the same quote can legitimately appear twice on one
---line, which a line-and-quote pair cannot disambiguate.
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
    "Do NOT report any of the following. Each belongs to a different level, and reporting it",
    "here defeats the point of grading the passes:",
    bullets(def.forbid),
    "",
    "Ignore entirely. These are deliberate typing shortcuts, not mistakes:",
    bullets(def.ignore),
    "",
    "## The most important rule: are you sure of the REPAIR?",
    "",
    "Being sure something is wrong is not the same as being sure what it should say. Every",
    "finding must choose one of two shapes, and choosing wrongly is the worst thing you can",
    "do here.",
    "",
    'SET `"confident": true` and give a `replacement` ONLY when the repair is BOTH',
    "unambiguous AND meaning-preserving: there is one right answer, and applying it does not",
    "decide anything the writer has not already decided.",
    bullets(def.confident_examples),
    "",
    'SET `"confident": false` and give a `question` instead, with NO `replacement`, whenever',
    "the defect is clear but the repair is a choice, or when fixing it would change who does",
    "what, when, or whether something is true.",
    bullets(def.question_examples),
    "",
    "A `question` is addressed TO the writer and must be answerable by them. Ask what they",
    "meant. Do not smuggle a suggestion into it: `Did you mean X?` with a single X is a",
    "replacement wearing a question mark. If two readings exist, name both.",
    "",
    "When in doubt, choose `false`. An unnecessary question costs him a moment. An",
    "unwarranted replacement costs him a sentence he did not write.",
    "",
    "Rules for your output:",
    "- Report a finding ONLY if you are confident it IS a defect. A false positive in prose",
    "  trains him to ignore the tool, which is worse than a miss.",
    "- `quote` must be the shortest exact substring of the given line that contains the",
    "  problem, copied byte for byte.",
    "- `replacement`, when present, is that same span corrected and nothing more. Do not",
    "  restate the surrounding words.",
    "- `occurrence` is 1-indexed and says which instance of `quote` on that line you mean.",
    "  Use 1 unless the substring genuinely appears more than once.",
    "- NEVER return two findings whose quotes overlap on the same line. If one span has two",
    "  problems, return ONE finding covering the whole span. Overlapping findings cannot both",
    "  be applied, so the second is discarded and its problem silently survives.",
    "- If your replacement changes which word begins a sentence, correct the capitalization",
    "  inside the replacement. That is not a capitalization report, which is out of scope; it",
    "  is part of making your own replacement grammatical.",
    "- `label` is a short name for the category. `note` is one sentence saying why.",
    "- Return STRICT JSON, no prose, no markdown fence:",
    '  {"findings":[{"line":<number as given>,"quote":"<exact substring>","occurrence":1,'
      .. '"confident":true,"replacement":"<corrected span>","label":"<category>",'
      .. '"note":"<one sentence>"},'
      .. '{"line":<number>,"quote":"<substring>","occurrence":1,"confident":false,'
      .. '"question":"<a question the writer can answer>","label":"<category>",'
      .. '"note":"<one sentence>"}]}',
    "- An empty findings array is a valid and common answer. Return it rather than inventing",
    "  work.",
    "",
    "The text, one line per numbered entry:",
    "",
  }, "\n")
end

M._IGNORE = IGNORE
return M
