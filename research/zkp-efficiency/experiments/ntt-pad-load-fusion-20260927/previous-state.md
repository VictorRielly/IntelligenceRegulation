# ZKP efficiency explorer — durable state

Last completed: **cycle-0009**, run `20260927T005233Z-ccb9384b`.
Started **2026-09-27 00:52:33 UTC**; checkpoint **2026-09-27T01:08:22.342306+00:00**.
Outcome: **Grouped fold/next-round fusion passes exact algebra and saves
19.92% counted table traffic at 256 rows; native speed remains unmeasured.**
No next cycle before **2026-09-27 01:52:33 UTC**. Supervisor owns scheduling;
no process-liveness or future-execution claim is made here.

## Target and boundaries

Complete private 8B attention-plus-FFN >=50 proved tokens/s, including witness
preparation and serialization; 512-token prefill <=10.24 s reference, five
seconds stretch. Larger workloads permitted with separate startup/total/warm
accounting; prefill is not decode. No complete private 8B timing exists.
D22 CPU toy only; D19b/D23 proposed. All writes research-only excluding runtime;
one thread, <=60 s/experiment, <=512 MiB. No builds/install/GPU/Git/production
edits, external messages or escalation. Native review/integration belongs to
main/Claude; nothing merged or queued.

## Latest experiment

- [README](experiments/grouped-fused-round-20260927/README.md),
  [result](experiments/grouped-fused-round-20260927/result.json),
  [handoff](handoffs/20260927-grouped-fused-round.md).
- **37 cases**, all **651 round samples** independently cube-MLE checked,
  **1,953 group samples**, **962 finals**, six zero-factor fallbacks,
  37 synthetic drivers, ten controls, 12 schedule and three fixture refusals.
  Rows 1/2/4/8/16/32/256; full Fp2; short equality support; ragged/reversed tiles.
- 26 synthetic tables, 256 rows: **26,520 -> 19,916 reads**, **6,630 writes**
  unchanged; **530,400 -> 424,736 logical B (19.9216%)**. Padded brackets stay
  [1148,638,638]. These are not native/DRAM/time measurements.
- Initial serial tile reductions added 11 field adds at four padded rows and
  506 at 256/tile3; rejected, preserved in initial/ and a final negative arm.
  Final serial path directly accumulates. Two-row case saves nothing.
- Seed 2026092709; Intel Core Ultra 9 185H; **9.2027 s / 24,192 KiB RSS**,
  one CPU. Validation passed: 24 artifact hashes, seven source/snapshot pairs,
  four owner logs and original history prefixes; eight source records appended.
  Prove/verify/readiness null. Uncompiled/unapplied Rust serial sketch
  at `grouped_fused.proposed.rs`; native parallel ownership and full gates owed.

## Measured bottleneck

Owner grouped A/B passed, terminal zero, four non-warm logs rechecked. New
prove **34.861/33.315 s**, witness **5.43/5.76 s**, serialization **.031/.020 s**,
known readiness **40.322/39.095 s**. Internal verify **.900/.810 s**, from bytes
**.91/.82 s**, separate. Shared two-thread dense synthetic 125M block, extra
oracles, not enclosing request/GPU/8B or this lane's run. Softmax slot
**8.601/7.832 s**; A+H encode/Merkle **16.739/16.903 s**. Fusion's fold/cache
share and end-to-end saving unknown; full-slot deletion is only a ceiling.

## Ranked queue / concrete next experiment

1. **Owner:** grouped fusion native masked/RNG/IR/extension/receipt gates,
   then complete evaluator/slot and readiness A/B under shared locks. Work
   moves into fold, so round-only timing is invalid. Preserve Rayon cutoff and
   grouping; serial sketch is not a large-table replacement.
2. **Next research, GPU NTT/commitments:** test hiding pad/coset production
   fused into `k_ntt_p1`'s bit-reversed load, avoiding actual `coef2` materialization
   in `hashline/src/gpu/cuda.rs::encode_rows_view_zk[_gather]`. Compare to current
   compact pw=n+q baseline, and direct polynomial oracle. q<n/q=n/q>n, non-unit
   coset, full/compact stride, ragged chunks, duplicate/unsorted gathers. Count
   coefficient/pad/power reads as well as removed scratch writes; scattered
   accesses may erase benefit. Preserve known pad-overlap negative. CPU tiny
   simulation only; tagged device path remains an integration prerequisite.
3. **Fp2 owner handoff:** release array/chain arithmetic A/B, then actual slot
   and readiness; carry costs can defeat multiply-count reductions.
4. **Architecture:** masked fractional-GKR only with original leaf links,
   full-table refusal and streamed lifetimes. Preserve disclosure/tree-memory
   negatives; public-weight batching <0.1% and pair-cache tiny phase stay demoted.

Remaining rotation: lookup/softmax -> memory traffic -> batching/amortization
-> quantization/arithmetic -> proof composition -> sumcheck/GKR.

## Sources and next pickup

Eight primary records appended. Older ICICLE CUDA fusion article 2025-04-01
newly assessed; frontend MIT inspected, separate backend license unverified.
Plonky3 release date lacks year; source/docs revision mismatch and inaccessible
PR/commit/package retained. Jolt/2026 sumcheck refreshed. June hardware study
is 255-bit synthesized/simulated acceleration, not GPU measurements. No
external code executed or benchmark reproduced. See search-log.json for exact
errors. Resume by reading STATE/FINDINGS/sources/latest results/AGENDA and
required project CLAUDE/status/decisions/active coordination, then LIVE search.
