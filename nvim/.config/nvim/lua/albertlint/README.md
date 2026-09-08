# albertlint

A prose linter for one writer's catalogued mistakes. Rules are derived from a personal log of corrections
collected over time, so every rule traces to a slip that actually happened rather
than to a style guide.

## Installation, and the trap that costs ten minutes

`~/.config/nvim` is **not** a symlink to this repo. It is a real directory whose entries are
symlinked individually, and `~/.config/nvim/lua/` is likewise a real directory with **one
symlink per module** (`annotate`, `config`, `insight`, `overseer`, `pilsa`, `plugins`,
`util`). Nothing maintains those links: `symlink.sh` and `Makefile` in this directory are
both empty, and the links were created by hand between 2024 and 2026.

So a new module in this repo is invisible to Neovim until it gets its own link:

```bash
cd ~/.config/nvim/lua
ln -s ../../../.dotfiles/nvim/.config/nvim/lua/albertlint albertlint
```

The failure mode is confusing rather than obvious. `init.lua` **is** symlinked, so your
`require("albertlint")` line is live and runs, and it fails with `module 'albertlint' not
found` while the file plainly exists in the repo you just edited. The searched-paths list in
the error does not include `~/.config/nvim/lua/albertlint/`, which is the tell.

Any future module added here needs the same one-line link.

## Why several tiers

| Tier | Runs | Rules | Cost |
|---|---|---|---|
| `live` | debounced 400ms on `TextChangedI`, cursor word exempt | 8 single-token rules | free, instant |
| `exit` | `InsertLeave`, `TextChanged`, `BufWritePost` | 13 sentence-level rules | free, instant |
| `semantic` | on demand, `:AlbertLintSemantic` | 4 error classes no regex can see | shells out to `claude`, ~35s |
| `collocation` | as you type, via nvim-cmp | 416 entries from the vault's own phrase notes | free, instant, no model |
| `style` | **not built.** Spec only | discourse-level annotations | — |

`collocation/` has its own [README](collocation/README.md). It is a completion source rather
than a linter: it suggests words and short collocations the writer has already collected, and is
capped at five words on purpose so it stays vocabulary rather than becoming composition.

`style/` is about a third built (`scope.lua` only). See
`docs/superpowers/specs/2026-08-28-nvim-writing-companion-design.md` before touching it.

The split is not a performance nicety. A sentence-level rule cannot judge a sentence you
have not finished typing, and a single-token rule can. Running `slash-list` on every
keystroke would flag `errors/` before you typed the second half.

The semantic tier exists because the largest logged category, **missing `the` before a
specific known referent (106+ instances)**, is undecidable by pattern matching: it needs to
know whether the reader has already met the referent. Three more classes are in the same
position. `:AlbertLintCoverage` prints exactly which patterns fall on which side.

## Commands

| Command | Does |
|---|---|
| `:AlbertLintStatus` | **start here.** What is on, which scope, whether `claude` is reachable, how many collocation entries |
| `:AlbertLint` | the free deterministic checks on this buffer. Not the LLM one |
| `:AlbertLintSemantic` | LLM grammar check over the configured scope, or a given `:'<,'>` range |
| `:AlbertLintSemanticCancel` | stop a running LLM check |
| `:AlbertLintToggle` | pause or resume the automatic diagnostics in this buffer |
| `:AlbertLintLevel1` | **level 1 review** (grammar/usage) as a two-window diff you accept per hunk |
| `:AlbertLintLevelAccept` | take only the line under the cursor, not the whole hunk |
| `:AlbertLintLevelReject` | push the original back over only the line under the cursor |
| `:AlbertLintLevelClose` | close the level diff and leave diff mode |
| `:AlbertLintLevelCancel` | stop a running level pass |
| `:AlbertLintCoverage` | which logged mistake patterns have a rule, and which cannot have one |
| `:AlbertLintReload` | reload rules, engine, semantic, level, and config. Not `init.lua`, not the commands |
| `:AlbertLintCollocationStatus` | collocation entry count, breakdown, and cache path |
| `:AlbertLintCollocationRebuild` | force a collocation rebuild after bulk-editing notes |

`:AlbertLint` deliberately excludes the semantic tier: that one costs money and takes ~35s, so it
is never on a path the user did not explicitly ask for. Running a second `:AlbertLintSemantic`
while one is in flight reports how long the first has been going rather than starting a second
paid call.

## Config

