#!/usr/bin/env python3
"""Independent BLAKE3 keyed-mode reference vectors for the device column digest.

Written for the adversarial check of
`docs/zkmatrix-poc/ZK60_HIDING_COMMITMENT_ON_DEVICE_DESIGN.md` (the memo's
section 4 and stage 1 of its plan). NOTHING here imports the project's Rust.

Three independent implementations are compared on every vector:

  A. `spec_*` below — BLAKE3 written from the specification in this file
     (compression function, chunk chaining, parent nodes, keyed mode,
     derive_key), by the checker, with no reference to the crate's code.
  B. the Python `blake3` package (bindings over the Rust crate) when present.
  C. the pinned literals in `zkp-core/src/hashtag.rs` for the eight derived
     keys, which this script re-derives from the four context strings.

It also answers the memo's own trap claim directly: `buggy_keyed_chunkstart`
is BLAKE3 keyed mode with the key words used ONLY at the chunk start and the
IV left in place at parent nodes — exactly the kernel bug the memo predicts.
The output shows at which input length it stops agreeing with real keyed
BLAKE3.

Run: python3 keyed_blake3_vectors.py   (writes keyed_vectors.json beside it)
"""

import json
import os
import struct

MASK32 = 0xFFFFFFFF

IV = [0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
      0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19]

MSG_PERMUTATION = [2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8]

CHUNK_START = 1
CHUNK_END = 2
PARENT = 4
ROOT = 8
KEYED_HASH = 16
DERIVE_KEY_CONTEXT = 32
DERIVE_KEY_MATERIAL = 64

BLOCK_LEN = 64
CHUNK_LEN = 1024


def rotr(x, n):
    return ((x >> n) | (x << (32 - n))) & MASK32


def g(state, a, b, c, d, mx, my):
    state[a] = (state[a] + state[b] + mx) & MASK32
    state[d] = rotr(state[d] ^ state[a], 16)
    state[c] = (state[c] + state[d]) & MASK32
    state[b] = rotr(state[b] ^ state[c], 12)
    state[a] = (state[a] + state[b] + my) & MASK32
    state[d] = rotr(state[d] ^ state[a], 8)
    state[c] = (state[c] + state[d]) & MASK32
    state[b] = rotr(state[b] ^ state[c], 7)


def round_fn(state, m):
    g(state, 0, 4, 8, 12, m[0], m[1])
    g(state, 1, 5, 9, 13, m[2], m[3])
    g(state, 2, 6, 10, 14, m[4], m[5])
    g(state, 3, 7, 11, 15, m[6], m[7])
    g(state, 0, 5, 10, 15, m[8], m[9])
    g(state, 1, 6, 11, 12, m[10], m[11])
    g(state, 2, 7, 8, 13, m[12], m[13])
    g(state, 3, 4, 9, 14, m[14], m[15])


def compress(cv, block_words, counter, block_len, flags):
    """The full 16-word output of the compression function."""
    state = [
        cv[0], cv[1], cv[2], cv[3], cv[4], cv[5], cv[6], cv[7],
        IV[0], IV[1], IV[2], IV[3],
        counter & MASK32, (counter >> 32) & MASK32, block_len & MASK32, flags & MASK32,
    ]
    m = list(block_words)
    for r in range(7):
        round_fn(state, m)
        if r < 6:
            m = [m[MSG_PERMUTATION[i]] for i in range(16)]
    for i in range(8):
        state[i] ^= state[i + 8]
        state[i + 8] ^= cv[i]
    return state


