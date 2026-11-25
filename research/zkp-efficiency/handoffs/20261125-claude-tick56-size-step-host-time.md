# Research handoff: where the size step's host time goes, counted from the switched opening's source (2026-11-25, claude tick 56, queue item 96)

From the Claude background researcher. Reading and counting only: no build, no run, no web search, no Git. Written: this file,
`20261125-claude-tick56-size-step-host-time.py` (standard library, reads the retained spike log, under a second) and its output
`20261125-claude-tick56-size-step-host-time.out.txt`. Triage material, not a work order.

**Read in full.** Sol's pinned `tower.rs`, `pcs/switch.rs`, `pcs/switched.rs` (lines 1-420), the fixture `b6a_spike_host.rs`, the runner
`zk60_b6a_spike.rs`, and the whole `measure.log` of attempt-00 (5 prover threads, 2 warm and 7 measured iterations; medians, as `result.json`).
These are Sol's pinned B6a sources, not the shipped prover: B6a is not in the running tree. Labels: COUNTED (file:line), MEASURED (the log),
DERIVED (arithmetic in the script), ASSUMED.

## 1. Result

**Pass.** The counts account for 86.9 of the 90.8 ms (96%) of the two timers (BAT 16.95 ms, tower 73.84 ms at rate 1/4). Largest phase: the
first fold, 29.8 ms (29% of the +99 ms). Honest limit: the rates that turn counts into milliseconds are calibrated on this same record
(section 3), so the agreement is a consistency check, not an independent test.

| Phase at rate 1/4 | ms | Threads | On the device with an existing kernel? | Inherent? |
|---|---:|---|---|---|
| First fold, `prove_fold` (`tower.rs:382-425`) | 29.8 | serial | yes: a product sumcheck, 0.35 to 2.1 ms (section 5) | cheap on parallel hardware |
| Switch step (`tower.rs:457-487`) | 21.3 | serial | no kernel read; a host rational form is about 6 ms | no |
| W2 commitment (`tower.rs:191-235`, call at `:540`) | 20.8 | NTT row loop serial; hash and Merkle on the pool | yes, the W commit route, about 0.2 ms | geometry fixed by the profile |
| BAT (`switched.rs:306-366`) | 17.0 | serial | per-vector loops independent | the Fp2 scalings, not the double copy |
| Bridge prep (spike `:59-67`) | 5.9 | NTT on 5 threads | device NTT kernels exist, not read | unknown |
| Salts, salted leaves, Merkle tree | 7.2 | leaf map serial, tree parallel | no | per position |

Sum of medians of the timers 97.7 ms against `host_added` 99.07; the 1.4 ms left is the host side of the commit call (encode wall minus GPU, 0.93).
The plan's estimate (+2.5 to +10 ms) missed by 10 to 40 times because it priced no fold, no second commitment and no switch step on the host.

## 2. Counts (head start checked)

- **First fold:** 6 rounds, 1,032,192 pairs, 5 Fp2 multiplications a pair (s2, two dots, two folds) = 5,160,960, plus the initial check dot
  (786,432) and the final dot (16,384) = **5,963,776, confirmed**. No parallel loop anywhere in `tower.rs`; five threads idle. One Fp2 multiplication
  is 5 Fp multiplications (`field.rs:163-169`).
- **Switch step:** 138, 169, 280 positions x 16,384 entries = 2.26 M, 2.77 M, 4.59 M, **confirmed**. Each entry is one Fp multiplication (power
  chain), one generic Fp2 multiplication (`generator` returns `Fp2::from_base`, so c1 = 0 and `mul_base` would give the same value with 3 of 6
  Fp multiplications) and one add; a fresh 262 KB vector per position. Measured slope: verifier 7.7 to 7.8 ns an entry, prover 6.3, 7.7, 7.4.
- **W2 commitment:** 16 rows x 2 components = 32 NTTs of 32,768 (7.86 M butterflies, serial `for` loop), 8.39 MB hashed, 32,768 salts and salted
  leaves, 32,767 nodes.
- **BAT (not in the head start):** 1,639,045 Fp2 multiplications (generator scaling 783,208, evaluation columns 737,280, row weights 118,557) and
  1,428,840 `mul_base` in the column dots; two rational generators (1.85 ms each, MEASURED); no parallel loop. **BAT already uses the rational
  form** (`switch.rs:240-241`): the dense form (46 ms a source) is a diagnostic outside the timer. Its 47 output vectors (12.5 MB) are built and
  then copied again into W by `pack`.
- **Recomputation:** the first fold's initial `dot(message, coefficients) == target` (`tower.rs:390`) repeats the claim BAT just built: a
  self-check, 786,432 multiplications (3.9 ms). Each round's `dot(m1, c1)` equals current target minus `dot(m0, c0)`, which the verifier already
  requires (`tower.rs:445`): 1,032,192 multiplications (5.2 ms) that need not be computed. Both leave proof bytes identical.

## 3. Rates, all from this repository

