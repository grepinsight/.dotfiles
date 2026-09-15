# The Obsidian door

Design for a fifth capture door, one that works from inside Obsidian itself.
Draft 1 written 2026-09-10. **Draft 2 written 2026-09-11**, after an adversarial `codex exec`
review. Status: **unreviewed draft, not implemented.**

Draft 1 claimed parity with the Python writer's exclusive-create guarantee. It does not have it,
and cannot. §2.3 is the correction, and it is the most important paragraph here.

## 1. The gap

Obsidian is currently a **read** surface for captures, and not even its own door: `cmd+alt+N` is
a *Hammerspoon* hotkey that fires `obsidian://open?...Captures.base` at it. From inside Obsidian
there is no way to capture at all. You either leave for the Hammerspoon prompt or create the file
by hand, which reintroduces the naming step the whole system exists to remove.

`Captures.base` already has a `By door` view grouped on `source`, so the read side needs no new
view. This is a write-only feature.

## 2. Decisions, and what they cost

### 2.1 Mobile is in scope

Chosen deliberately, with the cost named at the time. Mobile Obsidian has no `child_process`, so
the door cannot shell out to `~/bin/capture` the way the other four do. The slug budget in
decomposed bytes, the frontmatter shape, and the collision loop therefore exist **twice**, in
Python and in JavaScript.

This is the same objection the README raises against concatenating the Obsidian URI "in Lua, in
bash, and in a slash command". The answer is §5, and §5 changed in draft 2: a fixed golden-case
file **cannot** establish equivalence between two Unicode implementations, so parity is enforced
by a differential test over generated input.

Evidence mobile is real: six `workspace-mobile*.json` files in `.obsidian/`.

### 2.2 QuickAdd hosts the door; we do not write a plugin

QuickAdd, 2,089,718 downloads, v2.24.2 released 2026-09-02, 776 closed issues. It provides the
modal, the command and hotkey registration, the mobile command-palette entry, and a script
loader. We provide one user script.

**QuickAdd is not currently installed.** It is absent from `community-plugins.json`. Installing
and enabling it is step one, and syncing the script note does not do it: the note is data, the
plugin and its macro configuration are not.

Rejected alternatives:

| Option | Why not |
|---|---|
| **Custom TypeScript plugin** | Costs a manifest, a bundler, and an install path into `.obsidian/plugins` on two platforms, which the vault's `.gitignore` excludes from version control. It would fix §3.4 (it could own its modal) and would **not** fix §2.3 (`vault.create()` is the only primitive either option has). Revisit if §3.4's limits bite. |
| **QuickAdd, configuration only** | The `case:slug` modifier genuinely keeps Hangul (read `src/utils/caseTransform.ts`: tokenizes on `[^\p{L}\p{N}\p{M}]+`), but `src/utils/pathValidation.ts` is 50 lines with **no length or byte cap**, and the format syntax has no truncate or first-N-words modifier. Measured 2026-09-10: after the `YYYY-MM-DD-HHMM-` prefix and `.md`, 236 bytes remain for a filename component, and Korean costs 6 bytes/char without final consonants and 9 with, so the *filesystem* limit is reached between 26 and 39 Korean characters and the write fails outright. Also: no 8-word cap, an emoji-only thought slugs to the empty string, and "create file if it doesn't exist" *appends* on a name collision instead of claiming a suffix. |
| **Templater** | Installed but **not enabled** (absent from `community-plugins.json`; draft 1 said "enabled" and was wrong). Moot anyway: user functions are documented as unavailable on mobile, with open issues #223 and #550 confirming they fail silently there. |
| **Shell-commands plugin** | Perfect fidelity, one writer, zero duplication. Desktop only, so it dies on §2.1. Would be the right answer if mobile were dropped. |

**Accepted risk: QuickAdd is now a runtime dependency of a path whose doctrine is that it must
not fail because something upstream was unreachable.** QuickAdd contacts no server per capture,
so latency is unaffected, but a breaking change to its loader or macro API disables this door
while the Python writer and all four other doors stay healthy. There is no version pin, no
compatibility check, and no fallback. That is a real narrowing of the guarantee, accepted because
the alternative is maintaining a plugin. The mitigation is only that the other four doors are
unaffected, so a QuickAdd regression costs you *this* door, not capture itself.

