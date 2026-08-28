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

## Why two tiers

| Tier | Runs | Rules | Cost |
|---|---|---|---|
| `live` | debounced 400ms on `TextChangedI`, cursor word exempt | 8 single-token rules | free, instant |
| `exit` | `InsertLeave`, `TextChanged`, `BufWritePost` | 13 sentence-level rules | free, instant |
| `semantic` | on demand, `:AlbertLintSemantic` | 4 error classes no regex can see | shells out to `claude`, seconds |

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
| `:AlbertLint` | full pass on the buffer, both deterministic tiers |
| `:AlbertLintSemantic` | LLM pass on the paragraph, or on a visual selection |
| `:AlbertLintToggle` | pause or resume for this buffer |
| `:AlbertLintCoverage` | which drilled patterns have a rule, and which cannot have one |
| `:AlbertLintReload` | reload the catalogue after editing `rules.lua` |

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
    cmd = { "claude", "-p", "--output-format", "text" },
    scope = "paragraph",          -- paragraph | buffer | selection
  },
})
```

`semantic.scope` sets what `:AlbertLintSemantic` sends when you give it no range. It was
declared but never read until 2026-08-28, which made `"buffer"` a setting that did nothing.
The default stays `paragraph`, but **`"buffer"` is the one to use for notes written as
one-line paragraphs**: the paragraph under the cursor is then a single line, and none of
the four semantic classes can fire on one line, so the pass reports nothing and looks
broken. An explicit `:'<,'>AlbertLintSemantic` still wins over this setting.

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
