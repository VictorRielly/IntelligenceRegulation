#!/usr/bin/env python3
"""Tick 26 (item 27): committed padding words and the pad rule's cost. Arithmetic only, reads no file.

Constants are COUNTED from the retained source (ops/zkp-mvp/gpu-metal/hashline/src/private_block/shape.rs,
layout.rs, pad.rs), the census log results/zk60_effplan_20261105/census.log (W16R2_8B_T128_H24 plane
counts), results/zk60_w16r2_20261101/ACCOUNTING.md (W16R2_SHIELD has the same 2,501 A and 2,602 H rows as
W16R2_8B), tick 11 / tick 21 / tick 22 handoffs (phase times, commit shares, production block GPU).
"""
LOGC = 14
ROW = 1 << LOGC           # message words per row
CODE = 2                  # W16R2: code rate 1/2 -> codeword words per message word
BYTES = 8                 # Goldilocks word

# W16R2 plane lists (census.log, W16R2_8B): domain -> (A planes, H Fp2 planes); one row count per plane = size/2^14
A_PLANES = {"D": 19, "F": 9, "Q": 6, "Kv": 6, "S": 8, "T": 4, "Ht": 2, "L": 2, "Tab": 15}
H_PLANES = {"D": 10, "F": 5, "Q": 3, "Kv": 3, "S": 5, "L": 1, "Tab": 16}
A_ROWS_TOTAL, H_ROWS_TOTAL = 2501, 2602       # incl. 2 per claim site + 2 (A: 110 sites; H: 43)
TOTAL_ROWS = A_ROWS_TOTAL + H_ROWS_TOTAL      # 5,103

PROFILES = {
    "W16R2_8B":    dict(tokens=128, width=4096, hidden=14336, layers=32, block_gpu_ms=91.46,
                        commit_share=0.305, ntt_f=0.868),
    "W16R2_SHIELD": dict(tokens=128, width=3072, hidden=9216, layers=26, block_gpu_ms=174.25,
                         commit_share=0.437, ntt_f=0.855),
}


def clog2(n):
    return (n - 1).bit_length()


for name, p in PROFILES.items():
    t, w, h = p["tokens"], p["width"], p["hidden"]
    size = {"D": t * (1 << clog2(w)), "F": t * (1 << clog2(h))}
    true = {"D": t * w, "F": t * h}
    print(f"== {name}")
    pad_rows = 0.0
    for dom in ("D", "F"):
        rows = size[dom] // ROW
        padfrac = 1 - true[dom] / size[dom]
        a = A_PLANES[dom] * rows
        hh = H_PLANES[dom] * 2 * rows            # Fp2 plane = two base-word rows
        print(f"  {dom}: size 2^{clog2(size[dom])} true {true[dom]} pad {padfrac:.4f}; rows/plane {rows}; "
              f"A rows {a}, H base rows {hh}; padded A {a*padfrac:.1f}, padded H {hh*padfrac:.1f}")
        pad_rows += (a + hh) * padfrac
    # rows of the short domains: T (4 A), Ht (2 A), L (2 A + 1 H Fp2 = 2 base rows): one 2^14 row each, <= 2^12 words used
    short_rows = 4 + 2 + 2 + 2
    tab_rows = A_PLANES["Tab"] + 2 * H_PLANES["Tab"]
    print(f"  padded rows (D + F): {pad_rows:.1f} of {TOTAL_ROWS} = {100*pad_rows/TOTAL_ROWS:.2f}%")
    print(f"  short-domain rows (T, Ht, L): {short_rows} ({100*short_rows/TOTAL_ROWS:.2f}%), Tab rows {tab_rows} ({100*tab_rows/TOTAL_ROWS:.2f}%)")
    print(f"  upper bound incl. those: {pad_rows+short_rows+tab_rows:.1f} rows = {100*(pad_rows+short_rows+tab_rows)/TOTAL_ROWS:.2f}%")
    blk_bytes = TOTAL_ROWS * ROW * CODE * BYTES
    print(f"  block codewords {blk_bytes/1e9:.3f} GB; padded part {pad_rows*ROW*CODE*BYTES/1e6:.1f} MB per block, "
          f"{pad_rows*ROW*CODE*BYTES*p['layers']/1e9:.2f} GB per request (layers {p['layers']})")
    req_rows = p["layers"] * TOTAL_ROWS + 1252
    print(f"  request rows (32 blocks formula, boundaries 1,252): {req_rows}; request codewords {req_rows*ROW*CODE*BYTES/1e9:.2f} GB")
    # commit GPU bound: linear in committed rows
    share = pad_rows / TOTAL_ROWS
    ms = share * p["commit_share"] * p["block_gpu_ms"]
    print(f"  commit_A+H share {p['commit_share']:.3f} of block GPU {p['block_gpu_ms']} ms: "
          f"padded part at most {100*share*p['commit_share']:.2f}% = {ms:.2f} ms/block (if cost linear in rows and all padded rows dropped)")
    if name == "W16R2_8B":
        print(f"  8B cadence bound (rule a: x * 32 / 3745.5): {ms*32/3745.5*100:.2f}% at full pass-through")
    # lookups on padded positions: F has 7 per position, D 19 per position (census 'lookups per position')
    lk = {"D": 19, "F": 7, "Q": 6, "Kv": 6, "S": 7}
    padded_lookups = sum(lk[d] * (size[d] - true[d]) for d in ("D", "F"))
    total_lookups = 32_276_480
    print(f"  lookups on padded positions: {padded_lookups} of {total_lookups} counted (8B figure) = {100*padded_lookups/total_lookups:.2f}%")

