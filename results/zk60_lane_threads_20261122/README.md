# Threads per lane at the installed app profile (2026-11-22 UTC)

A setting test with no code change, run by the Claude co-coordinator. The rule and the arms were posted in `ops/zkp-mvp/RECOVERY_COORDINATION.md` before any run (set 1: entry of 2026-11-22T07:59:16Z; set 2: entry of 2026-11-22T08:39:53Z; set 3: entry of 2026-11-22T10:07:00Z). Labels: MEASURED (the raw files), DERIVED (arithmetic by `lane_threads_summary.py`).

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

## Set 2 and its repeat: X = 6 x 5, Y = 6 x 6, Z = 6 x 8 [MEASURED, guard runs `1f8a7114ab3b` (09:00 to 09:32 UTC) and `39fccb343151` (09:32 to 10:05 UTC)]

The first pass put both candidates between the two thresholds, so the set was repeated once and the mean of the four pairs decides, as the rule says.

| leg | setting | set 2, tok/s | repeat, tok/s |
|---|---|---:|---:|
| 1 | 6 x 5 | 47.236 | 47.402 |
| 2 | 6 x 6 | 48.410 | 47.659 |
| 3 | 6 x 8 | 48.073 | 48.437 |
| 4 | 6 x 8 | 48.977 | 49.111 |
| 5 | 6 x 6 | 48.408 | 48.011 |
| 6 | 6 x 5 | 47.189 | 46.558 |

- **6 x 8 against 6 x 5: +1.77%, +3.79%, +2.18%, +5.48%. Mean +3.31%, lowest +1.77%. GAIN.**
- **6 x 6 against 6 x 5: +2.48%, +2.58%, +0.54%, +3.12%. Mean +2.18%. Gain under the bar.**
- Levels (mean of four legs): 6 x 5 47.10, 6 x 6 48.12, 6 x 8 48.65 tok/s.
- 648 requests proved, 648 receipts accepted over the two sets. The guard status before each leg shows this job only.
- The smoke before the set (`raw/lt_smoke2`, guard run `a46f172b9f7b`): 24 proved, 24 accepted. No claim from its rates.
- `raw/lt_set2b_summary.txt` prints the first-pass verdict for the repeat taken alone; that verdict does not apply to a repeat. `raw/lt_set2_four_pairs.txt` is the one that counts.

**Reading:** about +3% from `--lane-threads 8` in place of 5, with the same receipts. The gain is small and the pairs spread from +1.8% to +5.5%; the last pair is helped by a low 6 x 5 leg (46.56). The expectation posted first was -1% to +3% for 6 x 6 and -4% to +3% for 6 x 8. With set 1, the thread axis at six lanes reads: four threads -4.7%, five 0, six +2.2%, eight +3.3%.

## Set 3: X = 6 x 8, Y = 6 x 12, Z = 5 x 10 [MEASURED, guard run `a0e31e7ab080`, 10:12 to 10:45 UTC; rule and arms posted at 2026-11-22T10:07:00Z]

| leg | setting | tok/s | proved | accepted by B0 |
|---|---|---:|---:|---:|
| 1 | 6 x 8 | 48.548 | 54 | 54 |
| 2 | 6 x 12 | 46.909 | 54 | 54 |
| 3 | 5 x 10 | 44.779 | 53 | 53 |
| 4 | 5 x 10 | 44.321 | 53 | 53 |
| 5 | 6 x 12 | 46.971 | 54 | 54 |
| 6 | 6 x 8 | 48.675 | 54 | 54 |

- **6 x 12 against 6 x 8: -3.38% and -3.50%. NO GAIN.**
- **5 x 10 against 6 x 8: -7.77% and -8.94%. NO GAIN.**
- 6 x 8 from leg 1 to leg 6: +0.26%. 322 requests proved, 322 receipts accepted. The guard status before each leg shows this job only.
- The smoke before the set (`raw/lt_smoke3`, guard run `8fdf4f3ec60d`): 22 proved, 22 accepted. No claim from its rates.
- The expectation posted first was -2% to +2% for 6 x 12 and -6% to +2% for 5 x 10: both results are lower.

## All settings together

Level means over all timed legs of the day (binary B1, both switches on, per-thread queues). The last column compares level means across sets and is DERIVED; the paired results above are what the rule reads.

