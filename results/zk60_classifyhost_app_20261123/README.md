# The classifier host-fast switch (`HL_CLASSIFY_HOST_FAST=1`) at the app profile: PASS at five threads, not merged; the binary with the switch unset is slower than the base

Run 2026-11-23 20:06 to 21:22 UTC by the Claude co-coordinator. Definition, rule and readings were posted in `ops/zkp-mvp/RECOVERY_COORDINATION.md` at 2026-11-23T20:07:56Z and pushed (`6d89de250`) before any run; part 3 was defined at 21:04:50Z and pushed (`669dc59f8`) before its run. Labels: MEASURED (the raw files), DERIVED (arithmetic by `classifyhost_summary.py`, output `raw/classifyhost_summary.txt`, and from the `t2_results.json` of each part). Every rate was measured once.

**Result in one line.** At six lanes by five threads the switch passes the posted rule (+5.88% and +7.10% over the merged head, 54.3 and 54.6 tok/s). The branch is **not merged and not sent to a code read**: with the switch unset, the new binary is 2 to 5% slower than the merged head in all four pairs measured (five and eight threads), and at eight threads the switch adds nothing over the unset binary. One figure does not fit the others and is unexplained (below).

## What was tested

Antigravity's branch `agy/classify-host-opt` at `41f12b121` (base `42b24a522`; 1,325 added lines in ten files of the classifier's host path): cached table digests (C1), a writer thread for segments (C2), verified boundary values kept in memory (C3), a duplicate scan skipped (C4), a NEON embedding fold (C5). The 8B stream does not exercise this code, so this set is its first measurement.

| name | commit | SHA-256 | guard build |
|---|---|---|---|
| B0 (the pushed head's prover; `git diff --stat dab3fe762 2473180f5 -- ops/zkp-mvp/gpu-metal` is empty) | `dab3fe762` | `b966e101f3df54e0a1919d86c4e3f35d55895a2d9dcf1027dd588da8d268fe3f` | (built for the host-fast test) |
| B1 (`agy/classify-host-opt`) | `41f12b121` | `2a5cc8eca292cdb946687bcdb426d85a0133c0a9ff81c546b89eccf78d741bd4` | `e0a1db46fd0e` |

**Arms.** A = B0 with `HL_METAL_FUSED_RS=1 HL_METAL_SPARSE_FOLD=1 HL_METAL_SC_CHAIN_FAST=1 HL_HOST_FAST=1`; B = B1 with the same four and the new switch unset; C = B1 with the same four plus `HL_CLASSIFY_HOST_FAST=1`. Fixture: that of `results/zk60_hostfast_app_20261123/` (fresh `zk60_classify serve` per leg on the installed W16R2 Shieldstral export, per-thread queues, 6 + 48 requests over the eight public posts, rate = 48 x 128 / (c[N+48] - c[N]), no trace and no `HL_METAL_TIMING` in a timed leg, every receipt of B1 checked by `check-serve` of B0).

## Smoke (MEASURED; not a timed measurement), guard `e04863fe34d1`

Three legs A, B, C of 6 + 6 requests at six by five with `HL_METAL_TIMING=1`, read by `smoke_paths.py` (`raw/smoke_paths.txt`): arm C printed 12 `[ZK60-CLASSIFY-HOST-FAST]` request lines, hit sums C1 201, C2 1955, C3 5640, C4 1736, C5 72, every fall-back sum 0; arms A and B none; every arm 312 `[ZK60-HOST-FAST]` block lines with zero fall-backs and only `sc-chain-fast` batches. 36 requests proved; 12 of 12 receipts of arms B and C accepted by B0. Condition (a): met.

## Part 1, the verdict: six lanes by five threads, legs A, B, C, C, B, A (guard `68a6158ff1e5`, exit 0)

| leg | arm | rate, tok/s | receipts | start to end, UTC |
|---|---|---|---|---|
| 1 | A | 51.307 | unverified | 20:14:57 to 20:17:46 |
| 2 | B | 48.569 | 54 of 54 checked | 20:17:47 to 20:20:43 |
| 3 | C | 54.326 | 54 of 54 checked | 20:23:16 to 20:25:58 |
| 4 | C | 54.595 | 54 of 54 checked | 20:28:30 to 20:31:12 |
| 5 | B | 49.976 | 54 of 54 checked | 20:33:44 to 20:36:37 |
| 6 | A | 50.975 | unverified | 20:39:10 to 20:42:01 |

**Primary, C over A (DERIVED): +5.88% and +7.10%. Verdict by the posted rule: PASS.** The two A legs differ by 0.65%, so the low-leg clause of the definition does not apply. **Secondary: B over A -5.34% and -1.96%; C over B +11.85% and +9.24%.**

## Part 2: six lanes by eight threads, B1 only, legs X, Y, Y, X (guard `b7ae23006840`, exit 0)

X = arm B, Y = arm C: 53.147, 53.678, 52.722, 52.809 tok/s. **Y over X: +1.00% and -0.16%: "does not hold at eight threads"** by the reading fixed before the run. 216 of 216 receipts accepted by B0.

## Part 3 (added, exploratory): six lanes by eight threads, legs A, B, B, A (guard `aa95a4c8c10d`, exit 0)

A 51.907 and 51.028 tok/s; B 49.636 and 49.492 tok/s. **B over A: -4.37% and -3.01%: "slower at eight threads"** by the reading fixed before the run. 108 of 108 receipts of B1 accepted by B0.

`overlap_check.py` (`raw/overlap_check.txt`): no other guarded job inside any of the sixteen timed legs. No agent ran beside any part.

## What is established, and what is not

- **Established:** the switched-on binary beats the merged head at five threads (two pairs, both arms steady within 0.7%). The binary with the switch unset is below the merged head in four of four pairs (-5.3, -2.0, -4.4, -3.0%), so the branch changes the default path, which an off-by-default switch must not.
- **Does not fit, unexplained:** arm B at eight threads ran at 53.1 and 52.8 tok/s in part 2 and at 49.6 and 49.5 in part 3, same binary and settings, twenty minutes apart. That is 6.7% between sets, where two legs of one arm inside one set differ by 0.3 to 3% in today's sets (once 5.5%). In part 2 the unset legs ran exactly as fast as the switched-on legs. Whether some state survives a server process and changes a later unset process has been asked of the author.
- **Not established:** C against A at eight threads (never in one set; parts 2 and 3 do not chain because of the item above).

## Next

The author is asked for (1) what executes differently with the switch unset, (2) whether any state outlives a process, (3) a commit whose unset path is the base path. That commit is measured with all three arms at both thread counts; B over A must be within about 1% before a read is spent.

## Files

`classifyhost_driver.py`, `t1_driver.py`, `classifyhost_launch.py`, `guarded_here.py`, `classifyhost_summary.py`, `overlap_check.py`, `smoke_paths.py`, `compress_traces.py` (unused); `raw/` holds the build log, the smoke (`ch_smoke`), part 1 (`ch_set1`), part 2 (`ch_lt8`), part 3 (`ch_lt8_ab`), guard records and script outputs. No receipts and no binaries are kept. The content is the eight public posts; nothing under the owner-private directory was read.
