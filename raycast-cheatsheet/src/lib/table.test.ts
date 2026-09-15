import { test } from "node:test";
import assert from "node:assert/strict";

import { parseNote } from "./parse.ts";

const TAG = "quick-ref";
const note = (...body: string[]) =>
  ["---", "tags:", `  - ${TAG}`, "---", ...body].join("\n");
const entriesOf = (...body: string[]) =>
  parseNote("/n.md", note(...body), TAG)?.entries ?? [];

test("indexes a table's data rows and neither its header nor its separator", () => {
  const entries = entriesOf(
    "| Flag | What it does |",
    "| --- | --- |",
    "| `--depth N` | how many levels down to walk |",
    "| `--json` | machine-readable output |",
  );

  assert.deepEqual(
    entries.map((e) => e.copyText),
    ["--depth N", "--json"],
  );
});

test("takes the description from the remaining cell", () => {
  const entries = entriesOf(
    "| Flag | Means |",
    "| --- | --- |",
    "| `--json` | no colour |",
  );

  assert.equal(entries[0]?.description, "no colour");
});

test("marks a table row as its own kind", () => {
  const entries = entriesOf(
    "| Flag | Means |",
    "| --- | --- |",
    "| `--json` | no colour |",
  );

  assert.equal(entries[0]?.kind, "table");
  assert.equal(entries[0]?.isCode, true);
});

test("accepts alignment colons in the separator", () => {
  const entries = entriesOf(
    "| Flag | Means |",
    "| :--- | ---: |",
    "| `--json` | no colour |",
  );

  assert.equal(entries.length, 1);
});

test("keeps a prose first cell whole when its code span does not lead", () => {
  const entries = entriesOf(
    "| Symptom | Cause |",
    "| --- | --- |",
    "| Columns truncated with `…` | terminal width |",
  );

  assert.equal(entries[0]?.copyText, "Columns truncated with `…`");
  assert.equal(entries[0]?.description, "terminal width");
  assert.equal(entries[0]?.isCode, false);
});

test("does not truncate a payload at a pipe escaped inside a code span", () => {
  // Codex's case. In GFM a backtick does NOT protect a table pipe, so the author
  // writes \|. Splitting naively yields `printf x`, which looks fine and is wrong.
  const entries = entriesOf(
    "| Command | Means |",
    "| --- | --- |",
    "| `printf x \\| cat` | pipes it |",
  );

  assert.equal(entries[0]?.copyText, "printf x | cat");
  assert.equal(entries[0]?.description, "pipes it");
});

test("reads a third column into the description rather than dropping the row", () => {
  const entries = entriesOf(
    "| Flag | Default | Means |",
    "| --- | --- | --- |",
    "| `--depth` | 1 | levels to walk |",
  );

  assert.equal(entries[0]?.copyText, "--depth");
  assert.equal(entries[0]?.description, "1 · levels to walk");
});

test("skips a row whose first cell is empty", () => {
  const entries = entriesOf(
    "| Flag | Means |",
    "| --- | --- |",
    "|  | orphaned |",
    "| `--json` | ok |",
  );

  assert.deepEqual(
    entries.map((e) => e.copyText),
    ["--json"],
  );
});

test("does not treat a pipe table inside a fence as a table", () => {
  const entries = entriesOf(
    "```markdown",
    "| Flag | Means |",
    "| --- | --- |",
    "| `--json` | x |",
    "```",
  );

  assert.equal(entries.length, 1);
  assert.equal(entries[0]?.kind, "block");
});

test("does not treat a lone pipe-containing prose line as a table", () => {
  const entries = entriesOf(
    "- a `|` pipe in prose",
    "some | prose | with pipes and no separator",
  );

  assert.deepEqual(
    entries.map((e) => e.kind),
    ["line"],
  );
});

test("carries the section and line number like any other entry", () => {
  const entries = entriesOf(
    "## Flags",
    "| Flag | Means |",
    "| --- | --- |",
    "| `--json` | no colour |",
  );

  assert.equal(entries[0]?.section, "Flags");
  assert.equal(entries[0]?.line, 8);
});

test("handles a table written without outer pipes", () => {
  const entries = entriesOf(
    "Flag | Means",
    "--- | ---",
    "`--json` | no colour",
  );

  assert.equal(entries[0]?.copyText, "--json");
});

test("skips entries under a navigation heading", () => {
  const entries = entriesOf(
    "## Flags",
    "- `--json` keep me",
    "## Related",
    "- [[Some Other Note]]",
    "- ~/src/somewhere/",
    "| Link | Why |",
    "| --- | --- |",
    "| [[Another]] | context |",
  );

  assert.deepEqual(
    entries.map((e) => e.copyText),
    ["--json"],
  );
});

test("resumes indexing after a navigation heading ends", () => {
  const entries = entriesOf(
    "## Related",
    "- [[Ignored]]",
    "## Flags",
    "- `--json` kept",
  );

  assert.deepEqual(
    entries.map((e) => e.copyText),
    ["--json"],
  );
});
