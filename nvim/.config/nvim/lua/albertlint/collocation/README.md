# albertlint.collocation

An nvim-cmp source that completes words and short collocations from the writer's own collected
phrase notes.

## Why it exists, and the line it must not cross

It fills a hole the config created deliberately. `plugins/lsp/copilot_gate.lua` blocks Copilot
from markdown outright and `plugins/cmp.lua` filters LuaSnip out of markdown, so a prose buffer's
menu held `nvim_lsp`, `path`, and `buffer` at five characters, and nothing that knows any English.

**This is not a Copilot substitute and must not become one.** The unit is the whole distinction:

| Unit | Is | Accepting it is |
|---|---|---|
| a word or short collocation | vocabulary | choosing from a menu, a judgment |
| a clause | composition | one keystroke, not a judgment |

`index.lua` caps a surface at **five words** and rejects terminal punctuation for exactly this
reason. The first version had no cap, and two `be_replacement` values in the vault are whole
sentences, so the menu offered them as one-key completions. That is the Copilot behaviour the
user blocked, arriving through a different door. **If the cap comes off, this stops being a
vocabulary aid.**

## Where suggestions come from

Not a model. The vault, at `$OBSIDIAN_VAULT/03-Resources/English/`:

| Directory | Notes | Entries | Surface |
|---|---|---|---|
| `Phrases/` | 151 | 409 | `title` plus every alias; definition and canonical example become the docs |
| `Better English/` | 25 | 7 | `be_replacement`, i.e. what to write **instead** |

Phrases yields more entries than notes because each alias is its own surface. Better English
yields far fewer because 18 of 25 are *guidance* notes whose replacement is a sentence and fails
the cap. Only the *swap* tier survives, which is correct: a structural move is not vocabulary.

A `be_replacement` note contributes its replacement, never its originals. Typing what you *would
have* written should surface what you decided to write instead.

## Files

| File | Contains | Pure? |
|---|---|---|
| `index.lua` | frontmatter parsing, entry building, candidate ranking | **yes** — no `vim.api`, no filesystem |
| `init.lua` | directory scan, cache, the cmp source, commands | no |

`index.lua` is pure for the same reason `annotate/anchor.lua` is: the ranking rules are the part
most likely to be wrong, and they are testable with string literals.

## Three non-obvious mechanisms

**1. Matching runs on up to the last three words, longest first.** This is what makes it a
collocation engine rather than a dictionary. Matching only the current word offers every phrase
starting `push`; also matching `give me push` lets the index answer "what did I collect that
continues this".

**2. `get_position_encoding_kind` returns `"utf-8"`, and this is load-bearing.** cmp defaults a
source that omits it to `UTF16` (`nvim-cmp/lua/cmp/source.lua:275`) and then runs the range
through `vim.str_byteindex`. The ranges built in `complete` are Lua byte offsets, so under the
default cmp translates an already-correct offset. **Two symptoms, one cause:** the replacement
lands in the wrong column on any line with a multibyte character before the cursor (this user
writes Korean), *and* `entry._get_offset` derives its matching offset from the same range, so
`filterText` misaligns and every multi-word candidate scores 0 and vanishes silently.

**3. `filterText = entry.matched` looks wrong and is right.** cmp normally matches the current
keyword, so a multi-word `matched` should never match. It works because `entry._get_offset` takes
the offset from `insert_range.start.character + 1` when an item carries a `textEdit`, so cmp's
input begins where the range begins, which is exactly `matched`. They align by construction.

## Case handling

Case follows what was typed, not what the note is titled. Note titles are Title Case because a
title is a heading, so inserting verbatim gave `it was A One-Off` and `please Surface`. The typed
text is kept and the tail lowercased, unless the typed text already carries a capital, read as a
sentence start.

Known edge, documented rather than papered over: typing `A one` yields `A one-Off`; the second
candidate is correct.

This does lowercase a genuine proper noun inside a phrase. Accepted, because the deterministic
`brand-caps` rule lives in the same plugin and flags exactly that on the next keystroke, so the
failure surfaces immediately and next to where it happened.

## Cache

`stdpath("cache")/albertlint-collocation.json`, or `config.cache_path`. Keyed by a fingerprint of
`(path, mtime, size)` for every note, **not** a max mtime: a max mtime cannot see a deletion, so
that cache would serve a deleted phrase forever. A corrupt cache rebuilds rather than erroring,
the opposite of `annotate`'s store, which holds the only copy and refuses instead.

Cold build ~40ms for 416 entries, warm read ~2ms, `candidates()` 0.107ms. The
O(prefixes × entries) scan needs no indexing at typing latency.

## Wiring

```lua
-- init.lua: registers the commands and builds the index
require("albertlint.collocation").setup({})

-- plugins/cmp.lua config(), where cmp is loaded and register_source exists
local ok, collocation = pcall(require, "albertlint.collocation")
if ok then cmp.register_source("english", collocation.source) end

-- and in the sources list, above `buffer`
{ name = "english", keyword_length = 2 },
```

`keyword_length = 2` matches the source's own `min_chars`: completing on one character puts 400+
entries in the menu on every word's first keystroke.

## Config

```lua
require("albertlint.collocation").setup({
  root = nil,          -- defaults to $OBSIDIAN_VAULT/03-Resources/English
  cache_path = nil,    -- defaults to stdpath("cache"); set in tests to avoid patching globals
  filetypes = { markdown = true, text = true, gitcommit = true, mail = true, org = true },
  min_chars = 2,
  max_words = 3,       -- how many trailing words can form a match prefix
  limit = 20,
})
```

## Commands

| Command | Does |
|---|---|
| `:AlbertLintCollocationStatus` | entry count, per-kind breakdown, cache path |
| `:AlbertLintCollocationRebuild` | force a rebuild, e.g. after bulk-editing notes |

## Which notes never appear

25 of 176 contribute nothing, all deliberately: long maxims over the cap
(`Absence of Evidence Is Not Evidence of Absence`), MOC notes with no frontmatter title
(`Life Phrases.md`), guidance-kind Better English notes, and Korean-only aliases.

To make a phrase completable: title of five words or fewer, no terminal punctuation, and an alias
for the form actually typed mid-sentence (`push back` alongside `Pushback`).

## Tests

`tests/albertlint/collocation_spec.lua` (35, pure) and
`tests/albertlint/collocation_source_spec.lua` (18, filesystem and cmp). Notable ones exist
because the bug happened: the sentence-shaped surface, the deleted-note fingerprint, the
multibyte byte-offset range, and the nested frontmatter map from
`Interesting Phrases and Idioms from the Lecture.md`.

Two bugs here were found by running the index over the real 176 notes rather than by unit tests,
because the fixtures agreed with the author's assumptions and the real data did not. Prefer a
real-corpus probe when changing parsing or ranking.
