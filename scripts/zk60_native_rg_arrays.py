"""The BINARY ARRAY STORE of schema `hashline-native-capture/5-run`.

Stage 27 of the Rust lane (2026-09-21) moved every homogeneous field-element
array of at least `ARRAY_MIN` entries out of the JSON and into ONE
`arrays.bin` beside it.  Format:
`docs/zkmatrix-poc/ZK60_RUN_CAPTURE_FORMAT.md` §12 on lane
`zk60-private-block-125m`.  A reference is

    {"array": "<sha256 hex>", "elem": "fp"|"fp2", "len": N,
     "offset": O, "bytes": B}

and the array's values are the `B` bytes at `O` of `arrays.bin`, each entry
one little-endian `u64` (`fp`) or two, `c0` then `c1` (`fp2`).  Identical
arrays are stored once, so one reference's bytes may serve many members.

WHY THIS MODULE EXISTS, AND WHAT IT REFUSES.

At the 125M shape one stage's opened columns, opening vectors and public
tables are hundreds of megabytes.  Rendered as decimal JSON they are 653 MB
for a two-block run and every one of them would have to be parsed into
Python ints before a single check could run.  Read from the store they are a
`numpy` view into a memory-mapped file: **nothing is copied and nothing is
converted until an entry is actually read**.  That is the whole of the
performance story, and it is why the two array classes below behave like the
lists `/4-run` writes rather than like arrays -- every existing gate module
indexes, iterates and takes `len` of these members and none of them had to
change.

Every resolution is CHECKED before it is handed out, and a check that fails
is a REFUSAL BY NAME -- an `ArrayRefused` carrying the member's path -- never
an exception from `struct`, `numpy` or a slice that ran off the end.  Rounds
5 and 8 each found a refusal path in this lane that crashed instead of
refusing (findings K4-F1 and R8-F1); this module is written so that the
refusal is the ordinary path and the crash does not exist.  What is checked:

  * the reference's own shape: exactly the five members, no more;
  * `elem` is one of the two the format names;
  * `bytes == len * width(elem)`, which the writer states as an invariant;
  * the byte range lies inside the file;
  * **the SHA-256 of exactly those bytes equals `array`** -- the digest is
    in the reference for this reason (format §12, last line);
  * every decoded `u64` is a reduced Goldilocks element (`< p`), which the
    format does not promise in words but which every value the verifier sees
    must satisfy, and which costs one vectorised comparison.

A digest, once recomputed, is remembered for the life of the store, so the
dedup the writer performs is not paid for again on this side.

NOTHING HERE IS A PRIVACY STATEMENT.  A capture is PUBLISHED data; this
module reads bytes the bundle already publishes and derives no key, no
witness and no hidden value.
"""

from __future__ import annotations

import hashlib
import mmap
import os
from collections.abc import Sequence

import numpy as np

SCHEMA_4 = "hashline-native-capture/4-run"
SCHEMA_5 = "hashline-native-capture/5-run"
SCHEMAS = (SCHEMA_4, SCHEMA_5)

ARRAY_STORE_FILE = "arrays.bin"
# `run_capture::ARRAY_MIN` -- an array shorter than this stays inline.
ARRAY_MIN = 256
ELEM_WIDTH = {"fp": 8, "fp2": 16}
REFERENCE_KEYS = frozenset(("array", "elem", "len", "offset", "bytes"))
# Format §12: "Which fields can be external ... Nothing else, ever."
EXTERNALISABLE = ("values", "vector", "proximity_vector", "proximity_rhos", "q", "prox")

P = (1 << 64) - (1 << 32) + 1


class ArrayRefused(ValueError):
    """A reference this store will not resolve, named at the member."""


def is_reference(v) -> bool:
    return isinstance(v, dict) and "array" in v


