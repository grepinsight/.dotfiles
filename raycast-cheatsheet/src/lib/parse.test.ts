import { test } from "node:test";
import assert from "node:assert/strict";

import { parseNote } from "./parse.ts";

const TAG = "quick-ref";

test("skips a note whose frontmatter lacks the tag", () => {
  const content = [
    "---",
    "tags:",
    "  - other",
    "---",
    "# Git",
    "",
    "- `git status`",
  ].join("\n");

  assert.equal(parseNote("/notes/git.md", content, TAG), null);
});

test("skips a note with no frontmatter at all", () => {
  assert.equal(
    parseNote("/notes/git.md", "# Git\n\n- `git status`\n", TAG),
    null,
  );
});

test("reads the tag from an inline frontmatter list", () => {
  const content = [
    "---",
    "tags: [quick-ref, git]",
    "---",
    "# Git",
    "- `git status`",
  ].join("\n");

  const note = parseNote("/notes/git.md", content, TAG);

  assert.equal(note?.entries.length, 1);
});

test("takes the topic from the H1", () => {
  const content = [
    "---",
    "tags:",
    "  - quick-ref",
    "---",
    "# Git Commands",
    "- `git status`",
  ].join("\n");

  assert.equal(parseNote("/notes/g.md", content, TAG)?.topic, "Git Commands");
});

test("falls back to the filename when there is no H1", () => {
  const content = [
    "---",
    "tags:",
    "  - quick-ref",
    "---",
    "- `git status`",
  ].join("\n");

  assert.equal(
    parseNote("/notes/Git Commands.md", content, TAG)?.topic,
    "Git Commands",
  );
});

test("indexes list items and ignores headings, prose and frontmatter", () => {
  const content = [
    "---",
    "tags:",
    "  - quick-ref",
    "---",
    "# Git",
    "",
    "Some prose that explains things.",
    "",
    "## Rebase",
    "",
    "- squash the last three",
    "* star bullet",
    "1. numbered bullet",
    "",
  ].join("\n");

  const texts = parseNote("/notes/git.md", content, TAG)?.entries.map(
    (e) => e.text,
  );

  assert.deepEqual(texts, [
    "squash the last three",
    "star bullet",
    "numbered bullet",
  ]);
});

test("records the nearest heading above as the section", () => {
  const content = [
    "---",
    "tags:",
    "  - quick-ref",
    "---",
    "# Git",
    "- loose entry",
    "## Rebase",
    "- inside rebase",
  ].join("\n");

  const entries = parseNote("/notes/git.md", content, TAG)?.entries ?? [];

  assert.equal(entries[0]?.section, undefined);
  assert.equal(entries[1]?.section, "Rebase");
});

test("copies the backticked span when the line has one", () => {
  const content = [
    "---",
    "tags:",
    "  - quick-ref",
    "---",
    "- `git rebase -i HEAD~3` squash the last three commits",
  ].join("\n");

  const entry = parseNote("/notes/git.md", content, TAG)?.entries[0];

  assert.equal(entry?.copyText, "git rebase -i HEAD~3");
  assert.equal(
    entry?.text,
    "`git rebase -i HEAD~3` squash the last three commits",
  );
  assert.equal(entry?.description, "squash the last three commits");
});

test("copies the whole line when there is no backticked span", () => {
  const content = [
    "---",
    "tags:",
    "  - quick-ref",
    "---",
    "- a rebase rewrites every commit hash",
  ].join("\n");

  const entry = parseNote("/notes/n.md", content, TAG)?.entries[0];

  assert.equal(entry?.copyText, "a rebase rewrites every commit hash");
});

