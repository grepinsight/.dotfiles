# nvim-annotate: fast in-buffer phrase annotation

**Status:** approved design, 2026-08-26
**Scope:** a local Lua module in this config (`lua/annotate/`), not a distributed plugin.

## Problem

While reading prose in Neovim, mostly markdown notes in the Obsidian vault, I want to
mark a word, phrase, or paragraph with a category in one keystroke, so I can review the
collected material later. Categories start as idiom, jargon, great expression, great
phrase, plus a free-text note. Marks persist across sessions in JSON and can be exported
to a single markdown review note in the vault.

The two hard requirements that shape everything else:

1. **Capture must be instant.** A visual selection plus one keymap, no prompt for the
   common case. Friction here kills the habit.
2. **Marks must survive editing**, including edits made outside Neovim. These notes are
   also edited in Obsidian, which reflows paragraphs and shifts line numbers freely.

## Non-goals

- Not a distributed plugin. No `plugin/` directory, no lazy.nvim spec for a remote repo.
- No cross-machine sync of marks. The exported markdown is what travels; the JSON is
  machine-local. (Sidecar storage mode makes syncing possible, but it is not the default.)
- No merging of the same phrase marked in two different files. Export groups them under
  the same category but keeps them as separate entries with separate backlinks.
- No annotation of non-text buffers, terminals, or unnamed buffers.

## Architecture

Seven modules under `lua/annotate/`. The split exists so the hard part, anchor
resolution, is pure and testable without a running editor. `custom_commands.lua` at
1389 lines is the counterexample already in this repo.

| Module | Responsibility | Depends on |
|---|---|---|
| `init.lua` | `setup()`, merge and validate config, register commands and keymaps, define highlight groups | config, marks, export, picker |
| `config.lua` | Defaults, validation, resolved accessors | — |
| `store.lua` | Path mapping (central/sidecar), atomic JSON read and write, quarantine of bad files | config |
| `anchor.lua` | Build an anchor from a selection; resolve an anchor against buffer lines | — (pure, no `vim.api`) |
| `marks.lua` | Per-buffer extmark to record map; add, delete, edit note; render | anchor, store, config |
| `export.lua` | Read all stores, render the grouped markdown review note | store, config |
| `picker.lua` | Telescope picker with `vim.ui.select` fallback | marks, store |

### Why extmarks plus content anchors

Neovim extmarks track buffer edits natively, so within a session highlights never drift
as you type. They do not help when the file changes outside Neovim, which is the common
case here because the same notes are edited in Obsidian. Content anchors cover that: on
load we re-locate each mark by its stored text and surrounding context.

Rejected alternatives:

- **Re-resolve on every render, no extmarks.** Simpler, but highlights drift on every
  insert until the next re-scan. Permanently worse feel for a small build saving.
- **Persist extmark positions only.** Any Obsidian edit silently misaligns every mark
  below it. Wrong for this workflow specifically.

## Data format

One JSON file per annotated source file.

```json
{
  "version": 1,
  "source": "~/Thoughts/03-Resources/English/Bat a Thousand.md",
  "marks": [
    {
      "id": "1756240980-3",
      "category": "idiom",
      "note": "use when a decision is overdue",
      "text": "bite the bullet",
      "prefix": "we just have to ",
      "suffix": " and ship it",
      "hint": { "start": [40, 16], "end": [40, 31] },
      "created_at": "2026-08-26T14:03:00-07:00",
      "orphaned": false
    }
  ]
}
```

Field decisions:

- `category` is **required**, `note` is **optional**. A free-text-only mark gets
  `category: "note"`. This differs from the original either/or framing: making category
  mandatory keeps every mark filterable, and allowing a note on any mark means the
  free-text option is additive rather than exclusive.
- `hint` is **0-indexed** `[line, col]` to match `nvim_buf_set_extmark` directly, so no
  off-by-one conversion layer exists.
- `id` is `os.time()` plus a per-file counter. Neovim has no UUID in stdlib and this file
  has a single writer, so a monotonic pair is sufficient.
- `version` gates the format. A store written by a newer version is refused for both read
  and write rather than silently downgraded.
- `text` for a multi-line (linewise) mark joins lines with `\n`.
- `orphaned` is set when resolution fails. The record is kept, not deleted.

### Storage layout

Default mode is `central`, path-mirrored so stores stay greppable:

```
~/.local/share/nvim/annotate~/Thoughts/03-Resources/English/Bat a Thousand.md.json
```

Chosen over sidecar files because the vault is synced and indexed by Obsidian; sibling
`.json` files would show up in its file explorer and in vault-wide greps.

Configurable alternatives, both implemented:

- `sidecar_hidden`: `<dir>/.annotations/<filename>.json` next to the source. Travels with
  vault sync; Obsidian ignores dot-directories.