class FpArray(Sequence):
    """An `fp` array: entry `i` is one little-endian u64, as an `int`.

    Reads exactly like the JSON list `/4-run` writes in its place."""

    elem = "fp"

    def __init__(self, view: "np.ndarray", ref: dict, where: str):
        self._a = view
        self.ref = ref
        self.where = where

    def __len__(self):
        return int(self._a.shape[0])

    def __getitem__(self, i):
        if isinstance(i, slice):
            return [int(x) for x in self._a[i]]
        return int(self._a[i])

    def __iter__(self):
        for x in self._a:
            yield int(x)

    def __eq__(self, other):
        if isinstance(other, FpArray):
            return np.array_equal(self._a, other._a)
        if isinstance(other, (list, tuple)):
            return len(other) == len(self) and all(
                a == b for a, b in zip(self, other)
            )
        return NotImplemented

    def __repr__(self):
        return f"FpArray(len={len(self)}, at={self.where})"

    def numpy(self):
        return self._a

    def tolist(self):
        return [int(x) for x in self._a]


class Fp2Array(Sequence):
    """An `fp2` array: entry `i` is `[c0, c1]`, two little-endian u64.

    Reads exactly like the JSON list-of-pairs `/4-run` writes in its place."""

    elem = "fp2"

    def __init__(self, view: "np.ndarray", ref: dict, where: str):
        self._a = view  # shape (len, 2)
        self.ref = ref
        self.where = where

    def __len__(self):
        return int(self._a.shape[0])

    def __getitem__(self, i):
        if isinstance(i, slice):
            return [[int(r[0]), int(r[1])] for r in self._a[i]]
        r = self._a[i]
        return [int(r[0]), int(r[1])]

    def __iter__(self):
        for r in self._a:
            yield [int(r[0]), int(r[1])]

    def __eq__(self, other):
        if isinstance(other, Fp2Array):
            return np.array_equal(self._a, other._a)
        if isinstance(other, (list, tuple)):
            return len(other) == len(self) and all(
                list(a) == list(b) for a, b in zip(self, other)
            )
        return NotImplemented

    def __repr__(self):
        return f"Fp2Array(len={len(self)}, at={self.where})"

    def numpy(self):
        return self._a

    def tolist(self):
        return [[int(r[0]), int(r[1])] for r in self._a]


