import { getPreferenceValues } from "@raycast/api";
import { homedir } from "node:os";

export type RawPreferences = {
  notesPath: string;
  tag?: string;
  primaryAction?: "copy" | "paste";
};

export type Settings = {
  notesPath: string;
  tag: string;
  primaryAction: "copy" | "paste";
};

/** Preferences with the tilde expanded and the optional fields defaulted. */
export function settings(): Settings {
  const raw = getPreferenceValues<RawPreferences>();
  return {
    notesPath: (raw.notesPath ?? "").replace(/^~(?=$|\/)/, homedir()),
    tag: (raw.tag ?? "").trim() || "quick-ref",
    primaryAction: raw.primaryAction ?? "copy",
  };
}
