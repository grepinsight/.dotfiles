# AlbertLintLevel1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `:AlbertLintLevel1`, a grammar-and-usage-only LLM review pass whose findings are rendered as a native two-window Neovim diff with per-hunk accept and reject.

**Architecture:** The model returns *labeled spans* (`quote` + `replacement`), never a rewritten paragraph, which makes out-of-level edits unrepresentable rather than merely forbidden. A pure module applies those spans to a copy of the buffer; a thin `vim.*` caller opens that copy in a split and turns on native diff mode, so `do` and `dp` are the accept and reject. Labels and notes ride as `virt_lines` extmarks mirrored on both sides, because a one-sided virtual line desyncs diff alignment.

**Tech Stack:** Lua 5.1 (LuaJIT), Neovim 0.12.4, plenary.busted for tests, `vim.system` for subprocesses, `claude` CLI and `curl` as the two providers.

**Spec:** `docs/superpowers/specs/2026-09-08-albertlint-graded-levels-design.md`

## Global Constraints

- **Baseline to hold: 295 passing, 0 failed, 0 errors.** Run the suite before and after every task.
- Test command, from `~/.dotfiles/nvim/.config/nvim`:
  ```bash
  PLENARY_DIR=~/.local/share/nvim/lazy/plenary.nvim nvim --headless \
    -u tests/minimal_init.lua \
    -c "PlenaryBustedDirectory tests { minimal_init = 'tests/minimal_init.lua' }"
  ```
  Ignore `telescope.builtin not found` and `UpdateRemotePlugins` noise from specs that `:edit` a real file.
- **`~/.dotfiles` is ONE git repo and it is PUBLIC (`grepinsight/.dotfiles`).** No employer, product, internal repo, person, host, ticket, or credential in any file, comments included.
- **The user has uncommitted work in this repo** (`Makefile`, `hammerspoon/.hammerspoon/init.lua`, `lua/custom_commands.lua`, and an untracked `capture/` feature). **Never `git add -A` and never `git add lua/`.** Stage explicit paths only.
- Working branch: `feat/albertlint-levels`. The spec is already committed there as `2e409a4`.
- Conventional commits (`feat(nvim):`, `fix(nvim):`, `docs(nvim):`). Bodies explain *why* and name the measurement or failure. **No AI authorship trailers.**
- `lua/albertlint/level/` is a subdirectory of an already-symlinked module, so **no new symlink is needed**. Only new *top-level* modules under `lua/` need one.
- Comments explain *why*, not *what*. Match the existing density: record the failure that motivated the code, with a date when there is a measurement.
- Never use `--no-verify`. Never disable a test to make it pass.

---

### Task 1: `apply.lua`, the pure span applier

This is the riskiest logic in the change and it uses no `vim.*`, so it goes first and is tested exhaustively with string literals.

**Files:**
- Create: `lua/albertlint/level/apply.lua`
- Test: `tests/albertlint/level_apply_spec.lua`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `apply.build(lines: string[], start_lnum: integer, fixes: LevelFix[]) -> corrected: string[], placed: Placed[], dropped: Dropped[]`
  - `apply.note_lines(label: string, note: string, width: integer) -> string[]`
  - `LevelFix = { line: integer, quote: string, replacement: string, label: string, note: string, occurrence: integer|nil }`
  - `Placed = { fix: LevelFix, lnum: integer, col: integer }` — `lnum` 1-indexed absolute, `col` 0-indexed byte
  - `Dropped = { fix: LevelFix, reason: string }` — `reason` is one of `"line out of range"`, `"quote not found"`, `"overlaps an earlier fix"`

- [ ] **Step 1: Write the failing test**

Create `tests/albertlint/level_apply_spec.lua`:

```lua
---Applying model-returned spans to build the corrected buffer.
---
---This module exists so that a level's boundary is an invariant rather than a request: the
---model can only return labeled spans, so it has no channel through which to reorder a clause
---or change tone. Everything here is therefore about placing spans exactly, and the cases
---below are the ones that silently corrupt text when they are wrong.
---
---No `vim.*` and no filesystem, so these are string-literal unit tests.
local apply = require("albertlint.level.apply")

---@param over table
---@return table
local function fix(over)
  local base = {
    line = 1,
    quote = "use LLM",
    replacement = "calls an LLM",
    label = "Subject-verb agreement",
    note = "`takes` and `use` share the subject `which`.",
  }
  return vim.tbl_extend("force", base, over or {})
end

describe("level.apply build", function()
  it("replaces a single span and reports where it landed", function()
    local lines = { "which takes the text and use LLM" }

    local corrected, placed, dropped = apply.build(lines, 1, { fix({}) })

    assert.same({ "which takes the text and calls an LLM" }, corrected)
    assert.equals(1, #placed)
    assert.equals(0, #dropped)
    assert.equals(1, placed[1].lnum)
    -- 0-indexed byte column of `use` in the original line.
    assert.equals(24, placed[1].col)
  end)

  it("leaves the original lines untouched", function()
    local lines = { "which takes the text and use LLM" }

    apply.build(lines, 1, { fix({}) })

    -- The caller diffs original against corrected, so mutating the input would
    -- produce an empty diff and look like "no findings".
    assert.same({ "which takes the text and use LLM" }, lines)
  end)

  it("applies two fixes on one line right to left", function()
    -- Applied left to right, the first replacement shifts every later offset on the
    -- line and the second fix lands in the wrong place or fails to match.
    local lines = { "a error and a apple" }

    local corrected, placed = apply.build(lines, 1, {
      fix({ quote = "a error", replacement = "an error" }),
      fix({ quote = "a apple", replacement = "an apple" }),
    })

    assert.same({ "an error and an apple" }, corrected)
    assert.equals(2, #placed)
    -- `placed` is sorted by position, not by the order the model returned them.
    assert.equals(0, placed[1].col)
    assert.equals(12, placed[2].col)
  end)

  it("drops the second of two overlapping spans and says why", function()
    local lines = { "the number of samples need review" }

    local corrected, placed, dropped = apply.build(lines, 1, {
      fix({ quote = "samples need", replacement = "samples needs" }),
      fix({ quote = "need review", replacement = "needs review" }),
    })

    -- Applying half of each would produce text neither the model nor the author wrote.
    assert.same({ "the number of samples needs review" }, corrected)
    assert.equals(1, #placed)
    assert.equals(1, #dropped)
    assert.equals("overlaps an earlier fix", dropped[1].reason)
  end)

  it("drops a fix whose quote is absent instead of guessing", function()
    local lines = { "this line is fine" }

    local corrected, placed, dropped = apply.build(lines, 1, { fix({ quote = "not here" }) })

    assert.same({ "this line is fine" }, corrected)
    assert.equals(0, #placed)
    assert.equals("quote not found", dropped[1].reason)
  end)

  it("resolves occurrence 2 to the second instance, not the first", function()
    -- `line` + `quote` alone cannot say which instance is meant. Taking the first
    -- would be silently wrong half the time.
    local lines = { "a error here and a error there" }

    local corrected = apply.build(lines, 1, {
      fix({ quote = "a error", replacement = "an error", occurrence = 2 }),
    })

    assert.same({ "a error here and an error there" }, corrected)
  end)

  it("defaults a missing occurrence to the first instance", function()
    local lines = { "a error here and a error there" }

    local corrected = apply.build(lines, 1, {
      fix({ quote = "a error", replacement = "an error" }),
    })

    assert.same({ "an error here and a error there" }, corrected)
  end)

  it("drops an occurrence past the last instance rather than clamping", function()
    local lines = { "a error here" }

    local _, placed, dropped = apply.build(lines, 1, {
      fix({ quote = "a error", occurrence = 3 }),
    })

    assert.equals(0, #placed)
    assert.equals("quote not found", dropped[1].reason)
  end)

  it("places a span that follows multibyte text", function()
    -- The author's buffers contain Korean. A character-based offset would misplace
    -- every span after the first multibyte run; Lua string ops are byte-based, and
    -- this test is what pins that they stay so.
    local lines = { "레베카는 a error 라고 했다" }

    local corrected, placed = apply.build(lines, 1, {
      fix({ quote = "a error", replacement = "an error" }),
    })

    assert.same({ "레베카는 an error 라고 했다" }, corrected)
    -- 4 Hangul syllables x 3 bytes + the topic particle is 3 bytes more, + 1 space.
    assert.equals(#("레베카는 "), placed[1].col)
  end)

  it("maps absolute line numbers through start_lnum", function()
    local lines = { "first", "a error", "third" }

    local corrected, placed = apply.build(lines, 1, {
      fix({ line = 2, quote = "a error", replacement = "an error" }),
    })

    assert.same({ "first", "an error", "third" }, corrected)
    assert.equals(2, placed[1].lnum)
  end)

  it("drops a fix pointing outside the given range", function()
    local lines = { "only one line" }

    local _, placed, dropped = apply.build(lines, 1, { fix({ line = 99 }) })

    assert.equals(0, #placed)
    assert.equals("line out of range", dropped[1].reason)
  end)

  it("returns the lines unchanged for an empty findings list", function()
    -- An empty result is valid and common, and must not error.
    local lines = { "nothing wrong here" }

    local corrected, placed, dropped = apply.build(lines, 1, {})

    assert.same({ "nothing wrong here" }, corrected)
    assert.equals(0, #placed)
    assert.equals(0, #dropped)
  end)

  it("is deterministic in the order it reports dropped fixes", function()
    -- pairs() over a table keyed by line index has no defined order, so a naive
    -- implementation reports drops in a different order run to run, which makes
    -- the user-facing count message unstable and this test flaky.
    local lines = { "line one", "line two", "line three" }
    local fixes = {
      fix({ line = 3, quote = "absent" }),
      fix({ line = 1, quote = "absent" }),
      fix({ line = 2, quote = "absent" }),
    }

    local first = apply.build(lines, 1, fixes)
    local _, _, d1 = apply.build(lines, 1, fixes)
    local _, _, d2 = apply.build(lines, 1, fixes)

    assert.equals(3, #d1)
    assert.same({ 1, 2, 3 }, { d1[1].fix.line, d1[2].fix.line, d1[3].fix.line })
    assert.same({ d1[1].fix.line, d1[2].fix.line }, { d2[1].fix.line, d2[2].fix.line })
    assert.same({ "line one", "line two", "line three" }, first)
  end)
end)

describe("level.apply note_lines", function()
  it("puts the label on the first line and wraps the note", function()
    local out = apply.note_lines("Article", "One audience exists here so the determiner is obligatory.", 30)

    assert.equals("Article: One audience", out[1])
    assert.is_true(#out > 1)
    for _, l in ipairs(out) do
      assert.is_true(#l <= 30)
    end
  end)

  it("never returns zero lines, because the mirror count would be zero", function()
    -- diffview mirrors this count as blank virt_lines on the other side. A zero-line
    -- note would produce an extmark with an empty virt_lines table, which is an error.
    local out = apply.note_lines("", "", 30)

    assert.equals(1, #out)
  end)

  it("does not split a word that is longer than the width", function()
    local out = apply.note_lines("X", "supercalifragilisticexpialidocious", 10)

    local joined = table.concat(out, " ")
    assert.is_true(joined:find("supercalifragilisticexpialidocious", 1, true) ~= nil)
  end)
end)
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
PLENARY_DIR=~/.local/share/nvim/lazy/plenary.nvim nvim --headless \
  -u tests/minimal_init.lua \
  -c "PlenaryBustedFile tests/albertlint/level_apply_spec.lua"
```

