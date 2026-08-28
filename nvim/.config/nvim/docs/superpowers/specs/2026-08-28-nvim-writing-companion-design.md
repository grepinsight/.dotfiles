# Writing companion: LLM annotations for prose, inside Neovim

Status: draft 4. Steps 1, 2, and part of 3 are implemented, tested, and committed. Open items
from review pass 3 are listed in 15.3 rather than silently closed.
Date: 2026-08-28

Two adversarial review passes by `codex exec` (`gpt-5.6-sol`, reasoning effort `xhigh`,
read-only, instructed to read the modules and verify claims).

- **Pass 1** on the design found two decisions wrong by construction (a fingerprint over mutable
  fields; insert-mode hiding via a function that destroys position tracking) and one conceptual
  error (`orphaned` treated as "addressed").
- **Pass 2** on draft 2 found eleven blocking contradictions, two overstated citations, and a set
  of contracts missing for the steps about to be implemented. Draft 3 closes all of them.
  Section 15 is the audit trail.

Every claim either review made that this document acts on was verified against the source before
acting. Two of pass 2's corrections were to **my** overstatements, recorded in 2.3.

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
| C3 | `attach()` sets `hl_group` unconditionally and `virt_text` when `config.virtual_text` is on (it defaults on); `add_range` never consults `st.visible` | `marks.lua:195`, `marks.lua:200`, `config.lua:44` | A result landing during insert mode renders immediately, **and the highlight alone is enough to violate the rule**. See 7. |
| C4 | `best_match()` does rank by context score then hint distance, but **zero is an acceptable best score** and an exact tie silently keeps the earlier candidate; `resolve()` tier 1 accepts matching text at the old byte range with no context check at all | `anchor.lua:164-176`, `anchor.lua:318-324` | Safe for human-selected phrases, **unsafe for short machine anchors**. See 6.5. |
| C5 | `sync()` sets `record.orphaned = false` whenever the anchor re-resolves, and `resolve()` will happily relocate to another occurrence | `marks.lua:337` | An edited span may relocate rather than orphan. `orphaned` cannot mean "addressed." See 6.2. |

**C3 and C4 as originally written were wrong, and the corrections are mine to own.** Draft 2 said
`virt_text` was unconditional (it is gated on `config.virtual_text`) and that `best_match` took the
first candidate unconditionally (it ranks by score, then distance). Both overstated the defect. The
*consequences* survive intact and in C4's case the real defect is narrower and more interesting: a
zero context score is accepted, so a match with no surviving context on either side still wins.

Two further verified constraints, both found in pass 2:

| # | Fact | Location | Consequence |
|---|---|---|---|
| C6 | `store.write` rebuilds the payload as `{ version, source, marks }`, discarding any other top-level key, **and unlinks the file entirely when `#marks == 0`** | `store.lua:260`, `store.lua:254` | A ledger cannot live inside the mark store. See 6.6. |
| C7 | `fns.hedge_density` takes a single line and counts each hedge phrase at most once, from a 15-phrase list; `nominalized-subject` is a narrow whitelist | `engine.lua:264-282`, `rules.lua:337` | Overlap with the proposed sentence classes is **partial, not duplication**. See 4.2. |

Plus one performance fact, now fixed: `add_range` called `persist(bufnr)` per mark and `next_id`
scanned all marks, so committing N findings one at a time was quadratic. Resolved by `add_many`
(10.2).

## 3. Non-goals

- No prose generation, in any surface.
- No autofix, no code actions, no `:diffget` path.
- No three-column layout (14.3).
- No continuous mode in v1 (see 11).
- No `fact-check` class in v1 (4.4).
- No sentence-level class group in v1 (4.2), and no Setext headings (5.1).
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

Draft 1 had a second group with `buried-verb`, `hedge`, `coined`, and `vague-verdict`. Draft 2 cut
it on the grounds that three of those duplicate existing deterministic rules. **That was
overstated** (C7). What the existing rules actually do:

| Proposed class | Nearest existing rule | What it really covers |
|---|---|---|
| `hedge` | `hedge-density` | Three or more hedges **in one line**, each phrase counted once, from a fixed 15-phrase list. Not over-hedging across a passage. |
| `buried-verb` | `nominalized-subject` | A narrow whitelist of specific nominalizations. Not general nominalization. |
| `coined` | `typo` | Misspellings against a known-words catalogue. Would catch `tankering`, would not catch a morphologically valid coinage like `motivationless`. |

