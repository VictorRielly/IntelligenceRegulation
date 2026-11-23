# The fast sumcheck chain (`HL_METAL_SC_CHAIN_FAST=1`) at the app profile: PASS, +3.9% and +3.4%

Run 2026-11-23 14:14 to 14:52 UTC by the Claude co-coordinator. The definition, the rule and what each verdict would do were posted in `ops/zkp-mvp/RECOVERY_COORDINATION.md` at 2026-11-23T13:29:42Z and pushed (`de23140c`) before any run. Labels: MEASURED (the raw files), DERIVED (arithmetic by `scchain_summary.py`; its output is `raw/scchain_summary.txt`). Each timed rate was measured once (one set; it passed, so the rule's repeat was not run).

**Result in one line.** With the switch on, the six-lane rate of the installed app profile is 3.94% and 3.42% above the merged head in the two pairs; the rule's line is +3% in both. The branch merges if the full check on the merged tree is green, and the switch is offered to the app.

## What was tested

Antigravity's branch `agy/sc-chain-opt` at `3f1caf249` (base `7ed1278b4`). One switch, off by default, three parts: the sumcheck round kernels add their SIMD group's partial sums inside the kernel (no separate reduce dispatch, a buffer 32 times smaller); a rewritten device transcript step (`k_sc_fs_step_v3`); the tables and the materialized tables folded in one dispatch. A block's sumcheck chain goes from 555 serial dispatches to 428. Outputs are byte-identical by the branch's golden and call-site tests.

Earlier gates: micro-bench of the chain (Antigravity, `results/zk60_k9_sc_chain_20261123/` in its checkout): 7.6 ms less per block alone, 25% less with six queues competing; 8B stream set: steady gap 2.22% shorter, 5 of 6 passes (`results/zk60_sc_chain_8b_20261123/`, recomputed from the raw log); code read `results/zk60_claude_review_20261116/SC_CHAIN_READ_20261123.md` (no High finding; M1, M2, M3 and L1 to L4 settled at `3f1caf249`).

## The two binaries (release `zk60_classify`, Metal feature, `cargo build --release --offline --locked -j 2 --features gpu-metal --example zk60_classify`, through the guard, in the tester's own worktrees)

| name | commit | SHA-256 | guard build |
|---|---|---|---|
| B0 (the branch's base in prover source; built for the bundle test the same day) | `462e3615` | `8b3fac68eb15bccfce215732ab4c259c037a6fbb7092df822ca815781a8409dc` | `45da7bd0037a` |
| B1 (`agy/sc-chain-opt`) | `3f1caf249` | `190dcd78d7d58e2beff3cd1200dd07debafd80e12a79148ee6dd34f22985fddd` | `a2694c4f6a93` |

Recorded in the coordination file (14:16:37Z) before the first timed leg. `git diff --stat 462e3615 7ed1278b4 -- ops/zkp-mvp/gpu-metal` is empty.

**Arms.** A = B0 with `HL_METAL_FUSED_RS=1 HL_METAL_SPARSE_FOLD=1`; B = B1 with the same two and the new switch unset; C = B1 with the same two plus `HL_METAL_SC_CHAIN_FAST=1`. The driver removes these variables from its own environment first. Two binaries are used because the diff edits shared code; a single binary would measure the switch, not the merge.

## Fixture

That of `results/zk60_bundle_app_20261123/` and `results/zk60_composed_app_20261122/` unchanged; `scchain_driver.py` is that driver with only the arms changed: a fresh `zk60_classify serve --lanes 6 --lane-threads 5 --witness-cache-gib 16 --dev-w16r2-public-content-only` per leg on the installed W16R2 Shieldstral export, per-thread queues, 6 + 48 = 54 requests over the eight public posts written at once; rate = 48 x 128 / (c[N+48] - c[N]) from one monotonic clock; no trace and no `HL_METAL_TIMING` in a timed leg. Every receipt of B1 was checked by `check-serve` of B0 outside the timed window.

## Smoke: the fast chain is taken (MEASURED; not a timed measurement)

Three legs of 6 + 6 requests with `HL_METAL_TIMING=1`, guard `e7f5d1bac28d`, exit 0. Counted by `smoke_paths.py` (`raw/smoke_paths.txt`) from the kind printed in each batched sumcheck's timing line (the marker added at `bcbcb55c2`):

| arm | batched sumchecks | kind | fall-back lines |
|---|---|---|---|
| A | 3818 | none printed (the binary predates the marker) | 0 |
| B | 3785 | all `std` | 0 |
| C | 3780 | all `sc-chain-fast` | 0 |

All 36 requests proved; B0's `check-serve` accepted 12 of 12 receipts of arm B and of arm C. (The counts differ a little between legs because the number of rounds a sumcheck batches is decided from a run-time cost estimate.)

## Set of record: A, B, C, C, B, A (guard `65e8b14f820c`, exit 0, peak RSS 59.0 GiB, peak VRAM 20.6 GiB)

| leg | arm | rate, tok/s | mean prove call, s | receipts | start to end, UTC |
|---|---|---|---|---|---|
| 1 | A | 46.638 | 13.384 | unverified | 14:23:15 to 14:26:16 |
| 2 | B | 46.389 | 13.435 | 54 of 54 checked | 14:26:17 to 14:29:20 |
| 3 | C | 48.477 | 12.783 | 54 of 54 checked | 14:31:50 to 14:34:48 |
| 4 | C | 47.834 | 13.021 | 54 of 54 checked | 14:37:18 to 14:40:18 |
| 5 | B | 46.242 | 13.562 | 54 of 54 checked | 14:42:48 to 14:45:52 |
| 6 | A | 46.252 | 13.518 | unverified | 14:48:22 to 14:51:25 |

All 324 requests were proved; 216 B1 receipts were checked by B0 and accepted; no failure.

**Primary, C over A (DERIVED):** pair (leg 1, leg 3) **+3.94%**; pair (leg 6, leg 4) **+3.42%**. **Verdict by the posted rule: PASS** ("PASS at +3 percent or more in both pairs").

**Secondary, no verdict (each pair measured once):** B over A (the branch binary with the switch unset): pair (1, 2) -0.53%, pair (6, 5) -0.02%. C over B (the switch): pair (2, 3) +4.50%, pair (5, 4) +3.44%.

**Other jobs.** `overlap_check.py` (`raw/overlap_check.txt`): no other guarded job overlapped any timed leg. Antigravity held the GPU and heavy builds idle. No agent and no research tick of the tester ran beside the set.

## Addendum, 15:12 to 15:34 UTC: the switch at six lanes by eight threads (guard `5671707378fb`, exit 0; no verdict on the merge, which was already made)

Defined in the coordination file at 15:11:07Z and pushed (`a7faf0dd`) before the run: four legs X, Y, Y, X with B1 only (the merge did not change the prover source), X = `frs1 sf1` at `--lanes 6 --lane-threads 8`, Y = the same plus `HL_METAL_SC_CHAIN_FAST=1`, every receipt of both arms checked by B0. Six lanes by eight threads is the best setting of the 2026-11-22 sweep (48.6 tok/s without the switch).

| leg | arm | rate, tok/s | mean prove call, s | receipts | start to end, UTC |
|---|---|---|---|---|---|
| 1 | X | 48.115 | 12.819 | 54 of 54 checked | 15:12:09 to 15:15:06 |
| 2 | Y | 48.946 | 12.515 | 54 of 54 checked | 15:17:38 to 15:20:34 |
| 3 | Y | 49.637 | 12.328 | 54 of 54 checked | 15:23:07 to 15:26:01 |
| 4 | X | 48.694 | 12.640 | 54 of 54 checked | 15:28:33 to 15:31:30 |

**Y over X (DERIVED): pair (1, 2) +1.73%, pair (4, 3) +1.94%.** By the reading fixed before the run ("holds at eight threads" if both are at least +2%, "does not hold" if either is under +1%) neither label applies: the switch gains about 1.8% at eight threads, about half of what it gains at five. The two Y rates were 48.9 and 49.6 tok/s. (CORRECTED 2026-11-23 18:08 UTC: this sentence first called them "the highest measured at this profile so far". That was wrong: the tail-round sets of 2026-11-22 at the same lane and thread counts, `results/zk60_lane_threads_20261122/raw/tr_set1` and `tr_set1b`, have legs at 49.45 to 50.82 tok/s, and their base legs were 48.02 to 49.47 where this set's were 48.1 and 48.7. Rates of different days differ by one to two percent, so legs of different sets do not rank; only the paired gains inside one set carry.) All 216 requests proved, all 216 receipts accepted by B0, no other guarded job inside a leg. Raw: `raw/sc_lt8/`.

So the two improvements overlap in part: more threads per lane and fewer GPU dispatches both shorten the same stretches of a block. Not measured: the tail-round option (`HL_METAL_BATCH_TAIL_US=250`, +1.5 to +2% at this setting on 2026-11-22) together with the switch.

## Reading (interpretation)

The second bundle of the same day shortened work inside two kernels and gave about 1% here. This change removes 127 of 555 small serial dispatches per block and shortens another 141, and gives about 3.7%. At six lanes the cost of a block's GPU work is driven by how many separate pieces the lanes interleave, not only by the time of each piece; Antigravity's bench of the chain under six competing queues (25% less) pointed the same way before this set. The set does not say how much of the gain comes from each of the three parts.

## Not measured

A second set at five threads (not needed by the rule); a traced pair; the three parts separately; lane and thread counts other than six by five and six by eight; the switch together with the tail-round option or with the earlier bundle's two switches; private content.

## Files

`scchain_driver.py`, `t1_driver.py` (helper, a copy), `scchain_launch.py` (one detached guarded job with a `.done` marker), `guarded_here.py`, `scchain_summary.py`, `overlap_check.py`, `smoke_paths.py`, `compress_traces.py` (unused here); `raw/` holds the build log of B1, the smoke (`sc_smoke`), the set (`sc_set1`), the guard records and the three script outputs. No receipts and no binaries are kept. The content is the eight public posts; nothing under the owner-private directory was read.