Expected: FAIL, `module 'albertlint.level.apply' not found`.

- [ ] **Step 3: Write the implementation**

Create `lua/albertlint/level/apply.lua`:

```lua
---Turning model-returned spans into the corrected copy of a buffer.
---
---The level tiers ask the model for labeled spans rather than a rewritten paragraph, and
---this module is why that choice pays: with no channel for free-form prose, a level-1 pass
---cannot reorder a clause or change tone even if the model wants to. Out-of-level edits are
---unrepresentable rather than forbidden by prompt.
---
---No `vim.*` and no filesystem, deliberately. This is the logic most likely to be wrong, so
---it is testable with string literals. Every offset here is a BYTE offset: the author's
---buffers contain Korean, and Lua's string functions are byte-based, so a character-based
---index would misplace every span after the first multibyte run.
local M = {}

---@class LevelFix
---@field line integer 1-indexed buffer line
---@field quote string Exact substring to replace
---@field replacement string
---@field label string
---@field note string
---@field occurrence integer|nil 1-indexed, defaults to 1

---Byte span of the nth occurrence of `needle` in `haystack`.
---
---Advances by one byte rather than past the whole match, so overlapping occurrences are
---each reachable. That is nearly irrelevant for prose but costs nothing and avoids a
---surprising gap in the counting.
---@param haystack string
---@param needle string
---@param n integer
---@return integer|nil s 1-indexed
---@return integer|nil e 1-indexed, inclusive
local function nth_find(haystack, needle, n)
  if needle == "" then
    return nil
  end
  local from, s, e = 1, nil, nil
  for _ = 1, n do
    s, e = haystack:find(needle, from, true)
    if not s then
      return nil
    end
    from = s + 1
  end
  return s, e
end

---Build the corrected lines from the originals plus a list of fixes.
---
---`lines` is normally the WHOLE buffer even when the pass covered a smaller range, because
---the caller diffs this result against the real buffer and a range-only array would make
---every untouched line read as a deletion. Fixes carry absolute line numbers, matching the
---convention `semantic.lua` already uses so the model needs no offset arithmetic.
---@param lines string[]
---@param start_lnum integer 1-indexed buffer line of lines[1]
---@param fixes LevelFix[]
---@return string[] corrected
---@return table[] placed { fix, lnum (1-indexed), col (0-indexed byte) }, sorted by position
---@return table[] dropped { fix, reason }, sorted by line then by the order given
function M.build(lines, start_lnum, fixes)
  local corrected = {}
  for i, line in ipairs(lines) do
    corrected[i] = line
  end

  -- Resolve every fix to a byte span first, so overlap detection can compare spans
  -- rather than re-searching. Keyed by line index, with `order` preserving the model's
  -- ordering as a stable tiebreak.
  local by_line, indices, dropped = {}, {}, {}
  local pending_drops = {}
  for order, fix in ipairs(fixes) do
    local lnum = tonumber(fix.line)
    local idx = lnum and (lnum - start_lnum + 1) or nil
    if not idx or not lines[idx] then
      table.insert(pending_drops, { fix = fix, reason = "line out of range", key = math.huge, order = order })
    else
      local s, e = nth_find(lines[idx], fix.quote or "", tonumber(fix.occurrence) or 1)
      if not s then
        table.insert(pending_drops, { fix = fix, reason = "quote not found", key = idx, order = order })
      else
        if not by_line[idx] then
          by_line[idx] = {}
          table.insert(indices, idx)
        end
        table.insert(by_line[idx], { fix = fix, s = s, e = e, order = order })
      end
    end
  end

  -- Walk lines in index order rather than via `pairs`, which has no defined iteration
  -- order. Without this the dropped-fix list comes back shuffled run to run, which makes
  -- the user-facing "N could not be attached" message unstable.
  table.sort(indices)

  local placed = {}
  for _, idx in ipairs(indices) do
    local items = by_line[idx]
    table.sort(items, function(a, b)
      if a.s ~= b.s then
        return a.s < b.s
      end
      return a.order < b.order
    end)

    local kept, last_e = {}, 0
    for _, item in ipairs(items) do
      if item.s <= last_e then
        -- Two spans cannot both apply. Applying half of each produces text that
        -- neither the model nor the author wrote, so the later one is dropped and
        -- counted instead.
        table.insert(pending_drops, {
          fix = item.fix, reason = "overlaps an earlier fix", key = idx, order = item.order,
        })
      else
        table.insert(kept, item)
        last_e = item.e
      end
    end

    -- Right to left. Applied left to right, the first replacement invalidates every
    -- later offset on the line.
    for i = #kept, 1, -1 do
      local item = kept[i]
      local line = corrected[idx]
      corrected[idx] = line:sub(1, item.s - 1) .. tostring(item.fix.replacement) .. line:sub(item.e + 1)
    end

    for _, item in ipairs(kept) do
      table.insert(placed, { fix = item.fix, lnum = start_lnum + idx - 1, col = item.s - 1 })
    end
  end

  table.sort(placed, function(a, b)
    if a.lnum ~= b.lnum then
      return a.lnum < b.lnum
    end
    return a.col < b.col
  end)
  table.sort(pending_drops, function(a, b)
    if a.key ~= b.key then
      return a.key < b.key
    end
    return a.order < b.order
  end)
  for _, d in ipairs(pending_drops) do
    table.insert(dropped, { fix = d.fix, reason = d.reason })
  end

  return corrected, placed, dropped
end

---Render a label and note into wrapped lines for the diff view's virtual text.
---
---Returns at least one line, always. `diffview` mirrors this count as blank virtual lines on
---the other side of the diff to keep the two windows aligned, and an extmark with an empty
---`virt_lines` table is an error rather than a no-op.
---@param label string
---@param note string
---@param width integer
---@return string[]
function M.note_lines(label, note, width)
  local text = (label ~= "" and label ~= nil) and (label .. ": " .. (note or "")) or (note or "")
  text = text:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then
    return { "" }
  end

  local out, current = {}, ""
  for word in text:gmatch("%S+") do
    if current == "" then
      current = word
    elseif #current + 1 + #word <= width then
      current = current .. " " .. word
    else
      table.insert(out, current)
      current = word
    end
  end
  if current ~= "" then
    table.insert(out, current)
  end
  -- A single word longer than `width` is left intact rather than split. Breaking a token
  -- mid-word to satisfy a wrap makes the note harder to read than an overlong line does.
  return out
end

M._nth_find = nth_find
return M
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
PLENARY_DIR=~/.local/share/nvim/lazy/plenary.nvim nvim --headless \
  -u tests/minimal_init.lua \
  -c "PlenaryBustedFile tests/albertlint/level_apply_spec.lua"
```

Expected: PASS, 16 successes, 0 failures.

If `note_lines` fails the `<= 30` width assertion, check that the label plus the first word does not already exceed the width; the first test's label is `Article` (7 chars) so `Article: One audience` is 21.

- [ ] **Step 5: Run the whole suite**

Expected: 295 + 16 = **311 passing, 0 failed, 0 errors**.

- [ ] **Step 6: Commit**

```bash
git -C ~/.dotfiles add nvim/.config/nvim/lua/albertlint/level/apply.lua \
                        nvim/.config/nvim/tests/albertlint/level_apply_spec.lua
git -C ~/.dotfiles commit -m "feat(nvim): pure span applier for the graded level tiers

The level tiers ask the model for labeled spans rather than a rewritten
paragraph, which makes an out-of-level edit unrepresentable instead of
merely forbidden by prompt. This is the module that pays that off.

Three cases here silently corrupt text when they are wrong, so each has
a test. Two fixes on one line must apply right to left, or the first
replacement invalidates the second's offset. Two overlapping spans
cannot both apply, so the later is dropped and counted rather than
half-applied. Offsets are bytes, not characters: the author's buffers
contain Korean and a character index would misplace every span after the
first multibyte run.

Dropped fixes are sorted rather than collected through pairs(), whose
iteration order is undefined. Without that the user-facing \"N could not
be attached\" count came back shuffled run to run."
```

---

### Task 2: `levels.lua`, the catalogue and the prompt

**Files:**
- Create: `lua/albertlint/level/levels.lua`
- Test: `tests/albertlint/level_levels_spec.lua`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `levels.levels: table<integer, LevelDef>`
  - `levels.get(id: integer) -> LevelDef|nil`
  - `levels.prompt(id: integer) -> string|nil`
  - `LevelDef = { id, name, spans_only, brief, allow: string[], forbid: string[], ignore: string[] }`

- [ ] **Step 1: Write the failing test**

Create `tests/albertlint/level_levels_spec.lua`:

