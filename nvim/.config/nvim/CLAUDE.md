# Working in this Neovim config

Conventions and traps for this repo. Written 2026-09-01 while handing off mid-project.

## Traps that cost real time

**`~/.config/nvim` is not a symlink to this repo.** It is a real directory whose entries are
symlinked individually, and `~/.config/nvim/lua/` has **one symlink per module**. A new
top-level module under `lua/` is invisible to Neovim until it gets its own link:

```bash
cd ~/.config/nvim/lua && ln -s ../../../.dotfiles/nvim/.config/nvim/lua/<module> <module>
```

The failure is confusing rather than obvious: `init.lua` *is* symlinked, so your `require` line
runs and fails with `module not found` while the file plainly exists in the repo you just edited.
Subdirectories of an already-linked module (`albertlint/style/`, `albertlint/collocation/`) need
nothing.

**Whatever branch is checked out is what Neovim loads,** because of the above. Switching branches
silently changes the user's editor.

**`:AlbertLintReload` cannot reload itself.** It clears `rules`, `engine`, `semantic`, `config`,
and `collocation.index`, and re-applies the opts stored at `setup()`. But a change to
`init.lua` or to the reload command itself needs a full restart. This cost an hour once: a fix
teaching `semantic.lua` to read a config field could not be picked up by any command, so setting
the field at runtime wrote to something the loaded module never read.

**The user often has uncommitted work in `lua/plugins/`.** As of this writing: `cmp.lua`
(modified), `lsp/copilot_gate.lua` and `tests/lsp/` (untracked). **Never `git add -A`** or
`git add lua/`. Stage explicit paths. This was violated once and required a
`reset --soft` plus `restore --staged` to unpick.

## Testing

```bash
cd ~/.dotfiles/nvim/.config/nvim
PLENARY_DIR=~/.local/share/nvim/lazy/plenary.nvim nvim --headless \
  -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests { minimal_init = 'tests/minimal_init.lua' }"
```

393 tests as of 2026-09-08 (275 as of 2026-09-01; the count moves, so treat it as a floor and diff per-file rather than pinning a total). Run before and after every change. `tests/minimal_init.lua` is
deliberately minimal and does not load `plugins.lua`; ignore the `telescope.builtin not found`
and `UpdateRemotePlugins` noise from specs that `:edit` a real file.

## Design conventions

**Data, not logic.** `rules.lua` is a catalogue; `engine.lua` holds a `fns` table for matchers
needing real code. `style/classes.lua` and `collocation` follow the same split. Adding a rule or
a finding class should be one row.

**Pure modules for the hard parts.** `annotate/anchor.lua`, `albertlint/style/scope.lua`, and
`albertlint/collocation/index.lua` use no `vim.api` and no filesystem, so the logic most likely
to be wrong is testable with string literals. Keep new hard logic in that shape and put the
`vim.*` calls in a thin caller.

**The false-positive doctrine**, from `albertlint/config.lua` and it governs every default:

> A linter that cries wolf in prose gets disabled within a week, so a rule earns its place in
> the default set by having a low false-positive rate, not by being high-value.

**Comments explain why, not what.** Existing comments record the failure that motivated the
code, often with a date and a measurement. Match that. A comment saying what the next line does
is noise here.

## The hard constraint on AI-generated prose help

**For the user's own English writing, the AI may produce only annotations and questions anchored
to a span. Never replacement prose.** Chosen deliberately: a diff hunk with a rewritten sentence
has a one-keystroke accept path, and the stated goal is "to actually HAVE me write." An
annotation has no accept key, so the only way to resolve it is to type something.

Consequences already encoded, do not undo them:

- `copilot_gate.lua` blocks Copilot from markdown outright.
- `collocation/index.lua` caps a completion surface at **five words**. A word or short
  collocation is vocabulary; a clause is composition. If that cap comes off, the completion
  source becomes the thing the user deliberately blocked.
- The deterministic tier names the fix in its message and still makes the user type it. No
  autofix, no code actions.

### Scoped exception, decided 2026-09-08: the graded level commands

**`:AlbertLintLevel1` shows replacement prose in a diff with an accept key (`do`), which the
constraint above rules out.** The user was shown the conflict, restated the requirement as
"review and decide accept/reject by hunk", and confirmed it. This is written down because the
constraint above is forceful enough that an agent reading only it would find this feature,
classify it as a violation, and delete it.

The exception is **narrow**. It covers the `:AlbertLintLevel*` commands only. Everything in the
list above still holds: the live, exit, and semantic tiers keep the no-autofix rule,
`copilot_gate.lua` still blocks Copilot from markdown, and the collocation source still caps a
surface at five words. Do not widen it.

What the original reasoning got right, and what this design preserves: the danger is
*unattributed* replacement prose arriving in bulk. Level 1 answers that structurally rather than
by refusing to show a fix. The model returns labeled spans, not a rewritten paragraph, so a
reorder or a tone change is **unrepresentable** rather than merely forbidden by prompt, and every
diff hunk traces back to exactly one named finding. See
`docs/superpowers/specs/2026-09-08-albertlint-graded-levels-design.md` §2 and §4.

If the accept key turns out to be used reflexively, the alternative to revisit is the **retype
gate** (spec §2, rejected as over-built): the diff shows the fix, but applying it requires typing
the corrected span. Do not revert to annotations-only; that option was considered and declined.

## Commit style

Conventional commits (`feat(nvim):`, `fix(nvim):`, `docs(nvim):`). Bodies explain the *why* and
name the measurement or the failure that motivated the change. **No AI authorship trailers** —
the user's global instructions forbid them.

## State of play, 2026-09-08

Branch `feat/albertlint-levels`, off `master` at `f5ca555`. The `feat/writing-companion` work
this file used to point at has since landed on `master`.

| Component | State |
|---|---|
| `albertlint` live + exit tiers | done, pre-existing |
| `albertlint` semantic tier | working. Was silent for two independent reasons, both fixed: a dead `scope` config field, and the CLI's default model returning `{"findings":[]}` where sonnet finds the error |
| `albertlint/level/` | **level 1 done.** `:AlbertLintLevel1` renders a grammar/usage pass as a native two-window diff, `do`/`dp` per hunk. Both `claude` and `openai` backends. Levels 2-4 are data rows only |
| `albertlint/collocation/` | **done and wired.** nvim-cmp source over the user's own phrase notes. See `README.md` |
| `albertlint/style/` | **~1/3 built.** `scope.lua` only. The runner, classes, groups, providers, and reconciliation are unwritten |
| `annotate` AI lifecycle | partly built: `author`/`state`/`dismiss`/`add_many`/`retarget` done, the dismissal **ledger is not** |

**Read `docs/superpowers/specs/2026-08-28-nvim-writing-companion-design.md` before touching the
style tier.** It is draft 5, reviewed adversarially three times by `codex exec`, and §15.3 lists
eight open items with the five that are genuinely unresolved. Its `marks.lua:NNN` citations are
stale after later commits; treat a mismatch as drift.

The next concrete step is the dismissal ledger (spec §6.6, a sidecar `ai/` tree, not a suffix),
then the runner (§16 step 4).

**Nothing about the style tier has been measured for precision.** Every number in the spec is
recall on text already known to be broken. The planned check is a pass over the `After:` column
of `~/Thoughts/03-Resources/English/English Fix Log.md`, which should return nothing. Do not
enable a continuous mode before that runs.
