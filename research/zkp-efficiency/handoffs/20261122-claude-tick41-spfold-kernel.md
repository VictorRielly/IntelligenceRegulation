# Research handoff: the spfold kernel against its floors (2026-11-22, claude tick 41, queue item 67)

From Claude, the standing researcher. Local reading and arithmetic only: no web search, no build, no run, no Git.
Script: `20261122-claude-tick41-spfold-kernel.py` (standard library, `python3 -I -B`, reads no file, prints every number).
**Triage material, not a work order.** The kernel change proposed here keeps the committed words, the transcript and the
output bytes (canonical Goldilocks sums are order independent, and the kernel already reorders them against the host fold),
so it needs no profile change and no Lean re-proof; it does need the project's own byte-identity tests.

**Read, and how.** In full: `metal_kernels.metal:924-1009` (`k_fold_sparse_partial`, `k_fold_sparse_reduce`),
`metal.rs:1736-1987` (`fold_rows_sparse_device`: limits, CSR build, block count, dispatch), `metal.rs:1500-1600` (callers),
`metal.rs:1989-2013` (test entry `fold_rows_sparse_for_test`, `FOLD_CAPTURE` at 2181); tick 40 sections 1 to 3 and its
table; the trace's `spfold` detail strings (`results/zk60_lane_threads_20261122/raw/traces/lt_trace_leg3`, via `xz -dc`).
Labels: COUNTED (file:line or trace string), MEASURED (tick 40's one-lane execution, partial + reduce together), DERIVED
(the script), ASSUMED.

## 1. What the kernel does (COUNTED)

- One threadgroup is **32 threads (one SIMD group), 0 barriers** (`metal_kernels.metal:924-928`, dispatch
  `metal.rs:1955-1958`). A thread owns one column `j`; a threadgroup owns 32 adjacent columns and one **row block** `b`
  (`tg.y`). It keeps **k accumulator pairs in threadgroup memory**, `acc[(g<<6)+lid]` and `+32`: **k x 512 B per group**
  (`tg_bytes = k*32*16`, `metal.rs:1827`; tick 40's "k x 64 x 8 B" is the same number). Limit 32 KiB, so k <= 64.
- Per row of its block (`:970-982`): load `row_idx[r]`, then `v = col_base[row*stride]` (one 256 B coalesced load per
  SIMD group), skip if `v == 0`, load `row_starts[r]`, `[r+1]`, then per term `term_r[t]` (16 B) and `term_g[t]`, two
  `gl_mul` and two `gl_add` through threadgroup memory. The row loop is serial inside a thread; a chain of about three
  dependent loads per row (index, then value; starts, then terms).
- At the end each thread writes its k pairs to the `part` buffer (`:984-988`); `k_fold_sparse_reduce` (`:991-1009`)
  re-reads all of it and sums over blocks. Blocks: `min(ceil(262144/cols), 16, 128 MiB/(k*cols*16), active/64)`
  (`metal.rs:1870-1874`).
- Shapes in the trace (COUNTED): **A** `rows=2504 active=2504 nnz=5658 n=16384 q=280 k=37 blocks=13`; **H**
  `rows=2606 nnz=7726 k=10 blocks=16`; both 16,664 columns, so 521 column tiles.

## 2. Where A's 4.18 ms goes against H's 1.85 ms (DERIVED, script)

| | A (k = 37) | H (k = 10) |
|---|---:|---:|
| threadgroups of 32 threads | 6,773 | 8,336 |
| threadgroup memory per group | 18,944 B | 5,120 B |
| terms per row / per vector | 2.26 / 153 | 2.96 / 773 |
| `gl_mul` | 188.6 M | 257.5 M |
| bytes: read + partials written and re-read + out | 334 + 128 + 128 + 10 MB | 347 + 43 + 43 + 3 MB |
| floor, bytes at 700 GB/s (K0) / mul at 220 G/s (K4) / sum | 0.86 / 0.86 / 1.71 ms | 0.62 / 1.17 / 1.79 ms |
| MEASURED (tick 40) | 4.18 ms = **2.44x the sum**, 4.9x the larger | 1.85 ms = **1.03x the sum** |
| attained read / `gl_mul` rate | 80 GB/s (11%) / 45 G/s (21%) | 188 GB/s (27%) / 139 G/s (63%) |

**The same kernel code reaches its floors on H and misses them by 2.4 to 4.9 times on A.** Tick 40 put the whole kernel
at "2.4 to 4.9 times its floors"; the split is that the H launch is already at its floor and only A is not. Differences
between the two launches: threadgroup memory per group (3.7x), terms per row (2.96 against 2.26), vector length
(773 against 153 terms), blocks (16 against 13). My reading, **ASSUMED**: A's 19 KB per group limits how many of the
32-thread groups are resident per core, so almost nothing hides the serial dependent-load chain; H's 5 KB lets several
groups share a core. The per-row cost fits this: at one resident group per core A's 6,773 groups run in 85 waves of 49 us,
256 ns a row (a plausible two or three cache-hit latencies); I do not know the resident-group limit of this GPU (Apple
documents 32 KiB per group; the per-core pool and the M3 dynamic-caching split are not something I could verify), so the
numbers for 2, 3 and 6 groups a core in the script do not discriminate. Other explanations are not excluded (the
`v == 0` skip, the 13 against 16 blocks, the partial write pattern).

## 3. What a layout that keeps fewer accumulators live would do (DERIVED; same output bytes)

**Layout B: one thread per (column, vector), terms listed by vector (CSC), accumulators in two registers, no threadgroup
memory, no partials, no reduce kernel.** The host already builds a CSR per call (`metal.rs:1844-1862`); a CSC is the same
O(nnz) pass over the same `rho` entries.
- Per thread about 153 terms at A (5,658/37): an index load, a value load (256 B per SIMD group, coalesced), two `gl_mul`,
  two register adds; the loads of different terms are independent, so the loop pipelines instead of chaining.
- Groups: 521 tiles x 37 = 19,277 (3x today), no threadgroup memory, so occupancy is set by registers only.
- Logical row loads rise to 754 MB (2.26x, one load per term instead of per row). DRAM traffic stays 334 MB **only if the
  37 groups of a column tile run together** (grid with the vector index fastest; the tile's rows are 641 KB). Output 9.9 MB
  against 128 MB written and 128 MB re-read today.
- Floor: bytes 0.49 ms, mul 0.86 ms, sum 1.35 ms (A today 1.71). At the rate H already attains (139 G `gl_mul`/s), A would
  take **1.35 ms, saving 2.8 ms of 4.18**; that is the optimistic end, since it assumes layout B matches H's efficiency.
- **Risk, unverified:** term counts per vector are unequal (H averages 773 and A 153 but the spread is not retained; no
  capture of A's `rho` is on disk) and a thread's work is its vector's length, so one long vector sets the tail. A
  g-chunk grid (chunks of 8 vectors, registers, CSR per chunk, partials kept) would trade that for more row loads; it
  needs the same histogram to choose.
- Value (tick 40's exchange range 0.27 to 0.8% of the six-lane rate per one-lane device ms): **0.8 to 2.3% of rate for
  2.8 ms**, 0.3 to 0.8% for 1 ms. H could gain at most 0.7 ms (1.85 to its 1.17 mul floor). Under the 5% rule neither is a lane.

**Cheaper than any rewrite: split the 37 vectors across calls of the unchanged kernel** (e.g. 19 + 18: 9.7 KB groups). The
script shows the cost: each call re-reads the 334 MB (668 MB for two calls, 1,335 MB for four), so this cannot reach 2.1 ms
if the re-read goes to DRAM; it is a diagnostic, not a candidate.

## 4. Falsifiable tests (kernel alone; not scheduled; GPU, so through the resource guard, class gpu, seconds)

All on a captured A-shape input (`FOLD_CAPTURE` in a `cfg(test)` build, `metal.rs:2181`; replay through
`fold_rows_sparse_for_test`, `:1993`). Outputs compared as bytes against the current kernel on the same capture.
- **T-occ (decides the reading; no kernel change).** Run the H capture (k = 10) with the threadgroup allocation set to
  A's 18,944 B instead of 5,120 (`set_threadgroup_memory_length`, `metal.rs:1954`; the kernel uses only k x 512 B of it,
  so the output is unchanged). If resident groups limit the rate H rises toward A's per-group speed: the script gives
  **about 4.3 ms** (2.3x). **Confirmed at 3.0 ms or more; refuted at 2.2 ms or less** (then the cost is in the A shape's
  data or chain, and layout B is unsupported). Report the A and H times as the buffer's `gpu_end - gpu_start`, median of 20.
- **T-B (only if T-occ confirms).** Layout B on the A capture, with the host CSC build timed apart. **Pass: 2.1 ms or
  less** (device, partial and reduce kernels together replaced by one dispatch), byte-identical; **kill at 3.5 ms or more**.
  Also record the per-vector term histogram of the capture first (a CPU count): if the longest vector is over 4x the mean,
  B's tail decides and the g-chunk grid is the one to try.
- **T-H (optional).** The same layout on H: pass 1.4 ms or less.

## 5. Expected effect

Committed words per request: **0** (same bytes out, same transcript). Proved tokens per second: **0.8 to 2.3% at the top
of the range if A reaches H's efficiency; 0.3 to 0.8% per ms saved**, from tick 40's non-constant exchange rate (a device
ms is worth about 3 ms of block period at six lanes at the present operating point). A CSC build adds host time of the
same order as today's CSR build (not measured). `HL_METAL_SPARSE_FOLD` is off by default (`metal.rs:1748`), so any gain
exists only where that switch is set, as in the traced app profile.

## 6. Risks and what was not verified

- I did not run or time anything: every ratio is tick 40's trace time against floors from the K0 and K4 records.
- The resident-group limit of the GPU is not known to me; T-occ exists because of that.
- H's efficiency is one launch with different term density; carrying it to A is an optimistic assumption.
- A's per-vector term spread is not on disk. Tick 40's "334 MB read" counts every row (a `v == 0` row is still read as a
  word); how many words are zero is not known.
- Layout B's L2 reuse across the 37 groups of a tile is assumed (grid order); a read counter would settle it.
- The 1.85 ms H figure and the 4.18 ms A figure are one-lane, traced runs (tick 40's limits apply).
