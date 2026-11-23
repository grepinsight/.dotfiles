# capture

One thought, one file, no model in the path.

```bash
capture "the friction is naming it, not typing it"
# → /Users/you/Thoughts/00-Capture/2026-09-08-0914-the-friction-is-naming-it.md
```

## Why it is built this way

The goal is the least possible friction between having a thought and having it
saved. That rules out things that look like features:

- **No model, no network, no search.** A capture cannot be slow and cannot fail
  because something upstream was unreachable. Routing a thought to the right
  topic note is a real and useful job, and it belongs to `/note-that`, which is
  allowed to take three seconds and think. This path is not.
- **It refuses rather than guesses.** With `$OBSIDIAN_VAULT` unset it exits
  non-zero instead of defaulting to `~/Thoughts`. A wrong-vault write is a
  thought saved where you will never look for it, which is worse than an error
  you can read.
- **It never rewords your text.** The body is what you typed, byte for byte.

## Layout

| Path | Role |
|---|---|
| `bin/capture` | Write CLI. Argument parsing, vault resolution, output format. |
| `bin/captures` | Read CLI. Separate entry point so no listing code sits on the write path. |
| `lib/capture_core.py` | The logic worth testing: slug, frontmatter, collisions. Pure or clock-injected. |
| `tests/` | `make test` — stdlib `unittest`, no dependencies to install. |

`make configure` links both entry points into `~/bin`, which is already on PATH.

## The CLI

```
capture [--source NAME] [--vault DIR] [--dry-run] [--json] [TEXT ...]
```

Reads stdin when given no text and stdin is a pipe. Prints the path it wrote to
stdout **and nothing else** -- the Neovim door reads that line as a filename and
the Raycast door strips it to a basename, so the URI must not be appended there.
`--json` emits `{path, slug, created_at, source, written, deeplink, first_line}`
for callers that want the parts.

## Writing: the four doors

All of them end up here, and each records itself in the file's `source:` field,
which is how you find out later which door you actually use.

| Door | Trigger | Notes |
|---|---|---|
| Shell | `capture "..."` | Also pipes: `pbpaste \| capture` |
| Hammerspoon | `cmd+shift+alt+N` | Type, Enter. Alert confirms, deeplink lands on the clipboard, and a clickable notification opens the note. |
| Hammerspoon | `cmd+ctrl+alt+N` | Same, then jumps straight to the note in Obsidian. |
| Raycast | the "Capture" command | `raycast/capture.sh` |
| Neovim | `:Capture`, `<leader>nc` | `nvim/.config/nvim/lua/util/capture.lua`; `:Capture!` opens the file, `:'<,'>Capture` takes the selection |
| Claude Code | `/capture` | `~/.claude/commands/capture.md` (not tracked here) |

Hammerspoon and Raycast invoke through `zsh -c`. Both are launched by launchd
and never source the dotfiles, so `$OBSIDIAN_VAULT` is absent from their own
environments; borrowing a shell's environment keeps one definition of the vault
path instead of hardcoding it, which is what the older raycast scripts do.

**That only works because the vault exports now live in a file `~/.zshenv`
sources.** They used to live in `bash_settings_local`, which only `zshrc_init`
reads, and `zshrc_init` only runs for an *interactive* zsh. Measured with the
variable stripped from the environment:

| Shell | `$OBSIDIAN_VAULT` | Extra output | Cost |
|---|---|---|---|
| `zsh -c` (before the move) | missing | 0 lines | ~27ms |
| `zsh -l -c` | missing | 0 lines | ~46ms |
| `zsh -i -c` | resolved | **13 lines** | **~990ms** |
| `zsh -c` (after the move) | **resolved** | 0 lines | **~27ms** |

So the interactive mode was the only one that worked, and it cost ~990ms per
capture while printing 13 lines of shell chatter (`zle` warnings, `... loaded`
notices) ahead of the output -- which broke the JSON parse and silently dropped
the deeplink. Moving the exports fixed the latency and the chatter at once. Full
capture round trip is now ~131ms.

## Deeplinks

`capture --json` and `captures --json` both return a `deeplink`:

```
obsidian://open?vault=Thoughts&file=00-Capture%2F2026-09-08-0914-a.md
```

Built by `capture_core.deeplink()`, which is pure and unit-tested, so the URI
has one definition rather than being concatenated in Lua, in bash, and in a
slash command. Percent-encoding uses `safe=""`, which matters twice: an
unencoded `/` in the `file` parameter is read as part of the query string, and
`&` or `=` in a filename would truncate it.

