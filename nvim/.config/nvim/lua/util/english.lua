---English study commands built on the `util.claude` job plumbing.
---
---`:'<,'>ClaudeAnalyze` sends the selection to `claude -p` with a fixed prompt and
---parks a five-section breakdown in the usual reply buffer: verbs, nouns,
---adjectives, idioms, sentence structures. Same background job, same
---`:ClaudeLast` / `:ClaudeSave` / `:ClaudeExport`, so nothing here knows about
---jobs, buffers or rendering. The whole module is a prompt plus a registration.
---
---The prompt lives here rather than in `util/claude.lua` because that file's job
---is generic plumbing: it should not grow a vocabulary about English study.
---
---Caveat worth keeping in mind while reading a reply: this is a language model's
---parse, not a parser's. Clause-pattern labels and idiom calls are usually right
---and occasionally arguable, so treat the output as a study aid rather than
---ground truth. It is not checked against a grammar.
---
---Run raw (`M.raw = true`, the default): no skills, plugins, hooks, CLAUDE.md or
---MCP. The prompt below is self-contained, so the extra system prompt buys
---nothing and only gives the model room to drift off the requested format.
---
---Usage:
---  :'<,'>ClaudeAnalyze              five sections, 40 lines of context
---  :'<,'>ClaudeAnalyze +full        the whole buffer as context
---  :'<,'>ClaudeAnalyze just verbs   same analysis, narrowed
local claude = require("util.claude")

local M = {}

---Strip the extra system prompt for the analysis run. See the header.
M.raw = true

---What `:ClaudeAnalyze` asks for.
---
---Written as instructions to the model, so it reads as a spec rather than as
---prose. Three details carry most of the weight:
---
---  * The selection is scoped explicitly. `build_payload` wraps the buffer's
---    surrounding lines in `<context-before>` / `<context-after>`, and without
---    this the model happily analyses those too.
---  * The word lists are selective, not a parse. An exhaustive dump of a
---    paragraph is mostly `the`, `is` and `thing`, which teaches nothing.
---  * What was skipped is stated. A selective list that hides its omissions
---    reads as "there was nothing else here", which is the one wrong impression
---    it could leave. Same reasoning as `apply_cap` announcing dropped context.
---The first line stands alone on purpose: `render` in util/claude.lua uses it as
---the reply buffer's H1, so a line that wrapped mid-sentence would make an
---awkward heading.
local ANALYSIS = [[
Break the selected text's English into verbs, nouns, adjectives, idioms and sentence structures.

Analyze the text inside <selection>. Any <context-before> and <context-after>
blocks are background only: do not analyze them, and do not list anything that
appears only in them.

Return ONLY the five sections below, in this order, each as a markdown table. No
preamble, no closing summary, no prose outside the tables.

The reader is a fluent non-native speaker who studies English to reuse in his own
writing. In the first three sections a row earns its place by being worth learning,
not by being present: skip function words and everyday vocabulary. The last two
sections are exhaustive.

## Verbs

Columns: verb | form | why it earns a row

Keep phrasal verbs, verbs locked to a particular preposition, and verbs whose choice
is doing real work. Skip auxiliaries and copulas. Skip plain everyday verbs (be,
have, do, go, get, make, say, take, come, know, want) unless the selection uses one
idiomatically.

`form` is the inflection as used: past, 3sg pres, pres perf, gerund, past participle,
bare infinitive.
`why it earns a row` is one clause naming what a learner would get wrong.

End the section with a line of the form `(skipped: ...)` listing the everyday verbs
you left out, comma separated.

## Nouns

Columns: noun | number | why it earns a row

Keep nouns that carry the topic and nouns that belong to a fixed pairing. Skip
pronouns. Skip generic nouns (thing, way, people, time, part, kind) unless the
selection uses one inside a set phrase.

`number` is singular, plural, or uncountable as used.

End the section with a `(skipped: ...)` line, as above.

## Adjectives

Columns: adjective | pairs with | why it earns a row

`pairs with` is the noun it modifies here, followed by other nouns it habitually
pairs with, so the row teaches the collocation and not just the word.

Skip bare intensity words (very, really, quite, so) and colorless adjectives (good,
bad, big, small, nice) unless the selection pairs one unusually.

End the section with a `(skipped: ...)` line, as above.

## Idioms and fixed expressions

Columns: expression | literal reading | actual meaning | register

Every multi-word unit whose meaning is not the sum of its words, plus fixed
collocations and rhetorical formulas. Exhaustive, not selective.

`literal reading` is what the words would mean read straight, which is the contrast
that makes the idiom stick. For a collocation that is literal already, write
`literal`.
`register` is one of: neutral, formal, informal, business, literary.

## Sentence structures

Columns: # | pattern | skeleton

One row per sentence in the selection, numbered in reading order.

`pattern` names the shape from: SVO, SVC, SVOO, existential there, cleft, fronted
adverbial, participial adjunct, relative clause, coordination, subordination,
passive, inversion, imperative, fragment. Name every pattern that applies, joined
with " + ".
`skeleton` is the sentence with content words replaced by placeholders, showing the
frame only, e.g. `It was X that Y` or `Having done X, S V O`.

## Rules that apply to every section

Quote every item exactly as the selection spells and inflects it. Do not correct,
improve or rewrite the text: this is a description of what is there.

If a section has no qualifying rows, write `none` on its own line under its heading.
Never drop a heading. All five appear, in the order above, every time.
]]

---`:'<,'>ClaudeAnalyze [+N|+full] [extra instruction]`
---
---Wrapped per call rather than once at load, so setting `M.raw` after the module
---is required actually takes effect instead of being silently ignored.
---@param opts table
function M.analyze(opts)
  claude.with_prompt(ANALYSIS, { raw = M.raw })(opts)
end

return M