```lua
require("albertlint").setup({
  filetypes = { "markdown", "text", "gitcommit", "mail", "asciidoc", "rst", "org" },
  live_debounce_ms = 400,
  skip_cursor_word = true,        -- a half-typed `Slac` is not a lowercase brand
  disabled_rules = {},            -- e.g. { "hedge-density" }
  enabled_optional = {},          -- e.g. { "a-vs-an", "brand-caps-ambiguous" }
  severity = {},                  -- e.g. { ["slash-list"] = vim.diagnostic.severity.WARN }
  semantic = {
    enabled = true,
    cmd = { "claude", "-p", "--output-format", "text", "--model", "sonnet" },
    timeout_ms = 60000,
    scope = "paragraph",          -- paragraph | buffer | selection
  },
  level = {
    enabled = true,
    provider = "claude",          -- claude | openai
    scope = "buffer",             -- paragraph | buffer | selection
    timeout_ms = 90000,
    model = nil,                  -- nil means the provider's own default
  },
})
```

`semantic.scope` sets what `:AlbertLintSemantic` sends when you give it no range. It was
declared but never read until 2026-08-28, which made `"buffer"` a setting that did nothing.
The default stays `paragraph`, but **`"buffer"` is the one to use for notes written as
one-line paragraphs**: the paragraph under the cursor is then a single line, and the two
classes that need prior context (a missing `the` before an already-introduced referent, and
an ambiguous pronoun) have nothing to work with, so the pass usually reports nothing and
looks broken. The other two, a missing `a`/`an` and agreement across an intervening phrase,
*can* fire within one sentence. An explicit `:'<,'>AlbertLintSemantic` still wins over this
setting.

**`--model sonnet` is load-bearing.** Measured 2026-08-28 on a five-line sample containing an
obvious missing `the`: without the flag the CLI's default model returned `{"findings":[]}`
twice in a row in 6.6s, while sonnet found the error in 34.6s. A tier that reports nothing on
flawed prose reads as "your writing is fine", which is the worst failure a linter has
available. `timeout_ms` is 60000 for the same reason: the old 30000 would have aborted that
34.6s call.

Diagnostics use their own namespace, so the display config here cannot fight your global
one. Default is underline with virtual text on the current line only, because prose is read
left to right and a floating message per line breaks that.

## The graded levels

`:AlbertLintLevel1` is the first of four planned review tiers, each answering a different
question so the feedback arrives in an order you can absorb:

| Level | Question | State |
|---|---|---|
| 1 | Is it grammatical? | shipped |
| 2 | Does it hold together? | data row only |
| 3 | Is it in the right order? | data row only |
| 4 | Is it substantive, and what would make it convincing? | data row only |

**This is the one tier that produces replacement prose.** Every other tier names the fix and
still makes you type it. That is a deliberate, scoped exception to the doctrine in `CLAUDE.md`,
decided 2026-09-08 — read that section before changing it, because the constraint it amends is
written forcefully enough to look like this feature is a bug.

The pass opens a native two-window diff: your buffer left, a corrected copy right. Navigation
and apply are Neovim's own, so nothing here is reinvented.

| Key | Does |
|---|---|
| `]c` / `[c` | next / previous hunk |
| `do` | accept the hunk from the corrected side |
| `dp` | push the original over the corrected side |

The label and the reason for each fix appear as virtual text above the change. **The blank
virtual lines on your side of the diff are not dead code.** Diff mode aligns two windows with
filler lines it computes itself, while `virt_lines` add screen rows to one window only. Measured
2026-09-08: a one-line note on the corrected side alone put line 3 at screen row 4 on the right
and row 3 on the left, and everything below it drifted further apart. An equal count of blanks
on the other side restores exact alignment.

**`do` takes a whole hunk, and vim merges adjacent changed lines into one hunk.** So two
unrelated findings that happen to land on consecutive lines are a single hunk, and one `do`
applies both. Measured 2026-09-08 with a Number fix on line 3 and an Article fix on line 4.
`:AlbertLintLevelAccept` is line-scoped and restores per-finding granularity. It is a command
rather than a keymap so it claims nothing in your keyspace; bind it if it earns it.

### Why spans and not a rewrite

The model returns *labeled spans* — the exact substring plus its correction — never a rewritten
paragraph. That is what keeps level 1 inside its own boundary: with no channel for free-form
prose, reordering a clause or changing tone is **unrepresentable**, not merely forbidden by the
prompt. It also means every diff hunk traces back to exactly one named finding, which is what
lets a note attach to a hunk at all.

Two prompt rules exist because a live call broke without them, both measured 2026-09-08. The
model returned `use` → `uses` *and* `use LLM` → `use an LLM` as two overlapping findings; both
were right, only the first could apply, and the article error silently survived. And it returned
`Audience` → `The Audience`, keeping a sentence-initial capital mid-phrase, because
capitalization is on the ignore list. The prompt now forbids overlapping quotes and requires the
model to fix capitalization it creates in its own replacement.

