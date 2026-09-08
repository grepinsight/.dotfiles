# Graded review levels: `:AlbertLintLevel1` and the ladder above it

Status: draft 1. Nothing implemented. Test baseline before this work: **295 passing, 0 failed,
0 errors** across 15 spec files, measured 2026-09-08 on `f5ca555`.

**Line-number citations are as of commit `f5ca555`** and are not re-verified per commit. Treat a
mismatch as drift, not as a claim about current code.

Date: 2026-09-08

## 1. Goal

Four progressive review tiers over the author's own English prose, each answering a different
question, invoked one at a time so the feedback arrives in an order the author can absorb:

| Level | Question | Status |
|---|---|---|
| 1 | Is it grammatical? | this spec |
| 2 | Does it hold together? | data row only |
| 3 | Is it in the right order? | data row only |
| 4 | Is it substantive, and what would make it convincing? | data row only |

Only Level 1 gets a command in this change. Levels 2 through 4 exist as rows in `levels.lua`
recording intent, because the author's stated reason for the ladder was progression: "the idea is
I want to do this progressively." The shape has to admit them; the code does not have to
implement them yet.

Level 1's output is rendered as a two-window Neovim diff with per-hunk accept and reject.

## 2. The doctrine this amends, and why

`2026-08-28-nvim-writing-companion-design.md` §1 states a hard constraint:

> the AI may produce only *annotations and questions* anchored to a span of text. It never
> produces replacement prose.

with the reason:

> A diff hunk containing a rewritten sentence has a one-keystroke accept path, which is the
> fastest available route to a document the author did not write. An annotation has no accept
> key; the only way to resolve one is to type something.

**Level 1 produces replacement prose in a diff with an accept key. That is a deliberate,
scoped reversal, decided by the author on 2026-09-08.** It is recorded here and in `CLAUDE.md`
rather than left implicit, because the constraint is written down forcefully enough that a future
agent reading only the old text would classify this feature as a bug and remove it.

Scope of the exception, stated narrowly:

- It applies to the **graded level commands only**. `albertlint`'s live, exit, and semantic tiers
  keep the no-autofix rule: they name the correct form in the message and still make the author
  type it.
- `copilot_gate.lua` still blocks Copilot from markdown outright. Untouched.
- `collocation/index.lua` still caps a completion surface at five words. Untouched.

What the original reasoning got right and this design preserves: the danger is *unattributed*
replacement prose arriving in bulk. Level 1 answers that structurally (§4), not by refusing to
show a fix.

Rejected alternatives, recorded so they are not silently revisited:

- **Display-only diff, no apply key.** Preserves the doctrine exactly. Rejected by the author,
  who asked to "review and decide accept/reject by hunk."
- **Diff plus a retype gate** (applying requires typing the corrected span, an exact match
  writes it). Honors "HAVE me write" literally. Rejected as over-built for level 1; may be worth
  revisiting if the accept key turns out to be used reflexively.
- **A custom scratch buffer rendering the chat fix format, with hand-built `<CR>`/`x` apply.**
  Selected first, then withdrawn in favor of native diff mode: "nvim/vim has a good diff view. I
  think showing diffview is enough. I can leverage nvim/vim's diffs." Native mode means `do`/`dp`
  are the accept and reject, so there is no apply code to get wrong.

## 3. Module layout

```
lua/albertlint/level/
  init.lua      runner: command, scope, in-flight guard, orchestration
  levels.lua    DATA: one row per level. Level 1 filled, 2-4 stubs
  provider.lua  DATA + dispatch: { claude = fn, openai = fn }
  apply.lua     PURE: fixes -> corrected lines. No vim.api, no filesystem
  diffview.lua  thin vim.* caller: scratch buffer, diffthis, mirrored notes
```

This follows the two conventions in `CLAUDE.md`. **Data, not logic:** `levels.lua` is a catalogue
in the shape of `rules.lua`, so adding level 2 is one row. **Pure modules for the hard parts:**
`apply.lua` uses no `vim.*` and no filesystem, matching `annotate/anchor.lua` and
`collocation/index.lua`, so the logic most likely to be wrong is testable with string literals.

