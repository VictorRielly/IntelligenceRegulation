# K1 and K0 roofline timing, M3 Ultra, 2026-11-18 (UTC 15:31)

Nothing outside this folder was edited. No commit.

## What was run
One guarded gpu job (run `9c98195d5666`, exit 0, 4.7 s) after one guarded build (`66b408bfeba4`; an earlier build `e8788123b99d` was superseded, see below). GPU timestamps per command buffer, 3 warm-up reps then 15 timed reps, kernels interleaved per rep. Raw lines: `timing.log` (`K1RAW`, `K0RAW`, ms). Summary: `analysis.txt` (from `analyze.py`).

**K1.** `gen_k1.py` is a copy of the A27 `gen.py` (original untouched). Its `k_v13` is byte-identical to the unmodified generator's (`check_v13_same.py`). `k_k1` loads the same tables, words and `d` branches as v13 and xors every loaded word into the thread accumulator. `k_k1b` (extra, not the pre-stated K1) keeps the line-value arithmetic (`ln_ext`) and drops only the body. Shapes as `kb1.sh`: slot 14 = 68 tables, 2^19; slot 18 = 33 tables, 2^21; np 4; every round from cap/4 to 1. K1 loads only the 67 (slot 14) and 32 (slot 18) tables v13 reads after dead-code removal; the first build loaded one dead extra table and was replaced.