### 2.3 `vault.create()` is NOT an exclusive create. Draft 1 was wrong.

Draft 1 claimed `app.vault.create()` "is the closest thing the Obsidian API has to the
`O_CREAT|O_EXCL` claim". Verified against `obsidian.asar` on this machine (Obsidian **1.12.7**),
deminified:

```js
async create(path, data, options) {
  const p = normalizePath(path);
  this.checkPath(p);
  if (await this.adapter.exists(p)) throw new Error("File already exists.");   // check
  await this.adapter.write(p, data, options);                                   // then write
  const f = this.getAbstractFileByPath(p);
  return f instanceof TFile ? f : null;
}
```

There is an `await` between the check and the write, and `adapter.write` overwrites
unconditionally. This is **precisely the pattern `capture_core.write()` was written to avoid**:

> Claims the filename with `O_CREAT|O_EXCL` rather than checking `exists()` first: two captures
> in the same minute with the same opening words are a real case (a hotkey pressed twice), and a
> check-then-write would let the second silently overwrite the first.

So the Obsidian door has a **strictly weaker** guarantee than the other four, and no amount of
design fixes it: `create()` is the only creation primitive available, on desktop and on mobile,
to a user script and to a custom plugin alike.

What is actually at risk, and what is not:

- **Two Obsidian captures racing each other**: not a concern in practice. You type into a modal,
  so the "hotkey pressed twice" case that motivated `O_EXCL` does not arise here.
- **An Obsidian capture racing the Python writer** (a Hammerspoon hotkey fired in the same minute
  with the same opening words): real, and it can lose the Python-written thought, because
  Obsidian's `exists()` returns false, Python then creates the file, and Obsidian's `write()`
  overwrites it. Narrow window, non-zero.
- **Two devices capturing offline in the same minute with the same opening eight words**: real
  and *unfixable locally*. Both succeed; sync then resolves a conflict it did not know was one.
  `O_EXCL` gives the Python writer no cross-device protection either, so this is a property of
  the naming scheme, not of this door. The one thing that makes it rare is that the filename
  derives from the first eight words, so a collision needs two near-identical thoughts.

**The collision loop is kept anyway** (`stem.md`, `stem-2.md` ... `stem-99.md`). It still handles
the common non-racing case correctly, and removing it would turn a rare overwrite into a routine
one.

**This weaker guarantee must be stated in `README.md`, not just here.** A future reader comparing
the doors will otherwise assume all five behave alike.

## 3. Architecture

### 3.1 Components

| Component | Role | Ours? |
|---|---|---|
| QuickAdd (install and enable) | modal, hotkey, mobile command-palette entry, script loader | no |
| Three QuickAdd **Macro** choices | bind commands to the script and its members | config |
| `capture.js`, one file, no `require()` | prompt, slug, render, write, confirm | **yes** |
| `00-Capture/` + `Captures.base` | already exist, already handle `source:` | no |

### 3.2 Three commands, one script, via `::` member access

Draft 1 generated two notes with a `run(false)` / `run(true)` factory, on the belief that a
script receives no per-choice arguments. That belief was wrong twice over, and both corrections
are verified in QuickAdd's source:

1. **`::` member access.** `getUserScriptMemberAccess()` splits a command name on `::` and the
   loader drills into the export. QuickAdd's own error string documents the intent: *"If you
   meant to export several functions, use `module.exports = { run }` and select `Script::run`."*
2. **Per-command settings.** `IUserScript` declares `settings: { [key: string]: unknown }`, and
   `MacroChoiceEngine` does `if (!command.settings) command.settings = {}` per command, so two
   macros referencing one script hold independent settings.

Either kills the two-notes design. `::` is chosen because it needs no settings schema.

```js
module.exports = { entry, captureAndOpen, captureSelection, slug, render, stem, strip };
```

| Command | Selects | Behaviour |
|---|---|---|
| **Capture** | (default `entry`) | Prompt, write, stay on the current note. |
| **Capture and open** | `::captureAndOpen` | Prompt, write, then `await` opening it in a new tab. |
| **Capture selection** | `::captureSelection` | **No prompt.** Take `editor.getSelection()`, write, stay put. |