So the overlap is partial. It is a reason for a **dedupe requirement**, not for a cut: an LLM
finding whose span overlaps a live `albertlint` diagnostic of a related rule is suppressed, which
is a span-intersection check in the runner and generalises to any future rule.

The sentence group is still deferred, for a reason that survives scrutiny: **v1 proves the fan-out
machinery with the one group that has measured recall.** The discourse group scored 4/4 twice; the
sentence classes were measured on a different sample and never on a negative corpus.

Draft 2 also claimed `semantic.lua`'s header supports the four discourse classes. **It does not.**
That header names missing definite articles, missing indefinite articles, agreement across an
intervening phrase, and pronoun ambiguity, which are grammar classes (`semantic.lua:3-8`, and its
prompt at `semantic.lua:76-95`). The transferable principle is only the general one, that some
error classes need a model rather than a regex. It is not evidence for `no-claim`, `unlinked`,
`dangling-ref`, or `abandoned`; the only evidence for those is the measurement in 12.

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
  fingerprint = "<16 hex chars>",   -- IMMUTABLE, see 6.1
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

### 5.1 Section parsing, pinned

Draft 2 said "the enclosing markdown heading block" and left every real decision open. Pinned:

- **ATX headings only** (`#` through `######`). Setext (`===` / `---` underlines) is not
  recognised, because `---` is also frontmatter and a horizontal rule and the disambiguation is not
  worth it for one author's notes. Recorded as a limitation, not an oversight.
- A heading line inside a fenced code block **is not a heading**. The mask from `engine.lua`
  (5.2) is applied before headings are scanned, which is the same pass that already tracks fence
  state.
- The section runs from its heading line to the line before **the next heading of the same or
  higher level**, so a `##` block contains its `###` children. This is the reading that matches
  "the unit a claim belongs to"; the alternative (stop at the next heading of any level) would
  split an argument from its own subsections.
- **The heading line is included** in the scanned text, because it is usually the claim the section
  is supposed to make.
- For a configured prose filetype with no ATX headings (`text`, `gitcommit`, `mail`), `section`
  degrades to the whole buffer.

**`scope_key` is the heading path**, not the heading text: the `/`-joined chain of ancestor heading
texts, each whitespace-collapsed and lowercased, with `""` for a file with no headings.

```
"## Symptoms" nested under "# 2026-08-28"   ->   "2026-08-28/symptoms"
```

The path rather than the bare text, so two sections named `Notes` under different parents are
distinguishable, which is what 6.1 needs from it.

**Renaming a heading changes `scope_key`, which changes every fingerprint in that section**, so
dismissed findings there can be raised again. That is accepted, and it is the safe direction: a
renamed section is a different context, and re-raising a finding the author already rejected costs
one dismissal, while suppressing a finding that has become true again costs a real miss. Changing a
heading's *level* reshapes boundaries the same way and is treated identically.

### 5.2 Masking, and how the payload keeps its coordinates

`engine.lua:97-163` builds a boolean mask over the **complete line array**, because fence and
frontmatter state depends on everything above. So the mask is computed for the whole buffer and
then sliced to the scope; it cannot be computed from the scope alone.

Masked spans are replaced **in place, byte for byte, with spaces** rather than removed. This is the
part that has to be right: quotes returned by the model are located by byte offset into the text
that was sent, so the payload must have the same line count and the same byte length per line as
the buffer. Deleting a code block would shift every subsequent offset and silently misplace every
finding after it.

Lines that are entirely masked are still sent, as blank lines. A model asked to judge discourse
across a code block should see that something interrupted the prose.

`min_lines` makes the scope/class interaction declarative rather than an if-chain:

```
n = unmasked non-blank prose lines in scope, excluding the heading line
eligible      = { c : c.min_lines <= n }
groups_to_call = { g : g.classes ∩ eligible ≠ ∅ }
```

