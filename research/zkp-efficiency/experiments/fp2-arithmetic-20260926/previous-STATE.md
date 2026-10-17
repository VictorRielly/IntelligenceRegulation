# ZKP efficiency explorer — durable state

Last completed: **2026-09-26 / cycle-0006**, run `20260926T215233Z-c6bf3a4b`.
Started 21:52:33 UTC; final state checkpoint **2026-09-26T22:05:21.501779+00:00**.
Outcome: **385 batched-weight-fold cases pass; current complete-slot ceiling
<0.1% of known readiness, so demote this optimization. No speed gain measured.**
No next cycle before **22:52:33 UTC**. Supervisor owns scheduling; this file
makes no process-liveness or future-execution claim.

## Target and boundaries

Complete private **8B attention-plus-FFN >=50 proved tokens/s**, including
witness/pre-proof preparation and serialization. The 512-token prefill
reference means **<=10.24 s**; five seconds remains a stretch. Additional
project direction permits larger workloads for amortization; report startup,
whole-workload and sustained rates. Proving/verification separate. No prefill
rate establishes decode. No complete private 8B timing exists. P1 hides IO
and activations; P3 also hides weights. D22 is CPU toy only; D19b/D23 proposed.
Research writes only, excluding runtime. One CPU thread, <=60 s/experiment,
<=512 MiB. No production/reviewer edits, Git/build/install/GPU, external
writes/messages, escalation or queued jobs. Main/Claude reviews integration.

## Latest result and updated owner measurements

- [Experiment](experiments/batched-weight-fold-20260926/README.md),
  [result](experiments/batched-weight-fold-20260926/result.json),
  [validation](experiments/batched-weight-fold-20260926/validation.json).
  **385 cases, 29,290 field outputs, 13,260 direct equality entries, 360 matrix
  MLEs, eight mutations and six fixture refusals pass.** Seed 2026092606,
  one CPU, 3.2093 s, 16,300 KiB RSS. All fixtures synthetic. No native proof run.
- B=1/2/4/8, row tiles 1/3/8/32, 1x1..65x128, signed extrema, full Fp2,
  padding, zero/sparse matrices, tails. Independent signed-integer-dot and
  cube-MLE references. Source/log hashes and prior history prefixes verified.
- Modeled 1024x4096 B=8 weight reads 33,554,432 -> 4,194,304 bytes. Counting
  coefficient reads/output, row tile 1 saves only **5.15%** ideal traffic;
  tile 32 models **58.18%**, with 4,096+128 live accumulator/coefficient bytes.
  Same row tile in both arms. Arithmetic and separately itemized local
  accesses remain. This is not measured DRAM traffic or runtime.
- Native seam: `zkp-core/src/mle.rs::fold_cols_i8`, FFN calls at
  `hashline/src/private_block/argument.rs:1432`. Slots draw challenges
  sequentially; gate/up/down use different matrices. A separate-proof
  rendezvous and its memory/latency costs are unimplemented. No patch applied
  or compiled; [handoff](handoffs/20260926-batched-weight-fold.md) is a
  **low-priority disposition**, not an integration recommendation.
- **Grouped dense A/B is now passed**, terminal zero; its queued README is
  stale. [Pinned clocks](experiments/batched-weight-fold-20260926/bottleneck.json):
  new proving **34.861/33.315 s**, witness **5.43/5.76 s**, serialization
  **.031/.020 s**, known readiness **40.322/39.095 s**. Verify internal
  **.900/.810 s**, from bytes **.91/.82 s**. Three complete FFN matmul slots
  **.035/.032 s** (~.087%/.082% readiness); fold-only time is smaller.
  Whole-process RSS there 8,548/8,591 MiB, not a concurrency forecast.
- Old proving 37.630/36.836 s; complete softmax slot old 10.050/10.085 s,
  new 8.601/7.832 s. Positive owner diagnostic evidence, two non-warm runs
  per arm on shared two-thread CPU, synthetic 125M, unchanged 40,783,352 B.
  No quiesced speed, GPU/8B projection or enclosing request timing implied.
  A+H commit encode/Merkle remains 16.739/16.903 s in the new arms.

## Ranked queue and next concrete experiment

1. **Quantization/arithmetic, next:** exact Fp2 Karatsuba/specialized square
   at `zkp-core/src/field.rs:158/:172`. Source has four variable base products
   plus multiplication by seven, and `square` calls `mul`. Test schoolbook
   versus candidate using independent big-integer polynomial reduction, with
   zero/base/full-extension/near-p inputs; then small existing grouped/fused
   round fixtures. Detect wrong nonresidue/cross-term and unreduced sum/u128
   overflow. Count multiplies, adds and reductions; no kernel/model speed
   estimate. Extra additions, carries or dependency chains may erase gains.
   No field/modulus/privacy/transcript change. Native timing/receipts owner-only.
2. **Larger measured phases:** owner native group-aware fusion and GPU
   commitments. Retain equality-factor savings and hiding pad semantics.
   Prior handoffs remain awaiting their native/device gates; no duplicate job.
3. **Higher-cost architecture:** fractional-GKR helper-column reduction;
   CQLin/ZKTorch preprocessing/accumulation need different PCS/composition,
   setup and masking review. Public-weight folds currently too small to
   justify a KZG rewrite or concurrent-proof scheduler.

Remaining rotation: proof composition -> sumcheck/GKR -> GPU NTT/commitments
-> lookup/softmax -> memory traffic -> batching/amortization.

## Sources and preserved negatives

Six primary-source records appended: September 23 SLP paper and artifact repo,
ZKTorch July 2025 paper/repo, CQLin (2023-03-19, revised 2023-10-16), Plonky3
release refresh. Sampled coverage does not meet this target; packed-offset
RoPE behavior/public IO do not transfer to exact P1 independent contexts.
External author timings unreplicated. ZKTorch master Apache-2.0 inspected;
commit detail fetches Cache miss, linked hashes explicitly uninspected. SLP
data license undetermined. Release date still lacks verified year. Exact
fetch failures retained; no network fallback/bypass or downloaded execution.
All prior findings and source records preserved. Previous full STATE archived
in this experiment. Pair-inverse cache remains tiny-phase; NTT overlap repair
needs device tests; fusion counts are not speed results; D22 scope unchanged.
Resume by reading this state, FINDINGS, sources, latest results, AGENDA and
project CLAUDE/status/decisions/active coordination before the next cycle.
