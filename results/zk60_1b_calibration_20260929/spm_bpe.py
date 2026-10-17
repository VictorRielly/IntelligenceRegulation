#!/usr/bin/env python3
"""Minimal stdlib SentencePiece-BPE encoder for the pinned TinyLlama tokenizer.

`sentencepiece` is not installed on this box and transformers' converter
needs it, so this parses `tokenizer.model` (a protobuf ModelProto) with a
hand-written wire-format reader and implements the SentencePiece BPE merge
rule: text -> identity normalization, dummy prefix, spaces escaped to U+2581,
split into code points, repeatedly merge the adjacent pair whose concatenation
is a vocabulary piece with the HIGHEST score (leftmost on ties), then map
leftover out-of-vocabulary symbols to their UTF-8 byte-fallback pieces.

It is validated in `tokenizer_selfcheck()` against known Llama-2 tokenizer
ids; any mismatch there is reported, never hidden. Token ids only feed the
calibration / held-out evaluation; nothing here is part of a proof.
"""

from __future__ import annotations

import struct
from pathlib import Path

SPACE = "▁"


def _varint(buf: bytes, pos: int):
    shift = 0
    out = 0
    while True:
        b = buf[pos]
        pos += 1
        out |= (b & 0x7F) << shift
        if b < 0x80:
            return out, pos
        shift += 7


def _fields(buf: bytes):
    pos = 0
    n = len(buf)
    while pos < n:
        key, pos = _varint(buf, pos)
        field, wire = key >> 3, key & 7
        if wire == 0:
            val, pos = _varint(buf, pos)
        elif wire == 1:
            val = buf[pos:pos + 8]
            pos += 8
        elif wire == 2:
            ln, pos = _varint(buf, pos)
            val = buf[pos:pos + ln]
            pos += ln
        elif wire == 5:
            val = buf[pos:pos + 4]
            pos += 4
        else:
            raise ValueError(f"unsupported protobuf wire type {wire}")
        yield field, wire, val