- `sidecar`: `<file>.json` beside the source. Simplest to find, visible in Obsidian.

## Config surface

```lua
require("annotate").setup({
  categories = {
    idiom      = { key = "i", label = "Idiom",            hl = "AnnotateIdiom" },
    jargon     = { key = "j", label = "Jargon",           hl = "AnnotateJargon" },
    expression = { key = "e", label = "Great expression", hl = "AnnotateExpression" },
    phrase     = { key = "p", label = "Great phrase",     hl = "AnnotatePhrase" },
    note       = { key = "n", label = "Note",             hl = "AnnotateNote", prompt = true },
  },
  storage = { mode = "central", dir = vim.fn.stdpath("data") .. "/annotate" },
  export  = { path = require("util.vault").path("03-Resources/English/Marked Phrases.md") },
  context_chars = 40,
  virtual_text  = true,
  filetypes = { "markdown", "text", "quarto", "org" },
  prefix = "<leader>a",
})
```

Adding a category is one table entry: label, key, highlight group. No code change.
`prompt = true` on a category means capture asks for note text before saving.

Highlight groups are defined with `default = true` and link to existing colorscheme
groups, using underline rather than background so prose stays readable. A colorscheme
change therefore cannot break them, and explicit user overrides win.

## Keymaps and commands

Visual mode, under the configured `prefix`:

| Key | Action |
|---|---|
| `<leader>ai` | mark as idiom, no prompt |
| `<leader>aj` | mark as jargon, no prompt |
| `<leader>ae` | mark as great expression, no prompt |
| `<leader>ap` | mark as great phrase, no prompt |
| `<leader>an` | prompt for free text, mark as note |

Normal mode:

| Key / command | Action |
|---|---|
| `<leader>aN` / `:AnnotateNote` | add or edit the note on the mark under the cursor |
| `<leader>ad` / `:AnnotateDelete` | delete the mark under the cursor |
| `<leader>al` / `:AnnotateList` | picker over all marks |
| `:AnnotateOrphans` | picker filtered to orphaned marks |
| `:AnnotateExport` | regenerate the markdown review note |
| `:AnnotateToggle` | show/hide highlights in this buffer |

Keymaps are generated from `config.categories`, so they stay in sync with the taxonomy
automatically.

## Anchor resolution

`anchor.resolve(lines, mark)` returns a range or `nil`. Three tiers, cheapest first.

1. **Hint hit.** Read buffer text at `mark.hint`. If it equals `mark.text`, accept. O(1),
   and the common case when nothing changed.
2. **Content search.** Find every occurrence of `mark.text` using plain string search,
   never regex, because phrases contain `.`, `(`, `*`. Score each candidate by context
   overlap: longest common suffix between the candidate's preceding text and
   `mark.prefix`, plus longest common prefix between its following text and
   `mark.suffix`. Tie-break on line distance from the hint, then earliest position.
   Rewrite the hint on success.
3. **Reflow search.** If tier 2 finds nothing, retry against a whitespace-normalized
   projection of the buffer and map the hit back to real positions. This tier exists
   because Obsidian and prettier reflow paragraphs, changing line breaks without changing
   a single word, which tier 2 would miss entirely.

   One refinement found while building it: a whitespace run containing **two or more
   newlines normalizes to `"\n"`, not to a space**, so a paragraph break stays a hard
   boundary. Collapsing everything to spaces would let `"the"` at the end of one
   paragraph join `"bullet"` at the start of the next into a phantom match. Needle and
   document go through the same normalizer, so a mark that genuinely spans a paragraph
   break still matches one.

   The tiers are ordered by trustworthiness, not by cost: a literal match wins over a
   whitespace-insensitive one even where both would succeed.

Failing all three sets `orphaned = true`. The mark is kept, not highlighted, and surfaces
in `:AnnotateOrphans` with its stored context so it can be re-marked or discarded
deliberately.

### Anchor construction

From a visual selection:

- `text` is the selected text, lines joined with `\n`.
- `prefix` is up to `context_chars` characters immediately before the selection start,
  possibly spanning into previous lines.
- `suffix` is up to `context_chars` characters immediately after the selection end.
- Charwise (`v`) and linewise (`V`) are supported. Blockwise (`<C-v>`) is refused: a
  rectangle over prose has no single meaningful string.

## Lifecycle

- **On mark add / delete / note edit:** write JSON immediately. Deliberately *not* tied
  to `BufWritePost`, because a file may be annotated and never saved.
- **`BufReadPost`** (configured filetypes only): a single `fs_stat` checks whether a store
  exists. If not, do nothing, so unannotated files cost nothing. If yes, load, resolve,
  create extmarks.
