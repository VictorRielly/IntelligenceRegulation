# Research handoff: the verifier's side of the size step (B6a), per request (2026-11-25, claude tick 58, queue item 98)

From the Claude background researcher. Reading and arithmetic only: no build, no run, no web search, no Git. Written: this file,
`20261125-claude-tick58-verifier-side-b6a.py` (standard library, reads two retained spike logs, under a second) and its output
`20261125-claude-tick58-verifier-side-b6a.out.txt`. Triage material, not a work order: nothing here changes what the prover commits,
so no proof byte, profile or Lean statement is touched; any change to the verifier's checks would need the owner's ruling.

**Read.** Sol's pinned `zkp-core/src/tower.rs` (`replay_fold`, `switch_claim`, `verify_after_bind`, 427-655), `pcs/switched.rs`
(`switched_batch`, `verify_zk_columns`, `verify_zk_switched`, 203-366, 447-493), the fixture `b6a_spike_host.rs:264-416` (what the
verifier timers cover), the optimized overlay's notes and diff (`results/zk60_claude_review_20261116/b6a_wp0/hostfix/`), both spike
`measure.log` files (as pinned, and the optimized build, 7 measured iterations a rate, 1 verifier thread), the D55 A/B log lines of
2026-11-05 (`results/zk60_effplan_20261105/a12merge_d55_ab.log:227-245`), the verifier in the running tree (`run_fork.rs:2807-2982`,
`protocol.rs:4355-4469`) and W16R3 study section 3.3. Labels: MEASURED (record), COUNTED (file:line), DERIVED (script), ASSUMED.

## 1. Result

**Pass, with a correction to the study.** A retained same-machine record exists for today's verifier, so a per-request range can be
given. At 32 blocks (the 8B profile), one thread:

| | per request, one thread | against today's 4.54 s |
|---|---|---|
| B6a as built (verifier unchanged), rates 1/8 to 1/2 | **1.46 to 2.93 s** | x1.6 to x3.1 |
| B6a with tick 56's rational switch row in the verifier | **1.11 to 2.04 s** | x2.2 to x4.1 |
| the spike's BAT + tower alone (hostfix build), a floor | 1.26 / 1.39 / 1.83 s at 1/8, 1/4, 1/2 | |

At six threads (the study's frame, 2.31 s today): **0.27 s** if blocks scaled perfectly (6 waves of one block's one-thread time) to
**1.50 s** if today's observed scaling (x1.96) carried over; that is x1.6 to x8.5 against 2.31 s. **The study's 0.15 s (x5 to x15,
ESTIMATE, W16R3 design 3.3) is below even the floor:** the measured BAT + tower alone is 0.21 to 0.31 s at an ideal six-fold
(32 x 39 to 57 ms / 6), before the 12 MB of column hashing and anything else the verifier does.

At 26 blocks (the classifier; the spike's geometry is the classifier's per the coordinator): BAT + tower alone 1.02 / 1.13 / 1.49 s one
thread, whole B6a verifier 1.19 to 2.38 s as built, 0.90 to 1.65 s rational. No classifier verification time is retained
(`ZK60_SIZE_B6A_BUILD_PLAN_20261124.md` says so itself), so no ratio is given for it; if its per-block cost equalled the 8B's, today's
would be 3.7 s one thread (ASSUMED).

## 2. Today's verifier, and why the study's calibration is off

- MEASURED (2026-11-05, diagonal synthetic weights, 32 blocks, receipt 818,728,480 B): the D12a verifier on **one thread takes 4.54 s**
  (`a12merge_d55_ab.log:227`); the D55 verifier on six threads takes **2.31, 2.33, 2.32 s** (`:232, :237, :245`). That is 141.9 ms a
  block on one thread.
- The study's section 3.3 calibrates "0.433 CPU-s a block" as 2.31 s x 6 / 32, which treats six threads as six fully busy cores.
  The one-thread record says 0.142 s a block: **the calibration is x3.05 too high** (DERIVED). The six-thread speed-up on the record is
  only x1.96. Caution: the two runs are different verifiers (D12a and D55), so the 41% "serial fraction" the two numbers imply
  (1.88 s of 4.54, Amdahl) is a hint, not a fact.
- A serial part exists in the code: after the parallel forks, the tail opens 31 boundary commitments and the two endpoints one after
  another on the calling thread with `pcs::verify_zk_tagged` (`run_fork.rs:2929-2973`). The pinned B6a entry takes the A and H
  statements only (`switched.rs:447-448`), so these openings stay as today under B6a (the integration into the running tree was not
  read). Their time is not retained.

## 3. What the spike's verifier timers cover, and what they leave out

`verify_bat_ms` is `switched_batch` (the same function the prover runs) plus the W binding; `verify_tower_ms` is `verify_after_bind`
(`b6a_spike_host.rs:347-376`). Medians, one thread, MEASURED: as pinned BAT 16.1 and tower 25.1 / 29.0 / 43.2 ms at rates 1/8, 1/4,
1/2 (sum 41.2 / 45.1 / 59.3); on the optimized build BAT 14.4 to 14.5 (a fusion in the shared `opening_claim`, 1.6 ms) and the tower
unchanged, 24.9 / 28.9 / 42.8 (sum 39.4 / 43.4 / 57.2). The overlay is prover-only: `replay_fold`, `verify_after_bind`,
`switch_claim` are byte-identical to the base (its notes), and its parallel work cannot show in a one-thread verifier.

