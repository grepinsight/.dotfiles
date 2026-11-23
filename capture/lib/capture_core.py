"""Core of the quick-capture path: turn a thought into a file in the vault.

Split out of `bin/capture` so the two parts that are easy to get wrong are
testable without a shell, a clock, or the real vault:

  * `slug()` is pure -- no filesystem, no time, no environment.
  * `write()` takes the vault root and the timestamp as arguments rather than
    reading them from the environment, so a test can point it at a temp dir.

Nothing here calls a model, opens a socket, or shells out. That is the whole
design constraint: the capture path must not be able to be slow, and must not
be able to lose a thought because something upstream was unreachable.
"""

import os
import re
import unicodedata
from pathlib import Path
from urllib.parse import quote

CAPTURE_DIR = "00-Capture"

# Fallback stem for text that contains no letters or digits at all (an emoji, a
# row of dashes). Better a file named `note` than a crash on the capture path.
FALLBACK_SLUG = "note"

# Readability cap. Long enough to recognise the thought in a file listing,
# short enough that the name is not the thing you read instead of the note.
MAX_SLUG_CHARS = 60

# Byte cap, and the reason it exists separately from the character cap: APFS
# compares filenames in decomposed form, and a single Hangul syllable that is
# 3 UTF-8 bytes composed becomes three jamo at 3 bytes each once decomposed. So
# 60 Korean characters is ~540 bytes on disk, well past the 255-byte limit for
# one path component, and the write would fail with ENAMETOOLONG on exactly the
# notes the user is most likely to type quickly. Budget in decomposed bytes and
# leave room for the `YYYY-MM-DD-HHMM-` prefix, a `-99` collision suffix, `.md`.
MAX_SLUG_BYTES = 180

MAX_COLLISIONS = 99


def _keeps(char):
    """True for characters that belong in a filename stem: letters and digits.

    Category-based rather than an ASCII allowlist, so Hangul and Kanji survive
    (`Lo`) instead of being stripped down to the fallback. Emoji are `So` and
    are dropped, which is intended -- they are decoration, not a name.
    """
    return unicodedata.category(char)[0] in ("L", "N")


def _words(text):
    """Split on runs of non-kept characters, discarding them."""
    words, current = [], []
    for char in text:
        if _keeps(char):
            current.append(char)
        elif current:
            words.append("".join(current))
            current = []
    if current:
        words.append("".join(current))
    return words


def _decomposed_bytes(text):
    return len(unicodedata.normalize("NFD", text).encode("utf-8"))


def _clip(word, max_chars, max_bytes):
    """Hard-cut a single word that is over budget on its own."""
    clipped = word[:max_chars]
    while clipped and _decomposed_bytes(clipped) > max_bytes:
        clipped = clipped[:-1]
    return clipped


def slug(text, max_words=8, max_chars=MAX_SLUG_CHARS, max_bytes=MAX_SLUG_BYTES):
    """A filename stem derived from the opening words of the thought.

    Pure. Drops whole trailing words to fit the budget rather than cutting
    mid-word, because a name that ends mid-word reads as corruption.
    """
    normalized = unicodedata.normalize("NFC", text).casefold()
    words = _words(normalized)[:max_words]

    while words:
        candidate = "-".join(words)
        if len(candidate) <= max_chars and _decomposed_bytes(candidate) <= max_bytes:
            return candidate
        if len(words) > 1:
            words.pop()
        else:
            # One word, still too long: no word boundary left to fall back to.
            return _clip(words[0], max_chars, max_bytes) or FALLBACK_SLUG

    return FALLBACK_SLUG


def _source_token(source):
    """Reduce a door name to something safe to drop into YAML unquoted."""
    token = re.sub(r"[^a-z0-9_.-]+", "-", str(source).lower()).strip("-")
    return token or "unknown"


def render(text, now, source):
    """The full file contents: minimal frontmatter, then the thought verbatim.

    `source` records which door was used. It costs nothing to write and is the
    only way to later answer "which of the four front doors do I actually use",
    which is the question a friction experiment exists to answer.
    """
    lines = [
        "---",
        'created_at: "{}"'.format(now.isoformat(timespec="seconds")),
        "tags:",
        "  - capture",
        "source: {}".format(_source_token(source)),
        "---",
        "",
        text.strip(),
        "",
    ]
    return "\n".join(lines)


def stem_for(text, now):
    """The filename stem, before collision handling: `YYYY-MM-DD-HHMM-<slug>`."""
    return "{}-{}".format(now.strftime("%Y-%m-%d-%H%M"), slug(text))


def _candidates(directory, stem):
    yield directory / "{}.md".format(stem)
    for n in range(2, MAX_COLLISIONS + 1):
        yield directory / "{}-{}.md".format(stem, n)


def capture_dir(vault_root):
    return Path(vault_root) / CAPTURE_DIR


def planned_path(text, vault_root, now):
    """Where `write()` would put this thought, without creating anything.

    Advisory only: it answers the question a `--dry-run` asks, and is
    deliberately not what `write()` uses to pick its name, because between the
    check and the write another capture could take the name.
    """
    directory = capture_dir(vault_root)
    for path in _candidates(directory, stem_for(text, now)):
        if not path.exists():
            return path
    raise RuntimeError(
        "more than {} captures share one minute and one slug".format(MAX_COLLISIONS)
    )


