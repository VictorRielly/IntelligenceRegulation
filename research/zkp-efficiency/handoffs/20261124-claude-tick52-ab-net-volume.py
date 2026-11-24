#!/usr/bin/env python3
"""Tick 52 (queue item 18, H152): whole-block rows of candidate B (packed byte cells, tick 6) together with
candidate A (lookups without committed helpers), counted from plane lists, with the digit lookup, the contraction
commitment U with its mask pairs (ticks 7, 8, 49) and the new claim sites that helper-free lookups put on the block.

Run:  python3 -I research/zkp-efficiency/handoffs/20261124-claude-tick52-ab-net-volume.py
Standard library only. Reads tick 6's script (to reuse its plane classes and cost function) and writes nothing.

COUNTED inputs (file:line in the handoff, tree ops/zkp-mvp/gpu-metal/hashline): census rows A 2,501 (data 2,279),
H 2,602 (data 2,514), A sites 110, H sites 43 (shape.rs:2751-2762, census.log); lookups per position
L2 D19 Q6 Kv6 F7 S7 (shape.rs:2520-2560); Tab planes 15 = 3 + 12 range sub-planes (shape.rs:2482, range16.rs:212).
Carried (labelled in the handoff): tick 6 cell classes, tick 8 U rows, tick 49 credit, cycle 6a M rows and request constant.
"""
import contextlib
import importlib.util
import io
import math

ROW = 1 << 14

# ---- tick 6's cost function and plane list (reused, not re-derived) ----
spec = importlib.util.spec_from_file_location("t6", "/Users/victorrielly/IntelligenceRegulation/research/zkp-efficiency/handoffs/20261117-claude-tick6-cell-width.py")
t6 = importlib.util.module_from_spec(spec)
with contextlib.redirect_stdout(io.StringIO()):
    spec.loader.exec_module(t6)
TAU = t6.TAU

# ---- today's block (COUNTED) ----
A_DATA, A_MASK = 2279, 222          # 2 * 110 + 2
H_DATA, H_MASK = 2514, 88           # 2 * 43 + 2
BLOCK = A_DATA + A_MASK + H_DATA + H_MASK
assert BLOCK == 5103
REQ_OTHER = 1252                    # rows of a request outside the 32 blocks (cycle 6a section 2)
M_BASE = 50 * 4096 / ROW            # M rows (4,096 words) as local rows, outside the 5,103


def request(block_rows):
    return 32 * block_rows + REQ_OTHER


REQ0 = request(BLOCK)

# ---- candidate B: A data rows by class split (tick 6 scenarios, S in the 4,096-column stack) ----
B_CASES = {
    "C": dict(split_c=2, split_m=1, split_w=1),
    "C+M": dict(split_c=2, split_m=2, split_w=1),
    "C+M+W": dict(split_c=2, split_m=2, split_w=2),
}
# U rows with their mask pairs (tick 8 table; tick 49 for the one-U-at-combination-only-sites case) and reads
U_ROWS = {"C": 204, "C+M": 222, "C+M+W": 286}
U_ROWS_COMB = {"C": 204, "C+M": 222, "C+M+W": 264}
CELL_READS = {"C": 76, "C+M": 83, "C+M+W": 107}
CREDIT = (122, 128)                 # A mask rows released (tick 49, S packed, NM 3..6 -> 128..122)
ZMASK = (8, 14)                     # Z's own pairs (tick 49)
BZ_ROWS = 32 * 2 ** 11 / ROW        # authors' BZ: 32 rows x 2^11 columns (tick 5): 4 local rows


def digit_rows_and_mz(split_c, split_m, split_w):
    """digit part of tick 6's cost: sum over planes of cells x ROWS x 2 tau / k, and the effective mz (cell rows)."""
    rows = 0.0
    mz = 0.0
    for dom, name, cls in t6.PLANES:
        cells = {"P": 1, "C": split_c, "M": split_m, "W": split_w}[cls]
        k = t6.K_NAT[dom] if dom != "S" else 4096
        mz += cells * t6.ROWS[dom] * ROW / k
        rows += cells * t6.ROWS[dom] * 2 * TAU / k
    return rows, mz


