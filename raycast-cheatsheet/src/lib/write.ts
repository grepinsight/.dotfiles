/**
 * Writing side of the cheatsheet: string in, string out.
 *
 * The caller owns the filesystem, so every function here is pure and the tests
 * in `write.test.ts` never touch disk. `replaceLine` takes the line it expects
 * to find and refuses the edit when the file moved underneath it, which is the
 * one hazard of editing a note the user also opens in a markdown editor.
 */

const HEADING = /^(#{1,6})[ \t]+(.*)$/;
const FENCE = /^[ \t]*(?:```|~~~)/;

/** Raised when the line on disk is not the line the edit was based on. */
export class DriftError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "DriftError";
  }
}

function headingTitle(line: string): string | null {
  const heading = HEADING.exec(line);
  if (!heading) return null;
  return (heading[2] ?? "").trim();
}

/** Index of the heading line for `section`, at any depth, or -1. */
function findSection(lines: string[], section: string): number {
  const wanted = section.trim().toLowerCase();
  return lines.findIndex(
    (line) => headingTitle(line)?.toLowerCase() === wanted,
  );
}

/**
 * Index one past the last content line belonging to the section that starts at
 * `headingAt`, so a new entry lands after the section's existing entries rather
 * than jumping the queue directly under the heading.
 */
function endOfSection(lines: string[], headingAt: number): number {
  let last = headingAt;
  let inFence = false;

  for (let i = headingAt + 1; i < lines.length; i++) {
    const line = lines[i] ?? "";
    if (FENCE.test(line)) {
      inFence = !inFence;
      last = i;
      continue;
    }
    if (!inFence && HEADING.test(line)) break;
    if (line.trim()) last = i;
  }
  return last + 1;
}

function withSingleTrailingNewline(lines: string[]): string {
  while (lines.length > 0 && (lines[lines.length - 1] ?? "").trim() === "")
    lines.pop();
  return lines.join("\n") + "\n";
}

export type AppendOptions = {
  /** Heading to file the entry under. A missing section is created at the end. */
  section?: string;
  /** The entry line, bullet included. Written verbatim. */
  text: string;
};

/** The note's content with one entry added. */
export function appendEntry(
  content: string,
  { section, text }: AppendOptions,
): string {
  const lines = content.split(/\r?\n/);

  if (!section) {
    return withSingleTrailingNewline([...lines, text]);
  }

  const headingAt = findSection(lines, section);
  if (headingAt === -1) {
    return withSingleTrailingNewline([...lines, "", `## ${section}`, "", text]);
  }

  const at = endOfSection(lines, headingAt);
  return withSingleTrailingNewline([
    ...lines.slice(0, at),
    text,
    ...lines.slice(at),
  ]);
}

export type ReplaceOptions = {
  /** 1-indexed, as carried on an Entry. */
  line: number;
  /** The raw line the edit was based on. */
  expectedRaw: string;
  /** The replacement line, bullet included. */
  text: string;
  /** Only used to name the file in a DriftError. */
  file?: string;
};

/**
 * The note's content with one line replaced.
 *
 * @throws DriftError when the line is gone or no longer matches `expectedRaw`.
 */
export function replaceLine(
  content: string,
  { line, expectedRaw, text, file }: ReplaceOptions,
): string {
  const lines = content.split(/\r?\n/);
  const at = line - 1;
  const found = lines[at];
  const where = file ? `${file}, line ${line}` : `line ${line}`;

  if (found === undefined) {
    throw new DriftError(
      `${where} no longer exists. The note changed on disk, so the edit was not applied.`,
    );
  }
  if (found !== expectedRaw) {
    throw new DriftError(
      `${where} no longer matches what was read.\n\nExpected: ${expectedRaw}\nFound:    ${found}\n\n` +
        "The note changed on disk, so the edit was not applied. Reload and try again.",
    );
  }

  lines[at] = text;
  return lines.join("\n");
}

/** A fresh note, tagged so the next scan picks it up, with the topic as its H1. */
export function newNoteContent(topic: string, tag: string): string {
  return ["---", "tags:", `  - ${tag}`, "---", "", `# ${topic}`, ""].join("\n");
}

export type ComposeOptions = {
  /** What the entry should copy. */
  text: string;
  /** Optional prose explaining it. */
  description?: string;
};

/**
 * Build the markdown line for a new or edited entry.
 *
 * The inverse of `splitPayload`. A description has to be delimited from the
 * payload somehow, and backticks are exactly the delimiter the parser reads, so
 * a described entry is written as `` - `payload` description ``. Without a
 * description there is nothing to delimit and the line stays plain markdown,
 * which is what keeps a prose entry from looking like code.
 */
export function composeEntry({ text, description }: ComposeOptions): string {
  const payload = text.trim();
  const note = (description ?? "").trim();

  if (!payload) throw new Error("An entry cannot be empty.");
  if (!note) return `- ${payload}`;
  if (payload.includes("`")) {
    throw new Error(
      "Remove the backtick from the text, or clear the description. " +
        "A description is delimited with backticks, so a backtick in the text would split it in the wrong place.",
    );
  }

  return `- \`${payload}\` ${note}`;
}
