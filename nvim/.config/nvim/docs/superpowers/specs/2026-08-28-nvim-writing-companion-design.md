# Writing companion: LLM annotations for prose, inside Neovim

Status: draft 2, revised after an adversarial review. No code written yet.
Date: 2026-08-28

Draft 1 was reviewed by `codex exec` (`gpt-5.6-sol`, reasoning effort `xhigh`, read-only, with
instructions to read the actual modules). It found two decisions that were wrong by construction
and several week-one problems that were missing. Section 15 records what changed and what I
declined. Every claim it made that this draft acts on was verified against the source first.

## 1. Goal and the one hard constraint

An AI reader that sits in the buffer while the author writes English prose, and helps with
grammar, clarity, weak points, brainstorming, pushback, and guiding questions.

**Hard constraint, decided deliberately:** the AI may produce only *annotations and questions*
anchored to a span of text. It never produces replacement prose.

The reason is the stated goal: "the goal is to actually HAVE me write." A diff hunk containing a
rewritten sentence has a one-keystroke accept path, which is the fastest available route to a
document the author did not write. An annotation has no accept key; the only way to resolve one is
to type something. The constraint protects the writing practice, not the output.

**Grammar help is allowed, autofix is not.** The deterministic tier of `albertlint` already works
this way: its messages name the correct form and still make you type it.

Rejected alternatives, recorded so they are not silently revisited:

| Option | Why rejected |
|---|---|
| Annotations plus mechanical diffs (brand caps, double spaces) | Author declined even the zero-voice fixes. Accepting a diff is a habit, and the habit is what erodes. |
| Annotations plus prose rewrites, accept/reject | Directly defeats the goal. |
| A chat interface in a split | Explicitly not wanted: "not a chat interface like Claude Code." |

## 2. What already exists

### 2.1 `lua/annotate/` (7 modules, tested)

| Capability | Location |
|---|---|
| Anchored marks over a word, phrase, or paragraph | `marks.lua` |
| Durable anchors in pure Lua, resolved by content | `anchor.lua` |
| 40 chars of `prefix`/`suffix` per mark | `config.lua:context_chars` |
| Atomic JSON persistence keyed by source path | `store.lua` |
| Orphan detection | `marks.lua`, `picker.lua` |
| Config-driven categories with per-category highlight | `config.lua` |
| Virtual text at `virt_text_pos = "eol"` | `marks.lua:196` |
| Telescope picker with `vim.ui.select` fallback | `picker.lua` |
| Idempotent markdown export | `export.lua` |

Stored record today: `{ id, category, note, text, prefix, suffix, hint, created_at, orphaned }`.

### 2.2 `lua/albertlint/` (5 modules, 33 tests)

Three tiers: `live` (debounced single-token regex), `exit` (sentence-level on InsertLeave),
`semantic` (on demand, `claude -p`, JSON, rendered as diagnostics).

Borrowed here:

- **Rules as data, logic in one place.** `rules.lua` is a catalogue; `engine.lua` holds a `fns`
  table for matchers needing real logic. The new tier copies that split rather than inventing one.
- **The false-positive doctrine**, from `config.lua`: "A linter that cries wolf in prose gets
  disabled within a week, so a rule earns its place in the default set by having a low
  false-positive rate, not by being high-value." This governs every default below, and it is the
  reason for most of the v1 cuts.

### 2.3 Five verified constraints in the existing code

These were found during review and each one changes a design decision. All verified by reading the
source, not taken on report.

| # | Fact | Location | Consequence |
|---|---|---|---|
| C1 | `sync()` overwrites `record.prefix` and `record.suffix` from current buffer text | `marks.lua:326-336` | A fingerprint derived from those fields is **unstable**. See 6.1. |
| C2 | `toggle()` clears the namespace **and** does `st.ids, st.rev = {}, {}` | `marks.lua:357` | Cannot be reused for insert-mode hiding: it destroys position tracking mid-edit. See 7. |
| C3 | `attach()` sets an extmark with `virt_text` unconditionally; `add_range` never checks `st.visible` | `marks.lua:196`, `marks.lua:397` | A result landing during insert mode renders immediately. See 7. |
| C4 | `best_match()` takes the first candidate unconditionally, with no minimum context score and no ambiguity check; `resolve()` tier 1 accepts matching text at the old byte range with no context check at all | `anchor.lua:154`, `anchor.lua:318` | Safe for human-selected phrases, **unsafe for short machine anchors**. See 6.3. |
| C5 | `sync()` sets `record.orphaned = false` whenever the anchor re-resolves, and `resolve()` will happily relocate to another occurrence | `marks.lua:337` | An edited span may relocate rather than orphan. `orphaned` cannot mean "addressed." See 6.2. |

