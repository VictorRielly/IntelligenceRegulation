# [UPERF-PC] U-PERF lane PC — wave/opening overhead (the 68.8%)

Status: Phase 0 in progress (O1 CRS memo landed 2026-08-13; O2-O4
open). Standing queue: CONTINUATION.md.
Branch uperf-pc at base c081212. All timings [MAC-BOX ~1T,
NOISY-SHARED] unless marked. PERF RULE: every optimization here is
differential — bit-identical transcript bytes, unmoved freeze
digests, identical verdicts at fixed test seeds; anything that would
move a byte is an R-row (Appendix), not a build.

## 1. Scope and baselines (from the frozen reports)

- m125 layer pass (M125_PASS_REPORT Section 5): 12-layer prove
  3,275.1 s, waves 2,251.8 s = 68.8% (127 masked wave ct-rounds per
  layer at ~131 commitments each), descents 25.5%. Layer-2 row:
  prove 254.7 s, waves 170.1 s, commit 38.7 s, verify 34.0 s.
- Composed pass (UAGB1_PASS_AGG_REPORT BG-F3): prove 69.6 min,
  level-0-dominated — h cross-garbage Theta(n_0*r) at the r = 64
  cap (~500M + ~227M kara-muls across the two groups), three
  O(N_limb) claim-kernel/phi passes, commit 380 s. Verifier
  residual (UAGB1_VERIFIER_REPORT 1): 1.03 s level-0 seed-XOF CRS
  expansion at the single-layer shape.

## 2. Wave-phase attribution (deliverable 1) — baseline

(to be measured: `uperf-pc wave-profile 2 512` at the baseline
commit; per-phase table for the m125 layer scope + eval-proof phase
table for the composed scope via `uperf-pc pass-profile`.)

## 3. Optimizations (each with its differential check)

Land in measured-share order. Transcript-preserving only.

### O1 — CRS memo (`expand_level_matrix`) — LANDED 2026-08-13

`eval_proof::expand_level_matrix` memoizes by
`(seed, group, level, which, rows, cols, q)`. Hits return a clone
of the cached polynomials; misses run the original XOF expansion
and store it. Prove-then-verify of the same group therefore pays
the seed-XOF once per unique CRS matrix (the 1.03 s BH residual
class + double re-expansions). Values are byte-identical to
`expand_level_matrix_raw` (the uncached oracle) — asserted by
`uperf-pc diff-battery` leg O1. Cache is process-global;
`clear_crs_cache` exists for tests. No transcript bytes change:
the CRS is deterministic from public (seed, labels, shapes).

Wall-clock on the 125M rig is NOT claimed here. Measure with
`uperf-pc pass-profile` on a quiesced box (ep.crs-expand vs
ep.crs-cache-hit).

### O2-O4 — NOT LANDED

O2 h-garbage NTT-MAC, O3 matvec_modq_small NTT-MAC, O4
prove_ct_round alloc/borrow. See CONTINUATION.md Phase 0.

## 4. Cumulative results

(m125-layer scope and composed scope before/after; the honest
wall-clock deltas at the same box state.)

## 5. Walls and cross-zone findings (filed, not built)

(measured shares for off-zone costs: mod.rs XofReader/gaussian
economics, commit.rs/aux shared column transforms, thread model.)

## Appendix R — transcript-CHANGING candidates (R-rows, not built)

(candidates with derived savings for the orchestrator to rule on.)