Left out of the timers: `verify_zk_columns` (hash and Merkle-authenticate 280 columns of each of A and H, the 12.0 MB that today's
verifier also hashes), `vector_claims`, and everything else in `verify_core` (the slot replay, M, the boundary openings).

The tower verifier decomposes exactly (DERIVED, tick 56's rates): switch step (positions x 16,384 x 7.7 ns) 17.4 / 21.3 / 35.3 ms,
fold replay 1,032,192 Fp2 products x 5 ns = 5.2 ms, remainder 2.6 ms (BASE, openings, canonical checks, eq tables): 25.2 / 29.1 / 43.2,
against 25.1 / 29.0 / 43.2 measured.

## 4. Which of tick 56's changes reach the verifier

- **Rational switch row: yes, unchanged.** The verifier's `switch_claim` (`tower.rs:457-487`) builds the same combined vector from
  `first.generator(position)` and accumulates `weight * g` for each of 138 / 169 / 280 positions; the rational form (11 NTTs, 6.1 / 6.3
  / 7.0 ms) gives the same Fp2 vector, so transcript and bytes stand. The tower verifier falls to about 13.8 / 14.0 / 14.9 ms
  (DERIVED) and BAT + tower to **28.3 / 28.5 / 29.3 ms a block, flat over the rate**. The generic `LinearCode` trait does not expose
  the evaluation point (overlay notes), so it needs a trait method or a `CoefficientRs` path.
- **`mul_base` alone: yes.** `weight.mul(g)` at `tower.rs:483` has c1 = 0 on every `CoefficientRs` row: tower 16.4 / 18.4 / 25.6 ms.
- **Not applicable:** the fold self-check and `dot(m1, c1)` (T-F1) are prover-only; the verifier's fold replay has no dot. The device
  routes (fold, W2 on the device) and the forward-NTT removal (tick 57) are prover-side.
- BAT's 12.4 ms body (11.1 M Fp-multiplication equivalents, 1.12 ns each, DERIVED) is shared by prover and verifier and is not
  reduced by any of tick 56's items.

## 5. How the per-request range is built (DERIVED, script section 5 and 6)

Per block: today's 141.9 ms minus the removed work, plus the spike's BAT + tower. Removed (counts of study 3.3 x rates from this repo):
column products 33.2 M x 2 Fp multiplications x 1.12 ns = 74 ms (53 to 93), re-encoding 3.08 M NTT points x 8 butterflies = 27 to 103
ms, the transcript absorb of 12.5 MB = 6.1 ms (MEASURED, `baseline_absorb_ms`). The counts sum to 108 to 184 ms; capped by 141.9 minus
the 6.4 ms of column hashing that stays, removed is 108 to 136 ms, leaving 6 to 34 ms of other work. B6a block: 45.7 to 91.5 ms as
built, 34.7 to 63.6 ms rational. The range is wide because the NTT term is uncertain; the lower end needs the largest NTT term.

## 6. Falsifiable tests (none scheduled; all read-only runs of existing code)

- **T-V1 (decides the six-thread figure).** Run the D55 verifier (`verify_run_with_forks`, `workers` = 1, 2, 3, 6) on one 8B
  diagonal-weight receipt with the `timing::Phases` marks printed per fork and for the tail. Pass: the per-phase one-thread time of A, H
  and M openings is 100 to 136 ms a block (confirms section 5's removed work) and the tail's boundary openings are under 5% of the
  verify; fail: the openings are under 90 ms a block, then the B6a gain is below x2 and the figures above move down.
- **T-V2 (spike, verifier side).** Add a timer around `verify_zk_columns` in the spike fixture and call the rational switch row in the
  verifier. Pass: BAT + tower at most 30 ms and columns at most 8 ms at all three rates; kill: columns above 15 ms.
- **T-V3 (weights).** The verifier on dense public weights (not diagonal): the 14 G multiplications of tick 55 are 11 to 20 s one thread
  (0.8 to 1.4 ns), 1.9 to 3.3 s at an ideal six-fold, **more than all of the PCS work either way**, and B6a leaves them. Until a
  committed-weight opening replaces that fold (item 13), the per-request verifier time with real weights is dominated by it.

## 7. Honest effect

Committed words per request: 0 changed. Proved tokens per second: none, since verification runs after the clock (the A/B log's
"all 4 receipts verified after the clock"). What moves is verification latency and the wrapper's work: B6a's verifier is about x1.6 to
x3.1 faster as built and x2.2 to x4.1 with the rational switch row, one thread, on diagonal weights, not the study's x5 to x15.

## 8. Risks and not verified

- The 4.54 s (D12a, one thread) and 2.31 s (D55, six threads) are different verifiers; T-V1 is the clean test.
- Rates for the removed work are counts x one repo-derived rate (1.12 ns per Fp multiplication, BAT's own); the NTT term's butterfly
  count per point (8, one or two components) was not read from `pcs.rs`.
- The spike's synthetic columns have empty paths and zero salts (`b6a_spike_host.rs:125-143`), so authentication is not exercised.
- Where the verifier's non-PCS work (slot replay, M, boundaries) sits in the 141.9 ms is not retained; no phase-split verification
  record at W16R2 exists on this machine (the only ones are from September, another machine).
- The geometry of the spike against the classifier and the 8B block (A 2,501 and H 2,602 rows) was taken as the coordinator states;
  per-block verifier cost at the other profile is unverified.
- Integration of `verify_zk_switched` into `verify_core` was not read.
