# TaskPaper support in Neovim

Rebuilding the TaskPaper app's feature list as a filetype, one stage at a time. The
source of truth is the app's own Welcome list plus its menus, which between them name
four item types and four groups of behaviour: create, organize, move, and
fold/focus/filter.

No maintained plugin exists to start from. `davidoc/taskpaper.vim` was last pushed
2015-10-03, its only real fork is archived, and Neovim 0.12 does not detect
`.taskpaper` at all. So this is written here rather than vendored.

## Language split

Settled 2026-09-16 after an adversarial `codex exec` review: **the syntax file stays
VimL, everything else is Lua.** Neovim has no Lua API for `:syn match`, so "syntax in
Lua" means one of wrapping the same regexes in `vim.cmd` (buys nothing), shipping a
Tree-sitter grammar (parser builds and distribution become ours), or highlighting from
a decoration provider. The last one is the real alternative and it costs the syntax
interface: `synID()`, `synstack()`, `:syntax off`, and containment do not come with it,
and ufo builds its closed-fold text by capturing syntax and stored highlights, so
ephemeral decorations would not appear in a fold summary. None of that is worth paying
at this file size. Everything structural is Lua, pure where it can be.

## Stage 1: Auto-format the four item types
**Goal**: `syntax/taskpaper.vim` renders projects, tasks, notes, and tags distinctly,
and strikes a done task through.
**Success Criteria**: bold project headings, grey tags, grey task markers, italic
notes, struck-through `@done` lines with the `@done` tag itself left plain. A quoted
`'@'` in prose and an email address are left alone.
**Tests**: `tests/syntax/taskpaper_spec.lua`, asserting the syntax group at a column.
**Status**: Complete

Done was a uniform grey until 2026-09-16, described in the file as "the closest
terminal equivalent of the app's strikethrough". It is now the strikethrough itself,
`term`/`cterm`/`gui=strikethrough`, which needs a terminal that honours SGR 9 (kitty
does). The grey went with it, because the app strikes the item and leaves its color
alone. The one structural consequence is that `taskpaperDone` gained
`contains=taskpaperTag`, so the `@done(...)` tag stays a grey unstruck tag, and so
`synID()` inside the tag now answers `taskpaperTag`: a test asking "is this line
struck" has to read `synstack()` instead.

The first draft of that struck the whole line including the indent, which on a
tab-indented list draws a rule out to the left margin on every done task and chains the
strikes into one figure. `taskpaperDonePad` carves the non-text whitespace back out by
the same containment trick: the indent, a trailing run, and **the gap in front of a
tag**. The third is the one that matters and the one that is easy to miss, since without
it the strike runs from the last word into the tag it stops at and the tags themselves
read as crossed out. The lookahead is what keeps a gap between two words carrying the
line. Carving rather than moving the match's start is deliberate: it keeps "every
line-level group starts at column 1" true, so the precedence reasoning at the top of the
syntax file still holds.

The `@done` boundary was wrong in the first draft and is worth not rediscovering: `\>`
uses *keyword* boundaries, and `-` and `.` are not keyword characters but are legal in
a tag name, so `@done-later` and `@done.foo` both dimmed a live task. A `@done` inside
another tag's value (`@note(mention @done here)`) dimmed one too. Both are now tests.

## Stage 2: Organize items
**Goal**: the app's "To Organize Items" list. Marking done is a toggle rather than a
click on the dash.
**Success Criteria**: `<localleader>d` adds `@done(YYYY-MM-DD)` and removes it again;
`:TaskPaperToggleDone` takes a range; tab-indented output round-trips to the app.
**Tests**: `tests/taskpaper/done_spec.lua`, plus
`tests/taskpaper/tag_boundary_spec.lua`, which runs one fixture table through both the
syntax file and the Lua scanner because they are two spellings of one rule.
**Status**: Complete

## Stage 3: The Move menu
**Goal**: Move Right, Left, Up, Down, and Move to Project, each carrying the item's
descendants.
**Success Criteria**: a move round-trips exactly; a move with no sibling that way is a
silent no-op rather than a reparenting; blank lines between siblings stay where they
are; Move to Project opens a fuzzy picker and never offers a destination inside the
item's own subtree.
**Tests**: `tests/taskpaper/outline_spec.lua` over the pure functions.
**Status**: Complete

