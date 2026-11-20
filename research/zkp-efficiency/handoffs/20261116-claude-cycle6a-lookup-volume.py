#!/usr/bin/env python3
"""Cycle 6a (2026-11-16): what one block / one request commits under alternative lookup arguments.

Run:  python3 -I research/zkp-efficiency/handoffs/20261116-claude-cycle6a-lookup-volume.py
Standard library only, reads no file, writes nothing. Counts only: it models committed ROWS and codeword BYTES,
not prover time. Inputs are the cycle 4 census (20261116-claude-cycle4-census.py: rows per plane and domain from
results/zk60_effplan_20261105/census.log:218-237, shape.rs:2466-2589). Labels: COUNTED / DERIVED / ASSUMED.
"""

N, INV_RATE, WORD_B = 1 << 14, 2, 8
BLOCKS = 32
ROWS_PER_PLANE = {"T": 1, "Ht": 1, "L": 1, "D": 32, "Q": 32, "Kv": 8, "S": 32, "F": 128, "Tab": 1}   # COUNTED (cycle 4)
H_PLANES = {"L": 1, "D": 10, "Q": 3, "Kv": 3, "S": 5, "F": 5, "Tab": 16}                            # COUNTED (cycle 4)
A_ROWS_BLOCK, H_ROWS_BLOCK = 2501, 2602                                                               # COUNTED (cycle 4)
H_SITE_ROWS = 86                                                                                      # COUNTED (cycle 4)
assert sum(2 * H_PLANES[k] * ROWS_PER_PLANE[k] for k in H_PLANES) == 2514

# Which H planes are range-lookup helpers (shape.rs:2568-2589): every plane in L, D, Q, Kv; S and F carry one extra
# plane each for the exp / act tuple lookup (shape.rs:2576, 2578); Tab holds 3 table helpers + 12 range sub-plane table
# helpers (4 + sub_planes - 1 u) and the last plane u (shape.rs:2587, "u stays the last plane").  The 12 is DERIVED:
# 16 planes - 3 - 1.
rows = lambda dom, planes: 2 * planes * ROWS_PER_PLANE[dom]
H_RANGE = {d: rows(d, H_PLANES[d]) for d in ("L", "D", "Q", "Kv")}
H_RANGE["S"] = rows("S", H_PLANES["S"] - 1)
H_RANGE["F"] = rows("F", H_PLANES["F"] - 1)
H_RANGE_ROWS = sum(H_RANGE.values())                           # 2 + 640 + 192 + 48 + 256 + 1024 = 2162
H_TABLE_ROWS = rows("Tab", H_PLANES["Tab"] - 1)                # 30 (everything in Tab except u)
H_EXPACT_ROWS = rows("S", 1) + rows("F", 1)                    # 64 + 256 = 320
H_U_ROWS = rows("Tab", 1)                                      # 2
assert H_RANGE_ROWS + H_TABLE_ROWS + H_EXPACT_ROWS + H_U_ROWS == 2514
# Cross-check against the 2026-11-01 note: it counted 1,970 rows as the LOOKUPS' helper words (32,276,480 / 16,384),
# i.e. before padding; the padded planes above are 2,162 rows. The difference (192 rows, 9%) is pad words inside
# helper planes (F stripes carry 2,048 pad words per 16,384-word row, S above the diagonal).
LOOKUP_WORDS = 32_276_480
assert abs(LOOKUP_WORDS / N - 1970.0) < 1e-9

M_ROWS_BLOCK, M_CODEWORD_WORDS = 50, 4096                      # COUNTED (cycle 4): M row = 4096 codeword words
OTHER_ROWS_REQ = 1178 + 74                                     # boundaries + endpoints (COUNTED, cycle 4)


def request_bytes(block_rows, extra_m_rows_per_block=0):
    main = (BLOCKS * block_rows + OTHER_ROWS_REQ) * N * INV_RATE * WORD_B
    m = BLOCKS * (M_ROWS_BLOCK + extra_m_rows_per_block) * M_CODEWORD_WORDS * WORD_B
    return main + m