**No new symlink is required.** `lua/albertlint/level/` is a subdirectory of the already-linked
`albertlint` module. Per `CLAUDE.md`, only a new *top-level* module under `lua/` needs its own
link in `~/.config/nvim/lua/`. Stated because the failure mode is a confusing
`module not found` on a file that plainly exists, and it has cost time before.

## 4. The model returns spans, not a rewrite

Each finding is:

```json
{"line": 47, "quote": "which takes the text and use LLM", "occurrence": 1,
 "replacement": "which takes the text and calls an LLM",
 "label": "Subject-verb agreement",
 "note": "`takes` and `use` share the subject `which`, so the second verb agrees with the first."}
```

`label` is free-form. §9 declines to constrain the model's label vocabulary, so this example
shows the field's shape, not an enumeration.

`occurrence` is 1-indexed and exists to remove an ambiguity rather than to paper over it. A quote
can legitimately appear twice on one line, and `line` plus `quote` alone cannot say which
instance is meant. Taking the first would be silently wrong half the time; dropping the finding
would discard a real fix. Making the model disambiguate costs one integer. A response omitting
the field defaults to `1`; a value pointing past the last occurrence is treated as unplaceable
and counted (§4.1).

`apply.lua` applies the findings to the original lines to build the corrected copy. The
alternative, asking the model for a fully corrected paragraph, is simpler to prompt and is
rejected for two reasons.

**It makes the level boundary an invariant instead of a request.** If the model can only return
labeled spans, there is no channel through which it can reorder a clause, adjust tone, or cut a
sentence. Level 2, 3, and 4 behavior is not forbidden by instruction, it is unrepresentable. Ask
for a full rewrite and "grammar only" is a promise in a prompt that the model may quietly ignore,
which is exactly the failure this ladder exists to prevent.

**It makes every hunk attributable.** One diff hunk traces to exactly one labeled finding, which
is what allows a note to attach to a hunk at all (§6). A free-form rewrite produces hunks with no
owner.

It also lets the design reuse the move already proven in `semantic.lua:263-270`: locate the quote
in the line by literal search rather than trusting a column from the model, drop the finding if
the quote is not present, and count the drops for the summary. A fix on the wrong span is worse
than no fix.

### 4.1 Ordering and overlap

Fixes on the same line are applied **right to left**, by descending byte offset. Applied left to
right, the first replacement invalidates every later offset on that line. Two fixes whose spans
overlap cannot both apply: the first by offset wins, the second is dropped and counted, because
silently applying half of each produces text neither the model nor the author wrote.

### 4.2 Byte offsets, not character counts

Spans are byte ranges. The author's buffers contain Korean, so a character-based offset would
misplace every span after the first multibyte run. This is a live concern in this corpus, not a
hypothetical one, and it gets a test.

## 5. Providers

Both ship in this change, selected by config.

### 5.1 claude

```lua
{ "claude", "-p", "--output-format", "text", "--model", "sonnet",
  "--safe-mode", "--disable-slash-commands", "--strict-mcp-config" }
```

The three isolation flags are **not re-derived**. `util/claude.lua:81` already carries them as
`M.raw_flags`, with a measurement from 2026-08-26 recorded in its header: `--safe-mode` alone
still left 12 skills reachable, `--disable-slash-commands` is what takes skills to zero, and
`--strict-mcp-config` drops the MCP servers. That is precisely the author's stated requirement,
"claude -p with no skills / plugin loaded; i.e. vanilla claude."

`--model sonnet` is carried over from `config.lua:56` for the reason recorded there: measured
2026-08-28, the CLI's default model returned `{"findings":[]}` on a five-line sample with an
obvious missing `the`, where sonnet found it.

JSON arrives as text and needs the `%b{}` outermost-braces strip that `semantic.lua:126` already
does, because models wrap JSON in a fence often enough that stripping is cheaper than re-prompting.