`captureSelection` restores something draft 1 silently dropped: the scope option chosen described
"a capture-selection command mirroring nvim's `:'<,'>Capture`". It also sidesteps §3.4 entirely,
since it never opens a prompt.

The extra exports (`slug`, `render`, `stem`, `strip`) are the pure functions the tests reach.
`hasRunnableObjectMember()` accepts this shape: it returns true as soon as
`typeof value.entry === "function"`, and it ignores only the keys `settings` and `quickadd`.

`OPEN_AFTER_CAPTURE` parity: the plain command does **not** navigate. The door exists so a
thought can be saved without leaving what you are doing, and in Obsidian that is usually a note
you are mid-sentence in.

**No deeplink, no clipboard write on success.** The Hammerspoon door copies the `obsidian://` URI
because it fires from outside Obsidian and the link is the only way back. Here you are already in
the app. The clipboard is still used on *failure*, see §7.

### 3.3 The flow

```
hotkey -> QuickAdd Macro -> capture.js
  text = await params.quickAddApi.inputPrompt("Capture a thought")   (or editor.getSelection())
  if blank -> Notice("Nothing captured"); return                     no file, nothing lost
  create 00-Capture unless it exists                                 see below
  body = render(text, now, "obsidian")
  for candidate in [stem.md, stem-2.md ... stem-99.md]:
      try { file = await app.vault.create(path, body); break }
      catch (already exists) { continue }
      catch (anything else)  { report, RETAIN the text, return }
  committed = true
  try { new Notice("Captured -> " + name) } catch { fallback, see §7 }
  if (open) { try { await leaf.openFile(file) } catch { report navigation failure only } }
```

**The folder is created.** `capture_core.write()` does
`directory.mkdir(parents=True, exist_ok=True)`; draft 1's architecture never created
`00-Capture`, so a first capture into a vault without that folder would fail for an entirely
avoidable reason. `createFolder` throws if the folder exists, so the call is guarded.

### 3.4 Accepted limits of QuickAdd's prompt

Verified in `src/gui/GenericInputPrompt/GenericInputPrompt.ts`. Accepted deliberately rather than
discovered later:

- **The field is single-line.** `protected inputComponent: TextComponent`, an Obsidian
  `TextComponent`, which is an `<input>`. `InputPromptOptions` has **no multiline flag**. So a
  pasted multi-line thought is flattened before `render()` ever sees it, which breaks the "byte
  for byte" contract for that input. **`captureSelection` is the multi-line path**; the typed
  path is single-line by construction.
- **Vault suggesters are attached unconditionally.** `attachSuggesters()` wires a `FileSuggester`
  and a `TagSuggester` to the input element. Typing a double bracket searches your vault files
  and a hash searches tags, and Enter can accept a suggestion instead of submitting the capture.
  This is in tension with the doctrine's "No model, no network, no search" and cannot be turned
  off from a user script.
- A user script **cannot** build its own modal on mobile: Obsidian's `Modal` class comes from the
  `obsidian` module, and `require` is `window.require && window.require(s)`, which is `undefined`
  on mobile. So there is no workaround short of §2.2's custom-plugin option.

## 4. Artifacts

```
~/.dotfiles/capture/
  lib/capture_core.py                unchanged
  obsidian/capture.js                NEW  canonical source, real .js, no require(), no Node API
  obsidian/capture.test.mjs          NEW  unit tests (node --test)
  tools/slug_dump.py                 NEW  reads inputs on stdin, prints slug+stem+body per line
  tools/slug_dump.mjs                NEW  the same, in JS
  tools/gen_inputs.py                NEW  seeded generator for the differential test
  tests/conformance/cases.json       NEW  golden anchors (regression, not proof)
  tests/test_capture_core.py         extended
  Makefile                           extended: configure, test, test-parity, check
  docs/2026-09-10-obsidian-door-design.md
        |
        |  make configure: wrap capture.js in a js fence, add a do-not-edit header
        v
~/Thoughts/99-Obsidian-Scripts/Capture Script.md
```

