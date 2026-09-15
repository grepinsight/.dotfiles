#!/usr/bin/env bash
# Gate the english-fix--*.yml files before they reach a PUBLIC repo.
#
# These files are generated from a personal English Fix Log whose source prompts are
# about work, so a perfectly good grammar fix can carry an internal name with it: the
# article correction is generic, the noun it attaches to may not be. That is why this
# runs rather than being remembered.
#
# The illustrating example used to be a real internal name, which made this comment a
# leak of exactly the kind it warns about. A comment ships like an entry does.
#
# Fails closed: an unrecognised hit is an error, never a warning.
set -euo pipefail

MATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/match"
die() { echo "english-fix-lint: $*" >&2; exit 1; }

[ -d "$MATCH_DIR" ] || die "no match/ directory beside this script (looked in $MATCH_DIR)"

shopt -s nullglob
FILES=("$MATCH_DIR"/english-fix--*.yml)
[ ${#FILES[@]} -gt 0 ] || { echo "english-fix-lint: no english-fix--*.yml files yet, nothing to check"; exit 0; }

# Case-insensitive denylist, READ FROM OUTSIDE THIS REPOSITORY.
#
# It used to be a literal here, which made this script the leak it exists to
# prevent: a list of internal product names, committed to a public repo, inside
# the guard against committing internal product names to a public repo. It was
# already pushed before anyone noticed.
#
# The list now lives outside every working tree. No fallback and no default: a
# missing list means this script cannot do its job, and saying so is the only
# honest outcome. A guard that passes when it cannot check is worse than none.
DENY_FILE="${ENGLISH_FIX_DENYLIST:-$HOME/.claude/private/public-repo-denylist.txt}"
[ -r "$DENY_FILE" ] || die "denylist not readable at $DENY_FILE, so nothing can be checked. Restore it before committing generated files."
DENY=$(grep -vE '^[[:space:]]*(#|$)' "$DENY_FILE" | paste -sd'|' -)
[ -n "$DENY" ] || die "denylist at $DENY_FILE is empty, so nothing would be caught."

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

# The file must be VALID YAML with a well-formed entry per match. Every other check here
# is a grep, so a syntactically broken file passes all of them: on 2026-09-15 an entry was
# appended at column 0 under a `matches:` list indented two spaces, and the lint reported
# "OK (5 files, 61 triggers)" while espanso refused to load the file with "did not find
# expected key at line 251". Grep counted the `word: true` line and never saw the break.
# Parse first, so a file espanso cannot read can never pass.
python3 - "${FILES[@]}" <<'PYEOF' || die "the file(s) above are not valid espanso match files. Fix the YAML before committing."
import sys
try:
    import yaml
except ImportError:
    sys.exit("english-fix-lint: PyYAML is missing, so YAML validity cannot be checked. "
             "Install it (pip3 install --user pyyaml) rather than skipping the check.")
bad = False
for path in sys.argv[1:]:
    name = path.rsplit("/", 1)[-1]
    try:
        doc = yaml.safe_load(open(path, encoding="utf-8"))
    except Exception as e:
        print(f"INVALID YAML in {name}: {e}", file=sys.stderr); bad = True; continue
    matches = (doc or {}).get("matches")
    if not isinstance(matches, list) or not matches:
        print(f"INVALID in {name}: no top-level 'matches' list", file=sys.stderr); bad = True; continue
    for i, m in enumerate(matches, 1):
        if not isinstance(m, dict):
            print(f"INVALID in {name} entry {i}: not a mapping", file=sys.stderr); bad = True; continue
        for field, want in (("trigger", str), ("replace", str)):
            if not isinstance(m.get(field), want):
                print(f"INVALID in {name} entry {i} ({m.get('trigger')!r}): missing or non-string '{field}'", file=sys.stderr); bad = True
        for flag in ("word", "propagate_case"):
            if m.get(flag) is not True:
                print(f"INVALID in {name} entry {i} ({m.get('trigger')!r}): '{flag}' must be true", file=sys.stderr); bad = True
sys.exit(1 if bad else 0)
PYEOF

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
