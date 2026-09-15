import { test } from "node:test";
import assert from "node:assert/strict";

import {
  appendEntry,
  composeEntry,
  newNoteContent,
  replaceLine,
  DriftError,
} from "./write.ts";

const NOTE = [
  "---",
  "tags:",
  "  - quick-ref",
  "---",
  "# Git",
  "",
  "## Rebase",
  "- squash three",
  "",
].join("\n");

test("appends under the matching section heading", () => {
  const out = appendEntry(NOTE, {
    section: "Rebase",
    text: "- `git rebase --abort` bail out",
  });

  assert.equal(out.split("\n")[8], "- `git rebase --abort` bail out");
});

test("appends after the last entry of the section, not directly under the heading", () => {
  const two = [
    "---",
    "tags:",
    "  - quick-ref",
    "---",
    "## A",
    "- one",
    "- two",
    "## B",
    "- three",
  ].join("\n");

  const out = appendEntry(two, { section: "A", text: "- four" });

  assert.deepEqual(out.split("\n").slice(4, 8), [
    "## A",
    "- one",
    "- two",
    "- four",
  ]);
});

test("appends at the end of the note when the section does not exist", () => {
  const out = appendEntry(NOTE, {
    section: "Bisect",
    text: "- `git bisect start`",
  });

  assert.deepEqual(out.trimEnd().split("\n").slice(-3), [
    "## Bisect",
    "",
    "- `git bisect start`",
  ]);
});

test("appends at the end of the note when no section is given", () => {
  const out = appendEntry(NOTE, { text: "- loose entry" });

  assert.equal(out.trimEnd().split("\n").pop(), "- loose entry");
});

test("leaves the file ending in exactly one newline", () => {
  const out = appendEntry(NOTE, { text: "- loose entry" });

  assert.ok(out.endsWith("\n"));
  assert.ok(!out.endsWith("\n\n"));
});

test("matches a section heading regardless of its depth", () => {
  const deep = [
    "---",
    "tags:",
    "  - quick-ref",
    "---",
    "### Rebase",
    "- one",
  ].join("\n");

  const out = appendEntry(deep, { section: "Rebase", text: "- two" });

  assert.deepEqual(out.trimEnd().split("\n").slice(-2), ["- one", "- two"]);
});

test("replaces the line when the raw text still matches", () => {
  const out = replaceLine(NOTE, {
    line: 8,
    expectedRaw: "- squash three",
    text: "- squash the last three",
  });

  assert.equal(out.split("\n")[7], "- squash the last three");
});

test("refuses to replace when the line drifted, naming file and line", () => {
  assert.throws(
    () =>
      replaceLine(NOTE, {
        line: 8,
        expectedRaw: "- something else",
        text: "- new",
        file: "/notes/git.md",
      }),
    (error: unknown) => {
      assert.ok(error instanceof DriftError);
      assert.match(error.message, /\/notes\/git\.md/);
      assert.match(error.message, /line 8/);
      return true;
    },
  );
});

test("refuses to replace a line past the end of the file", () => {
  assert.throws(
    () =>
      replaceLine(NOTE, {
        line: 999,
        expectedRaw: "- squash three",
        text: "- x",
      }),
    DriftError,
  );
});

test("preserves every other line when replacing", () => {
  const out = replaceLine(NOTE, {
    line: 8,
    expectedRaw: "- squash three",
    text: "- squash the last three",
  });
  const before = NOTE.split("\n");
  const after = out.split("\n");

  assert.equal(before.length, after.length);
  assert.deepEqual(after.slice(0, 7), before.slice(0, 7));
});

test("creates a new note carrying the tag and the topic as its H1", () => {
  const out = newNoteContent("Kubernetes", "quick-ref");

  assert.match(out, /^---\n/);
  assert.match(out, /^tags:\n {2}- quick-ref$/m);
  assert.match(out, /^# Kubernetes$/m);
  assert.ok(out.endsWith("\n"));
});

test("a new note is immediately parseable as a tagged note", async () => {
  const { parseNote } = await import("./parse.ts");
  const content = appendEntry(newNoteContent("Kubernetes", "quick-ref"), {
    text: "- `kubectl get pods -A`",
  });

  const note = parseNote("/notes/Kubernetes.md", content, "quick-ref");

  assert.equal(note?.topic, "Kubernetes");
  assert.equal(note?.entries[0]?.copyText, "kubectl get pods -A");
});

test("composes a plain bullet when there is no description", () => {
  assert.equal(
    composeEntry({ text: "a rebase rewrites every commit hash" }),
    "- a rebase rewrites every commit hash",
  );
});

test("backticks the payload when a description is given, so the split round-trips", async () => {
  const { parseNote } = await import("./parse.ts");
  const line = composeEntry({
    text: "git rebase -i HEAD~3",
    description: "squash the last three",
  });

  const content = ["---", "tags:", "  - quick-ref", "---", line].join("\n");
  const entry = parseNote("/n.md", content, "quick-ref")?.entries[0];

  assert.equal(entry?.copyText, "git rebase -i HEAD~3");
  assert.equal(entry?.description, "squash the last three");
});

test("a plain entry round-trips as its own payload", async () => {
  const { parseNote } = await import("./parse.ts");
  const content = [
    "---",
    "tags:",
    "  - quick-ref",
    "---",
    composeEntry({ text: "plain fact" }),
  ].join("\n");

  assert.equal(
    parseNote("/n.md", content, "quick-ref")?.entries[0]?.copyText,
    "plain fact",
  );
});

test("trims the fields before composing", () => {
  assert.equal(
    composeEntry({ text: "  ls -la  ", description: "  list all  " }),
    "- `ls -la` list all",
  );
});

test("rejects a payload holding a backtick, which would break the split", () => {
  assert.throws(
    () => composeEntry({ text: "echo `date`", description: "today" }),
    /backtick/i,
  );
});

test("allows a backtick when there is no description to delimit", () => {
  assert.equal(composeEntry({ text: "echo `date`" }), "- echo `date`");
});

test("rejects empty text", () => {
  assert.throws(() => composeEntry({ text: "   " }), /empty/i);
});
