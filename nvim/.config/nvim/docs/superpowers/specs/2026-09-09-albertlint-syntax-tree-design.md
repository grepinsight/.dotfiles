# albertlint syntax tree: hover a sentence, read its structure

Draft 1, 2026-09-09. Written before the code, and every latency number in it was measured on
this machine before the design was fixed, because the requested target turned out to be
unreachable one way and trivial another, and that distinction is the whole design.

## 1. The ask, and the one place it had to bend

> I want to hover over a sentence and have a sidebar show its structure as a nested list,
> parsed locally, sub-millisecond.

Two of the three are free. The third is not, and it is worth being exact about why.

**spaCy cannot parse a sentence in under a millisecond.** Measured here, `en_core_web_sm` with
`ner`, `lemmatizer`, and `senter` excluded:

| sentence | median | p95 |
|---|---|---|
| 9 words | 1.29 ms | 1.44 ms |
| 25 words | 2.01 ms | 2.29 ms |
| 44 words | 3.60 ms | 4.04 ms |

Dropping the tagger and `attribute_ruler` too buys almost nothing (1.19 / 1.81 / 3.26 ms) and
costs the POS column, so it is not worth doing. There is no configuration of this model that
parses the sentence from the screenshot in under a millisecond, and no other Python parser is
meaningfully faster; the ones that are more accurate (benepar, Stanza) are 1 to 2 orders of
magnitude slower.

**So the parse comes off the interaction path entirely.** What has to be sub-millisecond is the
*hover*, not the parse, and that is a different problem with an easy answer:

| operation | measured |
|---|---|
| Python dict lookup of a parsed sentence | 0.042 us |
| whole 294-word, 12-sentence document in one `nlp()` call | 22 ms (13.6k wps) |

A document parses faster per word than a sentence does, because the fixed per-call overhead
amortizes. So the design is: **parse the whole buffer off the interaction path, cache the trees
in Lua keyed by sentence text, and make hover a table lookup.** The interaction path then
contains no IPC, no Python, and no parser, which is the only way to reach the stated target.

This is not a workaround for a slow parser. It is the correct architecture for the requirement,
and it happens to also survive editing (see §4).

### What is being promised

- **Hover on a cached sentence: sub-millisecond.** A Lua table lookup plus a render of a
  pre-tokenized list. Verified by a benchmark in the test suite, not asserted.
- **Hover on an uncached sentence: 2 to 5 ms**, the parse plus one pipe round trip, resolved
  asynchronously so the sidebar fills in rather than blocking. Below the ~100 ms perceptual
  floor by a wide margin, but not sub-millisecond, and the docs should not claim otherwise.
- **First hover of a session: ~0.6 s**, the daemon cold start (§3).
- **First hover ever: ~20 s**, the one-time bootstrap (§3).

## 2. Dependency, not constituency

Chosen deliberately, and the alternative was live. A constituency parse (`S -> NP VP`) is the
tree most people picture when they picture sentence structure, and for studying clause nesting
it reads better. It needs benepar or Stanza, which means PyTorch, a 60 MB download minimum, and
a parse budget in the tens of milliseconds.

A dependency parse is already a tree, it comes free with the model that does the POS tagging,
and it is the only option inside the latency budget. It answers a slightly different question:
not *what phrase is this part of* but *what word governs this word*.

Consequence to accept: dependency trees put function words at the leaves and can nest in ways
that surprise a reader expecting phrase brackets. `due to` in the screenshot's second sentence
hangs off the main verb as `prep` + `pcomp`, which is correct and unintuitive. The gloss table
in §5 exists to soften exactly this.

If the constituency view turns out to be the one worth having, this design does not block it:
the daemon protocol (§3) returns a token list with a `head` index, and a constituency backend
would return the same shape with different edges. Do not add it before the dependency view has
been used for a week.

## 3. The daemon

**A long-lived Python process, spoken to in JSON Lines over a pipe.** Not an LSP server, and
not a per-hover subprocess.