BASE = A_ROWS_BLOCK + H_ROWS_BLOCK                              # 5,103
base_bytes = request_bytes(BASE)
print(f"today: {BASE} rows/block, request codewords {base_bytes/1e9:.2f} GB (cycle 4: 43.19 GB)")

scen = []
# G1: LogUp-GKR for the range lookups and the tables: range helper planes and table helper planes retired;
#     exp/act helpers and u stay; H site masks kept (conservative); +48..+144 M rows per block (2026-11-01 note, sec. 4).
g1 = BASE - H_RANGE_ROWS - H_TABLE_ROWS
scen.append(("G1 LogUp-GKR, range lookups + table helpers (exp/act helpers stay)", g1, (48, 144)))
# G2: all lookups in the tree (exp/act too): H keeps only u.
g2 = g1 - H_EXPACT_ROWS
scen.append(("G2 LogUp-GKR, every lookup (exp/act in the tree)", g2, (48, 144)))
# G3: G2 and the H claim-site mask rows of retired planes go too (ASSUMED: the masks exist per H claim site, 43 sites,
#     and sites vanish with their planes; only the proximity pair and a handful stay).
g3 = g2 - (H_SITE_ROWS - 4)
scen.append(("G3 = G2 and H site-mask rows dropped (ASSUMED 82 of 86)", g3, (48, 144)))
for name, r, (lo, hi) in scen:
    b_lo, b_hi = request_bytes(r, lo), request_bytes(r, hi)
    print(f"{name}: {r} rows/block ({100*r/BASE:.1f}% of today); request {b_lo/1e9:.2f}-{b_hi/1e9:.2f} GB "
          f"({100*b_lo/base_bytes:.1f}-{100*b_hi/base_bytes:.1f}% of {base_bytes/1e9:.2f})")

# Per-lookup committed words (DERIVED), words of one 64-bit field element counted once (message, not codeword):
print("\nper lookup, committed message words beyond the looked-up value itself:")
print("  today (helper h = 1/(a-v0) + 1/(a-v1) in Fp2, one per PAIR of lookups): 2 words / 2 lookups = 1.0")
print("  LogUp-GKR: 0 per lookup, multiplicities per table entry (a few 2^16-entry rows per block, already in A Tab)")
print("  Logup* (index array I, table T committed, pushforward I*eq_r in Fp2 of table size): 0 per lookup, 2 words per TABLE entry")
print("  Lasso c=1 (one counter per lookup + final counts per table entry): 1.0 per lookup, no gain")
print("  Shout d=1, dense hash-based commit of one-hot ra: K = 2^16 words per lookup (sparsity only pays on a PCS that")
print("      commits non-zeros only); d=2: 2 x 2^8 = 512; d=4: 4 x 2^4 = 64")
print("  zkLLM tlookup: A = (beta+S)^-1 per lookup (one word per lookup), same as today")
helper_share_words = (H_RANGE_ROWS + H_TABLE_ROWS + H_EXPACT_ROWS) * N / LOOKUP_WORDS
print(f"  check: padded helper words / counted lookups = {helper_share_words:.3f} words per lookup (pad words inflate the 1.0)")

# Soundness terms at Fp2 (|Fp2| ~ 2^128), counts from the 2026-11-01 note (sec. 5, item 7), 2^25 leaves per block:
import math
fp2 = 2 ** 128
leaves = 2 ** 25
gkr = sum(3 * (k - 1) + 7 for k in range(1, 26))
logup = (leaves + 2 ** 17)
print(f"\nsoundness, per block tree: LogUp ~ (N+T)/|Fp2| = 2^{math.log2(logup/fp2):.1f}; GKR sumchecks <= "
      f"{gkr}/|Fp2| = 2^{math.log2(gkr/fp2):.1f}; x 32 blocks (union bound) adds 5 bits: LogUp 2^{math.log2(32*logup/fp2):.1f}.\n"
      "The LogUp term is the same (N+T)/|Fp2| the helper-column LogUp already pays (cycle 2: 'capped by the LogUp bound'),\n"
      "so moving to GKR does not change it; the GKR sumcheck term is about 2^-118 per block and adds little.")