class ArrayStore:
    """One bundle's `arrays.bin`, memory-mapped, with the checks above."""

    def __init__(self, path: str, declared_bytes=None, declared_sha256=None):
        self.path = os.path.abspath(path)
        self.name = os.path.basename(self.path)
        if not os.path.exists(self.path):
            raise ArrayRefused(
                f"{self.name}: schema {SCHEMA_5} declares a binary array store "
                "and the directory has no such file"
            )
        self.bytes = os.path.getsize(self.path)
        if declared_bytes is not None and self.bytes != declared_bytes:
            raise ArrayRefused(
                f"{self.name}: {self.bytes} bytes on disk, {declared_bytes} in "
                "the manifest"
            )
        self._fh = open(self.path, "rb")
        self._mm = mmap.mmap(self._fh.fileno(), 0, access=mmap.ACCESS_READ)
        self._buf = memoryview(self._mm)
        self.declared_sha256 = declared_sha256
        # resolution book-keeping, all public counts.
        #
        # **The cache is keyed on the RANGE, not on the digest.**  Keying it
        # on the digest alone was the first form of this code and control
        # M9-1 caught it: a reference that claims an ALREADY-SEEN digest at
        # a DIFFERENT offset would have skipped the re-hash and been
        # accepted, which is exactly the check the digest is in the
        # reference for.  A round-9 finding against round 9's own loader,
        # written down here so the shape of the mistake stays visible.
        self.verified_ranges: set[tuple[int, int, str]] = set()
        self.verified_digests: set[str] = set()
        self.resolutions = 0
        self.distinct_arrays_verified = 0
        self.bytes_verified = 0
        self.refusals: list[str] = []

    # ------------------------------------------------------------- lifetime
    def close(self) -> bool:
        """Unmap if nothing still holds a view, and NEVER raise.

        Every resolved member is a zero-copy `numpy` view into this mapping,
        so while one is alive the mapping cannot be unmapped -- `mmap.close`
        raises `BufferError: cannot close exported pointers exist`.  That is
        a correct refusal by CPython and not an error here: closing a store
        whose arrays are still in use would be the bug.  The file handle is
        released either way and the mapping goes with the process.  Returns
        whether the mapping was actually unmapped."""
        unmapped = False
        try:
            self._buf.release()
        except (BufferError, ValueError):
            pass
        try:
            self._mm.close()
            unmapped = True
        except (BufferError, ValueError):
            pass
        finally:
            try:
                self._fh.close()
            except Exception:  # noqa: BLE001 -- close must not raise
                pass
        return unmapped

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    # ------------------------------------------------------------- resolve
    def check_reference(self, ref, where: str) -> tuple[str, int, int, int]:
        """Everything about the reference that can be checked without reading
        a byte.  Raises `ArrayRefused` naming `where`; never anything else."""
        if not isinstance(ref, dict):
            raise ArrayRefused(f"{where}: not an array reference object")
        extra = set(ref) - REFERENCE_KEYS
        missing = REFERENCE_KEYS - set(ref)
        if missing:
            raise ArrayRefused(
                f"{where}: the array reference is missing {sorted(missing)}"
            )
        if extra:
            raise ArrayRefused(
                f"{where}: the array reference carries {sorted(extra)}, which "
                f"schema {SCHEMA_5} does not define"
            )
        elem = ref["elem"]
        if elem not in ELEM_WIDTH:
            raise ArrayRefused(
                f"{where}: element type {elem!r} is not 'fp' or 'fp2'"
            )
        w = ELEM_WIDTH[elem]
        n, off, nb = ref["len"], ref["offset"], ref["bytes"]
        for label, v in (("len", n), ("offset", off), ("bytes", nb)):
            if not isinstance(v, int) or isinstance(v, bool) or v < 0:
                raise ArrayRefused(f"{where}: {label} {v!r} is not a whole number")
        if nb != n * w:
            raise ArrayRefused(
                f"{where}: bytes {nb} != len {n} * {w} for an {elem} array"
            )
        digest = ref["array"]
        if not isinstance(digest, str) or len(digest) != 64:
            raise ArrayRefused(f"{where}: {digest!r} is not a sha256 hex digest")
        if off + nb > self.bytes:
            raise ArrayRefused(
                f"{where}: bytes {off}..{off + nb} run past the end of "
                f"{self.name} ({self.bytes} bytes)"
            )
        return elem, n, off, nb

    def resolve(self, ref, where: str):
        """A checked, zero-copy view of the referenced array.

        The digest of the exact byte range is recomputed the first time that
        range is seen and remembered afterwards, so the writer's dedup costs
        one hash here too."""
        elem, n, off, nb = self.check_reference(ref, where)
        raw = self._buf[off : off + nb]
        digest = ref["array"]
        if (off, nb, digest) not in self.verified_ranges:
            got = hashlib.sha256(raw).hexdigest()
            if got != digest:
                raise ArrayRefused(
                    f"{where}: the sha256 of bytes {off}..{off + nb} of "
                    f"{self.name} is {got[:16]}..., the reference says "
                    f"{digest[:16]}..."
                )
            self.verified_ranges.add((off, nb, digest))
            if digest not in self.verified_digests:
                self.verified_digests.add(digest)
                self.distinct_arrays_verified += 1
                self.bytes_verified += nb
        a = np.frombuffer(raw, dtype="<u8")
        if a.shape[0] != nb // 8:
            raise ArrayRefused(f"{where}: {nb} bytes do not decode to whole u64")
        if bool((a >= P).any()):
            bad = int(np.argmax(a >= P))
            raise ArrayRefused(
                f"{where}: u64 {bad} is {int(a[bad])}, not a reduced Goldilocks "
                "element"
            )
        self.resolutions += 1
        if elem == "fp":
            return FpArray(a, ref, where)
        return Fp2Array(a.reshape(n, 2), ref, where)

    def summary(self) -> dict:
        return {
            "file": self.name,
            "bytes": self.bytes,
            "references_resolved": self.resolutions,
            "distinct_arrays_verified_by_sha256": self.distinct_arrays_verified,
            "bytes_verified_by_sha256": self.bytes_verified,
            "refusals": list(self.refusals),
            "what_is_checked": "per reference: exactly the five defined keys, "
            "elem in {fp, fp2}, bytes == len * width, the range inside the "
            "file, the sha256 of exactly those bytes, and every decoded u64 "
            "reduced mod the Goldilocks prime",
            "ok": not self.refusals,
        }