**K0.** `k_fold_tables_dev3` and `a27_fold_pair` are sliced verbatim from `metal_kernels.metal` (`mk_k0_src.py`). Shape: 22 tables, 2^20 pairs, 738,197,504 B read, 369,098,752 B written. Two copy kernels of ours: `copy_pat` (the fold's mapping and in-place store, xor instead of arithmetic) and `copy_vec` (16-byte vector streaming, separate destination). Variant `fold_mixed`: 10 of 22 tables base (c1 = 0), nearer the real slot.

## Results (medians; IQR in brackets)
| shape | v13 total ms | K1 total ms | K1/v13 | K1b ms | K1b/v13 |
|---|---|---|---|---|---|
| slot 14 | 14.095 (14.078-14.117) | 1.605 (1.595-1.609) | **0.114** | 3.651 | 0.259 |
| slot 18 | 14.250 (14.209-14.270) | 2.639 (2.629-2.649) | **0.185** | 3.571 | 0.251 |

Round 1 alone: K1/v13 0.133 (slot 14), 0.245 (slot 18). v13 reproduces `kb1.log` (14.1, 14.3 ms).

| kernel | ms | GB/s (read+write bytes / time) |
|---|---|---|
| fold (22 ext) | 1.591 (1.587-1.592) | **696** |
| fold_mixed | 1.596 | 694 |
| copy_pat | 1.574 (1.573-1.577) | **704** |
| copy_vec | 1.600 (1.584-1.602) | 692 |

Fold = **33.6%** of slot 18 window 1's 4.730 ms (33.7% for fold_mixed).

## Readings against the pre-stated thresholds
- **K1: under half of v13 at both shapes (0.11, 0.19). Reading: the body still costs; the "load-bound, arithmetic ideas dead" branch is refuted.** The 20%-band threshold is missed by a factor of four. Caution: K1 has low register use and so more occupancy than v13 can have; the gap is a ceiling for body, register and occupancy changes together, not a promise for any one.
- K1b - K1 is the line-value arithmetic: 2.0 ms of 14.1 (slot 14), 0.9 ms of 14.3 (slot 18). That is a ceiling for any line-value change (H158 and similar): about 15% and 7% of v13. The rest of the gap (K1b to v13, 10.4 and 10.7 ms) is the polynomial body and what it does to occupancy.
- **K0: 692-704 GB/s, about 0.85 of the 819 GB/s spec; no result near 500.** By the letter: copy_pat is at 700 or more; fold (696) and copy_vec (692) are 0.6-1.1% under 700, so strictly "undecided" for those two. Read together, the practical ceiling is about 700 GB/s. The "evaluation windows are saturated" branch is not supported.
- Derived, not measured: window 1 holds 1.59 ms of fold at that ceiling, leaving 3.14 ms for the evaluation, whose logical loads (about 1.2 GB) would need about 1.7 ms at 700 GB/s. So the evaluation runs well above its bandwidth floor, which agrees with K1.

## Clean or polluted
Clean: every IQR is under 1.5% of its median (limit 10%). Probes (`timing.log`): no `ds4-bench`, GPU idle at start (the later utilization samples include this job itself), guard status before and after shows 519/520 MiB GPU memory in use by others and the heavy lock free. Load average about 3 (other agents' CPU work). One timing run only; a rerun on a quiet box is the way to check run-to-run drift.

## Checks passed
K1: GPU `k_k1` equals a CPU xor reference (two thread-count cases, 0 mismatches); flipping one word of every loaded table changes the output for `k_k1` and `k_k1b` (0 insensitive); outputs of k1, k1b, v13 differ for different tables. K0: fold equals a CPU Fp2 reference on 3 tables x 64 pairs, including a base table (0 mismatches); both copy kernels equal their CPU results.

## Not verified
v13's output was not checked against a CPU polynomial (timing only, as `kb1`). No ISA dump (that the compiler drops v13's dead load is assumed from the live-table count). Random extension tables, not real witnesses. The fold ran standalone: no neighbouring kernels, tables partly in cache after the CPU re-initialisation. Slot shapes are Shieldstral R13 for K1 (as the README), W16R2_8B slot 18 for K0.

## Rerun
Guarded build: `build.sh`; guarded timing: `run.sh` (one gpu-class job, about 5 s); then `python3 analyze.py timing.log`. Guard records: `build.guard.json`, `timing.guard.json`, `guard_status_before.txt`, `guard_status_after.txt`.

## K3 and K4 (second run)
2026-11-18 15:39 UTC. Guarded build `7f871c76fcf6`, guarded gpu job `2f6d242436d3` (exit 0, 26 s). Files: `k3k4_gen.py`, `k3k4_bench.mm`, `k3k4_build.sh`, `k3k4_run.sh`, `k3k4_analyze.py`, raw `k3k4_timing.log`, `k3k4_analysis.txt`, `k3k4_build.log`, `k3k4_guard_status_before.txt`, `k3k4_*.guard.json`. 3 warm-ups, 15 interleaved timed reps. The `k_v13` text is again byte-identical to the unmodified generator's. All IQRs are at most 0.5% of the median (K4: at most 0.1%); no ds4-bench; GPU idle at start. **Clean.**

**K4 (planning numbers, no pass or fail).** 2^20 threads, eight independent chains per thread, 64 ops per thread per repetition, 16 repetitions (a 128-repetition run agrees within 1.5%). Whole-GPU time over total operations; functions exactly as in the v13 source.

| op | ps per op (16 reps) | Gop/s | ratio to gl_add | dependent-chain latency |
|---|---|---|---|---|
| gl_add | 1.71 | 586 | 1.00 | 29 ns |
| gl_mul | 4.55 | 220 | 2.66 | 64 ns |
| f2_mulb (extension by base) | 9.27 | 108 | 5.43 | not run |
| f2_mul (extension by extension) | 23.49 | 42.6 | 13.75 | 347 ns |

Latency = (t(65536) - t(16384)) / 49152 on one SIMD group. An extension multiply costs about 5.2 gl_mul, not 3.

**v13 product counts (per point, live nodes plus outputs, `k3k4_gen.py`).** Slot 14: 67 extension-by-extension, 48 base-by-extension, 0 base-by-base (297 base multiplications), plus one line-value `f2_mulb` per loaded table at d >= 2 (67 tables). Slot 18: 35, 22, 0 (149 base multiplications), 32 tables.

**K3a** = K1b's loads and line values (`ln_ext`), then exactly those body counts as multiply-then-add into four accumulators, each product with a distinct operand pair (no common subexpressions); it omits the body's other additions. Slot 14: 182 ops (67 loads, 67 ee, 48 eb); slot 18: 89. Checked before timing: GPU equals an exact-arithmetic CPU interpreter of the program (0 mismatches, two thread-count cases); flipping one lo and one hi word of every loaded table changes the output.

| shape | v13 ms | K3a ms | K3a / v13 | pre-stated reading |
|---|---|---|---|---|
| slot 14 | 14.267 | 21.762 | 1.525 | arithmetic-bound (>= 0.80) |
| slot 18 | 14.289 | 17.921 | 1.254 | arithmetic-bound (>= 0.80) |

**Caveat that limits this reading.** K3a is SLOWER than v13 although it does fewer additions. Derived, not measured: the K4 throughput numbers put the products alone (ee, eb and line values) at about 2.6 ms (slot 14) and 5.2 ms (slot 18) over these rounds, against 14.3 ms for v13. So the products at independent-chain throughput explain only about 18% and 36% of v13's time, and K3a costs 4 to 8 times that floor. The likely reason is that the compiler hoisted the loads and kept the values live, so K3a did not reach "few values live" (not verified: no register or ISA readout). By the letter the reading is "arithmetic-bound", but it is not evidence that the multiplications at throughput cost are the limit. It shows that this body's products cost much more than K4's throughput when issued the way these kernels issue them (long dependent latency, see 347 ns per extension multiply, with little occupancy to hide it).

**K3b (run).** The big output term v0 * n_big is distributed over n_big's additive sub-terms (exact in the field); the groups are balanced on product count. Every group loads only the tables its terms need. Exactness gate: sum of the G part buffers equals v13's, every word of every round of the full shape (28.3 M and 31.5 M words): 0 mismatches. Split kernels run back to back in one command buffer per round.

| shape | live tables v13 | G=2 live tables | G=4 live tables | G=2 / v13 | G=4 / v13 |
|---|---|---|---|---|---|
| slot 14 | 67 | 40, 33 | 20, 20, 17, 19 | 0.902 (small) | **0.771 (pass, 23% below)** |
| slot 18 | 32 | 21, 18 | 11, 10, 10, 12 | 0.878 (small) | 0.862 (small, 13.8% below) |

Pass at slot 14 with G=4; slot 18 misses the 15% line by 1.2 points. Base multiplications rise only by the extra v0 products (slot 14: 306 for G=4 against 297). Fewer live tables per kernel with the same products made the body faster, which points to register pressure and occupancy more than product count.

**Not verified.** No register, spill or occupancy counter was read; K3a's liveness is inferred. Random tables, Shieldstral R13 shapes, timing of rounds from cap/4 only. Split gains would need the two part buffers summed in the reduction, a cost not timed here.

## K5 (third run)
2026-11-18 15:46 UTC. Guarded build `cc8f16ccd54f` (an earlier build `73fed338d78f` stopped on a check-script comparison and was redone), guarded gpu job `736173bd1d00` (exit 0, 128 s). Files: `k5_gen.py`, `k5_bench.mm`, `k5_build.sh`, `k5_run.sh`, `k5_analyze.py`, raw `k5_timing.log`, `k5_analysis.txt`, `k5_guard_status_before.txt`, `k5_*.guard.json`, generated `build/k5_*.meta/.json` (per-kernel live tables, product counts). 3 warm-ups, 15 interleaved reps. **Clean**: every IQR at most 1.1% of the median, no ds4-bench, GPU idle at start. **Exactness gate:** every split, accumulate and grouped arm equals the reference on every word of every timed round (23.6 to 31.5 M words per shape; 1.6 M for round 0): 0 mismatches. K1 arms match a CPU xor reference. The reference k_v13 is gen.py's for the Shieldstral dumps and the dumped A27 kernel itself (renamed) for the 8B dumps, so the generator did produce the 8B polynomials; K5d needed no workaround.

**K5a, split sweep (separate kernels, each its own buffer; ratio to v13, all rounds / rounds 1 to 5).** v13 total: 14.27 and 14.26 ms (Shieldstral slots 14, 18).
| shape | G=2 | G=4 | G=8 | finest |
|---|---|---|---|---|
| slot 14 | 0.904 / 0.835 | **0.771 / 0.615** | 0.798 / 0.612 | 21 kernels: 0.937 / 0.721 |
| slot 18 | 0.879 / 0.837 | **0.865 / 0.801** | 0.889 / 0.801 | 12 kernels: 0.979 / 0.873 |

Live tables per kernel (v13: 67 and 32): slot 14 G=2 40,33; G=4 20,20,17,19; G=8 13,11,10,10,10,9,9,10; finest 13 then 3 to 6. Slot 18 G=2 21,18; G=4 11,10,10,12; G=8 6,5,7,9,6,6,4,4; finest 3 to 7. G=4 is the minimum at both shapes; G=8 flattens (slot 14) or turns up (slot 18). The gain sits in rounds 1 to 4 or 5 (round 1: 4.33 to 2.56 ms on slot 14); from round 6 on the split is slower (about 0.37 against 0.35 ms) because of dispatches and repeated products. **Best mixed schedule (derived from per-round medians):** split G=4 in rounds 1 to 5 (slot 18: 1 to 6), v13 after: 0.749-0.752 (slot 14), 0.840-0.843 (slot 18). Best arm chosen per round (G=8, 4, 2, then v13): 0.740 and 0.823.

**K5b, one kernel with four groups in scoped blocks (plain, and with a SIMD-group barrier between groups).** Ratios to v13: slot 14 1.247 and 1.264; slot 18 1.226 and 1.225; 8B slot 14 1.081 and 1.085; 8B slot 18 1.156 and 1.152. The grouped kernel is 8 to 26% SLOWER than v13, not equal to it, so the compiler did not merge the groups back and the reading falls in neither pre-stated branch (not within 3 points of the split, not within 3 points of v13). What it shows: the gain needs separate kernels; grouping inside one kernel reloads tables and does not lower the per-kernel register demand.

**K5c, accumulate in place (kernel g reads, adds, writes the previous output; no sum pass).** G=4 ratio to v13: slot 14 **0.773** (K5a split 0.771), slot 18 **0.871** (0.865), 8B slot 14 0.914 (0.907), 8B slot 18 0.967 (0.964). The read-add-write costs 0.2 to 0.7 points. These are the numbers to quote.

**K5d, W16R2_8B shapes** (reference = the dumped kernel; 39 and 21 live tables; v13 7.40 and 8.45 ms; K1 loads-only 0.109 and 0.160 of v13). Live tables G=4: slot 14 16,12,10,12; slot 18 9,7,6,7. Split ratios (G=2 / G=4, plain): slot 14 0.902 / 0.907, slot 18 0.953 / 0.964 (accumulate: 0.902 / 0.914 and 0.959 / 0.967). Pre-stated reading: slot 14 **small** (about 9 to 10% below), slot 18 **fail** (within 5%); no pass at either slot. Derived mixed schedule (split in rounds 1 to 4 or 5): 0.862 (slot 14), 0.925 (slot 18). Rounds 1 to 5 alone: 0.77 and 0.90.

**K5e, round 0 (8B slot 18, 2^21, one round).** v13 4.437 ms; K1 loads-only 0.381 of v13 (round 0 is much nearer load-bound than the later rounds); G=2 0.977 (fail), **G=4 0.925 (small)**, G=8 1.004, finest 1.039; accumulate G=4 0.928.

**Not verified.** No register, spill or occupancy counter; the mechanism for G=4's optimum is inferred. Random tables; timing of rounds from cap/4 (and one round 0) only; the host-side cost of launching extra kernels per round inside the real prover (encoders, batching) is not modelled beyond one command buffer per round; the 8B xtabs are random rather than the materialized values.
