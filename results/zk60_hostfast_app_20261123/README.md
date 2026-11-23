# The host-fast switch (`HL_HOST_FAST=1`) at the app profile: PASS, +5 to +8 percent

Run 2026-11-23 16:36 to 18:07 UTC by the Claude co-coordinator. The definition, the rule and what each verdict would do were posted in `ops/zkp-mvp/RECOVERY_COORDINATION.md` at 2026-11-23T16:37:35Z and pushed (`bf789a4dc`) before any run; the binaries were recorded there at 17:37:52Z and pushed (`953c570ab`) before the first timed leg. Labels: MEASURED (the raw files), DERIVED (arithmetic by `hostfast_summary.py`; its output is `raw/hostfast_summary.txt`). Each timed rate was measured once (one set; it passed, so the rule's repeat was not run).

**Result in one line.** With the switch on, the six-lane rate of the installed app profile was 50.8 and 49.2 tok/s against 46.9 tok/s for the merged head: PASS by the posted rule. One base leg ran low without a known cause, so the gain is quoted as +5 to +8 percent, not from the rule's two pair figures. The branch is not merged yet: the code reads come after this set (the order was announced with the definition), then the merge check.

## What was tested

Antigravity's branch `agy/host-g5g4g6` at `6b68cb931` (base `a7faf0ddb`, the merged head). One switch, off by default, six host-side parts: inverse tables for two lookup helpers (H1), the mask commitment's rows computed in parallel (H2), a parallel chunked batch inversion (H3), a single-pass NEON weight fold (H4), a tiled table fill with a per-block cache of two folds (H5), public tables generated on the device and three claimed sums computed directly (H6). Outputs are byte-identical by the branch's golden and call-site tests. About 3,700 changed lines in eleven files.

Earlier gate: 8B stream set by Antigravity (its guard `8bf1279718c3`, on `67facf460`), recomputed by me from its raw log with `results/zk60_composed_8b_20261123/summary_8b.py`: steady gap 3.256 to 3.176 s, paired median 3.04 percent shorter, 6 of 6 passes.

**Order of this gate.** The timed set ran before the code reads, the reverse of the sumcheck-chain gate the same day: the change needs two readers, and a host-side change had already failed to carry from one lane to six once (A36, 2026-11-21). Every receipt of the new binary is checked by the base binary, so an unread binary cannot pass on a wrong proof. If a review fix changes code on the measured path, the set is repeated on the fixed commit before any merge.

## The two binaries (release `zk60_classify`, Metal feature, `cargo build --release --offline --locked -j 2 --features gpu-metal --example zk60_classify`, through the guard, in the tester's own worktrees)

| name | commit | SHA-256 | guard build |
|---|---|---|---|
| B0 (the merged head's prover source; built for the sumcheck-chain test the same day) | `3f1caf249` | `190dcd78d7d58e2beff3cd1200dd07debafd80e12a79148ee6dd34f22985fddd` | `a2694c4f6a93` |
| B1 (`agy/host-g5g4g6`) | `6b68cb931` | `9a087c8061137cc5158ec5b3969e0e6a843c6abb61961eb8b548143335e618d4` | `51c4c08dfd3f` |

`git diff --stat 3f1caf249 721c2bb7c -- ops/zkp-mvp/gpu-metal` is empty, so B0 is the pushed head's prover.

**Arms.** A = B0 with `HL_METAL_FUSED_RS=1 HL_METAL_SPARSE_FOLD=1 HL_METAL_SC_CHAIN_FAST=1`; B = B1 with the same three and `HL_HOST_FAST` unset; C = B1 with the same three plus `HL_HOST_FAST=1`. The driver removes these variables from its own environment first. Two binaries are used because the diff edits shared code.

## Fixture

That of `results/zk60_scchain_app_20261123/` unchanged; `hostfast_driver.py` is that driver with only the arms changed: a fresh `zk60_classify serve --lanes 6 --lane-threads 5 --witness-cache-gib 16 --dev-w16r2-public-content-only` per leg on the installed W16R2 Shieldstral export, per-thread queues, 6 + 48 = 54 requests over the eight public posts written at once; rate = 48 x 128 / (c[N+48] - c[N]) from one monotonic clock; no trace and no `HL_METAL_TIMING` in a timed leg. Every receipt of B1 was checked by `check-serve` of B0 outside the timed window.

## Smokes: the new paths are taken (MEASURED; not timed measurements)

Three legs A, B, C of 6 + 6 requests with `HL_METAL_TIMING=1`, read by `smoke_paths.py`.

1. On the branch's first commit `67facf460` (guard `778170a3749b`, exit 0; B1 then SHA-256 `1ef300e8b686070631cc6711564285e35c68995b0befd5b7aae0ed23980d917e`, guard build `a0b686a3be30`): arm C printed the one-line marker, arms A and B did not. Antigravity then added a per-block counts line and removed an environment lookup from the hit counter, which sat on the measured path of arm C; the set of record therefore uses the later commit. Files `raw/hf_smoke_67facf460*`.
2. A relaunch on `6b68cb931` stopped after 6 s at the request writer (guard `0fbfa06c4ce4`, exit 1) because the scratch directory of the same label still existed; nothing was proved or timed. Files `raw/hf_smoke_refused*`.
3. On `6b68cb931` (guard `8bf77d1bca68`, exit 0, 17:31:25 to 17:37:27 UTC; `raw/hf_smoke2`, counts in `raw/smoke_paths.txt`):

| arm | batched sumchecks | `[ZK60-HOST-FAST]` lines | fall-backs |
|---|---|---|---|
| A | 3804, all `sc-chain-fast` | 0 | 0 |
| B | 3823, all `sc-chain-fast` | 0 | 0 |
| C | 3814, all `sc-chain-fast` | 312 block lines (12 requests of 26 blocks) | 0 in every one of the five fall-back counters |

In arm C every one of the eight hit counters was non-zero in all 312 blocks (sums over the leg: h1 2753, h2 1306, h3 5262, h4 10237, h5 11733, h6g 14168, h6c 1437, h6d 4119). All 36 requests proved; B0's `check-serve` accepted 12 of 12 receipts of arm B and of arm C. Condition (a) of the definition: met.

## Set of record: A, B, C, C, B, A (guard `d52d3ed514f2`, exit 0, peak RSS 58.8 GiB, peak VRAM 23.0 GiB)

| leg | arm | rate, tok/s | mean prove call, s | receipts | start to end, UTC |
|---|---|---|---|---|---|
| 1 | A | 46.858 | 13.295 | unverified | 17:38:38 to 17:41:39 |
| 2 | B | 47.153 | 13.265 | 54 of 54 checked | 17:41:40 to 17:44:41 |
| 3 | C | 50.778 | 12.053 | 54 of 54 checked | 17:47:13 to 17:50:04 |
| 4 | C | 49.244 | 12.221 | 54 of 54 checked | 17:52:36 to 17:55:30 |
| 5 | B | 46.737 | 13.141 | 54 of 54 checked | 17:58:02 to 18:01:05 |
| 6 | A | 44.257 | 14.110 | unverified | 18:03:37 to 18:06:48 |

All 324 requests were proved; 216 B1 receipts were checked by B0 and accepted; no failure.

**Primary, C over A (DERIVED):** pair (leg 1, leg 3) **+8.37%**; pair (leg 6, leg 4) **+11.27%**. **Verdict by the posted rule: PASS** ("PASS at +3 percent or more in both pairs").

**Secondary, no verdict (each pair measured once):** B over A: pair (1, 2) +0.63%, pair (6, 5) +5.60%. C over B (the switch): pair (2, 3) +7.69%, pair (5, 4) +5.36%.

**The low base leg.** Leg 6 ran 5.5% under leg 1 and under every base leg of the day's three sets (46.25 to 46.86 tok/s). No cause is known: `overlap_check.py` (`raw/overlap_check.txt`) finds no other guarded job inside any leg, Antigravity held the GPU, builds and agents idle, and the tester ran nothing between 18:03:09 UTC and the leg's end. An unguarded process cannot be excluded. The second pair's +11.27% and its B over A (+5.60%) carry that leg and are not quoted. Without leg 6: the two C legs are +8.37% and +5.09% over leg 1, and +7.69% and +5.36% over their B neighbours. Had leg 6 equalled leg 1, the second pair would be +5.09%, still a PASS. **Quoted gain: +5 to +8 percent, one set.**

**Other jobs.** Between 17:42 and 18:02 UTC the tester ran two web searches and one page-fetch agent for an unrelated question of the owner (remote calls, no local computation); no research tick and no reader agent ran beside the set.

## Reading (interpretation)

This is a host-side cut, and it carries to six lanes at more than its 8B size (3.0% of the 8B gap, 8.7% less CPU time there). With six lanes by five threads the machine is asked for 30 threads on 24 performance cores, so CPU time saved in one lane is also time given back to the others; that fits, and it is not shown by this set. The first pair of B over A (+0.63%) says the new binary with the switch unset behaves as the base.

Two legs with the switch were 50.8 and 49.2 tok/s. Rates of different sets and days differ by one to two percent (the same base setting gave 46.3 to 46.9 today), so this is not a claim that the profile runs at 50: it says the switch adds 5 to 8 percent to whatever the base is.

## Not measured

A second set (not needed by the rule); a traced pair; the six parts separately; six lanes by eight threads (planned as a four-leg addendum on the merged binary, after the reads and the merge check); the switch without the fast sumcheck chain; private content.

## Files

`hostfast_driver.py`, `t1_driver.py` (helper, a copy), `hostfast_launch.py` (one detached guarded job with a `.done` marker), `guarded_here.py`, `hostfast_summary.py`, `overlap_check.py`, `smoke_paths.py`, `compress_traces.py` (unused here); `raw/` holds the build logs, the three smokes, the set (`hf_set1`), the guard records and the script outputs. No receipts and no binaries are kept. The content is the eight public posts; nothing under the owner-private directory was read.
