#!/usr/bin/env python3
"""R-2 supporting arithmetic: the layout counts the no-wraparound argument
depends on - which plane is ranged by which lookup, how many lookups exist,
and which planes are NOT directly ranged (so their bound must be derived).

Transcribed from hashline/src/private_attention/layout.rs.
Read-only.
"""
T, D, H, DH, KV, N = 32, 16, 2, 8, 8, 256
LOG = {"T": 5, "Ht": 6, "L": 9, "D": 9, "Q": 9, "Kv": 8, "S": 11, "Tab": 8}

PLANES = [  # (name, domain) in A_* id order, layout.rs:90-136
    ("A_D", "T"), ("A_DSQ", "T"), ("A_MX", "Ht"), ("A_SUM", "Ht"), ("A_LIMB", "L"),
    ("A_X", "D"), ("A_XL0", "D"), ("A_XL1", "D"), ("A_Y", "D"),
    ("A_NR0", "D"), ("A_NR1", "D"), ("A_NR2", "D"), ("A_NR3", "D"),
    ("A_NS0", "D"), ("A_NS1", "D"), ("A_NS2", "D"), ("A_NS3", "D"),
    ("A_AO", "D"), ("A_AL0", "D"), ("A_AL1", "D"), ("A_RAL", "D"),
    ("A_X1", "D"), ("A_X1L0", "D"), ("A_X1L1", "D"),
    ("A_Q8", "Q"), ("A_RQL", "Q"), ("A_QR8", "Q"), ("A_RQRL", "Q"),
    ("A_O8", "Q"), ("A_RO0", "Q"), ("A_RO1", "Q"),
    ("A_K8", "Kv"), ("A_RKL", "Kv"), ("A_V8", "Kv"), ("A_RVL", "Kv"),
    ("A_KR8", "Kv"), ("A_RKRL", "Kv"),
    ("A_S8", "S"), ("A_RSL", "S"), ("A_ZSEL", "S"), ("A_E", "S"), ("A_P", "S"),
    ("A_PL0", "S"), ("A_PL1", "S"), ("A_SR0", "S"), ("A_SR1", "S"),
    ("A_SG0", "S"), ("A_SG1", "S"), ("A_MU8", "Tab"), ("A_MEXP", "Tab"),
]

LOOKUPS = {   # domain -> list of (plane, scale) ; sym() contributes two rows
    "L": [("A_LIMB", 1)],
    "D": [("A_XL0", 1), ("A_XL1", 1), ("A_Y", "sym+"), ("A_Y", "sym-"),
          ("A_NR0", 1), ("A_NR1", 1), ("A_NR2", 1), ("A_NR3", 1), ("A_NR3", 8),
          ("A_NS0", 1), ("A_NS1", 1), ("A_NS2", 1), ("A_NS3", 1), ("A_NS3", 8),
          ("A_AL0", 1), ("A_AL1", 1), ("A_RAL", 1), ("A_RAL", 2),
          ("A_X1L0", 1), ("A_X1L1", 1)],
    "Q": [("A_Q8", "sym+"), ("A_Q8", "sym-"), ("A_RQL", 1), ("A_RQL", 2),
          ("A_QR8", "sym+"), ("A_QR8", "sym-"), ("A_RQRL", 1), ("A_RQRL", 2),
          ("A_O8", "sym+"), ("A_O8", "sym-"), ("A_RO0", 1), ("A_RO1", 1), ("A_RO1", 128)],
    "Kv": [("A_K8", "sym+"), ("A_K8", "sym-"), ("A_RKL", 1), ("A_RKL", 2),
           ("A_V8", "sym+"), ("A_V8", "sym-"), ("A_RVL", 1), ("A_RVL", 2),
           ("A_KR8", "sym+"), ("A_KR8", "sym-"), ("A_RKRL", 1), ("A_RKRL", 2)],
    "S": [("A_S8", "sym+"), ("A_S8", "sym-"), ("A_RSL", 1), ("A_RSL", 4),
          ("A_PL0", 1), ("A_PL1", 1), ("A_PL1", 64),
          ("A_SR0", 1), ("A_SR1", 1), ("A_SR1", 4),
          ("A_SG0", 1), ("A_SG1", 1), ("A_SG1", 4)],
}
DECLARED_HELPERS = {"L": 1, "D": 10, "Q": 7, "Kv": 6, "S": 7}

total = 0
print("domain  lookups  helpers(declared)  domain size  lookups*size")
for dom, lks in LOOKUPS.items():
    size = 1 << LOG[dom]
    n = len(lks)
    h = -(-n // 2)
    total += n * size
    ok = "ok" if h == DECLARED_HELPERS[dom] else f"MISMATCH (declared {DECLARED_HELPERS[dom]})"
    print(f"{dom:>6}  {n:>7}  {h:>8} {ok:<12} {size:>11}  {n*size:>12}")
print(f"total U8 lookups = {total}  (note section 5 says 47104: "
      f"{'matches' if total == 47104 else 'MISMATCH'})")
print(f"exp lookups = H*T*T = {H*T*T} (note says 2048: "
      f"{'matches' if H*T*T == 2048 else 'MISMATCH'})")

ranged = {p for lks in LOOKUPS.values() for p, _ in lks}
print()
print("planes with NO direct range lookup (their bound must be derived from a relation):")
for name, dom in PLANES:
    if name not in ranged:
        print(f"  {name:<8} dom {dom:<3}")

rows = 0
for name, dom in PLANES:
    rows += max(1, (1 << LOG[dom]) // N)
print()
print(f"A data rows = {rows} (layout.rs test asserts 154: "
      f"{'matches' if rows == 154 else 'MISMATCH'});"
      f" A rows = {rows} + 2*75 + 2 = {rows + 152}"
      f" (note section 5 says 306: {'matches' if rows + 152 == 306 else 'MISMATCH'})")
H_PLANES = [("H_L", "L")] + [(f"H_D{k}", "D") for k in range(10)] \
    + [(f"H_Q{k}", "Q") for k in range(7)] + [(f"H_KV{k}", "Kv") for k in range(6)] \
    + [(f"H_S{k}", "S") for k in range(7)] + [("H_SEXP", "S"), ("H_GU8", "Tab"),
                                              ("H_GEXP", "Tab"), ("H_U", "Tab")]
hrows = sum(2 * max(1, (1 << LOG[d]) // N) for _, d in H_PLANES)
print(f"H data rows = {hrows} (layout.rs test asserts 218: "
      f"{'matches' if hrows == 218 else 'MISMATCH'});"
      f" H rows = {hrows} + 2*35 + 2 = {hrows + 72}"
      f" (note section 5 says 290: {'matches' if hrows + 72 == 290 else 'MISMATCH'})")