```lua
---The level catalogue and the prompt built from it.
---
---Level 1's whole value is its boundary: it must not reorder, retone, or rewrite for
---concision, because those are levels 3, 2, and 4. These tests pin the boundary in the
---prompt text, and pin the ignore list, which exists because the author's allowlist has
---settled three families (contractions, space-before-a-mark, capitalization) as deliberate
---typing shortcuts. Without the ignore list a generic grammar prompt surfaces exactly those
---and drowns the findings that matter.
local levels = require("albertlint.level.levels")

describe("level.levels catalogue", function()
  it("defines level 1 as grammar and usage", function()
    local def = levels.get(1)

    assert.equals(1, def.id)
    assert.equals("grammar/usage", def.name)
    assert.is_true(def.spans_only)
  end)

  it("returns nil for a level that has no command yet", function()
    -- Levels 2-4 exist as rows recording intent. get() must not invent one.
    assert.is_nil(levels.get(2))
    assert.is_nil(levels.get(99))
  end)
end)

describe("level.levels prompt", function()
  it("names the JSON contract, including occurrence", function()
    local p = levels.prompt(1)

    assert.is_true(p:find("findings", 1, true) ~= nil)
    assert.is_true(p:find("quote", 1, true) ~= nil)
    assert.is_true(p:find("replacement", 1, true) ~= nil)
    assert.is_true(p:find("occurrence", 1, true) ~= nil)
    assert.is_true(p:find("label", 1, true) ~= nil)
    assert.is_true(p:find("note", 1, true) ~= nil)
  end)

  it("forbids the things that belong to higher levels", function()
    local p = levels.prompt(1):lower()

    for _, banned in ipairs({ "reorder", "tone", "concision", "content" }) do
      assert.is_true(p:find(banned, 1, true) ~= nil, "prompt must mention " .. banned)
    end
  end)

  it("tells the model to ignore the settled typing shortcuts", function()
    local p = levels.prompt(1):lower()

    assert.is_true(p:find("capitalization", 1, true) ~= nil)
    assert.is_true(p:find("contraction", 1, true) ~= nil)
    assert.is_true(p:find("space before", 1, true) ~= nil)
  end)

  it("says an empty findings array is a valid answer", function()
    -- Without this the model invents work, and a false positive in prose trains the
    -- author to ignore the tool.
    local p = levels.prompt(1):lower()

    assert.is_true(p:find("empty", 1, true) ~= nil)
  end)

  it("returns nil for an unimplemented level", function()
    assert.is_nil(levels.prompt(2))
  end)
end)
```

- [ ] **Step 2: Run to verify it fails**

```bash
PLENARY_DIR=~/.local/share/nvim/lazy/plenary.nvim nvim --headless \
  -u tests/minimal_init.lua -c "PlenaryBustedFile tests/albertlint/level_levels_spec.lua"
```

Expected: FAIL, `module 'albertlint.level.levels' not found`.

- [ ] **Step 3: Write the implementation**

Create `lua/albertlint/level/levels.lua`:

```lua
---The catalogue of graded review levels.
---
---Data, not logic, in the shape of `rules.lua`: adding level 2 should be one row, not a
---rewrite. Four levels are planned and they answer different questions, which is the whole
---point of grading them rather than running one pass that does everything:
---
---  1  Is it grammatical?
---  2  Does it hold together?
---  3  Is it in the right order?
---  4  Is it substantive, and what would make it convincing?
---
---Only level 1 has a command. Rows 2 through 4 are recorded below as comments rather than as
---half-built entries, so `get()` cannot hand a caller a level with no prompt.
local M = {}

---The three families the author has settled as deliberate typing shortcuts rather than
---knowledge gaps, and which therefore must not be reported.
---
---This is the one concession to personalization in an otherwise generic prompt, and it is
---on the negative side only: suppressing known non-issues is a different act from hunting
---known issues, and only the second was declined. The counts come from the author's fix log:
---the contraction family was retired at 10 instances on 2026-08-27, and space-before-a-mark
---was settled at 31 instances on 2026-09-04. Without this list a generic grammar prompt
---surfaces exactly these and drowns everything that matters.
local IGNORE = {
  "capitalization of any kind, including a sentence starting lowercase and a lone `i`",
  "a missing apostrophe in a contraction: `dont`, `didnt`, `cant`, `wont`, `whats`, `isnt`",
  "a space before a punctuation mark, as in `why ?` or `3 times , investigate`",
  "spacing, hyphenation, and line wrapping",
}

---@class LevelDef
---@field id integer
---@field name string
---@field spans_only boolean
---@field brief string
---@field allow string[]
---@field forbid string[]
---@field ignore string[]

---@type table<integer, LevelDef>
M.levels = {
  [1] = {
    id = 1,
    name = "grammar/usage",
    spans_only = true,
    brief = "Report only grammar and usage errors.",
    allow = {
      "articles, definite and indefinite",
      "subject-verb agreement, including across an intervening phrase",
      "verb tense and aspect",
      "prepositions",
      "singular and plural",
      "pronoun case and reference where the sentence is ungrammatical without a change",
      "fixed idioms used in a form that is not English",
      "a word used in a sense it does not have",
    },
    forbid = {
      "reordering clauses, sentences, or ideas",
      "tone, register, or formality",
      "concision: do not cut a word merely because it is unnecessary",
      "content: do not add, remove, or argue with what is being said",
    },
    ignore = IGNORE,
  },

  -- Not implemented, and deliberately absent from the table rather than stubbed, so that
  -- `get()` cannot return a level whose prompt does not exist. Each needs the same
  -- treatment level 1 got: a data shape that makes out-of-level edits unrepresentable.
  --   [2] coherence   -- does each sentence follow from the one before it
  --   [3] rearrange   -- is this the right order for these ideas
  --   [4] substantive -- is the claim carried, and what would make it convincing
}

---@param id integer
---@return LevelDef|nil
function M.get(id)
  return M.levels[tonumber(id) or -1]
end

---@param items string[]
---@return string
local function bullets(items)
  local out = {}
  for _, item in ipairs(items) do
    table.insert(out, "- " .. item)
  end
  return table.concat(out, "\n")
end

---Build the prompt for a level.
---
---The JSON contract asks for `quote` plus `occurrence` rather than a column, because a
---column from a model is not trustworthy and because the same quote can legitimately appear
---twice on one line. `semantic.lua` already learned the first half of that lesson.
---@param id integer
---@return string|nil
function M.prompt(id)
  local def = M.get(id)
  if not def then
    return nil
  end

  return table.concat({
    ("You are reviewing one writer's English at level %d of four: %s."):format(def.id, def.name),
    def.brief,
    "",
    "He is a fluent Korean L1 speaker. Report only these categories:",
    bullets(def.allow),
    "",
    "Do NOT report any of the following. Each belongs to a later level and reporting it here",
    "defeats the point of grading the passes:",
    bullets(def.forbid),
    "",
    "Ignore entirely. These are deliberate typing shortcuts, not mistakes:",
    bullets(def.ignore),
    "",
    "Rules for your output:",
    "- Report a finding ONLY if you are confident. A false positive in prose trains him to",
    "  ignore the tool, which is worse than a miss.",
    "- `quote` must be the shortest exact substring of the given line that contains the error,",
    "  copied byte for byte. `replacement` is that same span, corrected, and nothing more.",
    "- Change only what is wrong. `replacement` must not restate the surrounding words.",
    "- `occurrence` is 1-indexed and says which instance of `quote` on that line you mean.",
    "  Use 1 unless the substring genuinely appears more than once.",
    "- `label` is a short name for the error category. `note` is one sentence: the fix and why.",
    "- Return STRICT JSON, no prose, no markdown fence:",
    '  {"findings":[{"line":<number as given>,"quote":"<exact substring>","occurrence":1,'
      .. '"replacement":"<corrected span>","label":"<category>","note":"<one sentence>"}]}',
    "- An empty findings array is a valid and common answer. Return it rather than inventing",
    "  work.",
    "",
    "The text, one line per numbered entry:",
    "",
  }, "\n")
end

M._IGNORE = IGNORE
return M
```

- [ ] **Step 4: Run to verify it passes**

Expected: PASS, 6 successes.

- [ ] **Step 5: Run the whole suite**

Expected: **317 passing, 0 failed, 0 errors**.

- [ ] **Step 6: Commit**

```bash
git -C ~/.dotfiles add nvim/.config/nvim/lua/albertlint/level/levels.lua \
                        nvim/.config/nvim/tests/albertlint/level_levels_spec.lua
git -C ~/.dotfiles commit -m "feat(nvim): level catalogue, with the boundary in the prompt

Data, not logic, in the shape of rules.lua, so adding level 2 is one row.
Levels 2-4 are comments rather than half-built entries, so get() cannot
hand a caller a level whose prompt does not exist.

The prompt is generic on the positive side, by choice: no error history
and no filesystem dependency on the vault, which also means returned
labels will not match the fix log's vocabulary. The one concession is on
the negative side. Three families are ignored outright because they are
settled typing shortcuts rather than gaps: contractions (retired at 10
instances, 2026-08-27), a space before a mark (settled at 31 instances,
2026-09-04), and capitalization. Suppressing a known non-issue is a
different act from hunting a known issue, and only the second was
declined. Without the list, a generic grammar prompt surfaces exactly
these and drowns the rest."
```

---

### Task 3: `provider.lua`, both backends with the key out of argv

**Files:**
- Create: `lua/albertlint/level/provider.lua`
- Test: `tests/albertlint/level_provider_spec.lua`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `provider.CLAUDE_CMD: string[]`
  - `provider.claude_cmd(opts: table) -> string[]`
  - `provider.openai_argv(body_path: string, opts: table) -> string[]` — never contains the key
  - `provider.openai_config(key: string) -> string` — the `curl --config -` stdin payload
  - `provider.openai_body(model: string, prompt: string, text: string) -> string` — JSON
  - `provider.scrub(s: string) -> string`
  - `provider.parse(text: string) -> table|nil, string|nil`
  - `provider.call(name: string, prompt: string, text: string, opts: table, cb: fun(res: table)) -> table|nil` — `res` is `{ ok, findings, err }`; returns the `vim.system` handle or nil

- [ ] **Step 1: Write the failing test**

Create `tests/albertlint/level_provider_spec.lua`:

```lua
---The two backends, and the credential handling that must not regress.
---
---The openai argv test is the important one and it is a standing regression test, not a
---formality: argv is world-readable through `ps`, so passing the key as
---`-H "Authorization: Bearer ..."` would expose it to every local process for the lifetime
---of the request. The key goes to curl on stdin instead. If someone "simplifies" that back
---into a header argument, this test is what catches it.
local provider = require("albertlint.level.provider")

local FAKE_KEY = "sk-NOT-A-REAL-KEY-test-fixture-only"

describe("level.provider claude argv", function()
  it("carries all three isolation flags", function()
    -- Measured 2026-08-26 and recorded in util/claude.lua: --safe-mode alone still left
    -- 12 skills reachable, --disable-slash-commands is what takes it to zero, and
    -- --strict-mcp-config drops the MCP servers. "Vanilla claude" needs all three.
    local cmd = provider.claude_cmd({})
    local joined = table.concat(cmd, " ")

    assert.is_true(joined:find("--safe-mode", 1, true) ~= nil)
    assert.is_true(joined:find("--disable-slash-commands", 1, true) ~= nil)
    assert.is_true(joined:find("--strict-mcp-config", 1, true) ~= nil)
  end)

  it("agrees with util.claude's measured raw flag set", function()
    -- Do not re-derive the flags. If util/claude.lua learns a fourth one, this fails.
    local raw = require("util.claude").raw_flags
    local joined = table.concat(provider.claude_cmd({}), " ")

    for _, flag in ipairs(raw) do
      assert.is_true(joined:find(flag, 1, true) ~= nil, "missing " .. flag)
    end
  end)

  it("pins the model, because the default one returned no findings", function()
    -- Measured 2026-08-28: without --model sonnet the CLI's default returned
    -- {"findings":[]} twice on a five-line sample with an obvious missing `the`.
    local joined = table.concat(provider.claude_cmd({}), " ")

    assert.is_true(joined:find("--model", 1, true) ~= nil)
  end)

  it("does not mutate the shared CLAUDE_CMD table", function()
    local before = #provider.CLAUDE_CMD

    provider.claude_cmd({ model = "opus" })
    provider.claude_cmd({ model = "opus" })

    assert.equals(before, #provider.CLAUDE_CMD)
  end)
end)

describe("level.provider openai credential handling", function()
  it("never puts the key in argv", function()
    local argv = provider.openai_argv("/tmp/body.json", { key = FAKE_KEY })
    local joined = table.concat(argv, " ")

    assert.is_nil(joined:find("sk-", 1, true))
    assert.is_nil(joined:find(FAKE_KEY, 1, true))
    assert.is_nil(joined:find("Bearer", 1, true))
    assert.is_nil(joined:find("Authorization", 1, true))
  end)

  it("reads its config from stdin", function()
    local joined = table.concat(provider.openai_argv("/tmp/body.json", { key = FAKE_KEY }), " ")

    assert.is_true(joined:find("--config", 1, true) ~= nil)
    assert.is_true(joined:find("-", 1, true) ~= nil)
  end)

  it("references the body by path rather than inlining it", function()
    local joined = table.concat(provider.openai_argv("/tmp/body.json", { key = FAKE_KEY }), " ")

    assert.is_true(joined:find("@/tmp/body.json", 1, true) ~= nil)
  end)

  it("puts the key in the stdin config, which is the only place it belongs", function()
    local cfg = provider.openai_config(FAKE_KEY)

    assert.is_true(cfg:find(FAKE_KEY, 1, true) ~= nil)
    assert.is_true(cfg:find("Authorization", 1, true) ~= nil)
  end)

  it("asks for a strict json schema so malformed JSON is impossible", function()
    local body = provider.openai_body("gpt-4o", "PROMPT", "1: some text")

    assert.is_true(body:find("json_schema", 1, true) ~= nil)
    assert.is_true(body:find("findings", 1, true) ~= nil)
    -- The body carries the author's prose, never the key.
    assert.is_nil(body:find("sk-", 1, true))
  end)
end)

describe("level.provider scrub", function()
  it("removes a bearer token from text headed for a notify", function()
    -- curl writes the effective request to stderr under some verbosity settings, and a
    -- vim.notify goes into the message history where it persists.
    local out = provider.scrub("curl: Authorization: Bearer " .. FAKE_KEY .. " failed")

    assert.is_nil(out:find(FAKE_KEY, 1, true))
    assert.is_nil(out:find("sk-", 1, true))
  end)

  it("removes a bare key even with no Bearer prefix", function()
    local out = provider.scrub("error near " .. FAKE_KEY)

    assert.is_nil(out:find(FAKE_KEY, 1, true))
  end)

  it("leaves ordinary text alone", function()
    assert.equals("connection refused", provider.scrub("connection refused"))
  end)

  it("handles nil without erroring", function()
    assert.equals("", provider.scrub(nil))
  end)
end)

describe("level.provider parse", function()
  it("strips a markdown fence around the JSON", function()
    -- Models wrap JSON in a fence often enough that stripping is cheaper than
    -- re-prompting, which is the lesson semantic.lua already encodes.
    local parsed, err = provider.parse('```json\n{"findings":[]}\n```')

    assert.is_nil(err)
    assert.same({}, parsed.findings)
  end)

  it("accepts a bare object", function()
    local parsed = provider.parse('{"findings":[{"line":1}]}')

    assert.equals(1, #parsed.findings)
  end)

  it("errors when there is no JSON object at all", function()
    local parsed, err = provider.parse("I could not do that.")

    assert.is_nil(parsed)
    assert.is_true(err:find("no JSON", 1, true) ~= nil)
  end)

  it("errors when the object has no findings key", function()
    local parsed, err = provider.parse('{"result":"ok"}')

    assert.is_nil(parsed)
    assert.is_true(err:find("findings", 1, true) ~= nil)
  end)

  it("errors on malformed JSON rather than throwing", function()
    local parsed, err = provider.parse('{"findings":[},}')

    assert.is_nil(parsed)
    assert.is_not_nil(err)
  end)

  it("unwraps an OpenAI chat completion envelope", function()
    local envelope = vim.json.encode({
      choices = { { message = { content = '{"findings":[{"line":3}]}' } } },
    })

    local parsed = provider.parse(envelope)

    assert.equals(3, parsed.findings[1].line)
  end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL, `module 'albertlint.level.provider' not found`.

- [ ] **Step 3: Write the implementation**

Create `lua/albertlint/level/provider.lua`:

```lua
---The two backends for the graded level passes.
---
---`claude` shells out so the plugin never sees a credential: the CLI already holds them.
---`openai` needs a key, and the whole of the credential handling below exists because argv
---is world-readable through `ps`. Passing the key as `-H "Authorization: Bearer ..."` would
---expose it to every local process for the lifetime of the request, so it goes to curl on
---stdin via `--config -` instead, and the request body goes to a private temp file.
local M = {}

---The vanilla-claude invocation.
---
---The three isolation flags are not re-derived here. `util/claude.lua:81` already carries
---them as `raw_flags` with a measurement from 2026-08-26: `--safe-mode` alone still left 12
---skills reachable, `--disable-slash-commands` is what takes skills to zero, and
---`--strict-mcp-config` drops the MCP servers. All three are needed to actually reach
---"no skills or plugins loaded".
---
---`--model sonnet` is carried over from `config.lua` for the reason recorded there: measured
---2026-08-28, the CLI's default model returned `{"findings":[]}` twice on a five-line sample
---with an obvious missing `the`, where sonnet found it. A slower pass that finds things beats
---a fast one that never does.
M.CLAUDE_CMD = {
  "claude", "-p", "--output-format", "text", "--model", "sonnet",
  "--safe-mode", "--disable-slash-commands", "--strict-mcp-config",
}

---@param opts table|nil
---@return string[]
function M.claude_cmd(opts)
  opts = opts or {}
  -- Copied, not returned by reference. A caller appending a flag would otherwise grow the
  -- shared table on every invocation.
  local cmd = {}
  for _, arg in ipairs(M.CLAUDE_CMD) do
    table.insert(cmd, arg)
  end
  if opts.model then
    for i, arg in ipairs(cmd) do
      if arg == "--model" then
        cmd[i + 1] = opts.model
        break
      end
    end
  end
  return cmd
end

M.OPENAI_URL = "https://api.openai.com/v1/chat/completions"

---curl argv. The key is deliberately absent; see `openai_config`.
---@param body_path string Path to a file holding the JSON request body
---@param opts table|nil
---@return string[]
function M.openai_argv(body_path, opts)
  opts = opts or {}
  return {
    "curl", "--silent", "--show-error", "--fail-with-body",
    -- Read the auth header from stdin so it never enters argv.
    "--config", "-",
    "--header", "Content-Type: application/json",
    "--data", "@" .. body_path,
    opts.url or M.OPENAI_URL,
  }
end

---The `curl --config -` payload, delivered on stdin.
---
---This is the ONLY place the key appears. curl's config format takes one directive per
---line; `header = "..."` is equivalent to `-H`, without the argv exposure.
---@param key string
---@return string
function M.openai_config(key)
  return ('header = "Authorization: Bearer %s"\n'):format(key)
end

---@param model string
---@param prompt string
---@param text string
---@return string json
function M.openai_body(model, prompt, text)
  -- `strict` plus an explicit schema makes malformed JSON structurally impossible, which
  -- deletes the whole parse-failure path that the claude backend still needs.
  local schema = {
    type = "object",
    additionalProperties = false,
    required = { "findings" },
    properties = {
      findings = {
        type = "array",
        items = {
          type = "object",
          additionalProperties = false,
          required = { "line", "quote", "occurrence", "replacement", "label", "note" },
          properties = {
            line = { type = "integer" },
            quote = { type = "string" },
            occurrence = { type = "integer" },
            replacement = { type = "string" },
            label = { type = "string" },
            note = { type = "string" },
          },
        },
      },
    },
  }
  return vim.json.encode({
    model = model,
    messages = {
      { role = "system", content = prompt },
      { role = "user", content = text },
    },
    response_format = {
      type = "json_schema",
      json_schema = { name = "albertlint_findings", strict = true, schema = schema },
    },
  })
end

---Remove anything credential-shaped from text about to be shown to the user.
---
---`vim.notify` output lands in the message history and persists there, and curl writes the
---effective request to stderr under some verbosity settings. Scrub rather than trust.
---@param s string|nil
---@return string
function M.scrub(s)
  if not s then
    return ""
  end
  s = s:gsub("[Bb]earer%s+[%w%-%._~%+/=]+", "Bearer [redacted]")
  s = s:gsub("sk%-[%w%-%._]+", "[redacted]")
  local key = vim.env.OPENAI_API_KEY
  if key and key ~= "" then
    s = s:gsub(vim.pesc(key), "[redacted]")
  end
  return s
end

---Pull a findings table out of whatever the backend returned.
---
---Handles three shapes: a bare object, an object inside a markdown fence (models do this
---often enough that stripping is cheaper than re-prompting), and an OpenAI chat completion
---envelope whose content is itself a JSON string.
---@param text string
---@return table|nil parsed
---@return string|nil err
function M.parse(text)
  local json = (text or ""):match("%b{}")
  if not json then
    return nil, "no JSON object in response"
  end
  local ok, decoded = pcall(vim.json.decode, json)
  if not ok then
    return nil, "invalid JSON: " .. tostring(decoded)
  end
  if type(decoded) ~= "table" then
    return nil, "response was not an object"
  end

  -- Unwrap a chat completion envelope, whose `content` is a JSON string rather than a table.
  if decoded.findings == nil and decoded.choices then
    local content = vim.tbl_get(decoded, "choices", 1, "message", "content")
    if type(content) == "string" then
      return M.parse(content)
    end
  end

  if decoded.findings == nil then
    return nil, "response has no `findings` key"
  end
  return decoded, nil
