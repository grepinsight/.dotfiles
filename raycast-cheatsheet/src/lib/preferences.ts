import { getPreferenceValues } from "@raycast/api";
import { homedir } from "node:os";

export type RawPreferences = {
  notesPath: string;
  extraNotesPaths?: string;
  newNotePath?: string;
  tag?: string;
  primaryAction?: "copy" | "paste";
  codeLanguage?: string;
};

export type Settings = {
  /** Every folder to scan, tilde-expanded, blanks dropped. */
  notesPaths: string[];
  /** The first folder, which is also where the scan's hint points. */
  notesPath: string;
  /**
   * Where `createNote` puts a new topic. Separate from `notesPath` because
   * scanning wants the whole vault while creating wants one tidy folder, and
   * defaulting them together would drop new notes at the vault root.
   */
  newNotePath: string;
  tag: string;
  primaryAction: "copy" | "paste";
  /** Highlighting fallback for code entries whose note declares no language. */
  codeLanguage: string;
};

function expand(path: string): string {
  return (path ?? "").replace(/^~(?=$|\/)/, homedir());
}

/** Preferences with the tilde expanded and the optional fields defaulted. */
export function settings(): Settings {
  const raw = getPreferenceValues<RawPreferences>();
  const notesPath = expand(raw.notesPath);
  const extra = (raw.extraNotesPaths ?? "")
    .split(/[,\n]/)
    .map((path) => expand(path.trim()))
    .filter(Boolean);

  return {
    notesPaths: [notesPath, ...extra].filter(Boolean),
    notesPath,
    newNotePath: expand(raw.newNotePath ?? "") || notesPath,
    tag: (raw.tag ?? "").trim() || "quick-ref",
    primaryAction: raw.primaryAction ?? "copy",
    codeLanguage: (raw.codeLanguage ?? "").trim().toLowerCase() || "bash",
  };
}