print("== 1. B's A-side rows (tick 6 data incl. Z digits) ==")
B = {}
for name, kw in B_CASES.items():
    data = t6.cost(k_s=4096, **kw)
    dig, mz = digit_rows_and_mz(**kw)
    leaves = TAU * mz
    B[name] = dict(data=data, dig=dig, mz=mz, leaves=leaves)
    print(f"  {name:6s} A data rows {data:7.0f}  of which digit rows ZZ {dig:6.1f}  mz {mz:8.0f}  digit leaves per table {leaves:10.0f}"
          f" = 2^{math.log2(leaves):.2f} (tree levels); BZ {BZ_ROWS:.0f} rows")

# ---- lookup routes ----
# helpers retired (G2: range 2,162 + table 30 + exp/act 320 = 2,512 of 2,514 data rows; `u` (2 rows) stays)
H_G1 = 2514 - 2162 - 30             # exp/act tuple helpers and u stay
H_G2 = 2
H_MASK_G1 = 2 * 3 + 2               # three H planes left: S exp, F act, L u -> 3 sites
H_MASK_G2 = 2 * 1 + 2
print("\n== 2. helper-free lookups alone (candidate A), rows of the 5,103 ==")
for lab, hd, hm in (("G1 (exp/act helpers stay)", H_G1, H_MASK_G1), ("G2 (all lookups in the tree)", H_G2, H_MASK_G2)):
    for site_lab, new_sites in (("lookup claims merged into existing end points (0 new sites)", 0),
                                ("one new A site per domain tree (7)", 7),
                                ("one new A site per lookup column (47) + 15 multiplicity sites", 47 + 15)):
        tot = A_DATA + A_MASK + 2 * new_sites + hd + hm
        print(f"  {lab:30s} {site_lab:68s} {tot:5d} = {tot / BLOCK:.3f}")
print("  cycle 6a for reference: G1 2,911 (0.570) keeps H masks 88 and adds no site; G3 2,509 drops 82 of them with no site added")

# multiplicity bits (product tree of tick 3: multiplicities in bit planes) against field multiplicities (LogUp-GKR)
# the 4 sub-planes of the 16-bit family may see up to all 2^25 lookups (25 bits); the other 11 tables at most their own plane
# sizes (2^17 .. 2^22 lookups -> 18..22 bits), taken as 21 on average (ASSUMED, not mapped plane by plane)
MULT_BITS_LO = 15 * 20
MULT_BITS_HI = 15 * 25
MULT_BITS_MID = 4 * 25 + 11 * 21
print(f"\n  multiplicity bit planes (product tree): 15 tables x 20..25 bits = {MULT_BITS_LO}..{MULT_BITS_HI}, mid {MULT_BITS_MID} rows,"
      f" against 15 rows with field multiplicities (LogUp-GKR): +{MULT_BITS_LO - 15}..+{MULT_BITS_HI - 15}; packed 3 per word: {MULT_BITS_LO / 3:.0f}..{MULT_BITS_HI / 3:.0f}")

# M rows (4,096 words) added by the lookup trees (cycle 6a: +48..+144) and the digit slot (ASSUMED 2..4)
M_ADD = ((48 + 2) * 4096 / ROW, (144 + 4) * 4096 / ROW)
print(f"  M rows as local rows: base {M_BASE:.1f}; trees + digit slot add {M_ADD[0]:.1f}..{M_ADD[1]:.1f}")

