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
| `Cmd+D` | show a multi-line entry in full before copying |
| `Cmd+E` | edit the entry |
| `Cmd+N` | new entry, seeded with whatever you typed |
| `Cmd+O` | open the source note |
| `Cmd+R` | rescan |

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
