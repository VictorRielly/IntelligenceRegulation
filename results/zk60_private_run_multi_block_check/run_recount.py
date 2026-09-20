#!/usr/bin/env python3
"""Independent recomputation of the multi-block RUN draft's numbers.
Everything here is either [MEASURED] (from m125-run2-timing.log, copied into
this directory) or [RECOMPUTED] from the code's own formulas.

Formulas used, with their source:
  wire.rs:75-77   opening_len(groups, rows) = (groups+1)*vec*16
                                            + checks*(8 + rows*8 + 32 + path*32)
                  vec = n + opened_cols, path = log2(n*inv_rate)
  wire.rs:87-94   encoded_len = HEADER(40) + 3*32 + slots + mask + A + H + 2*endpoint
  pcs.rs:665-699  a commitment allocates data(rows*n*8), encoded(rows*nn*8),
                  pads(rows*q*8), salts(nn*32) and a Merkle tree(~2*nn*32)
  pcs.rs:673-674  draws: rows*q pads (Fp) + nn salts (bytes, D9-exempt)
  endpoint_g:200  draws: (rows - data_rows)*n mask words (Fp)
"""
from math import log2

# ---------------------------------------------------------------- 125M shape
N = 1 << 14              # endpoint / boundary row width (log_n 14)
INV_RATE = 4
NN = N * INV_RATE        # 65,536 encoded columns
CHECKS = 256             # opened columns == pad count (ZkOpts::standard)
VEC = N + CHECKS         # 16,640
PATH = 16                # log2(65,536)
DATA_ROWS = (512 * 1024) // N   # the padded (t_pad, d_pad) plane over 2^14 rows

A_ROWS, H_ROWS, A_GROUPS, H_GROUPS = 5_681, 7_120, 36, 9
M_ROWS, MASK_VEC, MASK_PATH, MASK_DOM = 50, 1024, 12, 4096
HEADER = 40
BLOCK_RECEIPT = 40_782_792       # grow_tests.rs MODEL_M125
L = 12


def opening_len(groups, rows, vec=VEC, checks=CHECKS, path=PATH):
    return (groups + 1) * vec * 16 + checks * (8 + rows * 8 + 32 + path * 32)


mask_open = 2 * MASK_VEC * 16 + CHECKS * (8 + M_ROWS * 8 + 32 + MASK_PATH * 32)
a_open = opening_len(A_GROUPS, A_ROWS)
h_open = opening_len(H_GROUPS, H_ROWS)
e37 = opening_len(1, 37)
e36 = opening_len(1, 36)
b38 = opening_len(2, 38)
slots = BLOCK_RECEIPT - (HEADER + 3 * 32 + mask_open + a_open + h_open + 2 * e37)

print("=" * 74)
print("1. RECEIPT — reproduce the block, then the segments")
print("=" * 74)
print(f"  mask opening        {mask_open:>12,}   A opening {a_open:>12,}   H opening {h_open:>12,}")
print(f"  endpoint 37 rows    {e37:>12,}   endpoint 36 rows {e36:>12,}   boundary 38 rows {b38:>12,}")
print(f"  residual slot bytes {slots:>12,}  (block total {BLOCK_RECEIPT:,} reproduced)")
assert HEADER + 96 + slots + mask_open + a_open + h_open + 2 * e37 == BLOCK_RECEIPT

core = slots + mask_open + a_open + h_open          # per stage, no roots, no IO
seg1 = HEADER + 4 * 32 + core + e36                 # B_1, A, M, H roots; opens E_in
segmid = HEADER + 4 * 32 + core + b38               # opens B_{k-1}
seglast = HEADER + 3 * 32 + core + b38 + e36        # no B_12; opens B_11 and E_out
total = seg1 + (L - 2) * segmid + seglast
print(f"  segment 1 {seg1:,} | interior {segmid:,} | segment {L} {seglast:,}")
print(f"  run total {total:,} B  ({total/1e6:.1f} MB)   draft says 484,095,680")
print(f"  DRAFT SEGMENT FRAMING = {HEADER} B/segment (magic+binding only).")
hdr_design = 8 + 32 + 8 + 8 + 32 + 8   # magic, run-profile digest, L, index, state, counter
trl_design = 32 + 8
print(f"  but SS 4.3 describes header {hdr_design} B + trailer {trl_design} B = "
      f"{hdr_design + trl_design} B, i.e. +{hdr_design + trl_design - HEADER} B per segment")
print(f"  -> the design's real segment sizes are "
      f"{seg1 + hdr_design + trl_design - HEADER:,} / "
      f"{segmid + hdr_design + trl_design - HEADER:,} / "
      f"{seglast + hdr_design + trl_design - HEADER:,}")