Not an LSP server because LSP has no request that means "give me a tree". `documentSymbol`
comes closest (it returns a nested structure that aerial.nvim will render in a sidebar for
free), and it remains the right end state if this feature earns a rewrite. It is the wrong
starting point, because it is whole-document only, its symbol kinds are a fixed code-shaped
enum, and it would put a protocol between us and a decision we have not made yet (§2).

Not a per-hover subprocess because the model load is 142 to 150 ms and the interpreter import is
332 to 413 ms. Paying that per hover would be 500x the parse itself.

### Cold start, and the 20-second cliff

Measured, and worth writing down because it looks like a hang:

| | first run in a fresh venv | every run after |
|---|---|---|
| `import spacy` | 19.6 s | 332 to 413 ms |
| `spacy.load(...)` | 456 ms | 142 to 150 ms |

The first number is macOS verifying and caching a few dozen freshly written shared objects, not
spaCy being slow. It is per install location, which rules out `uv run --script` with PEP 723
inline dependencies: that builds an ephemeral environment per invocation, so **every** start
pays the 20 seconds. Verified, twice, before this was written.

So the environment is a **persistent venv** under `stdpath("data")/albertlint-parse/`, created
once by an explicit bootstrap command that says what it is doing. Never created implicitly on
first hover, because a 20-second silent stall on a keystroke is indistinguishable from a bug.

### Protocol

One JSON object per line, both directions. Request:

```json
{"id": 7, "sentences": ["There is a strong belief in the benefits.", "Data is often siloed."]}
```

Response:

```json
{"id": 7, "trees": [{"text": "...", "root": 1, "tokens": [
  {"i": 0, "text": "There", "pos": "PRON", "tag": "EX", "dep": "expl", "head": 1}
]}]}
```

`{"id": 7, "error": "..."}` on failure, and `{"id": 0, "ready": true}` once at startup so the
Lua side knows the model is loaded without probing. Ids are echoed so a stale response from a
buffer that has since changed can be dropped rather than rendered.

**Segmentation happens in Lua, always, and never in the daemon.** The daemon parses the strings
it is handed and disables `senter`.

The tempting split is to let spaCy segment a whole buffer, since it is better at it than a Lua
regex will ever be. It is wrong here, and the reason is the cache. The cache key is the sentence
text that Lua computed when the cursor asked; if Python re-split the buffer, it would return
trees filed under slightly different strings, and every hover would miss on exactly the
sentences whose boundaries the two disagreed about, which is the hardest class to debug. One
segmenter, in the process that does the lookup.

The cost is real and is accepted: the Lua splitter is a heuristic (§8), so a sentence it gets
wrong is parsed wrong. It is visibly wrong, because the sidebar header shows the text that was
actually parsed.

The daemon file lives at `lua/albertlint/parse/daemon.py`, inside the Lua tree. That looks
wrong and is deliberate: `~/.config/nvim/lua/albertlint` is a whole-directory symlink, so
anything under it is reachable with no new link, while a new top-level `python/` directory in
this repo would be invisible to Neovim until someone hand-linked it. See the trap at the top of
`CLAUDE.md`; this is the cheapest way to not step in it.

## 4. Caching, keyed by text and not by position

The cache is `sentence text -> tree`, per buffer, in Lua.

The obvious alternative is to key on character offsets from the last whole-buffer parse. It is
wrong: every keystroke shifts every offset after the cursor, so the cache invalidates on each
edit and the hover target is stale the moment you type. Keying on the text means an edit
invalidates exactly one sentence, the one you edited, and every other sentence in the buffer
stays hot across the entire editing session.

Flow:

1. `BufReadPost` and a debounced `TextChanged` submit the buffer's sentences, minus the ones
   already cached, to the daemon. Off the interaction path, so a slow first parse is invisible.
   Only the uncached ones are sent, so the second sweep after an edit costs one sentence.
