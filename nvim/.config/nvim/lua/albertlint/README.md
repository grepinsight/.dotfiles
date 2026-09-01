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
| `:AlbertLintCoverage` | which logged mistake patterns have a rule, and which cannot have one |
| `:AlbertLintReload` | reload rules, engine, semantic, and config. Not `init.lua`, not the commands |
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
