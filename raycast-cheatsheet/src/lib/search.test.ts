import { test } from "node:test";
import assert from "node:assert/strict";

import { matchEntries } from "./search.ts";
import { parseNote } from "./parse.ts";

const NOTE = [
  "---",
  "tags:",
  "  - quick-ref",
  "---",
  "# Git",
  "",
  "## Deleting merged branches",
  "- `git branch --merged main` list branches whose tip is an ancestor of main",
  "- `git branch -d <branch>` lowercase -d refuses to delete unmerged work",
  "- `git fetch --prune` drop remote-tracking refs whose upstream was deleted",
  "",
  "## Inspecting",
  "- `git diff --staged` what a commit would contain right now",
  "- `git blame -L 40,60 <file>` who last touched a specific line range",
  "- never rebase a branch someone else has already pulled",
].join("\n");

const ENTRIES = parseNote("/notes/git.md", NOTE, "quick-ref")!.entries;
const payloads = (query: string) =>
  matchEntries(ENTRIES, query).map((e) => e.copyText);

test("finds a command from what it does, not from its name", () => {
  assert.ok(payloads("delete branch").includes("git branch -d <branch>"));
});

test("a term that matches nothing does not empty the result", () => {
  // Strict AND was the first spec, and it made "already merged" return nothing
  // because "already" appears in no entry. Typing a natural phrase is exactly
  // how reverse lookup gets used, so one unmatched word must not be fatal.
  assert.ok(payloads("already merged").length >= 2);
});

test("ranks entries matching every term above those matching fewer", () => {
  const ranked = matchEntries(ENTRIES, "delete merged");
  const both = ranked.findIndex(
    (e) => e.copyText === "git branch --merged main",
  );
  const one = ranked.findIndex((e) => e.copyText === "git diff --staged");

  assert.ok(both !== -1, "the entry matching both terms is present");
  assert.ok(
    one === -1 || both < one,
    "it outranks anything matching fewer terms",
  );
});

test("still excludes an entry matching none of the terms", () => {
  assert.deepEqual(payloads("kubernetes helm"), []);
});

test("matches terms across different fields, ranking the both-term hit first", () => {
  // "inspecting" is the section, "staged" is in the payload.
  assert.equal(payloads("inspecting staged")[0], "git diff --staged");
});

test("matches the section a term only appears in", () => {
  assert.ok(payloads("merged").length >= 2);
});

test("ranks a payload match above a description-only match", () => {
  const ranked = payloads("prune");

  assert.equal(ranked[0], "git fetch --prune");
});

test("ranks an exact payload first even when others contain the term", () => {
  const ranked = payloads("git diff --staged");

  assert.equal(ranked[0], "git diff --staged");
});

test("is case-insensitive", () => {
  assert.deepEqual(payloads("DELETE BRANCH"), payloads("delete branch"));
});

test("ignores extra whitespace between terms", () => {
  assert.deepEqual(payloads("  delete   branch  "), payloads("delete branch"));
});

test("returns everything, in note order, for an empty query", () => {
  assert.deepEqual(matchEntries(ENTRIES, "   "), ENTRIES);
});

test("finds a prose entry by its own words", () => {
  assert.ok(
    payloads("rebase someone else").some((p) => p.startsWith("never rebase")),
  );
});

test("treats a hyphenated flag as searchable", () => {
  assert.ok(payloads("--prune").includes("git fetch --prune"));
});

test("does not match a term that appears nowhere", () => {
  assert.deepEqual(payloads("kubernetes"), []);
});

test("a description match at a word start outranks one inside a word", () => {
  // "who" sits mid-word in "whose upstream was deleted" and at a word start in
  // "who last touched". Only the second is what the searcher meant.
  const ranked = matchEntries(ENTRIES, "who");

  assert.equal(ranked[0]?.copyText, "git blame -L 40,60 <file>");
});

test("still finds a term inside a longer word", () => {
  // "prun" must keep reaching "--prune", so mid-word matches count, just less.
  assert.ok(matchEntries(ENTRIES, "prun").length >= 1);
});