print(f"  -> the design's real run total {total + L*(hdr_design+trl_design-HEADER):,} B")
print(f"  largest segment {max(seg1, segmid, seglast)/2**20:.2f} MiB vs the 64 MiB ceiling")
print()

# ---------------------------------------------------------------- 2. memory
print("=" * 74)
print("2. MEMORY — a commitment's resident bytes from pcs.rs' own allocations")
print("=" * 74)


def commitment_bytes(rows, n=N, nn=NN, q=CHECKS):
    data = rows * n * 8
    enc = rows * nn * 8
    pads = rows * q * 8
    salts = nn * 32
    tree = (2 * nn - 1) * 32
    return data + enc + pads + salts + tree, dict(data=data, encoded=enc, pads=pads, salts=salts, tree=tree)


for rows in (36, 37, 38):
    tot, parts = commitment_bytes(rows)
    print(f"  {rows} rows: {tot:>11,} B = {tot/2**20:6.2f} MiB   " +
          " ".join(f"{k} {v/2**20:.2f}" for k, v in parts.items()))
b38_mem = commitment_bytes(38)[0]
e36_mem = commitment_bytes(36)[0]
io_interior = (2 * b38_mem + e36_mem) / 2 ** 20
print(f"  IO resident in an interior stage (B_k-1 + B_k + E_out) = {io_interior:.1f} MiB"
      f"   [draft: 88.2]")

PEAK = 10_837            # MiB, HWM, m125-run2-timing.log line 39
print(f"  measured one-block peak {PEAK} MiB ({PEAK/1024:.2f} GiB)")
print(f"  draft's run peak        {PEAK + io_interior:.0f} MiB ({(PEAK+io_interior)/1024:.2f} GiB)")

# what a RUN has at the peak that one block does not
# 125M public weights, int8 (private_block.rs:226-233, :347-352)
d_pad, f_pad, t, kv = 768, 2048, 512, 4 * 64
att_i8 = 2 * d_pad * d_pad + 2 * kv * d_pad + d_pad           # wq wo wk wv gamma_a
att_i64 = 2 * (t * 32) + 256                                  # rope_cos/sin, exp
ff_i8 = d_pad + 2 * d_pad * f_pad + f_pad * d_pad             # gamma_m wg wu wd
one_public = att_i8 + ff_i8 + 8 * att_i64
print()
print(f"  ONE block's public statement: {att_i8 + ff_i8:,} B of int8 + "
      f"{8*att_i64:,} B of i64 = {one_public/2**20:.1f} MiB")
print(f"  TWELVE blocks' statements   : {L*one_public/2**20:.1f} MiB "
      f"(the run's caller holds them all unless they are streamed)")
print(f"  eleven EXTRA over one block : {(L-1)*one_public/2**20:.1f} MiB")
print(f"  eleven finished SEGMENTS held in memory (if not flushed): "
      f"{(L-1)*segmid/2**20:.0f} MiB")
peak_all = PEAK + io_interior + (L - 1) * one_public / 2 ** 20
print(f"  peak with all 12 statements resident, segments flushed: "
      f"{peak_all:.0f} MiB ({peak_all/1024:.2f} GiB)")
peak_worst = peak_all + (L - 1) * segmid / 2 ** 20
print(f"  peak if segments are NOT flushed as they are produced:  "
      f"{peak_worst:.0f} MiB ({peak_worst/1024:.2f} GiB)  <- over the 12 GiB ceiling? "
      f"{'YES' if peak_worst > 12*1024 else 'no'}")
print()

# ---------------------------------------------------------------- 3. time
print("=" * 74)
print("3. TIME")
print("=" * 74)
PROVE, WITNESS, VERIFY, DECODE, ENCODE = 26.539, 4.69, 1.027, 0.015, 0.021
a_commit_s, a_commit_rows = 2.997, A_ROWS
per_row = a_commit_s / a_commit_rows
b_commit = per_row * 38
b_open = 0.015                       # endpoint opens measured 0.010/0.008 at 1 group
print(f"  measured: prove {PROVE} s, witness {WITNESS} s, verify {VERIFY} s, "
      f"encode {ENCODE} s, decode {DECODE} s")
print(f"  boundary commit modelled at A's per-row rate: {b_commit*1000:.1f} ms")
base = L * (PROVE + WITNESS)
extra = (L - 1) * (b_commit + b_open) + (L - 1) * ENCODE
print(f"  L x (prove + witness)            = {base:.1f} s  ({base/60:.2f} min)")
print(f"  + 11 boundary commits and opens  = {extra:.1f} s")
print(f"  RUN PROVE                        = {base+extra:.1f} s  "
      f"({(base+extra)/60:.2f} min)   [draft: 6.3 min]")
