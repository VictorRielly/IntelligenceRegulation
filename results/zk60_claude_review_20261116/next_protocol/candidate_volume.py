#!/usr/bin/env python3
"""Committed volume per candidate, derived from the cycle-4 census (read-only arithmetic).

Used by docs/zkmatrix-poc/ZK60_NEXT_PROTOCOL_CANDIDATES.md section 3. Standard library only, reads no file.
Every input is a COUNTED figure from the census handoffs or an ASSUMED parameter named below.

Sources (COUNTED):
  research/zkp-efficiency/handoffs/20261116-claude-cycle4-committed-volume-census.md  sec 1.1-1.3
  research/zkp-efficiency/handoffs/20261116-claude-cycle6a-lookup-volume.md          sec 2
  research/zkp-efficiency/handoffs/20261116-claude-cycle6c-linear-chains.md          sec 1
  results/zk60_effplan_20261105/b6/model.py:246 via W16R3_DESIGN_B1_B3_20261105.md table (4,859 rows)
  results/zk60_metal_20261031/D56_FIELD_SWITCH_STUDY.md sec 2.3 (31-bit A elements, ESTIMATE there)
"""

ROW = 2 ** 14            # message words per committed row (shape.rs:323)
T = 128                  # tokens per request
BLOCKS = 32
EXTRA_ROWS = 1178 + 74   # 31 boundaries x 38 + 2 endpoints x 37 (census 1.3)
B_PER_ROW_CODE = ROW * 2 * 8   # rate 1/2, 8-byte words: 262,144 B of codeword per row
M_GB = (0.052, 0.052)    # 32 masking tables today (census 1.3)

BASE = dict(A_words=984, A_limbs=1272, A_agg=8, A_tab=15, H=2514, A_mask=222, H_mask=88)
assert sum(BASE.values()) == 5103


def per_token_layer(rows):
    return rows * ROW / T


def request_gb(rows_per_block, m_gb=M_GB):
    code = (BLOCKS * rows_per_block + EXTRA_ROWS) * B_PER_ROW_CODE / 1e9
    return code + m_gb[0], code + m_gb[1]


def show(name, rows, m_gb=M_GB, note=""):
    lo, hi = request_gb(rows, m_gb)
    print(f"{name:58s} rows/block {rows:8.0f}  words/token-layer {per_token_layer(rows)/1e3:7.1f} k"
          f"  share {100*rows/5103:5.1f}%  request codewords {lo:5.2f}-{hi:5.2f} GB {note}")


def main():
    show("W16R2 today (COUNTED)", 5103)
    show("W16R3 B1-B3 (MODEL, model.py:246)", 4859)
    show("W16R3 B1-B3 then C1-C3,C5,C7 -11.7% (ASSUMED multiplicative)", 4859 * (1 - 0.117))
    m_gkr = (0.052 + 32 * 48 * 4096 * 8 / 1e9, 0.052 + 32 * 144 * 4096 * 8 / 1e9)
    # Candidate A (cycle 6a): G1 range+table helpers retired, G2 all lookups, G3 plus H site masks
    show("A, G1: range and table helpers retired", 5103 - 2162 - 30, m_gkr)
    show("A, G2: every lookup in the tree, H keeps u", 5103 - 2162 - 30 - 320, m_gkr)
    g3 = 5103 - 2162 - 30 - 320 - 82
    show("A, G3: G2 and 82 H mask rows go (ASSUMED)", g3, m_gkr)
    # Product-tree variant: multiplicities as 32 bit-planes per table entry (FlashProve, tick 3)
    # 15 table planes of 2^14 today -> 32 x 15 rows if one lookup argument per block (ASSUMED one per block)
    show("A2 product tree, bit-plane multiplicities, one argument/block", g3 - 15 + 32 * 15, m_gkr,
         "(ASSUMED one lookup argument per block)")
    # Candidate B: G3, minus derived planes L1-L3 (424 rows, cycle 6c), remaining A data values re-expressed
    # in signed byte cells (ASSUMED mean 1.5-2.0 bytes per value) and packed 3 cells per word (radix 2^20),
    # plus smallness digits 2*tau words per cell row of 2^14 columns (tau = 128): 256/16384 rows per cell row.
    a_data = 2279 - 424
    for bbar in (1.5, 2.0):
        cell_rows = a_data * bbar
        packed = cell_rows / 3
        digits = cell_rows * (2 * 128) / ROW
        rows = packed + digits + 222 + (g3 - 2501)  # A site masks kept; residual H rows (u + kept mask rows)
        show(f"B: G3 + derived planes + byte cells packed 3/word (bytes/value {bbar})", rows, m_gkr)
    # Candidate C: D56's 31-bit exact-digit A (104.3 M elements per block, 4-byte words) with H retired by GKR.
    a31_bytes = 104.3e6 * 4
    rows_equiv = a31_bytes / (ROW * 8)   # in 8-byte-row equivalents, for comparison only
    show("C: D56 31-bit exact digits, H retired (8-byte-row equivalents)", rows_equiv, m_gkr,
         "(no packing: see section 3.C)")
    # Plain pass bytes for orientation (cycle 4 sec 3)
    print("plain int8 pass per request: 7.9-9.0 GB (DERIVED, cycle 4); fp16 15.4-16.5 GB")


if __name__ == "__main__":
    main()
