#!/usr/bin/env python3
"""Tick 55 (queue item 90): what a recursive wrapper for kilobyte receipts costs for this verifier.

Standard library only, reads no file, runs in well under a second.
Every input is labelled: COUNTED / MEASURED (record cited in the handoff), [AUTHORS] (a source's number),
ASSUMED (mine). Everything printed is DERIVED from them.
"""
import datetime
import math

print("clock", datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))

BLOCKS = 32                      # COUNTED: 8B profile, 32 blocks
CADENCE_S = 3.7455               # MEASURED: 8B stream cadence used by ticks 22 onward
BLOCK_GPU_MS = 91.46             # MEASURED: corrected block GPU (tick 21, coordinator)
WORDS_PER_BLOCK = 83.6e6         # COUNTED: committed words per block today (tick 52)

# ---- 1. the verifier's work for one request (B6 study 3.3 table, 'per block' columns) -------------
HASHED_MB = {'today': 12.0, 'B6a': 12.2, 'B6b': 2.2}      # bytes hashed per block [MODEL/CODE, B6 study 3.3]
ABSORB_MB = {'today': 12.5, 'B6a': 0.0, 'B6b': 0.0}       # bytes absorbed into the transcript per block
PRODUCTS = {'today': 33.2e6, 'B6a': 1.67e6, 'B6b': 0.08e6}  # column products per block
NTT_PTS = {'today': 3.08e6, 'B6a': 4e3, 'B6b': 4e3}
TREE_OVERHEAD = 1.06             # ASSUMED: BLAKE3 over ~21 KB = 21 chunks x 16 compressions + 20 parents (1.06x of bytes/64)
PATH_COMP_PER_BLOCK = 280 * 3 * 15   # ASSUMED: Q = 280 columns x 3 trees (A, H, M) x ~15 hops, one compression a hop
SALT_COMP_PER_BLOCK = 280 * 3        # COUNTED in kind: leaf = blake3(unsalted leaf || salt), pcs.rs:695-700, one compression

print("\n== 1. verifier work per request (32 blocks) ==")
comps = {}
for k in ('today', 'B6a', 'B6b'):
    leaf = HASHED_MB[k] * 1e6 / 64 * TREE_OVERHEAD
    absorb = ABSORB_MB[k] * 1e6 / 64 * TREE_OVERHEAD
    path = PATH_COMP_PER_BLOCK + SALT_COMP_PER_BLOCK
    per_block = leaf + absorb + path
    comps[k] = per_block * BLOCKS
    print(f"{k:6s} compressions/block: leaf {leaf:9.0f} absorb {absorb:9.0f} paths+salts {path:6d} = {per_block:9.0f};"
          f" per request {comps[k]/1e6:6.2f} M;  column products {PRODUCTS[k]*BLOCKS/1e6:8.1f} M;  NTT points {NTT_PTS[k]*BLOCKS/1e6:7.2f} M")

# Sable (arXiv 2611.14083) comparison [AUTHORS]: 17.8 M compressions at 360 MiB, 4.22 M after cuts at 134.8 MiB
print("compressions per MiB of receipt: ours today", f"{comps['today']/ (818.7e6/2**20) /1e6:.4f} M/MiB;",
      "Sable 360 MiB", f"{17.8/360:.4f};", "Sable 134.8 MiB", f"{4.22/134.8:.4f}")

# public weight fold: tick 54's 14 G mults a request (DERIVED there), 16 cells per extension operation [Sable estimate]
FOLD_MULTS = 14e9
print(f"\nweight fold today: {FOLD_MULTS/1e9:.0f} G mults x 16 cells = {FOLD_MULTS*16/1e9:.0f} G cells "
      f"(= {FOLD_MULTS*16/ (WORDS_PER_BLOCK*BLOCKS):.0f} x the request's {WORDS_PER_BLOCK*BLOCKS/1e9:.2f} G committed words)")