test("treats a whole fenced block as one entry, fences excluded", () => {
  const content = [
    "---",
    "tags:",
    "  - quick-ref",
    "---",
    "## Kube",
    "```bash",
    "kubectl get pods -A \\",
    "  --field-selector status.phase=Running",
    "```",
  ].join("\n");

  const entries = parseNote("/notes/k.md", content, TAG)?.entries ?? [];

  assert.equal(entries.length, 1);
  assert.equal(entries[0]?.kind, "block");
  assert.equal(
    entries[0]?.copyText,
    "kubectl get pods -A \\\n  --field-selector status.phase=Running",
  );
  assert.equal(entries[0]?.section, "Kube");
});

test("a block entry preserves indentation and internal blank lines", () => {
  const content = [
    "---",
    "tags:",
    "  - quick-ref",
    "---",
    "```",
    "first",
    "",
    "    indented",
    "```",
  ].join("\n");

  const entry = parseNote("/notes/k.md", content, TAG)?.entries[0];

  assert.equal(entry?.copyText, "first\n\n    indented");
});

test("a block entry shows its first line and counts the rest", () => {
  const content = [
    "---",
    "tags:",
    "  - quick-ref",
    "---",
    "```",
    "one",
    "two",
    "three",
    "```",
  ].join("\n");

  const entry = parseNote("/notes/k.md", content, TAG)?.entries[0];

  assert.equal(entry?.text, "one");
  assert.equal(entry?.lineCount, 3);
  assert.equal(entry?.line, 6);
});

test("does not let a mid-line code span hijack the clipboard", () => {
  const content = [
    "---",
    "tags:",
    "  - quick-ref",
    "---",
    "- never use `--force` on a shared branch",
  ].join("\n");

  const entry = parseNote("/notes/n.md", content, TAG)?.entries[0];

  assert.equal(entry?.copyText, "never use `--force` on a shared branch");
  assert.equal(entry?.description, undefined);
});

test("splits a leading code span into payload and description", () => {
  const content = [
    "---",
    "tags:",
    "  - quick-ref",
    "---",
    "- `git rebase -i HEAD~3` - squash the last three commits",
  ].join("\n");

  const entry = parseNote("/notes/g.md", content, TAG)?.entries[0];

  assert.equal(entry?.copyText, "git rebase -i HEAD~3");
  assert.equal(entry?.description, "squash the last three commits");
});

test("strips a colon or dash separator after a leading code span", () => {
  const content = [
    "---",
    "tags:",
    "  - quick-ref",
    "---",
    "- `ls -la`: list everything",
  ].join("\n");

  assert.equal(
    parseNote("/notes/g.md", content, TAG)?.entries[0]?.description,
    "list everything",
  );
});

test("takes the first span when a line leads with one and holds more", () => {
  const content = [
    "---",
    "tags:",
    "  - quick-ref",
    "---",
    "- `a` then `b`",
  ].join("\n");

  const entry = parseNote("/notes/g.md", content, TAG)?.entries[0];

  assert.equal(entry?.copyText, "a");
  assert.equal(entry?.description, "then `b`");
});

test("marks an ordinary bullet as a line entry", () => {
  const content = ["---", "tags:", "  - quick-ref", "---", "- plain"].join(
    "\n",
  );

  assert.equal(
    parseNote("/notes/g.md", content, TAG)?.entries[0]?.kind,
    "line",
  );
});

test("records a 1-indexed line number and the raw line", () => {
  const content = [
    "---",
    "tags:",
    "  - quick-ref",
    "---",
    "# Git",
    "- `git status`",
  ].join("\n");

  const entry = parseNote("/notes/git.md", content, TAG)?.entries[0];

  assert.equal(entry?.line, 6);
  assert.equal(entry?.raw, "- `git status`");
});

test("gives every entry a distinct id carrying file and line", () => {
  const content = [
    "---",
    "tags:",
    "  - quick-ref",
    "---",
    "- one",
    "- two",
  ].join("\n");

  const entries = parseNote("/notes/git.md", content, TAG)?.entries ?? [];

  assert.equal(entries[0]?.id, "/notes/git.md:5");
  assert.equal(entries[1]?.id, "/notes/git.md:6");
});