def write(text, vault_root, now, source="shell"):
    """Write the thought to its own file and return the path.

    Claims the filename with O_CREAT|O_EXCL rather than checking `exists()`
    first: two captures in the same minute with the same opening words are a
    real case (a hotkey pressed twice), and a check-then-write would let the
    second silently overwrite the first.
    """
    body = text.strip()
    if not body:
        raise ValueError("nothing to capture: the text was empty")

    root = Path(vault_root)
    if not root.is_dir():
        raise FileNotFoundError("vault root does not exist: {}".format(root))

    directory = capture_dir(root)
    directory.mkdir(parents=True, exist_ok=True)
    contents = render(body, now, source).encode("utf-8")

    for path in _candidates(directory, stem_for(body, now)):
        try:
            handle = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
        except FileExistsError:
            continue
        with os.fdopen(handle, "wb") as sink:
            sink.write(contents)
        return path

    raise RuntimeError(
        "more than {} captures share one minute and one slug".format(MAX_COLLISIONS)
    )


# `vault=<name>&file=<path>` rather than the absolute-path form, because this is
# the shape verified against this machine's Obsidian: firing it opened the
# target as the active tab. The vault *name* defaults to the basename of the
# vault root, which is how Obsidian names a vault unless it has been renamed
# independently of its folder -- hence the override parameter.
OBSIDIAN_URI = "obsidian://open?vault={vault}&file={file}"


def deeplink(path, vault_root, vault_name=None):
    """An `obsidian://open` URI for a capture. Pure: no filesystem, no network.

    Percent-encodes with `safe=""`, so the path separator becomes `%2F` and
    Korean becomes UTF-8 escapes. Both are required: an unencoded `/` in the
    `file` parameter is read as part of the query string, not the path.
    """
    root = Path(vault_root)
    # Raises ValueError when the path is not inside the vault, which is the
    # right answer: there is no vault-relative link to a file outside the vault.
    relative = Path(path).relative_to(root)

    name = vault_name or root.name
    if not name:
        raise ValueError("cannot derive a vault name from {!r}".format(str(vault_root)))

    return OBSIDIAN_URI.format(
        vault=quote(name, safe=""), file=quote(relative.as_posix(), safe="")
    )


# ---------------------------------------------------------------------------
# Reading side. Added when the write side had four doors and no way to review.
# ---------------------------------------------------------------------------

# Deliberately a hand-rolled reader rather than a YAML parser: it keeps the
# module dependency-free on a path that has to work on a fresh machine, and the
# frontmatter it parses is the frontmatter `render()` above writes, so its shape
# is known rather than guessed. A capture edited by hand into something exotic
# degrades to created_at=None, which the callers treat as "unknown", not as an
# error -- losing a field beats refusing to list the thought.
_FRONT_CREATED = re.compile(r'^created_at:\s*"?([^"]*)"?\s*$')
_FRONT_SOURCE = re.compile(r"^source:\s*(.*)$")


def parse_document(content):
    """Pull `created_at`, `source`, and the thought itself out of a capture file.

    Pure: takes the file's text, returns a dict. No filesystem.
    """
    lines = content.split("\n")
    created_at = None
    source = None
    body_start = 0

    if lines and lines[0].strip() == "---":
        for index in range(1, len(lines)):
            if lines[index].strip() == "---":
                body_start = index + 1
                break
            found = _FRONT_CREATED.match(lines[index])
            if found:
                created_at = found.group(1).strip() or None
                continue
            found = _FRONT_SOURCE.match(lines[index])
            if found:
                source = found.group(1).strip().strip('"') or None

    body = "\n".join(lines[body_start:]).strip()
    first, _, rest = body.partition("\n")
    return {
        "created_at": created_at,
        "source": source,
        "text": body,
        "first_line": first.strip(),
        "multiline": bool(rest.strip()),
    }


def list_captures(vault_root, limit=None):
    """Captures newest first, each parsed into a dict.

    Sorts by filename, not by mtime. Two reasons: the name begins with
    `YYYY-MM-DD-HHMM`, so a reverse lexicographic sort already is a reverse
    chronological one and costs no `stat()` calls; and mtime reports when a
    capture was last *edited*, which puts an old thought you fixed a typo in
    above a new one you just had.
    """
    directory = capture_dir(vault_root)
    if not directory.is_dir():
        return []

    paths = sorted(directory.glob("*.md"), key=lambda p: p.name, reverse=True)
    if limit is not None:
        paths = paths[:limit]

    captures = []
    for path in paths:
        try:
            parsed = parse_document(path.read_text(encoding="utf-8"))
        except OSError:
            # One unreadable file must not take out the whole listing.
            continue
        parsed["path"] = str(path)
        parsed["name"] = path.name
        try:
            parsed["deeplink"] = deeplink(path, directory.parent)
        except ValueError:
            parsed["deeplink"] = None
        captures.append(parsed)

    # The name sort above has one-minute precision, so a burst of thoughts
    # inside one minute comes back alphabetical rather than chronological.
    # Frontmatter carries seconds, so re-sort the selected records on it, with
    # the name as the tiebreaker for a capture whose frontmatter was edited
    # away. Caveat: with a `limit`, *which* records get selected is still
    # decided at minute precision, so a burst straddling the cut-off can lose a
    # record to the one after it. Not worth reading the whole folder to fix.
    captures.sort(key=lambda r: (r["created_at"] or "", r["name"]), reverse=True)
    return captures
