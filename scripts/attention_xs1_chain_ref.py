#!/usr/bin/env python3
"""[UPERF3-JJ] X-S1 rungs 1/5 — the Python side of the chain cross-check
(acceptance c). Usage: python3 attention_xs1_chain_ref.py [--cal] [seed] [t];
diff the output byte-for-byte against `ring_matmul uperf-x chain[-cal]`.

Drives scripts/attention_spec_spike.py's OWN machinery (softmax_int,
exp_table_generate, exp_table_digest — imported, not reimplemented) on
the lane's seeded s8 draw, and prints per-tensor sha256 digests in the
exact format `ring_matmul uperf-x chain` prints, for a byte-for-byte
diff (acceptance c).

Seeded s8 draw (lane-local convention, ledger-recorded): block i =
SHA256(le64(seed) || le64(i)); each byte b -> (b % 255) - 127.

Usage: python3 xs1_chain_ref.py [seed] [t]
"""
import hashlib
import importlib.util
import os
import struct
import sys

import numpy as np

SPIKE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "attention_spec_spike.py")
spec = importlib.util.spec_from_file_location("attention_spec_spike", SPIKE)
oracle = importlib.util.module_from_spec(spec)
spec.loader.exec_module(oracle)

E_S = -1          # the statement member (spec layer-0 example)
HEAD_DIM = 64
F_E = oracle.F_E  # 9
F_P = oracle.F_P  # 9


def seeded_s8(seed, n):
    out = []
    ctr = 0
    while len(out) < n:
        block = hashlib.sha256(struct.pack("<QQ", seed, ctr)).digest()
        for b in block:
            if len(out) == n:
                break
            out.append((b % 255) - 127)
        ctr += 1
    return np.array(out, dtype=np.int64)


def calibrated_s8(seed, n):
    """The rung-5 integer-exact Irwin-Hall map (see attn_softmax.rs
    calibrated_s8): s = sum of 16 raw stream bytes over the
    SHA256(seed || b"cal" || ctr) stream; s8 = clamp((s-2040)*3121 >> 15,
    -103, 103)."""
    raw = bytearray()
    ctr = 0
    while len(raw) < n * 16:
        raw += hashlib.sha256(struct.pack("<Q", seed) + b"cal" + struct.pack("<Q", ctr)).digest()
        ctr += 1
    out = np.empty(n, dtype=np.int64)
    for i in range(n):
        sv = sum(raw[i * 16:(i + 1) * 16])
        v = ((sv - 2040) * 3121) >> 15
        out[i] = max(-103, min(103, v))
    return out


def dig(v):
    return hashlib.sha256(np.ascontiguousarray(v, "<i8").tobytes()).hexdigest()


def main():
    cal = "--cal" in sys.argv
    args = [a for a in sys.argv[1:] if a != "--cal"]
    seed = int(args[0]) if len(args) > 0 else 161
    t = int(args[1]) if len(args) > 1 else 512
    es = -2 if cal else E_S
    other = -1 if es == -2 else -2
    s8 = (calibrated_s8 if cal else seeded_s8)(seed, t * t).reshape(t, t)

    tab = oracle.exp_table_generate(es, HEAD_DIM)
    tab_dig = oracle.exp_table_digest(es, HEAD_DIM, F_E, tab)
    tab_dig_m2 = oracle.exp_table_digest(
        other, HEAD_DIM, F_E, oracle.exp_table_generate(other, HEAD_DIM))
    exp_tab = np.array(tab, dtype=np.int64)

    # THE ORACLE'S OWN CHAIN (softmax_int verbatim).
    p, sums, dmat, mrow = oracle.softmax_int(s8, exp_tab, "xs1")

    # The internals softmax_int derives but does not return, recomputed
    # by the SAME expressions (verbatim lines from softmax_int).
    mask = np.tril(np.ones((t, t), dtype=np.int64))
    maskc = 1 - mask
    sm = mask * s8 + maskc * (-127)
    zsel = np.zeros_like(sm)
    zsel[np.arange(t), sm.argmax(axis=1)] = 1
    e = exp_tab[dmat]
    num = e.astype(np.int64) << F_P
    rho = np.where(mask == 1, num - p * sums[:, None], 0)
    sig = np.where(mask == 1, sums[:, None] - 1 - rho, 0)

    tensors = [
        ("s8", s8), ("m", mrow), ("zsel", zsel), ("d", dmat), ("E", e),
        ("Sum", sums), ("P", p), ("rho", rho), ("sigma", sig),
    ]
    tag = "-cal" if cal else ""
    print(f"[UPERF3-JJ] chain{tag} seed {seed} t {t} eS {es} d_h {HEAD_DIM} fE {F_E} fP {F_P}")
    print(f"  exp-member(eS {es})  {tab_dig}")
    print(f"  exp-member(eS {other})  {tab_dig_m2}")
    combined = hashlib.sha256()
    for name, v in tensors:
        d = dig(v)
        combined.update(bytes.fromhex(d))
        print(f"  {name:<6} {d}")
    print(f"  CHAIN  {combined.hexdigest()}")


if __name__ == "__main__":
    main()
