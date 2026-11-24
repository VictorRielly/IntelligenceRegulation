# The classifier host-fast switch (`HL_CLASSIFY_HOST_FAST=1`) at the app profile: first commit sent back (it slowed the default path), fixed commit PASS with the default path restored; fix commit after the code read: gain confirmed, default path intact, merge check pending a test-only fix

Run 2026-11-23 20:06 to 21:22 UTC by the Claude co-coordinator. Definition, rule and readings were posted in `ops/zkp-mvp/RECOVERY_COORDINATION.md` at 2026-11-23T20:07:56Z and pushed (`6d89de250`) before any run; part 3 was defined at 21:04:50Z and pushed (`669dc59f8`) before its run. Labels: MEASURED (the raw files), DERIVED (arithmetic by `classifyhost_summary.py`, output `raw/classifyhost_summary.txt`, and from the `t2_results.json` of each part). Every rate was measured once.

**Result in one line, after the fixed commit (section "Fixed commit" below, 22:10 to 23:12 UTC).** On `a4d836c3a` the switch passes at five threads (+10.16% and +4.93%; +7.2% and +4.9% against the higher base leg), gains +5.58% and +2.66% at eight threads, and the binary with the switch unset is level with the merged head in four of four pairs. With the switch the stream ran at 53.4 to 54.7 tok/s at both thread counts. Not merged yet: the code read comes next.

**First commit, `41f12b121` (the sections up to "Next").** At six lanes by five threads the switch passes the posted rule (+5.88% and +7.10% over the merged head, 54.3 and 54.6 tok/s). The branch is **not merged and not sent to a code read**: with the switch unset, the new binary is 2 to 5% slower than the merged head in all four pairs measured (five and eight threads), and at eight threads the switch adds nothing over the unset binary. One figure does not fit the others and is unexplained (below).

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

## Fixed commit `a4d836c3a` (22:10 to 23:12 UTC)

The author's answer (coordination entry 21:57:29Z; its code reading and disassembly, not re-derived here): nothing was meant to be always on, but the unset path had been restructured in seven production files (the segment loop inside a thread scope with a dispatcher, flag tests inside loops, a value kept alive across a check, changed inlining under fat LTO); no state of the branch outlives a process. In `a4d836c3a` every unset entry point is the base function with one guard at the top and the fast code in out-of-line siblings. Definition of the re-measurement: coordination entry 22:10:25Z, pushed (`33fcb8e5b`) before any run. B1 = `a4d836c3a`, SHA-256 `afadb0e9b12b94d4c59a01dbfbbba95e5c2ff7e19d519694e1a7ab01592eab20`, guard build `4fcf2918454b`; B0 unchanged.

Smoke (guard `9694e84e52a5`, `raw/ch2_smoke`, `raw/smoke_paths_a4d836c3a.txt`): condition (a) met (arm C hit sums C1 201, C2 1945, C3 5619, C4 1705, C5 72, all fall-back sums 0; arms A and B no request line; 12 of 12 receipts of arms B and C accepted by B0).

| leg | arm | five threads, tok/s (guard `812bf8d01094`) | eight threads, tok/s (guard `918489a7db32`) |
|---|---|---|---|
| 1 | A | 49.642 | 50.583 |
| 2 | B | 50.240 | 50.343 |
| 3 | C | 54.684 | 53.407 |
| 4 | C | 53.528 | 53.479 |
| 5 | B | 51.819 | 52.112 |
| 6 | A | 51.011 | 52.096 |

Six lanes, legs in the order shown, 6 + 48 requests each; every receipt of arms B and C checked by B0 (54 of 54 in each of the eight legs); DERIVED figures in `raw/ch2_summary.txt`.

- **Five threads, the verdict: C over A +10.16% (legs 1, 3) and +4.93% (legs 6, 4): PASS.** The two A legs are 2.76% apart, under the 3% of the low-leg clause. Against the higher A leg the C legs are +7.20% and +4.93%.
- **Eight threads, no verdict: C over A +5.58% and +2.66%.** Neither label of the fixed reading applies. Against the higher A leg: +2.52% and +2.66%.
- **Default-path condition: B over A +1.21% and +1.58% at five threads, -0.47% and +0.03% at eight: "default path restored"** (all four at or above -1.5%; on the first commit they were -5.3, -2.0, -4.4, -3.0%).
- **Drift inside both sets:** the first A and B legs are 2.8 to 3.5% below the last ones, while the two C legs agree within 2.2% and 0.1%. The order is symmetric, so a steady drift cancels in the means: mean C over mean A is +7.5% at five threads and +4.1% at eight. Quoted: about +5 to +7% at five threads, +2.5 to +5% at eight, one set each.
- All 648 requests proved; all 432 receipts of the new binary accepted by B0; no other guarded job inside a leg (`raw/overlap_check.txt`, 32 timed legs of this directory); no agent ran beside the sets.

The 6.7% between parts 2 and 3 of the first commit stays unexplained. In the two sets above all three arms sit inside one set, so nothing is chained across sets.

**Next:** one code read of `42b24a522..a4d836c3a`, fixes, the merge check on the merged tree with a full suite pass with the switch forced on, merge.

## Fix commit `eae00b314` (Nov 24, 00:45 to 03:18 UTC): smoke, a void set, a failed confirmation, a default-path set