Plus one performance fact: `add_range` calls `persist(bufnr)` per mark (`marks.lua:420`) and
`next_id` scans all marks (`marks.lua:44`), so committing N findings one at a time is quadratic.

## 3. Non-goals

- No prose generation, in any surface.
- No autofix, no code actions, no `:diffget` path.
- No three-column layout (14.3).
- No continuous mode in v1 (see 11).
- No `fact-check` class in v1 (4.4).
- No sentence-level class group in v1 (4.2).
- No conversation state. Each pass is stateless; memory lives in the mark store.
- No new dependency. Telescope stays optional, as in `picker.lua`.

## 4. Findings

### 4.1 Classes: `lua/albertlint/style/classes.lua`

```lua
{
  id = "no-claim",
  group = "discourse",
  min_lines = 3,
  category = "ai-question",
  marker = "?",                -- compact inline marker, NOT the full note
  description = "The passage lists facts but never states what they add up to.",
}
```

**v1 ships one group, `discourse`, with four classes:**

| id | min_lines | Evidence |
|---|---|---|
| `no-claim` | 3 | gpt-5.4-nano effort medium, 4/4 across 2 runs |
| `unlinked` | 2 | Same |
| `dangling-ref` | 1 | Same |
| `abandoned` | 1 | Found by every model tested, including qwen3:8b |

### 4.2 Why the sentence group is cut from v1

Draft 1 had a second group with `buried-verb`, `hedge`, `coined`, and `vague-verdict`. Three of
those **duplicate deterministic rules that already exist**:

| Proposed class | Existing rule | Location |
|---|---|---|
| `hedge` | `hedge-density` ("Three or more hedges in one paragraph") | `rules.lua:356` |
| `buried-verb` | `nominalized-subject` | `rules.lua:337` |
| `coined` | `typo` (with a known-words catalogue at `rules.lua:420`) | `rules.lua:345` |

Shipping both means the author receives the same criticism twice through two different UI systems,
one as a diagnostic and one as a persistent annotation. That is worse than either alone.

The `discourse` group has no such overlap, and that is not a coincidence: `semantic.lua`'s own
header says those classes exist precisely because "pattern matching cannot detect" them. The four
discourse classes are the ones where an LLM is the only available detector.

`vague-verdict` is the one sentence-level class with no deterministic counterpart. It is deferred
to v2 rather than shipped alone, so v1 makes exactly one API call and the group machinery is
proven with one group before a second is added.

**The two-group machinery stays** (`groups.lua` is still a data file and the runner still fans
out), because the measurement that justified it stands: on the author's sample, the 9-class
combined prompt found 2 findings with one mislabelled, while discourse-only found 3-4 correctly and
sentence-only found 2 non-overlapping ones. Combining classes into one prompt loses recall. v1
simply ships one row in that file.

`monotone` is cut outright: it never fired in any configuration across every model tested.

### 4.3 The extended mark record

```lua
{
  -- existing
  id, category, note, text, prefix, suffix, hint, created_at, orphaned,
  -- new, all optional so v1 stores load unchanged
  author      = "llm",              -- absent means "user"
  kind        = "no-claim",
  model       = "gpt-5.4-nano",
  analyzer    = "discourse@1",      -- group id + prompt version, see 6.4
  fingerprint = "<sha1>",           -- IMMUTABLE, see 6.1
  state       = "active",           -- see 6.2
  scan_id     = "<uuid>",           -- which pass produced it, see 6.2
}
```

`FORMAT_VERSION` stays at 1: adding optional fields is not a breaking change to the on-disk shape.
A test must assert that a store written without these fields loads and its marks read as
`author == "user"`, `state == "active"`.

### 4.4 Categories, and why `fact-check` is not one

Two new categories, one per severity of intrusion, not one per class:

```lua
["ai-question"] = { key = "Q", label = "AI question",   hl = "AnnotateAiQuestion", order = 6 },
["ai-note"]     = { key = "N", label = "AI note",       hl = "AnnotateAiNote",     order = 7 },
```

Eight classes do not need eight visual treatments. The class id lives in `kind` and shows in the
pane; the category controls only appearance and export grouping.