**`n` counts prose, not lines.** Raw line count would make a section of one sentence plus a
20-line code block look like 21 lines of argument and let `no-claim` fire on it. The heading is
excluded from the count for the same reason, while still being *sent* (5.1): it is context, not
content the classes judge.

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
fingerprint = vim.fn.sha256(table.concat({
  kind, normalize(text), analyzer, scope_key,
}, "\0")):sub(1, 16)
```

**`scope_key` is in the fingerprint, and has to be.** Without it, the same sentence appearing in
two sections of one note produces one fingerprint, so reconciliation would "touch" the first mark
instead of inserting the second and the second finding would silently never exist. Uniqueness
(6.5) is only checked *within* a scope, so it cannot rescue this. `scope_key` is defined in 5.1.

**`sha256`, not `sha1`.** Draft 1 said `sha1`, which is not implementable here: this Neovim
reports `exists("*sha256") == 1` and `exists("*sha1") == 0` (and no `md5`), so `sha1` would
mean shelling out or vendoring a Lua implementation for no benefit. Truncated to 16 hex
characters, because the fingerprint only has to be collision-free among one file's marks and
64 bits is far past that; the store is human-readable JSON and a full 64-char digest on every
record makes it unreadable.

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

| state | Means | Renders | On re-appearance in a later pass |
|---|---|---|---|
| `active` | Currently reported | yes | touched, not duplicated |
| `dismissed` | Author rejected it | no | stays dismissed (an `analyzer` bump changes the fingerprint, so a revised prompt raises a *different* finding) |
| `resolved` | A later pass over the same scope stopped reporting it | no | **re-activated**, because the problem came back |
| `stale` | Its anchor could not be placed in the current buffer | no | **re-activated and re-placed** |

`resolved` and `dismissed` live in the ledger (6.6), keyed by fingerprint. `stale` keeps its full
record, because it still holds the durable anchor data a later pass needs in order to re-place it.
`active` records are the only ones that render, which is a single equality check rather than a
filter over four states.

`orphaned` stays exactly as it is, for user marks, and AI marks that lose their anchor become
`stale` rather than `orphaned` so they never enter the repair queue.

### 6.3 Reconciliation is the real "addressed" signal

This replaces the orphan mechanism entirely, and it is a better mechanism because it handles the
case where the fix happened elsewhere.

Every pass records: `scan_id`, `scope_key`, the set of classes that were **eligible** (5), and the
set of groups whose calls **succeeded**. Reconciliation is then a total function over five cases,
so no state is left undefined:

| Fingerprint in result? | Existing state | Action |
|---|---|---|
| yes | none | insert as `active` |
| yes | `active` | touch (update `hint` only); never duplicate |
| yes | `dismissed` | stay dismissed |
| yes | `resolved` | **re-activate**: the problem returned |
| yes | `stale` | **re-activate** and re-place the anchor |
| no | `active`, in scope, class eligible, group succeeded | → `resolved` |
| no | `active`, otherwise | untouched |
| no | `stale`, in scope, class eligible, group succeeded | delete: it is gone and unplaceable |
| no | anything else | untouched |

Three qualifiers on the "no" rows, each closing a hole:

1. **Class eligibility.** A one-line scope makes `no-claim` ineligible (5), so its absence from
   that result means nothing. Only marks whose `kind` was eligible for *this* pass can be resolved
   by it. Without this, running the tier on a one-line selection would resolve every `no-claim`
   finding in the section.
2. **Group success.** A group whose call failed or timed out reports nothing, and nothing is not
   evidence of absence. Only marks belonging to a group that **succeeded** can be resolved.
3. **Scope membership for a `stale` mark.** A stale mark has no current range, so containment
   cannot be tested against one. It carries the `scope_key` it was last seen in, and that is what
   is compared. `active` marks are tested by their live extmark position.

Row 6 is the signal the design turns on: add a concluding sentence, rerun, and the `no-claim` mark
resolves itself even though its anchor never moved.

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

1. **Minimum anchor length, applied unconditionally.** A span shorter than 12 characters or fewer
   than 3 words is **expanded** to its enclosing clause (nearest sentence-or-comma boundary on
   each side), not rejected and not exempted for being unique. Draft 2 exempted unique short spans,
   which made this gate dead: every span that passed uniqueness passed the length floor too, so a
   unique bare `this` would have been accepted, which is precisely the case the rule exists to
   stop. Expansion rather than rejection is what makes a `dangling-ref` finding usable at all,
   since the pronoun is the *subject* of the finding and the clause is the *anchor* for it. If
   expansion cannot reach the floor (a one-word line), the finding is dropped.
2. **Uniqueness, checked on the final span after expansion.** Count occurrences of the normalized
   span in the scanned scope. More than one, and the finding is dropped and counted, not guessed
   at. Checking before expansion would test a string that is not the one being stored.
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

**The ledger cannot live in the mark store.** C6: `store.write` rebuilds the payload as
`{ version, source, marks }`, so any extra top-level key is silently discarded on the next write,
and it `unlink`s the file entirely when `#marks == 0`, so a store holding only a ledger would be
deleted. Putting it there means data loss with no error.

