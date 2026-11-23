#!/usr/bin/env python3
"""Tick 49 (queue item 21, H155): claims on packed A after candidate B, pairs released,
and the net U cost. Pure arithmetic over counts carried from ticks 5-8 (COUNTED there).
Reads no file, runs in well under a second."""
import itertools

ROW = 1 << 14  # words per local row

# reads on cell planes per domain at the 8B (tick 8 section 1, COUNTED there), width k (tick 6)
reads = {"D": (28, 4096), "Q": (9, 4096), "Kv": (9, 1024), "S": (11, 4096), "F": (10, 14336)}
total_reads = sum(n for n, _ in reads.values())
assert total_reads == 67

# 1. claims left on packed A: one tie claim per packed matrix (NM); digit planes and
#    multiplicities are committed AFTER Theta so they are on Z, not on A (tick 7 sec. 3).
print("== 1. tie claims on packed A (one per matrix) ==")
nm_cases = {
    "stack by width: 4096 {D,Q,S}, 1024 {Kv}, 7168 {F}": 3,
    "stack by width, S unpacked: 4096 {D,Q}, 1024, 7168": 3,
    "one matrix per domain D,Q,Kv,F,S": 5,
    "one per domain, F in two halves": 6,
}
for k, v in nm_cases.items():
    print(f"  NM = {v}: {k}")

# 2. pairs released on A
print("\n== 2. A mask rows (pairs) released ==")
rows = []
for s_packed in (True, False):
    moved = 67 if s_packed else 67 - 11   # cell claims leaving A
    for nm in (3, 4, 5, 6):
        if (not s_packed) and nm == 6:
            continue
        released = 2 * moved - 2 * nm
        rows.append((s_packed, nm, moved, released))
        print(f"  S packed={s_packed!s:5} NM={nm}: claims moved {moved}, pairs freed {2*moved} rows, "
              f"tie pairs kept {2*nm}, NET released {released} rows")
lo = min(r[3] for r in rows); hi = max(r[3] for r in rows)
print(f"  range of net release: {lo} to {hi} rows (tick 8's bracket was 38 to 114+)")
print(f"  claims left on A for cell planes: {min(nm for nm in (3,))} to 6 tie claims; "
      f"plus 11 unpacked S sites in the S-unpacked case = up to {6+11}")

# 3. U cost, entries = k per read (Fp2 entry = 2 words), +2 mask rows per read, +2 proximity rows
def u_rows(read_list):
    words = sum(2 * k for k in read_list)
    return -(-words // ROW)

base = []
for dom, (n, k) in reads.items():
    base += [k] * n
print("\n== 3. U rows ==")
print("  67 reads, S at 4096:", u_rows(base), "data rows +", 2 * 67 + 2, "= ", u_rows(base) + 2 * 67 + 2)
u67 = u_rows(base) + 2 * 67 + 2
s_unpacked_reads = [k for dom, (n, k) in reads.items() for _ in range(n) if dom != "S"]
u56 = u_rows(s_unpacked_reads) + 2 * 56 + 2
print("  56 reads (S unpacked, stays on A):", u56)

# tick 8's totals (carried) : (label, U rows, A data rows saved)
t8 = [("C split only, S one 4,096 matrix", 204, 1202),
      ("C + M split, S 4,096", 222, 1094),
      ("C + M + W split, S 4,096", 286, 839)]
credit = {"NM=3": 128, "NM=5": 124}
print("\n== 4. net U cost as a share of A data rows saved (tick 8 rows, S packed) ==")
print("  (a) each half its own U everywhere (tick 8 as written), no credit:")
for lab, u, sv in t8:
    print(f"      {lab}: U {u}, saved {sv}, {100*u/sv:.1f}%")
print("  (b) same, credit of freed A pairs NM=3 (128 rows) and NM=5 (124 rows):")
for lab, u, sv in t8:
    print(f"      {lab}: net {u-128} to {u-124} rows = {100*(u-128)/sv:.1f}% to {100*(u-124)/sv:.1f}%")

# 5. one U or two for a split limb.  Combined U at combination-only sites (W planes read at
#    matmul / norm-in / IO sites): from tick 8 section 1 these are
#    A_X(SS), A_X1(SSM), A_X(IO_IN), A_X2(IO_OUT), A_Y x3 (one vector), A_YM x2 (one vector),
#    A_H16 (DMM), A_E (RS), A_P (PV) = 12 claims, 9 distinct vectors on W planes.
comb_only_claims = 12
comb_only_vectors = 9
# tick 8 estimated 24 extra reads for W (15 planes); doubling only zero-check reads gives 15
w_extra_t8, w_extra_new = 24, 15
avg_k = 4096
saving_rows = (w_extra_t8 - w_extra_new) * (2 + (2 * avg_k) / ROW)
print("\n== 5. one U or two per split limb ==")
print(f"  W planes read where only the combined value is needed: {comb_only_claims} claims, {comb_only_vectors} vectors")
print(f"  W extra reads: tick 8 about {w_extra_t8} (every read doubled) -> about {w_extra_new} (zero-check reads only)")
print(f"  rows saved at the C+M+W scenario: about {saving_rows:.0f} of 286 (U 286 -> about {286-round(saving_rows)})")
print(f"  C and M planes (16 planes) are remainder limbs read only at their zero-check site: no change")
print(f"  C+M+W net with credit 124-128 rows: {286-round(saving_rows)-128} to {286-round(saving_rows)-124} rows "
      f"= {100*(286-round(saving_rows)-128)/839:.1f}% to {100*(286-round(saving_rows)-124)/839:.1f}% of 839")

# 6. groups (column-weight keys) on A: shape.rs a_groups = tzc + 15 + 2*2 + 4*2 (+2 dd)
print("\n== 6. A column-weight groups holding cell keys ==")
cell_groups = 1 + 1 + 1 + 3 + 1 + 3 + 1 + 2 + 2 + 1 + 2 + 2 + 1 + 1 + 1
print("  SS, SSM, RS, 09 Q K V, 12 WO, 13 G U D, 14 F, 10 score x2, 11 PV x2, 03 cube, 04 cube+partner,")
print("  05 cube+partner, 06 cube, IO_IN, IO_OUT =", cell_groups, "groups (DERIVED from the a_groups comment)")
print("  non-cell: tzc + 4 (08 limb, TAB, 03 off-cube T, 06 off-cube Ht); total tzc + 27 (+2 dictionary)")
print("  after B: 1 to NM groups for the tie claims if their column tails coincide (one shared end point)")
print("  one group vector = (2^14 + 256) Fp2 = %d words = %.2f rows" % (2 * (ROW + 256), 2 * (ROW + 256) / ROW))
