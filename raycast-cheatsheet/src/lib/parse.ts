/**
 * Reading side of the cheatsheet: a tagged markdown note in, a flat list of
 * copyable entries out.
 *
 * Pure on purpose. Nothing here touches the filesystem or Raycast, so the whole
 * contract is exercised by `parse.test.ts` and `table.test.ts` with plain
 * strings.
 */

export type EntryKind = "line" | "block" | "table";

export type Entry = {
  /** Stable list key. `file:line` survives a reload as long as the line does. */
  id: string;
  kind: EntryKind;
  /** The entry's full text: the bullet's content, or a block's first line. */
  text: string;
  /**
   * Exactly what Enter puts on the clipboard, and exactly what the row shows as
   * its title. Those two being the same string is the point: a launcher that
   * copies something other than what it displays is a trap.
   */
  copyText: string;
  /** The prose after a leading code span, or a table row's other cells. */
  description?: string;
  /** Whether the payload is code rather than prose. Drives highlighting. */
  isCode: boolean;
  /** The fence's info string or the note's declared language, lowercased. */
  language?: string;
  /** The note's H1, else its filename. */
  topic: string;
  /** Nearest `##` or deeper above the entry. Absent above the first one. */
  section?: string;
  file: string;
  /** 1-indexed, counted over the whole file including frontmatter. */
  line: number;
  /** Lines the entry spans. Always 1 except for a fenced block. */
  lineCount: number;
  /** The entry exactly as it sits on disk, which is what an edit checks against. */
  raw: string;
};

export type Note = {
  file: string;
  topic: string;
  /**
   * The note's own `language:` frontmatter key, lowercased. Lets one cheatsheet
   * be SQL and another shell without a global setting that is wrong for one of
   * them. A fence's own info string still wins inside the note.
   */
  language?: string;
  entries: Entry[];
};