### Providers

`provider = "claude"` shells out to the CLI, so this plugin never holds a credential. It passes
`--safe-mode --disable-slash-commands --strict-mcp-config`, which is the measured set for "no
skills or plugins loaded" from `util/claude.lua`: `--safe-mode` alone still left 12 skills
reachable when measured 2026-08-26.

`provider = "openai"` reads `OPENAI_API_KEY` **from the environment** — never from this config,
never from a dotfile. A strict `json_schema` makes a malformed response impossible, which is its
real advantage. The key is handed to curl on **stdin** via `--config -`, never in argv, because
argv is world-readable through `ps`; a test asserts no rendered argv contains `Bearer` or an
`sk-` string.

**The default model is `gpt-5.5`, and it was measured, not chosen.** Three runs per candidate
against a four-line sample with four known errors, 2026-09-08:

| model | hits over 3 runs | avg s | |
|---|---|---|---|
| `gpt-5.5` | 4, 4, 4 | 10.1 | stable, and the oldest that is |
| `gpt-5.6-sol` | 4, 4, 4 | 10.7 | equally stable, the expensive tier |
| `gpt-6-astra` | 4, 3, 4 | 10.6 | **newest, and not stable** |
| `gpt-5.6-luna` | 3, 3, 4 | 5.9 | fastest of the good ones, still not stable |
| `gpt-5.4-nano` | 0 | 1.6 | **returned zero findings** |
| `gpt-4o` | 0, 2, 0 | 1.7 | **zero findings on two runs of three** |

Two things worth keeping from that. **Newest is not best**: `gpt-6-astra` is three months newer
than `gpt-5.5` and less consistent here. And **the floor is real**: the nano tier does not score
worse, it silently returns nothing, which reads as "your writing is fine" and is the worst
failure a linter has available. Re-run the measurement before changing this.

Nothing about level 1 has been measured for precision. Every test is recall on text already
known to be broken.

## Adding a rule

Rules are data in `rules.lua`. Four matcher kinds, exactly one per rule:

```lua
{
  id = "brand-caps",              -- unique, stable, appears in the diagnostic as `code`
  tier = "live",                  -- live | exit
  severity = vim.diagnostic.severity.WARN,
  drill_ref = "Word form: brand capitalization dropped",  -- the fix-log pattern it came from
  words = { slack = "Slack" },    -- word-boundary, case-SENSITIVE
  message = "%s is a proper noun: %s",
}
```

- `words` builds one case-sensitive word-boundary regex from the keys. Use for single tokens.
- `phrases` builds one case-insensitive literal regex. Use for fixed multi-word swaps.
- `vimre` is a raw Vim regex. Use `[==[ ... ]==]` if the pattern contains `]]`.
- `fn` names a function in `engine.lua`'s `fns` table. Use for counting and lookup.

`drill_ref` is mandatory and is what makes `:AlbertLintCoverage` meaningful.

## What the engine deliberately ignores

Context masking is the reason the rule set can be aggressive. Masked: inline code spans,
fenced blocks, YAML frontmatter, URLs, and markdown link targets. Not masked: markdown link
**text**, because that is prose the reader sees, so a lowercase brand there is a real slip.

## Rules held back

Three rules are off by default with the reason recorded on each:

- `brand-caps-ambiguous` — names that are also common nouns (`hex`, `lance`, `parquet`,
  `feather`). The lowercase form parsing as the wrong sense is exactly what makes them worth
  catching and what makes them noisy.
- `no-space-before-paren` — `func(arg)` in prose about code is legitimate.
- `a-vs-an` — the sound rule needs an exception lexicon (`a URL`, `an hour`, `a UUID`,
  `an FDA filing`) and a bare vowel-letter test produces steady noise.

The acronym list deliberately excludes `it`, `id`, `cd`, `pr`, `ci`, and `rag`. A false
positive on a pronoun would make the linter unusable in one sitting, and a test pins this.

## Tests

```bash
cd ~/.dotfiles/nvim/.config/nvim
PLENARY_DIR=~/.local/share/nvim/lazy/plenary.nvim nvim --headless \
  -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/albertlint { minimal_init = 'tests/minimal_init.lua' }"
```

33 tests. Each behavioural test names the sentence it came from, so a failure points at the
source slip. Two of them exist because the first implementation failed on them:
`a write access` (the article was required to sit directly on the noun) and `when you login
for the first time` (the rule only fired before a preposition).