def words_from_le_bytes(b):
    assert len(b) % 4 == 0
    return list(struct.unpack("<%dI" % (len(b) // 4), b))


def block_words(block):
    padded = block + b"\x00" * (BLOCK_LEN - len(block))
    return words_from_le_bytes(padded)


def chunk_cv(data, chunk_counter, key_words, flags, parent_cv_is_key=True):
    """Chaining value of one whole chunk (<= 1024 bytes, non-empty unless the
    input is empty). Returns (cv_words, last_output) where last_output is the
    (cv, block, counter, block_len, flags) tuple of its final compression."""
    cv = list(key_words)
    blocks = [data[i:i + BLOCK_LEN] for i in range(0, len(data), BLOCK_LEN)] or [b""]
    for i, blk in enumerate(blocks):
        f = flags
        if i == 0:
            f |= CHUNK_START
        if i == len(blocks) - 1:
            f |= CHUNK_END
            return cv, (list(cv), block_words(blk), chunk_counter, len(blk), f)
        out = compress(cv, block_words(blk), chunk_counter, BLOCK_LEN, f)
        cv = out[:8]
    raise AssertionError("unreachable")


def spec_hash(data, key_words=None, flags=0, parent_key=None, add_keyed_flag=True):
    """BLAKE3, 32 bytes. `key_words` None -> hash mode (IV). Otherwise the
    key words replace the IV as the starting chaining value. `add_keyed_flag`
    is True for keyed mode and False for derive_key's material pass, which
    also starts from key words but carries DERIVE_KEY_MATERIAL, not
    KEYED_HASH. `parent_key` lets a caller inject the WRONG chaining value at
    parent nodes, which is the kernel bug this check is hunting."""
    if key_words is None:
        start = list(IV)
        base_flags = flags
    else:
        start = list(key_words)
        base_flags = flags | (KEYED_HASH if add_keyed_flag else 0)
    pkey = start if parent_key is None else list(parent_key)

    chunks = [data[i:i + CHUNK_LEN] for i in range(0, len(data), CHUNK_LEN)] or [b""]
    stack = []  # list of 8-word chaining values
    final = None
    for ci, ch in enumerate(chunks):
        cv, out = chunk_cv(ch, ci, start, base_flags)
        is_last = ci == len(chunks) - 1
        # lazy merge: reduce the stack to popcount(ci) subtrees before pushing
        want = bin(ci).count("1")
        while len(stack) > want:
            right = stack.pop()
            left = stack.pop()
            pout = compress(pkey, left + right, 0, BLOCK_LEN, base_flags | PARENT)
            stack.append(pout[:8])
        if is_last:
            if not stack:
                # the chunk's last compression IS the root
                cvv, bw, ctr, blen, f = out
                root = compress(cvv, bw, ctr, blen, f | ROOT)
                return b"".join(struct.pack("<I", w) for w in root[:8])
            cvv, bw, ctr, blen, f = out
            cur = compress(cvv, bw, ctr, blen, f)[:8]
            while stack:
                left = stack.pop()
                last = not stack
                pf = base_flags | PARENT | (ROOT if last else 0)
                cur = compress(pkey, left + cur, 0, BLOCK_LEN, pf)[:8]
            return b"".join(struct.pack("<I", w) for w in cur)
        else:
            cvv, bw, ctr, blen, f = out
            stack.append(compress(cvv, bw, ctr, blen, f)[:8])
    raise AssertionError("unreachable")


def spec_hash_unkeyed(data):
    return spec_hash(data, None, 0)


def spec_hash_keyed(data, key32):
    return spec_hash(data, words_from_le_bytes(key32), 0)


def buggy_keyed_chunkstart(data, key32):
    """THE PREDICTED KERNEL BUG: key words at the chunk start only; parent
    nodes keep the IV. KEYED_HASH is still ORed into every compression."""
    kw = words_from_le_bytes(key32)
    return spec_hash(data, kw, 0, parent_key=IV)


def spec_derive_key(context, key_material):
    ctx_key = spec_hash(context.encode("utf-8"), None, DERIVE_KEY_CONTEXT)
    return spec_hash(key_material, words_from_le_bytes(ctx_key), DERIVE_KEY_MATERIAL,
                     add_keyed_flag=False)


# --------------------------------------------------------------------------
# the project's own strings and shapes
# --------------------------------------------------------------------------
CTX_TRANSCRIPT = "hashline-zk-mr1 2026-09-20 fiat-shamir transcript"
CTX_COLUMN = "hashline-zk-mr1 2026-09-20 pcs column digest"
CTX_LEAF = "hashline-zk-mr1 2026-09-20 pcs salted merkle leaf"
CTX_NODE = "hashline-zk-mr1 2026-09-20 pcs merkle inner node"
RUNG_G = "hashline-zk-mr1/private-block-rung-g-t24-dev/1"
M125 = "hashline-zk-mr1/private-block-m125/1"

# the literals pinned in zkp-core/src/hashtag.rs:190-198
PINNED = {
    (RUNG_G, "transcript"): "51b7d0b0171d54b5bb45fd42c3f9369cad87894b625e0569b89fac0036d20dbe",
    (RUNG_G, "column"): "2295498fd6fd5e41320da717e9da89462e5c90a5b3b2d72ac496bcc157c2cd2c",
    (RUNG_G, "leaf"): "fe211417895c73c4a70430cb9bfb7081289ec7532f2716d2a86f609b0de54032",
    (RUNG_G, "node"): "8c4d2cfe7b8528d350f20dece1250c8d81596eb25d26bffda1247238f0f71fcc",
    (M125, "transcript"): "125f9b4d44ac3c46712a35419cdeda6c1428db443ccaf58da67f35b15b37291c",
    (M125, "column"): "d5fc391cc58eed85631b4c3dabc7d377477eb1a0a725aeccaec0f4d10061b135",
    (M125, "leaf"): "1dc6f7146ad501ede6d90b3071da2f3251d38137303ffcc0a6a48b7f89effe83",
    (M125, "node"): "798eb64ff187f6f3e8e889ac4c4742607ac71a71fa09e2944a0ecc5e8a42026b",
}
CTX = {"transcript": CTX_TRANSCRIPT, "column": CTX_COLUMN, "leaf": CTX_LEAF, "node": CTX_NODE}

P = 0xFFFFFFFF00000001  # Goldilocks


def synthetic_column(rows):
    """A deterministic column of `rows` canonical Goldilocks values, as the
    little-endian byte string `pcs::hash_column` would hash."""
    out = bytearray()
    x = 0x1234_5678_9ABC_DEF0
    for _ in range(rows):
        x = (x * 6364136223846793005 + 1442695040888963407) & 0xFFFFFFFFFFFFFFFF
        out += struct.pack("<Q", x % P)
    return bytes(out)


def main():
    try:
        import blake3 as b3mod
        have_b3 = True
    except Exception:
        b3mod = None
        have_b3 = False

    report = {"python_blake3_available": have_b3, "checks": [], "vectors": [], "key_pins": []}
    if have_b3:
        report["python_blake3_version"] = getattr(b3mod, "__version__", "?")

    def ref_unkeyed(d):
        return b3mod.blake3(d).digest() if have_b3 else None

    def ref_keyed(d, k):
        return b3mod.blake3(d, key=k).digest() if have_b3 else None

    fails = []

    # ---- 0. the official BLAKE3 test vector, so the spec implementation is
    # anchored to something outside this repository ----------------------
    official_key = b"whats the Elvish word for friend"
    official = [
        (0, "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262",
            "92b2b75604ed3c761f9d6f62392c8a9227ad0ea3f09573e783f1498a4ed60d26"),
        (1, "2d3adedff11b61f14c886e35afa036736dcd87a74d27b5c1510225d0f592e213",
            "6d7878dfff2f485635d39013278ae14f1454b8c0a3a2d34bc1ab38228a80c95b"),
        (1024, "42214739f095a406f3fc83deb889744ac00df831c10daa55189b5d121c855af7",
            "75c46f6f3d9eb4f55ecaaee480db732e6c2105546f1e675003687c31719c7ba4"),
    ]
    for n, want_unkeyed, want_keyed in official:
        msg = bytes((i % 251) for i in range(n))
        got_u = spec_hash_unkeyed(msg).hex()
        got_k = spec_hash_keyed(msg, official_key).hex()
        ok_u, ok_k = got_u == want_unkeyed, got_k == want_keyed
        report["checks"].append({
            "check": "official BLAKE3 test vector, length %d" % n,
            "unkeyed_spec": got_u, "unkeyed_expected": want_unkeyed, "unkeyed_ok": ok_u,
            "keyed_spec": got_k, "keyed_expected": want_keyed, "keyed_ok": ok_k,
        })
        if not (ok_u and ok_k):
            fails.append("official vector %d" % n)

    # ---- 1. spec vs the Python package on a length ladder ----------------
    key0 = bytes(range(32))
    ladder = [0, 1, 63, 64, 65, 1023, 1024, 1025, 2048, 4096]
    for n in ladder:
        msg = bytes((i * 7 + 3) % 256 for i in range(n))
        s_u = spec_hash_unkeyed(msg)
        s_k = spec_hash_keyed(msg, key0)
        row = {"len": n, "spec_unkeyed": s_u.hex(), "spec_keyed_key0": s_k.hex()}
        if have_b3:
            row["pkg_unkeyed_ok"] = (ref_unkeyed(msg) == s_u)
            row["pkg_keyed_ok"] = (ref_keyed(msg, key0) == s_k)
            if not (row["pkg_unkeyed_ok"] and row["pkg_keyed_ok"]):
                fails.append("ladder %d" % n)
        report["checks"].append({"check": "spec vs package, length %d" % n, **row})

    # ---- 2. derive_key: re-derive the eight pinned keys ------------------
    for (profile, role), pinned in PINNED.items():
        got = spec_derive_key(CTX[role], profile.encode("utf-8")).hex()
        ok = got == pinned
        entry = {"profile": profile, "role": role, "pinned_in_hashtag_rs": pinned,
                 "spec_derive_key": got, "agrees": ok}
        if have_b3 and hasattr(b3mod, "blake3"):
            try:
                pk = b3mod.blake3(profile.encode("utf-8"),
                                  derive_key_context=CTX[role]).digest().hex()
                entry["python_package"] = pk
                entry["package_agrees"] = (pk == pinned)
            except Exception as e:  # pragma: no cover
                entry["python_package_error"] = str(e)
        report["key_pins"].append(entry)
        if not ok:
            fails.append("key pin %s/%s" % (profile, role))

    # ---- 3. THE CONFORMANCE VECTORS a keyed kernel must reproduce --------
    # column key of each tagged profile, on real column lengths
    shapes = [
        ("empty", 0), ("one row", 1), ("8 rows = 64 B", 8), ("64 rows = 512 B", 64),
        ("127 rows", 127), ("128 rows = 1024 B (one chunk)", 128),
        ("129 rows = 1032 B (first parent)", 129), ("256 rows", 256),
        ("toy A column (455 rows)", 455), ("toy H column (384 rows)", 384),
        ("rung-W14 A column (527 rows)", 527), ("rung-W14 H column (436 rows)", 436),
        ("125M endpoint column (37 rows)", 37), ("mask M column (50 rows)", 50),
        ("125M A column (5681 rows)", 5681), ("125M H column (7120 rows)", 7120),
    ]
    for profile in (RUNG_G, M125):
        ckey = bytes.fromhex(PINNED[(profile, "column")])
        for name, rows in shapes:
            msg = synthetic_column(rows)
            d_keyed = spec_hash_keyed(msg, ckey)
            d_unkeyed = spec_hash_unkeyed(msg)
            d_buggy = buggy_keyed_chunkstart(msg, ckey)
            vec = {
                "profile": profile, "shape": name, "rows": rows, "input_bytes": len(msg),
                "chunks": max(1, (len(msg) + CHUNK_LEN - 1) // CHUNK_LEN),
                "keyed_column_digest": d_keyed.hex(),
                "legacy_unkeyed_digest": d_unkeyed.hex(),
                "chunkstart_only_bug_digest": d_buggy.hex(),
                "bug_is_invisible_here": d_buggy == d_keyed,
                "keyed_differs_from_unkeyed": d_keyed != d_unkeyed,
            }
            if have_b3:
                vec["package_agrees"] = (ref_keyed(msg, ckey) == d_keyed)
                if not vec["package_agrees"]:
                    fails.append("vector %s %s" % (profile, name))
            report["vectors"].append(vec)

    # ---- 4. the trap boundary, stated as a number ------------------------
    boundary = None
    for rows in range(0, 200):
        msg = synthetic_column(rows)
        k = bytes.fromhex(PINNED[(M125, "column")])
        if buggy_keyed_chunkstart(msg, k) != spec_hash_keyed(msg, k):
            boundary = {"first_failing_rows": rows, "first_failing_bytes": rows * 8}
            break
    report["chunkstart_only_bug_boundary"] = boundary

    # ---- 5. a second negative control: wrong key -------------------------
    k1 = bytes.fromhex(PINNED[(M125, "column")])
    k2 = bytes.fromhex(PINNED[(RUNG_G, "column")])
    msg = synthetic_column(527)
    report["negative_controls"] = {
        "keyed_K1_vs_keyed_K2_differ": spec_hash_keyed(msg, k1) != spec_hash_keyed(msg, k2),
        "keyed_K1_vs_unkeyed_differ": spec_hash_keyed(msg, k1) != spec_hash_unkeyed(msg),
        "column_key_vs_leaf_key_differ":
            spec_hash_keyed(msg, k1) != spec_hash_keyed(msg, bytes.fromhex(PINNED[(M125, "leaf")])),
    }

    report["FAILURES"] = fails
    report["VERDICT"] = "ALL AGREE" if not fails else "MISMATCH"

    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, "keyed_vectors.json"), "w") as f:
        json.dump(report, f, indent=1, sort_keys=True)

    print("python blake3 package:", report.get("python_blake3_version", "ABSENT"))
    print("official BLAKE3 vectors (unkeyed+keyed, len 0/1/1024):",
          all(c.get("unkeyed_ok", True) and c.get("keyed_ok", True) for c in report["checks"]))
    print("eight derived key pins re-derived from the spec:",
          all(e["agrees"] for e in report["key_pins"]))
    print("chunk-start-only keyed bug first shows at:", boundary)
    print("negative controls:", report["negative_controls"])
    print("VERDICT:", report["VERDICT"], "failures:", fails)
    print()
    print("%-34s %6s %7s %6s  %s" % ("shape", "rows", "bytes", "chunks", "keyed column digest (m125 column key)"))
    for v in report["vectors"]:
        if v["profile"] != M125:
            continue
        print("%-34s %6d %7d %6d  %s%s" % (
            v["shape"], v["rows"], v["input_bytes"], v["chunks"], v["keyed_column_digest"],
            "   <- chunk-start-only bug INVISIBLE" if v["bug_is_invisible_here"] else ""))


if __name__ == "__main__":
    main()
