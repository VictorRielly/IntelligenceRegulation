# ZKP efficiency explorer — durable state

Last completed: **cycle-0008**, run `20260926T235233Z-5f465072`.
Started **2026-09-26 23:52:33 UTC**; final checkpoint **2026-09-27T00:08:34.704444+00:00**.
Outcome: **Fraction-tree algebra passes; naïve private adaptation discloses
lookup values and materializes too much state. No measured speed improvement.**
No next cycle before **2026-09-27 00:52:33 UTC**. Supervisor owns scheduling;
no liveness or future-execution claim is made here.

## Target and boundaries

Complete private **8B attention-plus-FFN >=50 proved tokens/s**, including
witness/pre-proof preparation and serialization. The 512-token prefill
reference is **<=10.24 s**, five seconds stretch. Additional project direction
permits larger workloads for amortization; report startup, total and sustained
rates separately. Proving and verification separate; prefill is not decode.
No complete private 8B timing exists. P1 hides IO/activations; P3 also weights.
D22 remains CPU toy only; D19b/D23 proposed. Research writes only, excluding
runtime; one CPU thread, <=60 s/experiment, <=512 MiB. No production/reviewer
edits, Git, build/install/GPU jobs, external messages or escalation. Main/Claude
owns native review/integration; nothing was merged or queued.

## Latest experiment

- [Experiment](experiments/logup-fraction-tree-20260926/README.md),
  [result](experiments/logup-fraction-tree-20260926/result.json),
  [design handoff](handoffs/20260926-logup-fraction-tree.md).
  **150 fraction cases, 100 lookup identities, 300 independent MLE checks,
  15 controls pass**, lengths 1/2/3/8/32; full Fp2 and signed/zero weights.
- Independent reciprocal sum and O(n²) product expansion agree with binary
  `(nL*dR+nR*dL,dL*dR)` merges; `(0,1)` padding. Not a GKR/PCS proof.
- **Decisive negative:** unmasked denominator root D for one secret v equals
  `(alpha-tag-v)*C` for public table product C, recovering v exactly. Also
  `(0,0)` roots fool weak cross-products; pruning zero-multiplicity table
  leaves changes refusals; matched omissions require ORIGINAL witness binding.
  These are naïve-adaptation controls, not native/upstream vulnerability claims.
- Seed **2026092608**, Intel Core Ultra 9 185H, **0.7621 s / 15,820 KiB RSS**,
  one CPU. Native prove/verify/readiness null. No native source patched.
  Validation passes: 14 source hashes, eight native snapshots, four owner-log
  hashes, source records and original history prefixes. Initial passing run
  preserved; its flat-tree base-row floor corrected 65,535 -> **65,536**.

## Bottleneck and costs

Latest owner dense grouped A/B remains passed, terminal zero; old queued
summaries are stale. New proving **34.861/33.315 s**, witness **5.43/5.76 s**,
serialization **.031/.020 s**, known readiness **40.322/39.095 s**. Internal
verify **.900/.810 s**, from bytes **.91/.82 s**, separate; 40,783,352 B.
Synthetic dense 125M block, shared two-thread CPU, extra small-slot oracle
work; not enclosing request, quiesced benchmark, GPU/8B or this lane's run.

H encode/Merkle **9.377/9.593 s** (23.3%/24.5% of known readiness), softmax
slot **8.601/7.832 s**, combined A+H **16.739/16.903 s**. Removing an entire
phase is only an accounting ceiling, not a candidate saving.
Shaped H: **7,016 helper data rows + 2 zero-sum + 100 site masks + 2 proximity
= 7,120 rows**, 933,232,640 input bytes / 3,732,930,560 encoded-value bytes.
Naïve global fraction tree: 103,890,944 leaves -> 2^27 padded; almost **8 GiB**
for all nodes, 4 GiB leaf layer, 6 GiB out-of-place first step, before scratch.
Generic merge products **402,653,181**. These are unallocated counts, not lower
bounds or timings. New GKR masks/binding rows and **net row saving unknown**.
H helper removal requires a new private protocol, not only `write_h` replacement.

## Ranked queue and concrete next experiment

1. **Owner priority / next bounded sumcheck-GKR research:** adapt the prior
   fold+next-round fusion to all three native SC_SZC equality groups. Reuse
   pinned generic fusion/grouped oracles and read current `GroupedEqRounds`.
   Test 1–256 rows, full-extension challenges, separate equality points,
   ragged tiles, zero-factor fallbacks, actual per-group running claims and
   table finals. Compare every sample with unfused grouped evaluation AND
   direct cube MLEs. Count reads/writes separately from bracket evaluations.
   Stale prefix/suffix, combined-host-claim and scheduling controls required.
   Small-case added work or lost group savings falsifies promotion. No native
   build/GPU job in this lane; owner reviews after the synthetic gate.
2. **Fp2 arithmetic handoff remains:** native independent-array and dependent-
   chain A/B + release compiler inspection, then grouped slot and complete
   readiness. Native masking/RNG/refusal/receipt gates remain unrun here.
3. **Fractional-GKR architecture:** only resume with a design for masked root,
   layer messages, ordered trace link, whole-table refusal preservation and
   streamed lifetimes. Price new masks/PCS/verification/proof bytes before net
   saving. Current prototype does not establish privacy or composability.
4. **GPU commitments:** prior pad-overlap/layout handoff remains for owner
   device review. Public-weight batching <0.1% readiness and pair-cache tiny-
   phase negatives remain demoted; do not rediscover them without new evidence.

Remaining rotation after sumcheck/GKR: GPU NTT/commitments -> lookup/softmax ->
memory traffic -> batching/amortization -> quantization/arithmetic -> composition.

## Sources and preserved limits

Eight primary records appended: fractional-GKR refresh (2023, revised 2025),
September Plonky3 lookup PR/release, SP1 verifier, June tree-memory issue,
new older Winterfell interface/Boolean-GKR assessments and Jolt Atlas discovery.
Main MIT/Apache text inspected; version-specific licenses/commits unverified.
Plonky3 merge ID is hyperlink only (Cache miss); release year remains unverified.
SP1 crate/latest serves 6.0.2 dated 2026-02-26, but versioned source failed;
unversioned inspected source is not assumed revision-aligned. Paper PDF robots
denial and source/PR errors retained. No downloaded code execution or bypass.
Sources were searched across UTC midnight; records distinguish first access
from record creation and retain the inspection window.
Resume with STATE/FINDINGS/sources/latest results/AGENDA and required project
CLAUDE/status/decisions/active coordination, then native LIVE search.