2. Hover extracts the sentence under the cursor **in Lua** and looks it up. Hit renders
   immediately. That is the sub-millisecond path.
3. Miss submits that one sentence and renders when it lands, 2 to 5 ms later.

Two pure modules carry the parts most likely to be wrong, in the shape `annotate/anchor.lua`
and `style/scope.lua` established:

- `parse/sentence.lua`: lines plus a cursor position, out comes the sentence text and its span.
  No `vim.api`. Reuses `engine._build_mask` so a sentence-looking line inside a fenced code
  block is not offered up as prose.
- `parse/tree.lua`: a token list in, rendered lines plus a line-to-token index out. No
  `vim.api`, no filesystem. This is where the tree shape and the guide characters live, and it
  is testable against a hand-written token list.

## 5. What the sidebar shows

```
There is a strong belief in the benefits of enriching clinical patient data.  (13 words)

is · AUX · root
├── There · PRON · existential there
├── belief · NOUN · attribute
│   ├── a · DET · determiner
│   ├── strong · ADJ · adjective modifier
│   └── in · ADP · preposition
│       └── benefits · NOUN · object of preposition
│           ├── the · DET · determiner
│           └── of · ADP · preposition
│               └── enriching · VERB · complement of preposition
│                   └── data · NOUN · direct object
│                       ├── clinical · ADJ · adjective modifier
│                       └── patient · NOUN · noun modifier
```

Three decisions in that render:

**Glossed dependency labels by default.** `nsubj` is the searchable term and `subject` is the
one that teaches, so the default is the gloss and `dep_labels = "raw" | "both"` is available for
when the jargon is the point. The gloss table is data in `tree.lua`, one row per label, the same
split `rules.lua` uses.

**Punctuation hidden by default.** A `punct` leaf on every clause boundary triples the line
count and carries no structure. `include_punct = true` for when it matters.

**No prose is ever written into the sidebar.** The buffer is a read-only scratch, the sentence
header is copied verbatim from the source, and every other line is one token plus two labels.
There is no accept key, nothing to apply, and no rewritten span anywhere in the feature.

### Why this does not need the §"scoped exception" in CLAUDE.md

The hard constraint in `CLAUDE.md` is on *replacement prose with an accept path*. The graded
level commands needed a written exception because they show a fix and bind `do` to it. This
feature shows an analysis of what the writer already wrote. It cannot be accepted, because
there is nothing to accept, and the only way to act on it is to go and change the sentence.
That is the constraint's intent satisfied structurally rather than by permission, and it is the
same argument the collocation source makes with its five-word cap.

## 6. Surface

| command | does |
|---|---|
| `:AlbertLintTree` | toggle the sidebar for the sentence under the cursor |
| `:AlbertLintTreeClose` | close it |
| `:AlbertLintTreeFollow` | toggle follow mode, where cursor movement re-renders on sentence change |
| `:AlbertLintTreeBootstrap` | create the venv and download the model, with progress. `!` uses public PyPI |
| `:AlbertLintTreeStatus` | daemon state, cache size, and the measured hover latency |
| `:AlbertLintTreeBenchmark` | time the hover path over every cached sentence in the buffer |
| `:AlbertLintTreeClearCache` | drop this buffer's cached parses |

In the sidebar: `q` closes, `K` reports the raw `pos`/`tag`/`dep`/head for the token on that
line. `K` exists because the default gloss (`subject`) is the one that teaches and the raw tag
(`nsubj`) is the one you can search for, so neither replaces the other.

Config under `parse` in `config.lua`, defaults chosen the way the rest of this plugin chooses
them, which is to say toward silence: `follow = false`, `include_punct = false`,
`dep_labels = "gloss"`, `width = 52`, `debounce_ms = 500`, `highlight_sentence = true`,
`max_sentences = 400`.

`highlight_sentence` underlines the span that was actually parsed. It is on by default
specifically because the Lua splitter is a heuristic (§8): a wrong boundary should be visible in
the buffer, not inferred from a confusing tree.

