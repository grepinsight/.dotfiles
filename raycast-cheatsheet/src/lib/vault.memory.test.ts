import { test } from "node:test";
import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { mkdtemp, mkdir, writeFile, access } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { promisify } from "node:util";

const run = promisify(execFile);
// Resolved from the package root, where `npm test` runs. Not via
// import.meta.dirname, which tsc rejects under `module: commonjs`.
const VAULT_MODULE = resolve(process.cwd(), "src/lib/vault.ts");

/**
 * Raycast runs each command in a worker with a capped heap, so a scan whose
 * peak memory scales with the whole folder crashes the command outright:
 * "Worker terminated due to reaching memory limit: JS heap out of memory".
 * Measured on a real 13,455-note folder, holding every file at once peaked at
 * 141 MB of heap to produce 10 entries.
 *
 * This runs the scan in a child capped well below the corpus size. Streaming
 * passes; accumulating cannot.
 */
test("scans a folder larger than the heap it is given", async () => {
  await access(VAULT_MODULE).catch(() => {
    assert.fail(
      `Cannot find ${VAULT_MODULE}. Run this from the extension root, as \`npm test\` does.`,
    );
  });

  const root = await mkdtemp(join(tmpdir(), "cheatsheet-mem-"));
  const filler =
    "lorem ipsum dolor sit amet consectetur adipiscing elit. ".repeat(420); // ~24 KB
  const untagged = [
    "---",
    "tags:",
    "  - other",
    "---",
    "# Note",
    "",
    filler,
  ].join("\n");

  await mkdir(join(root, "notes"), { recursive: true });
  await Promise.all(
    Array.from({ length: 2000 }, (_, i) =>
      writeFile(join(root, "notes", `n${i}.md`), untagged, "utf-8"),
    ),
  );
  await writeFile(
    join(root, "kept.md"),
    [
      "---",
      "tags:",
      "  - quick-ref",
      "---",
      "# Kept",
      "- one",
      "- two",
      "",
    ].join("\n"),
    "utf-8",
  );

  const runner = join(root, "runner.ts");
  await writeFile(
    runner,
    `const { scan } = await import(${JSON.stringify(VAULT_MODULE)});\n` +
      `const { entries } = await scan(${JSON.stringify(root)}, "quick-ref");\n` +
      `console.log(entries.length);\n`,
    "utf-8",
  );

  // 2000 x 24 KB is roughly 47 MB of one-byte strings against a 32 MB heap, so
  // holding the corpus cannot fit while one 64-file batch (about 1.5 MB) has
  // room to spare. Calibrated against the real failure rather than guessed: an
  // earlier 1200-file, 48 MB version passed even while accumulating, because
  // V8 stores ASCII as one byte per character and 29 MB stayed under the cap.
  const { stdout } = await run(
    process.execPath,
    ["--max-old-space-size=32", runner],
    {
      maxBuffer: 1024 * 1024,
    },
  );

  assert.equal(stdout.trim(), "2");
});
