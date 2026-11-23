# The second bundle (fast opening + register-only sparse fold kernel) at the app profile: NO TRANSFER

Run 2026-11-23 11:13 to 11:48 UTC by the Claude co-coordinator. The definition, the rule and what each verdict would do were posted in `ops/zkp-mvp/RECOVERY_COORDINATION.md` at 2026-11-23T11:08:14Z and pushed (`d1a5f5d8`) before any run. Labels: MEASURED (the raw files), DERIVED (arithmetic by `bundle_summary.py`; its output is `raw/bundle_summary.txt`). Each timed rate was measured once.

**Result in one line.** With both new switches on, the bundle is faster than the base in both pairs, by +0.93% and +1.47%. The rule calls anything under +1.5% in either pair NO TRANSFER, with no repeat. The bundle is not merged, and the two switches are not offered for the installed app.

## What was tested

Antigravity's branch `agy/bundle-of1-r81` at `9a188a38` (base `462e3615`). It carries two changes, both off by default and both byte-identical to the paths they replace by their parity tests:

- `HL_METAL_OPEN_FAST=1`: the hiding opening skips two tables it never reads and gathers the opened columns on the host. On the 8B stream it shortened the steady gap by 2.32% (6 of 6 passes; `results/zk60_open_fast_20261122/`). Code review: `results/zk60_claude_review_20261116/OPEN_FAST_READ_20261123.md`.
- `HL_METAL_SPARSE_FOLD_REG8=1`: a rewritten sparse fold kernel that keeps its sums in registers instead of shared thread-group memory. On the 8B stream it shortened the steady gap by 1.79% (6 of 6 passes; `results/zk60_spfold_reg8_20261123/` on the branch). Code review: `results/zk60_claude_review_20261116/SPFOLD_REG8_READ_20261123.md`.

## The two binaries (release `zk60_classify`, Metal feature, `cargo build --release --offline --locked -j 2 --features gpu-metal --example zk60_classify`, through the guard, in the tester's own worktrees)

