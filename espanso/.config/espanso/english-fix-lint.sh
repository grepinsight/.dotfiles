#!/usr/bin/env bash
# Gate the english-fix--*.yml files before they reach a PUBLIC repo.
#
# These files are generated from a personal English Fix Log whose source prompts are
# about work. A fix like "goldmine dbt" -> "the goldmine dbt" would carry an internal
# repo name into a public repo, which is why this runs rather than being remembered.
#
# Fails closed: an unrecognised hit is an error, never a warning.
set -euo pipefail

MATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/match"
die() { echo "english-fix-lint: $*" >&2; exit 1; }

[ -d "$MATCH_DIR" ] || die "no match/ directory beside this script (looked in $MATCH_DIR)"

shopt -s nullglob
FILES=("$MATCH_DIR"/english-fix--*.yml)
[ ${#FILES[@]} -gt 0 ] || { echo "english-fix-lint: no english-fix--*.yml files yet, nothing to check"; exit 0; }

# Case-insensitive denylist of things that must never leave the machine in this file
# set. Employer, products, internal repos, hosts, ticket prefixes, and credentials.
DENY='guardant|goldmine|spacestation|midas|hatchhub|propel|titan|epishield|shield|lunar|bedrock|proteomics|protein_monitoring|spacebox|devana|ghsfa|snowflake|snowsql|databricks|artifactory|okta|crowdstrike|code42|cato|simpplr|OCT-[0-9]|atlassian|confluence|gh-[a-z]{3,}|slack\.com|\.internal|BEGIN [A-Z ]*PRIVATE KEY|ghp_|gho_|xox[baprs]-|AKIA[0-9A-Z]{16}'

fail=0
for f in "${FILES[@]}"; do
  if hits=$(grep -nEi "$DENY" "$f"); then
    echo "BLOCKED in $(basename "$f"):" >&2
    echo "$hits" | sed 's/^/    /' >&2
    fail=1
  fi
done
[ "$fail" -eq 0 ] || die "the files above name internal systems, people, or credentials. Rewrite the fix generically or keep it in the Fix Log only."

# No filesystem paths, home references, or machine identity -- in a COMMENT either.
# A generic-English autocorrect file has no business naming a directory. The header was
# the loophole: on 2026-09-04 the denylist above passed a file whose first line read
# "Generated from ~/<vault>/.../English Fix Log.md", because the denylist only knew about
# product and employer names. Paths were already banned by the written rule; nothing
# enforced it.
PATHS='~/|/Users/|/home/[a-z]|\$HOME|[Tt]houghts/|\.claude/|\.dotfiles/|English Fix Log'
for f in "${FILES[@]}"; do
  if hits=$(grep -nE "$PATHS" "$f"); then
    echo "BLOCKED (path or machine identity) in $(basename "$f"):" >&2
    echo "$hits" | sed 's/^/    /' >&2
    fail=1
  fi
done
[ "$fail" -eq 0 ] || die "the lines above name a filesystem path or this machine. Describe the source generically; a path in a comment ships to the public repo exactly like a path in an entry."

# Every match must carry word: true, or a multi-word trigger fires inside longer words.
for f in "${FILES[@]}"; do
  triggers=$(grep -c '^\s*-\s*trigger:' "$f" || true)
  words=$(grep -c '^\s*word: true' "$f" || true)
  [ "$triggers" -eq "$words" ] || die "$(basename "$f"): $triggers trigger(s) but $words 'word: true'. Every entry needs it."
done

# Duplicate triggers across the set would make which-one-wins undefined.
dupes=$(grep -h '^\s*-\s*trigger:' "${FILES[@]}" | sed 's/.*trigger: *//' | sort | uniq -d)
[ -z "$dupes" ] || die "duplicate trigger(s) across english-fix files: $dupes"

echo "english-fix-lint: OK (${#FILES[@]} files, $(grep -hc '^\s*-\s*trigger:' "${FILES[@]}" | paste -sd+ - | bc) triggers)"
