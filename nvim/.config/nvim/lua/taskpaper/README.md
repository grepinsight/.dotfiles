# taskpaper

The TaskPaper app's menus, rebuilt as a filetype: four item types formatted, and the Organize,
Move, and Fold/Focus groups of behaviour as keys.

Written here rather than vendored because no maintained plugin exists to start from.
`davidoc/taskpaper.vim` was last pushed 2015-10-03, its only real fork is archived, and Neovim
0.12 does not detect `.taskpaper` at all, which is why detection lives in `autocmds.vim:18`
rather than coming for free.

## Indentation *is* the data model

Read this before anything else, because every other behaviour in this module is downstream of it
and the failure mode does not look like an indentation problem. (`→` below is one hard
tab.)

`outline.level` is the only thing that establishes structure. A project owns the lines *indented
under it*, not the lines that follow it. So this file has one project with two children:

```
2026-09-16:
→   - buy milk
→   - pay rent
```

and this file, whose text is identical, has three items at level 0 and a project with **no
children at all**:

```
2026-09-16:
- buy milk
- pay rent
```

The second case is what a file looks like when it was typed rather than outlined, and everything
degrades quietly rather than erroring:

| Feature | On the childless project |
|---|---|
| Focus In | refuses: `nothing to focus here` |
| `zc` | nothing folds, and no fold marker appears in the gutter |
| Move Up/Down | moves the heading alone, leaving its tasks behind |

Focus In refuses because `enclosing_item` reads a subtree of one line as a **leaf** and resolves a
leaf to its parent, and a level-0 project has no parent (`outline.lua:270`). The warning is
accurate and says nothing about the cause; the cause is always that the children are at column 0.
Diagnosed 2026-09-18 from a real file, after the same key worked three lines further down.

The fix is `<Tab>` over the children, not a change here. A level-0 task genuinely belongs to no
project, and inferring otherwise from adjacency would make Move to Project guess.

## Keys

`<localleader>` is a space (`init.lua:2`). The app's own shortcuts are Cmd-based and a terminal
cannot deliver Cmd at all, so every binding below is an adaptation, not a copy.