- **`BufWritePost`:** for each mark, compare the extmark's current text against
  `mark.text`. If they match, refresh `prefix`, `suffix`, and `hint` from the current
  buffer. If they differ, the user edited *inside* the mark: re-run `anchor.resolve`, and
  orphan the mark if that fails. Never overwrite `mark.text` from the extmark.
- **`TextChanged`:** nothing. Extmarks track edits themselves.

### Verified extmark behavior (2026-08-26, nvim 0.12.4)

Probed empirically because the whole approach depends on it:

| Edit | Result |
|---|---|
| Lines inserted above | extmark moves correctly |
| Text inserted earlier on the same line | columns shift correctly |
| Line above deleted | moves correctly |
| Edit *inside* the marked range | range survives, but its text becomes wrong (`"bite the bullet"` became `" the bullet"`) |
| Whole marked line deleted | extmark collapses to **zero-width**, it does *not* disappear |

Two consequences, both load-bearing:

1. `BufWritePost` must not blindly refresh `mark.text` from the extmark. Doing so would
   silently rewrite a good anchor into a corrupt fragment. Hence the compare-first rule
   above.
2. Deletion cannot be detected by "extmark is gone". Empty extmark text is the deletion
   signal, and such a mark is orphaned rather than dropped.

## Failure handling

| Failure | Behavior |
|---|---|
| Malformed JSON | Rename to `<file>.bad-<timestamp>`, notify at ERROR with both paths, continue with an empty set. Never discarded silently. |
| `version` newer than supported | Refuse to load **and** refuse to write that file. Prevents clobbering a newer format. |
| Buffer has no filename | Refuse to mark, explain why. |
| Blockwise visual selection | Refuse, tell the user to use `v` or `V`. |
| Store directory unwritable | Notify with the path and the OS error. A mark is never silently lost. |
| Export target directory missing | `mkdir -p`, matching existing `OpenDaily` behavior in this repo. |
| Export vs. manual edits | Generated content lives between `<!-- annotate:begin -->` and `<!-- annotate:end -->`. Only that block is replaced. Anything outside survives regeneration. |
| Crash mid-write | All writes go to `<path>.tmp` then `fs_rename`, so a store is never truncated. |
| Marked text edited in place | Re-resolve on save; orphan only if resolution fails. `mark.text` is never overwritten from the buffer. |
| Marked line deleted | Extmark collapses to zero width; empty text is treated as deletion and the mark is orphaned, not dropped. |

## Export format

`:AnnotateExport` reads every store and regenerates one markdown note, grouped by
category, idempotently.

```markdown
# Marked Phrases

<!-- annotate:begin -->
## Idiom

- **bite the bullet** — [[Some Note]]
  > we just have to bite the bullet and ship it

  note: use when a decision is overdue

## Jargon

- **backpressure** — [[Distributed Systems]]
  > ...the backpressure step merges...
<!-- annotate:end -->
```

Each entry carries the phrase, its stored context as a blockquote, the optional note, and
a wiki link back to the source note (basename without extension, for Obsidian). Orphaned
marks are excluded from export; they are a repair queue, not review material.

## Testing

Plenary is already installed as a telescope dependency, so `plenary.busted` adds no new
plugin. The currently empty `test.sh` becomes the runner.

`anchor.lua` is pure, so it carries most of the coverage:

- build: charwise single-line, charwise multi-line, linewise paragraph, selection at
  buffer start (empty prefix), selection at buffer end (empty suffix)
- resolve tier 1: unchanged buffer, hint accepted
- resolve tier 2: ten lines inserted above, relocated and hint rewritten
- resolve tier 2: phrase occurs three times, only context disambiguates
- resolve tier 2: two occurrences in *identical* context, result must be deterministic
- resolve tier 3: reflowed paragraph found via normalized search
- resolve failure: text deleted, marked orphaned, no crash
- phrase containing regex metacharacters, found by plain search

`store_spec`: central and sidecar path mapping round-trip, malformed JSON quarantined
rather than deleted, version gate refuses, no `.tmp` left behind.

`export_spec`: grouping by category, delimiter block replaced not appended, text outside
delimiters preserved, empty input yields a valid note.

`marks_spec`: the thin integration layer that needs a real buffer. Add creates an
extmark; inserting lines moves it; delete removes both extmark and record.

Determinism: `os.time` and `created_at` are injected as a clock function defaulting to
`os.time`, so tests pin a fixed clock. No sleeps, no randomness.

## Installation note

`~/.config/nvim/lua/` uses per-item symlinks into this repo, so `lua/annotate/` needs one
new symlink:

```
~/.config/nvim/lua/annotate -> ../../../.dotfiles/nvim/.config/nvim/lua/annotate
```

`init.lua` gains a `require("annotate").setup({})` call alongside the existing
`require("custom_commands")`.