# ---- the new cost where A and B meet: lookup terminals on cell planes become U reads ----
# every cell-domain lookup key plane is read at its tree's end point: D 19, Q 6, Kv 6, S 7, F 7 = 45 (COUNTED: lookups_per_position)
KEY_READS = {"D": (19, 4096), "Q": (6, 4096), "Kv": (6, 1024), "S": (7, 4096), "F": (7, 7168 * 2)}
key_data_rows = sum(n * 2 * k / ROW for n, k in KEY_READS.values())
n_key = sum(n for n, _ in KEY_READS.values())
EXTRA_HALVES = {"C": 9, "C+M": 16, "C+M+W": 31}      # a recombined key reads both halves (tick 51): two U (tick 8 counts)
PER_READ = {c: (U_ROWS[c] - 2) / CELL_READS[c] for c in U_ROWS}
print(f"\n== 3. lookup terminals on cell planes (A + B only) ==\n  key planes read: {n_key}, data {key_data_rows:.1f} rows with one U each; extra halves {EXTRA_HALVES}")
for c in U_ROWS:
    reads = n_key + EXTRA_HALVES[c]
    per_tree = key_data_rows + 2 * 6 + 2 * 0.0 + (EXTRA_HALVES[c] * 0.4)   # one pair per domain tree (6 domains); halves' data ~0.4 row each
    per_plane = reads * PER_READ[c]
    print(f"  {c:6s} reads {reads:3d}: pair per tree ~{per_tree:5.0f} rows; pair per plane read ~{per_plane:5.0f} rows ({PER_READ[c]:.2f} a read, tick 8)")

# ---- 4. whole block ----
def block_rows(bname, route, lo):
    """rows of one block of A+B (route 'R1' field multiplicities, 'R2' bit planes); lo = favourable end, else unfavourable"""
    b = B[bname]
    credit = CREDIT[1] if lo else CREDIT[0]
    zmask = ZMASK[0] if lo else ZMASK[1]
    u = U_ROWS_COMB[bname] if lo else U_ROWS[bname]
    a = b["data"] + BZ_ROWS + (A_MASK - credit) + u + zmask
    # the 15 multiplicity rows are inside b["data"] (tick 6 keeps 8 + 15); replace by bit planes for R2
    if route == "R2":
        a += (MULT_BITS_LO / 3 - 15) if lo else (MULT_BITS_HI - 15)
    # lookup terminals
    reads = n_key + EXTRA_HALVES[bname]
    a += 0 if lo else reads * PER_READ[bname] + 2 * 15      # merged into existing points vs a pair per plane read + 15 multiplicity sites
    h = H_G2 + H_MASK_G2
    return a + h


def block_rows_b_only(bname, mode, lo):
    """B with committed helpers: recombined keys ('recomb'), two byte lookups ('bytes' = +480), digit helpers committed"""
    b = B[bname]
    credit = CREDIT[1] if lo else CREDIT[0]
    zmask = ZMASK[0] if lo else ZMASK[1]
    u = U_ROWS_COMB[bname] if lo else U_ROWS[bname]
    a = b["data"] + BZ_ROWS + (A_MASK - credit) + u + zmask
    h = H_DATA + H_MASK + b["dig"] + 2            # the digit lookups' own helpers: one Fp2 per two lookups = ZZ words
    if mode == "bytes":
        h += 480
    return a + h


print("\n== 4. whole block, rows of 2^14 words (today 5,103); request = 32 blocks + 1,252 ==")
hdr = f"  {'case':44s} {'favourable':>12s} {'unfavourable':>14s}   words/block (M words)   request words"
print(hdr)
results = {}
for bname in B_CASES:
    for mode in ("recomb", "bytes"):
        lo, hi = block_rows_b_only(bname, mode, True), block_rows_b_only(bname, mode, False)
        results[(bname, "B", mode)] = (lo, hi)
        print(f"  B {bname:6s} helpers committed, {mode:7s} {lo:9.0f} {lo / BLOCK:.3f} {hi:10.0f} {hi / BLOCK:.3f}")
for bname in B_CASES:
    for route in ("R1", "R2"):
        lo, hi = block_rows(bname, route, True), block_rows(bname, route, False)
        lo_all, hi_all = lo + M_ADD[0], hi + M_ADD[1]
        results[(bname, "AB", route)] = (lo, hi)
        rq_lo, rq_hi = request(lo_all) / REQ0, request(hi_all) / REQ0
        print(f"  A+B {bname:6s} {route} (G2)               {lo:9.0f} {lo / BLOCK:.3f} {hi:10.0f} {hi / BLOCK:.3f}"
              f"   +M {M_ADD[0]:.0f}..{M_ADD[1]:.0f}: {lo_all / BLOCK:.3f}..{hi_all / BLOCK:.3f}; request {rq_lo:.3f}..{rq_hi:.3f}; "
              f"words {lo * ROW / 1e6:.1f}..{hi * ROW / 1e6:.1f} M (today {BLOCK * ROW / 1e6:.1f} M)")