const FRONTMATTER = /^---[ \t]*\r?\n([\s\S]*?)\r?\n---[ \t]*(?:\r?\n|$)/;
const TAGS_KEY = /^tags[ \t]*:/;
const YAML_ITEM = /^[ \t]*-[ \t]+(.*)$/;
const BULLET = /^[ \t]*(?:[-*+]|\d+[.)])[ \t]+(.*)$/;
const HEADING = /^(#{1,6})[ \t]+(.*)$/;
const FENCE = /^[ \t]*(?:```|~~~)[ \t]*(\S*)/;
/** A code span only counts when it LEADS the text. See splitPayload. */
const LEADING_SPAN = /^`([^`\n]+)`[ \t]*(.*)$/;
const SEPARATOR = /^[-–—:,.)\]]+[ \t]*/;
/** A table separator cell: dashes, optionally with alignment colons. */
const SEPARATOR_CELL = /^:?-+:?$/;

/**
 * Headings whose content points elsewhere instead of being usable itself.
 *
 * A bare wiki-link or a bare path under one of these is navigation, not a
 * cheatsheet entry, and indexing it puts an uncopyable row in the results. The
 * note's own structure declares the intent, which beats guessing from syntax:
 * a link is a perfectly good payload anywhere else.
 */
const NAVIGATION_HEADINGS = new Set([
  "related",
  "see also",
  "links",
  "references",
  "further reading",
]);

function unquote(value: string): string {
  // Trimmed on both sides of the quote strip: `"  Python  "` has whitespace
  // outside the quotes and inside them, and only the second pass catches the
  // inner pair.
  return value
    .trim()
    .replace(/^["']|["']$/g, "")
    .trim();
}

/**
 * The tags of a note's YAML frontmatter, or null when it has no frontmatter.
 *
 * Deliberately not a YAML parser. Only the three shapes a note gets written in
 * by hand are understood: a block list, an inline flow list, and a bare scalar.
 * Anything else reads as untagged, which fails closed: the note is skipped
 * rather than half-indexed.
 */
export function frontmatterTags(content: string): string[] | null {
  const block = FRONTMATTER.exec(content);
  if (!block) return null;

  const lines = (block[1] ?? "").split(/\r?\n/);
  const at = lines.findIndex((line) => TAGS_KEY.test(line));
  if (at === -1) return [];

  const inline = lines[at]!.replace(TAGS_KEY, "").trim();

  if (inline.startsWith("[")) {
    return inline
      .replace(/^\[/, "")
      .replace(/\]$/, "")
      .split(",")
      .map(unquote)
      .filter(Boolean);
  }
  if (inline) return [unquote(inline)];

  const items: string[] = [];
  for (const line of lines.slice(at + 1)) {
    const item = YAML_ITEM.exec(line);
    if (!item) break;
    items.push(unquote(item[1] ?? ""));
  }
  return items;
}

/** A scalar value from the frontmatter, lowercased and unquoted. */
export function frontmatterScalar(
  content: string,
  key: string,
): string | undefined {
  const block = FRONTMATTER.exec(content);
  if (!block) return undefined;

  const matcher = new RegExp(`^${key}[ \\t]*:(.*)$`);
  for (const line of (block[1] ?? "").split(/\r?\n/)) {
    const hit = matcher.exec(line);
    if (hit) return unquote(hit[1] ?? "").toLowerCase() || undefined;
  }
  return undefined;
}

/** How many leading lines the frontmatter block occupies, 0 when there is none. */
function frontmatterLineCount(content: string): number {
  const block = FRONTMATTER.exec(content);
  if (!block) return 0;
  return block[0].replace(/\r?\n$/, "").split(/\r?\n/).length;
}

function basename(file: string): string {
  const last = file.split("/").pop() ?? file;
  return last.replace(/\.md$/i, "");
}

/**
 * Split a bullet or a table cell into what gets copied and what merely explains
 * it.
 *
 * The code span has to LEAD the text. An earlier version took the first span
 * anywhere, which quietly turned `never use \`--force\` on a shared branch` into
 * a clipboard holding `--force`: the copy inverted the sentence that warned
 * against it. A span mid-sentence is prose, so the whole text is the payload.
 */
export function splitPayload(text: string): {
  payload: string;
  description?: string;
} {
  const span = LEADING_SPAN.exec(text);
  if (!span) return { payload: text };

  const rest = (span[2] ?? "").replace(SEPARATOR, "").trim();
  return { payload: span[1] ?? "", description: rest || undefined };
}

/**
 * Split a table row into trimmed cells.
 *
 * Splits on UNESCAPED pipes only, and turns `\|` into a literal pipe. In GFM a
 * backtick does not protect a pipe inside a table cell, so an author writing a
 * shell pipeline in a cell has to escape it. Splitting naively turns
 * `` `printf x \| cat` `` into the payload `printf x`, which is the worst kind
 * of bug: the result looks like a valid command and silently does something
 * else.
 *
 * Outer pipes are optional, since `Flag | Means` is a valid GFM header.
 */
export function tableCells(row: string): string[] {
  const cells: string[] = [];
  let current = "";

  for (let i = 0; i < row.length; i++) {
    const character = row[i]!;
    if (character === "\\" && row[i + 1] === "|") {
      current += "|";
      i++;
      continue;
    }
    if (character === "|") {
      cells.push(current);
      current = "";
      continue;
    }
    current += character;
  }
  cells.push(current);

  if (cells.length > 1 && cells[0]!.trim() === "") cells.shift();
  if (cells.length > 1 && cells[cells.length - 1]!.trim() === "") cells.pop();

  return cells.map((cell) => cell.trim());
}

/** Is this row a table's `| --- | :---: |` separator? */
function isSeparatorRow(row: string): boolean {
  if (!row.includes("|") && !row.includes("-")) return false;
  const cells = tableCells(row);
  return cells.length > 0 && cells.every((cell) => SEPARATOR_CELL.test(cell));
}

/**
 * Is `row` a table header, i.e. is the line after it a separator?
 *
 * Detecting the separator rather than the header is what keeps ordinary prose
 * containing a pipe from being read as a table.
 */
function startsTable(row: string, next: string | undefined): boolean {
  return row.includes("|") && next !== undefined && isSeparatorRow(next);
}

type Cursor = { topic: string; section?: string; file: string };

function lineEntry(
  raw: string,
  content: string,
  line: number,
  at: Cursor,
): Entry {
  const { payload, description } = splitPayload(content);
  return {
    id: `${at.file}:${line}`,
    kind: "line",
    text: content,
    copyText: payload,
    description,
    // The payload differing from the whole line means splitPayload found a
    // leading span, which is the only thing that marks a bullet as code.
    isCode: payload !== content,
    topic: at.topic,
    section: at.section,
    file: at.file,
    line,
    lineCount: 1,
    raw,
  };
}

function tableEntry(
  raw: string,
  cells: string[],
  line: number,
  at: Cursor,
): Entry | null {
  const first = cells[0] ?? "";
  if (!first) return null;

  const { payload, description } = splitPayload(first);
  // Every cell past the first explains the payload. Joined rather than dropped:
  // discarding a column to avoid discarding context is self-defeating.
  const rest = [description, ...cells.slice(1)].filter((cell) =>
    Boolean(cell && cell.trim()),
  );

  return {
    id: `${at.file}:${line}`,
    kind: "table",
    text: first,
    copyText: payload,
    description: rest.length > 0 ? rest.join(" · ") : undefined,
    isCode: payload !== first,
    topic: at.topic,
    section: at.section,
    file: at.file,
    line,
    lineCount: 1,
    raw,
  };
}

/**
 * Index one note. Returns null when the note is not tagged, which is how the
 * caller filters a whole folder without a second pass over the frontmatter.
 */
export function parseNote(
  file: string,
  content: string,
  tag: string,
): Note | null {
  const tags = frontmatterTags(content);
  if (!tags || !tags.includes(tag)) return null;

  const lines = content.split(/\r?\n/);
  const start = frontmatterLineCount(content);
  const declared = frontmatterScalar(content, "language");

  const at: Cursor = { topic: basename(file), file };
  let topicFromHeading = false;
  let underNavigation = false;
  const entries: Entry[] = [];

  for (let i = start; i < lines.length; i++) {
    const raw = lines[i] ?? "";
    const line = i + 1;

    // A fenced block is ONE entry. Indexing its lines separately would hand the
    // clipboard half of a continued command. Checked before tables, so a pipe
    // table shown as an example inside a fence stays an example.
    const fence = FENCE.exec(raw);
    if (fence) {
      const language = (fence[1] ?? "").trim().toLowerCase() || undefined;
      const body: string[] = [];
      let j = i + 1;
      for (; j < lines.length && !FENCE.test(lines[j] ?? ""); j++)
        body.push(lines[j] ?? "");

      while (body.length > 0 && (body[0] ?? "").trim() === "") body.shift();
      while (body.length > 0 && (body[body.length - 1] ?? "").trim() === "")
        body.pop();

      if (body.length > 0 && !underNavigation) {
        const block = body.join("\n");
        entries.push({
          id: `${file}:${i + 2}`,
          kind: "block",
          text: (body[0] ?? "").trim(),
          copyText: block,
          description: body.length > 1 ? `${body.length} lines` : undefined,
          isCode: true,
          language,
          topic: at.topic,
          section: at.section,
          file,
          line: i + 2,
          lineCount: body.length,
          raw: block,
        });
      }
      i = j;
      continue;
    }

    const heading = HEADING.exec(raw);
    if (heading) {
      const depth = heading[1]!.length;
      const title = (heading[2] ?? "").trim();
      underNavigation = NAVIGATION_HEADINGS.has(title.toLowerCase());

      if (depth === 1) {
        if (!topicFromHeading) {
          at.topic = title;
          topicFromHeading = true;
        }
        at.section = undefined;
      } else {
        at.section = title;
      }
      continue;
    }

    if (startsTable(raw, lines[i + 1])) {
      // Skip the header and the separator structurally, by knowing where the
      // table began, rather than by pattern-matching each row.
      for (let j = i + 2; j < lines.length; j++) {
        const row = lines[j] ?? "";
        if (!row.includes("|") || HEADING.test(row) || !row.trim()) {
          i = j - 1;
          break;
        }
        if (!underNavigation) {
          const entry = tableEntry(row, tableCells(row), j + 1, at);
          if (entry) entries.push(entry);
        }
        i = j;
      }
      continue;
    }

    const bullet = BULLET.exec(raw);
    if (!bullet) continue;

    const text = (bullet[1] ?? "").trim();
    if (!text || underNavigation) continue;

    entries.push(lineEntry(raw, text, line, at));
  }

  // The H1 can sit below the first entry, so backfill rather than reporting two
  // different topics for one note.
  if (topicFromHeading) {
    for (const entry of entries) entry.topic = at.topic;
  }

  // Only code inherits the note's language. Tagging a prose line as SQL would
  // colour an English sentence as a broken query.
  if (declared) {
    for (const entry of entries) {
      if (entry.isCode && !entry.language) entry.language = declared;
    }
  }

  return { file, topic: at.topic, language: declared, entries };
}

export type ContextWindow = {
  /** The surrounding lines, verbatim. */
  lines: string[];
  /** 1-indexed line number of `lines[0]`, so a preview can number its gutter. */
  firstLine: number;
  /** Index within `lines` of the line asked for, after clamping. */
  targetIndex: number;
};

/**
 * The lines around a target line, clamped to the file.
 *
 * A cheatsheet row shows one line, which is the point at lookup time and not
 * enough when deciding whether it is the right line. The preview needs its
 * neighbours.
 */
export function contextAround(
  content: string,
  line: number,
  radius: number,
): ContextWindow {
  const all = content.split(/\r?\n/);
  const target = Math.max(1, Math.min(line, all.length));
  const first = Math.max(1, target - radius);
  const last = Math.min(all.length, target + radius);

  let from = first;
  let to = last;

  // Trim blank edges, but never past the target line. A window that opens at a
  // section boundary otherwise begins with two empty lines, which in a fenced
  // preview reads as a rendering fault rather than as context.
  while (from < target && (all[from - 1] ?? "").trim() === "") from++;
  while (to > target && (all[to - 1] ?? "").trim() === "") to--;

  return {
    lines: all.slice(from - 1, to),
    firstLine: from,
    targetIndex: target - from,
  };
}
