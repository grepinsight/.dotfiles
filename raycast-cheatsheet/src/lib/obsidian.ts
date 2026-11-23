/**
 * Obsidian deep links, via the Advanced URI community plugin.
 *
 * Plain `obsidian://open` reaches a file but not a position in it, which for a
 * cheatsheet means landing at the top of a note and hunting for the line you
 * were already looking at. Advanced URI takes a line number.
 */

export type AdvancedUriTarget = {
  /** The vault's name, which is its folder name. */
  vault: string;
  /** Vault-relative path, forward-slashed. */
  filepath: string;
  /**
   * 1-indexed, which is both `Entry.line`'s convention and the plugin's own:
   * it calls `setCursor` with `Math.min(line - 1, lineCount - 1)`.
   */
  line: number;
};

/**
 * Build an `obsidian://adv-uri` link that opens the note and puts the cursor on
 * `line`.
 *
 * Encoded with `encodeURIComponent` rather than `URLSearchParams`, which spells
 * a space as `+`. Whether the receiving handler reads `+` as a space or as a
 * literal plus is its business, and a vault called "My Vault" should not depend
 * on the answer.
 *
 * `column` is always sent because the plugin computes the cursor offset as
 * `Math.min(column - 1, lineLength)`. With no column that is `Math.min(NaN, n)`,
 * so the cursor would be set to NaN. Sending 1 pins it to the line's start.
 */
export function advancedUri({
  vault,
  filepath,
  line,
}: AdvancedUriTarget): string {
  const query = [
    `vault=${encodeURIComponent(vault)}`,
    `filepath=${encodeURIComponent(filepath)}`,
    `line=${line}`,
    "column=1",
  ].join("&");

  return `obsidian://adv-uri?${query}`;
}
