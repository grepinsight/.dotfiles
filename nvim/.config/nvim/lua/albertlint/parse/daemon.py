"""Dependency parses for albertlint, one JSON object per line.

Long-lived on purpose. Measured in a persistent venv: 332-413ms to import, 142-150ms to load
the model, 2.0ms to parse 25 words, so a per-hover subprocess would spend 500 times the parse
on startup. The Lua side keeps this alive for the session and caches the results, which is
what makes a hover a table lookup. Design doc: docs/superpowers/specs/
2026-09-09-albertlint-syntax-tree-design.md.

This file lives inside the `lua/` tree, which looks wrong and is not:
`~/.config/nvim/lua/albertlint` is a whole-directory symlink, so anything under it is
reachable, while a new top-level `python/` directory would be invisible to Neovim until
someone hand-linked it. See the trap at the top of CLAUDE.md.

Protocol, one JSON object per line in each direction:

    <- {"id": 1, "sentences": ["The cat sat.", "It was warm."]}
    -> {"id": 1, "trees": [...], "parse_ms": 2.4}

    <- {"id": 2, "ping": true}
    -> {"id": 2, "pong": true}

    <- {"id": 3, "quit": true}          (no response, process exits)

    -> {"id": 0, "ready": true, "load_ms": 291.0, "model": "en_core_web_sm"}

An id is echoed on every response so the caller can drop a reply for a buffer that has since
changed. Errors come back as {"id": N, "error": "..."} and the process stays up: dying on one
malformed sentence would take the whole session's cache with it.

Segmentation is NOT done here. The strings the caller sends are the cache keys it will look
the results up under, so re-splitting them would return trees filed under text nobody asked
about.
"""

from __future__ import annotations

import json
import sys
import time

MODEL = "en_core_web_sm"

# `senter` is redundant when the caller pre-splits, and `ner` plus `lemmatizer` cost about 45%
# of the parse for output this never reads: 3.52ms to 2.01ms median on 25 words, measured
# 2026-09-09 over 200 runs. `tagger` and `attribute_ruler` stay, since dropping them saves
# 0.2ms and costs the POS column.
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
                # Character offset within the sentence, which the phrase column needs.
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

    # The first call through a pipeline is several times slower than the rest, so pay it here
    # rather than on the session's first real hover.
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
            # `nlp.pipe` rather than a loop: it batches the tok2vec forward pass.
            trees = [tree_of(doc) for doc in nlp.pipe([str(s) for s in sentences])]
            parse_ms = (time.perf_counter() - t0) * 1000
        except Exception as exc:  # noqa: BLE001
            emit({"id": req_id, "error": f"{type(exc).__name__}: {exc}"})
            continue

        emit({"id": req_id, "trees": trees, "parse_ms": round(parse_ms, 3)})

    return 0


if __name__ == "__main__":
    sys.exit(main())