**Observation, labeled inferred, out of scope for this change.** `config.lua:56` gives the
semantic tier `{ "claude", "-p", "--output-format", "text", "--model", "sonnet" }` with none of
the three isolation flags. Inferring from the argv alone, that tier loads the author's full skill
and MCP surface on every call, which `util/claude.lua`'s header measures at 180 skills, ~160 MCP
tools, and ~2s of a ~7.6s trivial round trip. This has **not** been measured against
`semantic.lua` directly. It is a candidate improvement to raise separately, not a bug to fix while
building something else.

### 5.2 openai

Uses `response_format: {type: "json_schema", strict: true}`, which makes malformed JSON
structurally impossible and removes the entire parse-failure branch, including the user-facing
"the model returned an unreadable response" message at `semantic.lua:245`.

Transport is `curl` via `vim.system`, not `vim.net.request`. `vim.net` exists on the author's
0.12.4 and exposes a single `request` function, but it is experimental, and `curl` is the boring
choice that also gives auditable control over where the credential goes.

**Credential handling.** This is a hard requirement from the author's guardrails, not a
preference.

- The key is read from `vim.env.OPENAI_API_KEY`. Never from config, never from a dotfile, never
  written anywhere.
- The `Authorization` header is passed to curl through `--config -` **on stdin**. It must not go
  in argv: argv is world-readable through `ps`, so `-H "Authorization: Bearer ..."` would expose
  the key to every local process for the lifetime of the request.
- The request body goes to a mode-`0600` temp file referenced as `-d @file`, unlinked in the
  completion callback. The body contains the author's prose and the prompt, not the key.
- A missing key produces an error naming the **variable**, never its value.
- Error paths excerpt `stderr` the way `semantic.lua:238` does. Any excerpt is scrubbed of
  `Bearer` and of the key's value before it reaches `vim.notify`, because curl writes the
  effective request to stderr under some verbosity settings and a notify goes to the message
  history.

## 6. The diff view

`:AlbertLintLevel1` writes the corrected lines into an unlisted scratch buffer, opens it in a
vertical split, and runs `:diffthis` in both windows.

Navigation and apply are Neovim's own: `]c` and `[c` between hunks, `do` to accept a hunk from
the corrected side, `dp` to push the original over it. No apply code in this plugin.

### 6.1 Notes must be mirrored, and this is load-bearing

The label and note appear as `virt_lines_above` extmarks on the corrected side, with an **equal
count of blank `virt_lines` at the same row on the original side**.

The mirror is not cosmetic. Diff mode aligns two windows by filler lines it computes itself;
`virt_lines` add screen rows to one window only. Measured 2026-09-08 with a 5-line pair and one
one-line note on the right buffer only:

```
b.txt: line 3 at screen row 4
a.txt: line 3 at screen row 3
```

Every line below the note was one row out of alignment. With the note mirrored by an equal count
of blanks on the left:

```
b.txt  L1@r1  L2@r3  L3@r4  L4@r6  L5@r7
a.txt  L1@r1  L2@r3  L3@r4  L4@r6  L5@r7
```

Exact alignment restored. An N-line note therefore emits N virtual lines on the corrected side
and N blanks on the original side. This gets a test, because a future reader will see the blank
extmarks as dead code and delete them.

Fallback if mirroring proves flaky in real use: end-of-line `virt_text` instead of `virt_lines`,
which adds no screen rows and so cannot desync, at the cost of truncating the note.

### 6.2 Scope

Default `buffer`, reusing `semantic.scope_range` (`semantic.lua:78-95`) unchanged rather than
forking it. A two-window diff over a single paragraph is not worth the split. An explicit
`:'<,'>` range still wins over the config, matching `:AlbertLintSemantic`.

### 6.3 Teardown

`diffoff!` in both windows and wipe the scratch buffer, triggered on `BufWipeout` of either
buffer as well as by the close command. Without this, closing the scratch buffer by any route the
plugin does not own leaves the author's real buffer permanently in diff mode.

## 7. Error handling

Reuses the paths `semantic.lua` already proved:

- **Per-buffer in-flight guard** (`semantic.lua:22-33`). Without one, a second invocation spawns
  a second CLI process: two paid calls and two sets of results racing. The guard doubles as the
  only liveness signal during the wait, reporting elapsed time when re-invoked.
- **Exit-code check** with a bounded `stderr` excerpt.
- **Unplaced-fix count** in the summary, phrased as an action ("run the check again to place
  them") rather than as parser vocabulary.
- **Zero reads as a verdict, not a no-op.** `semantic.lua:296-303` records why: "0 findings" on
  visibly flawed prose is indistinguishable from "the tool did not really run," and that misled
  the author once for a real reason. The summary names the line count and the scope.

## 8. Testing

`tests/albertlint/level_apply_spec.lua` carries the weight, since `apply.lua` is pure.

| Case | Why |
|---|---|
| two fixes on one line | right-to-left order, or the second offset is stale (§4.1) |
| overlapping spans | first wins, second dropped and counted |
| quote absent from the line | dropped and counted, never guessed |
| quote appearing twice, `occurrence: 2` | resolves to the second instance, not the first |
| `occurrence` past the last instance | unplaceable, dropped and counted, never clamped |
| `occurrence` omitted | defaults to 1 |
| multibyte span (Korean) | byte vs character offsets (§4.2) |
| empty findings array | valid and common; must not error |

`level_provider_spec.lua`:

- the claude argv contains all three isolation flags from `util/claude.lua:81`
- **no** rendered openai argv contains the key or a `Bearer` substring, as a standing regression
  test against the leak in §5.2

`level_diffview_spec.lua`: the mirrored-blank invariant from §6.1, and that teardown leaves the
original buffer with `diff` unset.

`levels_spec.lua`: level 1's prompt carries the ignore list; level 1 declares `spans_only`.

Baseline to hold: 295 passing, 0 failed, 0 errors.

## 9. The prompt

Generic grammar and usage, chosen by the author over two personalized alternatives (injecting the
Fix Log drill list at call time; hardcoding canonical labels). No error history, no filesystem
dependency on the vault, no bias toward finding known patterns where they are absent. The cost,
accepted: returned labels will not match the Fix Log's canonical vocabulary, so they cannot bump
drill counts.

One concession to personalization survives, on the **negative** side only. The prompt carries an
`ignore` list, because the author's `CLAUDE.md` allowlist has settled three families as deliberate
typing shortcuts rather than knowledge gaps:

- contractions with dropped apostrophes (`dont`, `didnt`, `cant`, ...), retired from the drill
  list on 2026-08-27 at 10 instances
- a space before a terminal or medial mark, settled 2026-09-04 at 31 logged instances
- capitalization, skipped by the English Practice flow entirely

Without the ignore list, a generic grammar prompt surfaces exactly these and drowns the findings
that matter. Suppressing known non-issues is a different act from hunting known issues, and only
the second was declined.

## 10. Out of scope

- No autofix outside the diff view, no code actions, no continuous mode.
- No changes to the live, exit, or semantic tiers. The `semantic.lua` isolation-flag observation
  in §5.1 is raised, not acted on.
- No commands for levels 2 through 4.
- **No precision measurement.** `CLAUDE.md` records that nothing about the style tier has been
  measured for precision and that every number in the older spec is recall on text already known
  to be broken. The same caveat applies here: this design makes no claim about Level 1's false
  positive rate. The planned check, a pass over the `After:` column of the Fix Log which should
  return nothing, is not part of this change.

## 11. Open items

1. **`do`/`dp` ergonomics are inferred, not observed.** The accept and reject bindings follow from
   how diff mode works, not from watching the author use this particular view. The first real
   session may send §6 back for revision.
2. **Which provider is better on this corpus is unknown.** Both ship; no comparison has been run.
3. **The retype gate** (§2, rejected) becomes worth revisiting if `do` turns out to be used
   reflexively, since that is the exact failure the original doctrine predicted.
4. **Level 2's boundary is undefined.** "Coherence" needs the same treatment §4 gave level 1: a
   data shape that makes out-of-level edits unrepresentable. Not solved here.