So it is a **sidecar owned by this tier**, beside the mark store, and `annotate`'s format is
untouched at `FORMAT_VERSION = 1`:

```
<store_path>            annotate's marks, unchanged
<store_path>.ai.json    this tier's ledger
```

```json
{
  "version": 1,
  "entries": [
    { "fingerprint": "a1b2c3d4e5f60718", "state": "dismissed", "analyzer": "discourse@1", "at": 1756400000 }
  ]
}
```

`analyzer` is stored **explicitly** rather than left inside the opaque fingerprint. Draft 2 said
dismissed entries are kept "until an analyzer bump makes them irrelevant", which was unactionable:
a 16-hex-character digest cannot be asked which analyzer version produced it, so nothing could
identify the stale entries and the ledger grew without bound.

`:AlbertLintStylePrune [days]` (default 30) drops:

- `resolved` entries older than the cutoff, and
- `dismissed` entries whose `analyzer` is not in the current set of analyzer versions, at any age,
  because a prompt revision makes them permanently unmatchable.

Both are now identifiable, so both are collectable.

## 7. Visibility

**Rule:** AI annotations are not *presented* while in insert mode; they appear on `InsertLeave`.
A guiding question is the most disruptive thing that can appear mid-clause, since its whole
purpose is to make the reader stop and think.

