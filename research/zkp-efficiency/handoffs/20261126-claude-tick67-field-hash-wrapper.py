"""Tick 67 (queue item 95): what a field hash does to the wrapper bill and to the commitments.
Arithmetic only; every input is labelled. Run: python3 <this file>."""
import math

# ---- inputs -----------------------------------------------------------------
# COUNTED / DERIVED in tick 62 (BLAKE3 compressions per block, 8B W16R2)
A_ROWS, H_ROWS, M_ROWS = 2501, 2602, 50
COLS_AH, COLS_M = 280, 256            # opened columns (tick 62 s2)
PATH_AH, PATH_M = 15, 12
B3_BLOCK_TODAY = (412788, 415419)     # tick 62
B3_REQ_TODAY = (13.833e6, 13.917e6)   # with join
B3_REQ_B6A = (6.99e6, 7.08e6)         # join switched
B3_BLOCK_B6A = (212438, 215069)
# Plonky3 Poseidon2 AIR column formula (columns.rs): WIDTH + (2*HALF*WIDTH + PARTIAL)*(REGS+1)
WIDTH, HALF, PARTIAL = 12, 4, 22      # Goldilocks w12: 8 full + 22 partial (two libraries' docs)
def air_cols(regs):
    return WIDTH + (2 * HALF * WIDTH + PARTIAL) * (regs + 1)
RATE = 8                              # words absorbed a permutation (capacity 4 = 32 B key/digest)
SABLE_CELLS = (4096, 5344)            # BLAKE3 cells a compression [authors: estimate, measured]
EXT_PRODUCTS_B6A = 53.4e6             # tick 55, column products at B6a
EXT_CELLS = 16                        # cells an extension op [authors, Sable estimate]
WORD_NS = 1.094                       # ns a committed word, block GPU 91.46 ms / 83.6 M words (MEASURED/COUNTED)
SABLE_CELL_NS = (2.4e3 / 5344, 1.3e3 / 5344)   # ns a cell at Sable's measured 2.4 / 1.3 us [authors]
CADENCE = 3.18                        # s a request, stream of Nov 23

print("== Poseidon2 AIR columns a permutation (Plonky3 formula, COUNTED in columns.rs; widths ASSUMED) ==")
for regs, why in ((1, "max constraint degree 3 (x^3 kept in a register)"), (0, "degree-7 constraints, no register")):
    c = air_cols(regs)
    print(f"  SBOX_REGISTERS={regs}: {c} cells ({why}); BLAKE3 4,096 -> x{4096/c:.1f}, 5,344 -> x{5344/c:.1f} fewer")

# ---- perms per block, field sponge, rate 8 ------------------------------------
def perms(words):
    return math.ceil(words / RATE)
colA = perms(A_ROWS) + 1 + PATH_AH
colH = perms(H_ROWS) + 1 + PATH_AH
colM = perms(M_ROWS) + 1 + PATH_M
cols = COLS_AH * colA + COLS_AH * colH + COLS_M * colM
vec_words = 2 * 16664                  # (n+Q) Fp2 = 266,624 B (wire.rs:107) = 33,328 words
vecA = 37 * perms(vec_words); vecH = 10 * perms(vec_words); vecM = 2 * perms(2048)
vecs = vecA + vecH + vecM
print("\n== Field-sponge permutations a block (DERIVED; BLAKE3 numbers from tick 62) ==")
print(f"  per opened column: A {colA} (BLAKE3 348), H {colH} (362), M {colM} (20)")
print(f"  columns, salts, paths: {cols:,} (BLAKE3 203,920)")
print(f"  absorbed vectors today: {vecs:,} (BLAKE3 208,615) ratio {vecs/208615:.3f}")
misc = (253, 2884)
today = [cols + vecs + m for m in misc]
print(f"  block today: {today[0]:,} to {today[1]:,} (BLAKE3 {B3_BLOCK_TODAY[0]:,} to {B3_BLOCK_TODAY[1]:,}) "
      f"ratio {today[0]/B3_BLOCK_TODAY[0]:.3f}")
tower = 4140 + 2520 + perms(2048) + 786      # W (12 perms/col) + W2 (5) + BASE (2^10 Fp2) + draws (ASSUMED 786)
b6a_block = cols + tower
print(f"  tower {tower:,}; B6a block {b6a_block:,} (BLAKE3 {B3_BLOCK_B6A[0]:,} to {B3_BLOCK_B6A[1]:,}) "
      f"ratio {b6a_block/B3_BLOCK_B6A[1]:.3f} to {b6a_block/B3_BLOCK_B6A[0]:.3f}")