**No `ai-fact` category in v1.** A fact-check annotation is a claim about the world, and the
author's standing instructions forbid speculating on domain facts without a source and require
inferences be labelled as inferences. An LLM will assert confidently and without one. When it
lands in v2 it carries a rule enforced in `classes.lua`, not suggested in a prompt: **it may raise
a doubt with a reason drawn from the text, never a verdict about the world.**
`"'several days' contradicts 'this week' two lines down"` is an internal-consistency check the
model can perform. `"sitting does not cause temporal headaches"` is a medical claim it has no
standing to assert into a personal note.

## 5. Scope

`"paragraph" | "section" | "buffer" | "selection"`. **Default: `section`.**

Draft 1 defaulted to `buffer`. That was a correction of a real bug (10.1) but it overshot.
Whole-buffer analysis mixes unrelated sections, which makes a `no-claim` verdict meaningless
across a note containing four independent topics, and it uploads more text than the finding needs.
A single paragraph is too narrow in the other direction: `unlinked` is by definition about two
adjacent units, and `no-claim` needs the whole argument.

`section` means the enclosing markdown heading block, falling back to the whole buffer when the
file has no headings. That is the unit a claim actually belongs to.

`min_lines` makes the scope/class interaction declarative rather than an if-chain:

```
n = lines in scope
eligible      = { c : c.min_lines <= n }
groups_to_call = { g : g.classes ∩ eligible ≠ ∅ }
```