- W commit on the host (M1-CPU): 2.11 to 2.18 ns per butterfly all-in at 1/8, 1/4, 1/2 (MEASURED time over COUNTED butterflies). At 1/2 the
  transform size equals W2's, so W2 = 7.86 M x 2.18 ns + tree 3.67 ms = 20.8 ms.
- Salts + salted leaf + tree: 106, 109, 112 ns a position (MEASURED).
- Verifier slope 7.7 ns an entry (MEASURED); fold pair 5.5 ns from the verifier's remainder (DERIVED, 2 ms of small items ASSUMED); working
  figure 5.0 ns an Fp2 multiplication.
- Model: switch + fold 29.8 + W2 20.8 + misc 2.0 (ASSUMED) = 70.0, 73.9, 87.9 ms against 70.6, 73.8, 87.8 measured.

## 4. Switch step: rational form (head start item 3)

Yes. The row is sum_k w_k x_k^j for j < n with distinct nonzero x_k = 7 omega^pos (`tower.rs:94-108`), the first n coefficients of N(T)/Z(T),
Z = product(1 - x_k T). Same Fp2 vector, so same transcript and bytes. Count: Z and N by the loops of `switch.rs:118-140` (m^2 scale, 0.3 to 1.1 ms),
1/Z mod T^n by Newton (about 6 NTTs of 32,768) and N times 1/Z (5 more): 11 NTTs at 0.53 ms = **about 6.1, 6.3, 7.0 ms** against 17.4, 21.3, 35.3
dense (DERIVED). The cheaper step, `mul_base`, gives 8.7, 10.7, 17.7. The verifier runs the same loop (29 to 43 ms of its tower), so both help it.

## 5. Device time of the product sumcheck (head start item 4)

2^20 Fp2 entries, 6 rounds: pairs 2^19 down to 2^14, 5.16 M products, 99.1 MB read and written (0.14 ms at K0's 700 GB/s). Per round
max(products x rate, floor), rates and floors from the K5 ladders (`results/zk60_k0k1_roofline_20261118/k5_analysis.txt`, as read by tick 53):

| Case | Rate | Floor a round | Fold, ms | W (MEASURED 0.89 / 1.18 / 1.67) + fold + hand-back |
|---|---|---|---:|---|
| low | K4 23.5 ps | 0.057 (fast step) | 0.35 | 1.43 (pass) |
| mid | 50 ps | 0.118 (slot 18) | 0.72 | 2.40 (pass) |
| high | 77.5 ps | 0.35 (slot 14, rounds 6+) | 2.10 | 4.77 (between 3.0 and 6.0) |

Hand-back/dispatch is ASSUMED (0.2, 0.5, 1.0; M1's encode wall minus GPU is 0.93). W2 on the same route adds about 0.2 ms by word count. Not
included: moving the 12.6 MB coefficient row to the device (a copy of about 1.5 ms unless BAT writes into a shared buffer).

## 6. What it does and does not do (DERIVED, section 8 of the script)

Stacking everything above at 1/4 (rational switch step, fold on the device, W2 on the device, BAT on five threads at an ideal 5x) takes the host
add from 99 to about 29 ms. That is still above the +15 ms line, with the bridge (5.9), tree (7.2), W2 tree (3.7), switch (6.3) and the BAT
remainder left. At 32 blocks, 99 ms is 3.17 s a request at full pass-through (the stream period is 3.18 s); 29 ms is 0.93 s. Ceilings only: the
hidden share is unmeasured. Committed words: **0 changed** (every item keeps the bytes); proved tokens per second: only through host time on the
critical path, at most x ms x 32 / 3,180 of the period.

## 7. Falsifiable tests (not scheduled; none edits Sol's directory, all in an isolated copy)

- **T-R1:** replace the switch step with the rational form, assert the coefficient vector equals the dense one at the three rates (BAT's own
  `assert_eq!(dense, rational)`), time on 5 threads. Pass: at most 8 ms at 169 positions and `verify_tower_ms` falls by the same amount; fail: over 12 ms.
- **T-F1:** drop `dot(m1, c1)` and the self-check; assert `first_fold` bytes equal. Pass: `prove_tower_ms` falls at least 7 ms at all three rates.
- **T-D1:** the six-round product sumcheck over 2^20 pairs with GPU timestamps. Pass: at most 1.3 ms (W at its worst 1.7 stays under 3.0);
  kill: over 4.3 ms.

## 8. Risks and not verified

- Rates are calibrated on one record (attempt-00, one machine state, synthetic random rows); `ntt.rs`, `rng.rs`, `metal_commit_zk` and the generator
  of `host_added` in `result.json` were not read (reconstructed within 1.4 ms).
- The device range rests on K5 shapes of 21 and 39 tables; a 2-table kernel was never benched, and no existing kernel was inspected for this fold.
- Why the bridge's forward NTT exists (Lagrange input to the device commit against `CoefficientRs` coefficients) was not resolved; new item 97.
- Whether the real A/H fold cost differs from this fixture is outside this record.