class SpmBpe:
    # SentencePiece piece types
    NORMAL, UNKNOWN, CONTROL, USER_DEFINED, UNUSED, BYTE = 1, 2, 3, 4, 5, 6

    def __init__(self, path: Path):
        raw = Path(path).read_bytes()
        self.pieces: list[str] = []
        self.scores: list[float] = []
        self.types: list[int] = []
        normalizer = {}
        trainer = {}
        for field, wire, val in _fields(raw):
            if field == 1:
                piece, score, typ = "", 0.0, self.NORMAL
                for f2, w2, v2 in _fields(val):
                    if f2 == 1:
                        piece = v2.decode("utf-8")
                    elif f2 == 2:
                        score = struct.unpack("<f", v2)[0]
                    elif f2 == 3:
                        typ = v2
                self.pieces.append(piece)
                self.scores.append(score)
                self.types.append(typ)
            elif field == 2:
                for f2, w2, v2 in _fields(val):
                    trainer[f2] = v2
            elif field == 3:
                for f2, w2, v2 in _fields(val):
                    normalizer[f2] = v2
        # trainer_spec: 3 = model_type (2 = BPE), 35 = byte_fallback
        self.model_type = trainer.get(3, 1)
        self.byte_fallback = bool(trainer.get(35, 0))
        # normalizer_spec: 1 = name, 3 = add_dummy_prefix, 4 = remove_extra_whitespaces
        self.norm_name = normalizer.get(1, b"").decode("utf-8", "replace")
        self.add_dummy_prefix = bool(normalizer.get(3, 1))
        self.remove_extra_ws = bool(normalizer.get(4, 1))
        self.index = {p: i for i, p in enumerate(self.pieces) if self.types[i] in (self.NORMAL, self.USER_DEFINED)}
        self.byte_id = {}
        for i, p in enumerate(self.pieces):
            if self.types[i] == self.BYTE:
                self.byte_id[int(p[3:5], 16)] = i
        self.unk_id = self.types.index(self.UNKNOWN)
        if self.model_type != 2:
            raise ValueError("tokenizer.model is not a BPE SentencePiece model")
        if self.norm_name not in ("identity", ""):
            raise ValueError(f"unsupported normalizer {self.norm_name!r}")

    def encode(self, text: str, bos: bool = True) -> list[int]:
        """BPE over the whole normalized string, computed chunk by chunk.

        Exactness of the chunking: the string is cut before every U+2581
        that follows a non-U+2581 character. `boundary_selfcheck` verifies
        that no vocabulary piece contains such a position, so no merge can
        cross a cut, and BPE merges inside one chunk never depend on other
        chunks; the result equals the unchunked merge sequence."""
        if self.remove_extra_ws:
            text = " ".join(text.split())
        if self.add_dummy_prefix:
            text = " " + text
        text = text.replace(" ", SPACE)
        out = [1] if bos else []
        start = 0
        cache = self.__dict__.setdefault("_cache", {})
        for i in range(1, len(text) + 1):
            if i == len(text) or (text[i] == SPACE and text[i - 1] != SPACE):
                chunk = text[start:i]
                ids = cache.get(chunk)
                if ids is None:
                    ids = self._encode_chunk(chunk)
                    cache[chunk] = ids
                out.extend(ids)
                start = i
        return out

    def boundary_selfcheck(self) -> int:
        return sum(1 for p in self.index if any(p[i] == SPACE and p[i - 1] != SPACE for i in range(1, len(p))))

    def _encode_chunk(self, text: str) -> list[int]:
        syms = list(text)
        while len(syms) > 1:
            best, best_i = None, -1
            for i in range(len(syms) - 1):
                j = self.index.get(syms[i] + syms[i + 1])
                if j is not None:
                    sc = self.scores[j]
                    if best is None or sc > best:
                        best, best_i = sc, i
            if best_i < 0:
                break
            syms[best_i:best_i + 2] = [syms[best_i] + syms[best_i + 1]]
        out = []
        for s in syms:
            j = self.index.get(s)
            if j is not None:
                out.append(j)
            elif self.byte_fallback:
                out.extend(self.byte_id[b] for b in s.encode("utf-8"))
            else:
                out.append(self.unk_id)
        return out

    def decode(self, ids: list[int]) -> str:
        buf = bytearray()
        for i in ids:
            if self.types[i] == self.BYTE:
                buf.append(int(self.pieces[i][3:5], 16))
            elif self.types[i] in (self.CONTROL, self.UNKNOWN):
                continue
            else:
                buf.extend(self.pieces[i].replace(SPACE, " ").encode("utf-8"))
        s = buf.decode("utf-8", "replace")
        return s[1:] if s.startswith(" ") else s


def tokenizer_selfcheck(tok: SpmBpe) -> dict:
    """Known Llama-2 tokenizer ids (public, widely reproduced)."""
    cases = {
        "Hello world": [1, 15043, 3186],
        "The quick brown fox": [1, 450, 4996, 17354, 1701, 29916],
    }
    got = {k: tok.encode(k) for k in cases}
    return {"cases": {k: {"expected": v, "got": got[k], "ok": got[k] == v} for k, v in cases.items()},
            "boundary_crossing_pieces": tok.boundary_selfcheck(),
            "roundtrip_ok": tok.decode(tok.encode("Round trip: café 3.14 été!")[1:]) == "Round trip: café 3.14 été!"}


if __name__ == "__main__":
    import json
    import sys
    t = SpmBpe(Path(sys.argv[1]))
    print(json.dumps({"pieces": len(t.pieces), "byte_fallback": t.byte_fallback, "normalizer": t.norm_name,
                      "add_dummy_prefix": t.add_dummy_prefix, "remove_extra_ws": t.remove_extra_ws,
                      "selfcheck": tokenizer_selfcheck(t)}, indent=1))