A group with no eligible classes is **not called**. This is the same idea as `tier = "live" |
"exit"` in `rules.lua` ("a sentence-level rule cannot judge a sentence you have not finished
typing"), moved one level up.

**Prose selection.** `engine.lua:90` already masks frontmatter, fenced code, inline code, URLs,
and link targets, and deliberately does not mask link *text*. The payload sent to a provider
reuses that masking. Without it, whole-section analysis uploads code blocks (noise, cost, and a
prompt-injection surface, since a fenced block in a pasted log can contain instructions).

## 6. Lifecycle: the part draft 1 got wrong

### 6.1 The fingerprint is immutable

Draft 1 keyed dedupe on `hash(text + prefix + suffix + kind)`. **C1 makes that unstable**:
`sync()` rewrites `prefix` and `suffix` from current buffer text, so a mark's identity would drift
as unrelated nearby text changed, and dedupe would silently stop working.

Fix: compute `fingerprint` **once, at creation**, from the anchor as it was observed, and never
recompute it:

```
fingerprint = sha1(kind .. "\0" .. normalize(text) .. "\0" .. analyzer)
```

`normalize` collapses whitespace and lowercases, so a reflow does not create a new identity.
`prefix`/`suffix` are excluded precisely because they are mutable. `analyzer` is included so a
prompt revision can legitimately re-raise a finding a previous version's user dismissed (6.4).

The fingerprint answers "is this the same observation." It does **not** answer "is this still
valid," which is 6.2.

### 6.2 Explicit lifecycle states, and `orphaned` keeps its existing meaning

Draft 1 treated `orphaned` as "the author addressed it." That was the biggest error in it, and it
is wrong in both directions:

- **C5**: an edited span may *relocate* rather than orphan, because `resolve()` searches the whole
  document for the old text and `sync()` then sets `orphaned = false`. So editing may not orphan.
- A discourse finding can be addressed **without touching its anchor at all.** Adding a
  concluding sentence resolves `no-claim` while the marked span survives unchanged. So orphaning is
  not necessary either.

And `orphaned` already means something else to three existing consumers: `:AnnotateOrphans` lists
them as broken anchors needing repair (`picker.lua:27`), `export.lua:144` excludes them as
unresolvable, and `sync()` un-orphans them on re-resolution. Overloading it would flood a repair
queue with successes.

So AI marks get their own `state`, and `orphaned` is left alone:

| state | Means | Renders | Blocks re-raise |
|---|---|---|---|
| `active` | Currently reported | yes | yes |
| `dismissed` | Author rejected the finding | no | yes, until an `analyzer` bump |
| `resolved` | A later pass over the same scope no longer reports it | no | no |
| `stale` | Anchor could not be resolved in the current buffer | no | no |

`orphaned` stays exactly as it is, for user marks, and AI marks that lose their anchor become
`stale` rather than `orphaned` so they never enter the repair queue.

### 6.3 Reconciliation is the real "addressed" signal

This replaces the orphan mechanism entirely, and it is a better mechanism because it handles the
case where the fix happened elsewhere.

Every pass carries a `scan_id` and records the exact scope it covered. On a successful pass:

1. Findings in the result whose fingerprint is unknown → insert as `active`.
2. Findings in the result whose fingerprint exists as `active` → touch, do not duplicate.
3. Findings in the result whose fingerprint exists as `dismissed` → **stay dismissed**, do not
   re-raise.
4. Marks that were `active`, whose anchor lies **inside the scope just scanned**, and whose
   fingerprint is **absent** from the result → transition to `resolved`.

Step 4 is the signal. Add a concluding sentence, rerun, and the `no-claim` mark resolves itself
even though its anchor never moved. Nothing about it depends on anchor failure.

Marks outside the scanned scope are never touched, which is why the scope must be recorded on the
scan and not inferred.

### 6.4 Rechecking after a prompt change

Because `analyzer` (group id plus prompt version) is inside the fingerprint, bumping the prompt
version changes every fingerprint, so improved prompts can legitimately raise findings an earlier
version's dismissals had suppressed. That is intended, and it is the reason dismissal is not
permanent.

`:AlbertLintStyleRecheck` additionally clears `dismissed` for the current buffer on request, for
the case where the author changed their mind rather than the prompt changing.

### 6.5 Anchor safety at machine volume

**C4** is the constraint: `best_match` returns the highest-scoring candidate even when every
candidate scores zero, and `resolve` tier 1 accepts matching text at the old byte range with no
context check. For a human-selected phrase like `bite the bullet` that is fine. For a machine
anchor like `it's fine` or a bare `this` it will confidently attach to the wrong occurrence.

Three mitigations, all on the new tier so `anchor.lua`'s behaviour for user marks is unchanged:

1. **Minimum anchor length.** Reject a finding whose quoted span is shorter than 12 characters or
   fewer than 3 words unless it is unique in the scope. A `dangling-ref` finding about the word
   `this` anchors to the *clause containing it*, not to the pronoun.
2. **Uniqueness requirement at insert time.** Count occurrences of the normalized span in the
   scanned scope. More than one, and the finding is dropped and counted, not guessed at.
3. **Ambiguity-aware resolution.** The new tier calls a wrapper that requires a positive context
   score and rejects a tie, rather than calling `anchor.resolve` directly. A mark that cannot be
   placed unambiguously becomes `stale` rather than landing somewhere plausible.

Rationale for the strictness: **a stored mark on the wrong span is corruption that outlives the
session**, whereas a dropped finding costs one missed note. This inverts draft 1's quickfix-era
decision to keep unlocatable entries at `col = 1`, which was right for a throwaway list and wrong
for a persistent mark.

### 6.6 Tombstone growth

Suppression records must not live in the anchored-mark array forever: `next_id` scans it,
`sync` iterates it, `render` walks it, and `store.write` re-encodes it. Full records for every
dismissed finding make every one of those progressively slower.

`dismissed` and `resolved` AI marks are compacted into a separate ledger in the same store file:

```json
{ "version": 1, "marks": [...], "ai_ledger": [ { "fingerprint": "...", "state": "dismissed", "at": 1756... } ] }
```

The ledger holds only what dedupe needs. `:AlbertLintStylePrune [days]` (default 30) drops
`resolved` entries; `dismissed` entries are kept until an `analyzer` bump makes them irrelevant.

## 7. Visibility

**Rule:** AI annotations are not *presented* while in insert mode; they appear on `InsertLeave`.
A guiding question is the most disruptive thing that can appear mid-clause, since its whole
purpose is to make the reader stop and think.

**C2 rules out the obvious implementation.** `toggle()` clears the namespace *and* wipes
`st.ids`/`st.rev`, which is exactly the position tracking needed while text changes. Calling it on
every `InsertEnter` would force a full content re-resolve of every mark on every `InsertLeave`,
which is both slow (C4's whole-document search, per mark) and less reliable than the extmarks
Neovim was already maintaining for free.

So: **suppress decoration, never the extmark.** Two namespaces:

- `NS_POSITION` holds the position extmark, with `hl_group` only. Never cleared during a session.
- `NS_DECOR` holds the virtual text. Cleared on `InsertEnter`, rebuilt on `InsertLeave` from the
  live positions in `NS_POSITION`.

This also fixes **C3**: a result landing mid-insert inserts into `NS_POSITION` and simply does not
get a decoration until insert mode ends. No special case, no queue.

Two further consequences:

- Insert suppression applies to **AI marks only**. The existing namespace holds user marks too,
  and clearing it would hide the author's own annotations, which they never asked for.
- `st.visible` (the manual toggle) and insert suppression are now genuinely independent, because
  they act on different namespaces. No second boolean, no interaction to test for.
- **The pane must obey the same gate.** Otherwise the "non-disruptive" design still changes text
  beside the sentence being written. New findings are held and published to both surfaces at
  `InsertLeave`, together.

## 8. Concurrency and stale results

Each request carries: buffer handle, source path, `scan_id`, request generation, the `changedtick`
at dispatch, the exact scope range, and the payload hash.

Rules:

1. **Validate before mutating.** On completion, re-check that the buffer is still valid, that the
   generation is current, and that `changedtick` is unchanged for the scanned range. Fail any check
   and the result is **dropped**, not translated. `semantic.lua` today checks neither buffer
   validity nor `changedtick` (`semantic.lua:98`, `semantic.lua:117`), which is a latent bug in
   the existing tier.
2. **Cancellation is cleanup, not correctness.** Killing a `vim.system` handle does not unschedule
   an already-queued callback, and a remote call may already have been billed. The generation check
   in rule 1 is what provides correctness; the kill only saves resources.
3. **Never cache extmark ids across a callback.** `sync()` ends by calling `rebuild()`, which
   clears the namespace and mints new ids (`marks.lua:301`, `marks.lua:244`). Requests and the pane
   hold logical mark ids only.
4. **All session mutation goes through the live `marks` state.** No provider, pane, or projection
   reads and rewrites the store directly. `store.write` has no compare-and-swap and shares a fixed
   `<path>.tmp` name (`store.lua:143`, `store.lua:247`), so two Neovim processes on one file can
   already lose marks; machine writing raises the odds and the single-writer rule is the cheap
   containment. Multi-process safety is out of scope and recorded as a known limitation.

Within one Neovim instance, scheduled Lua callbacks are serialized, so this is not a data race.
The hazard is committing an obsolete snapshot.

## 9. Response validation

`semantic.lua`'s parser checks only that the response is a JSON object with a `findings` key
(`semantic.lua:63`). For a tier that writes persistent state, that is not enough:

- `kind` must be in the class allowlist for the group that was called. Unknown kinds are dropped.
- `quote` must be a byte-exact substring of the scanned text, and unique in it (6.5).
- `message` is truncated to a bounded length and stripped of control characters and newlines.
- Unexpected top-level fields are ignored; unexpected fields on a finding are dropped.
- **A finding carrying anything that looks like replacement prose** (a `suggestion`, `fix`, or
  `replacement` field) is rejected and logged, because that violates section 1 and the tier must
  enforce its own constraint rather than trust the prompt.
- Findings are capped per pass (default 20). A response with more is truncated and the truncation
  is reported, following the no-silent-caps rule.

## 10. Changes to existing modules

### 10.1 Bug: `semantic.scope` is dead config

`config.lua` declares `---@field scope string "paragraph" | "buffer" | "selection"` and
`semantic.lua`'s `M.run(ns, use_selection)` never reads it, branching on the range flag and
otherwise calling `paragraph_range` unconditionally. So `scope = "buffer"` does nothing, and the
scope could not be widened from config. **Ships first, as its own commit.** Likely cause of the
reported "0 findings" on text with obvious problems.

### 10.2 `annotate`: batch mutation

Add `marks.add_many(bufnr, entries) -> records, errors`: build every anchor, attach every extmark,
persist **once**. `add_range` becomes a one-entry wrapper so existing behaviour and tests are
untouched. Also hoist the `config.handles_filetype` check ahead of the batch so a disabled
filetype produces one message rather than N.

`next_id` currently rebuilds a `taken` set per call by scanning all marks. Batch insertion should
build that set once per batch.

### 10.3 `annotate`: AI lifecycle and two namespaces

- `state` field plus the ledger (6.2, 6.6).
- `NS_POSITION` / `NS_DECOR` split (7).
- `marks.dismiss_at_cursor`, distinct from `delete_at_cursor` which keeps deleting outright for
  user marks.
- Rendering filters to `state == "active"`.

### 10.4 `annotate`: keep AI marks out of human workflows

- `export.lua` currently exports every non-orphaned mark of any category, including unknown ones
  (`export.lua:153`, `export.lua:219`). The export target is a collection of *marked phrases*, and
  AI criticism does not belong in it. Export filters to `author ~= "llm"` by default, with a
  separate `:AlbertLintStyleExport` for the AI review note.
- `picker.entries()` reads the JSON directly (`picker.lua:27`), so its positions lag extmark
  movement until `BufWritePost`. `:AnnotateList` filters out AI marks; the pane is the AI surface.
- Legacy marks have no `author`; absent must read as `user` everywhere, not as a falsy AI mark.

### 10.5 `annotate`: rename handling

`BufState.source` is frozen at load (`marks.lua:150`) and there is no `BufFilePost` autocmd
(`init.lua:148`), so after `:saveas` marks continue writing under the old filename. Pre-existing
bug, surfaced by review, fixed here because machine writing makes it likely rather than rare.

## 11. What is deferred out of v1

Cut on the codebase's own false-positive doctrine and on the honest limits of the measurement.

| Deferred | Why |
|---|---|
| **Continuous mode** | The measurement reports *recall on six positive lines*. It says nothing about precision on ordinary prose, and a durable false positive is worse than a transient diagnostic. Needs a negative-corpus run first (14.1). |
| **Ollama as any default** | 1/4 measured recall means silently absent three quarters of the time. Fine as a free offline option, not as a default companion. |
| **Multiple providers** | v1 ships one path. Fewer failure modes while the prompt quality is still unknown. |
| **Direct OpenAI HTTPS as default** | See 12. |
| **`vague-verdict`, `fact-check`, sentence group** | 4.2, 4.4. |
| **The quickfix projection** | See 14.2, where I disagree with the reviewer but still defer it. |
| **Companion pane (phase B)** | 13. Built after A has been used on real writing. |

## 12. Provider and credentials

**v1 uses the existing `claude -p` path.** Not because it is faster (it is much slower: 32-84s
versus 2-12s through direct HTTPS, where most of the gap is process startup) but because
`config.lua` records a deliberate decision:

> Shells out rather than embedding an API key. The CLI already holds credentials, so the plugin
> never sees one.

Reversing a recorded security decision in the same change that introduces a new subsystem means
two risky things land together. v1 keeps the credential posture and eats the latency, which is
tolerable for an on-demand command and would not be for continuous mode. Continuous mode and the
OpenAI provider land together in v2, deliberately, with the reversal stated.

When it does land, the constraint is: **the key never appears in argv**, because `ps` is
world-readable. That rules out `-H "Authorization: Bearer $KEY"` and any `sh -c` wrapper, since the
shell expands the variable into curl's argv inside the child. The form is `curl -K -`, config on
stdin with the `header` line, body in a `0600` temp file as `data-binary = @path`, unlinked in the
completion callback including on error paths. Error text is scrubbed of bearer patterns before
reaching `vim.notify`. A missing key is a clear error naming the provider, never a silent fallback
to a different destination.

Measurements retained for when v2 chooses a model (discourse prompt, author's sample, ground truth
4 findings, 2 runs each):

| Model / config | Wall clock | Recall |
|---|---|---|
| `gpt-5.4-nano` effort `medium` | 7.9s / 8.7s | **4/4, 4/4** |
| `gpt-5.6-sol` | 12.1s | 4/4 |
| `gpt-5.4-nano` effort `low` | 3.9s / 3.6s | 3/4, 3/4 |
| `gpt-4.1-mini` | 3.4s / 3.5s | 3/4, 3/4 |
| `gpt-5.6-luna` | 10.9s | 3/4 |
| `gpt-5.4-mini` effort `medium` | 11.4s / 5.2s | 2/4, 2/4 |
| `gpt-5.5` | 10.2s | 2/4 |
| `qwen3:8b` local, `think:false` | 4.2s | 1/4 |
| `gpt-5.6-terra` | 8.8s | 1/4 |
| `gpt-4.1-nano` | 2.2s | 0/4 |
| `claude -p` haiku | 32s / 39s / 84s | 3, 3, 4 |
| `claude -p` sonnet | 56s / 80s | 4-5 |

Two gotchas that belong in code comments: `reasoning_effort: "minimal"` is rejected by the
`gpt-5.4` family (supported values start at `none`), and `think: false` is mandatory for `qwen3`
via ollama or the JSON never arrives. Also `ollama run` with stdin hung past 120s while
`/api/generate` answered in 4.2s.

## 13. Surfaces

### 13.1 Inline (v1): compact markers only

`albertlint/init.lua:195` records the reason: prose is read left to right, and a floating message
per line breaks that. `annotate`'s `attach()` puts the *entire note* in an unbounded end-of-line
virtual text (`marks.lua:183`), which is fine for one human mark per line and collapses when three
machine findings share a line.

So inline shows the class marker and nothing else:

```
My head hurts. slightly behind temple areas, above the ears.
               ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  ?
I've been sleep deprived for several days.
Also, I have been sitting and now standing up a lot this week.  ?
I feel motivationless. I feel l                                !
```

The full note lives in the pane, in `:AlbertLintStyleList`, and in a hover
(`vim.lsp.util.open_floating_preview` or a plain float) on demand. `marker` is a field on the class
row, so it is data.

### 13.2 The pane (phase B): a projection, never a second source

- `nofile`, `nomodifiable`, unlisted, filetype `albertlint-style`.
- Renders from `marks.state(bufnr)` filtered to `author == "llm"` and `state == "active"`, ordered
  by live extmark position so two groups completing in either order produce a stable list.
- Re-renders on one event: a `User AlbertLintStyleChanged` autocmd fired by the runner after a
  batch lands, and by dismiss/prune/recheck. No polling, no `CursorMoved` re-render.
- **Cursor sync is one-directional.** Source movement passively highlights the pane row. Pane
  movement does **not** move the source; `<CR>` in the pane jumps explicitly. Two `CursorMoved`
  handlers pointing at each other is the classic sync loop, and making one direction an explicit
  keypress removes the possibility rather than guarding against it.
- Tracks **logical mark ids**, never extmark ids (8, rule 3), and offers cycling for overlapping
  spans rather than relying on `at_cursor`'s innermost-extmark heuristic (`marks.lua:474`).
- **Pane state is window/tab scoped, not buffer scoped.** One buffer can appear in two splits;
  extmarks are buffer-global. Helpers that assume window `0` (`marks.lua:483`,
  `semantic.lua:18`) must take an explicit window, or operating from the pane targets the pane.
- Obeys the insert-mode gate (7).

`marks.state()` currently returns the raw mutable table (`marks.lua:570`). The pane needs a
read-only projection plus the change event, so that boundary is added rather than the pane reaching
into internals.

## 14. Open questions and stated trades

### 14.1 Precision is unmeasured

Every number in section 12 is recall on text known to contain problems. Nothing here measures
false positives on ordinary prose, which is the metric the codebase's own doctrine cares about. The
fix log is a labelled corpus (`Original` / `Fixed` / `Pattern`, thousands of rows) and its `After:`
text is a negative corpus: a pass over it should return nothing. **Continuous mode is blocked on
that run**, and v1's on-demand-only scope means it is not blocked on it.

### 14.2 Where I disagree with the reviewer: quickfix

The review recommended cutting the quickfix projection outright, on the grounds that it is a third
position model whose static line numbers conflict with extmarks, that refreshing it on every edit
resets navigation, and that it clobbers the user's global list.

I am deferring it rather than cutting it, because **the author asked for it explicitly** ("so I
know which line to look at") and an agent's architectural preference does not override a stated
requirement. The objections are answerable:

- Use a **location list** (`setloclist`), which is window-scoped, so the global quickfix list is
  never touched.
- Generate it **only on an explicit command**, never on edit. It is a snapshot the author asked
  for, and a snapshot going stale is understood behaviour for a quickfix list in every other Vim
  workflow.

It is deferred only because the pane covers the same need better, and shipping both at once means
three surfaces before any of them has been used in anger.

### 14.3 Not the third column

The original sketch had text, a diff of AI suggestions, and annotations. The diff column is cut on
principle (section 1). Three text columns at 80 each plus number columns wants roughly 250 terminal
columns, and an annotation three columns from the phrase it describes loses the adjacency that
makes it legible. 13.2 is the version of that idea that survives a laptop screen.

### 14.4 Unexplained measurement

`gpt-5.4-nano` beat `gpt-5.4-mini`, `gpt-5.5`, and two of the three `gpt-5.6` variants. Recorded as
observed, not understood. n=2 per config on one short text.

### 14.5 Prompt generation from the author's own notes

`~/Thoughts/03-Resources/English/Better English/` holds 25 notes with `be_originals`,
`be_replacement`, `be_move`, and `be_recurrence`. Generating the sentence-level prompt from them
would give that group the same "every rule traces to a real slip" property `rules.lua` has, with
`Lead With the Action` at 49 recurrences as rule one. Attractive, and out of scope for v1.

### 14.6 Known limitation: multi-process

`store.write` has no compare-and-swap and uses a fixed temp name, so two Neovim instances editing
one file can lose marks. Pre-existing, not introduced here, and not fixed here. The single-writer
rule (8, rule 4) contains it within a session.

## 15. What changed from draft 1, and why

Accepted from the review, each verified against source first:

| Change | Driver |
|---|---|
| Immutable `fingerprint` excluding `prefix`/`suffix` | C1: `sync()` mutates them |
| Explicit `state` field; `orphaned` untouched | C5 plus three existing consumers of `orphaned` |
| Reconciliation replaces orphan-as-resolution | A discourse finding can be fixed without touching its anchor |
| `NS_POSITION` / `NS_DECOR` split | C2: `toggle()` destroys tracking; also fixes C3 |
| Anchor length, uniqueness, and ambiguity gates | C4: `best_match` has no minimum score |
| Sentence group cut from v1 | Three of four classes duplicate existing deterministic rules |
| Compact inline markers, notes in the pane | `attach()` puts whole notes at EOL; `albertlint` already rejected that pattern |
| Continuous mode, OpenAI provider, ollama default deferred | Precision unmeasured; two risky changes should not land together |
| Scope default `section`, not `buffer` | Whole-buffer mixes unrelated topics; paragraph is too narrow |
| Compact ledger instead of full-record tombstones | Every store operation walks the mark array |
| Export/picker filtering, `BufFilePost`, response validation, budget and backoff semantics | Week-one problems that draft 1 missed |
| `changedtick` and generation validation | The existing semantic tier checks neither |

Declined: cutting the quickfix projection (14.2, deferred with the objections answered instead).

## 16. Build sequence

Each step compiles, passes tests, and is committed alone. Steps 1-4 involve no network call, which
means the majority of this is reviewable before prompt quality is in question.

1. **Fix `semantic.scope`** (10.1). Wire the field, test each value. Standalone bug.
2. **`annotate` foundation**: `add_many`, batch `next_id`, `NS_POSITION`/`NS_DECOR`, `state` field,
   ledger, `dismiss`, export/picker filtering, `BufFilePost`. All testable headless.
3. **Data files and pure logic**: `classes.lua`, `groups.lua`, `min_lines` filter, fingerprint,
   reconciliation, the anchor-safety wrapper, response validation. No network.
4. **Runner, on demand, `claude` provider only**: `:AlbertLintStyle` over a section or selection,
   masking via `engine.lua`, `changedtick` validation, commit via `add_many`.
5. **Inline markers plus `:AlbertLintStyleList` and the hover.**
6. **Negative-corpus precision run** over the fix log's `After:` text (14.1).
7. **v2, gated on step 6**: continuous mode, OpenAI provider, `vague-verdict`, the pane, and the
   location-list projection.

## 17. Testing

Follows the existing harness (`tests/minimal_init.lua`, plenary busted, `tests/<module>/`).

Pure logic:

- `min_lines`: a 1-line scope excludes `no-claim` and `unlinked`; a group with no eligible classes
  is not called.
- Fingerprint stability: changing `prefix`/`suffix` does not change the fingerprint; changing
  `analyzer` does; whitespace reflow does not.
- Reconciliation: a finding absent from a later pass over the same scope becomes `resolved`; one
  outside the scanned scope is untouched; a `dismissed` fingerprint is not re-raised.
- Anchor safety: a span under the minimum length is rejected; a span occurring twice in the scope
  is dropped, not guessed; a zero-context-score match is rejected.
- Response validation: unknown `kind` dropped; non-substring `quote` dropped; a finding carrying a
  `replacement` field rejected; over-cap response truncated and reported.
- Store compatibility: a store with no `author`/`state` loads, marks read as `user`/`active`,
  `FORMAT_VERSION` unchanged.

Editor state:

- `add_many` persists once for N entries.
- A result landing during insert mode creates a position extmark and no decoration; the decoration
  appears on `InsertLeave`.
- Manual `toggle` and insert suppression are independent.
- A result whose `changedtick` moved is dropped, not applied.
- `:AnnotateExport` omits AI marks; `:AlbertLintStyleExport` includes only them.

Provider `extract` regression tests, all four observed for real during measurement, so these are
regressions rather than hypotheticals: fenced JSON, bare JSON, empty response, thinking-block-only
response.