The `vault` name defaults to the basename of the vault root. That is how
Obsidian names a vault unless it was renamed independently of its folder, hence
the `vault_name` override on the function.

**Verified, not assumed.** Firing a generated URI left Obsidian with that file
as the active tab in `.obsidian/workspace.json`. Same check confirmed the
`.base` URI opens with view type `bases`.

### Why the alert does not show the link

`hs.alert` is an overlay Hammerspoon draws itself. It always appears, even with
notifications muted, and it **cannot be clicked** -- a URI printed there is
something you would have to retype. So the alert stays a short confirmation, and
the link goes two places that work: the clipboard (`cmd+V` anywhere) and a
notification whose click opens the note.

### Why capturing does not open Obsidian by default

`OPEN_AFTER_CAPTURE` at the top of `capture.lua` is `false`. The hotkey exists
so a thought can be saved *without leaving what you are doing*; switching apps
on every capture is the interruption it was built to avoid. `cmd+ctrl+alt+N`
asks for the jump explicitly. Flip the constant if you want it always.

## Reading: three doors

A one-line capture's **filename is already the thought**, so reviewing captures
is a list problem, not an open-a-file problem. Nothing has to read file bodies
to render a useful list.

| Door | Trigger | Notes |
|---|---|---|
| Shell | `captures` | Last 20 as `DATE TIME  thought`. `-n 100`, `--paths`, `--json`. |
| Neovim | `:Captures`, `\nC` | Telescope, newest first, file preview. Type to fuzzy-filter the thought **or its door**. `:Captures 50` to bound it. |
| Obsidian | `cmd+alt+N` | Opens `00-Capture/Captures.base`: a table with `created_at` and `source` columns, sorted newest first. |

`obsidian://open?vault=Thoughts&file=00-Capture%2FCaptures.base` is the URI. That
it resolves a `.base` file was verified, not assumed: after firing it, Obsidian's
`.obsidian/workspace.json` showed `Captures.base` as the active tab with view
type `bases`.

**What the Base cannot show: the thought's full text.** Bases reads frontmatter,
not the body, so the table shows the filename (the first ~8 words) rather than
the whole line. Putting a copy of the text into frontmatter would fix the display
and create two copies that diverge the moment you edit one, so it is not done.
`captures` and `:Captures` both show the real first line.

**The Base is an inbox view, filtered on `file.folder == "00-Capture"`,** not on
the `capture` tag. So a thought filed into `03-Resources/` drops off the list,
which is the point: what remains is what is unhandled.

## Ordering

Filenames carry minute precision, so a burst of thoughts inside one minute would
sort alphabetically. `list_captures` re-sorts the records it selected on the
`created_at` seconds that frontmatter carries, with the filename as tiebreaker.
Sorting by mtime was rejected: it reports when a capture was last *edited*, so
fixing a typo in an old thought would promote it above a new one.

## Traps

**A door tested with the variable already exported is not tested.** Both GUI
doors were once reported as verified when the test had inherited
`$OBSIDIAN_VAULT` from the calling shell. The Raycast door was in fact broken --
`zsh -lc` has no vault -- and would have failed under Raycast with "nowhere safe
to write". Test a launchd-started door with `env -u OBSIDIAN_VAULT -u
OBSIDIAN_VAULT_PATH` in front of it, or the test proves nothing.

**A confirmation that cannot fail loudly will lie.** The first version of the
deeplink code fell back to "no link" when the JSON would not parse, and still
showed `Captured`. The clipboard write and the notification were both skipped
with nothing to indicate it. It now says `Captured, but could not read the link`
and shows the tail of the output. The thought is on disk either way; the point is
that the message must not claim more than happened.

**Slug budget is in decomposed bytes, not characters.** APFS compares filenames
in NFD, and a Hangul syllable that is 3 UTF-8 bytes composed becomes three jamo
at 3 bytes each. Sixty Korean characters is ~540 bytes on disk, past the
255-byte limit for one path component, so a character-only cap would fail
`ENAMETOOLONG` on exactly the notes typed fastest. Hence `MAX_SLUG_BYTES`
alongside `MAX_SLUG_CHARS`.

**The filename is claimed with `O_CREAT|O_EXCL`.** Two captures in the same
minute opening with the same words is a real case — a hotkey pressed twice — and
a check-then-write would let the second silently overwrite the first. The suffix
(`-2`, `-3`) is assigned by whoever loses the race.

**`--dry-run` is advisory.** It reports where a write would go without creating
anything, including the capture directory. It is not what `write()` consults.
