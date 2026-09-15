import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, writeFile, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { appendToNote, createNote, editEntry, scan } from "./vault.ts";

const TAG = "quick-ref";

async function vault(files: Record<string, string>): Promise<string> {
  const root = await mkdtemp(join(tmpdir(), "cheatsheet-"));
  for (const [name, content] of Object.entries(files)) {
    const path = join(root, name);
    await mkdir(join(path, ".."), { recursive: true });
    await writeFile(path, content, "utf-8");
  }
  return root;
}

const tagged = (topic: string, ...lines: string[]) =>
  ["---", "tags:", `  - ${TAG}`, "---", `# ${topic}`, ...lines, ""].join("\n");

test("collects entries from tagged notes anywhere under the root", async () => {
  const root = await vault({
    "git.md": tagged("Git", "- `git status`"),
    "nested/deep/kube.md": tagged("Kube", "- `kubectl get pods`"),
  });

  const { entries } = await scan(root, TAG);

  assert.deepEqual(entries.map((e) => e.copyText).sort(), [
    "git status",
    "kubectl get pods",
  ]);
});

test("ignores notes without the tag", async () => {
  const root = await vault({
    "in.md": tagged("In", "- kept"),
    "out.md": ["---", "tags:", "  - other", "---", "- dropped"].join("\n"),
    "bare.md": "- no frontmatter at all\n",
  });

  const { entries } = await scan(root, TAG);

  assert.deepEqual(
    entries.map((e) => e.copyText),
    ["kept"],
  );
});

test("ignores non-markdown files and dot-directories", async () => {
  const root = await vault({
    "keep.md": tagged("Keep", "- kept"),
    "notes.txt": tagged("Txt", "- dropped"),
    ".obsidian/plugins/cache.md": tagged("Cache", "- dropped"),
    "node_modules/pkg/readme.md": tagged("Pkg", "- dropped"),
  });

  const { entries } = await scan(root, TAG);

  assert.deepEqual(
    entries.map((e) => e.copyText),
    ["kept"],
  );
});

test("reports the notes it found so a picker can list them", async () => {
  const root = await vault({
    "git.md": tagged("Git", "- one"),
    "kube.md": tagged("Kubernetes", "- two"),
  });

  const { notes } = await scan(root, TAG);

  assert.deepEqual(notes.map((n) => n.topic).sort(), ["Git", "Kubernetes"]);
});

test("returns nothing rather than throwing when the root does not exist", async () => {
  const { entries, notes } = await scan(
    join(tmpdir(), "cheatsheet-does-not-exist-9e1"),
    TAG,
  );

  assert.deepEqual(entries, []);
  assert.deepEqual(notes, []);
});

test("appends an entry to an existing note and it shows up on the next scan", async () => {
  const root = await vault({
    "git.md": tagged("Git", "## Rebase", "- squash three"),
  });
  const file = join(root, "git.md");

  await appendToNote(file, {
    section: "Rebase",
    text: "- `git rebase --abort` bail out",
  });
  const { entries } = await scan(root, TAG);

  const added = entries.find((e) => e.copyText === "git rebase --abort");
  assert.equal(added?.section, "Rebase");
  assert.equal(added?.description, "bail out");
});

test("creates a tagged note from a topic name and returns its path", async () => {
  const root = await vault({});

  const file = await createNote(root, "Kubernetes Basics", TAG);
  await appendToNote(file, { text: "- `kubectl get pods`" });
  const { entries } = await scan(root, TAG);

  assert.equal(file, join(root, "Kubernetes Basics.md"));
  assert.equal(entries[0]?.topic, "Kubernetes Basics");
});

test("refuses to create a note that already exists", async () => {
  const root = await vault({ "Git.md": tagged("Git", "- one") });

  await assert.rejects(() => createNote(root, "Git", TAG), /already exists/);
});

test("edits an entry in place, leaving the rest of the note alone", async () => {
  const root = await vault({
    "git.md": tagged("Git", "- squash three", "- other entry"),
  });
  const { entries } = await scan(root, TAG);
  const target = entries.find((e) => e.copyText === "squash three")!;

  await editEntry(target, "- squash the last three");
  const after = await readFile(join(root, "git.md"), "utf-8");

  assert.match(after, /^- squash the last three$/m);
  assert.match(after, /^- other entry$/m);
});

test("refuses an edit when the note changed underneath", async () => {
  const root = await vault({ "git.md": tagged("Git", "- squash three") });
  const { entries } = await scan(root, TAG);
  const target = entries[0]!;

  await writeFile(
    join(root, "git.md"),
    tagged("Git", "- someone else edited this"),
    "utf-8",
  );

  await assert.rejects(
    () => editEntry(target, "- squash the last three"),
    /changed on disk/,
  );
});

test("refuses to edit a fenced block in place and says to open the note", async () => {
  const root = await vault({
    "k.md": [
      "---",
      "tags:",
      `  - ${TAG}`,
      "---",
      "# Kube",
      "```bash",
      "kubectl get pods",
      "```",
      "",
    ].join("\n"),
  });
  const { entries } = await scan(root, TAG);

  assert.equal(entries[0]?.kind, "block");
  await assert.rejects(() => editEntry(entries[0]!, "x"), /open the note/);
});
