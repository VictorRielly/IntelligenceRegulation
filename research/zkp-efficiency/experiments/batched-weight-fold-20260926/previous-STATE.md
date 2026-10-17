# ZKP efficiency explorer — durable state

Last completed: **2026-09-26 / cycle-0005**, run `20260926T205233Z-79c00f5e`.
Started 20:52:33 UTC; final state checkpoint **2026-09-26T21:07:12.685879+00:00**.
Outcome: **exact fold/next-round fusion candidate; 19.98% fewer modeled table
bytes at the largest tested shape; no measured proving improvement**.
No next cycle before **21:52:33 UTC**. Supervisor owns scheduling; no process
liveness or future execution is inferred from this file.

## Target and boundaries

Complete private **8B attention-plus-FFN >=50 proved tokens/s**, including
witness/pre-proof preparation and serialization. For the existing 512-token
prefill reference this means **<=10.24 s**; five seconds remains a stretch.
Current project direction additionally permits larger workloads for
amortization; retain startup, total-workload and sustained rates explicitly.
Report proving and verification separately. Prefill does not establish decode.
No complete private 8B timing exists. P1 hides inputs/outputs/activations;
P3 also hides weights. D22 remains CPU toy only; D19b/D23 remain proposed.

Research-directory writes only, excluding runtime/. Production read-only.
One-thread CPU experiments <=60 s and <=512 MiB. No GPU/build/install/Git,
external writes/messages, escalation, production/reviewer edits or queued jobs.
Main/Claude reviews and integrates handoffs.

## Latest result and evidence

- [Experiment](experiments/fused-fold-round-20260926/README.md),
  [result](experiments/fused-fold-round-20260926/result.json),
  [validation](experiments/fused-fold-round-20260926/validation.json).
- **108 differential cases, 180 direct-MLE round checks, 432 final MLEs,
  54 synthetic masked-driver cases, eight mutations, ten schedule refusals
  and eight fixture refusals pass.** One CPU, 2.7433 s, 17,700 KiB RSS,
  seed 2026092605. Source hashes and prior log prefixes rechecked.
- Four tables, lengths 1..1024, degrees 2/3, base/full Fp2, zero equality
  factors, extension/0/1 challenges, recovery on/off, chunks 1/3/7 and tails.
  At N=1024 reads 16,368 -> 12,280 words, both write 4,092; counted table
  bytes **327,360 -> 261,952**. Polynomial calls unchanged. Cache/write
  allocation/scratch/driver traffic excluded; this is not DRAM or timing data.
- [Owner handoff](handoffs/20260926-fused-fold-round.md) identifies
  `zkp-core/src/sumcheck/rounds.rs` and native argument.rs:553/:556.
  `fused_fold_measure.proposed.rs` is an **uncompiled/unapplied SERIAL sketch**,
  not a parallel speed patch. Original source snapshots and hashes retained.
- SC_SZC already uses `GroupedEqRounds`; fusion needs its own adaptation,
  preserving per-group claims/prefixes, suffix setup, zero-factor fallbacks,
  tables and finals. Generic replacement would lose equality-factor savings.
  Native transcript/RNG/extension rounds/receipts/GPU remain untested.
- [Bottlenecks](experiments/fused-fold-round-20260926/bottleneck.json): R2a
  slot-17 masked sumcheck 9.858/9.686 s, prove 39.733/40.095 s, witness
  8.35/7.26 s, serialization .024/.027 s; known readiness sums 48.107/47.382 s.
  Verification internal .964/.976 s, from bytes .98/.99 s. Deleting the entire
  slot would save ~20.4% of the known sums; fusion removes much less work.
  Fold/read attribution is missing. Shared two-thread synthetic 125M CPU with
  compilation overlap, not GPU/8B estimates. Grouped A/B still records waiting
  for heavy lock, no runs. No job duplicated or liveness claim made.

## Ranked hypotheses and next concrete experiment

1. **Fusion**, moderate integration, measured-code seam: native parity first,
   then attribute fold/evaluation and cache/parallel costs. Actual gain unknown;
   register pressure or cache hits may erase modeled savings. Owner only.
2. **Batching/amortization**, next research experiment: B fresh-challenge
   public-weight contractions at `zkp-core/src/mle.rs::fold_cols_i8`, called
   by `private_block/argument.rs` for gate/up/down weights. Read each small
   int8 weight tile once and produce B independently challenged outputs.
   Compare B=1/2/4/8 to independent direct signed-Fp2 dot products; include
   signed extrema, zero padding, extension challenges, stale challenge and
   mixed-model controls. Count matrix reads, challenge reads, accumulator and
   output traffic. P1 block has no W commitment, and public objects already
   own reusable weight vectors: do not import legacy W-cache savings.
   Establish whether multiple challenge vectors can actually coexist without
   excessive concurrent witness memory. Falsify savings if this stage is
   negligible or scheduling/residency costs dominate. No claimed time ceiling
   until the relevant definition/fold phase is measured.
3. **Fractional-GKR helper-column reduction**, potentially larger effect but
   high protocol/PCS/masking/composition cost. Earlier sources preserved; no
   rewrite or privacy acceptance authorized by the experiment.

Remaining rotation: quantization/arithmetic -> proof composition ->
sumcheck/GKR -> GPU NTT/commitments -> lookup/softmax -> memory traffic.

## Preserved findings and source qualifications

All five cycles and separate-session budget/KV/amortization work remain in
FINDINGS.md/sources.jsonl. Prior NTT pad-overlap repair needs device tests;
current CUDA has no restoration-copy saving. Exact pair-cache arithmetic
passes but its phase ceiling is <0.5% of known readiness. Grouped native
correctness passed in owner's lane; timing remains pending.

Three primary records added: Plonky3 fusion follow-ups; Thaler 2013 work reuse
(revised 2017-02-08; current code already has geometrically shrinking tables);
2026-08-13 GPU instruction-throughput study (database workloads, no ZKP result).
Plonky3 release date displays Sep 23 without verified year; exact date null.
Main MIT inspected; revision-specific license/code unverified. PRs/source/
package/commit fetches returned Cache miss/Internal Error, recorded without
bypass. No downloaded code executed or approval requested.

Resume by reading this state, FINDINGS, sources, latest results and AGENDA,
then project CLAUDE.md, MVP_STATUS, decisions, active coordination and current
throughput accounting. Preserve negative results and keep all fixtures synthetic.