| setting | legs | mean tok/s | level against the 6 x 5 level |
|---|---:|---:|---:|
| 6 x 4 | 2 | 44.92 | -4.6% |
| 8 x 3 | 2 | 45.97 | -2.4% |
| 6 x 5 | 6 | 47.11 | 0 |
| 6 x 6 | 4 | 48.12 | +2.2% |
| **6 x 8** | 6 | **48.64** | **+3.2%** |
| 6 x 12 | 2 | 46.94 | -0.4% |
| 5 x 10 | 2 | 44.55 | -5.4% |

**Conclusion:** on per-thread queues the best measured setting is 6 lanes x 8 threads, about +3% over 6 x 5 (GAIN by the posted rule in set 2 with its repeat), and its neighbours on both sides are lower. Seven, nine and ten threads were not measured. 1,298 receipts were accepted by the previous head's verifier in the four timed sets (1,489 with the smokes and the traced run).

## Traced run [MEASURED once, guard run `1bedfa3b8cd9`, 08:44 to 08:59 UTC]

Three legs with `HL_A27_GPU_TRACE`: 6 x 5 (46.94 tok/s traced), 6 x 4 (44.54), one lane x 5 threads with 8 timed requests (12.40). 117 receipts accepted. The traces are in `raw/traces/*.tsv.xz` (compressed by `compress_traces.py`, round trip checked). Traced rates are not compared with untraced ones. Reading the gap tables is queue item 64 of the background researcher.

## Tail-round setting at 6 x 8 [MEASURED, guard runs `6acc13611b3a` (15:13 to 15:45 UTC) and `0ed4b573137a` (15:46 to 16:19 UTC); smoke runs `fecd13f0a7a5` and `b9dec84934f2`; rule and arms posted at 15:13:20Z before any timed run]

**Why.** Research tick 40 (`research/zkp-efficiency/handoffs/20261122-claude-tick40-device-demand.md`) ranked "more tail rounds on the host" first among the cuts of device work that keep the committed words, and it is a setting. A zero-check slot runs its leading sumcheck rounds on the device in one command buffer; the host takes a round once its estimated host cost is at or under a budget (`BATCH_TAIL_BUDGET_S`, 25 microseconds, `HL_METAL_BATCH_TAIL_US`; `metal.rs:4426-4438`, `4670-4690`). "Which side computes a round changes no byte (M4k)."

**Arms (all binary B1, both switches on, 6 lanes x 8 threads, per-thread queues, the settings above):** C = defaults; D = `HL_METAL_BATCH_TAIL_US=250`; E = `HL_METAL_BATCH_TAIL_US=1000` with `HL_METAL_TAIL_BUDGET_US=1000`; F = `HL_METAL_BATCH_TAIL_US=1000` alone (smoke only).

**Smoke runs, traced, 12 requests a leg, no rate quoted (`python3 -I -B tail_rounds_nd.py raw/traces/tr_smoke*.tsv.xz`).** Device rounds a block in the 12 main slots, of 218 rounds in all: 141 at the default (`lt_trace_leg1`, 6 x 5), 105 in arm D, 79 in arm E. All 36 receipts accepted by the base verifier. Arm F (leg 2 of `tr_smoke`, recorded there under the letter E) showed a second budget: rounds that are not batched have their own (`TAIL_ROUND_BUDGET_S`, 250 microseconds, `metal.rs:4237`), so with the batched budget alone at 1000 each slot ran two rounds and one fold as command buffers of their own (36 more buffers and 9.3 ms of execution a block). A value above 250 therefore needs both budgets raised; arm E does that, and `tr_smoke2` shows no such buffers beyond the rare slots.

**Timed sets, six legs X, Y, Z, Z, Y, X with X = C, Y = D, Z = E (tok/s; every leg 54 of 54 proved and 54 of 54 receipts accepted by the base verifier):**

| set | X | Y | Z | Z | Y | X | Y over X | Z over X |
|---|---:|---:|---:|---:|---:|---:|---|---|
| `tr_set1` | 49.469 | 50.821 | 49.778 | 49.319 | 49.870 | 48.017 | +2.73%, +3.86% | +0.62%, +2.71% |
| `tr_set1b` (the one repeat) | 49.171 | 49.846 | 49.626 | 50.058 | 49.450 | 49.194 | +1.37%, +0.52% | +0.92%, +1.76% |