| App menu item | App | Here | Command |
|---|---|---|---|
| Move Right / Left | `Ctrl-Cmd-←→` | `<Tab>` `<S-Tab>`, `<Space>l` `<Space>h`, `<M-l>` `<M-h>` | `:TaskPaperMoveRight` / `Left` |
| Move Up / Down | `Ctrl-Cmd-↑↓` | `<Space>k` `<Space>j`, `<M-k>` `<M-j>` | `:TaskPaperMoveUp` / `Down` |
| Move to Project… | `Cmd-\` | `<Space>\` | `:TaskPaperMoveToProject` |
| Mark as Done | click the dash | `<Space>d`, also over a visual range | `:TaskPaperToggleDone` |
| Focus In | `Opt-Cmd-→` | `<Space>f` | `:TaskPaperFocusIn` |
| Focus Out | `Opt-Cmd-←` | `<Space>F` | `:TaskPaperFocusOut` |
| Go Home | `Shift-Cmd-H` | `<Space>H` | `:TaskPaperHome[!]` |
| the eight Expand/Collapse items | — | `zo zc zO zC zr zm zR zM` | none, see below |

Two deliberate collisions. `<Tab>` in normal mode costs `<C-i>`'s jumplist jump in these buffers,
since they are one keycode in a terminal; it is worth it because an outline indent has to carry
the subtree and `>>` does not. Visual mode keeps plain `>gv`, because a selection is already
explicit and inferring a subtree there would move lines the user did not select.

## Files

| File | Contains | Pure? |
|---|---|---|
| `outline.lua` | level, subtree, shift, move, parent, enclosing_item, projects, move_to_project, changed_span | **yes** — no `vim.api`, no filesystem |
| `done.lua` | the `@done` scanner and toggle; `toggle_range` is the only impure function | mostly |
| `move.lua` | buffer read, smallest-span write, cursor restore, the Telescope picker | no |
| `focus.lua` | the view buffer, its write-back, and the focus/out/home lifecycle | no |
| `../../syntax/taskpaper.vim` | the four item types and the strikethrough | VimL, see below |
| `../../ftplugin/taskpaper.vim` | tab settings, commands, keys, `b:undo_ftplugin` | VimL |

`outline.lua` is pure for the same reason `annotate/anchor.lua` is: the awkward cases (blank lines
between siblings, a nephew that is not a sibling, moving an item into its own subtree) are the part
most likely to be wrong, and they are testable with string literals instead of a buffer.

**The syntax file stays VimL and everything else is Lua.** Settled 2026-09-16 after an adversarial
`codex exec` review. Neovim has no Lua API for `:syn match`, so "syntax in Lua" means wrapping the
same regexes in `vim.cmd` (buys nothing), shipping a Tree-sitter grammar (parser builds become
ours), or highlighting from a decoration provider — which costs the syntax interface: `synID()`,
`synstack()`, `:syntax off`, containment, and ufo's closed-fold text, which is built by capturing
syntax.

## Focus is a projection, not folds

A closed fold always keeps a summary row, so folding cannot hide the rest of the file; fold state
is window-local, so the same buffer in two windows has two of them; and ufo owns the folds here and
re-applies them on every change, so a fold this module created would not survive the next
keystroke. So Focus In builds a scratch buffer holding the subtree's lines.

**The view is editable and writes back**, departing from the plan deliberately. Focus in the app is
a working mode, and a read-only view of one project is useless for what a task file is for. What
makes it affordable is that a focused range is *contiguous*, so write-back is one
`nvim_buf_set_lines` over the source's slice. (Stage 5b's filter cannot borrow this: its visible set
is scattered, so there identity really is the hard part.)

The lifecycle, with the four decisions that are not obvious:

| Step | Behaviour |
|---|---|
| Focus In | narrows to `enclosing_item`; **the unit is the item, not the project** |
| again | narrows further only after the cursor moves onto a child |
| Focus Out | `outline.parent`, so out of a deep list → its parent list → the project → home |
| `:w` in the view | `buftype=acwrite` + `BufWriteCmd`: syncs, then writes the *source's* file |
| `BufLeave` | syncs quietly; an edit only in the view is an edit nowhere |
| source moved | write-back refuses and says so; the view stays on screen with the edit in it |
| Go Home | clean view leaves even when stale; a dirty one needs `:TaskPaperHome!` |

1. **Item, not project.** This asked for the nearest project until 2026-09-17, which made a nested
   list unfocusable: a task's nearest project is the top-level heading however deep the task sits,
   so Focus In from inside a nested list jumped straight back to the root.
2. **A leaf resolves to its parent**, since focusing a leaf would show one line. This is also what
   the section at the top of this file is about.
3. **Leaving is not writing.** Conflating them trapped the view: a source edited from another
   window makes write-back refuse, and refusing to *leave* as well left a buffer whose only exit
   was `:bd!`. Rebuilding the view from the moved source is not on the menu, because `root` is a
   line number and a shifted source is exactly the case where it means nothing.
4. **Identical lines are not written.** Writing them anyway bumps `changedtick` and sets
   `modified`, so focusing and going home without typing would leave the file looking edited.

## Four more mechanisms worth not rediscovering

**`tabstop` must equal `shiftwidth`, and that is what the fold stage rests on.** Stage 4 needed no
code: ufo's indent provider already returns heading-inclusive ranges, because it opens a range at
the preceding *shallower* line when indentation increases. But ufo computes a level as
`ceil(leading_columns / shiftwidth)` after expanding tabs by `tabstop`, while `outline.level` counts
one tab as one level. Set `ts=4 sw=2` in the ftplugin and every fold is drawn at twice its outline
depth **while the entire pure suite stays green**. `tests/taskpaper/fold_spec.lua` is the only thing
holding that up; the divergence was reproduced deliberately before the test was kept.

**`\>` is a keyword boundary and tag names are not keywords.** `-` and `.` are legal in a tag name,
so `@done-later` and `@done.foo` are tags named `done-later` and `done.foo`. A naive `@done\>`
dimmed both, plus `@note(mention @done here)` and the domain in `name@done.com`. `done.lua` is a
scanner rather than a `gsub` because two of those need paren depth, which a Lua pattern cannot
carry. `tag_boundary_spec.lua` runs the same fixtures through `done.lua` **and** through the syntax
file, because they are two spellings of one rule and the bug was that they disagreed.

**Blank lines have no level, on purpose.** Giving one level 0 would end every subtree at the first
blank inside it, and these files are written with blank lines between groups. The consequence is
that callers starting from a blank line resolve upward to a real line first.

**Writes replace the changed span, not the buffer.** Every operation here permutes or re-indents
lines and never adds or removes one, so `outline.changed_span` finds the one span to replace. That
is not only speed: rewriting every line marks every line changed, which moves extmarks and loses
the change marks even where nothing moved. Relatedly, on a move the blank lines that sat *between*
two items stay between them rather than travelling with either, which is the only arrangement that
survives a round trip.

## Tests

127 as of 2026-09-18, all passing:

| Spec | Count | Covers |
|---|---|---|
| `tests/taskpaper/outline_spec.lua` | 39 | the pure core |
| `tests/syntax/taskpaper_spec.lua` | 26 | the syntax group at a column |
| `tests/taskpaper/focus_spec.lua` | 25 | real buffers, the whole exit path |
| `tests/taskpaper/tag_boundary_spec.lua` | 22 | one rule, both spellings |
| `tests/taskpaper/done_spec.lua` | 12 | the `@done` transform |
| `tests/taskpaper/fold_spec.lua` | 3 | the ufo/outline agreement above |

```bash
PLENARY_DIR=~/.local/share/nvim/lazy/plenary.nvim nvim --headless \
  -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/taskpaper { minimal_init = 'tests/minimal_init.lua' }"
```

**The suite is pure-function heavy and that is also its blind spot.** Three bugs here were
invisible to it. The `<bang>0` bug lived entirely in the ftplugin, where no pure test reaches:
`<bang>` expands to a literal `!`, so `<bang>0` on a `:lua` line is the Lua syntax error `!0`,
which reads as valid only because `!0` is vimscript's own logical not — and once fixed, `0` is
*true* in Lua, so the unbanged command forced the discard it exists to prevent. Hence `v:lua` and
`v:true`/`v:false` in `ftplugin/taskpaper.vim:51`. The project-versus-item bug and the
column-0-children case were invisible to **both** layers until a real file was opened, because
every fixture happened to have a project at the depth under test.

Prefer a real-file probe when changing anything that reads indentation.

## Not built

**Stage 5b, the app's toolbar search** (`IMPLEMENTATION_PLAN.md`). Build it read-only: the visible
set is `matches` plus their ancestors, which is not contiguous, so there is no slice to write back.
Store the source `changedtick` and refuse stale actions, or an insertion above a result silently
retargets one.

The app's "To Create Items" list needs no code — typing a dash, a colon, or an `@` is already how
you type them. Continuing `- ` on Enter is left out deliberately: Enter in insert mode belongs to
completion here.
