#!/usr/bin/env python3
"""Reviewer's independent reference for R-C2's development-rung tied source (round 13 review).

Written from the CONTRACT text (classify_tied.rs module doc + native R12b derive.rs quantizer:
binary64 floor(x/scale + 0.5), refusal outside the class, no clipping, final-norm weights folded
into the margin row once, no rotation at the dev rung), not from the lane's Python script.

Differences from the lane's `r13/tools/dev_tied_reference.py`:
  * BF16 is decoded by hand (sign / exponent / mantissa) into exact Fractions, not via struct float;
  * every quantization is computed twice: exactly (Fraction) and in binary64 (Python float, IEEE
    correctly rounded division, as Rust f64); the digests use binary64 (the contract) and every
    coordinate where the two differ is counted (a tie or near-tie hazard);
  * the swapped policy (yes/no = 41/40) is derived too, and w + w' is checked to be in {0, 1};
  * the refusal edge is scanned over scales 2^-6 .. 2^-14 (requirement 4's margin).
The tensor bytes come from the pinned generator's definition (the pin IS those bytes): an LCG
s <- s*6364136223846793005 + 1442695040888963407 mod 2^64 seeded 0x74696564_2d646576, r = s >> 33;
rows: sign r&1, exponent 120 + (r>>1)%12, mantissa (r>>5)&0x7f; norm weights: exponent 126+(r&1),
mantissa (r>>1)&0x7f, positive. The rung export's s_x is read from the Rust fixture writer
(trained_block_tests.rs, `residual_scale_s_x`) by regex, not typed in.

Usage: python3 -I rv13_dev_tied_reference.py OUT.json [tensor_file_to_compare ...]
"""
import hashlib
import json
import math
import re
import struct
import sys
from fractions import Fraction

TREE = "/home/victor/IntelligenceRegulation/ops/zkp-mvp/token-io-review-r13-scratch/hashline/src/private_block"
V, D = 300, 384
M64 = 1 << 64


def gen_bits():
    s = 0x7469_6564_2D64_6576
    out = []
    for k in range(V * D + D):
        s = (s * 6364136223846793005 + 1442695040888963407) % M64
        r = s >> 33
        if k < V * D:
            sign, exp, man = r & 1, 120 + (r >> 1) % 12, (r >> 5) & 0x7F
        else:
            sign, exp, man = 0, 126 + (r & 1), (r >> 1) & 0x7F
        out.append((sign << 15) | (exp << 7) | man)
    return out


def bf16_exact(w):
    sign, exp, man = w >> 15, (w >> 7) & 0xFF, w & 0x7F
    assert 0 < exp < 255, "only normal numbers are generated"
    val = Fraction(128 + man, 128) * (Fraction(2) ** (exp - 127))
    return -val if sign else val


def q_exact(x, s):
    return math.floor(x / s + Fraction(1, 2))


def q_f64(x, s):
    return math.floor(float(x) / s + 0.5)


def main():
    out_path = sys.argv[1]
    src = open(f"{TREE}/trained_block_tests.rs").read()
    m = re.search(r'residual_scale_s_x\\": ([0-9.eE+-]+)\}', src)
    s_x = float(m.group(1))
    bits = gen_bits()
    tb = b"".join(struct.pack("<H", w) for w in bits)
    vals = [bf16_exact(w) for w in bits]
    E = [vals[r * D:(r + 1) * D] for r in range(V)]
    g = vals[V * D:]
    res = {"s_x": s_x, "s_x_hex": s_x.hex(), "tensor_bytes": len(tb), "tensor_sha256": hashlib.sha256(tb).hexdigest()}
    # embedding: no rotation; row -> binary32 -> binary64 is exact for BF16
    emb, emb_disagree, emb_ties = [], 0, 0
    sF = Fraction(s_x)
    for row in E:
        for x in row:
            a, b = q_exact(x, sF), q_f64(x, s_x)
            emb_disagree += a != b
            emb_ties += (x / sF + Fraction(1, 2)).denominator == 1
            assert -32768 <= b <= 32767
            emb.append(b)
    eb = struct.pack(f"<{len(emb)}h", *emb)
    res.update(embedding_sha256=hashlib.sha256(eb).hexdigest(), embedding_absmax=max(map(abs, emb)),
               embedding_exact_vs_f64_disagreements=emb_disagree, embedding_exact_ties=emb_ties)

    def margin(yes, no, scale):
        sc = Fraction(scale)
        w, dis, ties, inexact = [], 0, 0, 0
        for i in range(D):
            x = (E[yes][i] - E[no][i]) * g[i]
            xf = (float(E[yes][i]) - float(E[no][i])) * float(g[i])  # what binary64 computes
            inexact += Fraction(xf) != x
            a, b = q_exact(x, sc), math.floor(xf / scale + 0.5)
            dis += a != b
            ties += (x / sc + Fraction(1, 2)).denominator == 1
            w.append(b)
        refused = sum(1 for v in w if not -32767 <= v <= 32767)
        return w, {"refused_outside_int16_sym": refused, "f64_product_inexact": inexact,
                   "exact_vs_f64_disagreements": dis, "exact_ties": ties}

    w, info = margin(40, 41, 2.0 ** -8)
    assert info["refused_outside_int16_sym"] == 0
    wb = struct.pack(f"<{D}h", *w)
    res["dev_policy"] = dict(yes=40, no=41, scale=2.0 ** -8, sha256=hashlib.sha256(wb).hexdigest(),
                             absmax=max(map(abs, w)), first8=w[:8], **info)
    ws, infos = margin(41, 40, 2.0 ** -8)
    wsb = struct.pack(f"<{D}h", *ws)
    sums = sorted(set(a + b for a, b in zip(w, ws)))
    res["swapped_policy"] = dict(yes=41, no=40, scale=2.0 ** -8, sha256=hashlib.sha256(wsb).hexdigest(),
                                 absmax=max(map(abs, ws)), w_plus_wswapped_values=sums, **infos)
    edge = {}
    for k in range(6, 15):
        _, inf = margin(40, 41, 2.0 ** -k)
        edge[f"2^-{k}"] = inf["refused_outside_int16_sym"]
    res["refusals_by_scale"] = edge
    # compare any tensor files given (e.g. the fixture's copy in a capture or test dir)
    res["compared_files"] = {}
    for p in sys.argv[2:]:
        b = open(p, "rb").read()
        res["compared_files"][p] = {"bytes": len(b), "sha256": hashlib.sha256(b).hexdigest(), "equal_to_generated": b == tb}
    json.dump(res, open(out_path, "w"), indent=1)
    print(json.dumps(res, indent=1))


if __name__ == "__main__":
    main()