### 4.1 Why the delivered artifact is a markdown note

Verified in `src/utils/userScript.ts`: the loader tests `MARKDOWN_FILE_EXTENSION_REGEX`
(`/\.md$/i`) and routes a `.md` file through `extractScriptFromMarkdown()`, which runs the
**first** js fence and ignores surrounding prose. The source comment cites issue #1065 and says
the fenced form *"is editable on mobile"* and that *"the `.js` path is byte-identical."*

**Draft 1 over-claimed.** It said mobile Obsidian "cannot load a `.js` file as a script at all".
The documentation says mobile cannot *open* (edit) `.js` files, which is not the same as cannot
*execute*. Whether the `.js` form loads on mobile is **unverified**. The fenced form is chosen
because it is the documented mobile-friendly path and syncs under every mechanism, not because
the alternative is proven impossible.

Sync context, unresolved: there is no `.obsidian/sync.json`, the file Obsidian Sync writes for a
connected remote vault, yet the directory carries `hotkeys 2.json`, `workspace 2` through
`workspace 5`, and `workspace-mobile 2` through `6`, which is the macOS duplicate-name pattern
rather than Obsidian Sync's conflict format. The user reports Obsidian Sync. A markdown note
makes the discrepancy not load-bearing.

`.obsidian/` is also in the vault's `.gitignore` (line 1, `.obsidian/*`), so nothing installed
there is versioned by the vault repo. `99-Obsidian-Scripts/` is outside it and follows the
existing `99-Python-Tools` / `99-Rust-Tools` / `99-Claude-Config` convention. It does not exist
yet; `make configure` creates it. QuickAdd cannot load a script from a dot-prefixed path or from
`.obsidian/`, which is why it is a visible top-level folder.

### 4.2 The generated note is an executable file in a syncing folder

Draft 1 said a fenced script "cannot be linted, type-checked, or run". **That is false**, and the
false claim was doing real work in the argument. The fence can be extracted and executed, and it
now is:

- **`make test` extracts the fence from the generated note and runs the tests against the
  extracted bytes as well as against `capture.js`.** Testing the repository source does not
  authenticate the deployed bytes; testing both does.
- **A line of three backticks inside a JS template literal terminates the fence early.** The
  generator therefore rejects any source line whose first non-whitespace characters are three
  backticks, failing `make configure` rather than emitting a note that loads truncated code.

Remaining accepted risk: this is an **executable file on a sync channel**. A conflict between a
desktop regeneration and a phone-side edit can produce a syntactically valid but untested script,
and a conflict copy containing two js fences will silently execute only the first, which may be
the old behaviour. A do-not-edit header prevents none of this. Mitigations, all cheap:

1. The generated note carries the source's **git SHA and a content hash** in a comment, and
   `make check` compares the deployed note's hash against the source and reports drift.
2. `entry` logs its own version string to the console on first run, so "which script am I
   actually running" is answerable from the phone.
3. Nothing else writes to `99-Obsidian-Scripts/`, keeping the conflict surface to one file.

Note also that Templater's "creation processing" would interpret a literal Templater command
sequence inside this note if Templater were ever enabled and configured for that folder.
Templater is currently not enabled (§2.2). Recorded so the script never contains that sequence.

## 5. Proving the two writers agree

**A fixed golden-case file cannot do this.** Draft 1 assumed it could. Concretely, a port that
uses `toLowerCase()` plus a sharp-s special case passes every enumerated case and still diverges:

| Input | Python `casefold()` | JS `toLowerCase()` |
|---|---|---|
| the U+FB01 ligature (fi as one glyph) | two ASCII letters, `fi` | the ligature, unchanged |
| capital omicron followed by capital sigma | medial sigma | **final** sigma |

Both reproduced during review. Fixtures structurally miss unenumerated case mappings, contextual
casing, and Unicode-version drift. They also miss **UTF-16 counting**: Python's `word[:60]` and
`len(candidate)` count code points, while JS `.slice()` and `.length` count UTF-16 units, so 31
astral-plane characters fit Python's limit and can be cut to 30 by a naive JS port.

So parity is enforced two ways.

