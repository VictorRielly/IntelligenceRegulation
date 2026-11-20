#!/usr/bin/env python3
"""Cycle 6b (2026-11-16): codeword bytes per 8B request if the small-value rows were committed in a smaller symbol.

Run:  python3 -I research/zkp-efficiency/handoffs/20261116-claude-cycle6b-small-value-packing.py
Standard library only, reads no file, writes nothing. Counting only (rows x symbol bytes); no prover time.
Inputs from cycle 4 (20261116-claude-cycle4-census.py, COUNTED there); the three row classes are the cycle 4 categories.
"""

N, INV_RATE = 1 << 14, 2
BLOCKS = 32
# One block (COUNTED, cycle 4 sec. 1.2):
SMALL = 984 + 1272 + 8 + 15        # A words, A limb/remainder planes, per-token aggregates, A table planes = 2,279
HELP = 2514                        # H data rows (Fp2 helpers, table helpers, u)   -- full-field, not small
MASK = 222 + 88                    # A and H site + proximity mask rows               -- uniform random symbols
assert SMALL + HELP + MASK == 5103
OTHER_SMALL = 1178 + 74            # boundaries + endpoints: copies of the block-output plane X2 and a few masks; treated as small
M_BYTES = 32 * 50 * 4096 * 8       # masking tables, unchanged (already a small separate commitment)


def bytes_for(small, helpers, masks, small_b, help_b, mask_b, other=OTHER_SMALL):
    """codeword bytes per request; *_b = bytes per symbol-equivalent row-word (8 = today's Goldilocks word)."""
    per_block = (small * small_b + helpers * help_b + masks * mask_b) * N * INV_RATE
    return BLOCKS * per_block + other * small_b * N * INV_RATE + M_BYTES


base = bytes_for(SMALL, HELP, MASK, 8, 8, 8)
print(f"today: {base/1e9:.2f} GB codewords per request (cycle 4: 43.19 GB)")

rows = [
    # name, small_b, help_b, mask_b
    ("B1 ideal 4x packing, proof of packing free (UPPER BOUND; no prime-field mechanism found)", 2, 8, 2),
    ("B1b ideal 4x packing of small rows only, masks stay", 2, 8, 8),
    ("B2 31-bit prime base + degree-4 extension (H116 rebase); helpers are 4 x 4 B = 16 B = same", 4, 8, 4),
    ("B3 binary tower, GF(2^16) symbols for 16-bit values; helpers GF(2^128) = same bytes", 2, 8, 2),
]
for name, sb, hb, mb in rows:
    b = bytes_for(SMALL, HELP, MASK, sb, hb, mb)
    print(f"{name}\n    {b/1e9:.2f} GB ({100*b/base:.1f}% of today)")

print("\nwith Part A's G2 (every helper plane retired; H keeps u 2 rows and its 88 mask rows; 2,591 rows/block):")
SMALL2, HELP2, MASK2 = SMALL, 2, 310 - 0   # masks unchanged at 310 in G2 (conservative)
for name, sb, hb, mb in rows:
    b = bytes_for(SMALL2, HELP2, MASK2, sb, hb, mb)
    print(f"{name[:46]}...: {b/1e9:.2f} GB ({100*b/base:.1f}%)")

# Row-share check against cycle 4's scenario table: 4x on A words+limbs only (2,256 rows) -> 66.8% of rows
r4 = 5103 - 2256 * 3 / 4
print(f"\ncycle 4 scenario 'A words and limbs packed 4 per word': {r4:.0f} rows = {100*r4/5103:.1f}% (cycle 4: 3,411 / 66.8%)")

# Pad overhead when a row holds fewer message symbols (DERIVED): Q = 280 pads per row regardless of alphabet.
for k in (1, 2, 4):
    msg = N // k
    print(f"row with {msg} message symbols (k={k}): pad share {280/msg*100:.1f}% of message; opened column data per row = 280 symbols")