# ---- 5. interaction and breakeven checks ----
print("\n== 5. checks ==")
# A alone, B alone, sum of gains vs combined
a_alone = (A_DATA + A_MASK + H_G2 + H_MASK_G2, A_DATA + A_MASK + 2 * 62 + H_G2 + H_MASK_G2)
print(f"  A alone (G2): {a_alone[0] / BLOCK:.3f}..{a_alone[1] / BLOCK:.3f} of today")
for bname in B_CASES:
    blo, bhi = results[(bname, "B", "recomb")]
    ab = results[(bname, "AB", "R1")]
    print(f"  {bname:6s} B alone {blo / BLOCK:.3f}..{bhi / BLOCK:.3f}, A+B (R1) {ab[0] / BLOCK:.3f}..{ab[1] / BLOCK:.3f}")
# what B adds on top of A (R1): the question the item asks
for bname in B_CASES:
    ab = results[(bname, "AB", "R1")]
    print(f"  {bname:6s} B's marginal rows on top of A-G2 (R1): {a_alone[0] - ab[0]:+.0f} (favourable) / {a_alone[1] - ab[1]:+.0f} (unfavourable) rows")
# floor of the A-data rows that B can touch: with helpers gone A data + masks is the block
print(f"  with helpers gone the block is {(A_DATA + A_MASK + 8) / BLOCK:.3f} of today; B's whole possible saving is on the {A_DATA} A data rows"
      f" ({A_DATA / (A_DATA + A_MASK + 8):.2f} of that block)")

# ---- 6. what the digit lookup adds in tree work, and a ceiling on what the volume cut can give (DERIVED) ----
LOOKUPS_BLOCK = 32_276_480           # counted lookup words per block (cycle 6a, projection.py:17)
print("\n== 6. tree work and a ceiling ==")
for bname in B_CASES:
    zz_words = 2 * TAU * B[bname]["mz"]
    print(f"  {bname:6s} digit leaves (ZZ words) {zz_words / 1e6:5.2f} M = +{100 * zz_words / LOOKUPS_BLOCK:.1f}% on the block's {LOOKUPS_BLOCK / 1e6:.2f} M lookups;"
          f" each digit tree 2^{math.log2(TAU * B[bname]['mz']):.1f} leaves = {math.log2(TAU * B[bname]['mz']):.0f} levels (main tree 25 levels)")
# commit share of device work (tick 42, 25.5% of 2.968 s) and the stream cadence 3.745 s (tick 22 rule: per-block ms x 32 / 3745.5)
COMMIT_SHARE, DEVICE_S, CADENCE_S = 0.255, 2.968, 3.7455
def cadence_ceiling(rows_ratio):
    return COMMIT_SHARE * DEVICE_S * (1 - rows_ratio) / CADENCE_S
for lab, r in (("B alone C", results[("C", "B", "recomb")][0] / BLOCK), ("B alone C+M+W", results[("C+M+W", "B", "recomb")][1] / BLOCK),
               ("A alone G2 (merged)", a_alone[0] / BLOCK), ("A alone G2 (pair per column)", a_alone[1] / BLOCK),
               ("A+B C R1 favourable", results[("C", "AB", "R1")][0] / BLOCK), ("A+B C+M+W R2 unfavourable", results[("C+M+W", "AB", "R2")][1] / BLOCK)):
    print(f"  {lab:32s} rows ratio {r:.3f}: commit saving at most {100 * cadence_ceiling(r):.1f}% of the cadence at full pass-through (before any tree or U work)")
print("  cycle 6a's prior ESTIMATE for the lookup tree itself: 0.040..0.105 s per block on Metal (0.5..1.2 of today's whole block GPU 0.0915 s) -- not re-measured")