end

---@param name string "claude" | "openai"
---@param prompt string
---@param text string The numbered lines
---@param opts table { timeout_ms, model, url }
---@param cb fun(res: { ok: boolean, findings: table[]|nil, err: string|nil })
---@return table|nil handle A vim.system handle, or nil if the call could not start
function M.call(name, prompt, text, opts, cb)
  opts = opts or {}
  local function finish(res)
    vim.schedule(function()
      cb(res)
    end)
  end

  if name == "claude" then
    local cmd = M.claude_cmd(opts)
    if vim.fn.executable(cmd[1]) == 0 then
      finish({ ok = false, err = ("`%s` is not on PATH"):format(cmd[1]) })
      return nil
    end
    return vim.system(cmd, {
      stdin = prompt .. text,
      text = true,
      timeout = opts.timeout_ms,
    }, function(res)
      if res.code ~= 0 then
        finish({
          ok = false,
          err = ("claude exited %d: %s"):format(res.code, M.scrub(res.stderr):sub(1, 200)),
        })
        return
      end
      local parsed, err = M.parse(res.stdout or "")
      if not parsed then
        finish({ ok = false, err = err })
      else
        finish({ ok = true, findings = parsed.findings })
      end
    end)
  end

  if name == "openai" then
    local key = vim.env.OPENAI_API_KEY
    if not key or key == "" then
      -- Name the variable, never a value.
      finish({ ok = false, err = "OPENAI_API_KEY is not set in this environment" })
      return nil
    end
    if vim.fn.executable("curl") == 0 then
      finish({ ok = false, err = "`curl` is not on PATH" })
      return nil
    end

    local body_path = vim.fn.tempname() .. ".json"
    local fd = io.open(body_path, "w")
    if not fd then
      finish({ ok = false, err = "could not create a temp file for the request body" })
      return nil
    end
    fd:write(M.openai_body(opts.model or "gpt-4o", prompt, text))
    fd:close()
    -- Owner-only. The body holds the author's prose, and a world-readable temp file in a
    -- shared /tmp is an avoidable disclosure even without a credential in it.
    pcall(vim.loop.fs_chmod, body_path, 384) -- 0600

    return vim.system(M.openai_argv(body_path, opts), {
      stdin = M.openai_config(key),
      text = true,
      timeout = opts.timeout_ms,
    }, function(res)
      os.remove(body_path)
      if res.code ~= 0 then
        finish({
          ok = false,
          err = ("curl exited %d: %s"):format(res.code, M.scrub(res.stderr or res.stdout):sub(1, 200)),
        })
        return
      end
      local parsed, err = M.parse(res.stdout or "")
      if not parsed then
        finish({ ok = false, err = err })
      else
        finish({ ok = true, findings = parsed.findings })
      end
    end)
  end

  finish({ ok = false, err = ("unknown provider %q"):format(tostring(name)) })
  return nil
end

return M
```

- [ ] **Step 4: Run to verify it passes**

Expected: PASS, 18 successes.

If `openai_argv`'s `--config -` assertion trips on the bare `-` also matching `--silent`, note that the test uses `find(..., plain)` on the joined string, so `-` is trivially present; the meaningful assertion is `--config`.

- [ ] **Step 5: Run the whole suite**

Expected: **335 passing, 0 failed, 0 errors**.

- [ ] **Step 6: Commit**

```bash
git -C ~/.dotfiles add nvim/.config/nvim/lua/albertlint/level/provider.lua \
                        nvim/.config/nvim/tests/albertlint/level_provider_spec.lua
git -C ~/.dotfiles commit -m "feat(nvim): claude and openai backends, key kept out of argv

Both providers ship together so the two can be compared on real prose.

The credential handling is the part worth reading. argv is world-readable
through ps, so -H \"Authorization: Bearer ...\" would expose the key to
every local process for the lifetime of the request. It goes to curl on
stdin via --config - instead, the request body goes to a 0600 temp file
referenced by path, and the key is read from the environment rather than
from config so it is never in a dotfile. A test asserts no rendered argv
contains sk- or Bearer, which is a standing regression test rather than a
formality: the header form is the obvious simplification and this is what
catches it.

stderr excerpts are scrubbed before reaching vim.notify, because curl
writes the effective request to stderr under some verbosity settings and
the message history persists.

The three claude isolation flags are taken from util/claude.lua rather
than re-derived, and a test fails if the two drift apart."
```

---

### Task 4: `diffview.lua`, native diff with mirrored notes

**Files:**
- Create: `lua/albertlint/level/diffview.lua`
- Test: `tests/albertlint/level_diffview_spec.lua`

**Interfaces:**
- Consumes: `apply.note_lines`
- Produces:
  - `diffview.open(bufnr, corrected: string[], placed: Placed[], opts: table) -> State`
  - `diffview.close(state: State) -> boolean`
  - `State = { source_buf, scratch_buf, source_win, scratch_win, ns, count }`

- [ ] **Step 1: Write the failing test**

Create `tests/albertlint/level_diffview_spec.lua`:

```lua
---The two-window diff, and the alignment invariant that makes the notes safe.
---
---Diff mode aligns two windows using filler lines it computes itself. `virt_lines` add
---screen rows to ONE window, so a note placed only on the corrected side pushes every line
---below it out of alignment. Measured 2026-09-08 on a five-line pair with one one-line note
---on the right buffer only: line 3 sat at screen row 4 on the right and row 3 on the left.
---Mirroring the note with an equal count of blank virtual lines on the left restored exact
---alignment.
---
---The blank extmarks therefore look like dead code and are not. This spec is what stops them
---being deleted.
local diffview = require("albertlint.level.diffview")

---@return integer bufnr
local function source()
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "alpha",
    "which takes the text and use LLM",
    "beta",
    "grammar/expression error",
    "gamma",
  })
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_win_set_buf(0, buf)
  return buf
end

local CORRECTED = {
  "alpha",
  "which takes the text and calls an LLM",
  "beta",
  "grammar/expression errors",
  "gamma",
}

---@return table[]
local function placed()
  return {
    { lnum = 2, col = 24, fix = { label = "Agreement", note = "`takes` and `use` share a subject." } },
    { lnum = 4, col = 19, fix = { label = "Number", note = "Open-ended set, so the plural is the default." } },
  }
end

describe("level.diffview open", function()
  it("puts both windows in diff mode", function()
    local buf = source()

    local state = diffview.open(buf, CORRECTED, placed(), {})

    assert.is_true(vim.wo[state.source_win].diff)
    assert.is_true(vim.wo[state.scratch_win].diff)

    diffview.close(state)
  end)

  it("shows the corrected text in the scratch buffer", function()
    local buf = source()

    local state = diffview.open(buf, CORRECTED, placed(), {})

    assert.same(CORRECTED, vim.api.nvim_buf_get_lines(state.scratch_buf, 0, -1, false))
    -- The source buffer is untouched until the author presses `do`.
    assert.equals("which takes the text and use LLM",
      vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1])

    diffview.close(state)
  end)

  it("keeps the scratch buffer unlisted and scratch", function()
    local buf = source()

    local state = diffview.open(buf, CORRECTED, placed(), {})

    assert.equals("nofile", vim.bo[state.scratch_buf].buftype
      == "" and "nofile" or vim.bo[state.scratch_buf].buftype)
    assert.is_false(vim.bo[state.scratch_buf].buflisted)

    diffview.close(state)
  end)

  it("mirrors every note with an equal count of blanks on the source side", function()
    -- THE invariant. If these two counts diverge, the diff visibly desyncs.
    local buf = source()

    local state = diffview.open(buf, CORRECTED, placed(), {})

    local function virt_line_count(b)
      local total = 0
      for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(b, state.ns, 0, -1, { details = true })) do
        total = total + #(mark[4].virt_lines or {})
      end
      return total
    end

    local on_source = virt_line_count(buf)
    local on_scratch = virt_line_count(state.scratch_buf)

    assert.is_true(on_scratch > 0)
    assert.equals(on_scratch, on_source)

    diffview.close(state)
  end)

  it("places the note at the row the fix landed on", function()
    local buf = source()

    local state = diffview.open(buf, CORRECTED, placed(), {})

    local marks = vim.api.nvim_buf_get_extmarks(state.scratch_buf, state.ns, 0, -1, { details = true })
    local rows = {}
    for _, mark in ipairs(marks) do
      rows[mark[2]] = true
    end

    -- placed lnums are 1-indexed; extmark rows are 0-indexed.
    assert.is_true(rows[1])
    assert.is_true(rows[3])

    diffview.close(state)
  end)

  it("reports how many findings it rendered", function()
    local buf = source()

    local state = diffview.open(buf, CORRECTED, placed(), {})

    assert.equals(2, state.count)

    diffview.close(state)
  end)
end)

