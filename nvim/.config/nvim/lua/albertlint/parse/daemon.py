"""Dependency parses for albertlint, one JSON object per line.

Long-lived on purpose. Measured on the author's machine, in a persistent venv:

    import spacy          332 to 413 ms
    spacy.load(...)       142 to 150 ms
    parse, 25 words         2.0 ms

so a per-hover subprocess would spend 500 times the parse on startup. The Lua side keeps
this process alive for the session and caches the results, which is what makes a hover a
table lookup instead of a parse. See ../../../docs/superpowers/specs/
2026-09-09-albertlint-syntax-tree-design.md.

This file lives inside the `lua/` tree, which looks wrong. `~/.config/nvim/lua/albertlint`
is a whole-directory symlink into this repo, so anything under it is reachable with no new
link, while a new top-level `python/` directory would be invisible to Neovim until someone
hand-linked it. See the trap documented at the top of CLAUDE.md.

Protocol, one JSON object per line in each direction:

    <- {"id": 1, "sentences": ["The cat sat.", "It was warm."]}
    -> {"id": 1, "trees": [...], "parse_ms": 2.4}

    <- {"id": 2, "ping": true}
    -> {"id": 2, "pong": true}

    <- {"id": 3, "quit": true}          (no response, process exits)

    -> {"id": 0, "ready": true, "load_ms": 291.0, "model": "en_core_web_sm"}

An id is echoed on every response so the caller can drop a reply for a buffer that has
since changed. Errors come back as {"id": N, "error": "..."} and the process stays up: a
parser that dies on one malformed sentence would take the whole session's cache with it.

Segmentation is NOT done here. The caller sends sentences it has already split, and the
strings it sends are the cache keys it will look the results up under, so re-splitting them
here would return trees filed under text nobody asked about.
"""

from __future__ import annotations

import json
import sys
import time

MODEL = "en_core_web_sm"

# `senter` is redundant when the caller pre-splits, and `ner` plus `lemmatizer` cost about
# 45% of the parse for output this feature never reads. Measured 2026-09-09 over 200 runs:
# a 25-word sentence goes from 3.52 ms to 2.01 ms median with these three excluded.
#
# `tagger` and `attribute_ruler` stay. Dropping them too saves only 0.2 ms and costs the POS
# column, which is half of what the sidebar shows.
EXCLUDE = ["ner", "lemmatizer", "senter"]


def emit(payload: dict) -> None:
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def tree_of(doc) -> dict:
    return {
        "text": doc.text,
        "tokens": [
            {
                "i": token.i,
                # Character offset within this sentence. Unused by the current sidebar and
                # included anyway, because it is free here and the alternative later is a
                # protocol change: jumping from a tree line back to the word in the buffer
                # needs it.
                "idx": token.idx,
                "text": token.text,
                "pos": token.pos_,
                "tag": token.tag_,
                "dep": "ROOT" if token.dep_ == "ROOT" else token.dep_,
                "head": token.head.i,
            }
            for token in doc
        ],
    }


def main() -> int:
    t0 = time.perf_counter()
    try:
        import spacy

        nlp = spacy.load(MODEL, exclude=EXCLUDE)
    except Exception as exc:  # noqa: BLE001 - reported to the editor, not swallowed
        emit({"id": 0, "error": f"{type(exc).__name__}: {exc}"})
        return 1
    load_ms = (time.perf_counter() - t0) * 1000

    # One throwaway parse. The first call through a spaCy pipeline is several times slower
    # than the rest, and paying that here means the first real hover of a session is not the
    # slowest one the user will ever see.
    nlp("The cat sat on the mat.")

    emit({"id": 0, "ready": True, "load_ms": round(load_ms, 1), "model": MODEL,
          "pipes": nlp.pipe_names})

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError as exc:
            emit({"id": -1, "error": f"bad request json: {exc}"})
            continue

        req_id = req.get("id", -1)
        if req.get("quit"):
            return 0
        if req.get("ping"):
            emit({"id": req_id, "pong": True})
            continue

        sentences = req.get("sentences")
        if not isinstance(sentences, list):
            emit({"id": req_id, "error": "request needs a `sentences` list"})
            continue

        try:
            t0 = time.perf_counter()
            # `nlp.pipe` rather than a loop: it batches the tok2vec forward pass, which is
            # where the time goes, and the whole point of the buffer sweep is to be cheap.
            trees = [tree_of(doc) for doc in nlp.pipe([str(s) for s in sentences])]
            parse_ms = (time.perf_counter() - t0) * 1000
        except Exception as exc:  # noqa: BLE001
            emit({"id": req_id, "error": f"{type(exc).__name__}: {exc}"})
            continue

        emit({"id": req_id, "trees": trees, "parse_ms": round(parse_ms, 3)})

    return 0


if __name__ == "__main__":
    sys.exit(main())