# --------------------------------------------------------------- the walk
def resolve_document(doc, store: ArrayStore, where: str, refusals: list) -> int:
    """Replace every array reference in `doc` IN PLACE with a checked view.

    Two rules, both from format §12, and each a refusal by name rather than
    an exception:

      * a reference under one of the six externalisable member names is
        resolved;
      * a reference anywhere else is REFUSED -- "Nothing else, ever".

    Returns the number of references resolved.  Nothing raises: every
    failure lands in `refusals` as a sentence naming the member's path, so a
    caller reports a bundle it will not read instead of dying on it.
    """
    n = 0

    def walk(node, path):
        nonlocal n
        if isinstance(node, dict):
            for k in list(node):
                v = node[k]
                if is_reference(v):
                    sub = f"{path}.{k}"
                    if k not in EXTERNALISABLE:
                        refusals.append(
                            f"{sub}: an array reference under a member schema "
                            f"{SCHEMA_5} does not externalise (the six are "
                            f"{list(EXTERNALISABLE)})"
                        )
                        continue
                    try:
                        node[k] = store.resolve(v, sub)
                        n += 1
                    except ArrayRefused as e:
                        refusals.append(str(e))
                else:
                    walk(v, f"{path}.{k}")
        elif isinstance(node, list):
            for i, v in enumerate(node):
                if is_reference(v):
                    refusals.append(
                        f"{path}[{i}]: an array reference as a list element, "
                        "which the schema never writes"
                    )
                else:
                    walk(v, f"{path}[{i}]")

    walk(doc, where)
    return n


# -------------------------------------------------------------- the encoder
def encode_to_5run(doc, blob: bytearray, index: dict, where: str) -> int:
    """The INVERSE, used only to prove this decoder against the format.

    Walks a `/4-run` document and replaces every externalisable member that
    is a list of at least `ARRAY_MIN` field elements with a reference into
    `blob`, deduplicating by digest exactly as the writer does.  Returns the
    number of members externalised.

    THIS IS NOT THE RUST ENCODER and proves nothing about it.  It exists so
    that the decoder above can be run against a document whose `/4-run` form
    is known, member by member; the Rust side has its own byte-for-byte
    equality test
    (`run_capture_tests::the_array_store_and_the_classic_encoding_carry_the_same_values`).
    """
    n = 0

    def classify(v):
        if not isinstance(v, list) or len(v) < ARRAY_MIN:
            return None
        if all(isinstance(x, int) and not isinstance(x, bool) for x in v):
            return "fp"
        if all(
            isinstance(x, list)
            and len(x) == 2
            and all(isinstance(y, int) and not isinstance(y, bool) for y in x)
            for x in v
        ):
            return "fp2"
        return None

    def emit(v, elem):
        nonlocal n
        flat = v if elem == "fp" else [y for x in v for y in x]
        raw = np.asarray(flat, dtype="<u8").tobytes()
        digest = hashlib.sha256(raw).hexdigest()
        if digest in index:
            off = index[digest]
        else:
            off = len(blob)
            blob.extend(raw)
            index[digest] = off
        n += 1
        return {
            "array": digest,
            "elem": elem,
            "len": len(v),
            "offset": off,
            "bytes": len(raw),
        }

    def walk(node):
        if isinstance(node, dict):
            for k in list(node):
                v = node[k]
                elem = classify(v) if k in EXTERNALISABLE else None
                if elem is not None:
                    node[k] = emit(v, elem)
                else:
                    walk(v)
        elif isinstance(node, list):
            for v in node:
                walk(v)

    walk(doc)
    return n
