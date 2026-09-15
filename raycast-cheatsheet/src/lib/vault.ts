/**
 * Filesystem layer: the only module here that touches disk.
 *
 * Everything it does is a thin wrapper over `parse.ts` and `write.ts`, so the
 * tests in `vault.test.ts` run against real files in a temp directory rather
 * than against mocks.
 */

import { readdir, readFile, writeFile, access } from "node:fs/promises";
import { join } from "node:path";

import { parseNote, type Entry, type Note } from "./parse.ts";
import {
  appendEntry,
  replaceLine,
  newNoteContent,
  type AppendOptions,
} from "./write.ts";

/** Directories that never hold notes and are expensive to walk. */
const SKIP_DIRS = new Set([
  "node_modules",
  ".git",
  ".obsidian",
  ".trash",
  ".stversions",
]);

/** Open file handles allowed at once. Bounded to stay clear of EMFILE. */
const READ_CONCURRENCY = 64;

export type ScanResult = {
  entries: Entry[];
  notes: Note[];
};

async function markdownFiles(root: string): Promise<string[]> {
  let listing;
  try {
    listing = await readdir(root, { withFileTypes: true });
  } catch {
    // A missing or unreadable folder is a configuration problem, surfaced by the
    // caller as an empty list plus a hint, not as a crash on every keystroke.
    return [];
  }

  const found: string[] = [];
  const directories: string[] = [];

  for (const item of listing) {
    if (item.name.startsWith(".") || SKIP_DIRS.has(item.name)) continue;
    const path = join(root, item.name);
    if (item.isDirectory()) directories.push(path);
    else if (item.isFile() && item.name.toLowerCase().endsWith(".md"))
      found.push(path);
  }

  const nested = await Promise.all(directories.map(markdownFiles));
  return found.concat(...nested);
}

/**
 * Read every file, up to READ_CONCURRENCY at a time.
 *
 * Measured on a 13,455-note folder: one after another took 2,613ms, 64 at a
 * time took 316ms. The work is IO latency, not CPU, so the only thing
 * sequential reads buy is a stall. The cap is what keeps it clear of EMFILE.
 */
async function readAll(
  files: string[],
): Promise<Array<{ file: string; content: string }>> {
  const out: Array<{ file: string; content: string }> = [];

  for (let i = 0; i < files.length; i += READ_CONCURRENCY) {
    const batch = await Promise.all(
      files.slice(i, i + READ_CONCURRENCY).map(async (file) => {
        try {
          return { file, content: await readFile(file, "utf-8") };
        } catch {
          // An unreadable note is skipped rather than failing the whole scan.
          return null;
        }
      }),
    );
    for (const item of batch) if (item) out.push(item);
  }
  return out;
}

/** Every entry in every tagged note under `root`. */
export async function scan(root: string, tag: string): Promise<ScanResult> {
  const files = await markdownFiles(root);
  const notes: Note[] = [];

  for (const { file, content } of await readAll(files)) {
    const note = parseNote(file, content, tag);
    if (note) notes.push(note);
  }

  notes.sort((a, b) => a.topic.localeCompare(b.topic));
  return { entries: notes.flatMap((note) => note.entries), notes };
}

/** Add one entry to an existing note. */
export async function appendToNote(
  file: string,
  options: AppendOptions,
): Promise<void> {
  const content = await readFile(file, "utf-8");
  await writeFile(file, appendEntry(content, options), "utf-8");
}

/** Create a tagged note named after `topic` and return its path. */
export async function createNote(
  root: string,
  topic: string,
  tag: string,
): Promise<string> {
  const safe = topic.trim().replace(/[/\\:]/g, "-");
  if (!safe) throw new Error("A new topic needs a name.");

  const file = join(root, `${safe}.md`);
  try {
    await access(file);
    throw new Error(
      `A note named "${safe}.md" already exists. Pick it from the topic list instead.`,
    );
  } catch (error) {
    if (error instanceof Error && error.message.includes("already exists"))
      throw error;
  }

  await writeFile(file, newNoteContent(safe, tag), {
    encoding: "utf-8",
    flag: "wx",
  });
  return file;
}

/**
 * Replace the line an entry came from.
 *
 * @throws DriftError when the note changed since the entry was read, so an edit
 * based on a stale read never silently overwrites someone else's line.
 */
export async function editEntry(entry: Entry, text: string): Promise<void> {
  // A block entry spans several lines, and replaceLine swaps exactly one. Rather
  // than half-rewrite a fenced command, send the user to the note.
  if (entry.kind === "block") {
    throw new Error(
      "Code blocks are edited in the note itself. Use Open Source Note to open the note.",
    );
  }

  const content = await readFile(entry.file, "utf-8");
  const next = replaceLine(content, {
    line: entry.line,
    expectedRaw: entry.raw,
    text,
    file: entry.file,
  });
  await writeFile(entry.file, next, "utf-8");
}
