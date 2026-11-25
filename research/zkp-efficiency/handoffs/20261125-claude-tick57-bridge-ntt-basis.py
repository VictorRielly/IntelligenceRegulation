#!/usr/bin/env python3
"""Tick 57 (queue item 97): why the spike's bridge runs a forward NTT before the device commit.

Standard library only, under a second. Reads the retained spike record (measure.log) and two
retained device logs, and does arithmetic. Part A is a toy-size check of the identity the answer rests
on: encoding coefficients on the CPU tower's route equals the device route fed with their evaluations
(inverse transform, coset powers, zero pad, forward transform). The conventions restated below come
from ntt.rs:55-67 (forward = coefficients -> evaluations, inverse = evaluations -> coefficients with
the 1/n scale), pcs.rs:674-691 (encode_row_zk) and tower.rs:72-92 (CoefficientRs::encode).
"""
import re
import statistics as st

P = 0xFFFFFFFF00000001  # Goldilocks
G = 7                   # a generator of the multiplicative group (7 is the coset shift used here too)


def root_of_unity(n):
    return pow(G, (P - 1) // n, P)


def dft(a, inverse=False):  # naive size-n transform, toy sizes only
    n = len(a)
    w = root_of_unity(n)
    if inverse:
        w = pow(w, P - 2, P)
    out = []
    for k in range(n):
        wk = pow(w, k, P)
        acc, x = 0, 1
        for v in a:
            acc = (acc + v * x) % P
            x = x * wk % P
        out.append(acc)
    if inverse:
        ninv = pow(n, P - 2, P)
        out = [v * ninv % P for v in out]
    return out


def cpu_tower_encode(coeff, positions, coset=7):
    # tower.rs:72-92: coefficient i times coset^i, zero pad to `positions`, forward NTT of size positions
    row = [0] * positions
    p = 1
    for i, c in enumerate(coeff):
        row[i] = c * p % P
        p = p * coset % P
    return dft(row)


def device_route(evals, positions, pad, coset=7):
    # pcs.rs:674-691 encode_row_zk (the device route does the same): inverse of size n, subtract the pad
    # from the low coefficients and put it at n.., multiply by coset powers, forward NTT of size nn
    n, q = len(evals), len(pad)
    coeffs = dft(evals, inverse=True)
    out = coeffs + [0] * (positions - n)
    for i in range(q):
        out[i] = (out[i] - pad[i]) % P
        out[n + i] = pad[i]
    p = 1
    for i in range(n + q):
        out[i] = out[i] * p % P
        p = p * coset % P
    return dft(out)


import random
random.seed(57)
n, positions = 16, 64
coeff = [random.randrange(P) for _ in range(n)]
evals = dft(coeff)                       # the bridge's forward NTT (spike :59-67, 96 rows of 2^14)
cpu = cpu_tower_encode(coeff, positions)
dev = device_route(evals, positions, [0])  # the spike passes one zero pad word per row (zeros = vec![0; W_ROWS])
print("A. toy identity, n=16, positions=64, q=1 zero pad: CPU tower encode == device route on forward(coeff):", cpu == dev)
dev2 = device_route(dft(coeff), positions, [5])
print("A. with a nonzero pad the codeword differs (so the pad is what the hiding commit adds):", cpu != dev2)

# ---------------------------------------------------------------- B. the host cost of the bridge (MEASURED)
LOG = ("/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116/"
       "b6a_wp0/qualification-wp0/attempt-00/measure.log")
text = open(LOG).read()


def med(rate, key):
    vals = []
    for m in re.finditer(r"B6A-M1-METAL rate=1/%d iteration=(\d+) warm=(\w+) gpu_ms=([\d.]+) encode_wall_ms=([\d.]+) "
                         r"prep_host_ms=([\d.]+) salt_tree_host_ms=([\d.]+)" % rate, text):
        if m.group(2) == "false":
            vals.append(float(m.group({"gpu": 3, "wall": 4, "prep": 5, "tree": 6}[key])))
    return st.median(vals), len(vals)


ROWS, N = 96, 1 << 14
bfly = ROWS * (N // 2) * 14
print("\nB. bridge: %d rows x (2^14/2 x 14) = %d butterflies; the copy of the rows is %.1f MB (96 x 2^14 x 8 B)" %
      (ROWS, bfly, ROWS * N * 8 / 1e6))
gpu = {}
for rate in (8, 4, 2):
    prep, k = med(rate, "prep")
    g, _ = med(rate, "gpu")
    w, _ = med(rate, "wall")
    gpu[rate] = g
    print("   rate 1/%d (%d measured iterations): prep_host %.2f ms (NTT on 5 threads + copy), commit gpu %.2f ms, "
          "encode wall %.2f ms; prep / gpu = %.1f" % (rate, k, prep, g, w, prep / g))
print("   prep host per butterfly: %.3f ns all-in (copy included)" % (med(4, "prep")[0] * 1e6 / bfly))

# ---------------------------------------------------------------- C. device inverse share (MEASURED, staged-timing logs)
# '[ZK60-METAL] commit R x 2^14 -> 2^16: ... (inverse a, init 0.000, forward b, hash c)' from the retained
# TinyLlama golden logs (results/zk60_d55_20261101/logs/golden_metal_tinyllama_t128_dd.log and the
# t128 block log beside it); staged command buffers (each part timed alone), 3-decimal seconds.
lines = [
    (1871, 0.057, 0.008, 0.029, 0.003), (2026, 0.048, 0.009, 0.032, 0.003), (3283, 0.089, 0.014, 0.051, 0.004),
    (3634, 0.082, 0.015, 0.057, 0.005), (3405, 0.092, 0.014, 0.053, 0.004), (3790, 0.086, 0.016, 0.059, 0.005),
    (1993, 0.060, 0.008, 0.032, 0.003), (2182, 0.051, 0.009, 0.034, 0.003),
]
share = [inv / tot for _, tot, inv, _, _ in lines]
per_row_us = [inv / r * 1e6 for r, _, inv, _, _ in lines]
fwd_row_us = [f / r * 1e6 for r, _, _, f, _ in lines]
print("\nC. staged logs, rate 1/4 at 2^14 -> 2^16 (8 lines, TinyLlama golden logs, a different row count from the spike's 96): inverse share of the "
      "commit's device total %.0f to %.0f%%; inverse %.1f to %.1f us a row, forward %.1f to %.1f us a row" %
      (100 * min(share), 100 * max(share), min(per_row_us), max(per_row_us), min(fwd_row_us), max(fwd_row_us)))
print("   at 96 rows: inverse %.2f to %.2f ms in those staged timings (they split one buffer into parts, so an upper reading)" %
      (96 * min(per_row_us) / 1e3, 96 * max(per_row_us) / 1e3))
lo = min(share) * gpu[4]
hi = max(share) * gpu[4]
print("   share applied to the spike's own median commit gpu at 1/4 (%.2f ms): %.2f to %.2f ms the inverse pass costs on the device" %
      (gpu[4], lo, hi))

# ---------------------------------------------------------------- D. what the host would stop doing
prep4 = med(4, "prep")[0]
print("\nD. removing the bridge returns the whole prep timer (%.1f ms at 1/4: the 12.6 MB `to_vec` copy that lets the rows be "
      "transformed in place, plus the 5-thread forward NTTs); the upload the device does stays inside the commit's encode wall, "
      "so nothing is added back. The device sheds %.2f to %.2f ms (C)." % (prep4, lo, hi))
print("   against the +99 ms spike gap at 1/4 (tick 56): %.1f ms of host time, 0 committed words changed" % prep4)
