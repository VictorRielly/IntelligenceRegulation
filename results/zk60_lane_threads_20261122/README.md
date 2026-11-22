# Threads per lane at the installed app profile (2026-11-22 UTC)

A setting test with no code change, run by the Claude co-coordinator. The rule and the arms were posted in `ops/zkp-mvp/RECOVERY_COORDINATION.md` before any run (set 1: entry of 2026-11-22T07:59:16Z; set 2: entry of 2026-11-22T08:39:53Z). Labels: MEASURED (the raw files), DERIVED (arithmetic by `lane_threads_summary.py`).

## Why

The machine has 24 performance cores and 8 efficiency cores. The app's stream runs 6 lanes x 5 threads, which asks for 30 threads whenever the lanes are in their host phases together. That setting was inherited; at this profile only 6 x 5, 8 x 4 and 3 x 10 had been measured (research tick 29). Research tick 37 found the host gaps to be 44% of the block period with both switches on.

## What was run

The T2 stream of `results/zk60_composed_app_20261122/` with the same driver (copied here; the guard label prefix is the only change): a fresh `zk60_classify serve --lanes L --lane-threads T --witness-cache-gib 16` per leg on the installed W16R2 Shieldstral export, per-thread Metal queues, the eight public posts, L warm-up requests then 48 timed, all written at once; rate = 48 x 128 / (c[L+48] - c[L]) from one monotonic clock. Every leg uses binary B1 of that test (SHA-256 `3c86ada013dcddbdbd9855bc98cf4b6c43eae4896109e889cf3e50d50606c6ba`, checked again before the run) with `HL_METAL_FUSED_RS=1 HL_METAL_SPARSE_FOLD=1`. Every receipt was checked by `check-serve` of B0 (SHA-256 `2f2489d3476f3acf204c3933ff6e2bb8d03a437035bf882a62d8748377626c82`), outside the timed window, and deleted. No trace in any timed leg.

One set is six legs in the order X, Y, Z, Z, Y, X. Pairs: Y against X = legs (1,2) and (6,5); Z against X = legs (1,3) and (6,4).

**Rule (posted first):** GAIN if both pairs are at +3.0% or more. NO GAIN if either pair is under +1.5%. Otherwise one repeat of the set and the mean of the four pairs: GAIN if the mean is at +3.0% or more and every pair at +1.5% or more; NO GAIN if the mean is under +1.5%; else "gain under the bar". No third set. A leg counts only if all its requests are proved, all its receipts accepted, and the guard status before it shows no other heavy job.

## Set 1: X = 6 x 5, Y = 6 x 4, Z = 8 x 3 [MEASURED, guard run `3f0cd5f03f44`, 2026-11-22 08:04 to 08:38 UTC]

| leg | setting | tok/s | proved | accepted by B0 |
|---|---|---:|---:|---:|
| 1 | 6 x 5 | 46.976 | 54 | 54 |
| 2 | 6 x 4 | 45.427 | 54 | 54 |
| 3 | 8 x 3 | 45.933 | 56 | 56 |
| 4 | 8 x 3 | 45.997 | 56 | 56 |
| 5 | 6 x 4 | 44.416 | 54 | 54 |
| 6 | 6 x 5 | 47.285 | 54 | 54 |

- **6 x 4 against 6 x 5: -3.30% and -6.07%. NO GAIN.**
- **8 x 3 against 6 x 5: -2.22% and -2.72%. NO GAIN.**
- 6 x 5 from leg 1 to leg 6: +0.66%.
- 328 requests proved, 328 receipts accepted. The guard status before each leg shows this job only (`raw/lt_set1/guard_status_leg*`).
- The smoke before the set (`raw/lt_smoke`, guard run `aebc1c331bdb`): both new settings start, 28 proved, 28 accepted. No claim from its rates.

**Reading (written before the run):** both pairs of 6 x 4 are under -1.5%, so the host phases use the fifth thread, and the efficiency cores are not what stretches them. The expectation posted first was -3% to +3% for 6 x 4 (the second pair is lower) and -5% to +3% for 8 x 3.

## Not measured

Private content; the shared-queue mode; lane counts other than 6 and 8; Astra's GPU-busy capture; a second set (the rule did not ask for one).

## Files

`composed_driver.py`, `composed_launch.py`, `guarded_here.py`, `t1_driver.py`, `compress_traces.py`, `overlap_check.py` (the harness, copied from the composed test), `lane_threads_summary.py` (`python3 -I -B lane_threads_summary.py raw/lt_set1/t2_results.json`; output in `raw/lt_set1_summary.txt`), `raw/` (logs, guard records, per-leg results, guard status snapshots). No receipts and no binaries are kept. The helper scripts name the venv and export paths under the home directory's artifact folder, and the logs carry the session scratch paths; the content is public and nothing under the owner-private directory was read.