### 5.1 Golden anchors, `tests/conformance/cases.json`

Regression anchors, not proof. Each row is `{text, slug, body}`; the file carries a shared clock
as **explicit local components plus an offset**
(`{year, month, day, hour, minute, second, offsetMinutes}`), never an ISO string. Draft 1 planned
to inject an ISO string, which does not work: `new Date("2026-09-10T12:34:56-07:00")` is an
*instant*, and reading local components off it on a Seoul machine yields September 11, 04:34. The
offset must be data the renderer consumes, not something recovered from `getTimezoneOffset()`.

`stem` is **not** stored; it is derived from the clock plus `slug`, so the two cannot disagree.

Seeded rows:

| Case | What it pins |
|---|---|
| 21 Hangul syllables with final consonants | 189 NFD bytes, over `MAX_SLUG_BYTES` (180), so Python retains 20. **Draft 1's Korean row was wrong**: it cited a 203-byte candidate as fitting "the 236-byte budget", conflating the filesystem's per-component limit with the writer's own 180-byte slug cap. 236 is irrelevant to parity. |
| 20 of the same | 180 bytes exactly, the last that fits |
| emoji only | Python returns `note`; a naive port returns the empty string and the filename ends in a hyphen |
| one word over budget | the mid-word hard cut, `_clip()` |
| twelve words | the 8-word drop |
| `myNewIdea`, `blog2post` | QuickAdd's own tokenizer splits camelCase and letter/digit boundaries; `capture_core._words()` does not. The port follows Python. |
| the ligature and sigma cases above, plus sharp-s | the case-folding divergences |
| 31 Deseret characters | UTF-16 versus code-point slicing |
| a lone U+0085, and text wrapped in U+FEFF | the strip divergence, §6.2 |
| combining marks | `_keeps()` keeps categories `L` and `N` only, so an `Mn` mark is a separator. QuickAdd keeps `M`. The port follows Python. |
| `CON`, `NUL` | Windows device names, which QuickAdd guards and Python does not. Harmless on macOS, cheap to keep. |

### 5.2 The differential test, `make test-parity`

The actual guarantee. `tools/gen_inputs.py` emits N inputs from a **fixed seed**, so a failure
reproduces exactly, drawing from: Hangul with and without final consonants, Kanji, Latin with
diacritics, Greek including final-sigma positions, Turkish dotted and dotless i, ligatures,
astral-plane scripts, emoji, combining marks, U+FEFF and U+0085 and other Unicode whitespace,
words at and around each budget boundary, and pure punctuation.

Both `tools/slug_dump.py` and `tools/slug_dump.mjs` read those inputs on stdin and print one
record per line. The target diffs the two outputs byte for byte and fails on any difference. This
catches the classes §5.1 structurally cannot.

## 6. Behaviour the port must reproduce exactly

From `capture_core.py`, restated so the JS can be checked against prose as well as tests. Any
detail restated wrongly here becomes a bug an implementer faithfully reproduces, which is why
§5.2 exists as the real check.

### 6.1 slug

NFC-normalize, **casefold** (not lowercase, see §5), split on runs of characters whose Unicode
general category does not begin with `L` or `N`, take the first **8** words, join with `-`. While
the candidate exceeds **60 code points** or **180 NFD bytes**, drop the last word. If one word
remains and is still over, hard-cut it by code points then by bytes. Empty result becomes `note`.

**"Characters" means code points throughout.** The JS port iterates the spread of the string,
never `.length` or `.slice()`.

### 6.2 render, and what "stripped" means

```
---
created_at: "<local ISO8601, seconds precision, with UTC offset>"
tags:
  - capture
source: obsidian
---

<text, stripped, verbatim>
```

ending in a single newline.

**"Stripped" needs an explicit character set, because the two languages disagree.** Python's
`str.strip()` removes U+0085 (NEL); JavaScript's `trim()` does not. JavaScript's `trim()` removes
U+FEFF; Python's does not. So a lone U+0085 is an empty capture to Python and a non-empty one to
JS, and text wrapped in U+FEFF loses bytes under JS but not Python. The port implements an
explicit list matching Python's `str.isspace()` set and does **not** call `trim()`. Both cases
are in §5.1.

