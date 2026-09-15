# Cheatsheet

A Raycast extension that turns a folder of markdown notes into line-level,
copyable entries. Type a few characters, press Return, and the command you were
looking for is on the clipboard.

Two commands:

- **Search Cheatsheet** — fuzzy-search every indexed line, copy or paste it
- **Add Cheatsheet Entry** — append an entry without searching first

## What gets indexed

Any `.md` file under your notes folder whose YAML frontmatter tags include the
configured tag (`quick-ref` by default):

```markdown
---
tags:
  - quick-ref
---

# Git

## Rewriting history

- `git rebase -i HEAD~3` squash or reword the last three commits
- never rebase a branch someone else has already pulled
```

| Shown as | Comes from |
| --- | --- |
| Topic | the note's `#` heading, else its filename |
| Section | the nearest `##` or deeper above the entry |
| Entry | a list item, or a whole fenced code block |

Headings, prose paragraphs, blank lines and frontmatter are not indexed.

## What Return copies

**A code span only counts when it opens the line.** Then it is the payload, and
the rest of the line becomes the description:

```markdown
- `git rebase -i HEAD~3` squash the last three commits
```

copies `git rebase -i HEAD~3` and shows "squash the last three commits" beneath it.

Anywhere else, a code span is prose, so the whole line is copied:

```markdown
- never use `--force` on a shared branch
```

copies the entire sentence. Taking the first span found anywhere would put
`--force` on the clipboard, inverting the sentence that warned against it, so
the rule is deliberately narrow.

A fenced code block is one entry, never one entry per line, because half of a
line-continued command is worse than none. Blocks are copy-only; edit them in
the note.

The list row's title is the exact string Return copies. Nothing is stripped or
inferred at copy time.

## Keys

| Key | Action |
| --- | --- |
| `Return` | copy the entry (configurable: copy or paste) |
| `Cmd+Return` | the other one |
| `Cmd+Shift+C` | copy without closing the window |
| `Cmd+Shift+P` | show or hide the preview |
| `Cmd+E` | edit the entry |
| `Cmd+N` | new entry, seeded with whatever you typed |
| `Cmd+O` | open the note at the entry's own line |
| `Cmd+R` | rescan |

## Preview

The preview pane shows the exact string `Return` will copy, then the entry in
its note with a gutter marking its line, so you can tell a near-miss from the
line you wanted before pressing anything.

~~~
  Copies
  ```bash
  git reflog
  ```

  In the note · lines 12-16, yours is 14
  ```markdown
  - `git rebase -i HEAD~3` squash or reword the last three
  - `git commit --amend --no-edit` fold staged changes in
  - `git reflog` find a commit a reset left unreachable
  - never rebase a branch someone else has already pulled
  ```
~~~

Only the selected row's note is read, so the cost is one file read per
selection. `Cmd+Shift+P` turns the pane off, which restores the topic and
section accessory on each row.

### Syntax highlighting

Raycast renders detail markdown with highlight.js, so a fenced block gets real
highlighting. The language is resolved in this order:

1. **A fenced block's own info string.** ```` ```bash ```` wins for that entry.
2. **The note's `language:` frontmatter key.** One cheatsheet can be SQL and
   another shell, with no global setting that is wrong for one of them.
3. **The Default Code Language preference**, `bash` unless you change it.

```markdown
---
tags:
  - quick-ref
language: sql
---

- `select count(*) from t` row count
```

Prose entries are never tagged. A line with no leading code span is English, and
colouring an English sentence as SQL renders it as a broken query.

The surrounding-lines block is the note's markdown verbatim in a `markdown`
fence, so its headings, list markers and inline code spans all colour. It
carries no line-number gutter on purpose: a prefix like `> 14 | ` stops each
line parsing as a heading or a list item, and a markdown fence only highlights
if its contents are markdown. The line numbers live in the block's label and in
the metadata instead, where they cost no highlighting.

Blank lines are trimmed from the window's edges but never from inside it, so a
window that starts at a section boundary opens on the heading rather than on
two empty lines.

## Opening the note at the line

`Cmd+O` jumps to the entry's own line rather than the top of the note. It needs
Obsidian's [Advanced URI](https://github.com/Vinzent03/obsidian-advanced-uri)
plugin, since plain `obsidian://open` reaches a file but not a position in it.

The vault is detected, not configured: the extension walks up from the note
looking for a `.obsidian` folder, and the vault's name is that folder's parent.
So pointing the scan at a subfolder of a vault still produces a correct link.
With no vault above the note, `Cmd+O` opens the file with whatever owns `.md`.

`Cmd+K` lists every action with its shortcut.

## Editing safely

An edit re-reads the note and confirms the line still matches what was indexed.
If the note changed in your editor meanwhile, the edit is refused and names the
file and line rather than overwriting the newer text.

## Preferences

| Preference | Default | Meaning |
| --- | --- | --- |
| Notes Folder | — | searched recursively for tagged notes |
| New Note Folder | the Notes Folder | where a brand-new topic's note is created |
| Tag | `quick-ref` | only notes carrying this tag are indexed |
| Return Key | copy | whether Return copies or pastes |

Point Notes Folder at the whole collection, since the tag is what filters. Set
New Note Folder to one tidy subfolder, or a new topic lands at the root of
everything you just pointed at.

Scanning only ever reads, and only notes carrying the tag produce entries.
Writes happen on three explicit actions: appending an entry, creating a note for
a new topic, and replacing one line on edit. There are no network calls.

## Development

```bash
npm install
npm test     # the parse, compose and filesystem layers
npm run dev  # load into Raycast
npm run lint
```

`src/lib` holds the whole contract as pure functions plus a thin filesystem
wrapper, and it is where the tests live. The `.tsx` files are the Raycast shell.
