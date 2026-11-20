#!/usr/bin/env python3
"""Cycle 6c (2026-11-16): which committed activation planes of one W16R2 block need not be committed, and the
combined volume of the three cycle 6 levers (6a lookups, 6b small field, 6c derived planes).

Run:  python3 -I research/zkp-efficiency/handoffs/20261116-claude-cycle6c-linear-chains.py
Standard library only, reads no file, writes nothing. Counting only. Labels: COUNTED (source line), DERIVED, ASSUMED.

PLANE LIST (COUNTED): accuracy_layout.rs:122-160 (`new_w16`), shape.rs:2466-2489 (`a_plane_doms`), limb counts from
`range16::limbs_of` (range16.rs:114: 1 limb up to 16 bits, else 2). The W16R2 limb counts are DERIVED from the census
plane counts (census.log:218-237): D 19 = 15 + ao + down  =>  ao = down = 2; S 8 = 4 + score + 2*ws  =>  score = 2, ws = 1;
F 9 = 4 + gate + 1 + h24 + rh with h24 = rh = 1  =>  gate = 2. Cross-check against the census's lookups per position
(L2 D19 Q6 Kv6 F7 S7): D 7+8+2+2 = 19, S 2+score+1+2*ws = 7, F gate+1+1+2+rh = 7. All match.
"""

ROWS = {"D": 32, "Q": 32, "Kv": 8, "S": 32, "F": 128, "T": 1, "Ht": 1, "L": 1, "Tab": 1}   # rows per plane (cycle 4)

# (domain, plane, class, why / relation, source)
#  M  = must commit: chain input, output of a rounding / lookup / division / norm, a digit witness, or the committed form
#       of an UNcommitted accumulator (a matmul output is carried as 2^s * word + remainder limbs: host_* terms)
#  L1 = linear (or public-table elementwise) image of other committed planes
#  L2 = pointwise degree-2 image of committed planes (single-limb remainder that the relation determines)
#  L3 = top limb of a two-limb remainder whose total is pointwise determined by committed planes and the low limb
SRC_D = "slot_ir_accuracy.rs:483-488"          # c0 norm_a, c1, c2 residual 1, c3 norm_m, c4, c5 residual 2 (dzc_w16)
SRC_F = "slot_ir_accuracy.rs:534-537"          # f0 product relation (fzc_w16)
SRC_Q = "slot_ir_accuracy.rs:596-605"          # rope clause (qzc_w16)
SRC_S = "slot_ir_accuracy.rs:672-679"          # c2, c3 softmax division (szc_w16)
SRC_H = "slot_ir_accuracy.rs:494-495, 611-612, 693-695"   # host_* requantisation terms: acc = 2^s word + remainder - half
planes = [
    ("D", "X", "M", "block input (chain; equals previous block's X2 via the boundary link)", "accuracy_layout.rs:125"),
    ("D", "Y", "M", "norm_a output (division with remainder)", SRC_D),
    ("D", "NR0", "M", "norm remainder, low digit", SRC_D), ("D", "NR1", "L3", "top limb: nr = num*ig*x + dv*id - den*y*id is pointwise", SRC_D),
    ("D", "NS0", "M", "norm remainder ns = den*id - 1 - nr, low digit", SRC_D), ("D", "NS1", "L3", "top limb of ns, affine in id and nr", SRC_D),
    ("D", "AO", "M", "requantised Wo*O (accumulator uncommitted)", SRC_H), ("D", "RAL0", "M", "requant remainder digit (committed form of acc)", SRC_H),
    ("D", "RAL1", "M", "requant remainder digit", SRC_H),
    ("D", "X1", "L1", "x1 = x + ao  (c2)", SRC_D),
    ("D", "YM", "M", "norm_m output", SRC_D),
    ("D", "MR0", "M", "norm_m remainder, low digit", SRC_D), ("D", "MR1", "L3", "top limb", SRC_D),
    ("D", "MS0", "M", "norm_m remainder, low digit", SRC_D), ("D", "MS1", "L3", "top limb", SRC_D),
    ("D", "Z", "M", "requantised Wd*H", SRC_H), ("D", "RDL0", "M", "requant remainder digit", SRC_H), ("D", "RDL1", "M", "requant remainder digit", SRC_H),
    ("D", "X2", "L1", "x2 = x1 + z  (c5); also the boundary commitment's content", SRC_D),
    ("Q", "Q", "M", "requantised Wq*Y", SRC_H), ("Q", "RQL", "M", "requant remainder", SRC_H),
    ("Q", "QR", "M", "rounded rope output", SRC_Q), ("Q", "RQRL", "L1", "rem = cos*q + sin*flip(q) - 2^SH*qr + c, public cos, sin", SRC_Q),
    ("Q", "O", "M", "requantised P*V", SRC_H), ("Q", "RO", "M", "requant remainder", SRC_H),
    ("Kv", "K", "M", "requantised Wk*Y", SRC_H), ("Kv", "RKL", "M", "requant remainder", SRC_H),
    ("Kv", "V", "M", "requantised Wv*Y", SRC_H), ("Kv", "RVL", "M", "requant remainder", SRC_H),
    ("Kv", "KR", "M", "rounded rope output", SRC_Q), ("Kv", "RKRL", "L1", "rope remainder (as RQRL)", SRC_Q),
    ("S", "S", "M", "requantised QR*KR^T (score)", SRC_H), ("S", "RSL0", "M", "requant remainder digit", SRC_H), ("S", "RSL1", "M", "requant remainder digit", SRC_H),
    ("S", "ZSEL", "M", "row-max selector (nonlinear)", "slot_ir_accuracy.rs:670-671"),
    ("S", "E", "M", "exp-table output (pulled-back array, read pointwise in c2)", "slot_ir_accuracy.rs:672-675, 680-684"),
    ("S", "P", "M", "division quotient", SRC_S),
    ("S", "SR0", "L2", "sr = 2^fp*mask*e - p*sum (single 16-bit limb, determined)", SRC_S),
    ("S", "SG0", "L2", "sg = sum - 1 - sr (single limb, determined)", SRC_S),
    ("F", "G", "M", "requantised Wg*YM", SRC_H), ("F", "RGL0", "M", "requant remainder digit", SRC_H), ("F", "RGL1", "M", "requant remainder digit", SRC_H),
    ("F", "A_SCALED", "M", "SiLU table output (pulled-back array)", "slot_ir_accuracy.rs:538-550"),
    ("F", "U", "M", "requantised Wu*YM", SRC_H), ("F", "RU", "M", "requant remainder", SRC_H),
    ("F", "H", "M", "rounded product a*u (24-bit word)", SRC_F), ("F", "HT", "M", "top limb of the 24-bit word (digit extraction)", "accuracy_layout.rs:154"),
    ("F", "RH", "L2", "rh = a*u - 2^r*h + 2^(r-1) (single 16-bit limb, determined)", SRC_F),
]
dom_counts = {}
for d, *_ in planes:
    dom_counts[d] = dom_counts.get(d, 0) + 1