# replacement: a plain (non-hiding) opening of the public weights, 2^16-wide rows, rate 1/2, Q' = 277 (tick 54 table)
rows = 218_103_808 / 2**16
open_mb = 277 * rows * 8 / 1e6
open_comp = open_mb * 1e6 / 64 * TREE_OVERHEAD * BLOCKS
print(f"plain weight opening per block at 2^16: {rows:.0f} rows x 277 cols x 8 B = {open_mb:.2f} MB; "
      f"per request {open_mb*BLOCKS:.0f} MB = {open_comp/1e6:.2f} M compressions (ASSUMED shape; item 13 prices it properly)")

# ---- 2. wrapper layer-1 prover time: the verifier's hashing arithmetized in this project's own system ------------
print("\n== 2. layer 1 (verifier circuit, same proof system), BLAKE3 only ==")
SABLE_US = 2.8                    # [AUTHORS] 'constraint proof' per compression, hardware and scope unread
CELLS = 4096                      # [AUTHORS, Sable 10.1, their naive estimate] trace cells per compression
NS_PER_WORD = BLOCK_GPU_MS * 1e6 / WORDS_PER_BLOCK   # DERIVED: whole-block device ns per committed word
print(f"our device cost per committed word: {NS_PER_WORD:.3f} ns  -> {CELLS*NS_PER_WORD/1e3:.2f} us per compression at {CELLS} cells")
base_tps_note = 128 / CADENCE_S
for k in ('today', 'B6a', 'B6b'):
    c = comps[k]
    lo = c * SABLE_US * 1e-6
    hi = c * CELLS * NS_PER_WORD * 1e-9
    cells = c * CELLS
    print(f"{k:6s} {c/1e6:6.2f} M compressions: {lo:6.1f} s at 2.8 us ... {hi:6.1f} s at our measured word rate;"
          f" {cells/1e9:6.1f} G cells = {cells/(WORDS_PER_BLOCK*BLOCKS):5.1f} x the request's committed words;"
          f" x{lo/CADENCE_S:4.1f} to x{hi/CADENCE_S:4.1f} of the 3.7455 s cadence")
    print(f"       if serial on the proving device: request rate falls to {CADENCE_S/(CADENCE_S+hi):.2f} .. {CADENCE_S/(CADENCE_S+lo):.2f} of today's")

# lookups for the XOR tables: 16 per G row, 56 G rows a compression [AUTHORS, Sable]
lk = 56 * 16
print(f"\nXOR-table lookups: {lk} per compression -> B6a {comps['B6a']*lk/1e9:.1f} G against the request's 32.28 M x 32 = {32.28e6*BLOCKS/1e9:.2f} G lookups")

# ---- 3. non-hash verifier work, B6a ------------------------------------------------------------------------------
prod = PRODUCTS['B6a'] * BLOCKS
for ops_cells in (16,):
    print(f"\nB6a column products {prod/1e6:.1f} M x {ops_cells} cells = {prod*ops_cells/1e9:.2f} G cells "
          f"({prod*ops_cells/(comps['B6a']*CELLS)*100:.1f}% of the hashing's cells)")

# ---- 4. constant tail: shrink and Groth16 ---------------------------------------------------------------------
print("\n== 4. constant tail (independent of the request) ==")
print("RISC Zero Groth16 wrap, this box, native tools, 2026-09-18 (decisions D6): 197 s MEASURED, receipt 785 bytes")
print("RISC Zero blog 2024 [AUTHORS, dated], CUDA: about 15 s STARK-to-SNARK against 2.5 s for the STARK")
print("independent SP1-stack settlement project [search summary, unchecked]: base 48 + layer 1 26 + shrink 59 + witness 12 + Groth16 50 = 195 s")
print(f"tail of 15 .. 197 s is {15/CADENCE_S:.0f} .. {197/CADENCE_S:.0f} cadences, per request, whatever the request size")

# ---- 5. zkVM-guest route: cycles (all ASSUMED; no BLAKE3 cycle figure found) ---------------------------------------
print("\n== 5. zkVM guest route (RISC Zero style), cycles ASSUMED ==")
for cyc in (1500, 2500):
    print(f"software BLAKE3 at {cyc} cycles a compression: B6a {comps['B6a']*cyc/1e9:.1f} G cycles = {comps['B6a']*cyc/2**20/1e3:.1f} k segments of 2^20")
print("no cycle figure for BLAKE3 in any zkVM was found; test T-W3 (execute only) measures it")