describe("level.diffview close", function()
  it("leaves the source buffer out of diff mode", function()
    -- Without teardown a stale diffthis leaves the author's real buffer permanently in
    -- diff mode, which is the worst kind of leftover: it looks like a broken editor.
    local buf = source()
    local state = diffview.open(buf, CORRECTED, placed(), {})

    diffview.close(state)

    assert.is_false(vim.wo[state.source_win].diff)
  end)

  it("wipes the scratch buffer", function()
    local buf = source()
    local state = diffview.open(buf, CORRECTED, placed(), {})

    diffview.close(state)

    assert.is_false(vim.api.nvim_buf_is_valid(state.scratch_buf))
  end)

  it("clears the notes from the source buffer", function()
    local buf = source()
    local state = diffview.open(buf, CORRECTED, placed(), {})

    diffview.close(state)

    local left = vim.api.nvim_buf_get_extmarks(buf, state.ns, 0, -1, {})
    assert.equals(0, #left)
  end)

  it("is idempotent", function()
    local buf = source()
    local state = diffview.open(buf, CORRECTED, placed(), {})

    assert.is_true(diffview.close(state))
    assert.is_false(diffview.close(state))
  end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL, `module 'albertlint.level.diffview' not found`.

- [ ] **Step 3: Write the implementation**

Create `lua/albertlint/level/diffview.lua`:

```lua
---The two-window diff that renders a level pass.
---
---Native diff mode rather than a hand-built review buffer, deliberately: `]c`, `[c`, `do`,
---and `dp` already are hunk navigation and per-hunk accept and reject, so there is no apply
---code here to get wrong, and the author's existing diff habits transfer unchanged.
---
---The one non-obvious part is the mirrored blank virtual lines. Diff mode aligns two windows
---with filler lines it computes itself, while `virt_lines` add screen rows to one window
---only. Measured 2026-09-08 on a five-line pair with a single one-line note on the right
---buffer: line 3 sat at screen row 4 on the right and row 3 on the left, so every line below
---the note was out of alignment. Emitting an equal count of blank virtual lines on the other
---side restores it exactly. The blanks look like dead code. They are not.
local apply = require("albertlint.level.apply")

local M = {}

local NOTE_WIDTH = 64

---@class LevelDiffState
---@field source_buf integer
---@field scratch_buf integer
---@field source_win integer
---@field scratch_win integer
---@field ns integer
---@field count integer
---@field closed boolean

---@param bufnr integer
---@param corrected string[] The WHOLE buffer with the reviewed range corrected
---@param placed table[] { fix, lnum (1-indexed), col }
---@param opts table|nil { level }
---@return LevelDiffState
function M.open(bufnr, corrected, placed, opts)
  opts = opts or {}
  local ns = vim.api.nvim_create_namespace("albertlint_level")
  local source_win = vim.api.nvim_get_current_win()

  local scratch = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(scratch, 0, -1, false, corrected)
  vim.bo[scratch].buftype = "nofile"
  vim.bo[scratch].bufhidden = "wipe"
  vim.bo[scratch].swapfile = false
  vim.bo[scratch].filetype = vim.bo[bufnr].filetype
  vim.bo[scratch].modifiable = true
  local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
  pcall(vim.api.nvim_buf_set_name, scratch,
    ("albertlint://level%d/%s"):format(opts.level or 1, name == "" and "buffer" or name))

  vim.cmd("vertical rightbelow split")
  local scratch_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(scratch_win, scratch)

  -- diffthis in each window, not `:windo`, so no other window in the tab is affected.
  vim.api.nvim_win_call(scratch_win, function()
    vim.cmd("diffthis")
  end)
  vim.api.nvim_win_call(source_win, function()
    vim.cmd("diffthis")
  end)

  local count = 0
  for _, item in ipairs(placed) do
    local row = item.lnum - 1
    local note = apply.note_lines(item.fix.label or "", item.fix.note or "", NOTE_WIDTH)

    local virt, blanks = {}, {}
    for _, text in ipairs(note) do
      table.insert(virt, { { "  " .. text, "Comment" } })
      -- One blank per note line. This count, not the text, is what preserves alignment.
      table.insert(blanks, { { "", "Comment" } })
    end

    local ok_scratch = pcall(vim.api.nvim_buf_set_extmark, scratch, ns, row, 0, {
      virt_lines = virt,
      virt_lines_above = true,
    })
    local ok_source = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, 0, {
      virt_lines = blanks,
      virt_lines_above = true,
    })
    -- All or nothing. A note on one side without its mirror is worse than no note,
    -- because it silently misaligns the diff the author is reading.
    if ok_scratch and ok_source then
      count = count + 1
    else
      pcall(vim.api.nvim_buf_clear_namespace, scratch, ns, row, row + 1)
      pcall(vim.api.nvim_buf_clear_namespace, bufnr, ns, row, row + 1)
    end
  end

  vim.api.nvim_win_set_cursor(scratch_win, { 1, 0 })
  vim.api.nvim_win_call(scratch_win, function()
    -- Land on the first hunk so `do` is immediately meaningful.
    pcall(vim.cmd, "normal! ]c")
  end)

  ---@type LevelDiffState
  local state = {
    source_buf = bufnr,
    scratch_buf = scratch,
    source_win = source_win,
    scratch_win = scratch_win,
    ns = ns,
    count = count,
    closed = false,
  }

  -- Teardown on any route out, not only the close command. Without this, closing the
  -- scratch buffer by a path this plugin does not own leaves the real buffer stuck in
  -- diff mode, which reads as a broken editor rather than as a leftover.
  vim.api.nvim_create_autocmd({ "BufWipeout", "BufUnload" }, {
    buffer = scratch,
    once = true,
    callback = function()
      M.close(state)
    end,
  })

  return state
end

---@param state LevelDiffState|nil
---@return boolean closed True if this call did the teardown
function M.close(state)
  if not state or state.closed then
    return false
  end
  state.closed = true

  for _, win in ipairs({ state.source_win, state.scratch_win }) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_call(win, function()
        pcall(vim.cmd, "diffoff")
      end)
    end
  end

  for _, buf in ipairs({ state.source_buf, state.scratch_buf }) do
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_clear_namespace, buf, state.ns, 0, -1)
    end
  end

  if vim.api.nvim_buf_is_valid(state.scratch_buf) then
    pcall(vim.api.nvim_buf_delete, state.scratch_buf, { force = true })
  end

  return true
end

M._NOTE_WIDTH = NOTE_WIDTH
return M
```

- [ ] **Step 4: Run to verify it passes**

Expected: PASS, 10 successes.

Two likely stumbles. If the `buftype` assertion reads awkwardly, simplify it to `assert.equals("nofile", vim.bo[state.scratch_buf].buftype)`. If `close` reports the source window still in diff mode, check that `bufhidden = "wipe"` did not already fire the `BufWipeout` autocmd and mark the state closed before the explicit call; that is the behavior the idempotence test pins.

- [ ] **Step 5: Run the whole suite**

Expected: **345 passing, 0 failed, 0 errors**.

- [ ] **Step 6: Commit**

```bash
git -C ~/.dotfiles add nvim/.config/nvim/lua/albertlint/level/diffview.lua \
                        nvim/.config/nvim/tests/albertlint/level_diffview_spec.lua
git -C ~/.dotfiles commit -m "feat(nvim): render a level pass as a native two-window diff

Native diff mode rather than a hand-built review buffer, so ]c, [c, do,
and dp already are the navigation and the per-hunk accept and reject.
There is no apply code here to get wrong.

The mirrored blank virtual lines are the part that will look like dead
code. Diff mode aligns two windows with filler lines it computes itself,
while virt_lines add screen rows to one window only. Measured 2026-09-08
on a five-line pair with one note on the right buffer: line 3 sat at
screen row 4 on the right and row 3 on the left, so everything below the
note was out of alignment. An equal count of blanks on the other side
restores it exactly, and a test pins the two counts as equal.

Notes are placed all-or-nothing per finding. A note on one side without
its mirror is worse than no note, because it silently misaligns the diff
the author is reading.

Teardown runs on BufWipeout and BufUnload as well as on the close call,
because closing the scratch buffer by any route this plugin does not own
would otherwise leave the real buffer stuck in diff mode."
```

---

### Task 5: the runner, the config, and the commands

**Files:**
- Create: `lua/albertlint/level/init.lua`
- Test: `tests/albertlint/level_init_spec.lua`
- Modify: `lua/albertlint/config.lua` (add the `level` block to `defaults`, after the `semantic` block that ends around line 68)
- Modify: `lua/albertlint/init.lua` (register commands in `M.setup`, extend the `AlbertLintReload` module list, extend `AlbertLintStatus`)

**Interfaces:**
- Consumes: `levels.prompt`, `levels.get`, `provider.call`, `apply.build`, `diffview.open`, `diffview.close`, `semantic._scope_range`
- Produces:
  - `level.run(id: integer, use_selection: boolean)`
  - `level.close(bufnr: integer|nil) -> boolean`
  - `level.cancel(bufnr: integer|nil) -> boolean`
  - `level._numbered(lines: string[], start_lnum: integer) -> string`
  - `level._in_flight: table<integer, table>`

- [ ] **Step 1: Write the failing test**

Create `tests/albertlint/level_init_spec.lua`:

```lua
---The runner's own logic: payload construction, the in-flight guard, and config wiring.
---
---The network call itself is not tested here; `provider` covers argv and parsing, and a
---headless test must not spend money. What is tested is everything around it, including the
---in-flight guard, which exists because without one a second invocation spawns a second CLI
---process: two paid calls and two sets of results racing. That failure already happened once
---in the semantic tier.
local level = require("albertlint.level")
local config = require("albertlint.config")

describe("level payload", function()
  it("numbers lines with absolute buffer line numbers", function()
    -- Absolute, so the model's answer needs no offset arithmetic and a fix from a
    -- selection-scoped pass still points at the right buffer line.
    local out = level._numbered({ "first", "second" }, 41)

    assert.equals("41: first\n42: second\n", out)
  end)

  it("handles an empty range without erroring", function()
    assert.equals("", level._numbered({}, 1))
  end)
end)

describe("level config", function()
  it("defaults to the claude provider and buffer scope", function()
    config.setup({})

    local opts = config.get().level
    assert.equals("claude", opts.provider)
    -- A two-window diff over a single paragraph is not worth the split.
    assert.equals("buffer", opts.scope)
    assert.is_true(opts.enabled)
  end)

  it("lets the provider be overridden", function()
    config.setup({ level = { provider = "openai" } })

    assert.equals("openai", config.get().level.provider)
    -- The override must not wipe the sibling defaults.
    assert.equals("buffer", config.get().level.scope)

    config.setup({})
  end)
end)

describe("level in-flight guard", function()
  before_each(function()
    for k in pairs(level._in_flight) do
      level._in_flight[k] = nil
    end
  end)

  it("refuses a second pass on the same buffer", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a error" })
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_win_set_buf(0, buf)

    level._in_flight[buf] = {
      handle = nil,
      started = (vim.uv or vim.loop).hrtime(),
      lines = 1,
      level = 1,
    }

    local notified = {}
    local orig = vim.notify
    vim.notify = function(msg, lvl)
      table.insert(notified, { msg = msg, level = lvl })
    end

    level.run(1, false)

    vim.notify = orig
    assert.equals(1, #notified)
    assert.is_true(notified[1].msg:find("already running", 1, true) ~= nil)
  end)

  it("reports an unknown level rather than calling out", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "a error" })
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_win_set_buf(0, buf)

    local notified = {}
    local orig = vim.notify
    vim.notify = function(msg)
      table.insert(notified, msg)
    end

    level.run(3, false)

    vim.notify = orig
    assert.equals(1, #notified)
    assert.is_true(notified[1]:find("level 3", 1, true) ~= nil)
    assert.is_nil(level._in_flight[buf])
  end)
end)

describe("level close", function()
  it("says so when there is nothing open", function()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_win_set_buf(0, buf)

    assert.is_false(level.close(buf))
  end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL, `module 'albertlint.level' not found`.

- [ ] **Step 3a: Add the config block**

In `lua/albertlint/config.lua`, inside `defaults`, immediately after the closing `},` of the `semantic = { ... }` block, add:

```lua
  ---@class AlbertLintLevelConfig
  ---@field enabled boolean
  ---@field provider string "claude" | "openai"
  ---@field scope string "paragraph" | "buffer" | "selection"
  ---@field timeout_ms integer
  ---@field model string|nil Provider-specific model override
  level = {
    enabled = true,

    -- "claude" needs no credential in this process: the CLI already holds one. "openai"
    -- reads OPENAI_API_KEY from the environment and is otherwise equivalent, with the
    -- advantage that a strict json_schema makes a malformed response impossible.
    provider = "claude",

    -- "buffer" rather than the semantic tier's "paragraph". A two-window diff over one
    -- paragraph is not worth the split. An explicit `:'<,'>` range still wins.
    scope = "buffer",

    -- Larger than the semantic tier's 60s because a level pass over a whole buffer sends
    -- considerably more text than a paragraph-scoped pass.
    timeout_ms = 90000,

    -- nil means the provider's own default: sonnet for claude (see provider.lua for why
    -- that is pinned). For openai, provider.lua falls back to "gpt-4o". That string is
    -- NOT verified against OpenAI's current lineup as of 2026-09-08 -- set it explicitly
    -- if the call comes back with an unknown-model error.
    model = nil,
  },
```

Also extend the class annotation on `AlbertLintConfig`, after the `semantic` field:

```lua
---@field level AlbertLintLevelConfig
```

- [ ] **Step 3b: Write the runner**

Create `lua/albertlint/level/init.lua`:

```lua
---Graded review levels, on demand.
---
---One command per level, each answering a different question, so feedback arrives in an
---order the author can absorb rather than all at once. Level 1 is grammar and usage; see
---`levels.lua` for the ladder and `docs/superpowers/specs/2026-09-08-albertlint-graded-levels-design.md`
---for why the model returns spans rather than a rewrite.
---
---On demand only, like the semantic tier. Nothing here runs on a keystroke: it shells out,
---it takes tens of seconds, and it costs money.
local apply = require("albertlint.level.apply")
local config = require("albertlint.config")
local diffview = require("albertlint.level.diffview")
local levels = require("albertlint.level.levels")
local provider = require("albertlint.level.provider")
local semantic = require("albertlint.semantic")

local M = {}

---Passes currently running, keyed by buffer.
---
---The semantic tier learned this the expensive way: with no guard, a second invocation
---spawned a second CLI process, which meant two paid calls and two sets of results racing
---to overwrite each other with no way to tell. The guard also answers the liveness question
---for free, since running the command again while one is in flight reports how long it has
---been going instead of silently doubling the bill.
---@type table<integer, { handle: table|nil, started: number, lines: integer, level: integer }>
local in_flight = {}

---Diff views currently open, keyed by source buffer.
---@type table<integer, table>
local open_views = {}

---@param started integer Nanoseconds from vim.uv.hrtime
---@return string
local function elapsed(started)
  return ("%.0fs"):format(((vim.uv or vim.loop).hrtime() - started) / 1e9)
end

---@param lines string[]
---@param start_lnum integer 1-indexed
---@return string
function M._numbered(lines, start_lnum)
  local out = {}
  for i, line in ipairs(lines) do
    table.insert(out, ("%d: %s"):format(start_lnum + i - 1, line))
  end
  if #out == 0 then
    return ""
  end
  return table.concat(out, "\n") .. "\n"
end

---@param id integer
---@param use_selection boolean
function M.run(id, use_selection)
  local opts = config.get().level
  if not opts.enabled then
    vim.notify("albertlint: the level tiers are disabled in config", vim.log.levels.WARN)
    return
  end

  local def = levels.get(id)
  local prompt = levels.prompt(id)
  if not def or not prompt then
    vim.notify(
      ("albertlint: level %s is not implemented yet. Only level 1 (grammar/usage) has a command; "
        .. "see levels.lua for the planned ladder."):format(tostring(id)),
      vim.log.levels.WARN
    )
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()

  local running = in_flight[bufnr]
  if running then
    vim.notify(
      ("albertlint: a level %d pass is already running here (%s elapsed, %d lines). "
        .. ":AlbertLintLevelCancel to stop it."):format(running.level, elapsed(running.started), running.lines),
      vim.log.levels.WARN
    )
    return
  end

  -- One view per buffer. A second diff over the same buffer would stack diffthis windows
  -- and leave the author with no clear way back.
  if open_views[bufnr] then
    M.close(bufnr)
  end

  local start_lnum, end_lnum, scope_name
  if use_selection then
    start_lnum = vim.fn.line("'<") - 1
    end_lnum = vim.fn.line("'>")
    scope_name = "selection"
  else
    local warning
    start_lnum, end_lnum, warning = semantic._scope_range(bufnr, opts.scope)
    scope_name = warning and "paragraph" or (opts.scope or "buffer")
    if warning then
      vim.notify("albertlint: " .. warning, vim.log.levels.WARN)
    end
  end

  local range_lines = vim.api.nvim_buf_get_lines(bufnr, start_lnum, end_lnum, false)
  local payload = M._numbered(range_lines, start_lnum + 1)
  if payload == "" then
    vim.notify("albertlint: nothing to review in that range", vim.log.levels.INFO)
    return
  end

  vim.notify(
    ("albertlint: level %d (%s) over %d lines (%s scope), ~30-90s. Run again to check progress.")
      :format(def.id, def.name, #range_lines, scope_name),
    vim.log.levels.INFO
  )

  local started = (vim.uv or vim.loop).hrtime()
  local handle = provider.call(opts.provider, prompt, payload, {
    timeout_ms = opts.timeout_ms,
    model = opts.model,
  }, function(res)
    -- Cleared on every path, so a failed, timed-out, or cancelled pass cannot wedge the
    -- guard and lock this buffer out of running again.
    in_flight[bufnr] = nil

    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    if not res.ok then
      vim.notify(
        ("albertlint: level %d pass failed, so nothing changed. Run it again. (%s)")
          :format(def.id, tostring(res.err)),
        vim.log.levels.ERROR
      )
      return
    end

    -- The whole buffer, not the range: the scratch copy is diffed against the real buffer,
    -- and a range-only array would make every untouched line read as a deletion.
    local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local corrected, placed, dropped = apply.build(all_lines, 1, res.findings or {})

    if #placed == 0 then
      -- Zero has to read as a verdict, not as a no-op. "0 findings" on its own is
      -- indistinguishable from "the tool did not really run", which misled the author for
      -- a real reason once in the semantic tier.
      local msg = ("albertlint: level %d found nothing to fix in %d lines (%s scope, %s)")
        :format(def.id, #range_lines, scope_name, elapsed(started))
      if #dropped > 0 then
        msg = msg .. (". %d result%s could not be attached, because the text moved or was quoted "
          .. "inexactly; run the check again to place %s.")
          :format(#dropped, #dropped == 1 and "" or "s", #dropped == 1 and "it" or "them")
      end
      vim.notify(msg, vim.log.levels.INFO)
      return
    end

    open_views[bufnr] = diffview.open(bufnr, corrected, placed, { level = def.id })

    local msg = ("albertlint: level %d, %d fix%s in %d lines (%s scope, %s). "
      .. "]c next, do accept, dp reject, :AlbertLintLevelClose when done.")
      :format(def.id, #placed, #placed == 1 and "" or "es", #range_lines, scope_name, elapsed(started))
    if #dropped > 0 then
      msg = msg .. (" %d could not be attached; run the check again to place %s.")
        :format(#dropped, #dropped == 1 and "it" or "them")
    end
    vim.notify(msg, vim.log.levels.INFO)
  end)

  if handle then
    in_flight[bufnr] = { handle = handle, started = started, lines = #range_lines, level = def.id }
  end
end

---@param bufnr integer|nil
---@return boolean
function M.close(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local state = open_views[bufnr]
  if not state then
    vim.notify("albertlint: no level diff open for this buffer", vim.log.levels.INFO)
    return false
  end
  open_views[bufnr] = nil
  diffview.close(state)
  return true
end

---@param bufnr integer|nil
---@return boolean
function M.cancel(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local running = in_flight[bufnr]
  if not running then
    vim.notify("albertlint: no level pass running on this buffer", vim.log.levels.INFO)
    return false
  end
  -- The in-flight record is cleared by the completion callback rather than here, because
  -- killing still delivers one.
  if running.handle then
    pcall(function()
      running.handle:kill("sigterm")
    end)
  end
  vim.notify(
    ("albertlint: level %d pass cancelled after %s"):format(running.level, elapsed(running.started)),
    vim.log.levels.INFO
  )
  return true
end

M._in_flight = in_flight
M._open_views = open_views
return M
```

- [ ] **Step 3c: Register the commands**

In `lua/albertlint/init.lua`, in `M.setup`, immediately after the `AlbertLintSemanticCancel` command block, add:

```lua
  vim.api.nvim_create_user_command("AlbertLintLevel1", function(cmd)
    require("albertlint.level").run(1, cmd.range > 0)
  end, { range = true, desc = "albertlint: level 1 (grammar/usage) as a reviewable diff" })

  vim.api.nvim_create_user_command("AlbertLintLevelClose", function()
    require("albertlint.level").close()
  end, { desc = "albertlint: close the level diff and leave diff mode" })

  vim.api.nvim_create_user_command("AlbertLintLevelCancel", function()
    require("albertlint.level").cancel()
  end, { desc = "albertlint: stop the level pass running in this buffer" })
```

In the same file, extend the `AlbertLintReload` module list. It currently reads:

```lua
    for _, mod in ipairs({
      "albertlint.rules",
      "albertlint.engine",
      "albertlint.semantic",
      "albertlint.config",
      "albertlint.collocation.index",
    }) do
```

Add the five level modules, so edits to them are picked up without a restart:

```lua
    for _, mod in ipairs({
      "albertlint.rules",
      "albertlint.engine",
      "albertlint.semantic",
      "albertlint.config",
      "albertlint.collocation.index",
      -- The level tier, for the same reason `semantic` is on this list: a fix that
      -- cannot be reloaded by the command called Reload costs a restart to test.
      "albertlint.level",
      "albertlint.level.apply",
      "albertlint.level.levels",
      "albertlint.level.provider",
      "albertlint.level.diffview",
    }) do
```

And in `AlbertLintStatus`, after the `semantic:` line in the `lines` table, add:

```lua
      ("level: %s, provider %s, scope %s, timeout %dms"):format(
        cfg.level.enabled and "enabled" or "disabled",
        cfg.level.provider,
        cfg.level.scope,
        cfg.level.timeout_ms
      ),
```

- [ ] **Step 4: Run the new test**

Expected: PASS, 7 successes.

- [ ] **Step 5: Run the whole suite**

Expected: **352 passing, 0 failed, 0 errors**.

- [ ] **Step 6: Manual smoke test**

This is the first point at which the feature can actually be exercised, and the `do`/`dp` ergonomics are inferred rather than observed, so run it for real:

```bash
cd ~/.dotfiles/nvim/.config/nvim
printf 'which takes the text and use LLM.\n\nit should focus on grammar/expression error.\n' > /tmp/level1-smoke.md
nvim /tmp/level1-smoke.md
```

Then, in Neovim: `:AlbertLintLevel1`, wait for the notify, and check each of these:

1. Two windows appear, the right one named `albertlint://level1/level1-smoke.md`.
2. Notes appear above the changed lines on the right, and the two windows stay **line-aligned** (put the cursor on the last line in each window and compare `:echo screenrow()`).
3. `]c` jumps to a hunk, `do` accepts it into the left buffer, `u` undoes it.
4. `:AlbertLintLevelClose` leaves the left buffer with `:echo &diff` printing `0` and no leftover virtual lines.
5. Run `:AlbertLintLevel1` twice quickly; the second reports "already running".

Record any ergonomic surprise; the spec's open item 1 predicts this step may send the surface back for revision.

- [ ] **Step 7: Commit**

```bash
git -C ~/.dotfiles add nvim/.config/nvim/lua/albertlint/level/init.lua \
                        nvim/.config/nvim/tests/albertlint/level_init_spec.lua \
                        nvim/.config/nvim/lua/albertlint/config.lua \
                        nvim/.config/nvim/lua/albertlint/init.lua
git -C ~/.dotfiles commit -m "feat(nvim): wire up :AlbertLintLevel1

The runner reuses semantic.scope_range rather than forking it, and
carries over the two lessons that tier paid for. A per-buffer in-flight
guard, because without one a second invocation spawned a second CLI
process: two paid calls and two result sets racing. And zero reads as a
verdict rather than a no-op, naming the line count and scope, because
\"0 findings\" alone is indistinguishable from \"it did not really run\"
and misled the author once for a real reason.

apply.build gets the whole buffer, not just the reviewed range. The
scratch copy is diffed against the real buffer, so a range-only array
would make every untouched line read as a deletion.

Default scope is buffer rather than the semantic tier's paragraph: a
two-window diff over one paragraph is not worth the split. Timeout is
90s rather than 60s because a whole-buffer pass sends much more text.

All five level modules are added to AlbertLintReload, for the reason
semantic is on that list: a fix the Reload command cannot pick up costs
a restart to test."
```

---

### Task 6: record the doctrine exception

Without this the next agent reads the 2026-08-28 constraint, finds a feature that violates it, and removes it as a bug. This is the task that makes the change survive.

**Files:**
- Modify: `CLAUDE.md` (the section headed "The hard constraint on AI-generated prose help")
- Modify: `lua/albertlint/README.md`

- [ ] **Step 1: Amend `CLAUDE.md`**

In `CLAUDE.md`, at the end of the "The hard constraint on AI-generated prose help" section, after the existing bulleted "Consequences already encoded, do not undo them" list, add:

```markdown
**Scoped exception, decided 2026-09-08: the graded level commands.** `:AlbertLintLevel1` shows
replacement prose in a diff with an accept key (`do`), which the constraint above rules out. The
author was shown the conflict, restated the requirement as "review and decide accept/reject by
hunk", and confirmed it. This is recorded because the constraint is written forcefully enough
that an agent reading only it would classify the feature as a bug and delete it.

The exception is narrow. It covers the `:AlbertLintLevel*` commands only. The live, exit, and
semantic tiers keep the no-autofix rule, `copilot_gate.lua` still blocks Copilot from markdown,
and the collocation source still caps a surface at five words. Do not widen it.

What the original reasoning got right and the design preserves: the danger is *unattributed*
replacement prose arriving in bulk. Level 1 answers that structurally rather than by refusing to
show a fix. The model returns labeled spans, not a rewritten paragraph, so a reorder or a tone
change is unrepresentable rather than merely forbidden, and every hunk traces to one named
finding. See `docs/superpowers/specs/2026-09-08-albertlint-graded-levels-design.md` §2 and §4.

If the accept key turns out to be used reflexively, the rejected alternative to revisit is the
retype gate (spec §2), not a return to annotations-only.
```

- [ ] **Step 2: Update the state-of-play table**

In `CLAUDE.md`, in the "State of play" table, add a row:

```markdown
| `albertlint/level/` | **level 1 done.** Grammar/usage pass rendered as a native diff. Levels 2-4 are data rows only |
```

Two stale numbers in the same file are worth correcting while you are here, both verified 2026-09-08:

- The test count reads `275 tests as of 2026-09-01`. It is 352 after this change.
- The coverage note cites the article pattern at 121 instances. The fix log's drill row says 129.

- [ ] **Step 3: Document the command**

In `lua/albertlint/README.md`, add a section covering `:AlbertLintLevel1`, `:AlbertLintLevelClose`, and `:AlbertLintLevelCancel`: what level 1 covers, that `]c`/`do`/`dp` are the navigation and accept/reject, that the notes are virtual text, that `provider` picks between `claude` and `openai`, and that `openai` needs `OPENAI_API_KEY` in the environment. Match the file's existing tone and heading depth.

- [ ] **Step 4: Run the whole suite one more time**

Expected: **352 passing, 0 failed, 0 errors**. Docs-only changes must not move the number.

- [ ] **Step 5: Commit**

```bash
git -C ~/.dotfiles add nvim/.config/nvim/CLAUDE.md nvim/.config/nvim/lua/albertlint/README.md
git -C ~/.dotfiles commit -m "docs(nvim): record the scoped exception to the no-autofix doctrine

The hard constraint says the AI may produce only annotations, never
replacement prose, because a diff hunk has a one-keystroke accept path.
:AlbertLintLevel1 has exactly that. The author was shown the conflict,
restated the requirement as accept/reject by hunk, and confirmed it.

Written down because the constraint is forceful enough that an agent
reading only it would find this feature and delete it as a bug. The
exception is narrow and says so: the level commands only, with the other
three tiers, the Copilot gate, and the five-word collocation cap all
explicitly unchanged.

Also corrects two stale numbers verified today: the test count said 275
as of 2026-09-01 and is now 352, and the coverage note cited the article
pattern at 121 instances where the drill row says 129."
```

---

## Self-Review

**Spec coverage.** Walked every numbered section of the spec against the tasks:

| Spec | Task |
|---|---|
| §1 goal, ladder table | Task 2 (`levels.lua`) |
| §2 doctrine amendment | Task 6 |
| §3 module layout, no-symlink note | Tasks 1-5, Global Constraints |
| §4 spans not rewrite, `occurrence` | Task 1 |
| §4.1 right-to-left, overlap | Task 1, steps 1 and 3 |
| §4.2 byte offsets | Task 1, multibyte test |
| §5.1 claude flags, model pin | Task 3 |
| §5.1 semantic.lua observation | Deliberately not actioned; spec §10 says raise, not fix |
| §5.2 openai, credential handling | Task 3 |
| §6 diff view | Task 4 |
| §6.1 mirrored notes | Task 4, the mirror test |
| §6.2 scope default `buffer` | Task 5, step 3a |
| §6.3 teardown | Task 4 |
| §7 error handling, zero-as-verdict | Task 5 |
| §8 testing matrix | Tasks 1-5 |
| §9 prompt and ignore list | Task 2 |
| §10 out of scope | Respected; no task adds a level 2-4 command |
| §11 open items | Task 5 step 6 is the manual check open item 1 asks for |

No gaps found.

**Placeholder scan.** No `TBD`, no `TODO`, no "add appropriate error handling", no "similar to Task N". Every code step carries the real code. Task 6 step 3 describes the README section rather than dictating its prose, which is a judgment call about matching an existing document's voice, not a placeholder: the required content is enumerated.

**Type consistency.** Checked the names across task boundaries:

- `apply.build` returns `corrected, placed, dropped` in Task 1 and is called with exactly that arity in Task 5.
- `Placed` fields are `fix`, `lnum`, `col` in Task 1, and Task 4's `diffview.open` reads `item.lnum` and `item.fix.label` / `item.fix.note`. Consistent.
- `apply.note_lines(label, note, width)` in Task 1, called with three arguments in Task 4. Consistent.
- `provider.call(name, prompt, text, opts, cb)` in Task 3, called with that arity in Task 5. The callback receives `{ ok, findings, err }` in both.
- `diffview.open(bufnr, corrected, placed, opts)` returns `State` with `ns`, `count`, `source_win`, `scratch_buf`; Task 4's tests and Task 5's runner both use those names.
- `levels.get` and `levels.prompt` both take an id and both return nil for an unimplemented level, and Task 5 checks both before proceeding.

One fix applied during review: Task 5's test asserted on `level._in_flight`, so Task 5's implementation exports it as `M._in_flight`, matching `semantic.lua`'s existing `M._in_flight` convention.

## Notes carried forward

Two things the executor should not silently resolve:

1. **RESOLVED 2026-09-08, after this plan was written:** the model was pinned by measurement (`gpt-5.5`); see the table in `provider.lua`. `gpt-4o` scored zero findings on two runs of three, so the concern below was justified and is now closed. Original note, kept as the record: **The openai model string `"gpt-4o"` is a guess.** I cannot verify OpenAI's current model lineup, so it is a config default with a comment saying so, not a verified value. If the first `openai` call returns an unknown-model error, that is expected; set `level.model` explicitly rather than treating it as a bug in the provider.
2. **Nothing here measures precision.** Every test is recall on text known to be broken. The spec's §10 planned check, a pass over the fix log's `After:` column that should return nothing, is not in this plan and is not claimed.