assert dom_counts == {"D": 19, "Q": 6, "Kv": 6, "S": 8, "F": 9}, dom_counts      # census.log:218-237

per_class = {"M": 0, "L1": 0, "L2": 0, "L3": 0}
for d, name, cls, why, src in planes:
    per_class[cls] += ROWS[d]
# per-token and table planes: T 4, Ht 2, L 2 (one row each) and Tab 15: all M
per_class["M"] += 4 + 2 + 2 + 15
total = sum(per_class.values())
assert total == 2279, total                                                          # census.log: data rows 2279
print("A data rows per block by class:", per_class, "total", total)
for k, v in per_class.items():
    print(f"  {k}: {v} rows = {100*v/2279:.1f}% of A data rows, {100*v/5103:.1f}% of the 5,103 committed rows")

# --- volume (reuse 6a/6b bookkeeping) ----------------------------------------------------------------------------
N, INV_RATE, BLOCKS = 1 << 14, 2, 32
SMALL, HELP, MASK = 2279, 2514, 310
OTHER = 1178 + 74
M_BYTES = 32 * 50 * 4096 * 8


def req_bytes(small, helpers, masks, sb=8, hb=8, mb=8, extra_m=0):
    per_block = (small * sb + helpers * hb + masks * mb) * N * INV_RATE
    return BLOCKS * per_block + OTHER * sb * N * INV_RATE + M_BYTES + BLOCKS * extra_m * 4096 * 8


base = req_bytes(SMALL, HELP, MASK)
print(f"\ntoday {base/1e9:.2f} GB codewords per request")
l1, l2, l3 = per_class["L1"], per_class["L2"], per_class["L3"]
for name, cut in (("C-a  L1 only (linear / public-elementwise)", l1), ("C-b  L1 + L2 (adds degree-2 single-limb)", l1 + l2),
                  ("C-c  L1 + L2 + L3 (adds top limbs)", l1 + l2 + l3)):
    b = req_bytes(SMALL - cut, HELP, MASK)
    print(f"{name}: -{cut} rows/block ({100*cut/5103:.1f}%); {b/1e9:.2f} GB ({100*b/base:.1f}%)")

cut = l1 + l2 + l3
print("\ncombined (DERIVED; additivity is an assumption, see handoff section 5):")
g2_h, g2_m = 2, 310
b_ac = req_bytes(SMALL - cut, g2_h, g2_m, extra_m=96)
print(f"6a G2 + 6c C-c:                      {b_ac/1e9:.2f} GB ({100*b_ac/base:.1f}%)")
b_acb = req_bytes(SMALL - cut, g2_h, g2_m, sb=4, hb=8, mb=4, extra_m=96)
print(f"6a G2 + 6c C-c + 6b B2 (31-bit base): {b_acb/1e9:.2f} GB ({100*b_acb/base:.1f}%)")
b_a = req_bytes(SMALL, g2_h, g2_m, extra_m=96)
b_ab = req_bytes(SMALL, g2_h, g2_m, sb=4, hb=8, mb=4, extra_m=96)
print(f"6a G2 alone:                          {b_a/1e9:.2f} GB ({100*b_a/base:.1f}%);  G2 + B2: {b_ab/1e9:.2f} GB ({100*b_ab/base:.1f}%)")

# --- what the commit work is worth (MEASURED anchor: 20261101-logup-gkr-w16.md: commits A + H 0.096 s per block on Metal) ---
us_per_row = 0.096 / 5103 * 1e6
print(f"\ncommit time per row, Metal, measured anchor: {us_per_row:.1f} us; {cut} rows = {cut*us_per_row/1e3:.1f} ms of the 470 ms warm block "
      f"({100*cut*us_per_row/1e6/0.47:.1f}%)")
open_bytes = cut * 280 * 8
print(f"opened column data saved per block: {cut} x 280 x 8 B = {open_bytes/1e6:.2f} MB ({100*cut/ (2501+2602):.1f}% of the 372/32 = 11.6 MB per block)")
