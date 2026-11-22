# The composed bundle (fused RS + sparse fold + two always-on host changes) at the app profile: a full-lanes T2 test with two binaries and three arms

Run 2026-11-22 03:03 to 03:55 UTC by the A36 agent, from the coordination entry of 2026-11-22T03:01:33Z (the rule is that entry's; nothing changed). Labels: MEASURED (the raw files), DERIVED (arithmetic by `composed_summary.py`; its output is `raw/composed_summary.txt`). Each timed rate was measured once (one set; the set passed, so the pre-registered repeat was not run). Not committed or pushed, as asked.

**Where this lives.** The sandbox refused writes to the main checkout's `results/`, so this directory is in the agent's own worktree: `.claude/worktrees/agent-a3be4019d2dca3765/results/zk60_composed_app_20261122/` (the same relative path). The two worktrees are under the session scratch directory (the sandbox also refused a sibling path).

## The two binaries (release `zk60_classify`, Metal feature, `cargo build --release --offline --locked -j 2 --features gpu-metal --example zk60_classify`, through the guard, class build; no source edit; Antigravity's build and `.agy-worktrees/` not used)

| name | commit | SHA-256 | guard build |
|---|---|---|---|
| B0 (the base, pushed head) | `651abb96` | `2f2489d3476f3acf204c3933ff6e2bb8d03a437035bf882a62d8748377626c82` | `c0a49ab6b636` |
| B1 (`agy/composed-frs-sf`) | `5afee227` | `3c86ada013dcddbdbd9855bc98cf4b6c43eae4896109e889cf3e50d50606c6ba` | `e008a172e011` |

Recorded here before the first timed leg. **Arms:** A = B0, `HL_METAL_FUSED_RS` and `HL_METAL_SPARSE_FOLD` unset; B = B1, both unset; C = B1 with both set to 1. The driver removes both variables from its own environment before building each arm's, so unset means unset.

## Fixture (T2 as before)

Fresh `zk60_classify serve --lanes 6 --lane-threads 5 --witness-cache-gib 16 --dev-w16r2-public-content-only` per leg on the installed W16R2 Shieldstral export and tables (the same directory as the verifier export, as in the earlier tests), the three shieldstral policies, `HL_METAL_QUEUES=thread HL_METAL_SPIN_US=200 HL_A28_STAGGER_MS=300 HL_A26_KEPT=1 HL_A30_B3PAR=1 HL_A26_VERIFY_ONCE=0 HL_A28_SEAL_AHEAD=0`, no trace and no `HL_METAL_TIMING` in any timed leg; N + 48 = 54 requests over the eight public posts (category sexual, chunk 0), all written to the server's stdin at once; rate = 48 x 128 / (c[N+48] - c[N]) from one monotonic clock. **Every receipt made by B1 (arms B and C) was checked by `check-serve` of B0** (3 lanes x 4 threads, `--min-bits 95`), outside the timed window, and deleted after; arm A's receipts were deleted unverified. The guard's status was read and saved before every leg (`raw/cm_set1/guard_status_leg*`). `composed_driver.py` is the fused-RS driver copy with `--bin0/--bin1` and an arm per leg (`A:6:5:48,...`); `t1_driver.py` is its helper (a copy; it holds the fixture's paths); `composed_launch.py` starts one detached guarded job with a `.done` marker; `guarded_here.py` is the guard wrapper.

## Smoke: which paths are taken at this profile (MEASURED; not timed measurements)

- **Sparse fold: taken.** Arm C with `HL_METAL_TIMING=1` (this smoke only, 12 requests = 312 blocks, guard `46392bf3faa3`, `raw/cm_smoke_timing/leg1_armC.prover.log.err`): **1008 lines "store fold with pads (sparse-gpu)"**, **0 lines "store fold (sparse-gpu)"**, **0 lines of the old non-sparse "store fold"**, so no fold fell back to the old path. Shapes per block: 37 rho x 2504 rows x (16384 + 280) cols (312 times), 10 rho x 2606 rows (312), 3 rho x 38 rows (324), and a few small ones at (4096 + 256) columns (6 rho x 38, 5 rho x 76, 4 rho x 41; 12 each); the largest rho count is 37, under the limit of 64. The GPU trace of the arm C smoke agrees: tag `spfold` 504 buffers over 156 blocks (3.23 per block) in arm C, 0 in arm B (`raw/cm_smoke`, guard `25d748097ce9`).
- **Fused encoder: taken (by its effect).** The code has no trace marker or live counter for it; in the same two smoke legs the two large commitments' execution time per block is 18.70 and 17.65 ms in arm C against 27.79 and 21.77 ms in arm B (same buffer count, 3.23 commit buffers per block): the fused path's effect is there, not a direct count.
- The driver ran with the three-arm parameters, B0's `check-serve` accepted all 12 receipts of each smoke leg.

## Set of record: A, B, C, C, B, A (guard `fe477fa74a83`, exit 0, queued 45.9 s before it began, peak RSS 59.0 GiB, peak VRAM 21.8 GiB)