**C2 rules out the obvious implementation.** `toggle()` clears the namespace *and* wipes
`st.ids`/`st.rev`, which is exactly the position tracking needed while text changes. Calling it on
every `InsertEnter` would force a full content re-resolve of every mark on every `InsertLeave`,
which is both slow (C4's whole-document search, per mark) and less reliable than the extmarks
Neovim was already maintaining for free.

So: **suppress decoration, never the position extmark.** Two namespaces, and the split is only
sound if the position extmark is *completely invisible*:

| Namespace | Carries | Lifecycle |
|---|---|---|
| `NS_AI_POS` | position only: `end_row`/`end_col`, **no `hl_group`, no `virt_text`** | created on commit, cleared only by a deliberate `rebuild` |
| `NS_AI_DECOR` | `hl_group` and `virt_text`, derived from live `NS_AI_POS` ranges | cleared on `InsertEnter`, rebuilt on `InsertLeave` |

Draft 2 put `hl_group` on the position extmark. **That does not work**: a highlight is visible, so
the primary rule ("nothing is presented during insert mode") was violated by the mechanism meant
to implement it. Every visible attribute belongs to the decoration namespace.

Draft 2 also said `NS_AI_POS` is "never cleared", which contradicted section 8's reliance on
`rebuild` reminting ids. Corrected: it is never cleared *by the visibility path*, and `rebuild`
clears and remints both AI namespaces together, which is why nothing may cache extmark ids across
a callback (8, rule 3).

This also fixes **C3**: a result landing mid-insert creates a position extmark, which is invisible,
and acquires its decoration at `InsertLeave`. No queue, no special case.

Three further consequences:

- **Both AI namespaces are separate from `annotate`'s existing one.** Clearing a shared namespace
  on `InsertEnter` would hide the author's own marks, which they never asked for. User marks and
  `st.visible` are untouched by this mechanism, so the manual toggle and insert suppression are
  independent by construction rather than by a second flag.
- **"Held" was the wrong word, and draft 2 contradicted itself with it.** One model only: a result
  is committed to the store and to `NS_AI_POS` as soon as it validates, so a crash cannot lose it
  and dedupe sees one consistent world. **Only presentation is deferred.** Draft 2 said both
  "immediately creates `NS_AI_POS`" and "new findings are held", which implied two different
  persistence and cancellation models.
- **The pane reads the same gate.** It renders from `NS_AI_DECOR`'s existence, not from the store,
  so it cannot show a finding the buffer is hiding.

## 8. Concurrency and stale results

Each request carries: buffer handle, source path, `scan_id`, `scope_key`, request generation, the
`changedtick` at dispatch, the payload hash, and **the scope range held as a pair of extmarks, not
as line numbers.**

The extmarks matter and are not an optimisation. Line numbers recorded at dispatch stop pointing at
the same text the moment anything is inserted above the scope, so rule 1(c) below would rehash a
*different* region, find a mismatch, and discard a result whose own text never changed. Inserting
one line at the top of the file would invalidate every in-flight pass. Extmarks move with the
buffer, so the region rehashed at completion is the region that was sent. This is the same reason
`annotate` holds mark positions in extmarks rather than in the stored `hint`.

Rules:

1. **Validate before mutating**, in three steps, cheapest first. Draft 2 said "`changedtick`
   unchanged for the scanned range", which is not a thing: `changedtick` is per buffer, not per
   range. Precisely:

   a. The buffer is still valid and still loaded. Fail → drop.
   b. The request generation for this (buffer, group, scope) is still current. Fail → drop.
   c. **The extmark-delimited scope still hashes to the payload hash recorded at dispatch.**
      Buffer `changedtick` is used only as an early-out: unchanged tick means the region is
      certainly unchanged and no rehash is needed. If it moved, rehash the region the extmarks now
      delimit; equal means the edit was outside the scope and the result is still good. Both
      extmarks are deleted in the completion callback, on every path including error and timeout,
      or a cancelled pass leaks two extmarks per attempt.

   Step (c) is what makes the rule usable. A global `changedtick` test with no retry would discard
   every result whenever the author typed anywhere during a 30-to-80-second `claude` call, which is
   most of the time, and the tier would appear to do nothing. Editing paragraph 9 must not
   invalidate a pass over paragraph 2.

   When (c) does fail, v1 **notifies and offers a rerun** rather than failing silently, because the
   author explicitly asked for this pass and silence would read as "no findings". (Continuous mode
   will instead just reschedule, which is why this only matters while the trigger is a command.)

   `semantic.lua` today checks none of this (parse at `semantic.lua:102-116`, dispatch at
   `semantic.lua:158`), which is a latent bug in the existing tier.
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

### 8.1 Fan-out granularity, partial failure, and the timeout

- **Request generation is keyed on `(bufnr, group, scope_key)`.** Not per buffer, which would let a
  pass over one section cancel a pass over another; not per scope alone, which would let two groups
  over the same scope cancel each other.
- **Partial failure never resolves anything.** Each group's result is reconciled independently, and
  only for the classes that group owns (6.3, qualifier 2). If the discourse call succeeds and a
  future second group times out, the second group's classes are simply not reconciled that pass.
  Absence of evidence from a call that never returned is not evidence of absence.
- **The timeout must exceed the observed latency, and today's does not.**
  `config.semantic.timeout_ms` is 30000 (`config.lua:48`) while every recorded `claude -p` run in
  section 12 took 32 to 84 seconds. A 30-second timeout would abort essentially every call. The new
  tier's default is **120000**, chosen as roughly 1.5x the slowest observed run, with its own config
  key so the existing tier's value is not silently changed under it. That the existing tier is
  probably mistimed too is noted here and left alone: it is a separate change with its own
  evidence.

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

**Done, commit `c591b87`.** `config.lua` declared
`---@field scope string "paragraph" | "buffer" | "selection"` and `semantic.lua`'s
`M.run(ns, use_selection)` never read it, branching on the range flag and otherwise calling
`paragraph_range` unconditionally. So `scope = "buffer"` did nothing, and the scope could not be
widened from config. Likely cause of the reported "0 findings" on text with obvious problems: in a
note written as one-line paragraphs, the paragraph under the cursor is one line.

Shipped as `scope_range(bufnr, scope)`, extracted so each scope is testable without a request. An
explicit `:'<,'>` range still wins over the config. An unknown scope warns once and falls back to
`paragraph`. 8 tests, including the regression itself. README updated, since the option is now
real.

### 10.2 `annotate`: batch mutation

**Done, commit `fd525e6`.** `marks.add_many(bufnr, entries) -> records, errors`.

Contract as built, since draft 2 left it unspecified:

- **Entry shape** is `{ range, category, note, meta }`, where `meta` is checked against an
  explicit allowlist (`author`, `kind`, `model`, `analyzer`, `fingerprint`, `state`) and an unknown
  key fails that entry loudly. Draft 3 said metadata was *not* accepted and that the tier would set
  it on returned records instead; that was wrong, because `add_many` persists at the end, so the
  tier would have had to write a second time and lose the single write this function exists for.
  An allowlist keeps the vocabulary explicit without reintroducing that cost.
- **Partial, not atomic.** Bad entries collect into `errors`; good ones are still added. One
  unusable finding in a generated batch must not discard the rest. A caller wanting
  all-or-nothing validates first.
- **`errors` is not index-aligned with `entries`.** It is a list of messages, one per failure, in
  input order. Nothing needs the mapping today, and a sparse array keyed by index is worse to
  consume. Stated so no caller assumes otherwise.
- **Persistence failure is a notification, not a return value**, because `persist` only notifies
  (`marks.lua:171-183`). The records are in memory and correct; the store write failed and the
  author was told. Changing `persist` to return a status is a separate change and not required by
  this tier.
- **One write for the batch**, and **no write at all** when every entry failed.
- `id_allocator` replaces `next_id`: it builds the taken-id set once and records what it mints, so
  a batch is linear rather than quadratic.

17 tests, including a `store.write` spy asserting exactly one write for three marks, which is the
actual claim.

### 10.3 `annotate`: AI lifecycle and two namespaces

- `state` field plus the ledger (6.2, 6.6).
- **Legacy normalization happens in `ensure_loaded`, immediately after `store.read`**, not in
  `store.read` and not in accessors. Every in-memory record therefore carries `author` and `state`
  before anything reads it, so `state == "active"` is a safe equality test rather than a trap that
  hides every pre-existing mark. `store.read` is left alone because it is `annotate`'s boundary and
  should not learn about AI fields; accessors are the wrong place because there are several and one
  missed call site reintroduces the bug.
- `NS_AI_POS` / `NS_AI_DECOR`, both separate from `annotate`'s existing namespace (7).
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

## 15. Review audit trail

### Pass 1, on the design

Accepted, each verified against source first: immutable fingerprint excluding `prefix`/`suffix`
(C1); explicit `state` with `orphaned` untouched (C5 plus three existing consumers); reconciliation
instead of orphan-as-resolution; the position/decoration namespace split (C2); anchor length,
uniqueness and ambiguity gates (C4); compact inline markers instead of whole notes at EOL; scope
default moved off `buffer`; a compact ledger instead of full-record tombstones; export and picker
filtering; `BufFilePost`; response validation; `changedtick` validation.

Declined: cutting the quickfix projection. Deferred instead, with the objections answered (14.2).

### Pass 2, on draft 2

Two of my citations were **wrong** and are corrected in 2.3: C3 (`virt_text` is gated on
`config.virtual_text`, not unconditional) and C4 (`best_match` does rank candidates; the real defect
is that a zero context score is acceptable and ties keep the earlier candidate). A third
overstatement is corrected in 4.2: `semantic.lua`'s header names grammar classes, not the discourse
classes, so it is not evidence for them.

Eleven blocking contradictions, all closed:

| # | Contradiction | Where it is closed |
|---|---|---|
| 1 | Minimum anchor length was dead, since uniqueness already rejected everything it would have | 6.5: the floor applies unconditionally and **expands** the span rather than rejecting it |
| 2 | Identical text in two sections produced one fingerprint, so the second finding vanished | 6.1: `scope_key` is in the fingerprint |
| 3 | Nothing deleted `dismissed` ledger entries, and the opaque digest could not reveal its analyzer | 6.6: `analyzer` stored explicitly; prune collects both states |
| 4 | `resolved` and `stale` had no reconciliation cases | 6.3: a total case table over all five states |
| 5 | A `stale` mark has no range, so scope membership was undefined | 6.3 qualifier 3: it carries `scope_key` and is compared on that |
| 6 | `NS_POSITION` carried `hl_group`, which is visible, defeating the rule it implemented | 7: the position extmark carries no visible attribute at all |
| 7 | Results were both "committed immediately" and "held" | 7: one persistence model; only presentation defers |
| 8 | Strict `changedtick` would drop every result during sustained typing | 8 rule 1: range payload hash, with `changedtick` only as an early-out |
| 9 | Reconciliation ignored class eligibility | 6.3 qualifier 1 |
| 10 | "Same scope" was undefined and heading identity unstable | 5.1: `scope_key` is the heading path, and renaming invalidates deliberately |
| 11 | Build sequence claimed steps 1-4 were network-free while step 4 calls `claude` | 16: steps 1-3 |

Missing contracts, now pinned: store versioning (6.6, via a sidecar, because C6 makes an in-store
ledger lossy); the `add_many` contract (10.2); the legacy normalization point (10.3); rename
semantics (10.5); ATX-only section parsing with the same-or-higher-level boundary rule (5.1);
`min_lines` counting unmasked prose (5); mask-to-payload byte preservation (5.2); request
generation granularity, partial-fan-out semantics, and the timeout (8.1); and a build step for
every command named in prose (16).

Also corrected: draft 2's section 15 claimed it had added "budget and backoff semantics". **It had
not.** Those belong to continuous mode, which is deferred, and they are now listed in step 7 rather
than asserted as present.

### 15.3 Open after review pass 3

Pass 3 audited draft 3 against the eleven and found five not closed. Fixed in code where the
defect was in code; the remaining spec-level items are listed honestly rather than marked done.

**Fixed in code** (commit following this one):

| Finding | Fix |
|---|---|
| `retarget` called `index_add` before writing and returned `true` unconditionally, so a refused write left the index listing a store that does not exist | `persist` now returns a status; `retarget` rolls `st.source` back and returns false. `index_add` removed, since `store.write` does it after a successful write |
| `add_many`'s "errors are collected" was false: a malformed range threw inside `anchor.build` and aborted the batch | per-entry `pcall` around the anchor build |
| `add_many` attached an extmark even for a record created already `dismissed` | attach only when `state == "active"` |
| The selection clamp only clamped the end, so a buffer shrunk past both marks yielded an empty range | clamp both, fall back to paragraph if the result is empty |
| The README and two docstrings claimed none of the four semantic classes can fire on one line | corrected: two of the four need prior context, the other two can fire in one sentence. The zero-findings symptom was observed, not derived |

**Still open, spec-level, and to be settled before step 4:**

1. **`scope_key` is not unique.** Two sibling `## Notes` sections under the same parent produce the
   same key, and `buffer`/`paragraph`/`selection` scopes have no identity defined at all. That
   breaks fingerprint distinctness (2), stale scope membership (5), and request-generation keying
   (8.1), all of which key on it. Likely fix: append a stable disambiguator (occurrence index among
   same-path siblings) plus a scope-kind prefix, e.g. `section:alpha/notes#2`, `selection:12-40`.
2. **A heading rename leaves an unprunable dismissal.** Its `analyzer` is still current so the
   prune rule never collects it, and its `scope_key` no longer matches so it is never reachable.
   Needs either a rename-aware migration or a reachability-based prune.
3. **A `stale` record has no pruning rule at all** and keeps its historical `scope_key` forever.
4. **The store-and-ledger transition is two writes with no ordering defined.** "Active in store and
   dismissed in ledger" is reachable if one write fails, and is outside 6.3's table.
5. **The ledger sidecar has three holes**: removing the last mark unlinks the base store and leaves
   `.ai.json` orphaned with no index to find it; `retarget` does not copy it, so a rename loses
   dismissal history; and `store_path` appends `.json` before the ledger appends `.ai.json`, so the
   ledger for `/x` collides with the mark store for `/x.json.ai`.
6. **Extmark gravity at both scope boundaries is unpinned** (8), so an insertion exactly at a
   boundary may be included or excluded arbitrarily.
7. **The pane's insert-mode gate is not implementable as written** (13.2): it re-renders only on
   `AlbertLintStyleChanged`, and clearing decoration extmarks cannot change an already-rendered
   pane buffer. It needs its own `InsertEnter`/`InsertLeave` handling.
8. **`marks.lua` line citations throughout this document are stale** after `fd525e6` and later
   commits. They were accurate when written and are not re-verified per commit.

Items 1 to 5 all trace to one root cause: **`scope_key` was designed as a display-ish path and then
used as an identity.** Fixing 1 properly is likely to close 2, 3, and part of 5.

Also worth recording: pass 3 noted the dismissed-finding tombstone currently lives as a full record
in the mark array rather than in the ledger, which contradicts 6.6. That is not a defect in the
code, it is the ledger simply not being built yet. Step 2b is not finished.

## 16. Build sequence

Each step compiles, passes tests, and is committed alone. **Steps 1 to 3 involve no network call**
(draft 2 said 1 to 4, which contradicted step 4 invoking `claude`), so the majority of the logic is
reviewable before prompt quality is in question.

| # | Step | Status |
|---|---|---|
| 1 | **Fix `semantic.scope`** (10.1). Standalone bug. | **done**, `c591b87`, 8 tests |
| 2a | **`annotate` batch and rename**: `add_many`, `id_allocator`, `retarget` + `BufFilePost`. | **done**, `fd525e6`, 17 tests |
| 2b | **`annotate` AI lifecycle**: `state` field, legacy normalization in `ensure_loaded`, the sidecar ledger, `dismiss`, `NS_AI_POS`/`NS_AI_DECOR`, export and picker filtering. | next |
| 3 | **Data files and pure logic**: `classes.lua`, `groups.lua`, section parsing and `scope_key` (5.1), masking-to-payload (5.2), `min_lines`, fingerprint, reconciliation (6.3), anchor-safety wrapper (6.5), response validation (9). No network. | |
| 4 | **Runner, on demand, `claude` only**: `:AlbertLintStyle` over a section or selection, per-group fan-out, validation (8), commit via `add_many`. | |
| 5 | **Inline markers, `:AlbertLintStyleList`, the hover, `:AlbertLintStyleDismiss`, `:AlbertLintStylePrune`, `:AlbertLintStyleRecheck`, `:AlbertLintStyleExport`.** | |
| 6 | **Negative-corpus precision run** over the fix log's `After:` text (14.1). | |
| 7 | **v2, gated on step 6**: continuous mode with its budget and backoff, OpenAI provider, `vague-verdict`, the pane, the location-list projection. | |

Every command named in prose now has a step. Draft 2 required `prune`, `recheck`, and the AI export
in text without placing them anywhere in the sequence.

## 17. Testing

Follows the existing harness (`tests/minimal_init.lua`, plenary busted, `tests/<module>/`).

Pure logic:

- `min_lines`: a 1-line scope excludes `no-claim` and `unlinked`; a group with no eligible classes
  is not called.
- Fingerprint stability: changing `prefix`/`suffix` does not change the fingerprint; changing
  `analyzer` does; whitespace reflow does not.
- Reconciliation: a finding absent from a later pass over the same scope becomes `resolved`; one
  outside the scanned scope is untouched; a `dismissed` fingerprint is not re-raised.
- Anchor safety: a span under the minimum length is **expanded to its enclosing clause**, and
  dropped only when expansion cannot reach the floor; a span occurring twice in the scope is
  dropped, not guessed; a zero-context-score match is rejected. (Draft 3's plan said "rejected",
  contradicting 6.5.)
- Response validation: unknown `kind` dropped; non-substring `quote` dropped; a finding carrying a
  `replacement` field rejected; over-cap response truncated and reported.
- Store compatibility: a store with no `author`/`state` loads, marks read as `user`/`active`,
  `FORMAT_VERSION` unchanged.

Editor state:

- `add_many` persists once for N entries.
- A result landing during insert mode creates a position extmark and no decoration; the decoration
  appears on `InsertLeave`.
- Manual `toggle` and insert suppression are independent.
- A result whose **scanned region** changed is dropped; a result whose `changedtick` moved
  because of an edit *outside* the region is still applied. (Draft 3's plan said any changed tick
  is dropped, contradicting 8 rule 1c.)
- `:AnnotateExport` omits AI marks; `:AlbertLintStyleExport` includes only them.

Provider `extract` regression tests, all four observed for real during measurement, so these are
regressions rather than hypotheticals: fenced JSON, bare JSON, empty response, thinking-block-only
response.