**Keys are the adaptation, not the app's.** The app uses Ctrl-Cmd-Arrow and Cmd-\, and
a terminal cannot deliver Cmd at all. So `<localleader>` plus a direction is the
binding that always works, with `<M-hjkl>` alongside for terminals that send Alt.

**Move to Project is a telescope picker**, built the way `lua/util/capture.lua` builds
its own, `pcall` included, so a missing telescope degrades to `vim.ui.select` rather
than failing. Two details that are easy to get wrong: telescope's default select action
opens a file, so it has to be replaced via `attach_mappings` or Enter silently does
nothing, and the entry's `ordinal` has to be the trimmed line, because leaving the
display indent in it makes every nested project match a query of spaces. The sorter is
telescope's own `generic_sorter`; `fzy_native` is configured here with
`override_generic_sorter = false`, so it only overrides the file sorter.

Impossible destinations are filtered in the pure layer (`outline.move_targets`) rather
than rejected after a choice, so the picker never offers something the move refuses.

## Stage 4: Fold an item, heading included
**Goal**: `zc` on a project line folds the project, not just its children.
**Success Criteria**: the app's eight Expand/Collapse menu items all work.
**Tests**: `tests/taskpaper/fold_spec.lua`.
**Status**: Complete, with no code.

**The cheap check paid off.** Measured 2026-09-17 by driving nvim-ufo headlessly over a
tab-indented fixture: its indent provider already returns heading-inclusive ranges,
because it opens a range at the preceding *shallower* line when indentation increases.
On a file whose projects are `Project A:` at level 0 with tasks under it, the ranges came
back as `1..4` and `6..8`, heading included and the blank line between them excluded, and
`zc` on line 1 closed `1..4`. So every item in that half of the menu is a native fold key
and none of them needed binding:

| App | Key | App | Key |
|---|---|---|---|
| Expand Items | `zo` | Collapse Items | `zc` |
| Expand Items Completely | `zO` | Collapse Items Completely | `zC` |
| Expand All By Level | `zr` | Collapse All By Level | `zm` |
| Expand All Completely | `zR` | Collapse All Completely | `zM` |

`zr`/`zR`/`zm`/`zM` are already remapped to ufo's own versions in `lua/config/ufo.lua`,
which is required with any ufo provider and is not taskpaper-specific.

**A stage with no code has nothing holding it up,** which is what `fold_spec.lua` is for.
ufo computes a level as `ceil(leading_columns / shiftwidth)` after expanding tabs by
`tabstop`, and `taskpaper.outline` counts one tab as one level. The two agree only while
**`tabstop` equals `shiftwidth`**. Set `ts=4 sw=2` in the ftplugin and every fold in the
file is drawn at twice its outline depth while the entire pure suite stays green; that
divergence was reproduced deliberately before the test was kept, and it is the only thing
this stage rests on.

Two measurement traps, both probe artifacts rather than bugs, worth not rediscovering:
ufo's `enableFold()` restores the *previous* closed state, so probing several fold keys in
one session reports the leftovers of the last one, and ufo re-applies folds
asynchronously, so a `vim.wait` after a keypress can watch it reopen what `zc` just
closed. One key per process, and read `foldclosed()` immediately.

## Stage 5a: Focus
**Goal**: the app's Focus In, Focus Out, and Go Home.
**Success Criteria**: Focus In shows the subtree of the item the cursor is in and nothing
else, at any depth; Focus Out widens one item and goes home when there is none; an edit
made while focused lands back on the source lines it came from, with the rest of the file
pushed down or pulled up to fit.
**Tests**: `tests/taskpaper/focus_spec.lua` over real buffers, plus `enclosing_item` and
`parent` in `tests/taskpaper/outline_spec.lua`.
**Status**: Complete

**Keys**: `<localleader>f`, `<localleader>F`, `<localleader>H`. The app uses Opt-Cmd-Arrow
and Shift-Cmd-H and a terminal delivers none of it. `f`/`F` is Vim's own shape for a
motion and its opposite; `H` keeps the app's letter for Home.

**The unit is the item, not the project,** and getting that wrong shipped a bug the same
day. The first draft focused the nearest *project*, which reads fine until you try it on a
nested list: a task's nearest project is the top-level heading however deep the task sits,
so Focus In from anywhere inside `- outer list > - middle list > - deep one` jumped
straight back to the root, and pressing it again did nothing. Reported from a real file on
2026-09-17.

