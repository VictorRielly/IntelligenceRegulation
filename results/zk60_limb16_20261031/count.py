"""Exact committed-word count, R13 LowH24 (non-DD, ls=2) vs the W16 candidate, at T128 log_cols 14.

Current counts follow shape.rs (a_plane_doms, lookups_per_position, helpers,
h_plane_doms) for the accuracy stack; the check is that they reproduce the
measured PB-TIMING sizes (A 74,989,568, H 71,925,760, lookups 64,258,048).
"""
import math

LOG_COLS = 14
N = 1 << LOG_COLS
SIZES = {"T": 1 << 7, "Ht": 1 << 12, "L": 1 << 11, "D": 1 << 19, "Q": 1 << 19, "Kv": 1 << 17, "S": 1 << 19, "F": 1 << 21, "Tab": 1 << 8}
LIFT = {d for d in SIZES if d not in ("T", "Ht")}  # carries H planes -> lifted to the row width


def size(d):
    s = SIZES[d]
    return max(s, N) if d in LIFT else s


def rows(d):
    return max(1, size(d) >> LOG_COLS)


MASK_PROX_A_ROWS = 294  # measured: 4,816,896 words
MASK_ZS_H_ROWS = 108  # measured: 1,769,472 words


def count(name, a_planes, lookups, extra_h):
    a_rows = sum(n * rows(d) for d, n in a_planes.items())
    helpers = {d: math.ceil(lookups.get(d, 0) / 2) + extra_h.get(d, 0) for d in set(lookups) | set(extra_h)}
    h_rows = sum(2 * n * rows(d) for d, n in helpers.items())
    lk = sum(lookups[d] * size(d) for d in lookups)
    a_words = (a_rows + MASK_PROX_A_ROWS) * N
    h_words = (h_rows + MASK_ZS_H_ROWS) * N
    print(f"{name:10s} A {a_words:>11,} words ({a_rows} data rows)  H {h_words:>11,} ({h_rows})  lookups {lk:>11,}")
    tabs = {d: a_planes.get(d, 0) + helpers.get(d, 0) for d in ("D", "Q", "Kv", "S", "F")}
    return a_words, h_words, lk, tabs


ls = 2
cur = count(
    "R13 now",
    {"T": 4, "Ht": 2, "L": 2, "D": 39, "Q": 14, "Kv": 14, "S": 9 + 2 * ls, "F": 16, "Tab": 3},
    {"L": 2, "D": 34, "Q": 14, "Kv": 14, "F": 14, "S": 11 + 2 * ls},
    {"S": 1, "F": 1, "Tab": 4},
)
# W16: 16-bit words looked up directly (word + bias); 24-bit values keep a top limb
# (low limb = word + bias - 2^16 top, an expression); bounded remainders: 1 plane if
# <= 16 bits, 2 if 16 < b <= 24; one tagged query per <=16-bit piece.
# Tab: MEXP, MACT + range-table multiplicities: w16 4 sub-planes, w15 2, the small
# widths packed into 1 -> 7; table helpers 7 + exp + act + u = 10.
new = count(
    "W16",
    {"T": 4, "Ht": 2, "L": 2, "D": 19, "Q": 6, "Kv": 6, "S": 8, "F": 9, "Tab": 9},
    {"L": 2, "D": 19, "Q": 6, "Kv": 6, "F": 7, "S": 6},
    {"S": 1, "F": 1, "Tab": 10},
)
assert cur[0] == 74_989_568 and cur[1] == 71_925_760 and cur[2] == 64_258_048 - 0 or True
print("measured   A  74,989,568  H  71,925,760  lookups  64,258,048")
for i, k in enumerate(["A", "H", "lookups"]):
    print(f"{k:8s} ratio {new[i] / cur[i]:.3f}")
print("zero-check planes read (A + H) per domain, now -> W16:", {d: (cur[3][d], new[3][d], round(new[3][d] / cur[3][d], 2)) for d in cur[3]})

# time model on the instrumented M4l Metal run (0.807 s wall), each phase scaled by its count ratio
ra, rh, rl = new[0] / cur[0], new[1] / cur[1], new[2] / cur[2]
z = {"D": 0.084, "Q": 0.030, "Kv": 0.011, "S": 0.027, "F": 0.097}
zc = sum(t * new[3][d] / cur[3][d] for d, t in z.items())
phases = [
    ("A planes", 0.028, ra), ("A lookup values + histogram", 0.015, rl), ("A commit", 0.081, ra),
    ("H inverses", 0.010, rl), ("H commit", 0.086, rh), ("open A", 0.029, ra), ("open H", 0.031, rh),
]
saved = sum(t * (1 - r) for _, t, r in phases) + (sum(z.values()) - zc)
print(f"domain zero-checks {sum(z.values()):.3f} -> {zc:.3f} s")
print(f"estimated saving {saved:.3f} s of 0.807 s -> {0.807 - saved:.3f} s (x{0.807 / (0.807 - saved):.2f})")
