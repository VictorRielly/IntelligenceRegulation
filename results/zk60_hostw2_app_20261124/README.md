# The second host-speed switch (`HL_HOST_FAST_W2=1`) at the installed app profile: PASS by the repeat rule, narrowly (about +3 percent)

By the Claude co-coordinator, 2026-11-24 UTC. The switch is Antigravity's (`agy/host-wave2`); this directory is the independent gate at the profile the installed app runs. Every definition and reading below was written in `ops/zkp-mvp/RECOVERY_COORDINATION.md` (entry 2026-11-24T05:13:45Z) and pushed before the first run. Status of the branch: **not merged**; the code reads, the fixes, the default-path set on the final commit and the merge check are still to come.

## What was tested

- **Binaries.** B0 = the pushed head's prover (merge commit `da8546e7a`), SHA-256 `d12a867edb169f62bc4514da33b6f27bdd722fbbcad1ce9c268b1db6fed7fe31`. B1 = `83d784b26`, SHA-256 `796a65c20d7c069c563985408ae35fc1d1608ad9e9998c2119f14c0a6daed52c`, guard `847455782a04`. (The branch's first rebased tip `8de98094c` did not compile; `raw/build_b1_8de98094c.log`.)
- **Arms.** A = B0 with the five merged switches (`HL_METAL_FUSED_RS=1 HL_METAL_SPARSE_FOLD=1 HL_METAL_SC_CHAIN_FAST=1 HL_HOST_FAST=1 HL_CLASSIFY_HOST_FAST=1`). B = B1 with the same five, the new switch unset. C = B1 with the same five plus `HL_HOST_FAST_W2=1`; `HL_HOST_FAST_ASYNC_DROP` unset (off).
- **Fixture.** As in `results/zk60_classifyhost_app_20261123`: a fresh `zk60_classify serve --lanes 6 --lane-threads 5 --witness-cache-gib 16 --dev-w16r2-public-content-only` per leg, 6 + 48 requests over eight public posts, trained 3B classifier, rate = 48 x 128 tokens over the span of the 48 timed requests, every receipt of B1 checked by B0's `check-serve`. New here: each set begins with one discarded lead-in leg (arm A, printed, never read), and the driver stops a leg that stalls.

## Smoke `w2_smoke` (MEASURED; not a timed measurement), guard in `raw/w2_smoke.guard.json`

Condition (a) met (`raw/smoke_paths_83d784b26.txt`): arm C printed 312 `[ZK60-HOST-FAST-W2] block` lines with hit sums s 1707, te 3721, fw 1693, ad 0 (the async dropper is off), pc 19217, rg 6104, ft 12072, pr 4916, po 11382, me 252582 and every fall-back sum zero; arms A and B printed no wave-2 line; all three arms showed the classifier and host-fast lines with every component hit and zero fall-backs, only `sc-chain-fast` batches; every receipt of B1 was accepted by B0. The counters are process-wide, so the sums are what is established, not a per-block statement.

## The verdict: six lanes by five threads, a lead-in leg then A, B, C, C, B, A

| set | lead-in | A | B | C | C | B | A | C over A | B over A |
|---|---|---|---|---|---|---|---|---|---|
| `w2_set5`, guard `2b881d6dd81a` | 53.627 | 54.173 | 52.971 | 55.869 | 55.638 | 54.081 | 54.303 | +3.13%, +2.46% | -2.22%, -0.41% |
| `w2_set5r`, guard `9a10209f911a` | 54.127 | 54.290 | 53.777 | 55.618 | 56.873 | 54.363 | 54.598 | +2.45%, +4.17% | -0.94%, -0.43% |

- **Rule (the standing one):** PASS at +3% or more in both C-over-A pairs; NO TRANSFER under +1.5% in either; otherwise one repeat, read on the mean of the four pair gains (PASS if the mean is at least +3% and every pair at least +1.5%; NO TRANSFER if the mean is under +1.5%; otherwise "transfers, under the bar"; no third set).
- **Set 1** decided nothing (+3.13% and +2.46%). **With the repeat: mean of the four pair gains +3.05%, lowest pair +2.45%: PASS.** It clears the bar by 0.05 of a point. The size of the gain at this profile is about 3% (2.5 to 4.2); at the 8B size the author measured more (see below).
- With all six switches the stream ran 55.6 to 56.9 tok/s in these two sets, against 54.2 to 54.6 for the pushed head inside the same sets. Figures of different sets are not chained.
- **B over A is reported and decides nothing in these sets:** -2.22%, -0.41%, -0.94%, -0.43%; all four negative, mean -1.0%. The default-path question is asked by its own eight-leg set on the commit that is to be merged (`w2_ab8`: a lead-in leg, then A, B, B, A, B, A, A, B, every leg followed by the same receipt check; "default path intact" if mean B over mean A is at or above -1.5%).
- All 756 requests of the two sets proved; all 432 receipts of B1 accepted by B0; no stall and no Metal error; no other guarded job inside a leg (`overlap_check.py`: 17 timed legs, 0 overlaps); no agent ran beside the sets.

## The 8B evidence (the author's, recomputed by me from its raw log)

`results/zk60_host_wave2_8b_20261123/raw/w2_ab.log` on the branch, synthetic 8B stream `W16R2_8B_T128_H24`, six passes an arm: steady means 40.79 tok/s with the switch off and 43.03 with it on (+5.47%), every pass higher (+3.0 to +7.5%). Caveat: both arms are one binary of an earlier commit, and its switch-off path still built and dropped the histogram record in every block, which `83d784b26` removes; the gain against the base binary at 8B is not measured. A re-run on the final commit is requested.

## What is established, and what is not

- Established at this profile: the switch transfers; about +3% on top of the five merged switches; byte-identical receipts in the sense that B0 accepts every receipt of B1 with the switch on.
- Not established: that the switch-off path is unchanged in speed (four of four pairs are slightly negative; the eight-leg set decides); the reading at six lanes by eight threads (`w2_set8`, to run last); anything about the code beyond the smoke counters (two independent reads are under way).

## Files

`hostw2_driver.py`, `t1_driver.py`, `hostw2_launch.py`, `guarded_here.py`, `hostw2_summary.py` (prints the legs, the pair gains and the means; decides nothing), `overlap_check.py`, `smoke_paths.py`; `raw/` holds the build logs, the smoke (`w2_smoke`), the two sets (`w2_set5`, `w2_set5r`), guard records and script outputs. No receipts and no binaries are kept. The content is the eight public posts; nothing under the owner-private directory was read.