| name | commit | SHA-256 | guard build |
|---|---|---|---|
| B0 (the bundle's base; same prover source as the pushed head) | `462e3615` | `8b3fac68eb15bccfce215732ab4c259c037a6fbb7092df822ca815781a8409dc` | `45da7bd0037a` |
| B1 (`agy/bundle-of1-r81`) | `9a188a38` | `84fcda793a4366512f7a13ff663e6bd0d2575917040a1a5f191295b50f81f073` | `acc90e49aa88` |

Recorded in the coordination file (11:13:22Z) before the first timed leg. A first B1 build at `db67f862` failed to compile (a duplicate function from a cherry-pick, removed at `9a188a38`); it was never run.

**Arms.** A = B0 with `HL_METAL_FUSED_RS=1 HL_METAL_SPARSE_FOLD=1` (the configuration measured on 2026-11-22 and offered to the app); B = B1 with the same two and the new switches unset; C = B1 with the same two plus `HL_METAL_OPEN_FAST=1 HL_METAL_SPARSE_FOLD_REG8=1`. The driver removes all of these variables from its own environment first.

## Fixture

That of `results/zk60_composed_app_20261122/` unchanged; `bundle_driver.py` is that driver with only the arms changed. A fresh `zk60_classify serve --lanes 6 --lane-threads 5 --witness-cache-gib 16 --dev-w16r2-public-content-only` per leg on the installed W16R2 Shieldstral export and tables, the three shieldstral policies, 6 + 48 = 54 requests over the eight public posts (category sexual, chunk 0), all written to the server at once; rate = 48 x 128 / (c[N+48] - c[N]) from one monotonic clock; no trace and no `HL_METAL_TIMING` in a timed leg. Every receipt made by B1 (arms B and C) was checked by `check-serve` of B0 outside the timed window and deleted after; arm A's receipts were deleted unverified. The guard's status was saved before every leg.

## Smoke: both new paths are taken at this profile (MEASURED; not a timed measurement)

Three legs of 6 + 6 requests with `HL_METAL_TIMING=1`, guard `00fd717aa599`, exit 0. Counted by `smoke_paths.py` (`raw/smoke_paths.txt`):

| arm | fold lines | gather lines |
|---|---|---|
| A | 1008 `store fold with pads (sparse-gpu)` | 1008 `store columns` (device) |
| B | 1008 `store fold with pads (sparse-gpu)` | 1008 `store columns` (device) |
| C | 1008 `store fold with pads (sparse-gpu-reg8)` | 1008 `store columns (host tiled)` |

No fold of an older kind and no device gather in arm C. All 36 requests proved; B0's `check-serve` accepted 12 of 12 receipts of arm B and of arm C.

## Set of record: A, B, C, C, B, A (guard `c4ad7cec1e98`, exit 0, 1710 s, peak RSS 66.6 GiB, peak VRAM 21.0 GiB)

| leg | arm | rate, tok/s | mean prove call, s | receipts | start to end, UTC |
|---|---|---|---|---|---|
| 1 | A | 46.942 | 13.265 | unverified | 11:19:44 to 11:22:44 |
| 2 | B | 46.836 | 13.420 | 54 of 54 checked | 11:22:45 to 11:25:46 |
| 3 | C | 47.376 | 13.192 | 54 of 54 checked | 11:28:17 to 11:31:17 |
| 4 | C | 47.778 | 13.096 | 54 of 54 checked | 11:33:47 to 11:36:47 |
| 5 | B | 46.996 | 13.268 | 54 of 54 checked | 11:39:18 to 11:42:19 |
| 6 | A | 47.087 | 13.323 | unverified | 11:44:49 to 11:47:51 |

All 324 requests were proved; 216 B1 receipts were checked by B0 and accepted; no failure.

**Primary, C over A (DERIVED):** pair (leg 1, leg 3) **+0.93%**; pair (leg 6, leg 4) **+1.47%**. **Verdict by the posted rule: NO TRANSFER** ("NO TRANSFER under +1.5 percent in either pair"). The rule repeats a set only when it falls between its two lines, so there is no second set. The two sets are not pooled with anything and +1.47% is not read as 1.5%.

**Secondary, no verdict (each pair measured once):** B over A (the bundle binary with its switches unset): pair (1, 2) -0.23%, pair (6, 5) -0.19%. C over B (the two switches): pair (2, 3) +1.15%, pair (5, 4) +1.66%. The two arm A rates differ by 0.3%.

**Other jobs.** `overlap_check.py` (`raw/overlap_check.txt`): no other guarded job overlapped any timed leg. Antigravity held the GPU and heavy builds idle for the set. No agent and no research tick of the tester ran beside it.

## Traced pair, A then C (guard `4ba609f916f3`, exit 0, 11:52 to 12:01 UTC; `HL_A27_GPU_TRACE`; no verdict; per block, by begin time between completion N and N + 48, B = 26 x 48)

Stated in the coordination file (11:51:56Z) before it ran, with how it would be read. The trace costs time, so these rates are not read against the rule.

| arm | rate, tok/s | wall | prover e | q | w | host time (wall - e - q - w, DERIVED) | empty-device share | commit e, rows 2504 / 2606 | spfold buffers | trace records |
|---|---|---|---|---|---|---|---|---|---|---|
| A (B0, `frs1 sf1`) | 46.407 | 521.5 ms | 218.5 | 58.7 | 2.7 | 241.6 | 18.0 % | 17.00 / 17.38 | 4032 (3.23 per block, e 9.33 ms/block) | 41,938 |
| C (B1, plus `of1` and `reg8`) | 47.261 | 506.3 ms | 210.1 | 56.1 | 2.3 | 237.7 | 19.8 % | 16.15 / 17.68 | 4032 (3.23 per block, e 5.30 ms/block) | 37,440 |

(ms per block unless stated.) From A to C: wall -15.2 ms (-2.9%), device execution -8.4 ms (of which the sparse fold -4.0 ms; 4,498 fewer buffers in the window, about 3.6 per block, the gathers now done on the host), wait before start -2.6 ms, host time -3.9 ms. Rate +1.84% for this single traced pair. All 54 receipts of arm C were accepted by B0. `overlap_check.py`: no other guarded job inside either leg.

**Read by the lines fixed before it ran:** X, the fall of `e`, is 8.4 ms. "The saved device work turned into waiting" needed `q` to rise by at least 4.2 ms; `q` fell by 2.6 ms. **That explanation is not supported.** The second fixed line (`q` within 1 ms while wall falls by about X) does not describe the pair either, so no label is given; the numbers are above.

## Reading (interpretation; the first version of this section was wrong and is corrected here)

The first version of this section, written before the traced pair, said the saved work mostly turned into waiting for the GPU. The traced pair contradicts that: the wait fell too. What the pair shows instead is plain arithmetic. At six lanes one block costs a lane about 520 ms: about 218 ms of its GPU work running, 59 ms waiting for the GPU and 242 ms on the host. The bundle takes about 15 ms out of that (2.9% of the prove call), and the prove call is about four fifths of what sets the rate, so the rate moves by one to two percent. The bundle does what it was built to do; the opening path it speeds up is a small part of a block at this profile (the sparse fold was 9.3 ms of 218). The new kernel's own time fell from 9.33 to 5.30 ms per block here, less than the factor of four of the single-kernel test, because six lanes share the GPU.

Two things in the table are larger than anything the bundle touches: the host time (about 240 ms per block, 46% of the wall) and the slowdown of device work under six lanes (218 ms of execution per block against about 98 ms measured for one lane in research tick 40).

## What follows (fixed before the run)

Not merged. `agy/bundle-of1-r81` stays as a branch. Its parts are not re-tested one by one at the app profile. The two 8B results stand on their own records. Whether code that wins at 8B, with clean reviews and off by default, may merge for 8B use without passing here is a change of the rule and has been put to Victor; if it merges later, findings M1, L1 and L2 of the kernel review come first, and the two switches together have not yet been measured at 8B.

## Files

`bundle_driver.py`, `t1_driver.py` (helper, a copy), `bundle_launch.py` (one detached guarded job with a `.done` marker), `guarded_here.py` (guard wrapper), `bundle_summary.py`, `overlap_check.py`, `smoke_paths.py`, `compress_traces.py`; `raw/` holds the build logs, the smoke (`bn_smoke`), the set (`bn_set1`), the traced pair (`bn_trace`), the guard records, the three script outputs and the xz traces:

| file | uncompressed bytes | compressed bytes | SHA-256 of the `.xz` |
|---|---|---|---|
| `bn_trace_leg1.12896.tsv.xz` (arm A) | 8,358,309 | 727,584 | `bb077b4c77af94d809bb23945eecea15a870de3d91ef7900745592a7e474e916` |
| `bn_trace_leg2.14338.tsv.xz` (arm C) | 7,923,915 | 658,416 | `2e312b4cb11ab196d16c830a61ae06dd1ad4757290a56bba82430ed811620861` |

No receipts and no binaries are kept. The content is the eight public posts; nothing under the owner-private directory was read.