### 6.3 stem and collision

`stem = strftime("%Y-%m-%d-%H%M") + "-" + slug`. Candidates `stem.md`, then `stem-2.md` through
`stem-99.md`. Beyond that, report and do not write. See §2.3 for what this does and does not
guarantee.

### 6.4 The body is never reworded

Byte for byte, including typos, lowercase, and mixed Korean and English. This is the point of the
system. The single-line prompt in §3.4 is the one accepted exception, and it is a limitation of
the input surface, not a transformation of the text.

## 7. Failure behaviour

The README's rule applies unchanged: *"a confirmation that cannot fail loudly will lie."* Draft 1
did not satisfy it. Four states, tracked separately:

| State | Behaviour |
|---|---|
| **Nothing typed** | `Notice("Nothing captured")`. No file. |
| **Not committed** (folder creation failed, disk full, all 99 candidates taken) | Report the real error, **and retain the text.** Draft 1 lost it: the modal has closed, and "failed loudly" does not recover what you typed. Re-open the prompt pre-filled via `inputPrompt(header, placeholder, text)`, whose third parameter is the initial value, and additionally place the text on the clipboard. QuickAdd's own `InputPromptDraftHandler` is worth investigating as a better mechanism. |
| **Committed, confirmation failed** | The write succeeded and the `Notice` did not. Silence here makes the user retry and create a `-2`. So `committed` is tracked as a variable, the `Notice` call is wrapped, and the fallback is a *different* mechanism (`console.error` plus the clipboard), never a second identical `Notice`. |
| **Committed, navigation failed** | `openFile()` is `await`ed, and a rejection is reported as a *navigation* failure. Draft 1 did not await it, so "Capture and open" could confirm the capture while the navigation rejected unreported. |

The success `Notice` names the **filename**, so it is falsifiable at a glance.

## 8. Prerequisite: the vault currently corrupts captures

**Not a risk. Reproduced 2026-09-10 on the five existing captures.** Independent of this door,
and it must be fixed before "Capture and open" ships, because that command walks straight into
it.

Three of the five captures carry an injected heading, an H1 holding the filename, sitting between
the frontmatter and the thought.

Consequence, reproduced with `captures`:

```
2026-09-08 12:18  # 2026-09-08-1218-testy3 [...]     <- the filename, not the thought
2026-09-08 10:01  Testy                              <- an unopened capture, correct
```

`captures` and `:Captures` both display `first_line` from the body, so the thought is replaced by
the filename and hidden behind the multiline marker.

Causes, verified in plugin settings:

| Plugin | Setting | Effect |
|---|---|---|
| `obsidian-filename-heading-sync` | `useFileOpenHook: true`, `useFileSaveHook: true`, `ignoreRegex` does not match `00-Capture` | inserts the filename as an H1 when a headingless capture is opened. **This is the damage already done.** |
| `obsidian-linter` | `file-name-heading` enabled, `lintOnSave: true` | the same insertion, on save |
| `obsidian-linter` | `yaml-timestamp` enabled, `date-created-key: created_at`, `date-created-source-of-truth: "file system"` | **would overwrite `created_at`**, destroying the seconds and offset that `list_captures()` sorts on. Has not fired yet, because the damaged files were opened but never saved in Obsidian. A loaded gun. |
| `obsidian-linter` | `yaml-title`, `yaml-title-alias`, `insert-yaml-attributes` enabled | would add `title:` and `aliases:` keys to captures |

Fix:

1. Add `00-Capture` to Heading Sync's `ignoreRegex`.
2. Add `00-Capture` to the Linter's `foldersToIgnore` (currently
   `['99-Claude-Config', '', '04-Extras/obsidian_templates']`).
3. Repair the three damaged files by removing the injected H1.
4. Verify: open a capture, save it, and confirm `captures` still shows the thought and
   `created_at` still carries seconds and offset.

**Obsidian holds plugin settings in memory and rewrites `data.json` on change,** so steps 1 and 2
are done either through the Obsidian UI or with Obsidian quit. Editing `data.json` behind a
running Obsidian will be silently reverted.

