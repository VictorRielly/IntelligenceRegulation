# Research handoff: per-slot table traffic model for H133 and H134, from counts (2026-11-18 UTC, claude-tick 14, queue item 29)

From Claude, the standing researcher. Triage material, not a work order.

**Question.** For each zero-check slot and round: which tables the later-round kernel actually reads, which are fold-only (H134), the bytes read by evaluation, read and written by the fold, and so what the fused-fold and single-fetch cuts of H133 are worth as a share of block GPU time.

**What was read and how.** Local only. The A27 slot libraries dumped for the W16R2_8B and Shieldstral profiles (`/Users/victorrielly/zk60-artifacts/a27_shader_dumps_20261117/`, parsed in full), `metal_slot.rs:358-478`, `metal.rs:3537-3560` and `4000-4075`, `metal_kernels.metal:560-620, 1072-1100`, the breakdown `summary.json` (Arm B per-round medians) and README. 2 web searches (hardware figures only). All numbers come from `20261118-claude-tick14-slot-table-traffic.py` (standard library, reads files, runs nothing on a GPU). Labels: COUNTED, MEASURED, DERIVED, ASSUMED.

## 1. What the kernels read (COUNTED from the dumps)

Table elements are 16 bytes in the buffers (two words, base tables too: `tabs[(t*cap+x)*2]`). Round 0 types base tables as one word (8 B useful), later rounds read every table as extension. The fold (`a27_fold_pair`) reads lo and hi (32 B) and writes lo (16 B) for all k + m tables each round. In `round`, window j (the trace's "j") is the fold of round j-1 followed by evaluation j; window 0 is `k_sc_mat` plus evaluation 0 (`metal.rs:3537-3560`).

| W16R2_8B slot | k + m | log cap | later-round tables read | fold-only originals | `k_sc_mat` reads |
|---|---|---|---|---|---|
| 14 (D) | 36 + 3 | 19 | 39 of 39 | **0** | 15 (all base) |
| 15 (Q), 16 (KV) | 15 + 0 | 19, 17 | 15 of 15 | 0 | 0 |
| 17 (smx) | 19 + 1 | 19 | 20 of 20 | 0 | 1 |
| 18 (F) | 19 + 3 | 21 | 21 of 22 | **1** | 10 (all base) |
| 19 (TAB) | 58 + 18 | 14 | 76 of 76 | 0 | 20 |

Shieldstral: the same except slot 14 has one fold-only original of 64 and slot 18 one of 29. (Reads are the tables that reach `out` through the body; a load nothing uses is ASSUMED removed by the Metal compiler, not checked in an ISA dump.)

**H134's premise is nearly empty.** The A27 plan replaces whole nodes by tables, but the inputs of those nodes are also read by other nodes and terms: 0 to 1 original table per slot is dead, so skipping their folds and adding the end-of-slot dot product saves 0.1 to 0.2% of block GPU (0.12 to 0.18 ms of 117.3, 0.17 to 0.26 ms of 248.9). H134 is not worth a lane [DERIVED].

## 2. Bytes per window (rounds 0 to 4, DERIVED; X = one table at the round's start)

Per table: fold reads 2X, writes X; evaluation reads X once (distinct) or about 3.5X in logical loads (7 words per pair against 2 distinct: points 0, 2, 3, 4 later; 8 at round 0). Slot 18 (8B), distinct bytes counting the fold and `k_sc_mat`, against the window time:

| window | ms | distinct MB | GB/s | with logical eval loads MB | GB/s |
|---|---|---|---|---|---|
| 0 | 6.377 | 1,141 | 179 | 2,584 | 405 |
| 1 | 4.730 | 1,460 | 309 | 2,340 | 495 |
| 2 | 2.421 | 730 | 301 | 1,170 | 483 |
| 3 | 1.250 | 365 | 292 | 585 | 468 |
| 4 | 0.619 | 183 | 295 | 293 | 473 |

Slot 14: 135 to 238 GB/s distinct, 293 to 386 logical; slots 15 and 17 similar. **The fold is 76% of window 1's distinct bytes in slot 18** (1,107 of 1,460 MB), which tick 13 did not count as separate from evaluation. Windows 0 to 4 of slots 14 to 19 are 33.6 ms, **28.6% of the 8B block GPU** (24.7% for Shieldstral); that is the most any traffic cut there can touch. Windows 5 and later sit on the dispatch floor (breakdown README) and are left out.

Hardware figures (search, no measurement found): M3 Ultra memory bandwidth 819.2 GB/s [spec listing]; no measured achievable GPU bandwidth found; system cache stated as 96 MB in one source and 64 MB per die in another (disputed, not Apple-published).

## 3. The cuts, with the accounting corrected

**Correction to tick 13, section 2.** I wrote fused fold-then-evaluate alone as (e + 0.5)N, a 17 to 22% cut. That assumed the e evaluation fetches fall on the folded (half-size) table. A fused kernel reads the unfolded table, twice the elements, at the same multiplicity, unless it also fetches once. Per table, in units of X: today (3 + e); fused alone (2e + 1); single fetch alone 4; both 3. Fusion alone pays only when e < 2 (re-reads mostly cache hits); single fetch alone pays only when e is large; **fusion adds little to single fetch** and the two halves are not independent. Tick 13's 22%/44%/67% figures are withdrawn for the first two; the "both" form stands (reads once, writes once).

Share of block GPU, W16R2_8B, upper bounds (window time taken proportional to bytes, all of slots 14 to 19, windows 0 to 4):

| scenario for e (evaluation re-reads) | single fetch alone | fused alone | both | H134 |
|---|---|---|---|---|
| cache hits (e = 1) | 0% | 4.3% | 4.3% | 0.2% |
| every logical load reaches DRAM (e = 3.5) | 12.9% | -3.8% | 15.6% | 0.1% |
| as previous, windows with a 96 MB footprint or less held in cache | 10.8% | -2.9% | 12.7% | 0.1% |

Shieldstral: both 3.5% / 13.2% / 12.2%. On a request, a share s of block GPU is about 1/(1 - s) on proved tokens per second if the stream stays GPU-paced (cadence 3.7455 s against 3.753 s solo block sum, MEASURED), so x1.04 (cache) to x1.19 (DRAM) as an upper bound; Antigravity's -0.25 to -0.40 s (6.7 to 10.7%) sits inside. Which end is true is exactly the unmeasured e: the window rates in section 2 (about 300 GB/s distinct, about 480 GB/s with logical loads) are both below 819 GB/s, so neither scenario is excluded by the spec.

## 4. New small item, H161: base tables at 8 bytes until the first fold

Base-typed tables are read as one word but stored at 16 B stride, so a cache line fetched for round 0 carries the zero c1 word too (ASSUMED line-granular traffic). Holding base tables at 8 B until the first fold would cut, for the live base tables and the 10 to 15 base tables `k_sc_mat` reads, window 0 by 27 to 35% of distinct bytes and window 1 (the first fold's read) by 13 to 15%. DERIVED upper bound (time proportional to bytes): 5.3 ms per block on 8B = **4.5% of block GPU** (4.7% Shieldstral). It touches the table build (A12), `finals_inner` and the fold, so it is a larger code change than a kernel edit; it changes no field element.

## 5. Falsifiable tests (project terms, nothing run)

- **K0, copy roofline and fold alone.** Time `k_fold_tables_dev3` alone at slot 18's window-1 shape (22 tables, half 2^20: 738 MB read, 369 MB written) and a plain copy of the same bytes. Practical bandwidth B = bytes / time. If B is near 500 GB/s, the DRAM scenario's window rates (about 480 GB/s) mean saturation and single fetch pays; if B is 700 or more, the evaluation windows are not bandwidth-bound and H133's gain is capped near the cache column. Fold time alone also gives the fold's share of window 1 directly (the model says 76% of bytes).
- **F2/F3 as in ticks 12 and 13**, unchanged; add the prediction: with F3 DRAM bytes for slot 18 window 1, about 1.46 GB means cache scenario, about 2.3 GB DRAM scenario.
- **H161:** halve the round-0 and first-fold reads of base tables in a `kbench` variant (tables packed at 8 B); pass if slot 14 or 18 window 0 + 1 drops at least 8% with identical `part` and folded tables; fail under 3%.

## 6. Honest expected effect

- **Committed words per request: none.** Kernel and buffer layout only; same field elements, transcript, verifier, profile; no ruling or Lean change.
- **Proved tokens per second:** the single-fetch-with-fusion design: x1.00 to x1.04 if e is near 1, up to about x1.19 if every logical load is DRAM traffic; central value not claimable before K0. H134: x1.001. H161: at most x1.05, probably x1.01 to x1.03 [DERIVED upper bounds, ASSUMED proportionality].

## 7. Risks and what was not verified

- Time proportional to bytes is an upper bound; round 0 evaluates five points with base-field products and the fold has multiplications, so some of each window is not memory time (tick 12: arithmetic was not the limiter on the evaluation kernel).
- Live sets assume load elimination by the compiler; logical loads assume every point group loads its own pair (M4g, `metal_slot.rs:401-409`), with no allowance for cache hits within a threadgroup. Windows 5 and up, the table build and the batched (production) path's different barriers are not modelled; the dump was the A27 libraries, timings are Arm B (unbatched).
- Antigravity's `results/zk60_h133_sram_kbench_20261117/` holds a bench source and kernel variants (`k_simd_round`, `k_fused_simd_round`, ...) but no timing results; I did not read `kbench.mm` or the variants beyond their header, so I cannot say whether F1/F2 were already run.
- Hardware figures are search snippets, not read in full.
