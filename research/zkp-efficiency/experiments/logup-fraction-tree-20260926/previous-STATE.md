# ZKP efficiency explorer — durable state

Last completed: **2026-09-26 / cycle-0007**, run `20260926T225233Z-f66107c9`.
Started 22:52:33 UTC; final state checkpoint **2026-09-26T23:06:49.469395+00:00**.
Outcome: **Exact Fp2 Karatsuba/two-product square candidates pass; no measured
speed improvement. Two-hunk Rust proposal retained for owner review only.**
No next cycle before **23:52:33 UTC**. Supervisor owns scheduling; no process
liveness or future-execution claim is made here.

## Target and boundaries

Complete private **8B attention-plus-FFN >=50 proved tokens/s**, including
witness/pre-proof preparation and serialization. The 512-token prefill
reference is **<=10.24 s**, five seconds stretch. Additional project direction
permits larger workloads for amortization; report startup, total-workload and
sustained rates. Proving and verification separate; prefill is not decode.
No complete private 8B timing exists. P1 hides IO/activations; P3 also weights.
D22 remains CPU toy only; D19b/D23 proposed. Research writes only, excluding
runtime; one CPU thread, <=60 s/experiment, <=512 MiB. No production/reviewer
edits, Git, build/install/GPU jobs, external writes/messages or escalation.
Main/Claude owns native review/integration; nothing was merged or queued.

## Latest result

- [Experiment](experiments/fp2-arithmetic-20260926/README.md),
  [result](experiments/fp2-arithmetic-20260926/result.json),
  [handoff](handoffs/20260926-fp2-arithmetic.md).
  **24,641 product cases, 10,121 square cases, 35 powers**, independent
  integer-polynomial oracle; 10,121 base pairs, 10,007 u128 reductions.
- Downstream **24 fused + 13 grouped fixtures**, 630 fused round samples and
  288 final MLEs across three arms, 189 independent grouped round points,
  24 synthetic masked schedules and four zero-factor fallback rounds pass.
  Eleven mutations detected, four harness fixture refusals. Full extension,
  near-p/carry boundaries, padding, base/zero and ragged tiles covered.
- Seed **2026092607**, one Intel Core Ultra 9 185H CPU, **3.718 s**, peak
  **22,496 KiB RSS**. Source/log/history hashes checked by `validate.py`.
  No native proof: prove/verify/readiness fields null. Synthetic schedules do
  not validate native masking, RNG, commitments, refusals or receipt bytes.
- General multiplication: **4 variable products + 1 constant-seven product +
  2 adds -> 3 + 1 + 3 adds + 2 subtracts**. Canonical reductions 5 -> 4.
  Two-product square uses 2 + 1 products, 5 adds, 1 subtract; compare against
  the compiler-possible 3-product square, not literal four calls.
  Add-chain-seven variants reduce products further but add dependencies;
  tested in Python only. Native runtime direction remains unknown.
- [Two-hunk proposed patch](experiments/fp2-arithmetic-20260926/fp2-arithmetic.proposed.patch)
  at `zkp-core/src/field.rs::Fp2::{mul,square}`; main/current-grouped baseline
  hashes match. In-memory patch validation only; never applied or compiled.
  Wrong deferred u128 sums need up to 131/129 bits and fail negative controls.

## Latest bottleneck measurements (owner evidence, unchanged)

Grouped dense A/B passed, terminal zero; queued owner summaries remain stale.
New proving **34.861/33.315 s**, witness **5.43/5.76 s**, serialization
**.031/.020 s**, known readiness **40.322/39.095 s**. Internal verify
**.900/.810 s**, from bytes **.91/.82 s**, separately; 40,783,352 B.
Synthetic dense 125M block, shared two-thread CPU, extra small-slot oracle
work; not enclosing request, quiesced performance, GPU/8B or this lane's run.
Softmax slot **8.601/7.832 s**, A+H encode/Merkle **16.739/16.903 s**.
Fp2 operation attribution is absent. Base-field commitment encoding is not
accelerated by this Fp2 rewrite. No numeric full-proof saving is justified.
All four prior non-warm log hashes rechecked and pinned in this experiment.
Public-weight batching still exposes <0.1% readiness; pair-inverse caching
is a tiny-phase lead. Preserve those negative dispositions.

## Ranked queue and concrete next experiment

1. **Highest immediate owner impact:** group-aware fold/next-round fusion,
   hiding GPU encoding/tagged commitments. Existing fusion and pad-overlap
   handoffs retain native/device gates; do not duplicate owner jobs.
2. **Arithmetic candidate now handed off:** native independent-array AND
   dependent-chain A/B, release compiler inspection, then grouped slot and
   complete readiness including witness/serialization. Require identical
   native masked samples/challenges/finals/RNG/refusals and receipts first.
   Added carry chains or absent readiness benefit falsify promotion.
3. **Next bounded research cycle, proof composition:** tiny fractional LogUp
   tree with `(n,d)` merge `(nL*dR+nR*dL,dL*dR)` versus independent reciprocal
   sums, 1/2/3/8/32 leaves, Fp2 challenges, multiplicities and ragged padding.
   Demonstrate root-zero/cross-multiplication ambiguity, preserve zero-
   multiplicity and whole-public-table zero-denominator refusals, detect
   changed lookup inputs and omitted leaves. Read native shaped H layout and
   `private_block/protocol.rs::write_h`/helper production; count displaced
   helper rows plus NEW tree/binding/mask state. No row-reduction claim until
   all added work and private helper-sum binding are accounted for. Architecture
   feasibility only; no composability/privacy or relation change inferred.

Remaining rotation: sumcheck/GKR -> GPU NTT/commitments -> lookup/softmax ->
memory traffic -> batching/amortization -> quantization/arithmetic.

## Sources and preserved limits

Six primary-source records appended: older quadratic-field paper
2006/471 (received 2006-12-14, revised 2007-02-20), Plonky3 PR2098 (merged
2026-09-09), inspected main quadratic dot-product implementation, prime-ir
issue409 (2026-07-29), August instruction-wall paper refresh, v0.8.0 refresh.
Main MIT text inspected; source update dates/full commits unverified.
Displayed `4faefa9` merge details failed Internal Error; release date still
has no verified year. External author performance unreplicated. No downloaded
code execution/network bypass. A corrected local preparation JSON-key error
is retained. Original history prefixes and earlier full STATE are preserved.
Resume with STATE/FINDINGS/sources/latest results/AGENDA and the required
project CLAUDE/status/decisions/active coordination, then native LIVE search.