print()
print("== compact layouts (DERIVED)")
# F at 8B: 14336 = 7 * 2048; 8 planes' live words = 7 planes' slots
print("  8 F planes x 14,336 =", 8 * 14336, "= 7 x 16,384 =", 7 * 16384)
print("  8B F rows per plane: live 112 of 128 (live/pad = 7/8)")

print()
print("== the pad term inside the 8B slot 18 kernel (COUNTED from results/zk60_k0k1_roofline_20261118/build/k5_b18.metal, k_v13)")
# kernel text: 22 table reads (19 tabs + 3 xtabs); n16 = 1 - v18 (anti-support), n17 = v21 (xtab 2 = the 9-plane zeta batch),
# n18 includes f2_mul(f2_mul(CF(38), n16), n17); census: f2_mul 25, f2_mulb 13, live tabs 21
f2_mul_total, pad_f2_mul = 25, 2
live_tabs, pad_extra_tabs = 21, 1             # v18 (supp) is also read by the gate, so only v21 is extra
print(f"  pad term: {pad_f2_mul} of {f2_mul_total} f2_mul ({100*pad_f2_mul/f2_mul_total:.0f}%), {pad_extra_tabs} of {live_tabs} live tables ({100*pad_extra_tabs/live_tabs:.1f}%)")
# phases (tick 11 / breakdown README, ms, solo block): slot 18 = 21.339 batched; tab 1.701, r0 6.377, r1-4 9.020
tab, r0, r14 = 1.701, 6.377, 9.020
bw = r0 + r14
lo = bw / live_tabs * 0.6                      # ASSUMED realised 0.6 of equal-traffic share, no build saving
hi = bw / live_tabs + tab / 3                  # equal-traffic share plus up to a third of the table build
print(f"  lazy node (build the 9-plane batch after round 6 from the folded planes: 2^14 cells, never folded, term skipped in rounds 0-6): "
      f"saves {lo:.2f}-{hi:.2f} ms of slot 18's 21.3; of production block GPU 91.46 ms: {100*lo/91.46:.2f}-{100*hi/91.46:.2f}%; "
      f"cadence at most {lo*32/3745.5*100:.2f}-{hi*32/3745.5*100:.2f}%")
# Shield: slots 14 (67 live tabs, one extra) and 18 (32 live tabs, one extra); phases from tick 11 script (R13_SHIELD breakdown)
s18 = dict(tab=2.590, r0=11.564, r14=15.302, n=32)
s14 = dict(tab=1.656, r0=9.010, r14=10.785, n=67)
lo = sum(0.6 * (s["r0"] + s["r14"]) / s["n"] for s in (s14, s18))
hi = sum((s["r0"] + s["r14"]) / s["n"] + s["tab"] / 3 for s in (s14, s18))
print(f"  Shield slots 14 + 18 (ASSUMED same structure): {lo:.2f}-{hi:.2f} ms of production block GPU 174.25: {100*lo/174.25:.2f}-{100*hi/174.25:.2f}%")