The rule now: a line **with children is its own answer**, since that is the container the
cursor is standing on, and a **leaf resolves to its parent**, since focusing a leaf would
show one line. Focus Out is `outline.parent`, so the two form a ladder out of a deep list
to its parent list, to the project, to home -- every rung but the last being a task, which
is exactly what a project-based Focus Out could not express either. Going deeper means
moving the cursor onto the child and pressing again, the same as selecting the item in the
app.

Worth noting where the answer already was: this plan's own Stage 5b text says "an ancestor
can be a task or a note, not only a project". Focus narrowed it by mistake, and the pure
tests all passed because every fixture they used had a project at the depth being tested.
`deep_fixture()` in both specs is nested *tasks* under a single project for that reason.

**The view is editable, which departs from the read-only projection this plan specified.**
Focus in the app is a working mode, and a read-only view of one project is useless for the
thing a task file is for. What makes it affordable is that a focused range is
*contiguous*, so write-back is one `nvim_buf_set_lines` over the source's slice. The
warning below that "identity is the hard part" was about the search filter, where the
visible set is scattered and a line number really is the only handle; it does not apply to
a subtree. Everything else in that warning still holds and is implemented: the source
`changedtick` is stored, and a view whose source moved underneath it refuses to write
back rather than overwriting whatever now sits at those line numbers.

It keeps `filetype=taskpaper` rather than taking its own, also against the original plan,
and for the same reason: the Move and Toggle Done commands should work inside a focused
project, and folding should too. ufo attaching to the view was checked end to end and is
fine.

**Refusing to write back is right; refusing to *leave* was a trap.** The first draft had
Go Home decline on a stale view, which left a buffer whose only exit was `:bd!`. Now a
view with nothing unwritten in it goes home even when stale, since it has nothing to
lose, and one holding an edit needs `:TaskPaperHome!` -- the bargain `:q` already makes.
Rebuilding the view from the moved source is deliberately not offered: `root` is a line
number, and a source that shifted is exactly the case where it no longer means anything.

**`<bang>0` does not survive the trip into Lua,** and this cost a real bug that every unit
test missed because they call `focus.home(true)` directly. `<bang>` expands to a literal
`!`, so `<bang>0` on a `:lua` line is the Lua syntax error `!0`; it reads as valid only
because `!0` is *vimscript's* logical not. The quieter trap is the one behind it: once
fixed, `<bang>0` is 0 or 1, and **Lua counts 0 as true**, so the unbanged command would
have forced the discard it exists to prevent. The command now goes through
`v:lua` with `<bang>0 ? v:true : v:false`, and a test drives the command rather than the
function.

## Stage 5b: Filter
**Goal**: the app's toolbar search: the items matching a query, with their ancestors for
context.
**Status**: Not Started

**Build it as a read-only scratch projection**, not as folds and not as conceal. Folds
cannot hide an isolated non-matching line at all, since every closed fold keeps a summary
row, and fold state is window-local so one buffer in two windows breaks a single saved
state. Conceal can hide whole lines on 0.12, but searches, operators, and undo still act
on the source text underneath.

The projection's hard part is identity, not display: a mapping that stores only source
line numbers silently retargets an action after an insertion above a result. Store the
source `changedtick`, rebuild when it changes, and refuse stale actions. Visible set is
`matches` plus `ancestors of matches`, where an ancestor can be a task or a note, not only
a project. Unlike focus above, read-only is the right call here, because the visible set
is not contiguous and there is no slice to write back.

## Not in scope

The app's "To Create Items" list needs no code: typing a dash, a colon, or an `@` is
already how you type them. Continuing `- ` onto the next line on Enter is the one piece
of automation that section implies, and it is deliberately left out, because Enter in
insert mode belongs to completion here.

## Testing note

The suite is pure-function heavy by design, and that is also its blind spot. The review
named the integration failures a green pure suite will miss: adjacent folds, deleting
the last child of a project, syntax precedence, the same buffer in two windows, and a
stale action fired from a filtered view.

Stage 5a is the first part with no pure core to test, and `focus_spec.lua` runs against
real buffers because of it. That was the right call twice over: the `<bang>0` bug above
lived entirely in the ftplugin, where no pure test can reach, and the double warning on a
forced Go Home only showed up when the whole exit path ran. The project-versus-item bug,
by contrast, was invisible to *both* layers until a real file was tried, because every
fixture in the suite happened to have a project at the depth under test. 660 tests as of
2026-09-17.