print(f"  12 x prove only (the old figure) = {L*PROVE/60:.2f} min")
print(f"  RUN VERIFY  = {L*VERIFY:.1f} s + {L*DECODE:.2f} s decode "
      f"= {L*(VERIFY+DECODE):.1f} s   [draft: 12.3 s]")
print()

# ---------------------------------------------------------------- 4. soundness
print("=" * 74)
print("4. SOUNDNESS — the union bound the draft never states")
print("=" * 74)
one_block = 2 ** -101.1          # ZK60_PRIVATE_BLOCK_125M_LAYOUT.md:510
per_opening = 2 ** -105.61       # ZK60_PRIVATE_BLOCK_125M_LAYOUT_CHECK.md:1102
run = L * one_block + (L - 1) * per_opening
print(f"  one 125M block      2^{log2(one_block):.2f}   (prior documents)")
print(f"  12 blocks           2^{log2(L*one_block):.2f}")
print(f"  + 11 boundary PCS openings at 2^{log2(per_opening):.2f} each")
print(f"  RUN, L = 12         2^{log2(run):.2f}   "
      f"(prior docs' twelve-block pass: 2^-97.5)")
print(f"  the draft's section 2 is titled 'transcript order and soundness' and "
      f"gives NO such figure.")
print()

# ---------------------------------------------------------------- 5. draws
print("=" * 74)
print("5. D9 SAMPLER DRAWS — recount")
print("=" * 74)
A_MASK_WORDS = 4_030_464         # timing log line 13, measured
H_MASK_WORDS = 1_671_168         # timing log line 20, measured
a_pads, h_pads = A_ROWS * CHECKS, H_ROWS * CHECKS
m_pads = M_ROWS * CHECKS
per_block_no_io = 8_999_942      # the draft's figure
accounted = A_MASK_WORDS + a_pads + H_MASK_WORDS + h_pads
print(f"  A mask rows {A_MASK_WORDS:,} [MEASURED log line] + A pads {a_pads:,}")
print(f"  H mask rows {H_MASK_WORDS:,} [MEASURED log line] + H pads {h_pads:,}")
print(f"  subtotal {accounted:,}; the draft's per-block figure {per_block_no_io:,}")
print(f"  => M (coefficients + {m_pads:,} pads) accounts for the remaining "
      f"{per_block_no_io-accounted:,}")


def io_draws(rows, data_rows=DATA_ROWS, n=N, q=CHECKS):
    return (rows - data_rows) * n + rows * q


print(f"  boundary  38 rows: {io_draws(38):,}   [draft: 108,032]")
print(f"  endpoint  37 rows: {io_draws(37):,}   endpoint 36 rows: {io_draws(36):,}")
run_37 = L * per_block_no_io + (L - 1) * io_draws(38) + 2 * io_draws(37)
run_36 = L * per_block_no_io + (L - 1) * io_draws(38) + 2 * io_draws(36)
print(f"  RUN with 37-row external endpoints: {run_37:,} = 2^{log2(run_37):.2f}"
      f" -> residual 2^{log2(run_37)-96:.1f}   [draft: 109,370,440 / 2^-69.3]")
print(f"  RUN with 36-row external endpoints: {run_36:,} = 2^{log2(run_36):.2f}"
      f" -> residual 2^{log2(run_36)-96:.1f}")
print(f"  run_arithmetic.py prints 109,402,696 for the 36-row variant, which is "
      f"{109_402_696-run_36:,} too many:")
print(f"    it charges a 36-row endpoint SIX mask rows "
      f"(6*{N} = {6*N:,}) when 36 = 32 data + FOUR.")
print(f"  effect on the headline: none to one decimal "
      f"(2^{log2(run_36)-96:.2f} vs 2^{log2(109_402_696)-96:.2f}).")
print()
print(f"  a million runs: 2^{log2(1e6*run_37)-96:.1f}  [draft: 2^-49.4]")
print()

# ---------------------------------------------------------------- 6. refusals
print("=" * 74)
print("6. REFUSALS AT RUN SCALE")
print("=" * 74)
print(f"  12 x 2^-62  = 2^{log2(L*2**-62):.2f}   [draft: 2^-58.4]")
print(f"  12 x 2^-112 = 2^{log2(L*2**-112):.2f}  [draft: 2^-108.4]")