`:AlbertLintTreeStatus` and `:AlbertLintTreeBenchmark` exist because every latency claim in this
document is falsifiable on the user's own machine, and a feature sold on a measurement should be
able to show it.

### The install goes through whatever index uv is configured to use

Found while shipping. This machine's `~/.config/uv/uv.toml` names a non-public package
mirror, which needs network access, so off-network the bootstrap fails with a DNS error nested four
`Caused by:` levels deep and reads as a bug in this plugin.

The default therefore honours the configured index and the failure message names the likely
cause. `:AlbertLintTreeBootstrap!` is the explicit bypass to public PyPI. Two details worth
keeping: `--default-index` alone does **not** override a configured `[[index]]`, because uv adds
the configured one to the search rather than replacing it, so the bypass needs `--no-config`
too; and rerouting a package install is not something an editor should do silently, which is why
it is a bang and not a fallback.

## 6a. Verification, run 2026-09-09

Everything below was measured after the code was written, on this machine, through the shipped
code path rather than a benchmark harness.

| claim from §1 | measured |
|---|---|
| hover on a cached sentence is sub-millisecond | **~95 us end to end**, cursor move to rendered sidebar |
| the render alone | 13.8 us median, 76.9 us worst over the cached set |
| uncached hover is 2 to 5 ms | 2.50 ms for a 23-word sentence, reported by `parse_ms` |
| first parse ever is about 20 s | 18.7 s, first daemon start in the new venv |
| daemon start after that is about 0.5 s | 332 to 413 ms import plus 142 to 150 ms load |

Test suite: 470 examples, 0 failures, across 23 files, up from the 393 recorded in `CLAUDE.md` on
2026-09-08. 34 of the new ones cover `tree.lua` and `sentence.lua`.

Two bugs the verification pass caught, both worth recording because neither would have been
found by reading:

- **`installed()` checked for the interpreter, not for spaCy.** A `uv venv` that succeeds
  followed by a `uv pip install` that fails leaves a working `bin/python` with no model in it,
  so the check returned true and the daemon then died on `ModuleNotFoundError` three layers away
  from the actual cause. Now it globs for the model package.
- **`:AlbertLintStatus` had been broken on a default config since before this branch.**
  `level.timeout_ms` defaults to nil, meaning "scale to the line count", and the status line
  formatted it with `%d`. Fixed in passing; it is not part of this feature.

## 7. Staging

| stage | deliverable | done when | status |
|---|---|---|---|
| 1 | `parse/tree.lua`, pure | renders a hand-written token list, specs green | **done**, 13 specs |
| 2 | `parse/sentence.lua`, pure | finds the cursor's sentence, respects the code mask, specs green | **done**, 21 specs |
| 3 | `parse/daemon.py` plus `parse/daemon.lua` | `:AlbertLintTreeStatus` reports ready | **done** |
| 4 | `parse/init.lua`, sidebar, cache, commands | hover renders a real sentence | **done** |
| 5 | bootstrap plus README plus the latency benchmark | numbers in §1 reproducible via a command | **done**, `:AlbertLintTreeBenchmark` |

## 8. Open, and honest about it

- **The Lua sentence splitter will be wrong sometimes.** `success.1,` in the screenshot's own
  text is a footnote marker, not a boundary, and `e.g.` is not one either. An abbreviation list
  handles the common cases and something will still slip through. The failure is mild: a tree
  for slightly the wrong span, visibly labelled with the text it parsed, so the user can see it
  went wrong. Cheap to fix, not worth pre-solving.
- **Nothing here is measured for usefulness.** The latency numbers are real and the
  pedagogical value is a guess. The check worth running after a week: does the tree get opened
  on sentences that are *already* hard to read, or only on ones that were fine? If the second,
  the feature is a toy.
- **The gloss table is one person's translation of Universal Dependencies labels.** It is not
  authoritative and a linguist would argue with several rows.
