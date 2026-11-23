/**
 * Matching and ranking, owned here rather than delegated to the launcher's
 * built-in filter.
 *
 * The built-in filter could not answer "delete branch" with
 * `git branch -d <branch>`, even though the description carrying both words was
 * handed to it as a keyword: it does not spread a multi-word query across a
 * long keyword string. Reverse lookup is the whole point of a cheatsheet, since
 * you reach for it precisely when you cannot remember the command, so the
 * matcher is code we control and test.
 */

import type { Entry } from "./parse.ts";

/**
 * Score weights, highest first. What they encode: a term in the command itself
 * beats the same term in its explanation, which beats it appearing only in the
 * note's structure. Within each, a whole word beats a word's prefix, which
 * beats a fragment sitting inside a word.
 */
const EXACT_PAYLOAD = 1000;
const PAYLOAD_PREFIX = 120;
const PAYLOAD_WORD = 90;
const PAYLOAD_WORD_START = 60;
const PAYLOAD_ANYWHERE = 40;
const DESCRIPTION_WORD = 24;
const DESCRIPTION_WORD_START = 12;
const DESCRIPTION_ANYWHERE = 6;
const SECTION = 8;
const TOPIC = 5;

type MatchKind = "none" | "inside" | "wordStart" | "word";

const WORD_CHARACTER = /[a-z0-9]/;

function terms(query: string): string[] {
  return query.toLowerCase().split(/\s+/).filter(Boolean);
}

/**
 * How well `term` sits in `text`, at its best occurrence.
 *
 * Three tiers, because "starts a word" is not the same as "is a word" and
 * conflating them ranked badly: searching "who" put an entry whose description
 * said "whose upstream" above the one that said "who last touched", since "who"
 * does begin the word "whose". Only the second is what a searcher means.
 */
function matchKind(text: string, term: string): MatchKind {
  let best: MatchKind = "none";

  for (
    let at = text.indexOf(term);
    at !== -1;
    at = text.indexOf(term, at + 1)
  ) {
    const end = at + term.length;
    const startsWord = at === 0 || !WORD_CHARACTER.test(text[at - 1]!);
    const endsWord = end >= text.length || !WORD_CHARACTER.test(text[end]!);

    if (startsWord && endsWord) return "word";
    if (startsWord) best = "wordStart";
    else if (best === "none") best = "inside";
  }
  return best;
}

/**
 * Score one term against one entry. Zero means the term is absent from every
 * field, which is the only thing that keeps an entry out of the results.
 */
function scoreTerm(entry: Entry, term: string): number {
  const payload = entry.copyText.toLowerCase();

  if (payload === term) return EXACT_PAYLOAD;
  if (payload.startsWith(term)) return PAYLOAD_PREFIX;

  const inPayload = matchKind(payload, term);
  if (inPayload === "word") return PAYLOAD_WORD;
  if (inPayload === "wordStart") return PAYLOAD_WORD_START;
  if (inPayload === "inside") return PAYLOAD_ANYWHERE;

  const inDescription = matchKind(
    (entry.description ?? "").toLowerCase(),
    term,
  );
  if (inDescription === "word") return DESCRIPTION_WORD;
  if (inDescription === "wordStart") return DESCRIPTION_WORD_START;
  if (inDescription === "inside") return DESCRIPTION_ANYWHERE;

  if ((entry.section ?? "").toLowerCase().includes(term)) return SECTION;
  if (entry.topic.toLowerCase().includes(term)) return TOPIC;
  return 0;
}

/**
 * Entries relevant to `query`, best first.
 *
 * Ranked primarily by HOW MANY query terms matched, so an entry matching every
 * term always outranks one matching fewer, and only entries matching nothing at
 * all are dropped.
 *
 * Strict AND was the first spec and it was wrong for this tool: "already
 * merged" returned nothing, because no entry contains the word "already".
 * Reverse lookup gets used by typing a natural phrase, so one unmatched word
 * emptying the screen reproduces the exact failure the matcher exists to fix.
 *
 * An empty query returns the input untouched, in note order.
 */
export function matchEntries(entries: Entry[], query: string): Entry[] {
  const wanted = terms(query);
  if (wanted.length === 0) return entries;

  const scored: Array<{ entry: Entry; score: number; matched: number }> = [];
  const phrase = wanted.join(" ");

  for (const entry of entries) {
    let score = 0;
    let matched = 0;

    for (const term of wanted) {
      const termScore = scoreTerm(entry, term);
      if (termScore > 0) {
        matched++;
        score += termScore;
      }
    }

    if (matched === 0) continue;

    // The whole query matching the payload as one string beats the same terms
    // scattered across it, so `git diff --staged` outranks an entry that merely
    // contains all three words.
    const payload = entry.copyText.toLowerCase();
    if (payload === phrase) score += EXACT_PAYLOAD;
    else if (payload.includes(phrase)) score += PAYLOAD_PREFIX;

    scored.push({ entry, score, matched });
  }

  return scored
    .sort((a, b) => {
      // Term coverage dominates: matching more of what was typed is always more
      // relevant than matching less of it in a better field.
      if (b.matched !== a.matched) return b.matched - a.matched;
      if (b.score !== a.score) return b.score - a.score;
      // A shorter payload at equal score is the more specific answer.
      if (a.entry.copyText.length !== b.entry.copyText.length) {
        return a.entry.copyText.length - b.entry.copyText.length;
      }
      return a.entry.id.localeCompare(b.entry.id);
    })
    .map((hit) => hit.entry);
}
