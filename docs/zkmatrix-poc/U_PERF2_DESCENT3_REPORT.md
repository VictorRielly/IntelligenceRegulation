# U-PERF2 lane G — descents, round 2: fold/extract fusion, the table arena, thread scaling

Branch `uperf2-g` (worktree /home/victor/wt-uperf2-g), opened at f512ba1
on 2026-08-17. Ledger: PROGRESS_UPERF2.md "Lane G" + "Agent G status".
Box: the WSL box (Intel Core Ultra 9 185H, 22 threads, 15 GB; the local
m125 re-export is here, so the 3x16 and 12x64 real-data rigs run). Every
number carries a label `[WSL-BOX 1T|NT, QUIET|NOISY-SHARED]` (NOISY-SHARED
= lane F was building or running at the same time).

## 0. One paragraph

(to be written at close)

## 1. Baseline (untouched build at f512ba1)

`uperf-a descent-bench 20 8 5 9` (5 real depth-20 witness trees + 3 pads +
the dt-9 table side; DESCENT DIGEST 47a58a27..dafefb) [WSL-BOX, load 0.7,
lane F building]:

| | 1T | 8T |
|---|---:|---:|
| trees | 1.63 s | 0.39 s |
| masked_gkr_prove | 8.12 s | 2.24 s |
| a.round-g | 3.66 | 0.93 |
| a.fold | 2.54 | 0.89 |
| a.extract | 1.22 | 0.21 |
| a.eq-table | 0.67 | 0.19 |
| a.tree-step | 1.34 | 0.29 |
| peak RSS | 2,086 MiB | 2,087 MiB |

Freeze-check baseline: 98 `ok` rows (scratchpad g_freeze_baseline.txt),
identical to lane F's capture of the same build.

## 2. Item 1 — fold-into-next-round fusion + extract fusion into round 0

(plan) The packed descent kernel folds round t's five work tables INSIDE
round t+1's kernel pass (one read of the state-t tables, one write of
the state-(t+1) tables, in place with a rung-ordered schedule) and reads
the tree layer directly at rounds 0 and 1 (no materialized state-0
tables; PL = p0 + lambda q0 formed on the fly). Same arithmetic, same
canonical values, transcript-identical; `masked_rounds_bulk_ref` stays
the oracle under `oracle_mode()`; `ZK_UPERF_G_NOFUSE=1` runs the same
loop with every fold applied eagerly (lane A's HEAD path) for the A/B.

## 3. Item 2 — the per-pair table arena

(plan)

## 4. Item 3 — thread scaling

(plan)

## 5. Differential evidence + gates

(to be filled)

## 6. Projection to the rig (depth 22 x 16) + what is left

(to be filled)