join_cols = 33 * COLS_AH * (perms(38) + 1 + PATH_AH)
join_b6a = join_cols + 10000
req_today = 32 * today[0] + 31 * 0 + 0
req_b6a = 32 * b6a_block + join_b6a
print(f"  join (33 openings, columns only) {join_cols:,} (BLAKE3 194,040)")
print(f"  request at B6a: {req_b6a/1e6:.2f} M perms (BLAKE3 {B3_REQ_B6A[0]/1e6:.2f} to {B3_REQ_B6A[1]/1e6:.2f} M), "
      f"{req_b6a/B3_REQ_B6A[1]:.3f} to {req_b6a/B3_REQ_B6A[0]:.3f}")

print("\n== Layer 1 (wrapper) cells and seconds at B6a ==")
ext_cells = EXT_PRODUCTS_B6A * EXT_CELLS
for regs in (1, 0):
    hc = req_b6a * air_cols(regs)
    tot = hc + ext_cells
    t_ours = tot * WORD_NS * 1e-9
    t_lo = (hc + ext_cells) * min(SABLE_CELL_NS) * 1e-9
    print(f"  regs={regs}: hash cells {hc/1e9:.2f} G + ext-op cells {ext_cells/1e9:.2f} G = {tot/1e9:.2f} G; "
          f"at our 1.094 ns a cell {t_ours:.1f} s ({t_ours/CADENCE:.2f} cadences); "
          f"at Sable's 0.24 ns a cell {t_lo:.2f} s")
for c in SABLE_CELLS:
    print(f"  BLAKE3 at {c} cells: {7.0e6*c/1e9:.1f} G cells (+ ext {ext_cells/1e9:.2f} G) -> {(7.0e6*c+ext_cells)*WORD_NS*1e-9:.1f} s at our rate")
print("  tail of 15 to 197 s (tick 55 s3) unchanged by the hash")

print("\n== Prover side: the commitments hash every encoded column (DERIVED) ==")
ENC_W = 2 ** 15
words = (A_ROWS + H_ROWS) * ENC_W
P = words / RATE
MULS = (8 * 12 + 22) * 4 + 22 * 12      # x^7 in 4 mults a S-box; internal diagonal 12 mults per partial round (ASSUMED)
print(f"  encoded words hashed a block (A+H): {words/1e6:.1f} M = {words*8/1e9:.2f} GB; perms {P/1e6:.1f} M; mulmods a perm ~{MULS}")
total_mul = P * MULS
# device mulmod rates
bf_fwd = (A_ROWS + H_ROWS) * (ENC_W // 2) * 15
rate_ntt = bf_fwd / 14.0e-3
print(f"  NTT-implied lower bound on mulmod rate: {bf_fwd/1e9:.2f} G butterflies / 14.0 ms = {rate_ntt/1e9:.1f} G/s (tick 21/42 split, rows pairing ASSUMED)")
lanes = 80 * 128; clock = 1.4e9; ops_per_mul = 30
rate_peak = lanes * clock / ops_per_mul
print(f"  hardware ceiling (ASSUMED 80 cores x 128 lanes x 1.4 GHz / {ops_per_mul} ops a mulmod): {rate_peak/1e9:.0f} G/s")
for name, r in (("NTT-implied", rate_ntt), ("ceiling", rate_peak)):
    t = total_mul / r * 1e3
    print(f"  {name}: {total_mul/1e9:.1f} G mulmods -> {t:.0f} ms a block; extra over BLAKE3 hash (3.4 to 3.9 ms): +{t-3.9:.0f} to +{t-3.4:.0f} ms; "
          f"{(t-3.65)/91.46*100:+.0f}% of block GPU 91.46 ms; request x32: +{(t-3.65)*32/1e3:.1f} s against cadence {CADENCE} s (full pass-through)")
print(f"  WebGPU demo (M1 Max, browser): 2^16 leaves 177.2 ms, 2^20 leaves 2,119 ms; at one perm a leaf and one a node: "
      f"{177.2e-3/(2*65536)*1e6:.2f} and {2119.3e-3/(2*2**20)*1e6:.2f} us a perm -> {P*1.0e-6:.0f} to {P*1.35e-6:.0f} s a block at those rates (upper bound, leaf width unstated)")

print("\n== Verifier CPU (one thread) ==")
for ns, src in ((1291.5, "Monolith page, Goldilocks t=12, variable-time [secondary]"),):
    print(f"  {req_b6a/1e6:.2f} M perms x {ns} ns = {req_b6a*ns*1e-9:.1f} s ({src})")
print(f"  Plonky3 issue 476: Poseidon2 about 9x slower than Blake3 on Goldilocks (Merkle, 2^13 leaves, dev build, w16)")