**Verdicts by the posted rule.** Y (250): the first pass was between the bars (both pairs at or above +1.5%, one under +3.0%), so the six legs were repeated once; the four pairs have a mean of **+2.12%** and a lowest pair of +0.52%: **gain under the bar**. Z (both budgets at 1000): **NO GAIN** at the first pass (one pair under +1.5%); with the repeat's legs its four pairs have a mean of +1.50%, which adds data and no verdict. Levels over four legs each: X 48.96, Y 50.00, Z 49.70 tok/s. All eight pairs are positive.

**Limits.** The X leg that closes the first pass (48.02) is 2.9% under the X leg that opens it; without that leg the X level is 49.28 and Y's gain over it is +1.5%. So the honest range for the 250 setting is about +1.5% to +2%. One public stream, one machine state, one binary. No agent and no other heavy job ran beside any timed leg. Summaries: `raw/tr_set1_summary.txt`, `raw/tr_set1b_summary.txt`, `raw/tr_set1_four_pairs.txt` (the summary script prints every arm as "6x8"; the arm letter is in each leg's line).

## The two speeds of the gate and up sealing buffers [MEASURED from retained traces, nothing run; 2026-11-22 19:59 UTC]

Research tick 42 found that the largest sealing buffer (`wprod ... k=4096 n=16384`, the gate and the up product of a block) takes about 3.4 ms or about 5.8 ms at one lane, about half each, and is fast in 93% to 95% of cases at six lanes. `sealing_pair_check.py` reads four traces (this record's one-lane and six-lane legs and the same two of `zk60_lanes_trace_20261121`, the previous binary); output in `raw/sealing_pair_check.txt`.

| trace | device start offset in the pair | pairs | first buffer, submit to start | pair, first start to last end | slow buffers |
|---|---|---:|---:|---:|---:|
| one lane, Nov 21 | under 0.1 ms | 71 (40%) | 1.09 ms | 6.63 ms | 100% |
| one lane, Nov 21 | 0.3 to 0.6 ms | 95 (54%) | 0.65 ms | 4.17 ms | 21% |
| one lane, Nov 22 | under 0.1 ms | 80 (34%) | 1.11 ms | 6.20 ms | 100% |
| one lane, Nov 22 | 0.3 to 0.6 ms | 141 (61%) | 0.68 ms | 4.16 ms | 19% |
| six lanes, Nov 21 | under 0.1 ms | 4 of 998 | 2.21 ms | 6.26 ms | 75% |
| six lanes, Nov 22 | under 0.1 ms | 15 of 1,004 | 1.37 ms | 6.18 ms | 73% |

The host submits the two buffers within 0.01 ms of each other in every pair. When the device starts both in the same instant the pair takes 6.2 to 6.6 ms; when it starts them 0.3 to 0.6 ms apart, 4.2 ms. So the speed is set by the device's start timing of two equal buffers, not by the layer's weights and not by load before the pair. The cause inside the driver is not visible in a trace. Cost: about 1.0 to 1.3 ms a block at one lane (26 to 34 ms a request), nothing measurable at six lanes. A submit offset of 0.4 ms between the two products is the obvious test and was not run, since the six-lane rate gains nothing from it.

## Not measured

A submit offset between the gate and the up product; whether a common start slows the proof's own buffers (a quick look at six lanes showed mixed signs). Tail budgets other than 250 and 1000; a budget that adapts to the number of busy lanes. Private content; the shared-queue mode; lane counts other than 5 (set 3), 6 and 8; Astra's GPU-busy capture; the machine with other work on the GPU.

## Files

`composed_driver.py`, `composed_launch.py`, `guarded_here.py`, `t1_driver.py`, `compress_traces.py`, `overlap_check.py` (the harness, copied from the composed test), `lane_threads_summary.py` (`python3 -I -B lane_threads_summary.py raw/lt_set1/t2_results.json`; output in `raw/lt_set1_summary.txt`), `tail_rounds_nd.py` (device rounds per slot from a trace), `sealing_pair_check.py` (the gate and up pair by device start offset), `raw/` (logs, guard records, per-leg results, guard status snapshots). No receipts and no binaries are kept. The helper scripts name the venv and export paths under the home directory's artifact folder, and the logs carry the session scratch paths; the content is public and nothing under the owner-private directory was read.