| leg | arm | rate, tok/s | mean prove call, s | receipts | start to end, UTC |
|---|---|---|---|---|---|
| 1 | A | 42.532 | 14.836 | unverified | 03:16:35 to 03:19:47 |
| 2 | B | 44.307 | 14.272 | 54 of 54 checked | 03:19:48 to 03:22:56 |
| 3 | C | 46.117 | 13.561 | 54 of 54 checked | 03:25:25 to 03:28:29 |
| 4 | C | 47.115 | 13.392 | 54 of 54 checked | 03:30:59 to 03:33:59 |
| 5 | B | 45.614 | 13.913 | 54 of 54 checked | 03:36:26 to 03:39:32 |
| 6 | A | 43.411 | 14.602 | unverified | 03:42:01 to 03:45:15 |

All 324 requests were proved; 216 B1 receipts were checked by B0 and accepted; no failure.

**Primary, C over A (DERIVED):** pair (leg 1, leg 3) **+8.43%**; pair (leg 6, leg 4) **+8.53%**. **Verdict by the posted rule: PASS** (both at least +3%). No second set was run (the rule repeats only when the first set is not decided).

**Secondary, no verdict (each pair measured once):** B over A (the always-on part alone): pair (1, 2) +4.17%, pair (6, 5) +5.08%. C over B (the two switches on top): pair (2, 3) +4.08%, pair (5, 4) +3.29%. The two off-A rates (42.53 and 43.41) differ by 2.1%, which is the size of the pair noise.

**Other jobs.** `overlap_check.py` compares each timed leg's start and end with every record of `results/zk60_resource_guard/history.jsonl`: **no other guarded job overlapped any timed leg** (the traced pair's legs included). Antigravity's `agy-open-fast-pins` did not overlap a timed leg. The guard serialised our jobs with others' at launch: waits were 0.1 s for the smoke and the traced pair, 25.5 s for the HL_METAL_TIMING smoke and 45.9 s for the set (the guard still listed my own preceding timing-smoke job as live at launch; no other job was named), none inside a leg.

## Traced pair, A then C (guard `b43ccf587ded`, exit 0; `HL_A27_GPU_TRACE`; no verdict; per block, by begin time between completion N and N + 48, B = 26 x 48)

| arm | rate, tok/s | wall | prover e | q | w | host time (wall - e - q - w, DERIVED) | empty-device share (1 - union over all buffers) | commit e, rows 2504 / 2606 | spfold buffers |
|---|---|---|---|---|---|---|---|---|---|
| A (B0) | 43.446 | 552.6 ms | 201.5 | 52.8 | 2.6 | 295.7 | 22.7 % | 24.15 / 21.88 | 0 |
| C (B1, both on) | 45.221 | 534.9 ms | 222.0 | 67.6 | 2.9 | 242.5 | 19.0 % | 18.53 / 18.59 | 4032 (3.23 per block, e 9.54 ms/block) |

(ms per block unless stated; the spfold buffers' execution time is included in arm C's prover e.) Rate +4.08% for this single traced pair (not part of the rule).

## Not measured

A second set (not needed by the rule); other lane counts or queue modes; the GPU busy share by Astra's capture; private content; the sparse-fold-only arm and the fused-only arm of B1 (the bundle's parts separately).

## Files

`composed_driver.py`, `composed_launch.py`, `composed_summary.py` (`python3 -I -B composed_summary.py raw`; reads the `.xz` traces), `overlap_check.py`, `compress_traces.py`, `guarded_here.py`, `t1_driver.py`; `raw/`: logs, guard receipts, per-leg `t2_results.json` (arms named A/B/C explicitly) in `raw/cm_smoke`, `cm_smoke_timing`, `cm_set1`, `cm_trace`, the guard status snapshots, `raw/composed_summary.txt`, `raw/overlap_check.txt`, and the xz traces:

| file | uncompressed bytes | compressed bytes | SHA-256 of the `.xz` |
|---|---|---|---|
| `cm_smoke_leg1.76262.tsv.xz` (arm C) | 1,857,510 | 162,900 | `83dd7543065f04a9156a16671341fffabcde13da354e52c017a872db915cb645` |
| `cm_smoke_leg2.77253.tsv.xz` (arm B) | 1,703,470 | 145,220 | `bb6a3af06b4e95d5d2b97a17524b6ff03c76e77f854f84a8b9781b1052edb841` |
| `cm_trace_leg1.94096.tsv.xz` (arm A) | 7,663,112 | 650,148 | `5dcfe2d54ce5e74fa89c066b3d1b750d682cbe1ca88fbc44c0de6363e766733d` |
| `cm_trace_leg2.95710.tsv.xz` (arm C) | 8,340,132 | 726,872 | `df2c10b5efcd7e8ecaadd3c2a24dfcafc23d729daee249bde6f0cff9d033fd13` |

No receipts and no binaries are kept. For the scan: the helper scripts name the venv and export paths under the home directory's artifact folder (`t1_driver.py`, `composed_launch.py`), and the run logs and results JSON carry the session scratch paths; nothing private (the content is public; nothing under the owner-private directory was read).