## 9. Known limitations, accepted and recorded

- **§2.3**, the weaker create guarantee.
- **§3.4**, the single-line prompt and the vault suggesters on the capture path.
- **§2.2**, QuickAdd as a runtime dependency with no version pin or fallback.
- **§4.2**, an executable file on a sync channel.
- **Cross-timezone reader ordering, pre-existing and made reachable by this door.**
  `list_captures()` sorts `created_at` as a **string**, so `2026-09-10T10:00:00+09:00` sorts above
  `2026-09-10T02:00:00+00:00` although it is the older instant. Worse, the `limit` is applied to a
  filename sort *before* the timestamp re-sort, so parsing offsets afterwards cannot recover a
  record the filename pass already excluded. Harmless while every door runs on one machine in one
  zone. A phone in another zone makes it reachable. Out of scope here, but it is now a real bug in
  `capture_core.list_captures` and should get its own change.

## 10. What this deliberately does not do

- **No routing.** A capture is not filed into a topic note. That is `/note-that`, which is allowed
  to be slow and to think.
- **No new read view.** `Captures.base` and its `By door` view already cover it.
- **No AI, no network, no search** on the capture path, with §3.4's suggesters as an accepted and
  unavoidable violation.
- **No rewording.** See §6.4.

## 11. To verify during implementation

Resolved in draft 2, listed so they are not re-litigated:

- `{entry, ...}` export shape is accepted. `hasRunnableObjectMember()` returns true on
  `typeof value.entry === "function"`. **Verified.**
- `::` member access works. `getUserScriptMemberAccess()` splits on `::` and the loader drills.
  **Verified.**
- A `.md`-hosted script is a first-class loader path. `MARKDOWN_FILE_EXTENSION_REGEX` is
  `/\.md$/i` and routes to `extractScriptFromMarkdown()`. **Verified.**
- `inputPrompt(header, placeholder?, value?, options?)`. **Verified**, including that the third
  parameter pre-fills, which §7 depends on.

Still open:

1. **Does a markdown-hosted script actually run on mobile end to end?** The loader path exists for
   that purpose, but it has not been exercised on the phone. This is the whole delivery mechanism,
   so it is verified first, with a script that does nothing but show a `Notice`.
2. **`TextEncoder` on mobile.** A web standard, expected present in the mobile webview, but the
   byte budget depends on it.
3. **QuickAdd hotkey binding.** A choice reaches Obsidian's hotkey settings only when added to the
   command palette. Confirm and record the setting.
4. **`InputPromptDraftHandler`** as the retention mechanism for §7's not-committed state, in
   preference to re-prompting.
5. **How the vault actually reaches mobile**, per §4.1. Not blocking, but it decides whether
   `make configure` on the desktop is sufficient or whether a pull step is needed.

## 12. Documentation changes

`README.md`:

- "the four doors" becomes five, plus Claude Code.
- A new note that **this door's collision handling is weaker than the other four** (§2.3), because
  a reader comparing them will otherwise assume parity.
- The §8 plugin-interference finding, because it affects every door that opens a capture,
  including `:Capture!` and the Hammerspoon jump hotkey.

## 13. Review record

Adversarially reviewed by `codex exec` (codex-cli 0.153.4) on 2026-09-10 against draft 1 plus
`capture_core.py`, `bin/capture`, `bin/captures`, `Makefile`, and `README.md`. It returned 15
findings; 14 were accepted. Five were verified against source before acceptance:
`vault.create()`'s check-then-write (§2.3), the plugin interference (§8), the prompt's single-line
input and suggesters (§3.4), per-command settings (§3.2), and Templater not being enabled (§2.2).
Three were plain errors in draft 1: the Korean budget (§5.1), "cannot be tested" (§4.2), and
ISO-string clock injection (§5.1).

The one finding rejected: it reported Obsidian 1.14.1; this machine runs 1.12.7. The
`vault.create()` conclusion holds regardless, having been read from the installed 1.12.7 bundle.

Found independently of the review, and recorded because it is the kind of thing a review is
supposed to catch: `::` member access (§3.2), and the scope drift where draft 1 dropped the
capture-selection command (§3.2).