**What the commit changes [READ by me, the non-test diff `a4d836c3a..eae00b314`]:** the verifier's embedding fold and statement builder are the base functions again and the switch is prover-only (`emb_fold_fast`, `challenges_prover_fast`, `new_chunk_prover`, `prepare_fast`, each called only from the prover under the switch); the thread-local for the writer is replaced by an explicit argument, `None` when the switch is unset, so the unset run takes the base loop (`classify_run.rs:847-855`); the writer thread's failure paths have tests. These answer M1 and M2 of the code read. B1 rebuilt: SHA-256 `6a31b41d7cbfac30b5360502b9783d224400894d7be7911e834e3ae5dcef284d`, guard `a71c60b4e73e`. B0 unchanged (`b966e101...`, the pushed head's prover).

Because the fix again changes the shape of code around the switch-off path, which is what slowed the first commit, I ran timed sets on it before the merge check. Every definition and reading below was in the coordination file and pushed before its run.

| run | legs (tok/s) | reading |
|---|---|---|
| `ch3_smoke`, guard `bca418f4a7ef`, not timed | A, B, C with counters | condition met: hits C1 200, C2 1947, C3 5628, C4 1722, C5 72, zero fall-backs; arms A and B print none; receipts accepted by B0 (`raw/smoke_paths_eae00b314.txt`) |
| `ch3_set5`, guard `7a45a9c4b6c5`, exit 75 | A 50.044, B 50.541, C 53.621, C 53.364, then leg 5 lost | **void**: a GPU hang in leg 5 (below); no reading |
| `ch3_set5b`, guard `cc269f68b0f7`, exit 0 | A 51.274, B 49.051, C 53.990, C 54.358, B 51.034, A 50.361 | C over A +5.30% and +7.94% (line +1.5%): gain confirmed. B over A -4.33% and +1.34% (line -1.5%): **not confirmed** |
| `ch3_ab8`, guard `999d745371a7`, exit 0 | A 48.276, B 49.462, B 49.320, A 51.290, B 50.694, A 50.580, A 51.219, B 51.320 | mean B over mean A -0.28% (line -1.5%): **"default path intact"** |

- **The void set.** At 01:12:01Z macOS logged one command buffer of the prover as "Caused GPU Hang Error" and discarded five in-flight ones (`raw/ch3_set5/system_log_gpu_hang_011201Z.txt`). Two lane threads panicked at `src/gpu/metal.rs:5156`, the process then finished no request and did not exit, and the job held the heavy lock idle until the guard's time limit forty minutes later. Cause of the hang: not established; the branch does not touch the GPU code or, with the switch unset, the serve loop, and it is the first such error in the 22 timing result directories searched. The hang-instead-of-fail behaviour is a defect of the base prover, reported to Antigravity and to Astra (coordination entry 2026-11-24T01:57:46Z).
- **Driver changes that followed.** A stall check: a leg stops when the prover exits early or no request finishes for 300 s, after sampling the prover's stacks (five cases of the function checked without a GPU). `ZK60_CHECK_ALL=1`: arm A's receipts are checked too (smoke `ch3_ab_smoke`, guard `66bddc0d5b44`). `ZK60_MIN_FREE_GB`: the disk margin for one run (75 GB instead of 80 for `ch3_set5b`, `ch3_ab_smoke` and `ch3_ab8`; the shortfall was not in this test's files).
- **The failed confirmation stays failed.** `ch3_set5b` was read as written. Its two B legs, same binary and environment, are 4.0% apart, so one pair at -4.3% showed neither a slowdown nor its absence.
- **The default-path set** asks only whether B1 with the switch unset is slower than B0: eight legs in the order A, B, B, A, B, A, A, B (cancels a linear or quadratic drift), every leg followed by the same receipt check, read on the mean of four legs an arm, no repeat. All 432 requests proved and all 432 receipts checked.
- **What the eight legs show about the fixture.** The first three legs are the three lowest whatever their arm (48.3, 49.5, 49.3) and every later leg is between 50.6 and 51.3: the first quarter hour of a set runs 3 to 5% low. The order A, B, C, C, B, A does not cancel that for B. Future definitions begin with one discarded lead-in leg.
- No other guarded job ran inside any leg (`overlap_check.py`: 55 timed legs of this directory, 0 overlaps); no agent ran beside the sets.

**State of the gate:** PASS of `a4d836c3a`; gain confirmed and default path intact for `eae00b314`; merge check: first run `gate1` not green: one of the branch's new tests compares process-wide counters while other tests of the suite run, and failed in the no-switch suite pass; it passes alone, the prover is not at fault, and a test-only fix is requested (`results/zk60_classifyhost_merge_20261124`, coordination entry 2026-11-24T03:49:26Z). Not merged yet.

## Files

`classifyhost_driver.py`, `t1_driver.py`, `classifyhost_launch.py`, `guarded_here.py`, `classifyhost_summary.py`, `overlap_check.py`, `smoke_paths.py`, `compress_traces.py` (unused); `raw/` holds the build log, the smoke (`ch_smoke`), part 1 (`ch_set1`), part 2 (`ch_lt8`), part 3 (`ch_lt8_ab`), the fixed commit (`ch2_smoke`, `ch2_set5`, `ch2_set8`), the fix commit after the read (`ch3_smoke`, `ch3_set5` void, `ch3_set5b`, `ch3_ab_smoke`, `ch3_ab8`), guard records and script outputs. No receipts and no binaries are kept. The content is the eight public posts; nothing under the owner-private directory was read.
